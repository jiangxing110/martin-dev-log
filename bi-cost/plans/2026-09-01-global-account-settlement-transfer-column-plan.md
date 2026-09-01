# GLOBAL_ACCOUNT Settlement transfer Column Mapping Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make the settlement CDC JDBC source use the physical camelCase columns of `public.transfer`.

**Architecture:** Keep the Flink source schema in snake_case and alias the physical transfer columns in the JDBC query. Preserve the existing trigger and daily allocation logic.

**Tech Stack:** Flink SQL, PostgreSQL/ADBPG JDBC connector, Markdown documentation.

**Spec:** `design-docs/2026-09-01-global-account-settlement-transfer-column-design.md`

## Global Constraints

- Preserve the existing daily `report_date` output.
- Preserve the existing `GLOBAL_ACCOUNT` and NULL-provider trigger scope.
- Do not change the sink write mode.

### Task 1: Correct transfer source column mapping

**Files:**
- Modify: `online/cdc/total_cost/finance/global_account/dwm_online_global_account_settlement_cost-cdc-v2-sql.sql:143`

- [ ] **Step 1: Replace snake_case physical columns with quoted camelCase columns and aliases**

Map the physical `public.transfer` columns to the existing Flink source fields.

- [ ] **Step 2: Run static validation**

Run `git diff --check` and inspect the source query and trigger predicate.

- [ ] **Step 3: Commit**

```bash
git add design-docs/2026-09-01-global-account-settlement-transfer-column-design.md plans/2026-09-01-global-account-settlement-transfer-column-plan.md online/cdc/total_cost/finance/global_account/dwm_online_global_account_settlement_cost-cdc-v2-sql.sql
git commit -m "fix: map settlement transfer source columns"
```
