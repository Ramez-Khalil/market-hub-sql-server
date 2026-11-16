# Verification evidence

`static-check.txt` records the dependency-free source review (`python tests/static_check.py`).
It is **not** proof that SQL Server compiled or executed the scripts.

The runtime suite is `sql/04_tests.sql`. It contains nineteen expected-error cases and
positive checks of seed totals, subtype partitioning, historical pricing, transactional
sales, stock changes and rollback. A successful run ends with `ALL TESTS PASSED`.

SQL Server execution has **not yet been verified** in this repository. No runtime logs
are included or invented. After execution, preserve complete SQL output and engine
version. The GitHub workflow is manual and requires the operator to review and accept
Microsoft's SQL Server Developer license. Publishing a commit does not start it.

The arithmetic oracle is independently computed from six synthetic baskets:
$37.00 + $43.00 + $25.50 + $74.00 + $29.00 + $53.50 = **$262.00**, **27 units**.
These are example-data expectations, not business performance.

## Remaining runtime coverage

- Execute all five SQL scripts on SQL Server 2022 or newer.
- Run concurrent stock contention in two sessions; locking is implemented, not load-tested.
- Inspect execution plans with production-scale data before performance claims.
