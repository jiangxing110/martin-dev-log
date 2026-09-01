# finance CDC Trigger Scope Audit Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Make all finance v2 CDC jobs derive recomputation months only from their own cost scope.

**Architecture:** Preserve monthly recomputation and daily output. Add provider/product filters to explicit `v_param` queries and to embedded JDBC month-detection subqueries.

**Tech Stack:** Flink SQL, ADBPG JDBC/ADBPG connectors, Markdown documentation.

**Spec:** `design-docs/2026-09-01-finance-cdc-trigger-scope-audit-design.md`

## Global Constraints

- Preserve the existing daily output logic.
- Keep `writeMode = 'insert'`.
- Preserve each file's `Created Time` and update `Updated Time` with seconds.

### Task 1: Apply scope filters to all finance v2 jobs

**Files:**
- Modify: `online/cdc/total_cost/finance/**/*.sql` for the 13 v2 finance CDC jobs.

- [ ] **Step 1: Apply scope predicates**

Use each job's declared product line and provider set; use `IS NULL` for settlement's NULL provider and apply the same predicates inside embedded month-detection subqueries.

- [ ] **Step 2: Verify all scopes and sink modes**

Check all 13 files for matching trigger predicates and confirm every sink still contains `'writeMode' = 'insert'`.

- [ ] **Step 3: Run formatting validation**

Run `git diff --check`.

- [ ] **Step 4: Commit**

```bash
git add design-docs/2026-09-01-finance-cdc-trigger-scope-audit-design.md plans/2026-09-01-finance-cdc-trigger-scope-audit-plan.md online/cdc/total_cost/finance
git commit -m "fix: align finance cdc trigger scopes"
```
