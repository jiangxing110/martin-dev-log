# BB客户成本-v2.sql vs flink/quantum-v2/bb 差异分析

> 对比对象：
> - `BB客户成本-v2.sql` —— 独立 PG 报表，从**原始表**直接重算，按月、按 `master_client_id` 汇总。
> - `flink/quantum-v2/bb`（batch + `query_bb_card_cost_detail_v2.sql`）—— **Flink 管线**：DWM→DWS 原子指标 → 查表乘费率。
> 两者是同一套 26 项费率的**两套并行实现**。

---

## 0. 本质架构不同（最关键）
| 维度 | BB客户成本-v2.sql | flink/quantum-v2/bb |
|------|------------------|---------------------|
| 数据源 | 原始表 `quantum_card_transaction_extend` / `qbitCardSettlement` / `bb_card_auth_detail_*` | DWM 表 `dwm_bb_card_transaction_detail_v2_p` / `dwm_bb_card_auth_detail_v2_p` |
| 中间层 | 无，一次性 CTE 直算 | `dws_bb_card_finance_daily_v2_p`（账户×日×sale×am 原子指标） |
| 费用产出 | 报表内直接 `笔数/净额 × 费率` | `query_bb_card_cost_detail_v2.sql` 读 DWS 乘费率 |
| 汇总维度 | `master_client_id`（根账户前 6 位；3 个根→`666245`） | `account_id` 逐账户，查表时全量 SUM |

---

## 1. 费率完全一致（26 项费用，两边相同）
Count 0.1090/0.4845/0.0725/0.4770、Reversal 0.7190/0.7140/0.1780、Refund 0.4845/0.4770/0.1090、Dollar Volume 0.0021/0.0111/0.0016/0.0116、Decline 0.3595/0.3570/0.0890、Active Card 0.1、Volume Fee Cost 阶梯 0.0055/0.0045/0.004。**费率无差异**。

排除结算 ID 列表（16 个 UUID）两边也完全一致。

---

## 2. 实质性差异

### 2.1 计数窗口的月末 8 小时边界（最可能让两版 Count Fee 对不上）
- **BB q1**：`transaction_time ∈ [month_start+08:00, next_month+08:00)`（两端 +8h，见 tmp_params `txn_start/txn_end`）。
- **Flink batch**：源扫描 `transaction_time ∈ [start+8h, end+8h)`（JDBC 子查询），但视图 `v_bb_txn_time_rows` 又裁到自然日 `[start, end)` → **实际 = `[start+8h, end)`**，丢掉下月 1 日 00:00–08:00 的交易。
- 结果：同样源数据下，Flink 的 auth/AC 笔数**少于** BB 报表 → Count Fee 偏低。

### 2.2 "超时自动关单"交易
- **BB q1**：含兜底 `S.settlement_id IS NULL OR T.remarks = '超时自动关单'`（无结算但自动关单的成功交易仍计笔数）。
- **Flink 计数**：要求 `resp_code = 'APPROVE'`（无结算/关单的交易不计）。无此兜底。
- 结果：方向同上，Flink 笔数更少。

> 2.1 + 2.2 共同使 Flink 侧 Count Fee 笔数低于 BB 报表——即使跑在同一份源数据上也会不一致。

### 2.3 Cashback（现金返还）
- **费率**：BB `tmp_params.cashback_rate = 0.020795`；Flink DWS 写死 `0.02057316`。**不一致**。
- **计基**：BB `total_net_amount`（=q3 四区净额之和）；Flink `bb_rebate_base_amt`（仅 `settlement_match_type='card_transaction_id'` 的 clearing/refund 净额）。**基不同**。
- **输出**：BB 把 `Cashback Income` 作为第 27 项列出（但不计入 TOTAL）；Flink `query_...` **根本没有 Cashback 行**（止于 Fixed Fee）。

### 2.4 Fixed Fee 来源
- **BB**：`tmp_params.fixed_fee` **手工参数**（默认 0）。
- **Flink**：由独立任务 `dws_online_bb_channel_fixed_fee_v2` 写入 `cost_fixed_fee` 列，`query_...` 汇总该列。来源是真实跑出来的固定费，而非手填。

### 2.5 净额 / Volume 口径（settlement_match_type）
- **Flink 金额指标**：强制 `settlement_match_type = 'card_transaction_id'`（clearing/refund 才计入净额）。
- **BB q3**：用 `T.card_transaction_id = S.qbit_card_transaction_id` **直接键匹配**，无 match_type 过滤。
- 语义相近但不等价：DWM 中按非 card_transaction_id 匹配的结算，Flink 排除、BB 可能计入 → 净额/Volume Fee Cost 可能不同。

### 2.6 区域判定来源
- 计数：BB 用交易表 `T.country`；Flink 用 DWM `tx_country`。
- 金额/退款：BB 用 `RIGHT(S.txn_location,2)`（直接读 settlement rawData）；Flink 用 DWM `settle_country`。
- 通常等价，但 BB 直读源、Flink 读 DWM 派生字段——若 DWM 派生逻辑有偏差会传导。

---

## 3. 与你刚做的"1 月 原始 vs 清洗"比对的关联
- 之前那次比对是**同一份 BB 报表 SQL 跑在两个源库**上（原始库 688809 / 清洗库 686494，差 2315，97% 在 Count Fee）——那是**数据差异**（清洗库交易更少），不是 SQL 实现差异。
- 本次是**两套实现**的差异。注意：即便在**同一份源数据**上，Flink 管线跑出来的 Count Fee 也会比 BB 报表**再低一截**（因 2.1 月末 -8h、2.2 超时关单不计）。
- 也就是说：若"清洗库"是用 BB 报表口径算的 686494，那么用 Flink 管线（DWS + query）在同一清洗库上重算，Count Fee 还会进一步下降。

---

## 4. 建议
1. **锁定 Count Fee 根因**：确认 Flink 月末窗口（是否应像 BB 那样补回 +8h）与超时关单规则，是否需要与 BB 报表对齐（或反之统一到一套）。
2. **统一 Cashback**：费率 0.020795 vs 0.02057316、计基 total_net_amount vs bb_rebate_base_amt、以及 Flink query 是否需要补 Cashback 输出行。
3. **Fixed Fee 唯一口径**：手填参数 vs Flink 固定费任务，二选一。
4. **去重实现**：若 BB 报表只是临时对账工具，建议以 Flink DWS + `query_...` 为唯一口径，弃用 BB 报表的并行实现，避免双口径长期漂移。
