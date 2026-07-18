# Qbit 支付路由体系 (Payment Routing)

> 基于 `qbit-core` (Spring Boot) + `qbit-assets` 代码库分析。
> 支付路由涵盖渠道工厂、过滤器链、权重路由、前置校验、出金方向、询价/出金/Webhook 生命周期。
> 最后更新: 2025-06-12

---

## 1. 架构概览

### 1.1 整体拓扑

```
商户/管理员发起付款
        │
        ▼
┌────────────────────────────────────────────────────────┐
│                    路由前置校验                            │
│  PaymentCommonCheckContext.run()                        │
│    ├── GlobalAccountKycCheckParam (全球账户KYB检查)       │
│    ├── CheckSameNameParam (同名付款检查)                  │
│    ├── CheckWireParam (电汇参数检查)                      │
│    └── 其他 PaymentCommonCheckHandle 实现                 │
└──────────────────────┬─────────────────────────────────┘
                       ▼
┌────────────────────────────────────────────────────────┐
│                    渠道路由决策                            │
│  PayoutRoutingUtils.getPayoutPlatform()                 │
│    └── AllRatePlatformContext.getRateList()              │
│         ├── getPlatformLiquidationModes (DB费率查询)      │
│         ├── PlatformsFilterContext (过滤器链)              │
│         └── getOptimalChannel (询价+最低成本选择)           │
└──────────────────────┬─────────────────────────────────┘
                       ▼
┌────────────────────────────────────────────────────────┐
│                   出金执行                                │
│  PaymentChannelFactory → AbstractPaymentChannelService  │
│    ├── payoutPreCheckWithinDeficitThreshold (检查)       │
│    ├── createPayoutTransactionRecord (创建记录)          │
│    ├── payout (执行出金)                                  │
│    │    ├── 子账户→大账户 (SUB_TO_MASTER_TO_PAYEE)       │
│    │    ├── 大账户→收款人 (MASTER_TO_PAYEE)              │
│    │    └── 子账户→收款人 (SUB_TO_PAYEE)                 │
│    └── paymentWebhook (回调处理)                         │
└──────────────────────┬─────────────────────────────────┘
                       ▼
              第三方支付渠道
    (CL/EP/GEO/L2/Nium/Offline/RD/RF/Thunes/TZ/ZB)
```

### 1.2 技术栈

| 组件 | 技术 |
|------|------|
| 路由决策 | 工厂模式 + 管道过滤器 + 权重路由 |
| 渠道适配 | 模板方法模式 (AbstractPaymentChannelService) |
| 询价 | 并行 CompletableFuture (5s 超时) |
| 权重路由 | PayOutWeight 表 (交易/账户/系统/参数四维) |
| 黑白名单 | PaymentWhiteList 表 (RosterContext) |
| 费率配置 | PayoutCurrencies + PayoutPlatformLiquidationMode |
| 前置校验 | PaymentCommonCheckHandle SPI 模式 |

---

## 2. 渠道工厂 (PaymentChannelFactory)

### 2.1 工厂与枚举

**PaymentChannelFactory:** `InitializingBean` 自动发现所有 `AbstractPaymentChannelService` Bean，注册到 `EnumMap<PaymentChannelEnum, AbstractPaymentChannelService>`。

**PaymentChannelEnum:** 11 个渠道:

| 枚举 | value | 中文名 |
|------|-------|--------|
| GEO | GEO | GEO |
| RD | RD | RD |
| THUNES | TH | TH |
| OFFLINE_PAYMENT | offlinePayment | 线下打款 |
| NIUM | NM | NM |
| CL | CL | CL |
| L2 | L2 | L2 |
| EP | EP | Easy Pay |
| ZB | ZB | Zenus Bank |
| TZ | TZ | Tazapay |

### 2.2 渠道服务实现

| 服务类 | 对应渠道 |
|--------|----------|
| `ColumnChannelPaymentService` | CL |
| `EasyPayChannelPaymentService` | EP |
| `GeoChannelPaymentService` | GEO |
| `Layer2ChannelPaymentService` | L2 |
| `NiumChannelPaymentService` | NIUM |
| `OfflineChannelPaymentService` | Offline |
| `RdChannelPaymentService` | RD |
| `RfChannelPaymentService` | RF |
| `ThunesChannelPaymentService` | THUNES |
| `TzChannelPaymentService` | TZ |
| `ZenusBankChannelPaymentService` | ZB |

