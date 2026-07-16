# Quantum V2 Cost Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Implement BB/QI v2 cost scripts so DWM/DWS write v2 tables, preserve state-machine correctness, and prepare Total/Gross v2 integration.

**Architecture:** BB and QI keep separate channel folders under `flink/quantum-v2`. DWM stores current detailed facts and DWS recomputes affected ranges by deleting and reinserting from DWM. Total Cost and Gross Profit later read v2 DWS full-history tables and expose recent half-year materialized views.

**Tech Stack:** Alibaba Cloud Flink SQL, ADB PostgreSQL connector, PostgreSQL DDL, Markdown design docs.

## Global Constraints

- Do not write BB/QI v2 results into `dws_bb_card_finance_daily_p` or `dws_qi_card_finance_daily_p`.
- QI coefficients come from `ods_bi_month_tag`, not `ods_account_fee`.
- CDC scripts must delete affected DWS ranges before inserting recomputed rows.
- BB Active Card is maintained by an independent script as monthly distinct count and must not be daily-summed.
- BB main DWS flow must not calculate `active_card_count` or `active_card_account_fee`.
- DWM keeps source status and delete fields so `Pending -> Failed` and soft delete can be repaired by DWS recompute.

---

### Task 1: Add V2 Table DDL

**Files:**
- Create: `flink/quantum-v2/bb/table-scripts/dws_bb_card_finance_daily_v2_p.sql`
- Create: `flink/quantum-v2/qi/table-scripts/dwm_qi_card_transaction_detail_v2_p.sql`
- Create: `flink/quantum-v2/qi/table-scripts/dws_qi_card_finance_daily_v2_p.sql`

**Interfaces:**
- Produces BB sink table: `dws.dws_bb_card_finance_daily_v2_p`
- Produces QI DWM table: `dwm.dwm_qi_card_transaction_detail_v2_p`
- Produces QI DWS table: `dws.dws_qi_card_finance_daily_v2_p`

- [x] Create BB DWS v2 DDL with existing count/vol fields plus fee result fields.
- [x] Create QI DWM v2 DDL with source state tracking fields.
- [x] Create QI DWS v2 DDL with base/rate fields.
- [x] Verify no DDL references old sink table names except comments that explain migration.

### Task 2: Point BB DWS Scripts To V2 Sink

**Files:**
- Modify: `flink/quantum-v2/bb/batch/dws_online_bb_card_finance_daily_v2-batch-sql.sql`
- Modify: `flink/quantum-v2/bb/cdc/dws_online_bb_card_finance_daily_v2-cdc-sql.sql`

**Interfaces:**
- Consumes: `dwm.dwm_bb_card_transaction_detail_v2_p`
- Consumes: `dwm.dwm_bb_card_auth_detail_v2_p`
- Produces: `dws.dws_bb_card_finance_daily_v2_p`

- [x] Rename temporary sink to `sink_dws_bb_card_finance_daily_v2_p`.
- [x] Change ADBPG `tableName` to `dws_bb_card_finance_daily_v2_p`.
- [ ] Add fee amount fields derived from count/vol fields.
- [ ] Remove Active Card calculation from BB main DWS flow.

### Task 2.1: Add BB Active Card Count Independent Flow

**Files:**
- Create: `flink/quantum-v2/bb/batch/dws_online_bb_active_card_count_v2-batch-sql.sql`
- Create: `flink/quantum-v2/bb/cdc/dws_online_bb_active_card_count_v2-cdc-sql.sql`

**Interfaces:**
- Consumes: `dwm.dwm_bb_card_auth_detail_v2_p`
- Consumes: latest customer sale relation from `dim.dim_sale_account_relation_p`
- Produces: `dws.dws_bb_card_finance_daily_v2_p`

- [ ] Batch supports `start_time/end_time` and rewrites affected month-start active card rows.
- [ ] CDC defaults to current month daily maintenance.
- [ ] Delete old rows with `remarks = 'bb_active_card_count_v2'` before inserting recalculated rows.
- [ ] Write only `active_card_count`; keep `active_card_account_fee` and other cost fields as 0.
- [ ] Use latest valid sale/am relation for the customer, not auth-time historical relation.

### Task 3: Point QI DWM/DWS Scripts To V2 Sink

**Files:**
- Modify: `flink/quantum-v2/qi/batch/dwm_online_qi_card_transaction_detail_v2-batch-sql.sql`
- Modify: `flink/quantum-v2/qi/cdc/dwm_online_qi_card_transaction_detail_v2-cdc-sql.sql`
- Modify: `flink/quantum-v2/qi/batch/dws_online_qi_card_finance_daily_v2-batch-sql.sql`
- Modify: `flink/quantum-v2/qi/cdc/dws_online_qi_card_finance_daily_v2-cdc-sql.sql`

**Interfaces:**
- Consumes DWM source: `qbit_card_transaction`, `quantum_card_transaction_extend`, `dim_account`, `dim_sale_account_relation_p`
- Produces DWM: `dwm_qi_card_transaction_detail_v2_p`
- Produces DWS: `dws_qi_card_finance_daily_v2_p`

- [x] Change QI DWM sink table name to v2.
- [x] Add `source_update_time`, `source_delete_time`, `is_current_valid` in DWM select and sink schema.
- [x] Change QI DWS source table name to v2.
- [x] Change QI DWS sink table name to v2.
- [x] Rename misused `*_rate` expressions into `*_base_*`.
- [x] Add real rate fields from `ods_bi_month_tag`.
- [x] Keep QI DWS to base/rate fields; downstream calculates amount as `base * rate`.

### Task 4: Prepare Total/Gross V2

**Files:**
- Create: `flink/total_cost/table-scripts/dws_total_channel_cost_daily_v2_p.sql`
- Create: `flink/total_cost/table-scripts/vw_total_channel_cost_daily_v2.sql`
- Create: `flink/total_cost/table-scripts/mv_total_channel_cost_daily_recent_v2.sql`
- Create: `flink/profit/table-scripts/dws_gross_profit_daily_v2_p.sql`
- Create: `flink/profit/table-scripts/vw_gross_profit_daily_v2.sql`
- Create: `flink/profit/table-scripts/mv_gross_profit_daily_recent_v2.sql`

**Interfaces:**
- Consumes: BB/QI v2 DWS, SL current DWS, finance channel cost.
- Produces: v2 total cost and gross profit facts plus recent half-year materialized views.

- [ ] Add DDL/view scripts.
- [ ] Leave existing production scripts untouched until BB/QI v2 backfill validates.

### Task 5: Verification

**Files:**
- Read-only verification across modified SQL files.

- [x] Search for old sink table names in v2 batch/cdc scripts.
- [x] Search QI scripts for `0.07` VRM and replace with `0.09` if still present.
- [x] Search for `ods_account_fee` in QI v2 path and ensure no references remain.
- [x] Run SQL text sanity checks for balanced `CREATE TEMPORARY TABLE` sink columns vs insert select order where practical.
