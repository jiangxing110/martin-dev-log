# PD-3026 接口前缀整改开发方案

## 意图

为后台接口统一建立 `/api/admin/...` 路由，使后台 IP 白名单可以覆盖这些入口；对商户端也在使用的能力保留商户路由并建立独立后台入口。除此之外，移除已被 WAF 拦截且不应继续提供的 `/api/assets/internal/convert/...` 映射。业务逻辑和接口行为保持不变。

## 目标与非目标

- 目标：按故事附件清单完成后台路由迁移、共享接口拆分、Admin 前端调用更新和 internal 路由下线。
- 目标：核对 qbit-admin-v3、qbit_admin 中的接口路径；只要找到接口（包括请求封装）就纳入迁移并更新封装，不要求先证明页面实际调用。
- 目标：交付纵向访问边界（商户不能进入 admin 能力）和横向数据隔离（admin 查询/操作范围符合既有授权）的核查结论。
- 非目标：改变业务计算、请求/响应结构、校验、数据权限规则或商户侧 API 路径；把接口迁移给 qbit-web 团队。
- 非目标：自动调整清单外接口；如果调用方核实发现新依赖，先补充范围再实施。

## 范围基准

以用户提供的 PD-3026 故事附件清单为准。当前会话中可见的分类为：

1. BI board 统计 6 条：仅 admin 调用，迁移到 `/api/admin/...`。
2. 共享接口 7 条：GA 3 条、对账单 1 条、滑块验证码 2 条、CaaS onboarding card-bin 1 条；后台使用 admin 路由，商户使用原商户路由。
3. BI board / BI / drools / quantum-card 等 71 条：按清单迁移 admin-only 路由；其中 `employees/sales`、`employees/ams` 已是 `/api/admin/...`，只核对是否仍有其他要求。
4. 删除 2 条 `/api/assets/internal/convert/...` 映射：`api-customer/sub/card-bin/parent-list` 与 `issue-key`；保留已存在的 admin 路由。

原始 Excel 位于当前仓库外，本方案以用户粘贴的清单为输入；实施前需将 Excel 中的声明行作者、qbit-web 引用和前端仓库信息复核到任务清单。共享接口组的 `checkCode`、`getSecretKey` 已在 qbit_admin 找到请求封装，按清单新增 Admin 入口并更新封装；不以页面是否实际调用作为前置条件。

### 本次涉及接口逐项清单

共 86 条，按模块汇总在下表；路径参数保持不变。

颜色说明：<span style="background-color: #d4edda">绿色</span>表示后端路径已符合目标前缀（只代表路径项就绪）；黄色表示调用方、映射位置或处理方式仍待复核。

