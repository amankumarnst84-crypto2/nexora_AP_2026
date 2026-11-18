# WashTrack · Nexora T0138

College-hostel laundry management for students and staff. Team: Aman Agrawal, Rehaan Dhillon, Prtishtha Khurana and Nikunj Rohilla. Section D; mentor Vishnu.

Students use a fixed bag, submit up to 15 garments and track Submitted → Received → Washing → Ready → Collected. Staff manage morning/evening lots, delays and complaints. READY means the packed bag is available at the collection counter. Complaints are resolved only after the owning student's confirmation of a staff response.

The team reports React, Node.js/Express (CommonJS), PostgreSQL, Prisma Client 6, bcryptjs and JWT cookies as the application stack. This repository currently holds database/design artifacts, not the application source or a runnable server. Student signup is pending. Billing, photos and machine reservations are not in scope.

## Design and verification documents

- [Normalization and functional dependencies](dbms/01_normalization.md)
- [Existing team ER diagram](dbms/erd_final.png)
- [Order states and Ready rule](docs/order_workflow.md)
- [Student/staff permissions](docs/access_control.md)
- [Garment limits and concurrent submissions](docs/order_transactions.md)
- [Complaint resolution](docs/complaint_workflow.md)
- [Proposed REST API](docs/api_contract.md)
- [Acceptance scenarios — not yet executed](docs/acceptance_checks.md)
- [Implementation gaps and checkpoint handoff](dbms/IMPLEMENTATION_STATUS.md)

These contracts describe the intended behavior; compare them with the actual app before claiming implementation. Keep SQL, diagrams, normalization and endpoint behavior consistent. Collect AP query timings from WashTrack's actual database, separately from the OLX DE project.

Contribute under your own Git identity. Make a genuine change you can explain, check the diff and use a normal push or reviewed pull request. Never commit JWT secrets, database credentials, password dumps or node_modules.
