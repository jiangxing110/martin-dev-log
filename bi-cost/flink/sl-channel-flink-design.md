# SL 渠道 Flink 版设计说明

## 1. 背景

SL 渠道的历史实现主要依赖 PostgreSQL 函数、XXLJob、以及部分 CDC 同步任务。当前需要切换到阿里云实时计算 Flink 版后，链路要拆成两类职责：

- 流式/增量输入：负责为 DWM 提供 `qbitCardSettlement` 和交易关系的实时输入
- Batch 链路：负责 DWM / DWS 的按天重算和历史回补

本设计参考现有 `bi-cost/acquiring` 的写法，同时沿用 `bi-model.md` 中的成本口径。

> 说明：现有文档里 SL 渠道的历史命名有时写作 `LS`，本文统一按“SL 渠道”描述，表名可按现有库表命名保持 `ls` 前缀不变。

## 2. 目标

1. 在 DWM 层挂接 `sale_id` 和 `am_id`
2. DWM 的归属按交易时间生效，不按完成时间
3. DWS 层按 `account_id + report_date + sale_id + am_id` 出日汇总
4. 同一客户同一天如果前半天归属 A、后半天归属 B，DWS 保留两条记录
5. DWM 基于 `qbitCardSettlement` 落结算明细
6. DWS 基于 DWM 计算 `rebate_base`、`rebate_amt`
7. `cost_fixed_fee` 后续通过 `bi_month_tag` 单独更新

## 3. 整体架构

### 3.1 流式/增量输入

当前实现不再单独落 ODS / DWD，所以这里不定义“ODS CDC 同步链路”。
流式输入的职责是直接为 DWM 作业提供增量来源，主要包括：

- `qbitCardSettlement` CDC
- `qbit_card_transaction` 关联数据
- 销售关系表 CDC

它的职责是“进数”和“维持可重算输入”，不承担复杂的月度回补计算。

### 3.2 Batch 链路

Batch 链路负责把 DWM 和 DWS 做成稳定的日粒度结果，主要包括：

- 按交易时间重算 DWM 明细
- 按天、按销售归属、按 AM 归属汇总 DWS

Batch 链路是最终口径的主要产出层。

## 4. 数据分层

### 4.1 DWM

DWM 层按 settlement 明细落地，只负责在 `qbitCardSettlement` 上补账户和销售归属。

建议字段：

- `id`
- `account_id`
- `settlement_date`
- `settlement_transaction_id`
- `qbit_card_transaction_id`
- `qbit_transaction_id`
- `billing_amount`
- `country`
- `sale_id`
- `am_id`

其中：

- `id` 沿用 `qbitCardSettlement.id`
- DWM 按 `settlement_date` 月分区，主键为 `id + settlement_date`
- `qbit_card_transaction_id` 对应 `qbitCardSettlement.qbitCardTransactionId`
- `qbit_transaction_id` 对应 `qbit_card_transaction.transactionId`
- `sale_id` / `am_id` 基于 `qbit_transaction_id` 对应的年度交易关系表
- DWM 不承载 `cost_fixed_fee`

### 4.2 DWS

DWS 层按日汇总，但粒度不是单纯的账户日，而是：

- `account_id`
- `report_date`
- `sale_id`
- `am_id`

因此 DWS 一天可能有多条记录，只要销售或 AM 归属不同就拆分。
`rebate_base`、`rebate_amt` 在 DWS 层计算，`cost_fixed_fee` 先置 0，后续通过 `bi_month_tag` 更新。

建议字段：

- `id`
- `report_date`
- `account_id`
- `sale_id`
- `am_id`
- `version`
- `rebate_base`
- `rebate_amt`
- `cost_fixed_fee`
- `create_time`
- `update_time`
- `delete_time`

## 5. 销售归属规则

### 5.1 归属时间

`sale_id` / `am_id` 的归属基于交易时间，不基于完成时间。

也就是说：

- 交易发生在销售 A 有效期内，归属销售 A
- 同一客户当天如果关系切换到销售 B，后续交易归属销售 B

