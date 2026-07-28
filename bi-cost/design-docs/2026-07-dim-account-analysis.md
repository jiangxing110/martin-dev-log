# Dim Account Analysis 设计方案

## 摘要

新增 `dim.dim_account_analysis`，用于沉淀客户分析维表。该表以 DWM 层已合并后的最上层客户为粒度，保留客户基础属性、业务扩展字段、风险等级，以及量子卡、全球账户、加密资产、API、粒子理财五类业务激活时间。

## 背景

当前客户分析口径分散在多个业务 SQL 中，常见问题包括：

- 子母账户、Gateway、Distributor 账户聚合逻辑重复。
- 不同业务激活时间各自计算，难以统一复用。
- 客户基础属性、风险属性、CAAS/API 扩展字段和业务激活状态不在同一张维表中。

## 目标

- 新建 `dim.dim_account_analysis` 表。
- 提供批量初始化/回刷脚本。
- 提供增量同步脚本，用于持续刷新客户维表。
- 统一使用 root account 聚合业务激活时间，再回写到最上层客户。

## 非目标

- 不改造现有 `dim.dim_account` 生成逻辑。
- 不新增 ODS 同步脚本。
- 不变更现有渠道成本、毛利、月报 SQL。

## 目标表

目标表：`dim.dim_account_analysis`

主键：`account_id`

字段：

- `account_id`：客户 ID，来源 `dim.dim_account.id`
- `verified_name`：客户名称，来源 `dim.dim_account.verified_name`
- `account_category`：客户类型，来源 `dim.dim_account.type`
- `status`：客户状态，来源 `dim.dim_account.status`
- `system_type`：客户系统类型，来源 `dim.dim_account.system_type`
- `business_mode`：业务模式，来源 `caas_open_api_extend.business_mode`
- `access_type`：对接模式，来源 `caas_open_api_extend.access_type`
- `mor_type`：MOR 类别，来源 `caas_open_api_extend.mor_type`
- `mor_type_extra`：MOR 类别扩展字段，来源 `caas_open_api_extend.mor_type_extra`
- `account_risk_level`：客户风险等级，来源 `cddRiskRating.accountRiskLevel`
- `card_active_time`：量子卡激活时间
- `global_active_time`：全球账户激活时间
- `crypto_active_time`：加密资产激活时间
- `api_active_time`：API 上线时间
- `treasury_active_time`：粒子理财激活时间
- `create_time`、`update_time`、`delete_time`：维表维护字段

## 账户合并口径

基础客户只保留 `dim.dim_account.type IN ('ApiClient', 'MasterAccount', 'Merchant', 'TestAccount')`。

业务流水归属客户按以下规则计算：

- 若 `ods.ods_api_account_relation.account_id` 命中，则使用 `root_id`。
- 否则使用流水自身 `account_id`。

该口径覆盖子母账户以及 Gateway、Distributor 账户合并。

## 激活时间口径

量子卡激活时间：

- 来源：`public.qbitCardWalletTransaction`
- 条件：`business_type IN ('TransferInFromIPeakoin', 'QbitCryptoToQbitCardWallet', 'TransferInFromQbitGlobal', 'Deposit', 'TransferInFromFinancing', 'TransferInFromCryptoAssets', 'AccountDepositCNY')`
- 条件：`status = 'Closed'`
- 规则：按 root account 累计 `origin_amount`，累计金额首次超过 `5000` 时的第一笔交易时间。

全球账户激活时间：

- 来源：`public.transfer`
- 规则：按 root account 取 `MIN(transaction_time)`。

加密资产激活时间：

- 来源：`public.crypto_assets_transfers`
- 条件：`action = 'sell'`
- 条件：`status = 'Closed'`
- 条件：`hidden = FALSE`
- 规则：按 root account 累计 `origin_amount * usd_rate`，累计金额首次超过 `200000` 时的第一笔交易时间。

API 上线时间：

- 来源：`public.openApiClientConfig.online_time`
- 规则：`openApiClientConfig.clientId` 作为客户 ID，按 root account 取最早上线时间。

粒子理财激活时间：

- 来源：`public.fund_orders`
- 条件：`type = 'purchase'`
- 条件：`status = 'complete'`
- 规则：按 root account 取 `MIN(create_time)`。

## 脚本结构

- `flink/account_analysis/table-scripts/dim_account_analysis.sql`：ADBPG 建表脚本。
- `flink/account_analysis/batch/dim_online_account_analysis-batch-sql.sql`：全量初始化/回刷。
- `flink/account_analysis/cdc/dim_online_account_analysis-cdc-sql.sql`：增量持续刷新。

## 风险与注意事项

- 量子卡钱包、全球账户、加密资产、API 上线、粒子理财激活时间已按附件 DDL 直接读取 `public` 实表。
- `dim.dim_account` 字段在既有脚本中主要使用 `id/account_type/type/system_type`，本方案额外使用 `verified_name/status`，执行前需确认目标环境字段名一致。
- Flink CDC 对多来源聚合维表的精确撤回依赖 connector changelog 能力；生产上建议定期用 batch 重刷兜底。
