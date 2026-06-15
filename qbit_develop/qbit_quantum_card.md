# 量子卡体系

## 概述

量子卡是 Qbit 的核心发卡产品，提供虚拟卡和物理卡的发行、管理、交易处理能力。系统分为量子账户（QuantumAccount）和量子卡（QbitCard）两层，支持额度卡和储值卡两种模式，对接多个卡组渠道（BB、I2C 等），涵盖从卡 BIN 管理、开卡、消费、清算、对账到卡片生命周期管理的全流程。

## 分层架构

```
┌──────────────────────────────────────────────────────────────────┐
│                          Admin 管理端                            │
│  QuantumCardAdminController / AdminCardholderController / ...    │
├──────────────────────────────────────────────────────────────────┤
│                          Merchant 商户端                          │
│  CryptoAssetTransferV2Controller / CryptoAssetV2Controller / ... │
├──────────────────────────────────────────────────────────────────┤
│                       OpenAPI 对外接口层                          │
│  openapi/card/ → 卡接口、交易接口                                  │
├──────────────────────────────────────────────────────────────────┤
│                    Quantum Account 量子账户层                      │
│  QuantumAccountService → 余额、交易列表、转账、统计、发票           │
│  QuantumAccountTransferService → 转入/转出、手续费                 │
├──────────────────────────────────────────────────────────────────┤
│                    QbitCard 量子卡层                               │
│  CardV3Service → 冻结/启用/删除/限额/扣款方式                     │
│  CardConsumptionService → 消费查询                                │
│  QuantumCardRiskControlService → 风控                            │
│  CryptoConnectCardTransferService → 加密币与卡互转                │
├──────────────────────────────────────────────────────────────────┤
│                      Card Handler 层                              │
│  QbitCardHandler / QbitBudgetCardHandler / ...                   │
│  (报表导出、数据处理)                                              │
├──────────────────────────────────────────────────────────────────┤
│                    AbstractQuantumCardService                     │
│                    QuantumCardChannelFactory                      │
│                    卡组渠道适配 (BB / I2C 等)                      │
└──────────────────────────────────────────────────────────────────┘
```

## 卡类型

| 类型 | 枚举值 | 说明 |
|------|--------|------|
| 额度卡 (Budget) | `BUDGET` | 预算卡/额度卡，按额度消费 |
| 储值卡 (Recharge) | `RECHARGE` | 储值卡，先充值后消费 |

### 卡归属 (QuantumCardBelongEnum)

- `MASTER_ACCOUNT` — 主账户归属
- `SUB_ACCOUNT` — 子账户归属

### 卡模式 (QuantumCardModeEnum)

- `VIRTUAL` — 虚拟卡
- `PHYSICAL` — 物理卡

## 卡状态生命周期

```
创建 → ACTIVE ↔ SUSPENDED (冻结)
         ↓
      DELETED (删除)
```

支持冻结类型 (`FrozenTypeEnum`)：
- `SELF` — 自己冻结
- `SYSTEM` — 系统冻结
- `RISK_CONTROL` — 风控冻结

## 核心实体

### QbitCard (`qbitCard`)

| 字段 | 说明 |
|------|------|
| accountId | 所属账户ID |
| qbitCardNo | 量子卡号 |
| provider | 卡提供商 (BB/I2C 等) |
| type | 卡类型 (VISA/Master) |
| status | 卡状态 |
| balanceId | 余额钱包ID |
| cardBelong | 卡归属 (QuantumCardBelongEnum) |
| cardMode | 卡模式 (Virtual/Physical) |
| groupId | 卡分组ID |
| sourceType | 卡来源 (CardSourceTypeEnum) |
| transactionLimitsType | 限额类型 |
| lifeTimeAmountLimit | 终身消费限额 |
| cardholderInfo | 持卡人信息 (JSONB) |
| cardAddress | 卡地址 (JSONB) |

### CardSetting (`card_setting`)

- `cardId` — 卡ID
- `transactionMode` — 扣款方式列表 (TransactionModeEnum 数组)

### CardBin (`card_bin`)

- BIN 卡段管理
- CardDesignId — 卡设计模板

## 量子账户 (Quantum Account)

量子账户是基于账户维度的卡资金池，每张卡关联一个 balanceId 进行资金操作。

