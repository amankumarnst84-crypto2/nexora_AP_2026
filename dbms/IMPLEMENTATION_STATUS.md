# Database handoff and remaining evidence

Inspected repository state before this documentation update: dbms/01_normalization.md and dbms/erd_final.png. The repository does not contain the React/Express application, Prisma schema, executable SQL schema or raw AP timing plans. The stack and features are team-provided context, not locally verified implementation.

| Item | Evidence / next action |
|---|---|
| Normalization | 01_normalization.md describes proposed relations, FDs and exceptions. |
| Existing ER image | erd_final.png is retained unchanged; compare each entity/key with the implemented schema before treating it as final. |
| Checkpoint ER filename | Course checklist asks for dbms/02_er_diagram.*. Validate the existing drawing first, then export the reviewed diagram under that name. |
| PostgreSQL DDL | Still needs dbms/03_schema.sql derived from the real Prisma schema and reviewed requirements. |
| Actual app queries | Still needs dbms/04_queries.sql, labeled READ/WRITE, based on actual endpoints. Proposed API documentation is not query evidence. |
| AP timing evidence | Still needs dbms/05_query_timings.md and dbms/plans with three EXPLAIN ANALYZE runs per query. Do not reuse OLX timings. |

Before implementing migrations: verify login identifier and bag assignment policy; compare all proposed table names to Prisma models; decide how aggregate garment limits and role rules are enforced; implement the active-bag partial unique index; verify status/event updates are atomic; validate complaint confirmation references the same complaint.

Use a scratch PostgreSQL database to test the final DDL from empty state. Test concurrent submission and status updates before collecting timing evidence. Migration SQL may be required for PostgreSQL constraints that are not represented directly in the chosen Prisma schema syntax.

Documentation added here does not mark the above missing deliverables as completed. Do not replace or relabel the team's existing diagram without checking its content against the final schema.
