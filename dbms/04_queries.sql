-- CP03 query catalog for WashTrack / Nexora T0138
-- IMPORTANT: The repository supplied for this task has no application source or
-- Prisma schema. These are proposed PostgreSQL queries inferred from
-- docs/api_contract.md, the workflow contracts, and dbms/03_schema.sql.
-- Reconcile table/column names and actual endpoint usage with the running app
-- before presenting this as an inventory of queries the app actually uses.
-- Parameters use PostgreSQL $1, $2, ... placeholders; always bind values.
-- Each statement is marked READ or WRITE. Multi-statement transactions are
-- explicitly grouped; execute each group on one connection in one transaction.

-- ---------------------------------------------------------------------------
-- Authentication and profile
-- ---------------------------------------------------------------------------

-- READ: Find a login record; verify password_hash in application code.
SELECT user_id, login_identifier, full_name, password_hash, role
FROM users
WHERE login_identifier = $1;

-- WRITE: Logout is normally handled by clearing the authenticated cookie;
-- no database statement is required by the documented schema.
-- (No SQL query.)

-- READ: Authenticated profile and optional fixed student bag.
SELECT u.user_id, u.login_identifier, u.full_name, u.role, s.bag_number
FROM users AS u
LEFT JOIN students AS s ON s.user_id = u.user_id
WHERE u.user_id = $1;

-- ---------------------------------------------------------------------------
-- Orders
-- ---------------------------------------------------------------------------

-- WRITE: Create an order, its item rows, and initial timeline event atomically.
-- Application must first validate 1..15 total garments and active clothing
-- types. Resolve bag_number from the authenticated student, never request data.
-- Transaction step 1: lock and resolve the student's fixed bag.
SELECT s.bag_number
FROM students AS s
JOIN users AS u ON u.user_id = s.user_id
WHERE s.user_id = $1 AND u.role = 'STUDENT'
FOR UPDATE OF s;
-- Transaction step 2: insert order and return generated ID.
INSERT INTO orders (bag_number)
VALUES ($2)
RETURNING order_id, bag_number, submitted_at, current_status;
-- Transaction step 3: insert one row per distinct clothing type (repeat for
-- each item, or use a bound multi-row INSERT from the application).
INSERT INTO order_items (order_id, clothing_type_id, quantity)
VALUES ($1, $2, $3);
-- Transaction step 4: create the initial event.
INSERT INTO order_status_events
    (order_id, event_sequence, status, actor_user_id)
VALUES ($1, 1, 'SUBMITTED', $2);
-- Any failure in these steps must roll back the whole transaction. The partial
-- unique index orders_one_active_order_per_bag is the concurrency backstop.

-- READ: Student order history (ownership filter before pagination).
SELECT o.order_id, o.submitted_at, o.current_status, o.lot_id,
       wl.wash_date, wl.shift,
       COALESCE(SUM(oi.quantity), 0) AS garment_count
FROM orders AS o
JOIN students AS s ON s.bag_number = o.bag_number
LEFT JOIN washing_lots AS wl ON wl.lot_id = o.lot_id
LEFT JOIN order_items AS oi ON oi.order_id = o.order_id
WHERE s.user_id = $1
GROUP BY o.order_id, wl.wash_date, wl.shift
ORDER BY o.submitted_at DESC, o.order_id DESC
LIMIT $2 OFFSET $3;

-- READ: Staff operational order search; add validated optional filters in the
-- application (e.g. status/date/bag) and keep bound parameters. $1 limit, $2 offset.
SELECT o.order_id, o.bag_number, s.user_id AS student_user_id,
       u.full_name AS student_name, o.submitted_at, o.current_status,
       wl.wash_date, wl.shift,
       COALESCE(SUM(oi.quantity), 0) AS garment_count
FROM orders AS o
JOIN students AS s ON s.bag_number = o.bag_number
JOIN users AS u ON u.user_id = s.user_id
LEFT JOIN washing_lots AS wl ON wl.lot_id = o.lot_id
LEFT JOIN order_items AS oi ON oi.order_id = o.order_id
GROUP BY o.order_id, s.user_id, u.full_name, wl.wash_date, wl.shift
ORDER BY o.submitted_at DESC, o.order_id DESC
LIMIT $1 OFFSET $2;

-- READ: Order detail, items, clothing names, current lot and owner. Apply the
-- owner predicate for student requests; staff requests must pass staff auth.
SELECT o.order_id, o.bag_number, s.user_id AS student_user_id,
       o.submitted_at, o.current_status, wl.lot_id, wl.wash_date, wl.shift,
       oi.clothing_type_id, ct.name AS clothing_type, oi.quantity
FROM orders AS o
JOIN students AS s ON s.bag_number = o.bag_number
LEFT JOIN washing_lots AS wl ON wl.lot_id = o.lot_id
LEFT JOIN order_items AS oi ON oi.order_id = o.order_id
LEFT JOIN clothing_types AS ct ON ct.clothing_type_id = oi.clothing_type_id
WHERE o.order_id = $1
  AND ($2::BIGINT IS NULL OR s.user_id = $2)
ORDER BY ct.name, oi.clothing_type_id;

-- READ: Order timeline with actor names, newest event first.
SELECT e.event_id, e.event_sequence, e.status, e.changed_at,
       e.actor_user_id, u.full_name AS actor_name
FROM order_status_events AS e
JOIN users AS u ON u.user_id = e.actor_user_id
WHERE e.order_id = $1
ORDER BY e.event_sequence DESC;

-- READ: Latest recorded delay for order detail.
SELECT d.delay_id, d.reason, d.recorded_at,
       d.staff_user_id, u.full_name AS staff_name
FROM order_delays AS d
JOIN users AS u ON u.user_id = d.staff_user_id
WHERE d.order_id = $1
ORDER BY d.recorded_at DESC, d.delay_id DESC
LIMIT 1;

