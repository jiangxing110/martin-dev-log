# 销售毛利详情改用日期范围筛选设计

## 摘要

销售毛利详情分页和详情导出不再要求前端传 `settlementMonth`，由 `reportDateRange` 作为唯一日期条件。日期范围可以跨月；读取快照时，对范围覆盖的每个结算月分别选择最新 `snapshot_date`，再按 `report_date` 闭区间过滤并汇总。汇总分页和汇总导出继续使用 `settlementMonth`。

## 现状

- 四个接口共用 `SalesGrossProfitQueryDTO`，其中 `settlementMonth` 当前为必填字段。
- 详情快照查询通过 `settlementMonth` 选定一个月份及其最新快照版本；详情估算查询也按它限制月份。
- 详情导出复用详情请求条件，并循环调用详情分页。
- 详情按客户根账户、产品和渠道聚合；销售与账户信息仍由服务层回填。

## 目标行为

- 详情分页 `/detail` 与详情导出 `/detail/export` 请求使用 `reportDateRange`、`saleId`、分页字段及已有可选明细筛选字段，不要求 `settlementMonth`。
- `reportDateRange` 的首尾日期均包含；跨月范围覆盖的每个结算月分别取该月最大有效 `snapshot_date`，合并对应快照数据后再按 `report_date` 过滤。
- 生产估算视图的详情查询只按 `reportDateRange` 过滤日期，不再用单个结算月缩窄结果。
- 明细结果继续以 `saleId + rootAccountId + product + provider` 聚合，按 `cashflowGpSale` 降序，负值保持原值。
- 汇总分页 `/page` 和汇总导出 `/export` 的 `settlementMonth` 必填规则及查询口径保持不变。
- 详情导出文件名不再追加 `settlementMonth`，保留既有用户 ID 与时间前缀、报表名称和销售标识。
- 对接文档同步更新详情分页及详情导出示例和日期筛选说明。

## 实现边界

- 将汇总请求和详情请求拆分为独立 DTO，避免详情接口 Swagger schema 继续暴露必需的 `settlementMonth`；详情导出 DTO 继承或组合详情查询参数。
- Service、Mapper 方法及生产/本地 XML 一起调整。生产和本地查询都使用同一套“日期范围覆盖月份的最新快照”规则；生产无可用快照时，沿用当前生产估算回退策略，但按完整日期范围查询。
- 维持 `@DataScope("root_account_id")` 权限过滤，不增加 user/account SQL 关联。
- 四个接口的前端 `reportDateRange` 保持 `yyyy-MM-dd`，后端内部转换为开始日 `00:00:00` 和结束日 `23:59:59`；来源及快照 `report_date` 是 `DATE`，数据库筛选仍按日粒度。
- 不修改快照表结构、快照生成逻辑、汇总接口、毛利公式或账户信息回填。

## 验收重点

- 详情分页及详情导出可省略 `settlementMonth`，且 OpenAPI 请求模型不要求该字段。
- 单月日期范围只使用该月最新快照；跨月范围分别使用每月最新快照，并只累计范围内的 `report_date`。
- 生产估算路径、非生产空快照路径及 root account 数据权限维持预期行为。
- 汇总分页与汇总导出仍要求并使用 `settlementMonth`。
- 对接文档示例与接口实际请求模型一致。
