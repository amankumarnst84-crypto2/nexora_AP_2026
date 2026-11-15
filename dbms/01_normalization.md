# WashTrack — normalization from 1NF to 3NF / BCNF

**Team:** T0138 · Nexora · Section D  
**Members:** Aman Agrawal (2501010051), Rehaan Dhillon (2501010372), Prtishtha Khurana (2501010360), Nikunj Rohilla (2501010589)

## 1. Scope and design basis

WashTrack manages college-hostel laundry. Students and staff log in with different permissions. Each student has a fixed bag number. An order records clothing types and quantities (at most 15 garments), and each bag can have only one active order. Staff receive orders, allocate morning/evening washing lots, record delays and move orders through Submitted → Received → Washing → Ready → Collected. Ready means the packed bag is physically available at the collection counter; students see a dashboard alert. Students can report missing or extra clothes, stains and colour damage. Staff respond, and resolution requires the student's confirmation. Order history and status timelines persist in PostgreSQL.

This document proposes a relational design for the features supplied by the team. The current Prisma schema was not available for comparison; names below are logical database names, not a claim about already implemented Prisma models. Signup is pending implementation. Billing, paid services, photographs, machine reservations and delivery scheduling are outside scope.

Assumptions: each student has one permanently assigned bag; a bag belongs to one student; staff have no student bag. If bag reassignment is introduced, add an assignment-history relation and link orders to the assignment, rather than changing historical ownership. The login identifier is unique after application normalization; it need not be an email. One order has at most one current washing lot; repeated washing cycles would need a separate order-lot history table.

## 2. Unnormalized starting record (UNF)

A tempting implementation stores everything in one document:

```text
LaundryOrder(
  order_id, submitted_at, bag_number,
  student_id, student_name, student_login, student_password_hash,
  lot_id, lot_date, lot_shift,
  clothes: [{clothing_type_id, clothing_type_name, quantity}, ...],
  timeline: [{event_id, status, changed_at, staff_id, staff_name}, ...],
  delays: [{delay_id, staff_id, reason, recorded_at}, ...],
  complaints: [{complaint_id, category, description,
                responses: [{response_id, staff_id, response_text, responded_at}],
                student_confirmed_at}, ...]
)
```

Clothes, timeline events, delays and responses repeat inside an order. Student and staff details are copied across orders. Renaming a clothing type or changing a student's name then requires many updates. A new clothing type cannot be stored without an order, and deleting the last order could accidentally remove the only copy of a student's information.

Passwords must be stored as bcrypt hashes, never plaintext. JWT cookies are an authentication mechanism, not a reason to copy identity details into every order.

## 3. First normal form (1NF)

Flatten each repeating group into its own relation, keeping one scalar value in every column. Do not combine garment rows with status rows: doing so would multiply each garment by every event.

A deliberately still-redundant first step is:

```text
OrderClothing_1NF(
  order_id, clothing_type_id, quantity, clothing_type_name,
  submitted_at, bag_number, student_id, student_name, student_login,
  lot_id, lot_date, lot_shift
) PK(order_id, clothing_type_id)

StatusEvent_1NF(event_id PK, order_id, status, changed_at,
                actor_user_id, actor_name)
Delay_1NF(delay_id PK, order_id, staff_user_id, staff_name, reason, recorded_at)
Complaint_1NF(complaint_id PK, order_id, category, description, created_at,
              confirmed_response_id, student_confirmed_at)
Response_1NF(response_id PK, complaint_id, staff_user_id, staff_name,
             response_text, responded_at)
```

Functional dependencies (FDs) in the order-clothing relation:

```text
(order_id, clothing_type_id) → quantity
clothing_type_id → clothing_type_name
order_id → submitted_at, bag_number, lot_id
bag_number → student_id
student_id → student_name, student_login
lot_id → lot_date, lot_shift
```

These are rules of the application, not conclusions based only on coincidentally unique sample values. A clothing type appears once per order, with quantity holding the number of garments. Multiple missing garments do not create duplicate clothing-type rows.

The first relation is in 1NF but not 2NF: clothing_type_name depends only on clothing_type_id, while order attributes depend only on order_id. Those determinants are proper subsets of its composite key. Nullable lot_id means an unallocated order; the lot dependency applies where a lot exists.

## 4. Second normal form (2NF)

Remove the partial dependencies:

