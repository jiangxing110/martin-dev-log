# PD-3026 API 接口前缀整改开发记录

- 日期：2026-10-29
- 仓库：`/Users/martinjiang/IdeaProjects/qbit-assets`
- 分支：`jx/26/sprint-19/PD-3026/api-prefix`
- 本次范围：只修改 qbit-assets 后端；按用户要求未修改 `qbit-admin-v3`、`qbit_admin`、`qbit_web`。

## 本次变更

### BI 与 Drools Admin 路由

对涉及清单接口的 Controller 调整类级路由前缀，并将 Admin Controller 移入 `com.qbit.admin` 包。一个 Controller 下有多个相关接口时，按类级前缀统一迁移，因此该 Controller 下的其它方法也随之使用新前缀。

- BI board：`DashBoardController`、`BaasCustomerRetentionController`、`CustomerRetentionController` 调整到 `/api/admin/bi/...`。
- BI 统计：`DwsDashBoardController`、`GlobalAccountController`、`QbitCardController`、`SalesEarningDashBoardController`、`SaleQbitCardCustomerController`、`SaleQbitCardHealthCustomerController` 调整到 `/api/admin/bi/...`。
- Drools：`ControlWarningRuleController` 与 `RiskRatingController` 移入 `com.qbit.admin.drools.controller`，前缀分别调整为 `/api/admin/drools/control-warning`、`/api/admin/drools/risk-rating`。方法实现及方法级 `@NoAuth` 配置保留。

### 量子卡统计

- 修改已有 `AdminQbitCardStatisticsController`，为退款失败、退款笔数、退款金额、失败率、退款率五项接口增加清单所需的 camelCase Admin 路由，同时保留 Controller 原有 kebab-case Admin 路由。
- 商户 `QbitCardStatisticsController` 保留五项方法的原 `@PostMapping` 与登录校验；既有 Admin Controller 同时提供五项新 Admin URL。

- 五个商户 URL 与五个 Admin URL 均注册；Admin 调用方仍需在后续前端任务切换到新 Admin URL。


### 共享能力与独立 Admin 入口

- 新增 `AdminGoogleAuthController`，提供 `/api/admin/core/google/getSecretKey`、`getQrcode`、`checkCode`；原商户 Google 路由保留。
- 新增 `AdminCustomerSettleController`，提供 `/api/admin/statement/customer-settle`；抽取 `CustomerSettleExportService` 供 Admin 与商户入口复用，原商户 customer-settle 路由保留。
- 新增 `AdminAjCaptchaController`，提供 `/api/admin/ajCaptcha/get`、`check`；使用 `@NoAuth` 保留登录前调用能力，原验证码商户路由保留。Admin 前缀上的 IP 白名单仍需由网关/WAF 策略保障，`@NoAuth` 本身不做 IP 校验。
- 新增 `AdminTranslateController`，提供 `/api/admin/core/translate`；商户 `TranslateController` 保留原 POST 映射，`/api/core/translate/translate-form` 保留。
- CaaS onboarding card-bin 已存在 Admin 路由，本次后端不重复新增；员工 sales/ams 路径原已符合 `/api/admin/...`。

### 未处理项

- 清单中的两条 `/api/assets/internal/convert/...` 完整路由未在当前 Assets 源码中找到，本次没有删除其它 convert 映射。
- 量子卡五项商户 URL 保留，Admin 新 URL 同时提供；前端代码按本次范围未改。


## 验证记录

- `mvn -pl qbit-core -am -DskipTests test-compile`：通过。`qbit-core` 主源码与测试源码均编译成功（主源码 10,253 个，测试源码 379 个）。Maven 输出包含现有 systemPath 依赖告警及部分 deprecated/unchecked 警告。
- `git diff --check`：通过。
- 源码路由核对：未发现旧 `/api/bi/board`、`/api/drools/control-warning`、`/api/drools/risk-rating` Controller 前缀残留。
- 本次只做编译，没有执行测试用例；没有提交或推送。

## 工作区说明

Controller 跨目录移动在未暂存状态下由 Git 显示为旧路径删除、新路径未跟踪；这是文件移动的工作区表现，不代表 Controller 业务代码被删除。新路径文件保留相应方法实现，具体前缀调整见以上记录。

## 文件变更逐项清单

以下清单按本次 `git status --short` 核对，覆盖仓库内全部 32 个变更路径（11 个旧路径删除、16 个新路径、5 个修改文件）。Controller 移动按“旧路径 → 新路径”合并记录；未暂存时 Git 会分别显示为删除和未跟踪新增。

