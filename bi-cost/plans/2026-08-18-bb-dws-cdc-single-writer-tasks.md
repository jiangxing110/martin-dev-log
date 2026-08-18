# BB DWS 单一写入者改造 — 实现计划

- 日期：2026-08-18
- 前置：设计文档 `2026-08-18-bb-dws-cdc-single-writer-design.md`（已批准）
- 每个任务含改动文件与验证方式；完成一个再进下一个。

## T1. DWM 系 update_time 改为作业写入时间（解决 DWS 漏触发）

**改动文件**：
1. `flink/quantum-v2/bb/cdc/dwm_online_bb_card_transaction_detail_v2-cdc-sql.sql`
   - `v_bb_base_normal`：`COALESCE(t.update_time, t.create_time, CURRENT_TIMESTAMP) AS update_time` → `CAST(CURRENT_TIMESTAMP AS TIMESTAMP(6))`
   - `v_bb_refund_direct_base`：同上
2. `flink/quantum-v2/bb/batch/dwm_online_bb_card_transaction_detail_v2-batch-sql.sql`（重灌 DWM 时同样刷新）
3. `flink/quantum-v2/bb/monthly-cdc/dwm_online_bb_card_transaction_detail_v2-monthly-cdc-sql.sql`（2 处）
4. `flink/quantum-v2/bb/cdc/dwm_online_bb_card_auth_detail_v2-cdc-sql.sql`：确认已用 `CURRENT_TIMESTAMP`（疑似已对，核对即可）

**验证**：`grep -rn "COALESCE(t.update_time" flink/quantum-v2/bb/` 无残留；DWM 重写后 update_time=运行时间。

## T2. DWS CDC 口径对齐 batch（唯一指标定义）

**改动文件**：`flink/quantum-v2/bb/cdc/dws_online_bb_card_finance_daily_v2-cdc-v2-sql.sql`

在 `v_dws_bb_txn_daily_base`（及 auth 侧）中，把 batch 的口径条件补进 CDC：
1. 新增 `is_excluded_settlement` 标记：`COALESCE(s.settlement_id IN (16 黑名单), FALSE)`（可在 `v_bb_metric_rows` 层加列）；
2. auth 计数（m/v_dom/int_auth_count）追加 `business_code_list NOT LIKE '%1010%'` 与 `is_excluded_settlement = FALSE`；
3. reversal 计数追加 `is_excluded_settlement = FALSE`；
4. refund 计数（post_date 分支）追加 `is_excluded_settlement = FALSE`（resp_code APPROVE 已有）；
5. clearing vol / rebate base（completion_time 分支）追加 `is_excluded_settlement = FALSE`（settlement_match_type='card_transaction_id' 已有）。

**验证**：对同一 (天,账户) 分别用 CDC 与 batch 口径重算，结果一致；7 月 v4 ≈ 432,056。

## T3. DWS CDC 重算前先删（杜绝并存）

**改动文件**：
1. `flink/quantum-v2/bb/table-scripts/register_fn_quantum_bb_cdc_delete_v2.sql`
   - `fn_delete_bb_card_finance_daily_v2_cdc`：从"只计数"改为 `p_dry_run=false` 时真 DELETE（`WHERE special_fee_type IS NULL AND EXISTS(changed_keys 按 event_time::date 匹配)`），dry_run 时只计数；
2. `flink/quantum-v2/bb/cdc/dws_online_bb_card_finance_daily_v2-cdc-v2-sql.sql`
   - 新增 JDBC source 调用 `fn_delete_bb_card_finance_daily_v2_cdc(false)`（仿 fixed fee 作业的 source_delete 模式），INSERT 前 CROSS JOIN 保证先删后算。

**验证**：dry-run 输出待删行数；真删后同 (天,账户) 无并存；重算后行数与 DWM 直算一致。

## T4. batch 角色标注 + txn 窗口自然日化

**改动文件**：`flink/quantum-v2/bb/batch/dws_online_bb_card_finance_daily_v2-batch-sql.sql`
1. 头部注释标注「仅一次性初始化/手动回刷工具，日常 DWS 写入走 CDC」；
2. `v_bb_txn_time_rows` 取数窗口 `transaction_time >= ${start_date}+8h AND < ${end_date}+8h` → 改自然日 `>= ${start_date} AND < ${end_date}`（与 report_date 自然日、CDC、QI 对齐，消除 8/1 0-8 点边界坑）。

**验证**：窗口 SQL 语义检查；回刷 7 月不含 8/1 行。

## T5. 历史初始化执行（运维，见设计文档 §4.6）
停 CDC → 删 DWS 1-8 月 → batch 主链路 3 段 → fixed fee batch → active card batch → 校验（7 月 ≈432,056，逐日分布）→ 重启 CDC。

## 验收标准（全部满足视为完成）
1. DWM update_time 均为作业写入时间；
2. CDC 与 batch 对同一 (天,账户) 重算结果一致（口径统一）；
3. 重算先删后算，任意时刻无 batch/CDC 并存行；
4. 迟到 settlement 进 DWM 后 DWS 对应历史天自动回补；
5. v4 查询 1-8 月与回刷后 batch 口径一致，7 月 ≈ 432,056。