### 核心操作

**QuantumAccountService:**
- `getBalance(accountId)` — 获取量子账户余额
- `selectTransactionList()` — 查询交易列表
- `transactionsExport()` — 交易导出
- `generateInvoice()` — 生成发票 PDF
- `creditTrend()` / `consumptionTrend()` — 退款/消费趋势
- `refusalSumStatistics()` — 拒付率统计
- `dealAccountOrCardDecline()` — 处理账户/卡拒绝通知

**QuantumAccountTransferService:**
- `transferIn(accountId, amount, fee, options)` — 量子账户入金
- `transferOut(accountId, amount, fee, options)` — 量子账户出金
- `getStatistic()` — 消费统计
- `getCost()` — 成本计算
- `getRsSchemeFee()` — Scheme Fee 计算
- `getIncome()` — 收益统计

### 交易类型 (QuantumAccountWalletTransactionDTO)

支持多维度查询：交易类型、时间范围、卡号、渠道、商户等。

## 卡生命周期管理

### 卡片操作 (CardV3Service)

| 方法 | 说明 |
|------|------|
| `suspendCard()` | 冻结卡片 |
| `suspendCardAndSendWebhook()` | 冻结并发送 webhook |
| `enableCard()` | 启用卡片 |
| `deleteCard()` | 删除卡片 |
| `velocityControl()` | 设置限额 |
| `batchVelocityControl()` | 批量设置限额 |
| `transactionMode()` | 设置扣款方式 |
| `getCard()` | 获取卡信息 |
| `transferIn()` | 量子卡转入 |
| `transferOut()` | 量子卡转出 |
| `batchUpdateCardsLimitV1()` | 批量修改消费限额 |

### 卡分组管理

通过 MQ 消息监听器处理卡分组操作：
- 启用卡组: `EnableQbitCardGroupMessageListener`
- 冻结卡组: `SuspendQbitCardGroupMessageListener`
- 删除卡组: `DeleteQbitCardGroupMessageListener`

## 消费与交易

### 交易范围 (TransactionScopeEnum)

| 值 | 说明 |
|----|------|
| DOMESTIC (0) | 国内交易 |
| INTERNATIONAL (1) | 国际交易 |

### 业务码 (BusinessCodeEnum)

涵盖 50+ 场景码，关键分类：

| 分类 | 码值范围 | 示例 |
|------|---------|------|
| 扣款 | 1001-1006 | 强制扣款、消费释放、清算差额 |
| 验证 | 1007-1011 | FB 验证、Visa 验证、消费验证 |
| 风控拦截 | 1108-1120 | MCC黑/白名单、币种黑/白名单、场景拦截、ATM拦截 |
| 异常 | 1012-1014 | 撤销清算、删卡交易、盗刷 |
| 卡转加密 | 1122-1123 | 加密转入卡、卡转入加密 |
| 余额不足 | 1128 | 余额不足 |

### 交易扩展 (QuantumCardTransactionExtendService)

- 场景模式匹配: `QbitCardTransactionScenePatternService`
- 延迟处理: `QbitCardTransactionExtendStatusSyncService`
- 时间同步: `QbitCardTransactionExtendCreateTimeSyncService`
- 二级标签: `SecondLabelService`

## BIN 卡段管理

**CardBinService** — BIN 规则管理：
- `CardBin` — BIN 实体
- `CardDesignId` — 卡设计模板

相关 Controller:
- `AdminCardBinController` — 管理端 BIN 管理
- `CardBinAdminController` — BIN 管理
- `AccountCardBinPermissionAdminController` — 账户 BIN 权限管理

## 持卡人管理 (Cardholder)

**QuantumCardHolderService** — 持卡人信息管理：
- 创建/升级持卡人 (CardholderCreateDTO / CardholderUpgradeDTO)
- 持卡人详情查询
- 支持 RC 渠道持卡人 (RcCardHolderService)

## 物理卡 (Physical Card)

- `physical_card/common/` — 物理卡通用逻辑
- `physical_card/inventory/` — 物理卡库存管理
- `AdminPhysicalCardInventoryController` — 管理端库存管理

## APN (Apple Pay / Google Pay)

