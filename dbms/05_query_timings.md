# CP04 PostgreSQL query timings

## Measurement setup

- PostgreSQL engine: PostgreSQL 18.7 via PGlite 0.5.17 (WebAssembly, `wasm32-unknown-emscripten`).
- Environment: embedded in-process PostgreSQL; no native PostgreSQL server or application runtime. Results are specific to this engine/runtime and should not be compared directly with production-server timings.
- Schema: `dbms/03_schema.sql` from the supplied repo.
- Dataset: synthetic test fixtures only; 10,000 collected orders plus two workflow orders, 101 synthetic students, four clothing types, two washing lots, and synthetic complaint/event rows. No repo sample records existed; no real user data was used.
- Collection date: 2026-11-21 (Asia/Kolkata).
- Method: `EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)`; each statement was run three times. Writes were enclosed in `BEGIN` / `ROLLBACK`, so each run left fixture state unchanged.
- Parameters: representative synthetic IDs and values; exact SQL and values are included in each plan file.
- Timing field: PostgreSQL-reported `Execution Time` in milliseconds. Arithmetic mean of the three displayed runs, rounded to 3 decimals.

Logout clears the session cookie in the proposed API and has no SQL statement, so it has no timing or plan. The query catalog contains 20 SQL statements; all 20 have three runs and corresponding plan output files.

| ID | Query/action from `04_queries.sql` | Run 1 (ms) | Run 2 (ms) | Run 3 (ms) | Average (ms) |
|---|---|---:|---:|---:|---:|
| Q01 | Login lookup | 0.073 | 0.012 | 0.012 | 0.032 |
| Q02 | Profile with student bag | 0.045 | 0.020 | 0.017 | 0.027 |
| Q03 | Lock and resolve student bag | 0.089 | 0.032 | 0.025 | 0.049 |
| Q04 | Insert order | 0.446 | 0.176 | 0.142 | 0.255 |
| Q05 | Insert order item | 0.495 | 0.157 | 0.168 | 0.273 |
| Q06 | Insert initial SUBMITTED event | 0.348 | 0.163 | 0.129 | 0.213 |
| Q07 | Student order history | 5.482 | 2.875 | 2.967 | 3.775 |
| Q08 | Staff operational order search | 25.765 | 19.391 | 18.846 | 21.334 |
| Q09 | Order detail with item/clothing/lot joins | 0.063 | 0.029 | 0.024 | 0.039 |
| Q10 | Order timeline | 0.196 | 0.015 | 0.013 | 0.075 |
| Q11 | Latest delay | 0.042 | 0.035 | 0.031 | 0.036 |
| Q12 | Conditional lifecycle transition plus event | 1.398 | 0.101 | 0.085 | 0.528 |
| Q13 | Insert staff delay | 0.197 | 0.068 | 0.078 | 0.114 |
| Q14 | Washing lot list | 6.126 | 5.843 | 5.427 | 5.799 |
| Q15 | Create washing lot | 0.085 | 0.022 | 0.013 | 0.040 |
| Q16 | Assign lot to order | 0.126 | 0.049 | 0.038 | 0.071 |
| Q17 | Create owner complaint | 0.215 | 0.064 | 0.046 | 0.108 |
| Q18 | Complaint detail and derived state | 0.077 | 0.057 | 0.057 | 0.064 |
| Q19 | Insert staff complaint response | 0.229 | 0.066 | 0.055 | 0.117 |
| Q20 | Student complaint confirmation | 0.208 | 0.067 | 0.062 | 0.112 |
