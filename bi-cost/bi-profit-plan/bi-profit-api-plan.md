# BI Profit API Plan

## 1. 目标

在现有 BI 看板体系中新增“毛利能力”接口方案，和已有的：

- `AdminRevenueController`
- `AdminTPVController`

保持同一风格，但毛利模块独立成单独控制器，避免收入和毛利逻辑继续耦合。

本次方案覆盖首页“第一阶段一变现与业务健康度”里和毛利相关的组件：

1. 毛利卡片
2. 毛利率卡片
3. 各产品的有效收入与毛利 & COGS
4. 各产品的费率 & 毛利率
5. 收入 vs 毛利趋势
6. 按毛利 Top 客户

## 2. 已确认口径

### 2.1 数据来源

收入输入：

- `dws.vw_profit_revenue_daily`

成本输入：

- `dws.dws_total_channel_cost_daily_p`

毛利明细表：

- `dws.dws_gross_profit_daily_p`

### 2.2 毛利口径

- `COGS = dws_total_channel_cost_daily_p` 中按产品线映射后的渠道成本
- `gross_profit = revenue_amount - channel_cost_amount`
- `gross_margin = gross_profit / revenue_amount`

### 2.3 产品线映射

收入侧 `category` 和成本桶映射关系：

- `qbit_card -> quantum_cost`
- `global_account -> business_cost`
- `crypto_assets -> crypto_cost`
- `particle_financing -> 0`
- `company_registration -> 0`
- `offline_order -> 0`

说明：

- 本期方案先不把 `acquiring_cost` 映射进来
- 如果后续首页产品线新增“收单”独立卡片或图表，再补 `acquiring -> acquiring_cost`

## 3. 和现有后端风格的对齐结论

### 3.1 Controller 风格

现有 BI Controller 风格：

- `AdminTPVController`
- `AdminRevenueController`

特点：

- `@RestController`
- `@RequestMapping("/api/admin/...")`
- 直接接 `StatisticsQueryDTO`
- 返回 `Result<T>`
- Service 放在 `com.qbit.common_all.analysis.service.dws`

因此毛利模块建议新增：

- `AdminProfitController`

路径建议：

- `/api/admin/bi/v2/report-profit`

### 3.2 查询入参

复用已有：

- `StatisticsQueryDTO`

当前字段已经足够支撑毛利首页：

- `beginDate`
- `endDate`
- `compareBeginDate`
- `compareEndDate`
- `products`
- `geographies`
- `currencies`
- `clientSegments`
- `dateType`

注意：

- 现有 `products` 是中文产品名列表
- 毛利底层表使用的是 `category`
- Service 层需要做一层产品名到 `category` 的映射

建议映射：

- `量子卡 -> qbit_card`
- `全球账户 -> global_account`
- `加密资产 -> crypto_assets`
- `粒子理财 -> particle_financing`
- `公司注册收入 -> company_registration`
- `线下订单收入 -> offline_order`

## 4. 和前端形态的对齐结论

### 4.1 前端不是所有图都能复用 `BarChartVO`

现有 `BarChartVO` 只有：

- `label`
- `value`

只适合单指标柱状图。

而首页毛利屏至少包含：

- 多指标柱状图
- 双指标横向对比
- 趋势折线
- Top 客户表格
- 汇总卡片

所以本次不建议硬复用 `BarChartVO`，应为毛利模块定义专用 VO。

### 4.2 前端页面组织方式

从 `qbit-admin-v3` 现有 dashboard 页面看，前端普遍是：

1. 页面 `index.tsx`
2. `hook` 调接口
3. `hook` 再把接口结果转成页面需要的 shape

这意味着：

- 后端 VO 要稳定、清晰
- 但不需要为了页面细节把 VO 过度拼装成 UI 专属字段

建议后端返回“业务稳定结构”，前端 hook 再做轻量映射。

## 5. 接口方案

建议新增独立控制器：

- `AdminProfitController`

### 5.1 毛利总览卡片

接口：

- `GET /api/admin/bi/v2/report-profit/stat-gross-profit-summary`

用途：

- 页面顶部“毛利”和“毛利率”两张卡片

返回 VO：

- `GrossProfitSummaryVO`

字段建议：

- `grossProfit`
- `grossProfitCompare`
- `grossProfitGrowthRate`
- `grossMargin`
- `grossMarginCompare`
- `grossMarginChange`

说明：

- `grossProfitGrowthRate` 用于“vs 上期 +14.8%”
- `grossMarginChange` 用于“+4.0 个百分点”

### 5.2 收入 vs 毛利趋势

接口：

- `GET /api/admin/bi/v2/report-profit/trend-revenue-vs-profit`

用途：

- “收入 vs 毛利趋势”折线图

返回 VO：

- `List<RevenueProfitTrendVO>`

字段建议：

- `date`
- `effectiveRevenue`
- `grossProfit`

说明：

