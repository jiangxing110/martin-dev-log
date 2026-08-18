# BB DWS report_date 逐日化改造 + 全量回刷方案

- 日期：2026-08-18
- 背景：dws_bb_card_finance_daily_v2_p 主链路以「月初承载整月」（report_date = 月初），导致：
  1. 已完结月份仍被 DWS CDC 整月重算，7 月成本一夜 +26,404（batch 漏写 15 账户 + CDC 补写并存）；
  2. 无法按天回溯、无法增量追踪；
  3. 双写者（daily CDC / batch）在同一 (月, 账户, sale, am) key 上互相覆盖/并存。
- 决策：BB 主链路改为**逐日粒度**（对齐 QI，QI 已逐日且正确）；**active card fee 保持月初承载**（月度去重）；**fixed fee 月固定成本按天均分、逐日分摊**；历史 1-8 月**全量回刷**。

## 一、脚本改动清单（已完成）

| 脚本 | 改动 | 状态 |
|---|---|---|
| `flink/quantum-v2/bb/cdc/dws_online_bb_card_finance_daily_v2-cdc-v2-sql.sql` | changed_keys 由 `date_trunc('month',event_time)` 改 `event_time::date`；`v_bb_metric_rows` 三处 report_date 及 JOIN、auth 的 report_date 全部 `CAST(x AS DATE)` | ✅ 逐日 |
| `flink/quantum-v2/bb/batch/dws_online_bb_card_finance_daily_v2-batch-sql.sql` | `v_bb_txn_time_rows`（原固定 start_date）/ `completion` / `post` / `auth_month` 的 report_date 改 `CAST(x AS DATE)` | ✅ 逐日（回刷工具） |
| `flink/quantum-v2/bb/monthly-cdc/dws_online_bb_card_finance_daily_v2-monthly-cdc-v2-sql.sql` | 同上 4 处 | ✅ 逐日（当前不使用，保留） |
| `flink/quantum-v2/bb/cdc/dws_online_bb_channel_fixed_fee_v2-cdc-v2-sql.sql` | 新增 `v_day_channel_cost`（月固定成本÷当月天数）；`v_month_net_amount`→`v_day_net_amount`（按天）；分摊改 `day_fixed_fee × 当日行净额 ÷ 当日净额` | ✅ 逐日分摊 |
| `flink/quantum-v2/bb/batch/dws_online_bb_channel_fixed_fee_v2-batch-sql.sql` | 同上 | ✅ 逐日分摊 |
| `flink/quantum-v2/bb/monthly-cdc/dws_online_bb_channel_fixed_fee_v2-monthly-cdc-v2-sql.sql` | 同上 | ✅ 逐日分摊 |

**保持月初（不改）**：`dws_online_bb_active_card_count_v2-*.sql`（active card 月度去重）。

**删除函数（无需改）**：`fn_delete_bb_card_finance_daily_v2_cdc` 已按 `event_time::date`；`fn_delete_bb_channel_fixed_fee_v2_cdc` 按月份范围删（逐日后 fixed fee 分布整月，范围删仍干净）。

## 二、查询侧兼容性（已核查，均兼容）

- `query_bb_card_cost_detail_v4.sql`：已 `GROUP BY TO_CHAR(report_date,'YYYY-MM')`，volume fee 按月 total_net 阶梯，逐日天然兼容；
- `query_bb_card_cost_detail_v2/v3.sql`：范围查询全月 SUM，兼容；
- `update_bb_cash.sql` / `update_qi_cash.sql`：`DATE_TRUNC('month', report_date)` 分组，兼容；
- `mv_channel_cost_daily.sql`（materialized-view / incremental-view / total_cost 三版）：`DATE_TRUNC` 关联月数据 + 本身 daily 粒度，兼容且更合理；
- `dws_online_total_channel_cost_daily-batch-sql.sql`：`DATE_FORMAT(report_date,'yyyyMM')` 分组，兼容。

## 三、全量回刷执行步骤（1-8 月）

前置：确认 DWM 1-8 月数据完整（尤其 7 月 15 个迟到账户——8/17 后已回流）。

```sql
-- ① 回刷前校验 DWM 完整：1-8 月各月交易量（含 7 月 15 账户）
SELECT date_trunc('month', transaction_time)::date AS m, COUNT(*) AS txn_cnt, COUNT(DISTINCT account_id) AS acct_cnt
FROM dwm.dwm_bb_card_transaction_detail_v2_p
WHERE delete_time IS NULL AND transaction_time >= DATE '2026-01-01' AND transaction_time < DATE '2026-09-01'
GROUP BY 1 ORDER BY 1;
```

1. **停任务**：停 BB DWS CDC、fixed fee CDC、active card CDC（DWM CDC 可不停，batch 只读 DWM）。
2. **删 1-8 月 DWS 数据**（含主链路 + 特殊行）：
```sql
DELETE FROM dws.dws_bb_card_finance_daily_v2_p
WHERE report_date >= DATE '2026-01-01' AND report_date < DATE '2026-09-01';
```
3. **跑逐日版 batch 主链路**（写 DWS 主链路行，remarks=`bb_v2_batch_*`）：
   - 作业：`flink/quantum-v2/bb/batch/dws_online_bb_card_finance_daily_v2-batch-sql.sql`
   - 参数：start_date=`2026-01-01`，end_date=`2026-09-01`
   - ⚠️ 单次跑 8 个月数据量大，建议按 1-3 月 / 4-6 月 / 7-8 月分三段跑（batch 支持任意窗口，不会重复——DWS 已清空）。
4. **跑逐日版 fixed fee batch**：`dws_online_bb_channel_fixed_fee_v2-batch-sql.sql`，start_time/end_time 同上分三段。
5. **跑 active card batch**（保持月初）：`dws_online_bb_active_card_count_v2-batch-sql.sql`，覆盖 1-8 月。
6. **校验**：
```sql
-- 各月行数与 report_date 分布（应为逐日）
SELECT report_date, remarks, COUNT(*) FROM dws.dws_bb_card_finance_daily_v2_p
WHERE report_date >= DATE '2026-07-01' AND report_date < DATE '2026-08-01'
  AND delete_time IS NULL GROUP BY 1,2 ORDER BY 1,2;
-- v4 查询对账：7 月应回到 ≈ 432,056 附近（batch 口径完整版）
```
7. **重启 CDC**，后续变更按逐日写。

## 四、注意事项

1. **08:00 窗口边界**：batch 的 transaction_time 窗口仍为 [月初08:00, 次月月初08:00)，report_date 改自然日后，窗口末尾 8 小时（次月 1 日 00:00-08:00）的交易会落到次月 1 日——与 CDC 自然日口径一致，属可接受差异；如要严格对齐「成本月」，后续可再评估。
2. **volume fee 口径不变**：仍按「月 total_net 阶梯」在查询时计算（v4），逐日化不影响；DWS 表内 volume_fee_cost 字段本就未由 CDC/batch 写入。
3. **fixed fee 分摊口径变化**：由「月成本×行净额/月净额」变为「(月成本/天数)×日行净额/日净额」，**月度总额不变**（每天分摊份额合计=月固定成本），仅分布到天。
4. **7 月 15 账户**：回刷后由 batch 口径统一写入（DWM 已完整），不会再出现 batch/CDC 并存。
5. **1-8 月回刷后与「实际账单」对账**：若 batch 口径与账单仍有差（此前 1-6 月存在小差异），另行核对口径。