| 接口名称 | 模块 | 优化后 Admin | 优化后 Web | 备注 |
|---|---|---|---|---|
| POST `/api/bi/board/getAuthenticationRate` | BI board | /api/admin/bi/board/getAuthenticationRate | —（未发现 qbit-web 静态引用） | 前端：qbit-admin |
| POST `/api/bi/board/getCustomerSourceStatistics` | BI board | /api/admin/bi/board/getCustomerSourceStatistics | —（未发现 qbit-web 静态引用） | 前端：qbit-admin |
| POST `/api/bi/board/getNumberCustomersReceived` | BI board | /api/admin/bi/board/getNumberCustomersReceived | —（未发现 qbit-web 静态引用） | 前端：qbit-admin |
| POST `/api/bi/board/quantumCardConsumptionSuccessRate` | BI board | /api/admin/bi/board/quantumCardConsumptionSuccessRate | —（未发现 qbit-web 静态引用） | 前端：qbit-admin |
| POST `/api/bi/board/successRateEachSegment` | BI board | /api/admin/bi/board/successRateEachSegment | —（未发现 qbit-web 静态引用） | 前端：qbit-admin |
| POST `/api/bi/board/sumAllScenesBlock` | BI board | /api/admin/bi/board/sumAllScenesBlock | —（未发现 qbit-web 静态引用） | 前端：qbit-admin |
| GET `/api/bi/baas/retention/baas` | BI | /api/admin/bi/baas/retention/baas | —（未发现 qbit-web 静态引用） | 改映射并更新前端；前端：qbit-admin |
| GET `/api/bi/baas/retention/dashBoard` | BI | /api/admin/bi/baas/retention/dashBoard | —（未发现 qbit-web 静态引用） | 改映射并更新前端；前端：qbit-admin |
| GET `/api/bi/board/accountKyb` | BI board | /api/admin/bi/board/accountKyb | —（未发现 qbit-web 静态引用） | 改映射并更新前端；前端：qbit-admin |
| GET `/api/bi/board/accountKyc` | BI board | /api/admin/bi/board/accountKyc | —（未发现 qbit-web 静态引用） | 改映射并更新前端；前端：qbit-admin |
| GET `/api/bi/board/activate-conversion` | BI board | /api/admin/bi/board/activate-conversion | —（未发现 qbit-web 静态引用） | 改映射并更新前端；前端：qbit-admin |
| GET `/api/bi/board/businessData` | BI board | /api/admin/bi/board/businessData | —（未发现 qbit-web 静态引用） | 改映射并更新前端；前端：qbit-admin |
| GET `/api/bi/board/businessDataAssets` | BI board | /api/admin/bi/board/businessDataAssets | —（未发现 qbit-web 静态引用） | 改映射并更新前端；前端：qbit-admin |
| GET `/api/bi/board/businessDataCard` | BI board | /api/admin/bi/board/businessDataCard | —（未发现 qbit-web 静态引用） | qbit_admin 已找到请求封装；按清单改 Admin 路径并更新封装，不以页面调用为前置。 |
| GET `/api/bi/board/businessDataCardEarning` | BI board | /api/admin/bi/board/businessDataCardEarning | —（未发现 qbit-web 静态引用） | qbit_admin 已找到请求封装；按清单改 Admin 路径并更新封装，不以页面调用为前置。 |
| GET `/api/bi/board/businessDataCardProvider` | BI board | /api/admin/bi/board/businessDataCardProvider | —（未发现 qbit-web 静态引用） | qbit_admin 已找到请求封装；按清单改 Admin 路径并更新封装，不以页面调用为前置。 |
| GET `/api/bi/board/businessDataGlobal` | BI board | /api/admin/bi/board/businessDataGlobal | —（未发现 qbit-web 静态引用） | 改映射并更新前端；前端：qbit-admin |
| GET `/api/bi/board/businessQuantumByProvider` | BI board | /api/admin/bi/board/businessQuantumByProvider | —（未发现 qbit-web 静态引用） | 改映射并更新前端；前端：qbit-admin |
| GET `/api/bi/board/cardTransferInfo` | BI board | /api/admin/bi/board/cardTransferInfo | —（未发现 qbit-web 静态引用） | 改映射并更新前端；前端：qbit-admin |
| GET `/api/bi/board/globalInComes` | BI board | /api/admin/bi/board/globalInComes | —（未发现 qbit-web 静态引用） | 改映射并更新前端；前端：qbit-admin |
| GET `/api/bi/board/globalTransfer` | BI board | /api/admin/bi/board/globalTransfer | —（未发现 qbit-web 静态引用） | 改映射并更新前端；前端：qbit-admin |
| GET `/api/bi/board/globalUser` | BI board | /api/admin/bi/board/globalUser | —（未发现 qbit-web 静态引用） | 改映射并更新前端；前端：qbit-admin |
| GET `/api/bi/board/qbitCardActive` | BI board | /api/admin/bi/board/qbitCardActive | —（未发现 qbit-web 静态引用） | 改映射并更新前端；前端：qbit-admin |
| GET `/api/bi/board/qbitCardBalance` | BI board | /api/admin/bi/board/qbitCardBalance | —（未发现 qbit-web 静态引用） | 改映射并更新前端；前端：qbit-admin |
| GET `/api/bi/board/qbitCardStatics/{cardType}` | BI board | /api/admin/bi/board/qbitCardStatics/{cardType} | —（未发现 qbit-web 静态引用） | 改映射并更新前端；前端：qbit-admin |
| GET `/api/bi/board/qbitCardTransactionStatics/{cardType}` | BI board | /api/admin/bi/board/qbitCardTransactionStatics/{cardType} | —（未发现 qbit-web 静态引用） | 改映射并更新前端；前端：qbit-admin |
| GET `/api/bi/board/qbitCardTransfer` | BI board | /api/admin/bi/board/qbitCardTransfer | —（未发现 qbit-web 静态引用） | 改映射并更新前端；前端：qbit-admin |
| GET `/api/bi/board/registration-conversion` | BI board | /api/admin/bi/board/registration-conversion | —（未发现 qbit-web 静态引用） | 改映射并更新前端；前端：qbit-admin |
| GET `/api/bi/board/subjectRegister` | BI board | /api/admin/bi/board/subjectRegister | —（未发现 qbit-web 静态引用） | 改映射并更新前端；前端：qbit-admin |
| GET `/api/bi/board/{accountLabel}/connexTransactionStatistics` | BI board | /api/admin/bi/board/{accountLabel}/connexTransactionStatistics | —（未发现 qbit-web 静态引用） | 改映射并更新前端；前端：qbit-admin |
| GET `/api/bi/board/{accountLabel}/connexTransactionTrend` | BI board | /api/admin/bi/board/{accountLabel}/connexTransactionTrend | —（未发现 qbit-web 静态引用） | 改映射并更新前端；前端：qbit-admin |
| GET `/api/bi/customer/retention/{retentionProvider}/export` | BI | /api/admin/bi/customer/retention/{retentionProvider}/export | —（未发现 qbit-web 静态引用） | 改映射并更新前端；前端：qbit-admin |
| GET `/api/bi/dashBoard/qbitCard` | BI | /api/admin/bi/dashBoard/qbitCard | —（未发现 qbit-web 静态引用） | 改映射并更新前端；前端：qbit-admin |
| GET `/api/bi/globalAccountFirstDeposit/list` | BI | /api/admin/bi/globalAccountFirstDeposit/list | —（未发现 qbit-web 静态引用） | qbit_admin 已找到请求封装；按清单改 Admin 路径并更新封装，不以页面调用为前置 |
| GET `/api/bi/globalAccountFirstDepositChart` | BI | /api/admin/bi/globalAccountFirstDepositChart | —（未发现 qbit-web 静态引用） | qbit_admin 已找到请求封装；按清单改 Admin 路径并更新封装，不以页面调用为前置 |
| GET `/api/bi/globalAccountFirstDepositCountChart` | BI | /api/admin/bi/globalAccountFirstDepositCountChart | —（未发现 qbit-web 静态引用） | qbit_admin 已找到请求封装；按清单改 Admin 路径并更新封装，不以页面调用为前置 |
| GET `/api/bi/qbitCardWalletFirstDeposit/list` | BI | /api/admin/bi/qbitCardWalletFirstDeposit/list | —（未发现 qbit-web 静态引用） | qbit_admin 已找到请求封装；按清单改 Admin 路径并更新封装，不以页面调用为前置 |
| GET `/api/bi/qbitCardWalletFirstDepositChart` | BI | /api/admin/bi/qbitCardWalletFirstDepositChart | —（未发现 qbit-web 静态引用） | qbit_admin 已找到请求封装；按清单改 Admin 路径并更新封装，不以页面调用为前置 |
| GET `/api/bi/qbitCardWalletFirstDepositCountChart` | BI | /api/admin/bi/qbitCardWalletFirstDepositCountChart | —（未发现 qbit-web 静态引用） | qbit_admin 已找到请求封装；按清单改 Admin 路径并更新封装，不以页面调用为前置 |
| GET `/api/bi/sales/earning/assetsInCome` | BI | /api/admin/bi/sales/earning/assetsInCome | —（未发现 qbit-web 静态引用） | 改映射并更新前端；前端：qbit-admin |
| GET `/api/bi/sales/earning/assetsInComes` | BI | /api/admin/bi/sales/earning/assetsInComes | —（未发现 qbit-web 静态引用） | 改映射并更新前端；前端：qbit-admin |
| GET `/api/bi/sales/earning/globalAccountInCome` | BI | /api/admin/bi/sales/earning/globalAccountInCome | —（未发现 qbit-web 静态引用） | 改映射并更新前端；前端：qbit-admin |
| GET `/api/bi/sales/earning/globalAccountInComes` | BI | /api/admin/bi/sales/earning/globalAccountInComes | —（未发现 qbit-web 静态引用） | 改映射并更新前端；前端：qbit-admin |
| GET `/api/bi/sales/earning/qbitCardInCome` | BI | /api/admin/bi/sales/earning/qbitCardInCome | —（未发现 qbit-web 静态引用） | 改映射并更新前端；前端：qbit-admin |
| GET `/api/bi/sales/earning/qbitCardInComes` | BI | /api/admin/bi/sales/earning/qbitCardInComes | —（未发现 qbit-web 静态引用） | qbit_admin 已找到请求封装；按清单改 Admin 路径并更新封装，不以页面调用为前置 |
| GET `/api/bi/sales/earning/quantumEffectiveInComes` | BI | /api/admin/bi/sales/earning/quantumEffectiveInComes | —（未发现 qbit-web 静态引用） | 改映射并更新前端；前端：qbit-admin |
| GET `/api/bi/sales/qbitCard/customer/consumption` | BI | /api/admin/bi/sales/qbitCard/customer/consumption | —（未发现 qbit-web 静态引用） | 改映射并更新前端；前端：qbit-admin |
| GET `/api/bi/sales/qbitCard/customer/{accountLabel}/consumption-credit` | BI | /api/admin/bi/sales/qbitCard/customer/{accountLabel}/consumption-credit | —（未发现 qbit-web 静态引用） | 改映射并更新前端；前端：qbit-admin |
| GET `/api/bi/sales/qbitCard/customer/{accountLabel}/credit-rate` | BI | /api/admin/bi/sales/qbitCard/customer/{accountLabel}/credit-rate | —（未发现 qbit-web 静态引用） | 改映射并更新前端；前端：qbit-admin |
| GET `/api/bi/sales/qbitCard/customer/{accountLabel}/fail-rate` | BI | /api/admin/bi/sales/qbitCard/customer/{accountLabel}/fail-rate | —（未发现 qbit-web 静态引用） | 改映射并更新前端；前端：qbit-admin |
| GET `/api/bi/sales/qbitCard/health/consumption` | BI | /api/admin/bi/sales/qbitCard/health/consumption | —（未发现 qbit-web 静态引用） | 改映射并更新前端；前端：qbit-admin |
| GET `/api/bi/sales/qbitCard/health/consumption-count` | BI | /api/admin/bi/sales/qbitCard/health/consumption-count | —（未发现 qbit-web 静态引用） | 改映射并更新前端；前端：qbit-admin |
| GET `/api/bi/sales/qbitCard/health/credit-rate` | BI | /api/admin/bi/sales/qbitCard/health/credit-rate | —（未发现 qbit-web 静态引用） | 改映射并更新前端；前端：qbit-admin |
| GET `/api/bi/sales/qbitCard/health/credit-rate-count` | BI | /api/admin/bi/sales/qbitCard/health/credit-rate-count | —（未发现 qbit-web 静态引用） | 改映射并更新前端；前端：qbit-admin |
| GET `/api/bi/sales/qbitCard/health/fail-consumption-count-rate` | BI | /api/admin/bi/sales/qbitCard/health/fail-consumption-count-rate | —（未发现 qbit-web 静态引用） | 改映射并更新前端；前端：qbit-admin |
| GET `/api/bi/sales/qbitCard/health/fail-consumption-rate` | BI | /api/admin/bi/sales/qbitCard/health/fail-consumption-rate | —（未发现 qbit-web 静态引用） | 改映射并更新前端；前端：qbit-admin |
| POST `/api/bi/board/channel/card/cost` | BI board | /api/admin/bi/board/channel/card/cost | —（未发现 qbit-web 静态引用） | qbit_admin 已找到请求封装；按清单改 Admin 路径并更新封装，不以页面调用为前置 |
| POST `/api/bi/board/channel/card/trends` | BI board | /api/admin/bi/board/channel/card/trends | —（未发现 qbit-web 静态引用） | 改映射并更新前端；前端：qbit-admin |
| POST `/api/bi/board/channel/global-account/cost` | BI board | /api/admin/bi/board/channel/global-account/cost | —（未发现 qbit-web 静态引用） | 改映射并更新前端；前端：qbit-admin |
| POST `/api/bi/board/qbit-channel/record/upload` | BI board | /api/admin/bi/board/qbit-channel/record/upload | —（未发现 qbit-web 静态引用） | 改映射并更新前端；前端：qbit-admin |
| POST `/api/core/translate` | 其他 | /api/admin/core/translate | —（未发现 qbit-web 静态引用） | 改映射并更新前端；前端：qbit-admin-v3 |
| POST `/api/drools/control-warning/active` | Drools | /api/admin/drools/control-warning/active | —（未发现 qbit-web 静态引用） | 改映射并更新前端；前端：qbit-admin-v3 |
| POST `/api/drools/control-warning/add` | Drools | /api/admin/drools/control-warning/add | —（未发现 qbit-web 静态引用） | 改映射并更新前端；前端：qbit-admin-v3 |
| POST `/api/drools/control-warning/edit` | Drools | /api/admin/drools/control-warning/edit | —（未发现 qbit-web 静态引用） | 改映射并更新前端；前端：qbit-admin-v3 |
| POST `/api/drools/control-warning/findById` | Drools | /api/admin/drools/control-warning/findById | —（未发现 qbit-web 静态引用） | 改映射并更新前端；前端：qbit-admin-v3 |
| POST `/api/drools/control-warning/rule/logs` | Drools | /api/admin/drools/control-warning/rule/logs | —（未发现 qbit-web 静态引用） | 改映射并更新前端；前端：qbit-admin-v3 |
| POST `/api/drools/control-warning/rule/pages` | Drools | /api/admin/drools/control-warning/rule/pages | —（未发现 qbit-web 静态引用） | 改映射并更新前端；前端：qbit-admin-v3 |
| POST `/api/drools/risk-rating/info` | Drools | /api/admin/drools/risk-rating/info | —（未发现 qbit-web 静态引用） | 改映射并更新前端；前端：qbit-admin-v3 |
| POST `/api/drools/risk-rating/page` | Drools | /api/admin/drools/risk-rating/page | —（未发现 qbit-web 静态引用） | 改映射并更新前端；前端：qbit-admin-v3 |
| POST `/api/drools/risk-rating/save` | Drools | /api/admin/drools/risk-rating/save | —（未发现 qbit-web 静态引用） | 改映射并更新前端；前端：qbit-admin-v3 |
| POST `/api/quantum-card/customer/cycleFailRate` | quantum-card | /api/admin/quantum-card/customer/cycleFailRate | —（未发现 qbit-web 静态引用） | qbit_admin 已找到请求封装；按清单改 Admin 路径并更新封装，不以页面调用为前置 |
| POST `/api/quantum-card/customer/cycleRefundCount` | quantum-card | /api/admin/quantum-card/customer/cycleRefundCount | —（未发现 qbit-web 静态引用） | qbit_admin 已找到请求封装；按清单改 Admin 路径并更新封装，不以页面调用为前置 |
| POST `/api/quantum-card/customer/cycleRefundRate` | quantum-card | /api/admin/quantum-card/customer/cycleRefundRate | —（未发现 qbit-web 静态引用） | qbit_admin 已找到请求封装；按清单改 Admin 路径并更新封装，不以页面调用为前置 |
| POST `/api/quantum-card/customer/cycleRefundSum` | quantum-card | /api/admin/quantum-card/customer/cycleRefundSum | —（未发现 qbit-web 静态引用） | qbit_admin 已找到请求封装；按清单改 Admin 路径并更新封装，不以页面调用为前置 |
| POST `/api/quantum-card/customer/refundAndFail` | quantum-card | /api/admin/quantum-card/customer/refundAndFail | —（未发现 qbit-web 静态引用） | qbit_admin 已找到请求封装；按清单改 Admin 路径并更新封装，不以页面调用为前置 |
| <span style="background-color: #d4edda">POST `/api/admin/employees/sales`</span> | <span style="background-color: #d4edda">employees</span> | <span style="background-color: #d4edda">/api/admin/employees/sales</span> | <span style="background-color: #d4edda">—（未发现 qbit-web 静态引用）</span> | <span style="background-color: #d4edda">路径已符合规范，只复核白名单与故事要求；前端：admin-dashboard-web</span> |
| <span style="background-color: #d4edda">POST `/api/admin/employees/ams`</span> | <span style="background-color: #d4edda">employees</span> | <span style="background-color: #d4edda">/api/admin/employees/ams</span> | <span style="background-color: #d4edda">—（未发现 qbit-web 静态引用）</span> | <span style="background-color: #d4edda">路径已符合规范，只复核白名单与故事要求；前端：admin-dashboard-web</span> |
| <mark>POST `/api/assets/internal/convert/api-customer/sub/card-bin/parent-list`</mark> | <mark>API Convert</mark> | <mark>保留：`/api/admin/apiClient/convert/api-customer/sub/card-bin/parent-list`</mark> | <mark>—</mark> | <mark>删除该 internal 映射；当前源码未定位到完整映射，先确认定义位置。</mark> |
| <mark>POST `/api/assets/internal/convert/issue-key`</mark> | <mark>API Convert</mark> | <mark>保留：`/api/admin/apiClient/convert/issue-key`</mark> | <mark>—</mark> | <mark>删除该 internal 映射；当前源码未定位到完整映射，先确认定义位置。</mark> |
| GET `/api/core/google/checkCode` | Google Auth | `/api/admin/core/google/checkCode` | 保留原路由 `/api/core/google/checkCode` | qbit_admin 已找到请求封装；更新 Admin 封装调用新路径，保留原商户路由。 |
| GET `/api/core/google/getSecretKey` | Google Auth | `/api/admin/core/google/getSecretKey` | 保留原商户路由 `/api/core/google/getSecretKey` | qbit-web 有实际调用；qbit_admin 已找到 Admin 请求封装，更新其调用新路径。 |
| GET `/api/core/google/getQrcode` | Google Auth | `/api/admin/core/google/getQrcode` | 保留原商户路由 `/api/core/google/getQrcode` | 保留商户入口；Admin 前端改用独立 Admin 路由。 |
| GET `/api/statement/customer-settle` | 对账单 | `/api/admin/statement/customer-settle` | 保留原商户路由 `/api/statement/customer-settle` | Admin 前端改用独立路由；分别验收数据范围。 |
| POST `/ajCaptcha/check` | 滑块验证码 | `/api/admin/ajCaptcha/check` | 保留原商户路由 `/ajCaptcha/check` | Admin 登录前免登录；仍需网关/WAF IP 白名单校验。 |
| POST `/ajCaptcha/get` | 滑块验证码 | `/api/admin/ajCaptcha/get` | 保留原商户路由 `/ajCaptcha/get` | Admin 登录前免登录；仍需网关/WAF IP 白名单校验。 |
| POST `/api/merchant/apiClient/caas-onboarding/card-bin` | CaaS onboarding | 已有：`/api/admin/apiClient/lable/caas-onboarding/card-bin` | 保留原商户路由 `/api/merchant/apiClient/caas-onboarding/card-bin` | qbit-admin-v3 页面切换到已有 Admin 路由。 |
## 约束