---

## 3. AbstractPaymentChannelService (模板方法)

### 3.1 抽象方法 (各渠道实现)

| 方法 | 说明 |
|------|------|
| `getChannel()` | 返回当前服务对应的 PaymentChannelEnum |
| `sendInquiry()` | 向第三方渠道发送询价请求 |
| `doPay()` | 执行实际出金 |
| `getBalance()` | 查询渠道余额 |
| `doQueryThirdPartyAvailable()` | 查询第三方可用余额 |
| `doQueryThirdPartyAll()` | 查询第三方全部余额 |
| `doQueryMasterAvailable()` | 查询主账户可用余额 |
| `doWalletToWalletTransfer()` | 钱包间转账 |

### 3.2 核心模板方法

| 方法 | 行数(约) | 说明 |
|------|----------|------|
| `inquiry()` | ~200 | 询价: 保存记录 → 调用 sendInquiry → 更新结果 |
| `payoutPreCheckWithinDeficitThreshold()` | ~150 | 出金前检查: 余额校验 → 询价 → 可用额度检查 |
| `createPayoutTransactionRecord()` | ~100 | 创建支付记录 (幂等) |
| `payout()` | ~600 | 出金主流程: 加锁 → 检查 → 询价 → 赤字校验 → 子转主 → 执行出金 → Webhook → 结算 |
| `paymentWebhook()` | ~200 | Webhook 回调处理 (退款/成功/失败路径) |
| `checkBalance()` | ~100 | 余额检查 (可用 vs 需要, 不足时通知) |

### 3.3 出金方向 (PayoutDirectionTypeEnum)

| 类型 | 说明 |
|------|------|
| `MASTER_TO_PAYEE` | 大账户直接付给收款人 (代付) |
| `SUB_TO_PAYEE` | 子账户同名付给收款人 |
| `SUB_TO_MASTER_TO_PAYEE_STEP_1` | 子账户转大账户 (第一步) |
| `SUB_TO_MASTER_TO_PAYEE_STEP_2` | 大账户再付给收款人 (第二步) |

### 3.4 出金生命周期

```
inquiry (询价)
    │
    ▼
payoutPreCheckWithinDeficitThreshold
    │  (余额检查 → inquiry → 赤字校验)
    ▼
createPayoutTransactionRecord
    │  (幂等创建交易记录)
    ▼
payout
    ├── lock (分布式锁)
    ├── check (余额/状态检查)
    ├── inquiry/confirm (询价确认)
    ├── deficit check (赤字检查)
    ├── sub-to-master (子转主, 若需要)
    ├── doPay (实际出金)
    ├── webhook (回调)
    └── settlement (结算)
```

---

## 4. 过滤器链 (Filter Pipeline)

### 4.1 PlatformsFilterContext

过滤器链，`getSupportPlatform()` 顺序执行全部 10 个 `IPlatformsFilter`:

| 顺序 | 过滤器 | 职责 |
|------|--------|------|
| 1 | `GlobalFilterHandle` | 全球账户出金: 若当前渠道支持同名付款则直接走同名，否则走代付 |
| 2 | `ThFilterHandle` | THUNES 渠道: 匹配银行特殊信息过滤 |
| 3 | `RdFilterHandle` | RD 渠道: 不支持 ACH 付款 |
| 4 | `EpFilterHandle` | EP 渠道: 特定条件下的渠道过滤 |
| 5 | `ClFilterHandle` | CL 渠道: 特定条件下的渠道过滤 |
| 6 | `ZbFilterHandle` | ZB 渠道: 特定条件下的渠道过滤 |
| 7 | `GeoFilterHandle` | GEO 渠道: 特定条件下的渠道过滤 |
| 8 | `TzFilterHandle` | TZ 渠道: 特定条件下的渠道过滤 |
| 9 | `AgencyPaymentFilterHandle` | 代付管控: 代付渠道可用性过滤 |
| 10 | `MasterFilterHandle` | 加密资产: 主账户出金路由 (最后处理) |

### 4.2 过滤器接口

```java
public interface IPlatformsFilter {
    Map<String, List<PaymentChannelEnum>> handle(PaymentFilterChannelDTO input);
}
```

