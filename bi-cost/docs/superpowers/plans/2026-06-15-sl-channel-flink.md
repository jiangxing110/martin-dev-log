# SL Channel Flink Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Deliver the SL channel Flink skeleton under `flink/quantum/sl` with stream, DWM, DWS, and monthly fixed-fee rebuild scripts aligned to the approved cost allocation rules.

**Architecture:** Stream SQL handles CDC sync only. Batch SQL splits responsibilities into transaction-level DWM enrichment, day-level DWS aggregation, and next-month fixed-fee reallocation from `bi_month_tag`. All artifacts live under one folder so the job chain is easy to hand off and schedule.

**Tech Stack:** Flink SQL, PostgreSQL CDC, JDBC sinks, current bi-cost naming conventions.

---

### Task 1: Create the SL folder entrypoint

**Files:**
- Create: `flink/quantum/sl/README.md`

- [ ] **Step 1: Write the folder index and execution order**
Create `flink/quantum/sl/README.md` with the four-file index and execution order.

- [ ] **Step 2: Verify the entrypoint exists**

Run: `sed -n '1,120p' /Users/martinjiang/martin-dev-log/bi-cost/flink/quantum/sl/README.md`
Expected: file prints the folder index and file list.

### Task 2: Add stream ODS/DWD SQL

**Files:**
- Create: `flink/quantum/sl/00_stream_ods_dwd.sql`

- [ ] **Step 1: Write CDC source and JDBC sink scaffolding**
Create `flink/quantum/sl/00_stream_ods_dwd.sql` with `source_sl_transaction`, `source_sales_account_relation`, `source_bi_month_tag`, `sink_ods_sl_transaction`, and `sink_dwd_sl_transaction_detail_p`.

- [ ] **Step 2: Verify the file contains the ODS and DWD insert statements**

Run: `sed -n '1,260p' /Users/martinjiang/martin-dev-log/bi-cost/flink/quantum/sl/00_stream_ods_dwd.sql`
Expected: source tables, ODS sink, and DWD sink are present.

### Task 3: Add DWM enrichment SQL

**Files:**
- Create: `flink/quantum/sl/10_batch_dwm.sql`

- [ ] **Step 1: Write DWM enrichment with transaction-time sale/am lookup**
Create `flink/quantum/sl/10_batch_dwm.sql` with a lateral join from `source_dwd_sl_transaction_detail_p` to `source_sales_account_relation` using `r.create_time <= t.create_time`.

- [ ] **Step 2: Verify the DWM file contains the lateral lookup join**

Run: `sed -n '1,260p' /Users/martinjiang/martin-dev-log/bi-cost/flink/quantum/sl/10_batch_dwm.sql`
Expected: sale_id and am_id are assigned from transaction-time-aware relation lookup.

### Task 4: Add DWS aggregation SQL

**Files:**
- Create: `flink/quantum/sl/20_batch_dws.sql`

- [ ] **Step 1: Write day-level aggregation keyed by account/report_date/sale_id/am_id**
Create `flink/quantum/sl/20_batch_dws.sql` with `v_dws_sl_daily_base` grouped by `report_date`, `account_id`, `sale_id`, and `am_id`.

- [ ] **Step 2: Verify DWS includes cost_fixed_fee**

Run: `sed -n '1,260p' /Users/martinjiang/martin-dev-log/bi-cost/flink/quantum/sl/20_batch_dws.sql`
Expected: DWS sink includes rebate_base, rebate_amt, and cost_fixed_fee.

### Task 5: Add monthly fixed-fee rebuild SQL

**Files:**
- Create: `flink/quantum/sl/30_batch_fixed_fee_rebuild.sql`

- [ ] **Step 1: Write the next-month allocation query using bi_month_tag**
Create `flink/quantum/sl/30_batch_fixed_fee_rebuild.sql` with `v_sl_month_fixed_fee`, `v_sl_month_base`, and `v_sl_fixed_fee_allocation`.

- [ ] **Step 2: Verify the allocation is proportional to monthly rebate base**

Run: `sed -n '1,260p' /Users/martinjiang/martin-dev-log/bi-cost/flink/quantum/sl/30_batch_fixed_fee_rebuild.sql`
Expected: fixed fee is distributed by monthly rebate_base ratio and written back via upsert.
