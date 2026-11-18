# Complaint workflow

Design contract: categories are MISSING_CLOTHES, EXTRA_CLOTHES, STAINS and COLOUR_DAMAGE. A complaint references one order and carries a nonblank description and creation timestamp. The authenticated student must own that order.

1. Student submits the complaint; its state is open.
2. Staff adds a response with their identity, text and timestamp. Keep earlier responses; do not replace them.
3. The owning student reviews the response. Staff responding alone does not resolve the complaint.
4. Student confirms a specific response belonging to that complaint. Insert the final confirmation row and timestamp transactionally.

Derived display states: no responses and no confirmation → Awaiting staff; one or more responses and no confirmation → Awaiting student confirmation; confirmation exists → Resolved. Avoid a separately editable resolved Boolean that can disagree with the confirmation record.

Validate that response.complaint_id equals the complaint being confirmed and confirmation time is not before response time. Prevent more than one final confirmation per complaint. Treat duplicate confirmation requests consistently without inserting duplicate history. Staff cannot confirm using their own role or a body-supplied student ID.

The current proposal treats confirmation as final. Reopening, compensation and response editing are unspecified; do not silently invent those behaviors. An order can remain COLLECTED while a complaint is open: the laundry lifecycle and complaint lifecycle represent different facts.

Keep complaints and responses when an order is collected. Use history-preserving deletion policies so resolving an issue does not erase its evidence.