-- WRITE: Staff advances one lifecycle step and appends its event atomically.
-- Application validates actor is STAFF and the requested transition is allowed.
-- The conditional UPDATE prevents stale transitions; an empty result is a conflict.
WITH changed AS (
    UPDATE orders
    SET current_status = $3
    WHERE order_id = $1 AND current_status = $2
    RETURNING order_id, current_status
), event_added AS (
    INSERT INTO order_status_events
        (order_id, event_sequence, status, actor_user_id)
    SELECT c.order_id,
           (SELECT COALESCE(MAX(e.event_sequence), 0) + 1
            FROM order_status_events AS e WHERE e.order_id = c.order_id),
           c.current_status, $4
    FROM changed AS c
    RETURNING order_id, event_sequence, status, changed_at
)
SELECT c.order_id, c.current_status, e.event_sequence, e.changed_at
FROM changed AS c
JOIN event_added AS e ON e.order_id = c.order_id;

-- WRITE: Record staff delay reason.
INSERT INTO order_delays (order_id, staff_user_id, reason)
SELECT o.order_id, $2, btrim($3)
FROM orders AS o
JOIN users AS staff ON staff.user_id = $2 AND staff.role = 'STAFF'
WHERE o.order_id = $1
  AND length(btrim($3)) > 0
RETURNING delay_id, order_id, reason, recorded_at;

-- ---------------------------------------------------------------------------
-- Washing lots
-- ---------------------------------------------------------------------------

-- READ: List lots, optionally filtered by date; $1 may be NULL.
SELECT wl.lot_id, wl.wash_date, wl.shift, COUNT(o.order_id) AS assigned_orders
FROM washing_lots AS wl
LEFT JOIN orders AS o ON o.lot_id = wl.lot_id
WHERE ($1::DATE IS NULL OR wl.wash_date = $1)
GROUP BY wl.lot_id
ORDER BY wl.wash_date DESC, wl.shift, wl.lot_id;

-- WRITE: Create morning/evening lot. Validate staff role in request middleware.
INSERT INTO washing_lots (wash_date, shift)
VALUES ($1, $2)
RETURNING lot_id, wash_date, shift;

-- WRITE: Assign lot to an order before it enters WASHING. Application checks
-- staff role and order state (RECEIVED); run in a transaction with row lock.
UPDATE orders AS o
SET lot_id = wl.lot_id
FROM washing_lots AS wl
WHERE o.order_id = $1
  AND wl.lot_id = $2
  AND o.current_status = 'RECEIVED'
RETURNING o.order_id, o.lot_id;

-- ---------------------------------------------------------------------------
-- Complaints
-- ---------------------------------------------------------------------------

-- WRITE: Create complaint only for an order owned by the authenticated student.
INSERT INTO complaints (order_id, category, description)
SELECT o.order_id, $3, btrim($4)
FROM orders AS o
JOIN students AS s ON s.bag_number = o.bag_number
WHERE o.order_id = $1
  AND s.user_id = $2
  AND length(btrim($4)) > 0
RETURNING complaint_id, order_id, category, description, created_at;

-- READ: Complaint detail and derived display state; owner filter for student
-- requests, while authorized staff may query by complaint ID.
SELECT c.complaint_id, c.order_id, c.category, c.description, c.created_at,
       s.user_id AS student_user_id,
       CASE
         WHEN cc.complaint_id IS NOT NULL THEN 'RESOLVED'
         WHEN EXISTS (SELECT 1 FROM complaint_responses r WHERE r.complaint_id = c.complaint_id)
           THEN 'AWAITING_STUDENT_CONFIRMATION'
         ELSE 'AWAITING_STAFF'
       END AS display_state,
       r.response_id, r.response_text, r.responded_at,
       staff.full_name AS staff_name,
       cc.response_id AS confirmed_response_id, cc.confirmed_at
FROM complaints AS c
JOIN orders AS o ON o.order_id = c.order_id
JOIN students AS s ON s.bag_number = o.bag_number
LEFT JOIN complaint_responses AS r ON r.complaint_id = c.complaint_id
LEFT JOIN users AS staff ON staff.user_id = r.staff_user_id
LEFT JOIN complaint_confirmations AS cc ON cc.complaint_id = c.complaint_id
WHERE c.complaint_id = $1
  AND ($2::BIGINT IS NULL OR s.user_id = $2)
ORDER BY r.responded_at, r.response_id;

-- WRITE: Staff responds to complaint. Verify staff role in middleware.
INSERT INTO complaint_responses (complaint_id, staff_user_id, response_text)
SELECT c.complaint_id, $2, btrim($3)
FROM complaints AS c
JOIN users AS staff ON staff.user_id = $2 AND staff.role = 'STAFF'
WHERE c.complaint_id = $1
  AND length(btrim($3)) > 0
RETURNING response_id, complaint_id, response_text, responded_at;

-- WRITE: Owning student confirms one response belonging to that complaint.
-- Unique constraints ensure one final confirmation; application must handle
-- duplicate confirmation consistently and verify actor is a STUDENT.
INSERT INTO complaint_confirmations (complaint_id, response_id)
SELECT c.complaint_id, r.response_id
FROM complaints AS c
JOIN orders AS o ON o.order_id = c.order_id
JOIN students AS s ON s.bag_number = o.bag_number
JOIN complaint_responses AS r
  ON r.complaint_id = c.complaint_id AND r.response_id = $2
JOIN users AS student ON student.user_id = $3 AND student.role = 'STUDENT'
WHERE c.complaint_id = $1
  AND s.user_id = $3
  AND r.responded_at <= CURRENT_TIMESTAMP
RETURNING complaint_id, response_id, confirmed_at;