- 后端基于当前 Spring Boot Controller 映射实现；admin-only Controller/映射归入 `com.qbit.admin`，商户入口保留在 merchant 路由边界。
- 共享业务能力尽量复用现有 Service；Controller 仅处理请求边界和用例编排，不复制业务实现。
- 不保留旧 admin-only URL 作为兼容别名，否则旧路径仍可能绕过目标白名单边界。
- 不改共享接口现有商户 URL；admin 前端必须改为新 admin URL。
- `internal` 删除范围严格限于清单明确的两个映射；`ApiConvertController` 其他映射不在范围内。
- 当前仓库只包含后端；qbit-admin / qbit-admin-v3 等前端修改需在其各自仓库完成并联测。
- 仓库规范要求中文注释、按现有 Controller 分层、所有 Git 命令在仓库目录执行；不自动创建分支、提交或推送。

## 方案选择

### 方案 A：按调用边界最小调整（推荐，当前方案）

Admin-only 接口迁移现有映射到 `/api/admin/...`；共享接口建立独立 admin Controller 路由并保留原商户路由，共用现有 Service；两条 internal 映射删除。按端点清单同步各 Admin 前端。

优点是改动范围与故事清单一致，路由可直接表达身份边界，业务逻辑复用，便于逐项验证。代价是共享能力会有两个 Controller 入口，需要确保两边参数和响应契约保持一致。

