# Total Channel Cost V4 BB V2 Implementation Plan

Created Time: 2026-07-31 16:11:06
Updated Time: 2026-07-31 16:13:12

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 新增总渠道成本批处理 V4 脚本，使 BB 成本统计对齐 BB v2 明细校验 SQL。

**Architecture:** 复制 V3 总成本脚本生成 V4。V4 只调整 BB source table、BB 月度 Volume Fee 分摊视图和 BB 成本表达式，其他产品线和 sink 维持 V3 行为。

**Tech Stack:** Alibaba Cloud Flink SQL, ADB PostgreSQL JDBC/ADBPG connector, Markdown.

## Global Constraints

- 不覆盖 V3 文件。
- BB 来源必须使用 `dws.dws_bb_card_finance_daily_v2_p`。
- QI、SL、`dwm_finance_channel_cost_p` 逻辑保持 V3 不变。
- 输出仍写入 `dws.dws_total_channel_cost_daily_v2_p`。

---

### Task 1: 生成 V4 SQL

**Files:**
- Create: `flink/total_cost/dws_online_total_channel_cost_daily_v4-batch-sql.sql`
- Create: `design-docs/2026-07-total-channel-cost-v4-bb-v2.md`
- Create: `plans/2026-07-total-channel-cost-v4-bb-v2.md`

**Interfaces:**
- Consumes: `dws.dws_bb_card_finance_daily_v2_p`
- Consumes: `dws.dws_qi_card_finance_daily_v2_p`
- Consumes: `dws.dws_sl_card_finance_daily_p`
- Consumes: `dwm.dwm_finance_channel_cost_p`
- Produces: `dws.dws_total_channel_cost_daily_v2_p`

- [x] 复制 V3 SQL 为 V4 文件。
- [x] 将 BB source table 改为 `source_dws_bb_card_finance_daily_v2_p`。
- [x] 在 BB source schema 中补齐 `ac_m_int_decline_count`、`ac_v_int_decline_count`、`ac_dom_decline_count`、`total_net_amount`。
- [x] 增加 BB 月度 `total_net_amount` 聚合视图。
- [x] 增加 BB 成本视图，按月阶梯分摊 Volume Fee Cost。
- [x] 将总成本来源视图中的 BB 分支替换为 BB 成本视图。
- [x] 执行文本校验并查看 diff。