### Controller 路径迁移：旧文件 → 新文件

1. `qbit-core/src/main/java/com/qbit/merchant/analysis/controller/board/DashBoardController.java` → `qbit-core/src/main/java/com/qbit/admin/analysis/controller/board/DashBoardController.java`：包从 merchant 改到 admin；类级路由 `/api/bi/board` 改为 `/api/admin/bi/board`，Controller 下所有映射随之迁移。
2. `qbit-core/src/main/java/com/qbit/merchant/analysis/controller/board/BaasCustomerRetentionController.java` → `qbit-core/src/main/java/com/qbit/admin/analysis/controller/board/BaasCustomerRetentionController.java`：移入 Admin 包；retention 路由改为 `/api/admin/bi/baas/retention`。
3. `qbit-core/src/main/java/com/qbit/merchant/analysis/controller/board/CustomerRetentionController.java` → `qbit-core/src/main/java/com/qbit/admin/analysis/controller/board/CustomerRetentionController.java`：移入 Admin 包；customer retention 路由改为 `/api/admin/bi/customer/retention`。
4. `qbit-core/src/main/java/com/qbit/merchant/analysis/controller/DwsDashBoardController.java` → `qbit-core/src/main/java/com/qbit/admin/analysis/controller/DwsDashBoardController.java`：移入 Admin analysis 包；类级路由 `/api/bi/dashBoard` 改为 `/api/admin/bi/dashBoard`，该 Controller 的全部映射随之迁移。
5. `qbit-core/src/main/java/com/qbit/merchant/analysis/controller/crm/GlobalAccountController.java` → `qbit-core/src/main/java/com/qbit/admin/analysis/controller/crm/GlobalAccountController.java`：移入 Admin CRM 包；类级 `/api/bi` 前缀改为 `/api/admin/bi`。
6. `qbit-core/src/main/java/com/qbit/merchant/analysis/controller/crm/QbitCardController.java` → `qbit-core/src/main/java/com/qbit/admin/analysis/controller/crm/QbitCardController.java`：移入 Admin CRM 包；类级 `/api/bi` 前缀改为 `/api/admin/bi`。
7. `qbit-core/src/main/java/com/qbit/merchant/analysis/controller/sales/SalesEarningDashBoardController.java` → `qbit-core/src/main/java/com/qbit/admin/analysis/controller/sales/SalesEarningDashBoardController.java`：移入 Admin sales 包；路由前缀改为 `/api/admin/bi/sales/earning`。
8. `qbit-core/src/main/java/com/qbit/merchant/analysis/controller/sales/SaleQbitCardCustomerController.java` → `qbit-core/src/main/java/com/qbit/admin/analysis/controller/sales/SaleQbitCardCustomerController.java`：移入 Admin sales 包；路由前缀改为 `/api/admin/bi/sales/qbitCard/customer`。
9. `qbit-core/src/main/java/com/qbit/merchant/analysis/controller/sales/SaleQbitCardHealthCustomerController.java` → `qbit-core/src/main/java/com/qbit/admin/analysis/controller/sales/SaleQbitCardHealthCustomerController.java`：移入 Admin sales 包；路由前缀改为 `/api/admin/bi/sales/qbitCard/health`。
10. `qbit-core/src/main/java/com/qbit/drools/controller/ControlWarningRuleController.java` → `qbit-core/src/main/java/com/qbit/admin/drools/controller/ControlWarningRuleController.java`：移入 `com.qbit.admin.drools.controller`；路由前缀改为 `/api/admin/drools/control-warning`，接口方法与方法级注解保留。
11. `qbit-core/src/main/java/com/qbit/drools/controller/RiskRatingController.java` → `qbit-core/src/main/java/com/qbit/admin/drools/controller/RiskRatingController.java`：移入 `com.qbit.admin.drools.controller`；路由前缀改为 `/api/admin/drools/risk-rating`，接口方法与方法级注解保留。

### 新增文件