```text
OrderItem(order_id, clothing_type_id, quantity)
  PK(order_id, clothing_type_id)
ClothingType(clothing_type_id PK, clothing_type_name UNIQUE)
Order_2NF(order_id PK, submitted_at, bag_number, student_id,
          student_name, student_login, lot_id, lot_date, lot_shift)
```

OrderItem's quantity now depends on the whole key. Clothing types can exist before any orders. Order_2NF has a single-column key, but still repeats student and washing-lot details:

```text
order_id → bag_number → student_id → student_name, student_login
order_id → lot_id → lot_date, lot_shift
```

Similarly, event_id → actor_user_id → actor_name, delay_id → staff_user_id → staff_name and response_id → staff_user_id → staff_name are transitive dependencies. These leave update anomalies even though the relations are in 2NF. Names are not keys: different people may have the same name.

## 5. Third normal form (3NF): proposed final relations

Separate identity, student bag assignment, catalog data, orders and activity. PK = primary key; AK = alternate candidate key; FK = foreign key.

| Relation | Attributes and keys | Nontrivial functional dependencies |
|---|---|---|
| users | **user_id PK**, **login_identifier AK**, full_name, password_hash, role, created_at | user_id → all other attributes; login_identifier → all other attributes |
| students | **user_id PK/FK → users**, **bag_number AK** | user_id → bag_number; bag_number → user_id |
| clothing_types | **clothing_type_id PK**, **name AK**, is_active | clothing_type_id → name, is_active; name → clothing_type_id, is_active |
| washing_lots | **lot_id PK**, wash_date, shift | lot_id → wash_date, shift |
| orders | **order_id PK**, bag_number FK → students.bag_number, submitted_at, current_status, lot_id nullable FK → washing_lots | order_id → all other attributes |
| order_items | **(order_id FK → orders, clothing_type_id FK → clothing_types) PK**, quantity | (order_id, clothing_type_id) → quantity |
| order_status_events | **event_id PK**, order_id FK → orders, **(order_id, event_sequence) AK**, status, changed_at, actor_user_id FK → users | event_id → remaining attributes; (order_id, event_sequence) → remaining attributes |
| order_delays | **delay_id PK**, order_id FK → orders, staff_user_id FK → users, reason, recorded_at | delay_id → remaining attributes |
| complaints | **complaint_id PK**, order_id FK → orders, category, description, created_at | complaint_id → remaining attributes |
| complaint_responses | **response_id PK**, complaint_id FK → complaints, staff_user_id FK → users, response_text, responded_at | response_id → remaining attributes |
| complaint_confirmations | **complaint_id PK/FK → complaints**, response_id FK → complaint_responses, confirmed_at | complaint_id → response_id, confirmed_at; response_id → complaint_id, confirmed_at when response_id is UNIQUE |

Make confirmation.response_id UNIQUE: one response belongs to one complaint, and the proposed design permits at most one final confirmation per complaint. Enforce that the referenced response belongs to the same complaint (for example a composite FK to a unique `(complaint_id, response_id)` pair in complaint_responses). The confirming student is derived through complaint → order → bag → student and checked against the authenticated user, so we do not duplicate student_id in complaints or confirmations. This design treats confirmation as final; reopening would require a resolution-event history instead.

No staff name is copied into events, delays or responses. No student name or login is copied into orders. The order stores its fixed bag number and derives the student through students, avoiding the redundant FD bag_number → student_id inside orders. Names of clothing types occur only in the catalog. Multiple events, delays, complaints and responses remain separate rows.

`current_status` is an intentional cached projection of the latest status event. Its table-local FD is order_id → current_status, so the orders relation is still in 3NF; however, the cache duplicates a fact across relations. Update the event and cached status in one transaction. The cache supports efficient active-order enforcement. Do not persist a second `is_active_order`, garment total, student display name, complaint-resolved flag or Ready-alert flag when those can be derived.

## 6. BCNF check (optional)

BCNF requires every determinant of a nontrivial FD to be a superkey. Under the dependencies above, each proposed relation meets BCNF:

- users: user_id and normalized login_identifier are candidate keys.
- students: both user_id and bag_number are candidate keys. This is a 1:1 student-to-bag assignment, not a bag copied into every identity/event row.
- clothing_types: both ID and canonical name identify a type. The name uniqueness is an explicit catalog policy.
- washing_lots: lot_id identifies a lot. Date alone and shift alone do not; no `(wash_date, shift)` uniqueness is assumed because multiple lots may share a shift.
- orders: bag_number is not a key across history; the same bag can have many collected orders. Only order_id determines an order's attributes.
- order_items: quantity depends on the complete composite key, not on either component alone.
- status events: both event_id and `(order_id, event_sequence)` are keys. Timestamps are not keys because two events can share a timestamp.
- delays, complaints and responses: their own IDs determine their fields. An order can have multiple complaints and a complaint can have multiple responses.
- confirmations: complaint_id and unique response_id are candidate keys under the one-final-confirmation rule.

