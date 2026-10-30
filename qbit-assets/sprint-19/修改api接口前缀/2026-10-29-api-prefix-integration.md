# PD-3026 API 前后端对接文档

- 日期：2026-10-29
- 后端仓库：`qbit-assets`
- 当前交付范围：只修改 Assets 后端；`qbit_admin`、`qbit-admin-v3`、`qbit_web` 前端仓库未改。
- 清单来源：`2026-10-29-api-prefix-plan.md` 的 86 条接口项。

## 对接规则

- Admin 页面与 Admin API 封装改用清单中的 `/api/admin/...` 路径。
- qbit-web 对共享能力继续使用原商户路径；Admin 侧通过独立 Admin 路由访问同一业务服务。
- 量子卡退款/失败统计五项在商户旧路径和 Admin 新路径均保留；两侧都校验登录。
- 翻译表单根 POST 接口保留商户旧路径，同时新增 Admin 路径。`translate-form` 原商户映射保持不变。
- 除明确的路径/入口拆分外，HTTP 方法、参数名、请求体、响应结构和业务行为保持不变；动态路径参数原样传递。
- Admin 新路径由网关/WAF 的 `/api/admin/**` 规则纳入白名单策略。`@NoAuth` 只影响应用登录校验，不替代 IP 白名单。

## 86 条接口清单

