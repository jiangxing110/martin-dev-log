# Qbit Card Transaction CDC Temporal Join Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task.

**Goal:** Keep the transaction table as the only wide-table CDC driver, and use JDBC Lookup for `qbitCardGroup` so the wide table does not create a second PG replication slot.

**Architecture:** `qbit_card_transaction` remains the only business-event CDC source in the wide-table job. `qbitCard`, account, and accountExtend are read from ADB ODS; `qbitCardGroup` is read directly from ADB PG `public."qbitCardGroup"` through JDBC Lookup. The existing wide-table snapshot lookup retains frozen dimension fields when a transaction is updated.

**Tech Stack:** Flink SQL, PostgreSQL CDC, JDBC Lookup, ADBPG sink.

**Spec:** Existing qbit wide-table design and CDC SQL comments.

## Global Constraints

- Do not create views or mirror dimension tables.
- Do not use a custom Connector JAR.
- Dimension changes must not directly update the wide table.
- Transaction UPDATE must replace transaction columns only and preserve dimension columns.
- Use PG Test credentials for the transaction CDC source and ADB PG credentials for dimensions and sink.

### Task 1: Replace camelCase dimension JDBC tables with ADB CDC tables

**Files:**
- Modify: `flink/quantum-v2/qbit-card-transaction-widetable/cdc/dwm_online_qbit_card_transaction_widetable-cdc-sql.sql`

- [ ] Use JDBC Lookup against `ods.ods_qbit_card`, `ods.ods_account`, and `ods.ods_account_extend`.
- [x] Replace the wide-table `qbitCardGroup` PostgreSQL CDC source with JDBC Lookup against `public."qbitCardGroup"`.
- [ ] Keep `api_account_relation` and `dim_sale_account_relation_p` as JDBC lookups because their fields are already snake_case and the sales relation is a one-to-many time-line keyed by relation record id.
- [ ] Keep `lookup_wide_snapshot` as JDBC Lookup against `dwm.dwm_quantum_card_transaction_p`.

### Task 2: Preserve transaction update semantics

**Files:**
- Modify: `flink/quantum-v2/qbit-card-transaction-widetable/cdc/dwm_online_qbit_card_transaction_widetable-cdc-sql.sql`

- [ ] Keep `CASE WHEN hist.id IS NOT NULL THEN hist.<dimension> ELSE <current CDC dimension> END` for every dimension column.
- [ ] Keep all transaction columns sourced directly from `source_qbit_card_transaction`.
- [ ] Ensure dimension CDC sources are not used as INSERT drivers and do not create independent sink statements.

### Task 3: Validate SQL and deployment prerequisites

**Files:**
- Modify: `flink/quantum-v2/qbit-card-transaction-widetable/cdc/dwm_online_qbit_card_transaction_widetable-cdc-sql.sql`

- [ ] Validate table aliases, temporal join syntax, primary keys, and source/sink column counts locally.
- [ ] Search the final script for mirror table names and unintended JDBC Lookup definitions.
- [ ] Document that PG Test replication privilege/publication is required only by the ODS group job; the wide-table job now requires one transaction CDC slot and ADB JDBC access.
