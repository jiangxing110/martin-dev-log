# BB DWS 单一写入者（CDC）架构设计

- 日期：2026-08-18
- 状态：已批准（用户确认方案 A）
- 前置：`plans/2026-08-18-bb-dws-daily-granularity-refactor.md`（逐日化改造，已完成）

## 1. 背景与问题

dws_bb_card_finance_daily_v2_p 由 DWM（transaction + auth 两张明细）构建，此前存在：

1. **双写者并存**：daily CDC（口径A，remarks=`bb_v2_cdc`）与 monthly batch（口径B，`bb_v2_batch_q3_refund_net_20260721`）同时写 DWS，指标定义不一致（16 个黑名单 settlement、auth 1010 排除、refund 条件），同一 (月,账户,sale,am) key 上互相覆盖/并存 → **7 月成本一夜 +26,404 的直接原因**（batch 漏 15 账户 + CDC 补写并存）。
2. **触发不可靠**：DWS CDC 靠「DWM 行 update_time/delete_time 近 24h 变化」触发，而 transaction DWM 写入的 update_time = 源交易 update_time（7 月交易 = 7 月），DWM 每日按事件窗口重写行时 update_time 不变 → **迟到 settlement 进了 DWM 却可能永远不触发 DWS 重算**。
3. **月初承载**：主链路 report_date=月初，已完结月份被整月重算、无法按天回溯（已通过逐日化解决）。
4. **幂等缺失**：DWS CDC 只 upsert 不删除，sale/am 归属变更会残留旧行 → 同账户同月双计。

## 2. 决策记录

| 决策 | 结论 |
|---|---|
| report_date 粒度 | 逐日（对齐 QI）✅ 已完成 |
| 已完结月份策略 | **允许自动回补**（迟到数据到达即重算对应历史天） |
| DWS 构建架构 | **方案 A：CDC 单写**（唯一写入者 = 重构后的 daily CDC） |
| batch 角色 | 仅一次性历史初始化 + 手动回刷工具，日常不写 DWS |
| active card fee | 保持月初承载（月度去重） |
| fixed fee | 月固定成本按天均分、逐日分摊（已完成） |

## 3. 架构

```
DWM.transaction + DWM.auth（唯一事实源，逐笔明细）
        │
        ▼
DWS CDC（唯一写入者，每日调度）
  扫近 24h DWM 变更（update_time/delete_time）
  → 命中 (事件时间天, account)
  → 先删 DWS 该 (天,账户) 范围（仅普通行）→ 按统一口径重算 → 幂等 upsert
        │
        ▼
DWS（逐日粒度，口径唯一；active/fixed 特殊行由独立作业维护）
        │
        ▼
v4 查询 / mv_channel_cost_daily（按月聚合，无需改）
```

## 4. 分节设计

### 4.1 触发与回补（解决"漏触发"）
- **DWM sink 的 update_time 改为 `CURRENT_TIMESTAMP`（作业写入时间）**，替代 `COALESCE(源交易update_time, ...)`；
- 效果：DWM 每次 upsert（每日事件窗口重写 + 迟到 settlement 补写）都刷新 update_time → DWS CDC 近 24h 扫描必然命中 → 按 (事件时间天, 账户) 重算；
- 迟到数据（T 月交易 T+1/T+2 月入账）：DWM 补写时 update_time=当天 → DWS 重算对应历史天 → **自动回补** ✓；
- auth DWM 已用 CURRENT_TIMESTAMP，transaction DWM（cdc/batch/monthly-cdc 三版）需改。

### 4.2 幂等与并发
- `id = ABS(HASH(日:账户:sale:am))` 含天，upsert 天然幂等；
- **重算前先删 DWS 该 (report_date, account_id) 的普通行**（`special_fee_type IS NULL`，不动 active/fixed 特殊行）→ 杜绝任何并存；
- 删除函数 `fn_delete_bb_card_finance_daily_v2_cdc` 由"只计数"改为"真删除"（保留 p_dry_run 开关），CDC 作业通过 JDBC source 调用（仿 fixed fee 作业模式）；
- changed_keys 已按 `event_time::date`（逐日）✓。

### 4.3 口径统一（唯一指标定义）
把 batch（monthly-cdc）口径对齐进 DWS CDC：
- `is_excluded_settlement`：16 个黑名单 settlement_id 排除（auth 计数、refund 计数、clearing vol 均排除）；
- auth 计数排除 `business_code_list LIKE '%1010%'`（Account Verification 走独立 av_* 计数）；
- refund 计数按 `transaction_type='refund.clearing'` + `resp_code='APPROVE'` + 排除黑名单；
- clearing vol / rebate base 按 `settlement_match_type='card_transaction_id'` + 排除黑名单；
- 统一后：CDC 重算结果 = batch 回刷结果，两者可互相校验。

### 4.4 特殊行（独立作业，主链路不碰）
- active card fee：`dws_online_bb_active_card_count_v2-*`（月初承载）✅ 已正确，不动；
- fixed fee：`dws_online_bb_channel_fixed_fee_v2-*`（按天分摊）✅ 已完成，须在主链路之后调度。

### 4.5 查询侧
- v4 查询：`GROUP BY TO_CHAR(report_date,'YYYY-MM')`，volume fee 按月 total_net 阶梯 → 兼容 ✅；
- `update_bb_cash` / `mv_channel_cost_daily` / `dws_online_total_channel_cost_daily`：均已按月转换或 daily 粒度 → 兼容 ✅。

### 4.6 历史初始化（一次性）
1. 停 BB DWS/fixed fee/active card CDC；
2. 删 DWS 1-8 月（含特殊行）；
3. batch 主链路（逐日版）分 3 段跑：1-3 / 4-6 / 7-8 月；
4. fixed fee batch（逐日分摊版）；
5. active card batch；
6. 校验：7 月 v4 ≈ 432,056（batch 完整口径），report_date 逐日分布；
7. 重启 CDC（唯一写入者），后续变更按统一口径增量。

## 5. 影响面与风险

- 口径统一后，CDC 写入的历史/近期值与 batch 旧口径存在一次性差异（7 月 458,459 → 432,056 附近），属预期修正；
- batch txn 窗口 `[月初08:00, 次月月初08:00)` 与 report_date 自然日的边界差异（8/1 0-8 点交易落 8/1）——建议 batch 取数窗口改自然日 `[start, end)` 与 CDC 对齐（待办）；
- DWS 表 `volume_fee_cost` 冗余列无查询依赖，保留不写；
- fixed fee 调度须在主链路之后。

## 6. 待办（实现计划见 `2026-08-18-bb-dws-cdc-single-writer-tasks.md`）
- T1 DWM 系 update_time 改作业时间（4 个文件）
- T2 DWS CDC 口径对齐 batch（is_excluded_settlement 等）
- T3 删除函数改真删除 + CDC 重算前先删
- T4 batch 角色标注 + txn 窗口自然日化
- T5 历史初始化执行