1. `qbit-core/src/main/java/com/qbit/admin/google/AdminGoogleAuthController.java`：新增 Admin Google 验证码控制器，映射 `getSecretKey`、`getQrcode`、`checkCode` 三个 Admin 路由；复用现有 Google 验证服务。
2. `qbit-core/src/main/java/com/qbit/admin/security/captchas/controller/AdminAjCaptchaController.java`：新增 Admin 验证码控制器，映射 `/api/admin/ajCaptcha/get` 和 `/check`；保留免登录入口语义并复用验证码服务。
3. `qbit-core/src/main/java/com/qbit/admin/statement/AdminCustomerSettleController.java`：新增 Admin 客户对账单导出控制器，映射 `/api/admin/statement/customer-settle`，调用共享导出服务。
4. `qbit-core/src/main/java/com/qbit/admin/system/controller/AdminTranslateController.java`：新增 Admin 翻译入口，映射 `/api/admin/core/translate`，复用翻译服务。
5. `qbit-core/src/main/java/com/qbit/common_all/report/service/CustomerSettleExportService.java`：新增商户/Admin 共用的客户对账单导出协作者，统一填充账户、登记待导出文件并加入导出队列。

### 修改文件

1. `qbit-core/src/main/java/com/qbit/admin/analysis/controller/statistics/AdminQbitCardStatisticsController.java`：为五个既有 Admin 统计方法增加清单要求的 camelCase 路由别名（`refundAndFail`、`cycleRefundCount`、`cycleRefundSum`、`cycleFailRate`、`cycleRefundRate`）；原 Admin kebab-case 路由保留。
2. `qbit-core/src/main/java/com/qbit/merchant/analysis/controller/statistics/QbitCardStatisticsController.java`：五个统计方法保留商户 `@PostMapping` 和 `@NoAuth(NoAuth.LOGIN)`；Admin 新路由由既有 Admin Controller 提供。

3. `qbit-core/src/main/java/com/qbit/merchant/analysis/controller/statistics/QbitStatementController.java`：商户 customer-settle 入口改为显式注入 `@CurrentUser User` 并调用 `CustomerSettleExportService`；删除 Controller 内重复的队列入队逻辑，商户 URL 保留。
4. `qbit-core/src/main/java/com/qbit/merchant/TranslateController.java`：保留根 POST 翻译方法的 `@PostMapping`，同时保留 `translate-form` 映射。
5. `qbit-core/src/test/java/com/qbit/analysis/controller/DashBoardControllerTest.java`：测试导入改为 Admin 包下的 `DashBoardController`，跟随 Controller 包迁移。

### 本开发记录文件

- `2026-10-29-api-prefix-dev-log.md`：记录本次范围、逐文件变更、验证和未处理项；文件位于 `/Users/martinjiang/VsCodeProjects/martin-dev-log/qbit-assets/sprint-19/修改api接口前缀/`。

## 鉴权补充说明

量子卡统计的退款失败、退款笔数、退款金额、失败率、退款率五个接口均有商户旧 URL 和 Admin 新 URL。两侧均保留 `@NoAuth(NoAuth.LOGIN)`，即校验登录 token，并非免登录。


## 路由保留修正（后续澄清）

更正前文量子卡统计相关的“旧商户 URL 已移除/不再注册”描述：用户未要求下线这些接口。当前代码已恢复 `QbitCardStatisticsController` 五个方法的原商户 `@PostMapping`，并保留 `@NoAuth(NoAuth.LOGIN)` 登录校验；`AdminQbitCardStatisticsController` 的五个 Admin 新路由及相同登录校验也保留。因此商户旧 URL 和 Admin 新 URL 均可用。前端仓库没有修改，Admin 调用方后续仍需切换到新 Admin URL。

## 翻译接口路由保留修正（后续澄清）

更正前文翻译接口相关描述：`qbit-core/src/main/java/com/qbit/merchant/TranslateController.java` 的根 POST 商户路由继续保留；`AdminTranslateController` 提供独立 `/api/admin/core/translate` 路由。此前移除商户 `@PostMapping` 的做法已撤销。商户 `translate-form` 路由也保持不变。

## 接口变更汇总与对接清单

本次按 PD-3026 86 项范围记录：BI board 6 项；共享接口 7 项；BI/Drools/quantum-card 等 71 项（其中 employees/sales、employees/ams 已符合 Admin 前缀）；internal convert 待定位 2 项。五个量子卡统计接口保留商户路由并提供 Admin 新路由；翻译接口也保留商户根 POST 路由并提供 Admin 新路由。Google、客户对账单、滑块验证码按商户/Admin 双入口处理；CaaS Admin 路由原已存在。

接口级旧/新路径、HTTP 方法、qbit-web 使用情况、待前端切换项已逐条列在 `2026-10-29-api-prefix-integration.md`。本次没有修改任何前端仓库。
