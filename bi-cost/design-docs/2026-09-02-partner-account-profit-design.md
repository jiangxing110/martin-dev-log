# 合伙人客户毛利物化视图与月度快照设计

## 摘要

基于现有销售毛利返佣物化视图，新增一套面向合伙人渠道的客户毛利数据链路：先按账户根客户归集各产品、渠道和费用项的收入与成本，形成可查询的近期毛利物化视图；每月 21 号从该视图固化上个月的客户毛利快照，并同时写入合伙人客户毛利汇总和可追溯的快照详情。

本期只计算和固化客户经营毛利，不处理任何返佣费率、阶梯配置、应发佣金或应付佣金。

## 1. 背景与目标

### 1.1 背景

现有 `dws.mv_sales_commission_recent_estimate` 服务于销售返佣，包含销售/AM 归属、佣金阶段、佣金规则和佣金金额等字段。合伙人客户毛利的计算单元不同：需要以合伙人推荐的 root account 为客户单元，先记录客户真实毛利，再按合伙人维度汇总。

### 1.2 目标

1. 新增合伙人客户毛利近期估算物化视图。
2. 保留账户层面的收入、成本、毛利和渠道结果值来源。
3. 将 `open_api` 与 `qbit_card` 统一为 `qbit_card`，同时保留原始产品字段用于追溯。
4. 排除 `item = 'month_revenue'` 的 API 实收数据；后续可扩展时再加入。
5. 增加 `root_account_referral_id`，便于后续按合伙人结算。
6. 每月 21 号固化上个月数据，形成快照主表和快照详情表。

## 2. 范围与非目标

### 2.1 本期范围

- 收入来源沿用 `dws.dws_metrics_sales_revenue_monthly`。
- 成本来源沿用现有销售返佣视图使用的渠道成本和产品成本表。
- 数据主粒度为 `root_account_id + product + provider + item + source_type + settlement_month`，并携带合伙人归属。
- 快照主表按 `root_account_referral_id + root_account_id + product + settlement_month` 汇总。
- 快照详情保留视图明细粒度，确保主表金额可由详情重算。

### 2.2 非目标

- 本期不落地任何返佣金额、费率、发放状态或支付流水。
- 本期不纳入 `month_revenue` API 实收；不改变现有销售返佣视图的口径。
- 本期不改变现有销售佣金表、销售佣金规则或销售看板接口。

## 3. 业务口径

### 3.1 名词定义

| 术语 | 定义 |
|---|---|
| 渠道结果值 | 合伙人推荐客户在某产品、渠道/费用项、结算月产生的收入或成本净值，可正可负。 |
| 客户当月毛利 | 同一 root account、产品、结算月下全部渠道结果值的代数和。 |
| 合伙人客户月度毛利汇总 | 同一合伙人、产品、结算月下全部推荐客户的客户当月毛利之和。 |

### 3.2 毛利计算

```text
渠道结果值
  -> 客户当月毛利 = SUM(全部渠道结果值，可正可负)
  -> 合伙人客户月度毛利汇总 = SUM(推荐客户毛利，可正可负)
```

客户层和合伙人层都不提前将负数归零。负毛利客户必须保留，并在合伙人维度参与代数和。任何返佣下限规则由后续独立的返佣结算层处理。

## 4. 数据模型

### 4.1 近期毛利物化视图

建议名称：`dws.mv_partner_account_profit_recent_estimate`。

视图仅保留近 6 个月可查询数据，刷新方式沿用现有物化视图刷新函数/调度模式。