每个过滤器接收当前可用的渠道列表，返回过滤后的渠道列表，管道传递。

### 4.3 GlobalFilterHandle 路由决策

全球账户付款时的核心路由逻辑:

1. 判断 `isProxyPayment(balance)` — 加密资产或特殊渠道直接返回原始列表
2. 查询 `GlobalSubAccount` 获取当前账户的 provider
3. 对每个收款人:
   - 若当前渠道支持同名付款 (SupportSameName) → 只走同名渠道
   - 若当前渠道本身支持该付款方式 → 只走当前渠道
   - 否则 → 走代付渠道 (SupportPaymentAgency)

---

## 5. 权重路由 (Weight Flows)

### 5.1 WeightParameterFlow

```java
public interface WeightParameterFlow {
    List<PayOutWeight> handle(PayoutWeightDTO input);
}
```

### 5.2 四维权重

| 实现类 | 维度 | 查询条件 |
|--------|------|----------|
| `PayoutWeightTransactionFlow` | 交易维度 | transactionId |
| `PayoutWeightAccountFlow` | 账户维度 | accountId (排除交易级) |
| `PayoutWeightSystemFlow` | 系统维度 | accountId IS NULL + transactionId IS NULL |

查询统一按 `weight` 降序排列，从高权重渠道优先选择。

### 5.3 PayOutWeight 实体

| 字段 | 说明 |
|------|------|
| `accountId` | 账户 ID |
| `transactionId` | 交易 ID |
| `platform` | 渠道枚举值 (如 "CL", "EP") |
| `weight` | 权重值 (BigDecimal) |
| `enable` | 是否启用 |
| `isFinal` | 是否最终确定 (路由完成后标记) |
| `remarks` | 备注 (如 "init"，"角色更换") |

---

## 6. 路由决策流程 (getPayoutPlatform)

### 6.1 执行步骤

```
PayoutRoutingUtils.getPayoutPlatform(channel, platforms)
    │
    ├── 1. addPayWeight — 保存初始权重 (所有候选渠道，weight=100)
    │
    ├── 2. getPayeeDetail — 获取收款人详情
    │
    ├── 3. 单独 OFFLINE_PAYMENT 直接返回
    │
    ├── 4. AllRatePlatformContext.getRateList()
    │       ├── getPlatformLiquidationModes (DB查询可用渠道+费率)
    │       ├── 单渠道检查 (直接返回)
    │       ├── PlatformsFilterContext (过滤器链过滤)
    │       └── getOptimalChannel (选择最优渠道)
    │             ├── filterComplianceDisabled (合规过滤)
    │             ├── ZB优先 (排除TZ)
    │             ├── 节假日: 取第一个可用渠道
    │             └── 工作日: 并行询价 → 选择成本(金额+手续费)最低渠道
    │
    └── 5. 返回 PaymentChannelDTO (platform + sameNameOutMoneyMode)
```

### 6.2 最优渠道选择

工作日时 `getOptimalChannel()`:
1. 合规过滤: 排除合规禁用的渠道
2. ZB 优先: 存在 ZB 时排除 TZ
3. 并行询价: `CompletableFuture` + `completeOnTimeout(5s)` → 所有渠道查询汇率/费用
4. 成本比较: `amount + fee` 最小值
5. 保存路由: `savePayWeight()` 记录路由结果

节假日时直接取第一个可用渠道 (不询价)。

### 6.3 同名/非同名出金模式

| 条件 | 出金模式 |
|------|----------|
| 全球账户 + 同名付款 | `rateList.sameNameOutMoneyMode` |
| 其他 | `rateList.notSameNameOutMoneyMode` |

`PayoutOutMoneyModeEnum`: `Sub` (子账户出) / `Master` (主账户出)

---

## 7. 前置校验 (PaymentCommonCheck)

### 7.1 校验流程

```java
PaymentCommonCheckContext.run(checkDTO)
    → 遍历所有 PaymentCommonCheckHandle Bean 依次执行 check()
```

### 7.2 校验实现

| 校验器 | 接口 | 职责 |
|--------|------|------|
| `GlobalAccountKycCheckParam` | PaymentCommonCheckHandle | 全球账户 KYB 状态校验 (MultiCurrencyAccount Passed) |
| `CheckSameNameParam` | PaymentCommonCheckHandle | 同名付款参数校验 |
| `CheckWireParam` | PaymentCommonCheckHandle | 电汇 (Wire) 参数校验 |

