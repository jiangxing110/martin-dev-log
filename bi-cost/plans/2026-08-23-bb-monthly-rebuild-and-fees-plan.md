# BB Monthly Rebuild and Fee Allocation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Convert BB historical/current rebuild to a parameterless date window from 2026-01-01 through `CURRENT_DATE`, use monthly fee/rate logic, and add the QI net-consumption field without changing special-row ownership.

**Architecture:** Reuse the existing BB batch and monthly-cdc SQL instead of introducing a second calculation model. The parameterless rebuild uses the half-open range `[DATE '2026-01-01', CURRENT_DATE)`; monthly aggregation uses `DATE_TRUNC('month', report_date)`, so on 2026-08-23 it includes January–July full months and August 1–22. BB normal rows are rebuilt before the existing active-card and fixed-fee scripts. A separate runner is only needed when physical one-month-at-a-time submission is required; the SQL itself must not depend on user-provided dates.

**Tech Stack:** Flink SQL 1.20, PostgreSQL/ADB PG JDBC, existing `dws`/`dwm` tables, shell runner only if the deployment environment supports submitting multiple Flink SQL jobs.

**Spec:** `design-docs/2026-08-23-bb-monthly-rebuild-and-volume-fee-design.md`

## Global Constraints

- Use half-open time windows: `report_date >= start` and `report_date < end`.
- The effective rebuild range starts at `DATE '2026-01-01'` and ends at `CURRENT_DATE` midnight.
- `ACTIVE_CARD_ACCOUNT_FEE` and `CHANNEL_FIXED_FEE` rows are excluded from normal-row deletion and volume-fee allocation.
- Volume Fee is calculated once per BB month using the 5m/10m tier formula, then allocated by ordinary-row net consumption share.
- Existing daily CDC remains parameterless and must not be changed into a full-history scan without an explicit deployment decision.
- Preserve unrelated dirty worktree changes and do not stage them.

---

### Task 1: Map existing monthly/batch interfaces and lock the source-of-truth fields

**Files:**
- Read: `flink/quantum-v2/bb/batch/dws_online_bb_card_finance_daily_v2-batch-sql.sql`
- Read: `flink/quantum-v2/bb/monthly-cdc/dws_online_bb_card_finance_daily_v2-monthly-cdc-v2-sql.sql`
- Read: `flink/quantum-v2/bb/monthly-cdc/dws_online_bb_active_card_count_v2-monthly-cdc-v2-sql.sql`
- Read: `flink/quantum-v2/bb/monthly-cdc/dws_online_bb_channel_fixed_fee_v2-monthly-cdc-v2-sql.sql`
- Read: `flink/quantum-v2/bb/table-scripts/dws_bb_card_finance_daily_v2_p.sql`
- Read: `flink/quantum-v2/qi/table-scripts/dws_qi_card_finance_daily_v2_p.sql`

**Interfaces:**
- Produces the exact existing target columns, special-row values, `ods_bi_month_tag` tag names, and batch parameter conventions needed by later tasks.

- [ ] Confirm BB target already contains `total_net_amount`, `volume_fee_cost`, `cashback_rate`, and `cashback_income`.
- [ ] Confirm ordinary-row marker is `NORMAL` and special-row markers are `ACTIVE_CARD_ACCOUNT_FEE` and `CHANNEL_FIXED_FEE`.
- [ ] Confirm QI net-consumption field should be named `total_net_amount` for cross-channel consistency, unless the existing QI table contract requires a distinct name.
- [ ] Record the actual BB cashback tag in `ods_bi_month_tag`; do not invent a tag name in SQL.
- [ ] Record the existing active-card/fixed-fee monthly scripts and their delete-function contracts.

### Task 2: Add the parameterless BB historical/current rebuild SQL

**Files:**
- Create: `flink/quantum-v2/bb/rebuild/dws_online_bb_card_finance_daily_v2-rebuild-sql.sql`
- Modify: `flink/quantum-v2/bb/table-scripts/register_fn_quantum_bb_monthly_cdc_delete_v2.sql`

**Interfaces:**
- Consumes: `dwm.dwm_bb_card_transaction_detail_v2_p`, `dwm.dwm_bb_card_auth_detail_v2_p`, `ods.ods_bi_month_tag`, and the BB DWS target.
- Produces: idempotent ordinary BB rows for `[DATE '2026-01-01', CURRENT_DATE)`.

- [ ] Define the internal range once in a one-row source/view:

```sql
SELECT
    DATE '2026-01-01' AS rebuild_start,
    CURRENT_DATE::date AS rebuild_end
```

- [ ] Filter transaction source rows using all three report-date candidates (`transaction_time`, `original_completion_time`, `settlement_post_date`) against the same half-open range; filter auth by `auth_time`.
- [ ] Remove `changed_keys` and recent-day `update_time/delete_time` predicates from this historical/current rebuild path.
- [ ] Make the target-delete function clear only ordinary rows in `[DATE '2026-01-01', CURRENT_DATE)`; preserve the two special-row types.
- [ ] Keep the delete function as a JDBC source joined into the sink query so deletion executes before rows are allowed into the sink, matching the existing repository pattern.
- [ ] Keep the SQL parameterless: no `${start_time}` or `${end_time}` placeholders in this rebuild script.
- [ ] Add comments that `CURRENT_DATE` excludes the current date, so on 2026-08-23 the last included date is 2026-08-22.

### Task 3: Implement monthly cashback and volume-fee allocation in BB rebuild