逐项按原接口、Admin 目标路径、模块、qbit-web 使用情况及原清单备注登记。方括号用于前端联调逐项勾选；清单中的“未发现静态引用”不表示可以跳过 Admin 请求封装迁移。
- [ ] **POST `/api/bi/board/getAuthenticationRate`** → **/api/admin/bi/board/getAuthenticationRate**；模块：BI board；qbit-web：—（未发现 qbit-web 静态引用）；状态：后端 Admin 路径已按清单处理。前端：qbit-admin
- [ ] **POST `/api/bi/board/getCustomerSourceStatistics`** → **/api/admin/bi/board/getCustomerSourceStatistics**；模块：BI board；qbit-web：—（未发现 qbit-web 静态引用）；状态：后端 Admin 路径已按清单处理。前端：qbit-admin
- [ ] **POST `/api/bi/board/getNumberCustomersReceived`** → **/api/admin/bi/board/getNumberCustomersReceived**；模块：BI board；qbit-web：—（未发现 qbit-web 静态引用）；状态：后端 Admin 路径已按清单处理。前端：qbit-admin
- [ ] **POST `/api/bi/board/quantumCardConsumptionSuccessRate`** → **/api/admin/bi/board/quantumCardConsumptionSuccessRate**；模块：BI board；qbit-web：—（未发现 qbit-web 静态引用）；状态：后端 Admin 路径已按清单处理。前端：qbit-admin
- [ ] **POST `/api/bi/board/successRateEachSegment`** → **/api/admin/bi/board/successRateEachSegment**；模块：BI board；qbit-web：—（未发现 qbit-web 静态引用）；状态：后端 Admin 路径已按清单处理。前端：qbit-admin
- [ ] **POST `/api/bi/board/sumAllScenesBlock`** → **/api/admin/bi/board/sumAllScenesBlock**；模块：BI board；qbit-web：—（未发现 qbit-web 静态引用）；状态：后端 Admin 路径已按清单处理。前端：qbit-admin
- [ ] **GET `/api/bi/baas/retention/baas`** → **/api/admin/bi/baas/retention/baas**；模块：BI；qbit-web：—（未发现 qbit-web 静态引用）；状态：后端 Admin 路径已按清单处理。改映射并更新前端；前端：qbit-admin
- [ ] **GET `/api/bi/baas/retention/dashBoard`** → **/api/admin/bi/baas/retention/dashBoard**；模块：BI；qbit-web：—（未发现 qbit-web 静态引用）；状态：后端 Admin 路径已按清单处理。改映射并更新前端；前端：qbit-admin
- [ ] **GET `/api/bi/board/accountKyb`** → **/api/admin/bi/board/accountKyb**；模块：BI board；qbit-web：—（未发现 qbit-web 静态引用）；状态：后端 Admin 路径已按清单处理。改映射并更新前端；前端：qbit-admin
- [ ] **GET `/api/bi/board/accountKyc`** → **/api/admin/bi/board/accountKyc**；模块：BI board；qbit-web：—（未发现 qbit-web 静态引用）；状态：后端 Admin 路径已按清单处理。改映射并更新前端；前端：qbit-admin
- [ ] **GET `/api/bi/board/activate-conversion`** → **/api/admin/bi/board/activate-conversion**；模块：BI board；qbit-web：—（未发现 qbit-web 静态引用）；状态：后端 Admin 路径已按清单处理。改映射并更新前端；前端：qbit-admin
- [ ] **GET `/api/bi/board/businessData`** → **/api/admin/bi/board/businessData**；模块：BI board；qbit-web：—（未发现 qbit-web 静态引用）；状态：后端 Admin 路径已按清单处理。改映射并更新前端；前端：qbit-admin
- [ ] **GET `/api/bi/board/businessDataAssets`** → **/api/admin/bi/board/businessDataAssets**；模块：BI board；qbit-web：—（未发现 qbit-web 静态引用）；状态：后端 Admin 路径已按清单处理。改映射并更新前端；前端：qbit-admin
- [ ] **GET `/api/bi/board/businessDataCard`** → **/api/admin/bi/board/businessDataCard**；模块：BI board；qbit-web：—（未发现 qbit-web 静态引用）；状态：后端 Admin 路径已按清单处理。qbit_admin 已找到请求封装；按清单改 Admin 路径并更新封装，不以页面调用为前置。
- [ ] **GET `/api/bi/board/businessDataCardEarning`** → **/api/admin/bi/board/businessDataCardEarning**；模块：BI board；qbit-web：—（未发现 qbit-web 静态引用）；状态：后端 Admin 路径已按清单处理。qbit_admin 已找到请求封装；按清单改 Admin 路径并更新封装，不以页面调用为前置。
- [ ] **GET `/api/bi/board/businessDataCardProvider`** → **/api/admin/bi/board/businessDataCardProvider**；模块：BI board；qbit-web：—（未发现 qbit-web 静态引用）；状态：后端 Admin 路径已按清单处理。qbit_admin 已找到请求封装；按清单改 Admin 路径并更新封装，不以页面调用为前置。
- [ ] **GET `/api/bi/board/businessDataGlobal`** → **/api/admin/bi/board/businessDataGlobal**；模块：BI board；qbit-web：—（未发现 qbit-web 静态引用）；状态：后端 Admin 路径已按清单处理。改映射并更新前端；前端：qbit-admin
- [ ] **GET `/api/bi/board/businessQuantumByProvider`** → **/api/admin/bi/board/businessQuantumByProvider**；模块：BI board；qbit-web：—（未发现 qbit-web 静态引用）；状态：后端 Admin 路径已按清单处理。改映射并更新前端；前端：qbit-admin
- [ ] **GET `/api/bi/board/cardTransferInfo`** → **/api/admin/bi/board/cardTransferInfo**；模块：BI board；qbit-web：—（未发现 qbit-web 静态引用）；状态：后端 Admin 路径已按清单处理。改映射并更新前端；前端：qbit-admin
- [ ] **GET `/api/bi/board/globalInComes`** → **/api/admin/bi/board/globalInComes**；模块：BI board；qbit-web：—（未发现 qbit-web 静态引用）；状态：后端 Admin 路径已按清单处理。改映射并更新前端；前端：qbit-admin
- [ ] **GET `/api/bi/board/globalTransfer`** → **/api/admin/bi/board/globalTransfer**；模块：BI board；qbit-web：—（未发现 qbit-web 静态引用）；状态：后端 Admin 路径已按清单处理。改映射并更新前端；前端：qbit-admin
- [ ] **GET `/api/bi/board/globalUser`** → **/api/admin/bi/board/globalUser**；模块：BI board；qbit-web：—（未发现 qbit-web 静态引用）；状态：后端 Admin 路径已按清单处理。改映射并更新前端；前端：qbit-admin
- [ ] **GET `/api/bi/board/qbitCardActive`** → **/api/admin/bi/board/qbitCardActive**；模块：BI board；qbit-web：—（未发现 qbit-web 静态引用）；状态：后端 Admin 路径已按清单处理。改映射并更新前端；前端：qbit-admin
- [ ] **GET `/api/bi/board/qbitCardBalance`** → **/api/admin/bi/board/qbitCardBalance**；模块：BI board；qbit-web：—（未发现 qbit-web 静态引用）；状态：后端 Admin 路径已按清单处理。改映射并更新前端；前端：qbit-admin
- [ ] **GET `/api/bi/board/qbitCardStatics/{cardType}`** → **/api/admin/bi/board/qbitCardStatics/{cardType}**；模块：BI board；qbit-web：—（未发现 qbit-web 静态引用）；状态：后端 Admin 路径已按清单处理。改映射并更新前端；前端：qbit-admin
- [ ] **GET `/api/bi/board/qbitCardTransactionStatics/{cardType}`** → **/api/admin/bi/board/qbitCardTransactionStatics/{cardType}**；模块：BI board；qbit-web：—（未发现 qbit-web 静态引用）；状态：后端 Admin 路径已按清单处理。改映射并更新前端；前端：qbit-admin
- [ ] **GET `/api/bi/board/qbitCardTransfer`** → **/api/admin/bi/board/qbitCardTransfer**；模块：BI board；qbit-web：—（未发现 qbit-web 静态引用）；状态：后端 Admin 路径已按清单处理。改映射并更新前端；前端：qbit-admin
- [ ] **GET `/api/bi/board/registration-conversion`** → **/api/admin/bi/board/registration-conversion**；模块：BI board；qbit-web：—（未发现 qbit-web 静态引用）；状态：后端 Admin 路径已按清单处理。改映射并更新前端；前端：qbit-admin
- [ ] **GET `/api/bi/board/subjectRegister`** → **/api/admin/bi/board/subjectRegister**；模块：BI board；qbit-web：—（未发现 qbit-web 静态引用）；状态：后端 Admin 路径已按清单处理。改映射并更新前端；前端：qbit-admin
- [ ] **GET `/api/bi/board/{accountLabel}/connexTransactionStatistics`** → **/api/admin/bi/board/{accountLabel}/connexTransactionStatistics**；模块：BI board；qbit-web：—（未发现 qbit-web 静态引用）；状态：后端 Admin 路径已按清单处理。改映射并更新前端；前端：qbit-admin
- [ ] **GET `/api/bi/board/{accountLabel}/connexTransactionTrend`** → **/api/admin/bi/board/{accountLabel}/connexTransactionTrend**；模块：BI board；qbit-web：—（未发现 qbit-web 静态引用）；状态：后端 Admin 路径已按清单处理。改映射并更新前端；前端：qbit-admin
- [ ] **GET `/api/bi/customer/retention/{retentionProvider}/export`** → **/api/admin/bi/customer/retention/{retentionProvider}/export**；模块：BI；qbit-web：—（未发现 qbit-web 静态引用）；状态：后端 Admin 路径已按清单处理。改映射并更新前端；前端：qbit-admin
- [ ] **GET `/api/bi/dashBoard/qbitCard`** → **/api/admin/bi/dashBoard/qbitCard**；模块：BI；qbit-web：—（未发现 qbit-web 静态引用）；状态：后端 Admin 路径已按清单处理。改映射并更新前端；前端：qbit-admin
- [ ] **GET `/api/bi/globalAccountFirstDeposit/list`** → **/api/admin/bi/globalAccountFirstDeposit/list**；模块：BI；qbit-web：—（未发现 qbit-web 静态引用）；状态：后端 Admin 路径已按清单处理。qbit_admin 已找到请求封装；按清单改 Admin 路径并更新封装，不以页面调用为前置
- [ ] **GET `/api/bi/globalAccountFirstDepositChart`** → **/api/admin/bi/globalAccountFirstDepositChart**；模块：BI；qbit-web：—（未发现 qbit-web 静态引用）；状态：后端 Admin 路径已按清单处理。qbit_admin 已找到请求封装；按清单改 Admin 路径并更新封装，不以页面调用为前置
- [ ] **GET `/api/bi/globalAccountFirstDepositCountChart`** → **/api/admin/bi/globalAccountFirstDepositCountChart**；模块：BI；qbit-web：—（未发现 qbit-web 静态引用）；状态：后端 Admin 路径已按清单处理。qbit_admin 已找到请求封装；按清单改 Admin 路径并更新封装，不以页面调用为前置
- [ ] **GET `/api/bi/qbitCardWalletFirstDeposit/list`** → **/api/admin/bi/qbitCardWalletFirstDeposit/list**；模块：BI；qbit-web：—（未发现 qbit-web 静态引用）；状态：后端 Admin 路径已按清单处理。qbit_admin 已找到请求封装；按清单改 Admin 路径并更新封装，不以页面调用为前置
- [ ] **GET `/api/bi/qbitCardWalletFirstDepositChart`** → **/api/admin/bi/qbitCardWalletFirstDepositChart**；模块：BI；qbit-web：—（未发现 qbit-web 静态引用）；状态：后端 Admin 路径已按清单处理。qbit_admin 已找到请求封装；按清单改 Admin 路径并更新封装，不以页面调用为前置
- [ ] **GET `/api/bi/qbitCardWalletFirstDepositCountChart`** → **/api/admin/bi/qbitCardWalletFirstDepositCountChart**；模块：BI；qbit-web：—（未发现 qbit-web 静态引用）；状态：后端 Admin 路径已按清单处理。qbit_admin 已找到请求封装；按清单改 Admin 路径并更新封装，不以页面调用为前置
- [ ] **GET `/api/bi/sales/earning/assetsInCome`** → **/api/admin/bi/sales/earning/assetsInCome**；模块：BI；qbit-web：—（未发现 qbit-web 静态引用）；状态：后端 Admin 路径已按清单处理。改映射并更新前端；前端：qbit-admin
- [ ] **GET `/api/bi/sales/earning/assetsInComes`** → **/api/admin/bi/sales/earning/assetsInComes**；模块：BI；qbit-web：—（未发现 qbit-web 静态引用）；状态：后端 Admin 路径已按清单处理。改映射并更新前端；前端：qbit-admin
- [ ] **GET `/api/bi/sales/earning/globalAccountInCome`** → **/api/admin/bi/sales/earning/globalAccountInCome**；模块：BI；qbit-web：—（未发现 qbit-web 静态引用）；状态：后端 Admin 路径已按清单处理。改映射并更新前端；前端：qbit-admin
- [ ] **GET `/api/bi/sales/earning/globalAccountInComes`** → **/api/admin/bi/sales/earning/globalAccountInComes**；模块：BI；qbit-web：—（未发现 qbit-web 静态引用）；状态：后端 Admin 路径已按清单处理。改映射并更新前端；前端：qbit-admin
- [ ] **GET `/api/bi/sales/earning/qbitCardInCome`** → **/api/admin/bi/sales/earning/qbitCardInCome**；模块：BI；qbit-web：—（未发现 qbit-web 静态引用）；状态：后端 Admin 路径已按清单处理。改映射并更新前端；前端：qbit-admin
- [ ] **GET `/api/bi/sales/earning/qbitCardInComes`** → **/api/admin/bi/sales/earning/qbitCardInComes**；模块：BI；qbit-web：—（未发现 qbit-web 静态引用）；状态：后端 Admin 路径已按清单处理。qbit_admin 已找到请求封装；按清单改 Admin 路径并更新封装，不以页面调用为前置
- [ ] **GET `/api/bi/sales/earning/quantumEffectiveInComes`** → **/api/admin/bi/sales/earning/quantumEffectiveInComes**；模块：BI；qbit-web：—（未发现 qbit-web 静态引用）；状态：后端 Admin 路径已按清单处理。改映射并更新前端；前端：qbit-admin
- [ ] **GET `/api/bi/sales/qbitCard/customer/consumption`** → **/api/admin/bi/sales/qbitCard/customer/consumption**；模块：BI；qbit-web：—（未发现 qbit-web 静态引用）；状态：后端 Admin 路径已按清单处理。改映射并更新前端；前端：qbit-admin
- [ ] **GET `/api/bi/sales/qbitCard/customer/{accountLabel}/consumption-credit`** → **/api/admin/bi/sales/qbitCard/customer/{accountLabel}/consumption-credit**；模块：BI；qbit-web：—（未发现 qbit-web 静态引用）；状态：后端 Admin 路径已按清单处理。改映射并更新前端；前端：qbit-admin
- [ ] **GET `/api/bi/sales/qbitCard/customer/{accountLabel}/credit-rate`** → **/api/admin/bi/sales/qbitCard/customer/{accountLabel}/credit-rate**；模块：BI；qbit-web：—（未发现 qbit-web 静态引用）；状态：后端 Admin 路径已按清单处理。改映射并更新前端；前端：qbit-admin
- [ ] **GET `/api/bi/sales/qbitCard/customer/{accountLabel}/fail-rate`** → **/api/admin/bi/sales/qbitCard/customer/{accountLabel}/fail-rate**；模块：BI；qbit-web：—（未发现 qbit-web 静态引用）；状态：后端 Admin 路径已按清单处理。改映射并更新前端；前端：qbit-admin
- [ ] **GET `/api/bi/sales/qbitCard/health/consumption`** → **/api/admin/bi/sales/qbitCard/health/consumption**；模块：BI；qbit-web：—（未发现 qbit-web 静态引用）；状态：后端 Admin 路径已按清单处理。改映射并更新前端；前端：qbit-admin
- [ ] **GET `/api/bi/sales/qbitCard/health/consumption-count`** → **/api/admin/bi/sales/qbitCard/health/consumption-count**；模块：BI；qbit-web：—（未发现 qbit-web 静态引用）；状态：后端 Admin 路径已按清单处理。改映射并更新前端；前端：qbit-admin
- [ ] **GET `/api/bi/sales/qbitCard/health/credit-rate`** → **/api/admin/bi/sales/qbitCard/health/credit-rate**；模块：BI；qbit-web：—（未发现 qbit-web 静态引用）；状态：后端 Admin 路径已按清单处理。改映射并更新前端；前端：qbit-admin
- [ ] **GET `/api/bi/sales/qbitCard/health/credit-rate-count`** → **/api/admin/bi/sales/qbitCard/health/credit-rate-count**；模块：BI；qbit-web：—（未发现 qbit-web 静态引用）；状态：后端 Admin 路径已按清单处理。改映射并更新前端；前端：qbit-admin
- [ ] **GET `/api/bi/sales/qbitCard/health/fail-consumption-count-rate`** → **/api/admin/bi/sales/qbitCard/health/fail-consumption-count-rate**；模块：BI；qbit-web：—（未发现 qbit-web 静态引用）；状态：后端 Admin 路径已按清单处理。改映射并更新前端；前端：qbit-admin
- [ ] **GET `/api/bi/sales/qbitCard/health/fail-consumption-rate`** → **/api/admin/bi/sales/qbitCard/health/fail-consumption-rate**；模块：BI；qbit-web：—（未发现 qbit-web 静态引用）；状态：后端 Admin 路径已按清单处理。改映射并更新前端；前端：qbit-admin
- [ ] **POST `/api/bi/board/channel/card/cost`** → **/api/admin/bi/board/channel/card/cost**；模块：BI board；qbit-web：—（未发现 qbit-web 静态引用）；状态：后端 Admin 路径已按清单处理。qbit_admin 已找到请求封装；按清单改 Admin 路径并更新封装，不以页面调用为前置
- [ ] **POST `/api/bi/board/channel/card/trends`** → **/api/admin/bi/board/channel/card/trends**；模块：BI board；qbit-web：—（未发现 qbit-web 静态引用）；状态：后端 Admin 路径已按清单处理。改映射并更新前端；前端：qbit-admin
- [ ] **POST `/api/bi/board/channel/global-account/cost`** → **/api/admin/bi/board/channel/global-account/cost**；模块：BI board；qbit-web：—（未发现 qbit-web 静态引用）；状态：后端 Admin 路径已按清单处理。改映射并更新前端；前端：qbit-admin
- [ ] **POST `/api/bi/board/qbit-channel/record/upload`** → **/api/admin/bi/board/qbit-channel/record/upload**；模块：BI board；qbit-web：—（未发现 qbit-web 静态引用）；状态：后端 Admin 路径已按清单处理。改映射并更新前端；前端：qbit-admin
- [ ] **POST `/api/core/translate`** → **/api/admin/core/translate**；模块：其他；qbit-web：—（未发现 qbit-web 静态引用）；状态：后端 Admin 路径已按清单处理。改映射并更新前端；前端：qbit-admin-v3
- [ ] **POST `/api/drools/control-warning/active`** → **/api/admin/drools/control-warning/active**；模块：Drools；qbit-web：—（未发现 qbit-web 静态引用）；状态：后端 Admin 路径已按清单处理。改映射并更新前端；前端：qbit-admin-v3
- [ ] **POST `/api/drools/control-warning/add`** → **/api/admin/drools/control-warning/add**；模块：Drools；qbit-web：—（未发现 qbit-web 静态引用）；状态：后端 Admin 路径已按清单处理。改映射并更新前端；前端：qbit-admin-v3
- [ ] **POST `/api/drools/control-warning/edit`** → **/api/admin/drools/control-warning/edit**；模块：Drools；qbit-web：—（未发现 qbit-web 静态引用）；状态：后端 Admin 路径已按清单处理。改映射并更新前端；前端：qbit-admin-v3
- [ ] **POST `/api/drools/control-warning/findById`** → **/api/admin/drools/control-warning/findById**；模块：Drools；qbit-web：—（未发现 qbit-web 静态引用）；状态：后端 Admin 路径已按清单处理。改映射并更新前端；前端：qbit-admin-v3
- [ ] **POST `/api/drools/control-warning/rule/logs`** → **/api/admin/drools/control-warning/rule/logs**；模块：Drools；qbit-web：—（未发现 qbit-web 静态引用）；状态：后端 Admin 路径已按清单处理。改映射并更新前端；前端：qbit-admin-v3
- [ ] **POST `/api/drools/control-warning/rule/pages`** → **/api/admin/drools/control-warning/rule/pages**；模块：Drools；qbit-web：—（未发现 qbit-web 静态引用）；状态：后端 Admin 路径已按清单处理。改映射并更新前端；前端：qbit-admin-v3
- [ ] **POST `/api/drools/risk-rating/info`** → **/api/admin/drools/risk-rating/info**；模块：Drools；qbit-web：—（未发现 qbit-web 静态引用）；状态：后端 Admin 路径已按清单处理。改映射并更新前端；前端：qbit-admin-v3
- [ ] **POST `/api/drools/risk-rating/page`** → **/api/admin/drools/risk-rating/page**；模块：Drools；qbit-web：—（未发现 qbit-web 静态引用）；状态：后端 Admin 路径已按清单处理。改映射并更新前端；前端：qbit-admin-v3
- [ ] **POST `/api/drools/risk-rating/save`** → **/api/admin/drools/risk-rating/save**；模块：Drools；qbit-web：—（未发现 qbit-web 静态引用）；状态：后端 Admin 路径已按清单处理。改映射并更新前端；前端：qbit-admin-v3
- [ ] **POST `/api/quantum-card/customer/cycleFailRate`** → **/api/admin/quantum-card/customer/cycleFailRate**；模块：quantum-card；qbit-web：—（未发现 qbit-web 静态引用）；状态：后端 Admin 路径已按清单处理。qbit_admin 已找到请求封装；按清单改 Admin 路径并更新封装，不以页面调用为前置
- [ ] **POST `/api/quantum-card/customer/cycleRefundCount`** → **/api/admin/quantum-card/customer/cycleRefundCount**；模块：quantum-card；qbit-web：—（未发现 qbit-web 静态引用）；状态：后端 Admin 路径已按清单处理。qbit_admin 已找到请求封装；按清单改 Admin 路径并更新封装，不以页面调用为前置
- [ ] **POST `/api/quantum-card/customer/cycleRefundRate`** → **/api/admin/quantum-card/customer/cycleRefundRate**；模块：quantum-card；qbit-web：—（未发现 qbit-web 静态引用）；状态：后端 Admin 路径已按清单处理。qbit_admin 已找到请求封装；按清单改 Admin 路径并更新封装，不以页面调用为前置
- [ ] **POST `/api/quantum-card/customer/cycleRefundSum`** → **/api/admin/quantum-card/customer/cycleRefundSum**；模块：quantum-card；qbit-web：—（未发现 qbit-web 静态引用）；状态：后端 Admin 路径已按清单处理。qbit_admin 已找到请求封装；按清单改 Admin 路径并更新封装，不以页面调用为前置
- [ ] **POST `/api/quantum-card/customer/refundAndFail`** → **/api/admin/quantum-card/customer/refundAndFail**；模块：quantum-card；qbit-web：—（未发现 qbit-web 静态引用）；状态：后端 Admin 路径已按清单处理。qbit_admin 已找到请求封装；按清单改 Admin 路径并更新封装，不以页面调用为前置
- [ ] **POST `/api/admin/employees/sales`** → **/api/admin/employees/sales**；模块：employees；qbit-web：—（未发现 qbit-web 静态引用）；状态：现有 Admin 路径，复核。路径已符合规范，只复核白名单与故事要求；前端：admin-dashboard-web
- [ ] **POST `/api/admin/employees/ams`** → **/api/admin/employees/ams**；模块：employees；qbit-web：—（未发现 qbit-web 静态引用）；状态：现有 Admin 路径，复核。路径已符合规范，只复核白名单与故事要求；前端：admin-dashboard-web
- [ ] **POST `/api/assets/internal/convert/api-customer/sub/card-bin/parent-list`** → **保留：`/api/admin/apiClient/convert/api-customer/sub/card-bin/parent-list`**；模块：API Convert；qbit-web：—；状态：待复核/定位。删除该 internal 映射；当前源码未定位到完整映射，先确认定义位置。
- [ ] **POST `/api/assets/internal/convert/issue-key`** → **保留：`/api/admin/apiClient/convert/issue-key`**；模块：API Convert；qbit-web：—；状态：待复核/定位。删除该 internal 映射；当前源码未定位到完整映射，先确认定义位置。
- [ ] **GET `/api/core/google/checkCode`** → **`/api/admin/core/google/checkCode`**；模块：Google Auth；qbit-web：保留原路由 `/api/core/google/checkCode`；状态：后端 Admin 路径已按清单处理。qbit_admin 已找到请求封装；更新 Admin 封装调用新路径，保留原商户路由。
- [ ] **GET `/api/core/google/getSecretKey`** → **`/api/admin/core/google/getSecretKey`**；模块：Google Auth；qbit-web：保留原商户路由 `/api/core/google/getSecretKey`；状态：后端 Admin 路径已按清单处理。qbit-web 有实际调用；qbit_admin 已找到 Admin 请求封装，更新其调用新路径。
- [ ] **GET `/api/core/google/getQrcode`** → **`/api/admin/core/google/getQrcode`**；模块：Google Auth；qbit-web：保留原商户路由 `/api/core/google/getQrcode`；状态：后端 Admin 路径已按清单处理。保留商户入口；Admin 前端改用独立 Admin 路由。
- [ ] **GET `/api/statement/customer-settle`** → **`/api/admin/statement/customer-settle`**；模块：对账单；qbit-web：保留原商户路由 `/api/statement/customer-settle`；状态：后端 Admin 路径已按清单处理。Admin 前端改用独立路由；分别验收数据范围。
- [ ] **POST `/ajCaptcha/check`** → **`/api/admin/ajCaptcha/check`**；模块：滑块验证码；qbit-web：保留原商户路由 `/ajCaptcha/check`；状态：后端 Admin 路径已按清单处理。Admin 登录前免登录；仍需网关/WAF IP 白名单校验。
- [ ] **POST `/ajCaptcha/get`** → **`/api/admin/ajCaptcha/get`**；模块：滑块验证码；qbit-web：保留原商户路由 `/ajCaptcha/get`；状态：后端 Admin 路径已按清单处理。Admin 登录前免登录；仍需网关/WAF IP 白名单校验。
- [ ] **POST `/api/merchant/apiClient/caas-onboarding/card-bin`** → **已有：`/api/admin/apiClient/lable/caas-onboarding/card-bin`**；模块：CaaS onboarding；qbit-web：保留原商户路由 `/api/merchant/apiClient/caas-onboarding/card-bin`；状态：后端 Admin 路径已按清单处理。qbit-admin-v3 页面切换到已有 Admin 路由。

