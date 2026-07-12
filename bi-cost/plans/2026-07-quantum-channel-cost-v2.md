# BB / QI / SL 渠道成本 v2 执行计划

## 1. 准备工作

- [ ] 确认 `ods_bi_month_tag` 中 BB / QI / SL 的指标命名，包括固定成本、成本系数、返现系数。
- [ ] 确认固定成本第一版采用有效 DWS 行均摊。
- [ ] 新建 `flink/quantum-v2` 目录结构。
- [ ] 复用现有 BB / QI / SL 脚本作为 v2 初始版本，避免直接影响生产脚本。

## 2. 业务链路和固定成本链路拆分

- [ ] BB / QI / SL 主业务脚本只负责交易、结算、Auth、成本基数、返现基数等明细清洗。
- [ ] 主业务 batch 脚本按业务时间窗口定向回刷，不使用 `ods_bi_month_tag.update_time` 作为默认驱动。
- [ ] 主业务 cdc 脚本按业务源表增量运行，不扫描昨天 `ods_bi_month_tag.update_time`。
- [ ] 固定成本回刷单独建脚本，只负责 `cost_fixed_fee`。
- [ ] 固定成本 batch 脚本接收 `start_time` / `end_time`，用于扫描 `ods_bi_month_tag.update_time`。
- [ ] 固定成本 cdc 脚本不设置必填变量，默认扫描昨天 `ods_bi_month_tag.update_time`。

## 3. 固定成本独立回刷

- [ ] 从 `ods_bi_month_tag` 获取 BB / QI / SL 月固定成本金额。
- [ ] 同月同指标多条数据时，按 `update_time desc, statistics_time desc` 取最新有效记录。
- [ ] 识别 `ods_bi_month_tag.update_time` 变动影响的固定成本月份。
- [ ] 加入软删除月份识别。
- [ ] 加入硬删除对账逻辑，按源表和目标表的月份、渠道、指标做 diff。
- [ ] 统计当月有效 DWS 明细行数。
- [ ] 计算 `cost_fixed_fee = month_fixed_fee / month_valid_row_count`。
- [ ] 当月没有固定成本有效记录时，`cost_fixed_fee` 按 0 处理。
- [ ] 当月没有有效 DWS 明细行时，不产出固定成本摊销结果。
- [ ] 回写前先清理对应月份、渠道的历史 `cost_fixed_fee`。

## 4. BB v2

- [ ] 创建 BB batch / cdc 目录。
- [ ] 新增 `dwm.dwm_bb_card_transaction_detail_v2_p` 表结构，避免旧 DWM 缺字段影响新规则。
- [ ] BB 交易 DWM 以 `quantum_card_transaction_extend` 为主源。
- [ ] BB 交易 DWM 关联 `qbitCard` 获取 `Master` / `VISA` 卡组织。
- [ ] BB 交易 DWM 过滤 `channel_provision = 'BLUEBANC'`、`type in ('Consumption', 'Credit')`、`delete_time is null`。
- [ ] BB 交易 DWM 排除 `detail like 'AUTO CLASS CAR RENTAL%'` 的数据。
- [ ] BB 结算 DWM 迁移 `qbitCardSettlement` 的 BlueBanc 清结算逻辑。
- [ ] 新增 `dwm.dwm_bb_card_auth_detail_v2_p` 表结构。
- [ ] 新增 BB Auth 月表 batch 导入脚本，参数为 `auth_table_name`、`start_time`、`end_time`。
- [ ] Auth 月表存在时，计算 Decline / AC Decline / Active Card 相关指标。
- [ ] Auth 月表不存在时，对应字段按 0 处理。
- [ ] BB DWS 表结构保持不变。
- [ ] BB DWS 从 `dwm_bb_card_transaction_detail_v2_p` 汇总到现有 `dws_bb_card_finance_daily_p`。
- [ ] BB DWS 从 `dwm_bb_card_auth_detail_v2_p` 汇总非验证 Decline 和 Active Card。
- [ ] AC Decline 明细先保留在 Auth DWM，现有 BB DWS 不强行承接。
- [ ] BB 主业务 CDC 第一阶段只同步 DWM，DWS 通过受影响日期 batch 回刷。
- [ ] BB DWS 保留 `cost_fixed_fee` 字段，但主业务脚本不负责从 `ods_bi_month_tag` 回刷该字段。
- [ ] 确认 BB DWS 粒度仍为 `account_id + report_date + sale_id + am_id`。

## 5. QI v2

- [ ] 创建 QI batch / cdc 目录。
- [ ] 迁移现有 QI DWS 逻辑。
- [ ] 将 QI 成本系数改为从 `ods_bi_month_tag` 获取。
- [ ] 通过独立迁移 SQL 增加 `cost_reimbursement_base_amt`、`cost_service_base_amt`、`cost_acs_regular_base_cnt`、`cost_acs_vip_base_cnt`、`cost_vrm_base_cnt`、`rebate_interchange_base_amt`、`rebate_incentive_base_amt`。
- [ ] QI DWS 保留原有 `*_vol` 字段兼容旧链路。
- [ ] QI DWS 保留 `cost_fixed_fee` 字段，但主业务脚本不负责固定成本回刷。
- [ ] 确认 QI DWS 粒度仍为 `account_id + report_date + sale_id + am_id`。

## 6. SL v2

- [ ] 创建 SL batch / cdc 目录。
- [ ] 迁移现有 SL DWS 逻辑。
- [ ] 将 SL 成本系数和返现系数改为从 `ods_bi_month_tag` 获取。
- [ ] SL DWS 保留 `cost_fixed_fee` 字段，但主业务脚本不负责固定成本回刷。
- [ ] 确认 SL DWS 粒度仍为 `account_id + report_date + sale_id + am_id`。

## 7. 阿里云 Flink 兼容

- [ ] 主业务 cdc 脚本不保留必填变量。
- [ ] 固定成本 cdc 脚本不保留必填变量。
- [ ] 不使用 `SET 'execution.runtime-mode'`。
- [ ] 对 cdc 脚本设置较低并行度，避免小表任务产生过多网络 buffer。
- [ ] 关闭 source / sub-plan 复用，减少 VVR 优化导致的复杂执行图。
- [ ] 检查是否存在 Flink SQL 不支持的临时表、动态表名或非法语法。

## 8. 验证

- [ ] 检查 v2 脚本中是否还存在写死月份。
- [ ] 检查 v2 脚本中是否还存在 `job_action`。
- [ ] 用单月回刷验证 batch 逻辑。
- [ ] 用业务源表增量验证主业务 cdc 逻辑。
- [ ] 用默认昨天窗口验证固定成本 cdc 逻辑。
- [ ] 验证软删除后目标表固定成本被清理。
- [ ] 验证硬删除后通过源表和目标表 diff 能识别受影响月份。
- [ ] 验证 BB Auth 月表不存在时脚本不会失败。
- [ ] 验证总成本聚合能读取 `cost_fixed_fee`。

## 9. 交付

- [ ] 更新变更说明，记录 BB / QI / SL v2 脚本路径。
- [ ] 标记旧脚本和 v2 脚本的使用边界。
- [ ] 和财务确认 `cost_fixed_fee` 均摊口径是否可以作为第一版上线。