| 字段 | 类型建议 | 说明 |
|---|---|---|
| id | bigint | 按报告日、月份、客户、产品、渠道、费用项、来源类型生成确定性行 ID。 |
| report_date | date | 物化视图刷新/报告日期。 |
| settlement_month | date | 结算月份月初。 |
| root_account_id | varchar(64) | 顶层客户 ID。 |
| root_account_referral_id | varchar(64) | 顶层客户当前邀请码归属用户/合伙人 ID，来源 `dim.dim_account_analysis.referral_user_id`。 |
| product | varchar(64) | 统一产品编码；`open_api` 与 `qbit_card` 均输出 `qbit_card`。 |
| source_product | varchar(64) | 原始产品编码，用于区分 `open_api` 与原始 `qbit_card`。 |
| provider | varchar(255) | 渠道/服务商。 |
| item | varchar(64) | 收费项；排除 `month_revenue`。 |
| source_type | varchar(64) | 收入或成本来源类型。 |
| effective_revenue | numeric(20,4) | 渠道结果值中的收入部分。 |
| cogs | numeric(20,4) | 渠道结果值中的成本部分。 |
| gp | numeric(20,4) | 毛利，统一按 `effective_revenue - cogs` 计算。 |
| version | int | 版本号。 |
| remarks | varchar(1000) | 来源及处理说明。 |
| create_time/update_time/delete_time | timestamp | 审计字段。 |

说明：用户要求的字段全部保留；`source_product` 是为产品合并后的底层追溯字段。若现有成本收入口径将成本表示为负数，则统一在标准化层转换为 `cogs` 成本正值并计算 `gp = effective_revenue - cogs`，避免同一指标在不同来源符号不一致。

### 4.2 客户毛利快照详情表

建议名称：`dws.dws_partner_account_profit_snapshot_detail_p`，按 `snapshot_date` 分区。

字段以物化视图字段为主，增加快照字段：

- `snapshot_date`：固定为每月 21 号，表示固化动作日期。
- `root_account_referral_id`：快照时固化的合伙人 ID，不随之后账户邀请码变化而回溯改变。
- `source_product`：原始产品来源。
- `effective_revenue/cogs/gp`：该详情行的收入、成本、毛利。
- `version/remarks/create_time/update_time/delete_time`：版本和审计字段。

详情主键建议为 `(id, snapshot_date)`；ID 指纹至少包含 `snapshot_date、settlement_month、root_account_referral_id、root_account_id、product、source_product、provider、item、source_type`。

### 4.3 合伙人客户毛利快照主表

建议名称：`dws.dws_partner_account_profit_snapshot_p`，按 `snapshot_date` 分区。

主表汇总粒度为：

```text
root_account_referral_id + root_account_id + product + settlement_month
```

建议字段：

| 字段 | 类型建议 | 说明 |
|---|---|---|
| id | bigint | 快照、月份、合伙人、客户、产品的确定性 ID。 |
| snapshot_date | date | 每月 21 号。 |
| settlement_month | date | 被固化的上个月月份。 |
| root_account_referral_id | varchar(64) | 合伙人/渠道 ID。 |
| root_account_id | varchar(64) | 推荐客户 root account。 |
| product | varchar(64) | 统一产品线。 |
| total_effective_revenue | numeric(20,4) | 客户产品月度收入合计。 |
| total_cogs | numeric(20,4) | 客户产品月度成本合计。 |
| total_gp | numeric(20,4) | 客户产品月度毛利合计，可为负。 |
| version/remarks/create_time/update_time/delete_time | - | 版本和审计字段。 |

主表不提前执行毛利下限，不把负毛利客户过滤掉；没有收入但有成本的客户也必须保留。

## 5. 数据处理流程

1. 从现有销售返佣视图的收入和成本 CTE 复用业务口径，抽出不含销售佣金计算的客户毛利基础层。
2. 将账户关系归一到 root account；通过 `dim.dim_account_analysis` 获取 root account 的 `referral_user_id`。
3. 标准化产品：保留 `source_product`，将 `open_api` 和 `qbit_card` 的输出 `product` 统一为 `qbit_card`。
4. 过滤 `item = 'month_revenue'`。由于现有视图可能将该来源转换为 `source_type = past_due_invoice/billing_decline_fee`，实现时应以原始 `metric_code` 或明确的来源标记过滤，不能只依赖转换后的 item。
5. 按视图明细粒度聚合 `effective_revenue`、`cogs`，计算 `gp = effective_revenue - cogs`。
6. 物化视图按近 6 个月刷新，提供当前月和历史未固化月份查询。
7. 每月 21 号读取 `settlement_month = 当前月月初 - 1 个月` 的物化视图，先写详情，再由详情/同一输入聚合写主表。
8. 主表与详情在同一 Flink batch 作业中使用 statement set/upsert 写入，避免两张表出现不同批次版本。