`common_all/quantum/apn/`:
- 配置、常量、实体、Mapper、Service
- 支持 Apple Pay 和 Google Pay 卡绑定

## 统计与报表

### Statistics V1 & V2

- `statistics/` — 统计 V1
- `statistics_v2/` — 统计 V2 (含 domain/mapper/service)
- `QuantumStatisticsController` — 管理端统计接口

### 报表导出 Handler (策略模式)

| Handler | 说明 |
|---------|------|
| `QbitCardHandler` | 储值卡报表导出 |
| `QbitBudgetCardHandler` | 额度卡报表导出 |
| `SubAccountPrepaidQbitCardHandler` | 子账户储值卡导出 |
| `SubAccountBudgetQbitCardHandler` | 子账户额度卡导出 |

继承自 `AbstractReportHandler`，配合 `ReportFactory` 工厂。

## 渠道架构

**QuantumCardChannelFactory** — 卡组渠道工厂：
```
AbstractQuantumCardService (模板方法)
  ├── BB 适配 (Binan/Bind)
  ├── I2C 适配
  └── 其他卡组...
```

渠道调用通过 `QuantumCardCommService` 统一封装。

## 管理端 Controller

| Controller | 说明 |
|------------|------|
| `QuantumCardAdminController` | 卡片管理 (冻结/启用/删除/限额/扣款) |
| `AdminCardholderController` | 持卡人管理 |
| `AdminCardTransactionAuthorizationController` | 交易授权 |
| `AdminEmployeeCardController` | 员工卡管理 |
| `AdminQuantumAccountTransactionController` | 量子账户交易管理 |
| `AdminCardRefundController` | 卡退款管理 |
| `CardConsumptionLabelController` | 消费标签管理 |
| `QuantumStatisticsController` | 统计报表 |

## 关键路径速查

| 路径 | 说明 |
|------|------|
| `common_all/quantum/card/entity/QbitCard.java` | 量子卡实体 |
| `common_all/quantum/card/entity/CardSetting.java` | 卡设置实体 |
| `common_all/quantum/card/enums/QuantumCardTypeEnum.java` | 卡类型枚举 |
| `common_all/quantum/card/enums/` | 20+ 枚举 |
| `common_all/quantum/card/service/CardV3Service.java` | 卡操作接口 |
| `common_all/quantum/card/service/CardConsumptionService.java` | 消费查询 |
| `common_all/quantum/card/service/impl/MasterAccountQuantumCardService.java` | 主账户卡服务 |
| `common_all/quantum/card/handler/QbitCardHandler.java` | 储值卡处理器 |
| `common_all/quantum/card/handler/QbitBudgetCardHandler.java` | 额度卡处理器 |
| `common_all/quantum/card/handler/SubAccountPrepaidQbitCardHandler.java` | 子账户储值卡处理器 |
| `common_all/quantum/card/handler/SubAccountBudgetQbitCardHandler.java` | 子账户额度卡处理器 |
| `common_all/quantum/card/service/listener/` | 卡分组 MQ 监听器 |
| `common_all/quantum/account/service/QuantumAccountService.java` | 量子账户服务 |
| `common_all/quantum/account/service/QuantumAccountTransferService.java` | 量子转账服务 |
| `common_all/quantum/transaction/enums/BusinessCodeEnum.java` | 业务码枚举 |
| `common_all/quantum/transaction/enums/TransactionScopeEnum.java` | 交易范围枚举 |
| `common_all/quantum/transaction/service/` | 交易扩展服务 |
| `common_all/quantum/bin/service/CardBinService.java` | BIN 管理 |
| `common_all/quantum/apn/` | APN 绑定 |
| `common_all/quantum/physical_card/` | 物理卡 |
| `common_all/quantum/cardholder/` | 持卡人 |
| `common_all/quantum/statistics/` | 统计 V1 |
| `common_all/quantum/statistics_v2/` | 统计 V2 |
| `admin/quantumcard/card/controller/` | 管理端卡片 Controller |
| `admin/quantumcard/account/controller/` | 管理端账户 Controller |
| `core/service/quantum/card/impl/QuantumCardChannelFactory.java` | 渠道工厂 |
| `core/service/quantum/card/impl/AbstractQuantumCardService.java` | 卡服务模板方法 |
