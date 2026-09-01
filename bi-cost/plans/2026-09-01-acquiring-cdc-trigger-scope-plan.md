# ACQUIRING CDC Trigger Scope Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Align the ACQUIRING CDC job's month trigger scope with its OD/WP delete-function scope.

**Architecture:** Keep monthly recomputation and daily `report_date` output. Restrict trigger rows to `ACQUIRING` with provider `OD` or `WP`.

**Tech Stack:** Flink SQL, ADBPG JDBC/ADBPG connectors, Markdown documentation.

**Spec:** `design-docs/2026-09-01-acquiring-cdc-trigger-scope-design.md`

## Global Constraints

- Preserve the existing daily output logic.
- Do not change the sink from `insert` to `upsert`.
- Preserve `Created Time` and update `Updated Time` with seconds.

### Task 1: Restrict ACQUIRING CDC trigger scope

**Files:**
- Modify: `online/cdc/total_cost/finance/acquiring/dwm_online_acquiring_cost-cdc-v2-sql.sql:4,105-107`

- [ ] **Step 1: Add product and provider scope**

Add `t.product_line = 'ACQUIRING'` and `t.provider IN ('OD', 'WP')` to the `v_param` source query.

- [ ] **Step 2: Verify the SQL diff**

Run `git diff --check` and inspect the diff to confirm only trigger scope and update timestamp changed.

- [ ] **Step 3: Commit**

```bash
git add design-docs/2026-09-01-acquiring-cdc-trigger-scope-design.md plans/2026-09-01-acquiring-cdc-trigger-scope-plan.md online/cdc/total_cost/finance/acquiring/dwm_online_acquiring_cost-cdc-v2-sql.sql
git commit -m "fix: align acquiring cdc trigger scope"
```