<!-- 接口清单条目：86 -->

## 双入口接口与鉴权

### 商户与 Admin 保持双入口

- Google Auth：`GET /api/core/google/checkCode`、`/getSecretKey`、`/getQrcode`；Admin 使用对应的 `/api/admin/core/google/...`。商户原路径保留。
- 客户对账单：商户 `GET /api/statement/customer-settle`；Admin `GET /api/admin/statement/customer-settle`。两边复用导出服务，身份上下文各自取自当前登录用户。
- 滑块验证码：商户 `POST /ajCaptcha/get`、`/check`；Admin `POST /api/admin/ajCaptcha/get`、`/check`。Admin 登录前流程保留免登录要求，并由网关/WAF 管理 IP 白名单。
- CaaS card-bin：商户继续使用 `POST /api/merchant/apiClient/caas-onboarding/card-bin`；Admin 使用已存在的 `POST /api/admin/apiClient/lable/caas-onboarding/card-bin`。
- 量子卡五项：
  - `POST /api/quantum-card/customer/refundAndFail` → Admin `POST /api/admin/quantum-card/customer/refundAndFail`
  - `POST /api/quantum-card/customer/cycleRefundCount` → Admin `POST /api/admin/quantum-card/customer/cycleRefundCount`
  - `POST /api/quantum-card/customer/cycleRefundSum` → Admin `POST /api/admin/quantum-card/customer/cycleRefundSum`
  - `POST /api/quantum-card/customer/cycleFailRate` → Admin `POST /api/admin/quantum-card/customer/cycleFailRate`
  - `POST /api/quantum-card/customer/cycleRefundRate` → Admin `POST /api/admin/quantum-card/customer/cycleRefundRate`
  - 两侧都保留 `@NoAuth(NoAuth.LOGIN)`，即校验登录 token。Admin Controller 同时保留其既有 kebab-case 路由。