**Files:**
- Modify: `flink/quantum-v2/bb/rebuild/dws_online_bb_card_finance_daily_v2-rebuild-sql.sql`
- Modify: `flink/quantum-v2/bb/monthly-cdc/dws_online_bb_card_finance_daily_v2-monthly-cdc-v2-sql.sql`
- Modify: `flink/quantum-v2/bb/batch/dws_online_bb_card_finance_daily_v2-batch-sql.sql`

**Interfaces:**
- Consumes: ordinary BB daily rows with `total_net_amount` and monthly `ods_bi_month_tag` values.
- Produces: `cashback_rate`, `cashback_income`, and `volume_fee_cost` at ordinary daily customer row grain.

- [ ] Add a monthly ordinary-row aggregate excluding special rows:

```sql
DATE_TRUNC('month', report_date)::date AS report_month,
SUM(COALESCE(total_net_amount, 0)) AS month_total_net_amount
```

- [ ] Calculate one `month_volume_fee_cost` per month with the exact tier formula:

```sql
CASE
    WHEN month_total_net_amount <= 0 THEN 0
    WHEN month_total_net_amount <= 5000000
        THEN month_total_net_amount * 0.0055
    WHEN month_total_net_amount <= 10000000
        THEN 5000000 * 0.0055
           + (month_total_net_amount - 5000000) * 0.0045
    ELSE 5000000 * 0.0055
       + 5000000 * 0.0045
       + (month_total_net_amount - 10000000) * 0.004
END
```

- [ ] Allocate each ordinary row with `total_net_amount / month_total_net_amount * month_volume_fee_cost`, guarding zero denominators.
- [ ] Join the monthly BB cashback tag from `source_bi_month_tag`/`ods_bi_month_tag` by product line, tag, and report month.
- [ ] Replace the hardcoded BB cashback rate `0.02057316` with the matched monthly rate.
- [ ] Preserve existing `bb_rebate_base_amt` and compute `cashback_income = bb_rebate_base_amt * cashback_rate`.
- [ ] Do not calculate volume fee on `ACTIVE_CARD_ACCOUNT_FEE` or `CHANNEL_FIXED_FEE` rows.
- [ ] Add a deterministic monthly rounding-tail rule so the sum of ordinary-row `volume_fee_cost` equals the monthly tier amount to the target precision.

### Task 4: Align active-card and fixed-fee execution after BB rebuild

**Files:**
- Modify: `flink/quantum-v2/bb/monthly-cdc/dws_online_bb_active_card_count_v2-monthly-cdc-v2-sql.sql`
- Modify: `flink/quantum-v2/bb/monthly-cdc/dws_online_bb_channel_fixed_fee_v2-monthly-cdc-v2-sql.sql`
- Read: `flink/quantum-v2/bb/table-scripts/register_fn_quantum_bb_monthly_cdc_delete_v2.sql`

**Interfaces:**
- Consumes: completed BB ordinary rows for the same `[DATE '2026-01-01', CURRENT_DATE)` range.
- Produces: active-card and fixed-fee special rows without changing ordinary-row volume-fee totals.

- [ ] Ensure the active-card script runs only after ordinary BB rebuild completion.
- [ ] Ensure the fixed-fee script runs after ordinary BB rebuild and active-card completion, using the ordinary-row `total_net_amount` as its allocation base.
- [ ] Verify each delete function clears only its own special-row type and does not clear ordinary rows.
- [ ] If the existing monthly scripts remain “previous month only,” create a parameterless historical/current variant using `CURRENT_DATE` and the common 2026-01-01 start.

### Task 5: Add QI net-consumption field and populate it

**Files:**
- Modify: `flink/quantum-v2/qi/table-scripts/dws_qi_card_finance_daily_v2_p.sql`
- Modify: `flink/quantum-v2/qi/batch/dws_online_qi_card_finance_daily_v2-batch-sql.sql`
- Modify: `flink/quantum-v2/qi/monthly-cdc/dws_online_qi_card_finance_daily_v2-monthly-cdc-v2-sql.sql`

**Interfaces:**
- Consumes: existing QI transaction aggregation.
- Produces: one daily QI net-consumption field with the same sign and inclusion rules used by the QI net-consumption calculation.

- [ ] Add the field to the physical QI DWS table and its column comment.
- [ ] Add the field to batch/monthly-cdc temporary sink schemas and `INSERT` column lists in the same ordinal position.
- [ ] Populate it from the existing QI consumption/reversal net amount expression rather than introducing a second transaction filter.
- [ ] Verify existing QI cost/rebate base fields remain unchanged.

### Task 6: Add verification SQL and deployment notes

**Files:**
- Create: `flink/quantum-v2/bb/rebuild/check_bb_monthly_rebuild.sql`
- Modify: `design-docs/2026-08-23-bb-monthly-rebuild-and-volume-fee-design.md`
- Create: `changelogs/2026-08-23-bb-monthly-rebuild-and-fees.md`

**Interfaces:**
- Consumes: rebuilt BB/QI DWS rows and `ods_bi_month_tag`.
- Produces: reproducible checks for date coverage, ordinary/special-row separation, monthly volume-fee reconciliation, cashback-rate completeness, and QI net-consumption totals.

- [ ] Check the effective range is `[2026-01-01, CURRENT_DATE)` and that no 2026-08-23 rows are included when run on 2026-08-23.
- [ ] Check monthly `SUM(total_net_amount)` and recompute the tier total.
- [ ] Check ordinary-row `SUM(volume_fee_cost)` equals the tier total to the target precision.
- [ ] Check special rows do not enter the volume-fee denominator.
- [ ] Check every processed month has a non-null BB cashback rate or an explicit controlled zero.
- [ ] Check QI net consumption against the existing source aggregation.
- [ ] Document execution order: BB rebuild → active card → fixed fee → checks.