### 方案 B：统一重构整套 admin/merchant Controller 结构

把相关接口整体移动到全新的 admin 与 merchant 控制器体系。

优点是目录和入口风格更统一；代价是会触及清单外接口或扩展重构面，增加回归成本，与“不改行为、只处理清单”的约束不符，因此不选。

### 方案 C：保留旧路径并增加 admin 别名

在旧路径旁新增 `/api/admin/...` 映射。

不选。对于 admin-only 接口，旧路径继续有效会留下白名单边界缺口；双入口的生命周期也缺少清单依据。

## 前端调用情况首轮核查

已按 Excel 的 126 条接口，在 `qbit_web`、`qbit-admin-v3`、`qbit_admin` 做静态检索。以下结论区分实际业务调用与 API 封装/生成代码；生成文件中出现旧路径本身不代表页面实际调用。静态检索不能排除运行时拼接路径，最终下线前仍需做前端旧路径扫描和联调。

### qbit_web

- 本次 7 条拆分接口中，6 条有业务调用：`/api/core/google/getSecretKey`、`/api/core/google/getQrcode`、`/api/statement/customer-settle`、`/ajCaptcha/get`、`/ajCaptcha/check`、`/api/merchant/apiClient/caas-onboarding/card-bin`。这些商户路径必须保留。
- `/api/core/google/checkCode` 只发现请求封装、未发现页面调用；但 qbit_admin 中已命中封装，仍按清单改为 Admin 路径；商户原路由保留。
- 本次 admin-only 改前缀组在 Excel 的 qbit-web 列均未发现静态引用。
- 代表性调用位置：`src/views/app/statements/_api/index.ts`、`src/views/ga-enable/_api/index.ts`、`src/views/app/cdd/_view/cass-api-kyb/index.tsx`、`src/api/verify.ts`。

