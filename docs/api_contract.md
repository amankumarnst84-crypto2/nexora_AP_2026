# Proposed REST contract

These endpoint names are a design proposal for the stated Express backend. No routes or response formats have been verified against application source in this repository. Reconcile with the real app before implementation.

| Method and path | Actor | Input / result |
|---|---|---|
| POST /api/auth/login | Public | Login identifier/password → session cookie and safe profile |
| POST /api/auth/logout | Authenticated | Clear session cookie |
| GET /api/me | Authenticated | Safe identity, role and student's bag when applicable |
| POST /api/orders | Student | items: [{clothingTypeId, quantity}]; server derives owner/bag |
| GET /api/orders | Student/staff | Student's own history; staff operational search; paginated |
| GET /api/orders/:id | Owner/staff | Items, current status, timeline and delay information |
| POST /api/orders/:id/transitions | Staff | expectedStatus, nextStatus; validate allowed transition |
| POST /api/orders/:id/delays | Staff | Nonblank reason |
| GET /api/lots | Staff | Date/shift filter |
| POST /api/lots | Staff | washDate, shift (MORNING/EVENING) |
| PUT /api/orders/:id/lot | Staff | lotId; assign before washing |
| POST /api/orders/:id/complaints | Owner | category, description |
| GET /api/complaints/:id | Owner/staff | Complaint, responses, confirmation |
| POST /api/complaints/:id/responses | Staff | responseText |
| POST /api/complaints/:id/confirmation | Owner | responseId from this complaint |

Suggested error shape: `{ "error": { "code": "ACTIVE_ORDER_EXISTS", "message": "Your bag already has an active order." } }`. Do not include SQL text, stack traces or credentials in responses. Use 400 for malformed input, 401 for absent/invalid session, 403 for forbidden action, 404 for unavailable resources, and 409 for active-bag or stale-status conflicts.

For list endpoints, validate page size and use a stable ordering with a unique ID tie-breaker. Apply ownership filters before pagination. Parameterize search queries. Store instants as timestamptz and return an explicit timezone offset/UTC representation; display hostel-local time in the UI.

Signup routes remain outside this proposal until the pending student-verification policy is defined. Payment, photos and machine booking endpoints are not part of the stated scope.