BCNF does not prove that a status transition is valid, that a staff member physically placed a bag at the counter, or that API authorization is correct. Those require the operational rules below.

## 7. Business constraints and transaction boundaries

| Requirement | Enforcement in the proposed PostgreSQL / API design |
|---|---|
| Student/staff roles | users.role CHECK in STUDENT/STAFF. API derives role from authenticated identity; only students have a students row. Enforce this cross-table role rule transactionally. |
| Fixed bag | students.bag_number NOT NULL UNIQUE. Do not accept a student-supplied bag belonging to someone else. Retain assignment to protect historical ownership. |
| Clothing type and quantity | order_items FKs, composite PK and CHECK(quantity BETWEEN 1 AND 15). At least one item and sum(quantity) ≤ 15 per order must be checked transactionally or with a deferred constraint trigger; a row CHECK cannot enforce the sum. |
| One active order per bag | A UNIQUE partial index on orders(bag_number) WHERE current_status <> 'COLLECTED' enforces this even for concurrent submissions. current_status is NOT NULL and restricted to the five known states. |
| Lifecycle and lot | Append the initial SUBMITTED event on creation. Staff alone make RECEIVED → WASHING → READY → COLLECTED transitions, in sequence after SUBMITTED → RECEIVED. A lot is assigned before washing; lot.shift is MORNING or EVENING. Lock the order during changes and maintain monotonic event_sequence. |
| Ready means counter availability | Staff marks READY only after the packed bag is physically at the collection counter. The student alert is derived from current_status = READY; it disappears after collection. The database cannot independently verify physical availability. |
| Status history | Insert one event per transition and update current_status in the same transaction. The creator records SUBMITTED; later actor IDs must belong to staff. Use timestamptz for event instants and Asia/Kolkata when displaying them. |
| Delay reasons | Store nonblank reason, staff identity and timestamp in order_delays. Several delays may belong to one order. |
| Complaints | category CHECK in MISSING_CLOTHES, EXTRA_CLOTHES, STAINS, COLOUR_DAMAGE. Student may complain only about their own order. Staff responses reference authenticated staff. |
| Student-confirmed resolution | A complaint is resolved exactly when its confirmation row exists. Require at least one response, confirm a response from the same complaint, and check the authenticated student owns the order. confirmed_at must be at or after responded_at. Staff cannot resolve by merely responding. |
| History retention | RESTRICT deletion of users, orders, lots and catalog rows with historical references; deactivate clothing types instead. Avoid cascading away complaints or timelines. |

For max-15 and lifecycle checks, serialize changes by locking the parent order row before inspecting or changing children. A frontend validation alone is insufficient: concurrent API requests can otherwise violate limits. These are implementation requirements for the next schema checkpoint, not claims that existing endpoints already enforce them.

## 8. Why the decomposition preserves information

OrderClothing_1NF decomposes on order_id and clothing_type_id, which are keys of the resulting orders and clothing_types relations; joining through those keys recovers order/item/catalog facts without multiplying item rows. Identity and bag details are recovered through unique students.bag_number and users.user_id. Lot attributes are recovered through washing_lots.lot_id; use a LEFT JOIN for unallocated orders. Activity groups remain independent 1:N relations; joining several event groups into one output may multiply rows and should use separate queries or aggregation.

The main FDs are preserved in individual tables through PKs and UNIQUE constraints. Cross-table business rules (garment sum, ownership, actor role, valid transitions and confirmation matching) are listed explicitly rather than being mislabeled as normal-form guarantees.

### Example (illustrative, not measured production data)

Student U17 owns bag B042. Order O501 contains `(O501, SHIRT, 3)` and `(O501, TROUSERS, 2)`: total five garments, stored as two item rows. The order is allocated to morning lot L9. Every transition adds a status event; the order becomes READY only when B042 reaches the counter. Complaint C12 about a missing shirt receives staff response R8. C12 remains unresolved until U17 confirms R8. After collection a new order can reuse B042 without overwriting O501's items or timeline.