### qbit_admin

- 6 条 BI board 统计在注册统计看板中有实际业务调用；其余清单接口只要在 qbit_admin 中找到路径或请求封装，也纳入迁移，不以页面实际调用为条件。
- 滑块验证码用于登录流程，GA 二维码用于登录/绑定流程，均有实际页面调用；新增 Admin 路径时要继续支持登录前验证码流程。
- 在 `qbit_admin` 内，`/api/core/google/getSecretKey` 和 `/api/core/google/checkCode` 只发现请求封装、未找到页面业务调用；仍须更新这些 Admin 封装的目标路径。`getSecretKey` 在 qbit_web 有实际业务调用，因此保留商户路径。
- Excel 标记仅请求封装、需要复核的本次改前缀项包括：`GET /api/bi/board/businessDataCard`、`businessDataCardEarning`、`businessDataCardProvider`；`GET /api/bi/globalAccountFirstDeposit/list`、`globalAccountFirstDepositChart`、`globalAccountFirstDepositCountChart`；`GET /api/bi/qbitCardWalletFirstDeposit/list`、`qbitCardWalletFirstDepositChart`、`qbitCardWalletFirstDepositCountChart`；`GET /api/bi/sales/earning/qbitCardInComes`；`POST /api/bi/board/channel/card/cost`；以及 `POST /api/quantum-card/customer/cycleFailRate`、`cycleRefundCount`、`cycleRefundRate`、`cycleRefundSum`、`refundAndFail`。这些接口已在 qbit_admin 找到请求封装，按清单迁移并更新封装；不要求证明存在页面实际调用。
- 代表性调用位置：`src/views/qbit-admin/data-dashboard/components/registration-statistics/`、`src/views/login/components/slide-captcha/`、`src/views/login/validate.tsx`。