- 前端直接画两条线
- `dateType` 默认按日

### 5.3 各产品有效收入 / 毛利 / COGS

接口：

- `GET /api/admin/bi/v2/report-profit/product-income-profit-cogs`

用途：

- “各产品的有效收入与毛利 & COGS（产品成本）”

返回 VO：

- `List<ProductIncomeProfitCogsVO>`

字段建议：

- `category`
- `productName`
- `effectiveRevenue`
- `grossProfit`
- `cogs`

说明：

- 前端可以直接按 `productName` 做分组柱状图
- `cogs = channel_cost_amount`

### 5.4 各产品费率 & 毛利率

接口：

- `GET /api/admin/bi/v2/report-profit/product-fee-rate-margin`

用途：

- “各产品的费率 & 毛利率”

返回 VO：

- `List<ProductFeeRateMarginVO>`

字段建议：

- `category`
- `productName`
- `feeRate`
- `grossMargin`

公式：

- `feeRate = cogs / effectiveRevenue`
- `grossMargin = grossProfit / effectiveRevenue`

### 5.5 按毛利 Top 客户

接口：

- `GET /api/admin/bi/v2/report-profit/top-profit-accounts`

用途：

- “按毛利 Top 客户”

返回 VO：

- `List<ProfitAccountRankingVO>`

VO 设计建议：

- 参考 `QuantumAccountRankingVO`
- 实现 `IAccount`

字段建议：

- `accountId`
- `displayId`
- `verifiedName`
- `accountType`
- `systemType`
- `grossProfitAmount`
- `profitShare`
- `growthRate`
- `riskLevel`
- `ranking`

说明：

- `accountId` 是账户信息补全主键
- `displayId`、`verifiedName` 由账户信息增强逻辑补齐
- `profitShare = 客户毛利 / 总毛利`
- `growthRate = 当前周期 vs 对比周期`
- `riskLevel` 当前如果没有稳定规则，可以先返回空或默认值，不建议本期硬编码算法

## 6. 后端分层建议

### 6.1 Controller

新增文件：

- `com.qbit.admin.analysis.controller.AdminProfitController`

方法建议：

- `grossProfitSummary(StatisticsQueryDTO dto)`
- `revenueVsProfitTrend(StatisticsQueryDTO dto)`
- `productIncomeProfitCogs(StatisticsQueryDTO dto)`
- `productFeeRateMargin(StatisticsQueryDTO dto)`
- `topProfitAccounts(StatisticsQueryDTO dto)`

### 6.2 Service

接口：

- `com.qbit.common_all.analysis.service.dws.DwsProfitService`

实现：

- `com.qbit.common_all.analysis.service.impl.dws.DwsProfitServiceImpl`

方法建议：

- `GrossProfitSummaryVO queryGrossProfitSummary(StatisticsQueryDTO dto)`
- `List<RevenueProfitTrendVO> queryRevenueProfitTrend(StatisticsQueryDTO dto)`
- `List<ProductIncomeProfitCogsVO> queryProductIncomeProfitCogs(StatisticsQueryDTO dto)`
- `List<ProductFeeRateMarginVO> queryProductFeeRateMargin(StatisticsQueryDTO dto)`
- `List<ProfitAccountRankingVO> queryTopProfitAccounts(StatisticsQueryDTO dto)`

### 6.3 Mapper

建议新增：

- `DwsGrossProfitDailyMapper`

对应查询对象：

- 主查 `dws_gross_profit_daily_p`
- 必要时 join 账户维度增强信息

建议不要直接在 Controller 或 Service 里拼大量 SQL。

## 7. 数据库查询建议

### 7.1 统一过滤层

所有接口都应复用统一过滤逻辑：

- 主时间范围：`beginDate ~ endDate`
- 对比时间范围：`compareBeginDate ~ compareEndDate`
- 产品线：`products -> category`
- 账户类型：`clientSegments`

其中：

- `geographies`
- `currencies`

由于当前毛利底层表不天然具备有效地区/币种维度，建议本期处理方式：

- Service 层接收但不生效，文档中明确“当前毛利数据固定 USD / 不支持 geography 精准过滤”

### 7.2 汇总卡片 SQL 思路

当前周期：

- 汇总 `sum(gross_profit_amount)`
- 汇总 `sum(revenue_amount)`
- `gross_margin = sum(gross_profit_amount) / sum(revenue_amount)`

对比周期：

- 同样计算一份

增长：

- `grossProfitGrowthRate = (current - compare) / compare`
- `grossMarginChange = currentMargin - compareMargin`

### 7.3 产品收入/毛利/COGS SQL 思路

按 `category` 分组：

- `sum(revenue_amount)`
- `sum(channel_cost_amount)`
- `sum(gross_profit_amount)`

### 7.4 产品费率/毛利率 SQL 思路

按 `category` 分组：

- `feeRate = sum(channel_cost_amount) / sum(revenue_amount)`
- `grossMargin = sum(gross_profit_amount) / sum(revenue_amount)`

