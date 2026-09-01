# GLOBAL_ACCOUNT BZ CDC Trigger Scope Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Align the BZ CDC job's month trigger scope with its delete-function scope so unrelated tag updates do not cause duplicate daily inserts.

**Architecture:** Keep the existing monthly recomputation and daily `report_date` output. Restrict `v_param` to yesterday-updated `GLOBAL_ACCOUNT` and `BZ` month tags, matching the delete function's scope.

**Tech Stack:** Flink SQL, ADBPG JDBC/ADBPG connectors, Markdown documentation.

**Spec:** `design-docs/2026-09-01-global-account-bz-cdc-trigger-scope-design.md`

## Global Constraints

- Preserve the existing daily output logic.
- Do not change the sink from `insert` to `upsert`.
- Preserve the file's original `Created Time` and update `Updated Time` with seconds.

### Task 1: Restrict BZ CDC trigger scope

**Files:**
- Modify: `online/cdc/total_cost/finance/global_account/dwm_online_global_account_bz_cost-cdc-v2-sql.sql:4,104-113`

- [ ] **Step 1: Confirm the pre-change trigger predicate**

Verify that `v_param` currently filters only `delete_time` and the yesterday time window.

- [ ] **Step 2: Apply the minimal SQL change**

Add `t.product_line = 'GLOBAL_ACCOUNT'` and `t.provider = 'BZ'` to the `v_param` source query, and update the header timestamp.

- [ ] **Step 3: Verify the change**

Run `git diff --check` and inspect the diff to confirm only the trigger scope and update timestamp changed.

- [ ] **Step 4: Commit**

```bash
git add design-docs/2026-09-01-global-account-bz-cdc-trigger-scope-design.md plans/2026-09-01-global-account-bz-cdc-trigger-scope-plan.md online/cdc/total_cost/finance/global_account/dwm_online_global_account_bz_cost-cdc-v2-sql.sql
git commit -m "fix: align global account bz cdc trigger scope"
```
