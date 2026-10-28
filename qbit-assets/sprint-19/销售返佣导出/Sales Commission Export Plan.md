# 销售佣金明细异步导出开发方案

## 目标

在 `SaleCommissionController` 增加销售佣金明细异步导出接口。根据目标销售所属部门生成对应 Excel：海外销售二部导出独立的五列表格，其他部门导出按产品拆分的四个 sheet。

## 接口与异步方式

- 接口：`POST /api/admin/sale/commission/export`，使用现有 `SaleCommissionQueryDTO`（`saleId`、`settlementMonth`）。
- Controller 采用 `HttpServletRequest`、`HttpServletResponse` 和 `void` 返回，调用佣金服务发起导出。
- 参考 `AdminBalanceController` 的 `POST /snapshot/export`：接入 `ExportEnum`、`ReportFactory` 和 `AbstractReportHandler`，异步生成 Excel，经现有 `ExportService` 上传，并按现有导出通知流程告知用户下载；不在当前 HTTP 响应中同步写文件。
- 任务启动和异步执行都遵循销售佣金看板的数据权限校验；异步任务恢复发起人的 `UserContext`。

## 数据来源与字段映射

- 按 `saleId + settlementMonth` 检查发薪快照；存在时读取 `dws_sales_commission_snapshot_detail_p`，不存在时读取已有预估视图 `dws.mv_sales_commission_recent_estimate`。环境对应生产/本地 mapper 的选择沿用现有看板服务。
- 使用来源中的 `product`、`provider`、`effective_revenue`、`cogs`、`gp`、`active_days`、`commission_rate` 和佣金金额；快照用 `commission_amount`，预估视图用 `estimated_commission`。不在导出时重算金额。
- 客户名称：通过 `root_account_id` 关联 `account.id`，沿用账户字段 `verifiedName`（缺失时可回退 `verifiedNameEn`）。
- 销售名称：通过 `sale_id` 关联 `"user".id`，沿用系统用户 `nickname`。
- 激活时间：通过 `root_account_id` 关联 `dim.dim_account_analysis.account_id`，按产品读取 `qbit_card -> card_active_time`、`group_account -> global_active_time`、`crypto -> crypto_active_time`、`open_api -> api_active_time`；这些原始时间不在佣金视图输出中，需补查维度表。视图已输出对应的 `active_days`。

## 导出规则

- 根据明细中的部门 ID 判定模板。海外销售二部 ID 为 `1851130772357509121`。
- **海外销售二部使用特殊表头**：只导出一个 sheet，表头固定且仅包含“客户名称、销售、毛利、费率、提成”；不得追加其他部门使用的渠道、有效收入、成本、激活时间、激活天数等列。字段映射为账户 `verifiedName`、销售 `nickname`、`gp`、`commission_rate` 和佣金金额。
- 其他部门导出四个 sheet，产品映射为 `qbit_card -> 量子卡`、`group_account -> 全球账户`、`crypto -> 加密资产`、`open_api -> API`。每个 sheet 的表头为“客户名称、销售、渠道、有效收入、成本、毛利、激活时间、激活天数、费率、提成”。
- API sheet 仅查询 `product = 'open_api'`、`commission_stage = 'current_payout'` 且 `NULLIF(TRIM(provider), '') IS NULL` 的记录。视图将 `month_receivable` 记为 `future_payout`，因此该条件会排除应收记录，同时保留无渠道实收记录（如月费实收、历史账单实收及线下 API 实收）。

## 实现范围

1. 在 `SaleCommissionController` 增加异步导出入口，在 `SaleCommissionService` 增加发起导出的方法。
2. 扩展 `ExportEnum` 并新增销售佣金导出 Handler，注册到 `ReportFactory`，使用通用异步导出和通知链路。
3. 在销售佣金 Mapper 及 XML 增加明细查询，支持快照和预估视图两种来源及账户/用户/激活维度字段补齐。
4. 新增 Excel 行对象/转换器，分别输出海外销售二部的五列表头和其他部门的四个十列表头 sheet。
5. 补充成功导出、无快照回退视图、部门模板、API 实收过滤和权限拒绝的测试。

## 已确认的方案选择

- 已固化快照优先；快照不存在时查询已有预估视图。
- 导出采用异步任务、上传文件并通知用户的仓库既有模式。
- 海外销售二部使用独立的五列表头；其他部门使用产品拆分的四个十列表头 sheet。