### qbit-admin-v3

- 确认有实际页面调用：GA 二维码、customer-settle、滑块验证码、CaaS card-bin、Drools control-warning 相关接口，以及 KYC 详情中的 `/api/core/translate`。
- CaaS 审核页面当前通过 `postMerchantApiClientCaasOnboardingCardBin` 调商户路径 `/api/merchant/apiClient/caas-onboarding/card-bin`；同一页面的其它审批操作已调用 Admin 入口。应将该 Admin 页面调用切换到现有 `/api/admin/apiClient/lable/caas-onboarding/card-bin`，商户路径继续保留给 qbit_web。
- customer-settle 页面有实际调用，迁移时必须把 Admin 前端切到独立 Admin 路径，qbit_web 继续使用商户路径。
- 验证码由 `src/api/verify-code.ts` 封装并在 `src/components/SlideCaptcha/` 使用；需将 Admin 登录流程改到 Admin 路径并保留免登录能力，同时确保网关/WAF IP 白名单对该路径生效。
- `src/restful/**`、`src/utils/http/api.ts` 等生成文件中的路径不代表页面实际调用；但只要属于清单接口，仍需更新对应源定义/生成产物中的 Admin 路径。

### 对实施范围的影响

- 前端改动更新清单命中的 API 请求封装及其页面调用（如有）；按项目既有流程更新源定义或生成产物。页面是否引用封装不作为是否更新路径的条件。
- 在 qbit-admin-v3 或 qbit_admin 找到接口路径/请求封装，就纳入改造并更新 Admin 路径；是否存在页面实际调用不作为前置。两仓均未找到时，记录未命中并单独确认处理。
- 前后端联测至少覆盖：Admin 登录验证码、GA 二维码、Admin customer-settle、Admin CaaS card-bin、Drools 页面，以及 qbit_web 的 GA/验证码/对账单/CaaS 商户流程。

