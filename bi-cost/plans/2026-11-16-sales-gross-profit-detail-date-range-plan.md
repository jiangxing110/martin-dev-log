# 销售毛利详情日期范围筛选实施计划

> **For agentic workers:** 按任务步骤实现并核对；遵守不编译、不提交、不推送的要求。

**Goal:** 让销售毛利详情分页和详情导出只依赖 `reportDateRange`，支持跨月逐月使用最新快照。

**Architecture:** 汇总继续使用含 `settlementMonth` 的现有查询 DTO；详情新增独立请求 DTO。Service、Mapper 契约和生产/本地 XML 依据详情日期范围选择每个结算月的最新快照，生产估算路径只按报告日期范围过滤。同步详情导出文件命名和接口文档。

**Tech Stack:** Java 17, Spring Boot, MyBatis-Plus, MyBatis XML, Markdown。

**Spec:** `design-docs/2026-11-16-sales-gross-profit-detail-date-range-design.md`

## Global Constraints

- 汇总分页与汇总导出仍要求 `settlementMonth`，不改变查询口径。
- 详情分页及详情导出不要求也不暴露 `settlementMonth`。
- `reportDateRange` 首尾包含；跨月时对范围覆盖的每个结算月分别选择最大有效 `snapshot_date`。
- 四个接口的前端 `reportDateRange` 保持 `yyyy-MM-dd`；后端转换为当天 `00:00:00` 到 `23:59:59`。数据库 `report_date` 为 `DATE`，按日粒度过滤。
- 保持 `@DataScope("root_account_id")`、当前账户信息回填方式和毛利排序。
- 不改快照表结构或生成逻辑；不编译、不运行测试、不执行数据库 SQL、不提交或推送。

## Review Focus

- 日期范围部分跨月时，快照月份边界按 `reportDateRange` 的月份首尾正确计算。
- 快照版本按结算月分别选择，避免跨月时用一个全局 `MAX(snapshot_date)` 混版本或漏月。
- 生产估算与本地快照查询保持相同的日期范围语义及数据权限。
- 导出 DTO 复制全部详情筛选条件；分页循环和 CSV 命名不再依赖结算月。
- 汇总接口请求 Schema 和行为不受详情 DTO 拆分影响。

### Task 1: 拆分汇总与详情请求模型并调整服务契约

**Files:**
- Create: `qbit-core/src/main/java/com/qbit/common_all/analysis/domain/dto/salesgrossprofit/SalesGrossProfitDetailQueryDTO.java`
- Modify: `qbit-core/src/main/java/com/qbit/admin/analysis/controller/reportform/v2/SalesGrossProfitController.java`
- Modify: `qbit-core/src/main/java/com/qbit/common_all/analysis/service/salesgrossprofit/SalesGrossProfitService.java`
- Modify: `qbit-core/src/main/java/com/qbit/common_all/analysis/service/impl/salesgrossprofit/SalesGrossProfitServiceImpl.java`
- Modify: `qbit-core/src/main/java/com/qbit/common_all/assets/service/report/salesgrossprofit/SalesGrossProfitDetailExportDTO.java`

- [x] 独立详情 DTO，仅保留分页、reportDateRange、saleId、rootAccountId、product 和服务端数据权限字段。
- [x] 将详情分页及详情导出 Controller/Service 入参切换为详情 DTO；汇总端保留现 DTO。
- [x] 按已有行为校验日期范围与 saleId；详情导出 DTO 复制所有详情字段。
- [x] 快照完整性判定按 reportDateRange 覆盖月份处理；生产缺少完整快照时回退估算，非生产缺少时返回空页。

### Task 2: 调整详情 Mapper 与两套 XML

**Files:**
- Modify: `qbit-core/src/main/java/com/qbit/common_all/analysis/mapper/dws/SalesGrossProfitMapper.java`
- Modify: `qbit-core/src/main/java/com/qbit/common_all/analysis/mapper/dws/DwsSalesGrossProfitMapper.java`
- Modify: `qbit-core/src/main/java/com/qbit/common_all/analysis/mapper/dws/DwsLocalSalesGrossProfitMapper.java`
- Modify: `qbit-core/src/main/resources/mapper/dws/DwsSalesGrossProfitMapper.xml`
- Modify: `qbit-core/src/main/resources/mapper/dws/DwsLocalSalesGrossProfitMapper.xml`

- [x] 详情 Mapper 查询改收详情 DTO；新增日期范围快照可用性查询，汇总 `countSnapshot` 继续保留原接口。
- [x] 快照明细通过按 `settlement_month` 分组的最新快照集合连接/过滤明细，并应用 `reportDateRange`。
- [x] 估算明细移除 `settlement_month` 条件，使用 `reportDateRange` 与既有销售、账户及产品条件。
- [x] 保留 XML `<where>`、账户 DataScope、销售权限过滤、聚合列和 `cashflowGpSale` 降序。

### Task 3: 更新详情导出和对接文档

**Files:**
- Modify: `qbit-core/src/main/java/com/qbit/common_all/assets/service/report/salesgrossprofit/SalesGrossProfitDetailCsvHandler.java`
- Modify: `qbit-assets/sprint-19/销售毛利报表/销售毛利报表前后端对接文档.md`

- [x] 详情 CSV 命名去掉 `settlementMonth`，其他文件名前缀和销售标识保持不变。
- [x] 更新详情分页、详情导出请求字段说明和 JSON 示例，汇总示例继续保留 `settlementMonth`。
- [x] 更新数据来源说明，写明跨月日期范围按每个结算月最新快照筛选。
- [x] 保持四个接口前端 `reportDateRange` 类型及格式不变；新增服务端起止时刻转换，并更新字段说明。

### Task 4: 静态核对

- [x] 检查 Controller、Service、Mapper、DTO、XML 参数名和类型一致。
- [x] 搜索详情接口请求和导出代码中的残留 `settlementMonth` 引用；确认只剩汇总路径或响应字段用途。
- [x] 运行 `git diff --check` 和 XML well-formedness 检查；不编译、不运行测试、不执行数据库 SQL。