## 6. 快照调度、幂等与补跑

- 调度日期：每月 21 号；`snapshot_date` 固定为当月 21 号，而不是任务实际补跑日期。
- 目标月份：当前月份的上个月月初。例如 2026-09-21 固化 `2026-08-01`。
- 幂等键：详情使用快照日期 + 明细业务指纹；主表使用快照日期 + 合伙人 + 客户 + 产品 + 结算月。
- 补跑策略：同一快照日期再次执行使用 upsert 覆盖同一业务键；若需重算，必须先确认物化视图已刷新到目标月份的最新数据。
- 历史稳定性：快照写入时固化 `root_account_referral_id`，后续邀请码或客户关系变化不修改已固化月份。
- 空结果：目标月份没有数据时不生成伪造汇总行，任务记录成功且输出 0 行。

## 7. 数据质量校验

上线前和每月快照后执行以下校验：

1. 产品校验：输出 `product` 不得出现 `open_api`；原始 `source_product` 能区分来源。
2. 过滤校验：结果中不存在原始 `metric_code = month_revenue` 的 API 实收。
3. 关系校验：同一 `root_account_id + settlement_month` 的有效合伙人归属符合当前维表；无归属的客户保留记录且 `root_account_referral_id` 为空，供异常清单处理。
4. 金额校验：详情按主表粒度聚合后，`SUM(effective_revenue/cogs/gp)` 与主表一致，误差不超过 0.0001。
5. 毛利校验：每条记录满足 `gp = effective_revenue - cogs`；负毛利不得在客户层被截断。
6. 快照校验：快照日期为当月 21 号，结算月为上个月月初；重复补跑不产生重复业务行。

## 8. 实现文件建议

在目标项目目录新增并按职责拆分：

- `table-scripts/mv_partner_account_profit_recent_estimate.sql`：物化视图、索引、刷新函数依赖说明。
- `table-scripts/dws_partner_account_profit_snapshot_p.sql`：快照主表和年度分区。
- `table-scripts/dws_partner_account_profit_snapshot_detail_p.sql`：快照详情表和年度分区。
- `batch/dws_partner_account_profit_snapshot-batch-sql.sql`：参数化快照任务，支持 `snapshot_date`、`settlement_month`。
- `cdc/dws_partner_account_profit_snapshot-month-cdc-sql.sql`：每月 21 号自动计算目标月份的调度任务。
- `plans/2026-09-02-partner-account-profit-plan.md`：实现步骤、验证项和进度。

## 9. 风险与待确认事项

1. `dim.dim_account_analysis.referral_user_id` 当前是账户分析维表的当前值；如果业务要求严格按历史生效时间还原合伙人归属，需要补充账户邀请码历史表或有效期字段。
2. 同一 root account 若存在多个产品来源，合并为 `qbit_card` 后必须依赖 `source_product` 进行审计，不能再假设产品编码唯一代表来源。
3. 本期不设计返佣费率及配置表；后续返佣计算需单独设计费率配置、优先级和结算结果表。

## 10. 验收标准

- 物化视图包含用户要求的 11 个业务字段及 `root_account_referral_id/source_product` 扩展字段。
- `month_revenue` API 实收被过滤，后续可通过单独配置重新启用。
- `open_api` 和 `qbit_card` 对外统一输出 `qbit_card`，且来源可追溯。
- 客户层的正负渠道结果值可相抵，合伙人客户汇总保留正负毛利，不在本数据层截断。
- 每月 21 号可幂等固化上个月数据，主表与详情表金额一致。
- 设计不修改现有销售返佣表和现有销售返佣视图的对外口径。