### 7.5 趋势 SQL 思路

按 `report_date` 分组：

- `sum(revenue_amount)`
- `sum(gross_profit_amount)`

### 7.6 Top 客户 SQL 思路

按 `account_id` 分组：

- `sum(gross_profit_amount) as grossProfitAmount`
- `sum(revenue_amount)`
- `sum(channel_cost_amount)`

排序：

- `order by grossProfitAmount desc`

限制：

- `limit 30`

增长率：

- 需要对当前周期和对比周期分别聚合再合并

账户信息补全：

- 参考现有 `IAccount` 体系
- 返回后由现有账户增强逻辑补齐 `displayId`、`verifiedName`

## 8. 推荐 VO 清单

建议新增包：

- `com.qbit.common_all.analysis.domain.vo.profit`

文件建议：

- `GrossProfitSummaryVO`
- `RevenueProfitTrendVO`
- `ProductIncomeProfitCogsVO`
- `ProductFeeRateMarginVO`
- `ProfitAccountRankingVO`

### 8.1 GrossProfitSummaryVO

字段：

- `BigDecimal grossProfit`
- `BigDecimal grossProfitCompare`
- `BigDecimal grossProfitGrowthRate`
- `BigDecimal grossMargin`
- `BigDecimal grossMarginCompare`
- `BigDecimal grossMarginChange`

### 8.2 RevenueProfitTrendVO

字段：

- `String date`
- `BigDecimal effectiveRevenue`
- `BigDecimal grossProfit`

### 8.3 ProductIncomeProfitCogsVO

字段：

- `String category`
- `String productName`
- `BigDecimal effectiveRevenue`
- `BigDecimal grossProfit`
- `BigDecimal cogs`

### 8.4 ProductFeeRateMarginVO

字段：

- `String category`
- `String productName`
- `BigDecimal feeRate`
- `BigDecimal grossMargin`

### 8.5 ProfitAccountRankingVO

字段：

- `String accountId`
- `Integer ranking`
- `String displayId`
- `String verifiedName`
- `String accountType`
- `String systemType`
- `BigDecimal grossProfitAmount`
- `BigDecimal profitShare`
- `BigDecimal growthRate`
- `String riskLevel`

建议：

- `implements IAccount`

## 9. 产品名映射建议

后端提供统一映射方法：

- `qbit_card -> 卡`
- `global_account -> 全球账户`
- `crypto_assets -> CryptoConnect`
- `particle_financing -> 资管账户`
- `company_registration -> 公司注册`
- `offline_order -> 收单`

说明：

- 页面展示名应在后端统一返回 `productName`
- 前端不要重复维护一份映射表

## 10. 风险与建议

### 10.1 风险一：收入和成本粒度暂时不带 sale/am

当前方案刻意不带：

- `sale_id`
- `am_id`

原因：

- 本次目标是先打通首页毛利能力
- 收入输入 `vw_profit_revenue_daily` 当前独立设计，未和销售归属完全绑定

建议：

- 首页毛利能力先按 `客户 + 产品线 + 日期` 做
- 后续如果要支持销售/AM 毛利分析，再升级 `dws_gross_profit_daily_p`

### 10.2 风险二：地区/币种筛选无真实支撑

当前毛利层口径更接近：

- `USD`
- `ALL geography`

建议：

- 本期前端保留筛选 UI，但后端文档标注暂不生效
- 或前端在毛利模块隐藏 geography / currency 过滤

### 10.3 风险三：riskLevel 缺少稳定算法

Top 客户中的：

- `riskLevel`

如果首页只是展示，可以先：

- 返回空
- 或基于现有风险标签体系后补

不建议本期为了页面完整性临时造一套不稳定算法。

## 11. 实施顺序建议

### 第一阶段

落后端查询能力：

1. `AdminProfitController`
2. `DwsProfitService`
3. `DwsGrossProfitDailyMapper`
4. 5 个首页接口

### 第二阶段

前端接首页组件：

1. 毛利卡片
2. 毛利率卡片
3. 产品收入/毛利/COGS
4. 产品费率/毛利率
5. 趋势
6. Top 客户

### 第三阶段

补增强能力：

1. geography / currency 维度
2. sale / am 维度
3. 风险等级规则
4. 导出能力

## 12. 最终结论

本次推荐方案是：

- 新建独立 `AdminProfitController`
- 基于 `StatisticsQueryDTO` 复用首页时间筛选能力
- 基于 `dws_gross_profit_daily_p` 提供独立毛利接口
- 不复用 `BarChartVO`，为毛利首页定义专用 VO
- Top 客户接口按 `accountId` 出发，参考 `QuantumAccountRankingVO` / `IAccount` 风格做账户增强

这版方案既能和现有 BI 接口风格保持一致，也不会把毛利继续塞进收入模块里，后面扩展空间更好。
