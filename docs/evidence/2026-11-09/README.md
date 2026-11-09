# Supplier import evidence

This package supports the README's validation, duplicate-confirmation and reconciliation claims. All suppliers, products and imported values are synthetic.

## Recorded snapshot

- Measured backend revision: [`8e5528ab52fc768a97797d1458ed56e3a928b179`](https://github.com/vietdungnguyen2005/v-market-commerce-platform/commit/8e5528ab52fc768a97797d1458ed56e3a928b179).
- Three runs recorded on 6 November 2026, 16:58–17:00 UTC; published here on 9 November without relabelling the original measurement date.
- Windows 11, Java 21, Spring application context/MockMvc, disposable Testcontainers PostgreSQL 17.6 and Redis 8.2.
- [Raw run summary and per-run metrics](import-results.json), including input SHA-256, seed, source SHA, selected methods and timestamps.

## Method and results

Each run executes four existing integration scenarios against a fresh fixture. The seeded import scenario uses **220 rows: 200 valid and 20 invalid**, seed `20261023`, and repeats confirmation of the same import.

| Claim | Observation in each of the three runs | Boundary |
|---|---|---|
| Reject invalid input before application | 200 accepted rows; 20 rejected rows | Only the defined synthetic validation cases. |
| Duplicate confirmation does not reapply stock | One durable job and 200 inventory movements after repeated confirmation | Exact dataset/import identity; not arbitrary semantically equivalent files. |
| Applied inventory can be reconciled | Zero mismatches; zero unverified stock rows | Comparison with the fixture's recorded baseline, not real inventory counts. |

The other three scenarios check preview without business writes, concurrent confirmations sharing one identity/movement, and database-failure rollback followed by explicit safe restart. They are correctness assertions, not measured staff-time savings.

The JSON retains timing observations: preview through import took **2,222–2,519 ms** and through reconciliation **3,136–3,481 ms**. These are three local elapsed-time samples, excluding application/container startup. They are **not a before/after improvement**, production throughput, API request rate, p95 latency or an SLA. The row-rate field is derived from accepted rows over that local workflow interval; it is not HTTP requests per second.

## Reproduce

Requirements: PowerShell 7+, Java 21 and a working Docker engine; network access for Maven/container downloads on first use. No supplier account or production credentials are required.

From the repository root:

```powershell
pwsh -File ./tools/evidence/run-import.ps1 -Runs 3
```

The [runner](../../../tools/evidence/run-import.ps1) selects these methods in the unchanged [VMarketApplicationTest](../../../backend/src/test/java/dev/vmarket/VMarketApplicationTest.java):

1. `seededSupplierOnboardingBenchmarkProducesMeasuredImportAndReconciliationEvidence`
2. `supplierPreviewMapsAndQuarantinesRowsWithoutAnyBusinessWrites`
3. `concurrentSupplierConfirmationsShareOneDurableIdentityAndOneMovement`
4. `supplierDatabaseFailureRollsBackChunkAndUsesOnlyTheExistingSafeRestart`

Generated logs, benchmark copies and the timestamped summary stay under ignored `backend/target/portfolio-evidence/import/`; Maven also writes its normal ignored `backend/target/` reports. The runner checks the selected methods, rejects skipped/failed tests and stale benchmark output, verifies business invariants, and records source SHA and fixture hash. It refuses tracked backend changes and checks that the snapshot did not change during execution. New runs do not overwrite this historical summary.

## Provenance and limits

The recorded summary was extracted from three previously executed isolated runs. Its values and original timestamps are preserved, not regenerated or estimated. The published runner adapts that measurement script to repository-relative paths; a one-run smoke execution was also performed before publication. Raw machine logs and job-application preparation documents are excluded.

This is a selected four-scenario exercise, not the complete backend suite or a browser/load test. It does not prove supplier adoption, sales, cost savings or performance improvements. The importer currently supports existing catalog items and at most 1,000 data rows per file; this dataset does not demonstrate larger imports. The separate [historical process-recovery exercise](../../fde/impact-evaluation.md) has its own conditions and is not part of these timings.
