# Order lifecycle contract

Design guidance based on the team's stated features; this repository does not currently contain application code proving these rules are implemented.

| Current state | Next state | Actor | Preconditions |
|---|---|---|---|
| New order | SUBMITTED | Owning student | Fixed bag belongs to student; 1–15 total garments; no active order for bag. |
| SUBMITTED | RECEIVED | Staff | Physical bag received and quantities reviewed. |
| RECEIVED | WASHING | Staff | Morning/evening lot assigned. |
| WASHING | READY | Staff | Washing and packing complete; bag physically available at collection counter. |
| READY | COLLECTED | Staff | Bag handed over to the owning student. |

Reject skipped/backward transitions in this proposed flow. No cancellation or reopening is specified; add an explicit policy before adding either. An order stays active until COLLECTED. READY is not equivalent to washing finished: packing and counter availability are required.

For each accepted transition, lock the order row, check the expected old status, insert one timeline event and update current_status in the same transaction. Event sequence numbers establish ordering even when timestamps match. Include actor and timestamp in the event; do not overwrite previous events.

A repeated request to move an already-updated order must not create another event. Return a conflict or a documented idempotent response consistently. Two staff members updating the same order concurrently must not both advance from the same stale state.

The student dashboard derives the collection alert from current_status = READY; hide it after collection. Display the latest delay reason without replacing the timeline. History includes collected orders; student queries must be restricted to the authenticated student's fixed bag.