### 5.2 关系来源

归属关系来自销售关系时间线维表和账户层级关系：

- `public.dim_sale_account_relation_p`
- `public.api_account_relation`

匹配规则：

- 优先用交易 `account_id` 直接匹配 `dim_sale_account_relation_p.relation_account_id`
- direct 没命中时，用 `api_account_relation.root_id` 匹配 `dim_sale_account_relation_p.relation_account_id`
- 两者都按 `qbit_card_transaction.transactionTime` 匹配销售关系生效区间
- 都找不到时，`sale_id` / `am_id` 允许为空

### 5.3 DWM 与 DWS 的关系

- DWM 负责挂接交易时点的 `sale_id` / `am_id`
- DWS 负责按 `account_id + report_date + sale_id + am_id` 汇总

这样可以保证同一天多销售切换时的结果可追溯。

## 6. SL 固定成本口径

`cost_fixed_fee` 后续通过 `bi_month_tag` 更新：

- `provider = 'LS'`
- `tag = '量子卡-渠道固定成本'`

更新任务按月内 `rebate_base` 占比分摊到 `account_id + report_date + sale_id + am_id` 粒度。

## 7. 流式链路建议

### 7.1 增量输入

当前 DWM 作业直接以 `postgres-cdc` 读取 `qbitCardSettlement`，并关联 `qbit_card_transaction` 与年度交易关系表。

### 7.2 职责边界

输入层只做：

- 数据捕获
- 轻度标准化
- 为 DWM 提供可重算输入

不要把 DWS 多行拆分这类逻辑塞进输入层。

## 8. Batch 链路建议

### 8.1 DWM 重算

Batch 任务按交易时间窗口重算 DWM。

建议原则：

- 只按交易事件时间过滤
- 交易关系表切换后能重新回刷历史日
- 支持按天或按时间窗口重算

### 8.2 DWS 重算

DWS 按天重算，并且以：

- `account_id`
- `report_date`
- `sale_id`
- `am_id`

作为聚合粒度。

如果同一客户当天有多个销售归属，就会生成多条 DWS 记录。

### 8.3 固定成本更新

当前 DWS 主作业不读取 `bi_month_tag`。后续单独补固定成本更新任务，读取 `bi_month_tag` 后按月返现基数占比分摊 `cost_fixed_fee`。

## 9. 推荐落地命名

如果延续现有风格，建议采用以下命名：

- `sp_sync_sl_card_incremental.sql`
- `sp_init_sl_card_dwm_by_fast.sql`
- `sp_init_sl_card_dws_by_fast.sql`
- `dwm_sl_card_transaction_detail_p.sql`
- `dws_sl_card_finance_daily_p.sql`

如果后续想完全贴合现有目录命名，也可以沿用 `ls` 前缀，只在文档中统一称作 SL 渠道。

## 10. 需要确认的实现细节

以下细节在写 SQL 前建议最终确认：

1. `qbitCardSettlement.qbitCardTransactionId` 是否对 SL settlement 全量可靠
2. `bi_month_tag.tag = '量子卡-渠道固定成本'` 是否就是生产库实际存储值
3. 固定成本更新任务是否按月全量覆盖 DWS 的 `cost_fixed_fee`
4. `sale_id` / `am_id` 是否允许为空，以及空值是否进入 DWS

## 11. 结论

SL 渠道的 Flink 版不建议继续沿用单纯的 Postgres 函数式写法，而应采用：

- 流式：`qbitCardSettlement` CDC 作为 DWM 的增量输入
- Batch：DWM 按 settlement 挂销售归属，DWS 基于 DWM 汇总返现指标
- 后置：固定成本后续通过 `bi_month_tag` 更新 DWS

这样可以同时满足：

- 销售/AM 关系按交易时间生效
- 同一天多销售拆行
- 返现主链路保持 `qbitCardSettlement -> DWM -> DWS`
- 固定成本更新和主汇总链路解耦
- 和 `acquiring` 目录中的 Flink 版实现风格保持一致