- 翻译：商户 `POST /api/core/translate` 保留；Admin `POST /api/admin/core/translate` 新增。商户 `POST /api/core/translate/translate-form` 不变。

### 前端对接清单

- [ ] `qbit_admin`：更新 6 条 BI board 统计以及本清单中命中的 BI、Drools、quantum-card 请求封装，统一调用 Admin 目标路径；不因暂未找到页面调用而跳过已命中的封装。
- [ ] `qbit-admin-v3`：更新 Drools、翻译、Google Auth、客户对账单、登录验证码、CaaS card-bin 对应 Admin 调用。
- [ ] `qbit_web`：共享接口继续调用商户路径；不切换到 `/api/admin/...`。
- [ ] 前端更新后，对清单中 Admin-only 的旧路径做静态残留搜索，并完成页面联调。

## 已知限制与待确认项

- 员工 `POST /api/admin/employees/sales` 与 `POST /api/admin/employees/ams` 已使用 Admin 前缀，本次只复核，不需要改路径。
- 清单中的两条 `/api/assets/internal/convert/...` 完整映射在当前 Assets 源码中未找到，未据此删除其它路由；需要提供运行时路由/网关定义后再确认。
- 本次只编译 Assets（`mvn -pl qbit-core -am -DskipTests test-compile`）；未运行业务测试，也未做前端构建或联调。当前编译通过，`git diff --check` 通过。