## 实施方案

1. **固化接口清单**：从 Excel 逐行登记 HTTP 方法、旧路径、新 admin 路径、后端 Controller、调用前端、qbit-web 使用情况、责任人、复核结果和验收证据。将已在 qbit_admin 命中的 `checkCode` 等请求封装同步改为 Admin 路径；不以页面引用情况阻塞。
2. **后端 admin-only 迁移**：对确认仅 admin 使用的 6 + 71 组接口逐条改映射为 `/api/admin/...`，包括 BI、drools、quantum-card 等；同步核验已符合前缀规范的两条 employees 路径。
3. **共享接口拆分**：为 GA、customer-settle、验证码、CaaS onboarding 建立 admin 入口；商户侧原入口保持现状。admin 与 merchant Controller 复用服务，必要时抽取薄的共用协作者，不复制业务规则。逐个核对请求对象、响应/文件输出和鉴权上下文。
4. **下线 internal 映射**：先用运行时映射、部署路由配置和 Excel 定位两个 internal URL 的实际定义；只移除清单指定的 `card-bin/parent-list` 与 `issue-key` 映射；确认原 admin 路由仍可用，并确认 internal URL 不再注册。
5. **前端联动**：在 qbit-admin 和 qbit-admin-v3 更新清单标注的 admin 调用；若 qbit-web 对共享接口有依赖，确保它仍调用原商户路径。移除前再次搜索旧路径及动态拼接调用。
6. **安全验收**：分别验证未在白名单内的后台来源无法调用 admin 新入口、白名单内后台可以正常调用；验证商户凭证无法调用 admin 路由且商户原功能可用；检查涉及 accountId/userId 的接口不能通过篡改请求访问他人数据。记录每条结论的接口和证据。
7. **发布与清理**：先部署后端并完成前端联调；对 admin-only 旧路径确认没有合法调用后随版本直接下线，不做别名兼容。若发现外部依赖，暂停该条迁移并回到故事清单确认，不扩大到行为改造。

## 共享接口与免登录接口的安全边界

### 商户端和 Admin 共用的业务能力

