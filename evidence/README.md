# Verification evidence

## SQL Server execution

Verified on **Microsoft SQL Server 2025 Standard Developer**, engine **17.0.1000.7**, x64, using a fresh isolated `MarketHubPortfolio` database on Windows.

| Script | Result |
|---|---|
| `00_create_database.sql` | Exit 0: fresh database created |
| `01_schema.sql` | Exit 0: schema, constraints, views, procedure and role created |
| `02_seed.sql` | Exit 0: fictional seed scenario loaded |
| `03_reports.sql` | Exit 0: all five reporting result sets returned |
| `04_tests.sql` | Exit 0: **ALL TESTS PASSED** |

The runtime suite passed **19 expected-error cases** plus seed-count/revenue/stock/subtype checks, historical-price preservation after repricing, a successful two-item sale with both stock decrements, and outer-transaction rollback. Full captured output is stored in `sql-server/`. Errors were not suppressed; stdout and stderr were captured.

Confirmed seed totals: **6 sales, 12 sale lines, 27 units, $262.00**. Store revenue: **Harbor Market $133.50; River Market $74.00; Meadow Market $54.50**. Every name and transaction in the dataset is fictional.

The scripts were run directly through `sqlcmd` using Windows integrated authentication. The local development server's self-signed certificate was trusted explicitly for that local test connection only; no server encryption or global security setting was changed. The PowerShell convenience wrapper and GitHub workflow were not used for this run.

## Source and model checks

`static-check.txt` records the dependency-free checks from `python tests/static_check.py`: nine tables, nine primary keys, nine foreign keys, normalized sale lines, historical-price column, transactional locking, subtype checks, and an independent arithmetic oracle. These checks supplement, rather than replace, the engine execution above.

## Scope of verification

- Concurrent stock contention has not been load-tested in multiple sessions; the procedure uses update and serializable-range locks.
- Performance has not been benchmarked on production-scale data.
- The manual GitHub workflow has not run. It requires an operator to review and accept Microsoft SQL Server Developer terms; pushing a commit does not start it.
- Tests preserve seeded rows; identity gaps left by failed/rolled-back test inserts are expected.
