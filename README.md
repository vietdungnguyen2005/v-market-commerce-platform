# V-Market — Commerce & Supplier Data

An online store with a reviewable supplier-import workflow: validate a file, approve its changes, process it and check the resulting inventory.

[Live storefront](https://v-market.vmarket-vietdung2005.workers.dev/) · [Operations console](https://v-market.vmarket-vietdung2005.workers.dev/ops) · [Recorded results](docs/evidence/2026-11-09/README.md) · [Run locally](docs/developer-guide.md)

## Problem & Solution

**Problem:** Supplier files can contain invalid stock values, unfamiliar columns and Japanese character encodings. Blind imports can apply bad data; repeated submissions or interrupted processing can leave operators unsure whether inventory was updated twice.

**Solution:** V-Market provides a **Preview → Confirm → Import → Reconcile** workflow. Operators inspect mapped records and row-level errors before approving changes, then check progress and compare results with recorded inventory movements. Catalog browsing, checkout and private order tracking complete the application.

Suppliers and datasets are fictional; this is not a live retailer or a real supplier integration.

## Engineering

- **Feature integration:** Storefront and operator interfaces connect to Java APIs for checkout, file review, import status and reconciliation.
- **Data validation:** Strict UTF-8/CP932 decoding and versioned mappings produce validated records. Preview does not apply stock changes.
- **Recoverable processing:** PostgreSQL transactions, file identity and committed import chunks protect against duplicate application and support explicit restart after failures.
- **Consistency:** Checkout uses server-owned prices and stock locks. Imports check current product/stock versions; reconciliation reports differences rather than silently repairing them.

**Stack:** Java 21, Spring Boot, Spring Batch, PostgreSQL, Redis, TypeScript, Next.js/React, Docker and GitHub Actions.

## Impact & Results

**Three isolated local runs with the same synthetic 220-row supplier file and real disposable PostgreSQL/Redis.**

| Problem addressed | Verified result in every run | Practical value |
|---|---|---|
| Mixed-quality input | **200 valid records accepted; 20 invalid rows rejected** | Bad values are identified before application. |
| Repeated confirmation | **One import job and 200 inventory movements**, with no extra movements | Retry does not apply the stock changes twice. |
| Checking applied data | **Zero reconciliation mismatches and zero unverified stock rows** | Effects can be checked against the recorded baseline. |

Related local scenarios verified read-only preview, concurrent confirmation and rollback followed by an explicit import restart after an injected database failure. These are results on the defined dataset—not production throughput, an optimization percentage or staff-time savings.

[Raw results, methodology and reproduction](docs/evidence/2026-11-09/README.md) preserve the measured revision. A separate [historical process-recovery exercise](docs/fde/impact-evaluation.md) records its own fault-injection conditions.

## Explore the project

- [Supplier preview screenshot](docs/fde/evidence/supplier-preview-desktop.png) · [Demo walkthrough](docs/fde/customer-demo-script.md)
- [Architecture](docs/ARCHITECTURE.md) · [Integration contract](docs/fde/integration-contract.md)
- [Acceptance criteria](docs/fde/acceptance-criteria.md) · [Operator handoff](docs/fde/operator-handoff.md)

## Scope & Demo Limits

The importer updates existing catalog items and accepts at most **1,000 data rows per file**. Duplicate-file protection covers original bytes and verified import identity, not every reformatted version of the same business event. Reconciliation is not automatic repair.

The free-hosted backend may cold-start; administration requires a provisioned account. No credentials or real customer data are published. Local measurements do not establish real supplier adoption, revenue or an always-on service guarantee.

Former repository name: Project2; the live-demo URL is unchanged.
