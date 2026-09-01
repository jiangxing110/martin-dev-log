# task_2026 Remove Sale Mapping Middle Layer Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Remove the obsolete `ods_sale_am_transaction` mapping middle layer while keeping sale/AM aggregation pipelines backed directly by `dim_sale_account_relation_p`.

**Architecture:** Keep all sale output targets and their scope-delete behavior. Replace their mapping source with a database-side temporal relation query using direct-account priority and root-account fallback. Remove only the four obsolete mapping artifacts.

**Tech Stack:** Python, Flink SQL, PostgreSQL JDBC/ADBPG connectors, Markdown.

**Spec:** `design-docs/2026-09-01-task-2026-remove-sale-pipelines-design.md`

## Global Constraints

- Do not delete or alter online database tables.
- Do not remove sale output pipelines.
- Do not modify sale pipelines outside `task_2026/flink_reference`.
- Preserve existing file creation timestamps; update timestamps only on edited files.
- Generated CDC and batch filenames must be numbered continuously from `01_`.

### Task 1: Remove only the obsolete mapping target

**Files:**
- Modify: `task_2026/flink_reference/gen_all_jobs.py`
- Delete: `task_2026/flink_reference/cdc/01_ods_sale_am_transaction_v2-cdc-sql.sql`
- Delete: `task_2026/flink_reference/batch/01_ods_sale_am_transaction_v2-batch-sql.sql`
- Delete: `task_2026/flink_reference/table/ods_sale_am_transaction_ddl.sql`
- Delete: `task_2026/flink_reference/table/register_fn_ods_sale_am_transaction_cdc_delete_v2.sql`

- [x] Remove only `ods_sale_am_transaction` from `ODS_KEYS` and preserve `SALE_SET`.
- [x] Remove the four obsolete mapping artifacts.

### Task 2: Switch sale relation source to the dimension table

**Files:**
- Modify: sale CDC/batch SQL and sale delete functions under `task_2026/flink_reference`.

- [x] Replace `ods_sale_am_transaction_2026` joins with temporal `dim.dim_sale_account_relation_p` resolution.
- [x] Keep direct-account priority and root-account fallback.
- [x] Expand sale/am IDs with `UNION` so equal IDs produce one row.

### Task 3: Renumber and update documentation

**Files:**
- Modify: `task_2026/flink_reference/README.md`
- Modify: `task_2026/flink_reference/DEPLOY.md`
- Modify: generated CDC and batch filenames after the removed target.

- [x] Renumber CDC and batch files continuously after removing target 01.
- [x] Document that sale output remains active and reads the dimension table directly.
- [x] Document that existing online sale tables are not dropped.

### Task 4: Verify repository consistency

- [x] Search `task_2026/flink_reference` for stale `ods_sale_am_transaction` references.
- [x] Confirm `SALE_SET` and all sale output files remain.
- [x] Run `python3 -m py_compile task_2026/flink_reference/gen_all_jobs.py`.
- [x] Run `git diff --check`.
