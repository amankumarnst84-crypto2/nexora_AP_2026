# Query plan evidence

This directory contains the full PostgreSQL `EXPLAIN (ANALYZE, BUFFERS, FORMAT TEXT)` output for each SQL statement in `04_queries.sql`, with one file per run (`Q01_run1.txt` through `Q20_run3.txt`). Each plan includes the exact query with synthetic test values and PostgreSQL's reported execution time.

The 20 SQL statements were run three times each. Logout has no SQL statement and therefore has no plan. Write statements were measured inside transactions that were rolled back after every run.

Engine and fixture details are recorded in `../05_query_timings.md`. These are local synthetic-data results from PostgreSQL 18.7 via PGlite 0.5.17 (WebAssembly), not measurements from a native team/production server.
