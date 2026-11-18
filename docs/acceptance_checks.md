# Acceptance checklist — not yet executed

Record pass/fail, build version and evidence when these scenarios are run against the actual application. Documentation alone is not a passing test.

| Scenario | Expected result |
|---|---|
| Student submits 3 shirts + 2 trousers | Two item rows, total 5; SUBMITTED timeline event; own fixed bag. |
| Student submits exactly 15 garments | Accepted when no active order exists. |
| Student submits 16 garments, zero, negative or fractional quantity | Rejected without any partial order. |
| Two simultaneous submissions for the same bag | Exactly one active order is committed. |
| Student alters bag/user ID in request | Cannot create an order for another student. |
| Student requests another student's order or complaint ID | No private data returned. |
| Student calls staff transition endpoint | Forbidden regardless of hidden UI buttons. |
| Staff follows all five lifecycle states | One correctly attributed event per transition. |
| Staff tries SUBMITTED → READY | Rejected as skipped transition. |
| Two staff update from the same expected state | No duplicate or contradictory transition commits. |
| Washing finished but bag not at counter | Must remain not READY; collection alert not shown. |
| Bag is packed and at counter, then marked READY | Owning student sees collection alert. |
| Staff marks COLLECTED | Alert disappears; history stays; bag can submit next order. |
| Staff adds a delay reason | Correct order displays reason and timestamp; old events remain. |
| Each of the four complaint categories is submitted | Persisted under the owning order. |
| Staff responds to complaint | Awaiting student confirmation, not Resolved. |
| Staff attempts confirmation | Forbidden. |
| Student confirms a response from a different complaint | Rejected; neither complaint is wrongly resolved. |
| Owning student confirms correct response twice | One final confirmation; consistent duplicate-request behavior. |
| Server/database restart | Existing orders, events and complaints remain. |
| Narrow mobile screen | Forms, status, alert and error messages remain readable and usable. |

Include rollback failure injection during submission to confirm that items, order and initial event are atomic. Execute concurrent cases with independent requests/connections; sequential clicks do not prove concurrency safety. Use synthetic test accounts and bags, not classmates' real credentials.