### 7.3 BeforeRoutingCheck (路由前检查)

```java
PaymentCommonCheckContext.runBeforeRoutingCheck(checkDTO)
    → 遍历所有 BeforeRoutingCheck Bean 依次执行 check()
```

| 校验器 | 接口 | 职责 |
|--------|------|------|
| `AmountParamCheck` | BeforeRoutingCheck | 金额参数校验 |

---

## 8. 黑白名单 (RosterContext)

### 8.1 RosterContext

名单检查中心，提供给免材料/免审核判断:

| 方法 | 说明 |
|------|------|
| `freeMaterials()` | 免材料检查 → "Material" Handle |
| `freeReview()` | 免审核检查 → "Examine" Handle |

### 8.2 白名单处理策略

通过 `PaymentWhiteList` 表查询收款人对端账户是否在白名单中，结合累计出金金额判断是否需要补充材料或审核。

### 8.3 累计金额

`getAccumulatedAmount()`: 查询当日/累计向同一收款人的出金总额，用于限额判断。

---

## 9. 上下文对象

| Context | 说明 |
|---------|------|
| `PlatformsFilterContext` | 过滤器链上下文，管理 10 个 IPlatformsFilter |
| `AllRatePlatformContext` | 渠道费率与最优路由上下文 |
| `PaymentCommonCheckContext` | 公共前置校验上下文 |
| `QbitWebhookContext` | Webhook 回调上下文 |
| `RosterContext` | 黑白名单上下文 |

---

## 10. Admin 管理接口

**Controller:** `AdminPaymentRoutingController` (`/api/admin/payment/`)

| 接口 | 方法 | 说明 |
|------|------|------|
| `/default-route` | POST | 当前订单可选渠道(下拉框) |
| `/get-payment-log-info-route` | POST | 获取前端调用接口类型 (java/node) |
| `/get-payment-info-third-log` | POST | 获取三方详情 |
| `/check-admin-payment-examine` | POST | 检查付款审核相关操作 |
| `/purpose/list` | POST | 出金目的列表 |
| `/payout/purpose` | POST | 获取选择的付款目的 |
| `/payout/documents` | POST | 获取补充材料 |
| `/payment-agency-channels` | GET | 获取代付渠道 |
| `/payment-agency/operate` | POST | 启用/停用代付渠道 |

---

## 11. 数据模型

### 11.1 核心表

| 表 | 说明 |
|----|------|
| `payment_transaction_record` | 支付交易记录 (核心表) |
| `payout_currencies` | 出金币种配置 |
| `payout_platform_liquidation_mode` | 渠道清算模式与费率 |
| `pay_out_weight` | 出金权重 (路由决策) |
| `payment_white_list` | 付款白名单 |
| `global_sub_account` | 全球账户子账户 |

### 11.2 PaymentTransactionRecord 主要字段

| 字段 | 说明 |
|------|------|
| `id` | 主键 |
| `source_transaction_id` | 源交易 ID (幂等) |
| `parent_id` | 父交易 ID (退款关联) |
| `account_id` | 账户 ID |
| `payee_id` | 收款人 ID |
| `platform` | 支付渠道 |
| `status` | 状态 (PENDING/SUCCESS/FAILED/REFUNDED) |
| `direction_type` | 出金方向类型 |
| `business_type` | 业务类型 |

### 11.3 PayoutPlatformLiquidationMode

| 字段 | 说明 |
|------|------|
| `currencies_id` | 关联 payout_currencies |
| `platform` | 渠道枚举 |
| `fee` | 手续费 |
| `fee_currency` | 手续费币种 |
| `liquidation_mode` | 清算模式 (OUR/SHA/BEN) |
| `support_same_name` | 是否支持同名出金 |
| `support_payment_agency` | 是否支持代付 |
| `transfer_type` | 转账类型 (local/swift) |

---

## 12. 路径速查