- 按调用方拆 URL 和 Controller：商户继续调用原商户路径，Admin 调用 `/api/admin/...`；两侧 Controller 共用现有 Service，不共享同一个 URL 来推断调用方。
- 商户入口沿用商户 JWT、账户/租户上下文和既有数据范围；Admin 入口走后台账户、角色/部门数据范围以及 `/api/admin/**` 对应的网络策略。不能把请求体里的 accountId、普通 Header 或来源 IP 当成可信用户身份。
- 对两条入口分别验收：商户凭证只访问商户能力，不能访问 Admin URL；Admin 凭证能访问后台入口；同一账户/资源的权限边界在两入口保持一致，且篡改 accountId/userId 不能读取或操作未授权数据。
- 两个入口的请求、响应、文件流和错误语义应保持一致；如有意做差异，必须在故事清单注明，不能靠 Controller 路由变化悄悄改变行为。

### Admin 免登录接口（例如登录前的验证码）

- 若免登录接口仍属于 Admin 流程，使用独立 `/api/admin/...` 路径以匹配 Admin 网络白名单；Admin 前端改用该路径。商户/公开流程需要时继续保留原商户路径。
- 路由归属、登录认证、IP 访问控制是三个独立维度：`@NoAuth` 表示跳过登录用户解析/权限上下文，不表示绕过网关/WAF 的 IP 白名单。仓库中的 `AdminRequestParamInterceptor` 对 `@NoAuth` 会直接提前放行，因此 Admin 免登录接口不能依赖该拦截器建立管理员身份或做角色授权；IP 限制需由负责该策略的网关/WAF 明确匹配 `/api/admin/**` 并验证。
- 免登录仅用于真正必须在登录前调用的流程。其它接口需登录的，不应因 Admin 前缀迁移而新增 `@NoAuth`。如验证码需在未受信网络访问，应另外确认放行策略，并保留验证码有效性、频率限制/滥用防护及必要的审计。
- 验收分别验证：未登录且来源不在允许 IP 内访问 Admin 免登录 URL 会被网络策略拒绝；未登录且来源在允许 IP 内访问只获得验证码等最小公开能力；商户端原路径仍按原规则工作；免登录 Admin URL 不会创建虚假的 Admin 用户/角色/数据范围上下文。

## 验收标准

- 清单中所有 admin-only 端点都只有 `/api/admin/...` 正式入口，Admin 前端调用新路径；旧 admin-only 路径不再注册。
- 共享端点存在独立 admin 与 merchant URL；两类客户端各自走正确入口，响应与既有业务行为一致。
- 共享业务入口的 Admin 与 merchant 认证/数据范围分别生效；`@NoAuth` Admin 路径通过网关/WAF IP 策略控制，且不依赖登录拦截器提供身份。
- 两条指定 internal URL 不再注册，现有 admin URL 可用；其他 internal 映射未被误删。
- `employees/sales`、`employees/ams` 的复核结论记录在清单中。
- qbit-admin-v3/qbit_admin 中命中的请求封装均已更新；页面是否实际调用不作为迁移前置，未命中项有明确处理结论。
- 纵向权限和横向数据隔离均有覆盖清单接口类别的验证证据；权限失败不是仅凭 URL 前缀推断。
- 后端编译/相关测试、前端构建或等价验证完成；`git diff --check` 通过。测试按仓库约束在全部代码和测试完成后统一执行。

## 风险与待实施者决定

- Excel 原表不在当前工作区，需在实施时确认其是最终版本，并复核行作者分配及 qbit-web 标记。
- 本地源码搜索未找到清单所列的两个完整 `/api/assets/internal/convert/...` 路径；当前只看到 `ApiConvertController` 映射 `/api/assets/internal/convert` 的根路径、`ApiCustomerComplianceController` 下的 admin `api-customer/sub/card-bin/parent-list`，以及 `ApiCustomerManagerController` 下的 admin `issue-key`。因此实施前必须从故事 Excel、运行时路由或网关配置确认 internal 路由实际归属，避免删错映射或误判其已下线。
- 滑块验证码常处于未登录流程。新增 `/api/admin/...` 后要确认 IP 白名单规则与登录前访问链路相容，不能因 admin 身份校验要求导致后台无法登录；若安全网关对登录前 admin 请求有特殊配置，需在部署配置同步处理。
- BI 接口当前位于 `merchant` 包且使用共享 Service；迁移时应重点确认是否另有动态、脚本或非静态请求调用，不能仅凭前端静态搜索结果认定无调用。
- 管理员数据范围可能受既有角色、部门或 accountId 过滤影响；共享 Controller 拆分不能丢失这些约束。
- `/api/admin/**` 的 IP 白名单由何处执行需要和网关/WAF 配置负责人确认；Java 中 Admin 请求拦截器对 `@NoAuth` 方法会提前返回，不能把“进入 admin 路径”误当成已由该拦截器完成 IP 校验。
- 本方案推荐并暂按方案 A 细化，尚未视为用户对设计的最终批准；开发前需确认设计范围与安全验收方式。
