# Submission and concurrency rules

Proposed implementation for the normalized design in dbms/01_normalization.md. No migration or running endpoint is supplied by this document.

An order contains one row per clothing type, with a positive integer quantity. The total quantity must be between 1 and 15. Reject unknown/inactive clothing types and duplicate type entries (or combine duplicates before validating, if that policy is documented). Do not count the number of item rows as the garment total.

Create order, items and initial SUBMITTED event in one transaction. Resolve bag_number from the authenticated student. Validate integer quantities and total before writing, and enforce per-row positivity in PostgreSQL as well. A unique partial index on bag_number for orders whose current_status is not COLLECTED enforces one active order even when two requests arrive together.

For edits or concurrent item insertion, lock the parent order before inspecting the item sum. All write paths must take the same lock; otherwise one compliant endpoint cannot protect against a bypass. A deferred database trigger is an alternative for enforcing the aggregate limit across arbitrary SQL writers. A simple CHECK on order_items cannot sum other rows.

Use Prisma's transaction interface consistently, with parameterized SQL if a database feature needs raw SQL. Map unique active-bag violations to a user-facing conflict; do not retry the same conflicting submission indefinitely. If any item/event insert fails, roll back the entire submission so there are no empty or partially created orders.

Recommended immutable boundary: garment quantities cannot be edited after staff reception without a separately documented reconciliation process. Record missing/extra-clothes issues as complaints rather than silently rewriting historical counts.

Concurrency review: two submits for one bag → one succeeds; two item changes that would exceed 15 → at most a valid total commits; simultaneous lifecycle changes → one event for the expected transition; item insert failure → no partial order remains.