| 模块 | 路径 |
|------|------|
| 渠道工厂 | `qbit-core/.../payout/dispatch/PaymentChannelFactory.java` |
| 渠道抽象基类 | `qbit-core/.../payout/dispatch/AbstractPaymentChannelService.java` |
| 渠道枚举 | `qbit-core/.../assets/enums/PaymentChannelEnum.java` |
| 路由工具类 | `qbit-core/.../payout/utils/PayoutRoutingUtils.java` |
| 渠道费率上下文 | `qbit-core/.../payout/handle/context/AllRatePlatformContext.java` |
| 过滤器链上下文 | `qbit-core/.../payout/handle/context/PlatformsFilterContext.java` |
| 公共校验上下文 | `qbit-core/.../payout/handle/context/PaymentCommonCheckContext.java` |
| Webhook 上下文 | `qbit-core/.../payout/handle/context/QbitWebhookContext.java` |
| 黑白名单上下文 | `qbit-core/.../payout/handle/context/RosterContext.java` |
| GlobalFilterHandle | `qbit-core/.../payout/handle/filter/GlobalFilterHandle.java` |
| MasterFilterHandle | `qbit-core/.../payout/handle/filter/MasterFilterHandle.java` |
| 代付管控 | `qbit-core/.../payout/handle/filter/AgencyPaymentFilterHandle.java` |
| 渠道过滤 Handle | `qbit-core/.../payout/handle/filter/{Cl,Ep,Geo,Rd,Rf,Th,Tz,Zb}FilterHandle.java` |
| 权重: 交易维度 | `qbit-core/.../payout/handle/weight/PayoutWeightTransactionFlow.java` |
| 权重: 账户维度 | `qbit-core/.../payout/handle/weight/PayoutWeightAccountFlow.java` |
| 权重: 系统维度 | `qbit-core/.../payout/handle/weight/PayoutWeightSystemFlow.java` |
| 权重接口 | `qbit-core/.../payout/handle/weight/WeightParameterFlow.java` |
| 前置校验接口 | `qbit-core/.../payout/handle/check/PaymentCommonCheckHandle.java` |
| 路由前检查接口 | `qbit-core/.../payout/handle/check/routing/BeforeRoutingCheck.java` |
| KYB 校验 | `qbit-core/.../payout/handle/check/routing/GlobalAccountKycCheckParam.java` |
| 金额校验 | `qbit-core/.../payout/handle/check/routing/AmountParamCheck.java` |
| 同名参数校验 | `qbit-core/.../payout/handle/check/CheckSameNameParam.java` |
| 电汇参数校验 | `qbit-core/.../payout/handle/check/CheckWireParam.java` |
| Admin 路由控制器 | `qbit-core/.../admin/payout/controller/AdminPaymentRoutingController.java` |
| 出金方向枚举 | `qbit-core/.../payout/enums/PaymentTransferDirectionTypeEnum.java` |
| 渠道 DTO | `qbit-core/.../payout/domain/dto/PaymentChannelDTO.java` |
| 路由参数 BO | `qbit-core/.../payout/domain/bo/PaymentOptimalChannelBO.java` |
| 过滤器 DTO | `qbit-core/.../payout/domain/dto/PaymentFilterChannelDTO.java` |
| CL 渠道服务 | `qbit-core/.../payout/dispatch/ColumnChannelPaymentService.java` |
| EP 渠道服务 | `qbit-core/.../payout/dispatch/EasyPayChannelPaymentService.java` |
| GEO 渠道服务 | `qbit-core/.../payout/dispatch/GeoChannelPaymentService.java` |
| L2 渠道服务 | `qbit-core/.../payout/dispatch/Layer2ChannelPaymentService.java` |
| NIUM 渠道服务 | `qbit-core/.../payout/dispatch/NiumChannelPaymentService.java` |
| Offline 渠道服务 | `qbit-core/.../payout/dispatch/OfflineChannelPaymentService.java` |
| RD 渠道服务 | `qbit-core/.../payout/dispatch/RdChannelPaymentService.java` |
| RF 渠道服务 | `qbit-core/.../payout/dispatch/RfChannelPaymentService.java` |
| THUNES 渠道服务 | `qbit-core/.../payout/dispatch/ThunesChannelPaymentService.java` |
| TZ 渠道服务 | `qbit-core/.../payout/dispatch/TzChannelPaymentService.java` |
| ZB 渠道服务 | `qbit-core/.../payout/dispatch/ZenusBankChannelPaymentService.java` |
