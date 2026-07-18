# wjc/account-fee-20260517 分支改动总览

> 生成时间: 2026-05-30
> 源分支: develop
> 提交次数: 38 commits
> 改动文件: 76 files (+2940 / -729 lines)
> 作者: fengkewei, klover, litaoh

---

## 一、改动的核心目标

本次分支的核心任务是 **新版费率系统重构**，具体包括：

1. **新建费率体系表结构**：`fee_template`、`fee_template_item`、`account_fee_item`、`account_fee_transaction`
2. **新费率查询服务**：`AccountFeeItemService`，支持按账户层级、渠道、金额阶梯、交易国家等维度查询
3. **老费率兼容**：`AccountFeeItemConverter` 将老 `AccountFee` 表数据映射到新 `AccountFeeItem`
4. **费率交易记录**：`AccountFeeTransaction` 记录每一笔交易的费率使用情况
5. **国际费率 Key 规范化**：i18n 费率文案从旧命名迁移到新命名
6. **各业务域接入新费率**：加密资产、全球账户、出金、入金等业务改用新费率查询

---

## 二、新增数据表 / 实体

| 表名 | 实体 | 说明 |
|------|------|------|
| `fee_template` | `FeeTemplate` (extends BaseV4) | 费率模板主表，包含 accountId、businessType、customerType、customerVolume、status、isRootTemplate |
| `fee_template_item` | `FeeTemplateItem` (extends BaseV4) | 费率模板明细，包含 feeName、channel、channelField、transactionCountry、deductionNode、rateType、amount 范围、阶梯、有效时间 |
| `account_fee_item` | `AccountFeeItem` (extends FeeTemplateItem) | **账户实际生效的费率项**，新增 accountId、collectionRateValue 字段 |
| `account_fee_transaction` | `AccountFeeTransaction` (extends BaseV3) | **费率交易记录**，记录每笔交易关联的费率 ID、费率值、代收费率、手续费金额等 |

### account_fee_transaction 核心字段

| 字段 | 类型 | 说明 |
|------|------|------|
| account_id | String | 账户 ID |
| business_id | String | 业务 ID（如卡 ID） |
| transaction_id | String | 大表交易 ID |
| source_id | String | 业务表 ID |
| fee_id | String | account_fee_item 表 ID |
| fee_name | FeeTemplateNameEnum | 费用名称枚举 |
| deduction_node | FeeTemplateDeductionNodeEnum | 扣费节点（realtime / monthly） |
| rate_type | FeeTemplateRateTypeEnum | 费率类型（fixed / percentage） |
| transaction_country | FeeTemplateTransactionCountryEnum | 交易国家（domestic / international / all） |
| direction | AccountFeeTransactionDirectionEnum | 扣款方向（debit 收取 / credit 退回） |
| amount | BigDecimal | 计费基数金额 |
| rate | BigDecimal | 费率值 |
| collection_rate | BigDecimal | 代收费率 |
| fee | BigDecimal | 手续费金额 |
| collection_fee | BigDecimal | 代收费用 |
| status | String | 状态 (Closed) |
| is_settled | Boolean | 是否已结算 |

---

## 三、新增枚举

### FeeTemplateNameEnum — 费率名称（统一枚举，覆盖所有业务域）

| 业务域 | 费率名称枚举 |
|--------|------------|
| 加密资产 | CryptoAddressScanner, CryptoCreationWallet, CryptoCrossChainWithdraw, CryptoDeposit, CryptoFiatDeposit, CryptoSwap, CryptoWithdraw, CryptoStablecoinTopUpSwap |
| 量子卡 | QuantumCardVerificationFee, SchemeFeeSignature, QuantumCardActiveFee, QuantumCardApplePayFee, QuantumCardSettlementFee, SchemeServiceFee, QuantumCardATMFee, SchemeSettlementFee, QuantumCardCrossBorderBaseFee, AccountDeposit, QuantumCardOpenFee, SchemeRefundFee, QuantumCardFxFee, 等共 24 项 |
| 全球账户 | InternationalCharging, GlobalInbound2, GlobalInboundCurrencyOther, GlobalTransferIn, GlobalAccountCreateFee, GlobalInboundCurrencyMain, GlobalAchInbound, GlobalAccountToQbitWallet, GlobalAccountTransferFee, GlobalAccountMaxOpenCount |
| 粒子理财 | FundTechnicalServiceFee |

### 其他新增枚举

- **FeeTemplateBusinessTypeEnum**: quantum_card / global_account / crypto_assets / particle_financial
- **FeeTemplateDeductionNodeEnum**: realtime / monthly
- **FeeTemplateRateTypeEnum**: fixed / percentage
- **FeeTemplateTransactionCountryEnum**: domestic / international / all
- **AccountFeeTransactionDirectionEnum**: debit（收取手续费）/ credit（退回手续费）

### 修改的枚举

- **AccountFeeType**: 移除 `CRYPTO_ASSET_COLLECTION` 常量集合；新增 `getByValueNoException()` 方法

---

## 四、核心服务类

### 1. AccountFeeItemService / AccountFeeItemServiceImpl

**新费率查询核心服务**，提供以下功能：

| 方法 | 说明 |
|------|------|
| `getRate(accountId, feeName, amount, options)` | 单条费率查询，按账户层级向上递归 |
| `listRates(accountIds, nameList, options)` | 批量费率查询，支持自定义账户 ID 列表 |
| `calculateFee(feeItem, amount, precision)` | 根据费率和金额计算手续费 |
| `splitAgencyFee(fees, types, feeRates)` | 拆分代收费用（按比例拆分系统费 vs 代收费） |
| `getBusinessAccountFeeItem(request)` | 全球账户专用费率配置查询 |
| `getBusinessAccountFeeRate(request)` | 全球账户专用费率+手续费计算 |

**费率查找优先级**：当前账户 > 母账户 > 祖父账户 > 白标客户

**降级兼容**：新表无数据时自动查询老 `account_fee` 表，通过 `AccountFeeItemConverter` 转换

### 2. AccountFeeTransactionService / AccountFeeTransactionServiceImpl

- `saveAccountFeeTransaction(AccountFeeTransactionSaveBO)` — 记录费率交易，防重复（按 sourceId + feeName + direction 去重）
- 填充 accountId、transactionId、sourceId、feeId、feeName、deductionNode、rateType 等完整信息

### 3. AccountFeeItemConverter

**新老费率数据转换器**：

- `FeeTemplateNameEnum` ↔ `AccountFeeType` 映射（通过 `FEE_TYPE_MAPPING` 常量表）
- 老 `AccountFee` → 新 `AccountFeeItem` 转换
- 支持阶梯费率映射（CryptoSwap 对应 CryptoExchange / L1 / L2 / L3）
- 支持地域映射（QuantumCardSettlementFee 分为 Domestic / International）

---

## 五、各业务域接入改动

### 加密资产 (CryptoAssets)

| 文件 | 改动说明 |
|------|----------|
| ExchangeController / TransferController | 改用新费率枚举查询 i18n |
| CryptoAssetV2ServiceImpl | 改用 AccountFeeItemService 查询创建钱包、地址扫描等费率 |
| CryptoAssetV2TransferServiceImpl | 出金时使用新费率计算 |
| CryptoAssetV2WalletServiceImpl | 钱包相关费率改用新接口 |
| CryptoAssetV2TransactionServiceImpl | 交易相关费率改用新接口 |
| CryptoAssetsExchangeServiceImpl | 兑换/闪兑改用新费率（**改动最多，+185/-138**） |
| CryptoAssetsTransferServiceImpl | 转账手续费改用新费率 |
| WithdrawalCregisServiceImpl / WithdrawalSafeheronServiceImpl | 出金费率改用新费率 |
| ExchangeController | 汇率报价查询改用新枚举 |

### 全球账户 (GlobalAccount)

| 文件 | 改动说明 |
|------|----------|
| CollectUtils | 入金收款时使用新费率查询 |
| BuildTransferOrderFeeServiceImpl | 转账手续费改用新费率 |
| SaveTransferHandlerServiceImpl | 新增：保存费率交易记录 |
| AdminGlobalAccountServiceImpl | 改用新费率方法 |
| GlobalAccountService | 移除旧费率方法（**-134行**） |
| RunDatabaseEntityDTO | 新增字段支持新费率 |

### 出金 (Payout / Dispatch)

| 文件 | 改动说明 |
|------|----------|
| PaymentTransferService | 付款出金手续费改用新费率（**+162/-53**） |
| AbstractWalletTransferService | 提现转账费率调整 |
| BusinessAccountWalletTransferService | 新费率查询 |
| CryptoConnectWalletTransferService | 微调 |
| InfinityAccountWalletTransferService | 微调 |

### 资金 (Funding)

| 文件 | 改动说明 |
|------|----------|
| FundProfitServiceImpl | 改用新费率 |
| FundingTransferCryptoAssetCollectImpl | 改用新费率 |

---

## 六、国际化 i18n 费率 Key 迁移

旧 Key → 新 Key 对照：

| 旧 Key | 新 Key |
|--------|--------|
| FEE_RATE_CRYPTOUSDCINBOUND | FEE_RATE_CRYPTODEPOSIT |
| FEE_RATE_CRYPTOCREATIONSUBWALLET | FEE_RATE_CRYPTOCREATIONWALLET |
| FEE_RATE_CRYPTOEXCHANGE | FEE_RATE_CRYPTOSWAP |
| FEE_RATE_TRANSFEROUTCROSSCHAIN | FEE_RATE_CRYPTOCROSSCHAINWITHDRAW |
| FEE_RATE_ADDRESSSCANNER | FEE_RATE_CRYPTOADDRESSSCANNER |
| FEE_NAME_CRYPTOEXCHANGE | FEE_NAME_CRYPTOSWAPL1 |
| FEE_NAME_CRYPTOEXCHANGEFEEL1 | FEE_NAME_CRYPTOSWAPL2 |
| FEE_NAME_CRYPTOEXCHANGEFEEL2 | FEE_NAME_CRYPTOSWAPL3 |
| FEE_NAME_CRYPTOEXCHANGEFEEL3 | FEE_NAME_CRYPTOSWAPL4 |
| FEE_UNIT_CRYPTOCREATIONSUBWALLET | FEE_UNIT_CRYPTOCREATIONWALLET |
| FEE_DESCRIPTION_CRYPTOEXCHANGE | FEE_DESCRIPTION_CRYPTOSWAP |
| FEE_DESCRIPTION_TRANSFEROUTCROSSCHAIN | FEE_DESCRIPTION_CRYPTOCROSSCHAINWITHDRAW |

英文翻译和中文翻译同步迁移。

---

## 七、测试类

| 测试文件 | 说明 |
|----------|------|
| AccountFeeItemServiceVerificationTest (qbit-core 下两个) | AccountFeeItemService 验证测试 |
| CryptoAssetsTransferCoreServiceTest | 加密资产转账单元测试修改 |
| AccountFeeServiceTest（移除） | 旧费率测试已删除 |

---

## 八、提交历史摘要

| 日期 | 提交信息 | 作者 |
|------|----------|------|
| 5/17 | 新版费率查询 | klover |
| 5/18 | fix: 增加全球账户查询费率方法 | fengkewei |
| 5/19 | fix: 修改字段类型 | fengkewei |
| 5/19 | 加密资产、粒子理财使用新费率接口 | litaoh |
| 5/20 | 老费率兼容 | litaoh |
| 5/20 | fix: 增加迁移费率任务 | fengkewei |
| 5/21 | 老费率兼容,删除法币费率 | litaoh |
| 5/21 | fix: 修改费率查询逻辑 / 增加渠道字段设置 | fengkewei |
| 5/22 | fix: 修改查询 account_fee_item 费率逻辑 | fengkewei |
| 5/22 | 记录 fee id | litaoh |
| 5/22 | fix: 修改每页查询条数 | fengkewei |
| 5/22 | fix: 增加业务交易与费率关联表 | fengkewei |
| 5/22 | mapping | litaoh |
| 5/23 | fix: 修改获取费率查询 / ZB入金增加交易与费率关联 | fengkewei |
| 5/23 | fix: 获取手续费增加币种转换 | fengkewei |
| 5/24 | fix: 修改单元测试 | fengkewei |
| 5/29 | fix / 合并develop | klover |

---

## 九、架构总结

```
┌─────────────────────────────────────────────────────────────┐
│                    业务调用方 (各 Service)                      │
│  CryptoAssetV2Service / GlobalAccountService / PayoutService │
└───────────────┬─────────────────────────────────────────────┘
                │ 调用
┌───────────────▼─────────────────────────────────────────────┐
│              AccountFeeItemService (新费率核心)                │
│  ┌─────────────────────────────────────────────────────────┐│
│  │ getRate() → 按账户层级 + 渠道 + 阶梯 + 时间查找费率        ││
│  │ calculateFee() → rateType × amount                      ││
│  │ splitAgencyFee() → 系统费用 vs 代收费用拆分               ││
│  └─────────────────────────────────────────────────────────┘│
└───────────────┬─────────────────────────────────────────────┘
                │ 查询
┌───────────────▼─────────────────────────────────────────────┐
│  account_fee_item 表 (新)      ← 降级 →  account_fee 表 (旧)  │
│  优先查询                       AccountFeeItemConverter 转换   │
└─────────────────────────────────────────────────────────────┘
                │ 保存
┌───────────────▼─────────────────────────────────────────────┐
│          AccountFeeTransactionService                       │
│          → 写入 account_fee_transaction 表                    │
│          → 记录每笔交易的费率使用情况                           │
└─────────────────────────────────────────────────────────────┘
```

---

---

## 十一、新账户费率系统表关系图谱

### 表关系总览

```
┌─────────────────────────────────────────────────────────────────────────────┐
│                          fee_template (费率模板主表)                          │
│  BaseV4(id,remarks,createTime,updateTime,deleteTime,version)                │
│  + accountId, templateName, businessType, customerType                      │
│  + customerVolume, status, isRootTemplate                                   │
└──────────────────────────┬──────────────────────────────────────────────────┘
                           │ 1:N (template_id)
                           ▼
┌─────────────────────────────────────────────────────────────────────────────┐
│                       fee_template_item (费率模板明细)                        │
│  BaseV4(id,remarks,createTime,updateTime,deleteTime,version)                │
│  + templateId, feeName, channel, channelField, transactionCountry           │
│  + deductionNode, rateType, maxAmount, minAmount, rateValue                 │
│  + effectiveTime, expirationTime, ladderMaxAmount, ladderMinAmount          │
└─────────────────────────────────────────────────────────────────────────────┘
        ↑ (继承关系: Java class extends, 但独立建表)
        │
┌───────┴─────────────────────────────────────────────────────────────────────┐
│                    account_fee_item (账户实际生效费率)                         │
│  继承 FeeTemplateItem 所有字段 +                                             │
│  + accountId ───────────────────────────────┐                              │
│  + collectionRateValue                       │                              │
└──────────────────┬──────────────────────────┘                              │
                   │ 1:N (fee_id)                                             │
                   ▼                                                          │
┌──────────────────────────────────────────────────────────────────────┐      │
│              account_fee_transaction (费率交易记录)                     │      │
│  BaseV3(id,remarks,createTime,updateTime,deleteTime,version)          │      │
│  + accountId ─────────────────────────────────────────────────────────┘      │
│  + businessId, transactionId, sourceId, feeId (→ account_fee_item.id)       │
│  + feeName, deductionNode, rateType, transactionCountry, direction          │
│  + amount, rate, collectionRate, fee, collectionFee                         │
│  + status, isSettled                                                        │
└─────────────────────────────────────────────────────────────────────────────┘
                                    ▲
                                    │
┌───────────────────────────────────┴─────────────────────────────────────────┐
│                         account (账户表, 外部关联)                            │
│                         account.id ← account_fee_item.account_id            │
│                         account.id ← account_fee_transaction.account_id      │
└─────────────────────────────────────────────────────────────────────────────┘
```

### 继承关系（Java 类层次）

```
BaseV4 (id, remarks, createTime, updateTime, deleteTime, version)
  ├── FeeTemplate (table: fee_template)
  │    字段: accountId, templateName, businessType, customerType, customerVolume, status, isRootTemplate
  │
  └── FeeTemplateItem (table: fee_template_item)
       字段: templateId, feeName, channel, channelField, transactionCountry,
             deductionNode, rateType, maxAmount, minAmount, rateValue,
             effectiveTime, expirationTime, ladderMaxAmount, ladderMinAmount
        │
        └── AccountFeeItem (table: account_fee_item) ← 继承 FeeTemplateItem
             新增字段: accountId, collectionRateValue

BaseV3 (id, remarks, createTime, updateTime, deleteTime, version)
  └── AccountFeeTransaction (table: account_fee_transaction)
       字段: accountId, businessId, transactionId, sourceId, feeId,
            feeName, deductionNode, rateType, transactionCountry, direction,
            amount, rate, collectionRate, fee, collectionFee, status, isSettled
```

### 核心关联关系

| 左表 | 关系 | 右表 | 关联键 | 语义 |
|------|------|------|--------|------|
| `fee_template` | 1 → N | `fee_template_item` | `template_id` → `id` | 一个模板包含多条费率明细 |
| `fee_template_item` | 父→子 (继承) | `account_fee_item` | Java extends, 独立建表 | 模板项实例化为账户具体费率 |
| `account` | 1 → N | `account_fee_item` | `account_id` → `id` | 一个账户可配置多条费率 |
| `account_fee_item` | 1 → N | `account_fee_transaction` | `fee_id` → `id` | 一条费率被多笔交易使用 |
| `account` | 1 → N | `account_fee_transaction` | `account_id` → `id` | 一个账户有多笔费率交易 |

### 实体类型映射

```
FeeTemplateNameEnum  ←→  AccountFeeType (通过 AccountFeeItemConverter)
  (新枚举)                   (旧枚举)

FeeTemplateBusinessTypeEnum ── 标识费率所属业务域
  ├── crypto_assets          → 加密资产
  ├── quantum_card           → 量子卡
  ├── global_account         → 全球账户
  └── particle_financial     → 粒子理财
```

### 数据流

```
Admin后台配置
    │
    ▼
fee_template (模板)
    │
    ▼
fee_template_item (模板项)
    │
    ▼
account_fee_item (账户费率, 含生效时间范围)
    │                           ▲
    │                           │ 降级兼容
    │                    account_fee (旧表)
    │
    ├── AccountFeeItemService.getRate() → 查询费率
    │
    └── AccountFeeTransactionService.saveAccountFeeTransaction()
            │
            ▼
    account_fee_transaction (记录交易关联的费率)
```

---

## 十二、新老费率关联机制

### 关联方式：双表兼容 + 降级查询

新老费率的关联通过 **三种方式** 实现：

### 方式一：枚举映射（AccountFeeItemConverter）

通过 `FEE_TYPE_MAPPING` 常量表将新枚举 `FeeTemplateNameEnum` ↔ 旧枚举 `AccountFeeType` 一一映射：

```
FeeTemplateNameEnum.CryptoDeposit           ←→ AccountFeeType.CryptoUSDCInbound
FeeTemplateNameEnum.CryptoWithdraw          ←→ AccountFeeType.CRYPTO_WITHDRAW_COIN
FeeTemplateNameEnum.CryptoCrossChainWithdraw ←→ AccountFeeType.TransferOutCrossChain
FeeTemplateNameEnum.CryptoSwap              ←→ AccountFeeType.CryptoExchange + L1/L2/L3 (阶梯)
FeeTemplateNameEnum.QuantumCardSettlementFee ←→ AccountFeeType.QuantumCardSettlementFeeDom/DomRate/Int/IntRate (境内外)
```

提供双向转换方法：

| 方法 | 方向 | 用途 |
|------|------|------|
| `convert(FeeTemplateNameEnum)` | 新→旧 | 降级时将新枚举转成旧枚举列表去查旧表 |
| `convert(AccountFeeType)` | 旧→新 | 将旧 `AccountFee` 转成新 `AccountFeeItem` 时还原枚举 |
| `convert(AccountFee)` | 旧实体→新实体 | 字段级映射（rate、provider、startTime 等） |
| `convertList(List<AccountFee>)` | 批量旧→新 | 批量转换 |

### 方式二：查询时自动降级（fetchAccountFeeList）

在 `AccountFeeItemServiceImpl.fetchAccountFeeList()` 中，**先查新表，新表无数据时自动降级旧表**：

```
getRate() / listRates()
    │
    ▼
查询 account_fee_item 表 (新)
    │
    ├── 有数据 → 直接返回 AccountFeeItem
    │
    └── 无数据 → AccountFeeItemConverter.convertTypeList(nameList)
                  → FeeTemplateNameEnum 转 AccountFeeType 列表
                  → 查询 account_fee 表 (旧)
                  → AccountFeeItemConverter.convertList()
                  → 返回 AccountFeeItem
```

### 方式三：业务层独立降级（getBusinessAccountFeeItem）

全球账户等业务场景采用两层显式降级：

```
getBusinessAccountFeeItem(request)
    │
    ▼
step1: getRate(新表) → 有数据则直接返回
    │
    无数据
    ▼
step2: getAccountFeeType() → 通过 FeeTemplateNameEnum.getValue() 匹配 AccountFeeType
    │
    ▼
step3: accountFeeService.getFeeRate(旧表) → 查老 account_fee
    │
    ▼
step4: convertToAccountFeeItem() → 老数据转成新实体返回
```

### 字段映射对照

| 旧 account_fee | 新 account_fee_item | 说明 |
|----------------|---------------------|------|
| account_id | account_id | 直传 |
| fee_type (AccountFeeType) | fee_name (FeeTemplateNameEnum) | 枚举转换 |
| provider | channel | 渠道缩写 (CC/QB/CL/ZB) |
| provider_field | channel_field | 直传 |
| rate | rate_value | 直传 |
| collection_rate | collection_rate_value | 直传 |
| math_type | rate_type | Count→FIXED, 其他→PERCENTAGE |
| start_time | effective_time | 生效时间 |
| end_time | expiration_time | 失效时间 |
| low | ladder_min_amount | 阶梯下限 |
| high | ladder_max_amount | 阶梯上限 |
| — | min_amount | 新表新增，最小值限制 |
| — | max_amount | 新表新增，最大值限制 |
| — | transaction_country | 新表新增，境内/境外/全部 |
| — | deduction_node | 新表新增，扣费节点 |

### 需要注意的点

1. **降级是代码级兼容**，不是数据迁移。新表灌入数据后降级逻辑自动不再触发
2. **阶梯费率映射**：旧表多条记录表阶梯（CryptoExchange/L1/L2/L3），新表用一条 `CryptoSwap` + `ladderMinAmount`/`ladderMaxAmount`
3. **地域拆分映射**：旧表 `QuantumCardSettlementFee*` 分4条（Dom/DomRate/Int/IntRate），新表合并为一条 + `transactionCountry`
4. **`getByValueNoException()`**：旧枚举新增此方法，通过 value 字符串匹配，使得新旧枚举 value 值能直接对应

---

## 十三、待改造的旧 AccountFee 查询（createBillJobHandler 调用链）

`createBillJobHandler` → `initBill` 调用链中，有 **5 处旧 AccountFee 查询** 需迁移到新 `AccountFeeItemService`：

```
createBillJobHandler (ApiCustomerJob.java:133)
  └─ apiClientBillService.initBill() (ApiClientBillServiceImpl.java:196)
       ├─ createApiClientBillStatement() (第438行)
       │    └─ getApiClientMonthlySettlementFee() (ApiClientTransactionServiceImpl.java:119)
       │         ├─ identityVerificationMap (第304行)
       │         └─ buildExtendData (第361/379/397行)
       └─ extracted() (第447行)
            └─ dealMonthlyRejectPayByAccount → dealAccountFee (第1010行)
```

| # | 文件 | 行号 | 旧 AccountFeeType | 新 FeeTemplateNameEnum | 当前查询方式 | 说明 |
|---|------|------|-------------------|----------------------|-------------|------|
| 1 | `ApiClientBillServiceImpl.java` | 1034-1041 | `DECLINE_FEE_API_ACCOUNT_CAAS` | `DeclineFee` | `accountFeeMapper.selectList` + `LambdaQueryWrapper<AccountFee>` | 拒付罚款费率，直接查旧表 |
| 2 | `ApiClientTransactionServiceImpl.java` | 304 | `KYC_INTERFACE_CALL_FEE_CAAS` | `KycInterfaceCallFee` 🆕 | `accountFeeService.identityVerificationFee()` | KYC 认证费，批量查旧表 |
| 3 | `ApiClientTransactionServiceImpl.java` | 379 | `MONTHLY_ACTIVE_CARD_FEE_CAAS` | `MonthlyActiveCardFee` 🆕 | `accountFeeService.getCaasFeeRate()` | 月活跃卡费 |
| 4 | `ApiClientTransactionServiceImpl.java` | 361 | `ACCOUNT_DEPOSIT_CAAS` | `AccountDeposit` | `accountFeeService.getCaasFeeRate()` | 入金充值费 |
| 5 | `ApiClientTransactionServiceImpl.java` | 397 | `QUANTUM_CARD_NOT_ACTIVE_FEE_CAAS` | `QuantumCardNotActiveFee` | `accountFeeService.getCaasFeeRate()` | 未激活卡管理费 |

**改造方式**（统一替换为 `AccountFeeItemService`）：

| # | 旧代码 | 改为 |
|---|--------|------|
| 1 | `accountFeeMapper.selectList(wrapper)` 查阶梯费率 | `accountFeeItemService.listRates(accountId, List.of(FeeTemplateNameEnum.DeclineFee), options)`，通过 `ladderMinAmount`/`ladderMaxAmount` 做阶梯匹配 |
| 2 | `accountFeeService.identityVerificationFee()` | `accountFeeItemService.getRate(accountId, FeeTemplateNameEnum.KycInterfaceCallFee)`，乘以 KYC 次数 |
| 3 | `accountFeeService.getCaasFeeRate(MONTHLY_ACTIVE_CARD_FEE_CAAS, ...)` | `accountFeeItemService.getRate(accountId, FeeTemplateNameEnum.MonthlyActiveCardFee, options)`，取 channel 匹配 |
| 4 | `accountFeeService.getCaasFeeRate(ACCOUNT_DEPOSIT_CAAS, ...)` | `accountFeeItemService.getRate(accountId, FeeTemplateNameEnum.AccountDeposit, options)` |
| 5 | `accountFeeService.getCaasFeeRate(QUANTUM_CARD_NOT_ACTIVE_FEE_CAAS, ...)` | `accountFeeItemService.getRate(accountId, FeeTemplateNameEnum.QuantumCardNotActiveFee, options)` |

---

## 十四、关键设计决策

1. **双表兼容**：新 `account_fee_item` 表无数据时降级查询老 `account_fee` 表，通过 `AccountFeeItemConverter` 自动转换
2. **费率按账户层级追溯**：当前账户 → 母账户 → 祖父账户 → 白标客户，使用递归查询
3. **渠道+阶梯维度扩展**：新表支持 `channel`、`channelField`、`ladderMin/MaxAmount` 等多维度费率查询
4. **代收费用拆分**：通过 `collectionRateValue / rateValue` 比例拆分系统手续费和代收手续费
5. **UUID 字段处理**：Long 类型 tenantId 通过 `HexUtil.longToUUID()` 转 UUID 查询
6. **Mapper XML 优先排序**：`getFeeRate` 查询通过 `array_position` 数组排序实现按 accountIds 传入顺序优先匹配

---

## 十五、量子卡月结改造方案（ApiCustomerBill）

### 背景

`ApiCustomerJob.createBillJobHandler` → `initBill` 调用链中，月结费用计算目前混合使用了：
- **ODS 数仓**（已发生的交易手续费）
- **旧 `account_fee` 表查费率**（5 种特殊费用）
- **`api_client_transaction` 表**（scheme 层费用）

改造目标是统一迁移到新费率体系，基于 `account_fee_transaction` 做月结汇总。

---

### 15.1 核心概念对齐

```
旧系统                            新系统
───────────────────────────────────────────────────────
ApiClientFeeEnum                 FeeTemplateNameEnum
  ._CLOSED 后缀 (实收)         →  deduction_node = REALTIME
                                  已扣费，直接在 account_fee_transaction 中

  .非 CLOSED (月结)            →  deduction_node = MONTHLY
                                  月末算费

api_client_transaction 表       →  此部分待确认是否需要保留
                                  或统一迁移到 account_fee_transaction

accountFee 表 (旧)              →  fee_template → fee_template_item
                                    → account_fee_item (账户生效费率)

dealAccountFee(梯度拒付费)       →  AccountFeeItemService 查费率(ladder阶梯)
                                   + 月结时批量计算
```

**关键理解**：`FeeTemplateDeductionNodeEnum` 的两个值对应月结的不同数据来源：

| deduction_node | 含义 | 月结处理方式 |
|---------------|------|-------------|
| `REALTIME` | 交易时实时扣费 | 直接汇总 `account_fee_transaction`，对应旧 `_CLOSED` 项 |
| `MONTHLY` | 月末批量算费 | 月末按费率批量计算，再写入/更新 `account_fee_transaction` |

---

### 15.2 需补充的 FeeTemplateNameEnum

当前 `FeeTemplateNameEnum` 缺少 2 个枚举值（月结 5 种特殊费用中有 2 种没有对应项）：

| 旧 accountFee 类型 | 当前 FeeTemplateNameEnum | 需操作 |
|--------------------|------------------------|--------|
| `DeclineFeeAPIAccount_Caas` | `DeclineFee` ✅ 已存在 | 无需操作 |
| `AccountDeposit_Caas` | `AccountDeposit` ✅ 已存在 | 无需操作 |
| `QuantumCardNotActiveFee_Caas` | `QuantumCardNotActiveFee` ✅ 已存在 | 无需操作 |
| `MonthlyActiveCardFee_Caas` | ❌ 不存在 | **需新增** |
| `KycInterfaceCallFee_Caas` | ❌ 不存在 | **需新增** |

**需新增的枚举**：

```java
// 在 FeeTemplateNameEnum 中 QUANTUM_CARD 组追加：
MonthlyActiveCardFee("MonthlyActiveCardFee", FeeTemplateBusinessTypeEnum.QUANTUM_CARD),
KycInterfaceCallFee("KycInterfaceCallFee", FeeTemplateBusinessTypeEnum.QUANTUM_CARD),
```

并在 `AccountFeeItemConverter.FEE_TYPE_MAPPING` 中补充映射：

```java
Map.entry(FeeTemplateNameEnum.MonthlyActiveCardFee, List.of(AccountFeeType.MonthlyActiveCardFee_Caas)),
Map.entry(FeeTemplateNameEnum.KycInterfaceCallFee, List.of(AccountFeeType.KycInterfaceCallFee_Caas)),
```

---

### 15.3 full ApiClientFeeEnum ↔ FeeTemplateNameEnum 映射

| ApiClientFeeEnum (旧) | FeeTemplateNameEnum (新) | deduction_node | 月结数据来源 |
|----------------------|-------------------------|---------------|-------------|
| SETTLEMENT_FEE_CLOSED | QuantumCardSettlementFee | REALTIME | account_fee_transaction 汇总 |
| CARD_CREATION_FEE_CLOSED | QuantumCardActiveFee | REALTIME | account_fee_transaction 汇总 |
| AUTH_FEE_CLOSED | QuantumCardAuthorizationFee | REALTIME | account_fee_transaction 汇总 |
| APPLE_PAY_AUTH_FEE_CLOSED | QuantumCardApplePayFee | REALTIME | account_fee_transaction 汇总 |
| TOP_UP_FEE_CLOSED | AccountDeposit | REALTIME | account_fee_transaction 汇总 |
| PHYSICALCARD_FEE_CLOSED | QuantumCardMakeCardFee | REALTIME | account_fee_transaction 汇总 |
| ATM_WITHDRAWAL_FEE_CLOSED | QuantumCardATMFee | REALTIME | account_fee_transaction 汇总 |
| --- | --- | --- | --- |
| DECLINE_FEE | DeclineFee | MONTHLY | 月结时算 = 拒付笔数 × 阶梯费率 |
| MONTHLY_CARD_FEE | MonthlyActiveCardFee 🆕 | MONTHLY | 月结时算 = 活跃卡数 × 费率 |
| IDENTITY_VERIFICATION | KycInterfaceCallFee 🆕 | MONTHLY | 月结时算 = KYC 次数 × 费率 |
| INACTIVE_CARD_MANAGEMENT_FEE | QuantumCardNotActiveFee | MONTHLY | 月结时算 = 未激活卡数 × 费率 |
| TOP_UP_FEE | AccountDeposit | MONTHLY | 月结时算 = 充值金额 × 费率 |
| --- | --- | --- | --- |
| SETTLEMENT_FEE | QuantumCardSettlementFee | MONTHLY | 来自 provider/ODS 数据 |
| AUTH_FEE | QuantumCardAuthorizationFee | MONTHLY | 来自 provider/ODS 数据 |
| CROSS_BORDER_FEE | QuantumCardCrossBorderFee | MONTHLY | account_fee_transaction 中已有 |
| REFUND_FEE | QuantumCardRefundFee | MONTHLY | account_fee_transaction 中已有 |
| ... 其余 scheme 级费用 | 对应 FeeTemplateNameEnum | MONTHLY | 待确认来源 |

---

### 15.4 5 种特殊费用的月结处理流程

这 5 种费用 **没有单笔交易记录**，需要在月末统一计算：

```
每月1号凌晨
    │
    ▼
对每个 accountId:
    │
    ├── 1. DeclineFee (拒付费)
    │    ├── 查询该月拒付笔数 (rejectPayCount)
    │    ├── AccountFeeItemService.getRate(DeclineFee, amount=笔数)
    │    │   └── 新表 account_fee_item 的 ladderMin/MaxAmount 天然支持阶梯
    │    │   └── 例: ladderMinAmount=0,20   → 0-20笔 单价0.3
    │    │        ladderMinAmount=20,100   → 20-100笔 单价0.5
    │    ├── fee = rejectPayCount × rateValue
    │    └── 写入 account_fee_transaction (deduction_node=MONTHLY, status=Closed)
    │
    ├── 2. MonthlyActiveCardFee (月活跃卡费)
    │    ├── 查询该月活跃卡数 (按 provider 区分)
    │    ├── AccountFeeItemService.getRate(MonthlyActiveCardFee, channel=provider)
    │    ├── fee = 活跃卡数 × rateValue
    │    └── 写入 account_fee_transaction
    │
    ├── 3. KycInterfaceCallFee (KYC认证费)
    │    ├── 查询该月 KYC 调用次数
    │    ├── AccountFeeItemService.getRate(KycInterfaceCallFee)
    │    ├── fee = KYC次数 × rateValue
    │    └── 写入 account_fee_transaction
    │
    ├── 4. InactiveCardManagementFee (未激活卡费)
    │    ├── 查询该月未激活卡数
    │    ├── AccountFeeItemService.getRate(QuantumCardNotActiveFee)
    │    ├── fee = 未激活卡数 × rateValue
    │    └── 写入 account_fee_transaction
    │
    └── 5. AccountDeposit (入金充值费)
         ├── 从 ODS 汇总该月充值金额
         ├── AccountFeeItemService.getRate(AccountDeposit)
         ├── fee = 充值金额 × rateValue
         └── 写入 account_fee_transaction
```

**注意**：`DeclineFee` 的阶梯逻辑在旧系统中是通过 `accountFee.low/high` 字段实现的，新表 `fee_template_item` 的 `ladderMinAmount`/`ladderMaxAmount` 就是对应的阶梯字段。不需要特殊处理，`AccountFeeItemService.listRates()` 已经支持阶梯排序返回。

---

### 15.5 account_fee_transaction 的 status 语义设计

当前 `status` 只有硬编码 `"Closed"` 一个值。建议明确 status 语义以支持月结流程：

| status | 含义 | 适用场景 |
|--------|------|---------|
| `Pending` | 待结算 | deduction_node=MONTHLY 的费用，已记录但未月结 |
| `Closed` | 已结算 | 已进入月账单的费用 |

**月结流程中的状态流转**：

```
REALTIME 费用:
  交易时写入 → status=Closed (已扣费，直接汇总)

MONTHLY 费用:
  方式 A: 平时交易时写入 → status=Pending → 月结时更新 status=Closed
  方式 B: 月结时才计算 → 直接写入 status=Closed

5 种特殊费用:
  月结时计算并写入 → status=Closed (一次性)
```

---

### 15.6 月结整体流程（改造后）

```
createBillJobHandler
    │
    ▼
initBill(accountIds, billMonth)
    │
    ▼
createApiClientBillStatement
    │
    ├── 1. 汇总 account_fee_transaction 中已 Closed 的费用
    │    ├── deduction_node=REALTIME → 直接取 fee 金额
    │    └── deduction_node=MONTHLY, status=Closed → 直接取 fee 金额
    │
    ├── 2. 计算 5 种特殊月结费用
    │    ├── AccountFeeItemService 查费率
    │    ├── 从 ODS 或其他来源取计费基数(笔数/卡数/金额)
    │    ├── 计算 fee
    │    └── 写入 account_fee_transaction (status=Closed)
    │
    ├── 3. 处理 deduction_node=MONTHLY, status=Pending 的费用
    │    ├── 对每条 Pending 记录执行结算
    │    └── 更新 status=Closed, is_settled=true
    │
    ├── 4. 费用汇总 → ApiClientMonthFeeVO
    │    └── FeeTemplateNameEnum → ApiClientFeeEnum 映射
    │
    └── 5. 生成账单明细
```

---

### 15.7 实现步骤清单

| 步骤 | 内容 | 涉及文件 |
|------|------|---------|
| **Step 1** | `FeeTemplateNameEnum` 新增 `MonthlyActiveCardFee`、`KycInterfaceCallFee` | `FeeTemplateNameEnum.java` |
| **Step 2** | `AccountFeeItemConverter.FEE_TYPE_MAPPING` 补充新枚举映射 | `AccountFeeItemConverter.java` |
| **Step 3** | 新增转换器方法：`FeeTemplateNameEnum` ↔ `ApiClientFeeEnum`（或在月结服务中维护） | 新建 `ApiClientFeeConverter.java` |
| **Step 4** | 在数据库中为 5 种费用添加 `fee_template_item` + `account_fee_item` 数据 | SQL 脚本 |
| **Step 5** | 改造 `getApiClientMonthlySettlementFee`：<br>— 5 种特殊费用改用 `AccountFeeItemService`<br>— 其他 REALTIME 费用改为汇总 `account_fee_transaction`<br>— 计算后写入 `account_fee_transaction` | `ApiClientTransactionServiceImpl.java` |
| **Step 6** | 改造 `dealAccountFee`（拒付费梯度）：<br>— `LambdaQueryWrapper<AccountFee>` → `AccountFeeItemService.listRates()`<br>— `ladderMinAmount`/`ladderMaxAmount` 替代 `low`/`high` | `ApiClientBillServiceImpl.java` |
| **Step 7** | 统一 `getCaasFeeRate` 的 3 处调用改为 `AccountFeeItemService` | `ApiClientTransactionServiceImpl.java` |
| **Step 8** | 明确 `account_fee_transaction.status` 枚举语义（Pending/Closed） | `AccountFeeTransactionServiceImpl.java` |
| **Step 9** | 补充 `related_id` 到 `FeeTemplateItem` 实体（当用途明确后） | `FeeTemplateItem.java` |

---

### 15.8 关于 `related_id` 的建议

`fee_template_item.related_id` 目前有建表无代码使用。从已有数据看，示例值为 `2adb794c-0009-47bc-8d62-ed1625a3a2ea`（一个 UUID）。

可能的用途：
1. **关联旧 `accountFee.id`** — 数据迁移时标记来源
2. **费率项间关联** — 如百分比费率项关联到封顶/保底费率项
3. **关联外部业务 ID** — 如 scheme 费率编号

建议确认 DBA 或建表人的设计意图后再使用。如果暂无明确用途，可以在实体中先补充字段，不影响改造。

---

### 15.9 数据库 fee_template_item 配置示例

以 **量子默认费率-直客(勿动)** 模板（`template_id = 2054479724258758658`）为例，补充 5 种月结费用的 `fee_template_item`：

```sql
-- MonthlyActiveCardFee（按 provider 分多条）
INSERT INTO fee_template_item (id, template_id, fee_name, channel, deduction_node, rate_type, rate_value, effective_time, expiration_time)
VALUES
(next_id(), 2054479724258758658, 'MonthlyActiveCardFee', 'QbitIssuing', 'monthly', 'fixed', 0.12, '2026-02-01', '2099-12-31'),
(next_id(), 2054479724258758658, 'MonthlyActiveCardFee', 'Slash', 'monthly', 'fixed', 0.10, '2026-02-01', '2099-12-31'),
(next_id(), 2054479724258758658, 'MonthlyActiveCardFee', 'BlueBanc', 'monthly', 'fixed', 0.12, '2026-02-01', '2099-12-31'),
(next_id(), 2054479724258758658, 'MonthlyActiveCardFee', 'I2c', 'monthly', 'fixed', 0.25, '2026-02-01', '2099-12-31');

-- KycInterfaceCallFee
INSERT INTO fee_template_item (id, template_id, fee_name, deduction_node, rate_type, rate_value, effective_time, expiration_time)
VALUES
(next_id(), 2054479724258758658, 'KycInterfaceCallFee', 'monthly', 'fixed', 1.5, '2026-02-01', '2099-12-31');

-- DeclineFee（阶梯费率，用 ladderMinAmount/ladderMaxAmount）
INSERT INTO fee_template_item (id, template_id, fee_name, deduction_node, rate_type, rate_value, ladder_min_amount, ladder_max_amount, effective_time, expiration_time)
VALUES
(next_id(), 2054479724258758658, 'DeclineFee', 'monthly', 'fixed', 0, '0', '20', '2026-03-20', '2099-12-31'),
(next_id(), 2054479724258758658, 'DeclineFee', 'monthly', 'fixed', 0.5, '20', '100', '2026-03-20', '2099-12-31');

-- QuantumCardNotActiveFee
INSERT INTO fee_template_item (id, template_id, fee_name, deduction_node, rate_type, rate_value, effective_time, expiration_time)
VALUES
(next_id(), 2054479724258758658, 'QuantumCardNotActiveFee', 'monthly', 'fixed', 0, '2024-08-01', '2099-12-31');
```

---

## 十六、AccountFeeTransaction 三个核心业务字段说明

**数据来源**：`qbitpay_service` TypeScript 端 + `qbit-assets` Java 端

### 字段总览

| 字段 | 注释 | 量子卡场景（qbitpay_service） | 全局账户入金场景（qbit-assets） |
|------|------|-------------------------------|-------------------------------|
| `business_id` | 业务 ID（注释：卡 ID） | `FeeV3Input.cardId` = `qbitCard.id` | **从未赋值** |
| `transaction_id` | 我方交易 ID | `FeeV3Input.txId` = `transactionObj.id`（余额交易 ID） | `transfer.getTransactionId()`（全局交易流水号） |
| `source_id` | 业务表 ID | `FeeV3Input.sourceId`（部分场景未设，如开卡） | `transfer.getId()`（入金记录 ID） |

### 各场景具体赋值

#### 场景 1：全局账户入金（qbit-assets, Java）

```java
// SaveTransferHandlerServiceImpl
accountFeeTransactionSaveBO.setSourceId(transfer.getId());              // source_id = 入金记录ID
accountFeeTransactionSaveBO.setTransactionId(transfer.getTransactionId()); // transaction_id = 全局交易流水号
// business_id 未设置（Java 端从未赋值）
```

#### 场景 2：量子卡开卡（qbitpay_service, TypeScript）

```typescript
const input: FeeV3Input = {
  accountId: account.id,
  feeName: FeeTemplateNameEnum.QuantumCardOpenFee,
  cardId: qbitCard.id,       // → business_id = 卡ID
  // sourceId 未设置（开卡场景）
};
// 创建余额交易后
input.txId = transactionObj.id;  // → transaction_id = 余额交易ID（Balance Transaction）
await this.accountFeeItemService.getMonthlyFees(input, res);

// 写入后更新状态
await manager.update(AccountFeeTransaction,
  { sourceId: input.txId, businessId: input.cardId, accountId: input.accountId, status: TransactionStatusEnum.Pending },
  { status: TransactionStatusEnum.Closed, transactionId: transactionObj.id },
);
```

#### 场景 3：出金/量子卡交易（qbit-assets, PaymentTransferService）

```java
// PaymentTransferService.saveAccountFeeTransaction
QbitCardWalletTransaction qbitCardWalletTransaction = ...;
accountFeeTransactionSaveBO.setTransactionId(qbitCardWalletTransaction.getId());        // source_id
accountFeeTransactionSaveBO.setTransactionId(qbitCardWalletTransaction.getTransactionId()); // transaction_id
// business_id 未设置
```

### 注意点

1. **`account_fee_transaction` 没有 `provider` 字段**，无法按供应商纬度聚合月费数据
2. **`business_id` 在 Java 端（qbit-assets）从未赋值**，仅在 TypeScript 端（qbitpay_service）赋值
3. **`transaction_id` 语义不一致**：Java 端是全局交易流水号（`Transfer.transactionId`），TypeScript 端是余额交易 ID（`transactionObj.id`）
4. **`source_id` 语义基本一致**：都是业务记录主键，但部分场景（如开卡）未设置
5. **唯一索引**：`(account_id, source_id, business_id, fee_name, rate_type, transaction_country)`

---

## 十七、FeeTemplateNameEnum ↔ ApiClientFeeEnum 完整映射

> 用于月结改造：`account_fee_transaction.feeName` (FeeTemplateNameEnum) 转成月结返回的 `ApiClientFeeEnum`

### REALTIME 费用（已实收，account_fee_transaction 中已有数据）

| FeeTemplateNameEnum | deduction_node | ApiClientFeeEnum | 说明 |
|---------------------|---------------|------------------|------|
| `QuantumCardSettlementFee` | REALTIME | `SETTLEMENT_FEE_CLOSED` | 结算手续费(实收) |
| `QuantumCardOpenFee` | REALTIME | `CARD_CREATION_FEE_CLOSED` | 实时开卡费 |
| `QuantumCardAuthorizationFee` | REALTIME | `AUTH_FEE_CLOSED` | 授权费实收 |
| `QuantumCardApplePayFee` | REALTIME | `APPLE_PAY_AUTH_FEE_CLOSED` | Apple Pay服务费实收 |
| `AccountDeposit` | REALTIME | `TOP_UP_FEE_CLOSED` | 实时充值手续费 |
| `QuantumCardMakeCardFee` | REALTIME | `PHYSICALCARD_FEE_CLOSED` | 实体卡制卡费实收 |
| `QuantumCardATMFee` | REALTIME | `ATM_WITHDRAWAL_FEE_CLOSED` | ATM取现手续费Closed |
| `QuantumCardVerificationFee` | REALTIME | `VERIFICATION_FEE` | 绑卡验证费 |

### MONTHLY 费用（月结计算，可能在 account_fee_transaction 中已有或需月结时写入）

| FeeTemplateNameEnum | ApiClientFeeEnum | 说明 |
|---------------------|------------------|------|
| `AccountDeposit` | `TOP_UP_FEE` | 月结充值手续费 |
| `QuantumCardSettlementFee` | `SETTLEMENT_FEE` | 结算手续费 |
| `QuantumCardOpenFee` | `CARD_CREATION_FEE` | 开卡费 |
| `QuantumCardAuthorizationFee` | `AUTH_FEE` | 授权费 |
| `QuantumCardApplePayFee` | `APPLE_PAY_AUTH_FEE` | Apple Pay服务费 |
| `QuantumCardMakeCardFee` | `CARD_PRODUCTION_FEE` | 制卡费 |
| `QuantumCardATMFee` | `ATM_WITHDRAWAL_FEE` | ATM取现手续费 |
| `QuantumCardCrossBorderFee` | `CROSS_BORDER_FEE` | 跨境手续费 |
| `QuantumCardFxFee` | `FX_FEE` | 汇兑费用 |
| `QuantumCardRefundFee` | `REFUND_FEE` | 退款手续费 |
| `QuantumCardRefundCustomerRefundFee` | `REFUND_CLIENT_FEE` | 退款客户退款手续费 |
| `QuantumCardReversalFee` | `REVERSAL_FEE` | 撤销手续费 |
| `DeclineFee` | `DECLINE_FEE` | 交易失败手续费 |
| `MonthlyActiveCardFee` | `MONTHLY_CARD_FEE` | 活跃卡月费 |
| `QuantumCardNotActiveFee` | `INACTIVE_CARD_MANAGEMENT_FEE` | 非活跃卡管理费 |
| `KycInterfaceCallFee` | `IDENTITY_VERIFICATION` | 身份验证费用 |
| `QuantumCardShoppingFee` | `POSTAGE_FEE` | 邮寄费 |

### Scheme 层费用（按交易国家分）

| FeeTemplateNameEnum | transactionCountry | ApiClientFeeEnum |
|---------------------|-------------------|------------------|
| `SchemeServiceFee` | DOMESTIC | `ISSUER_CARD_SERVICE_DOM_FEE` |
| `SchemeServiceFee` | INTERNATIONAL | `ISSUER_CARD_SERVICE_INT_FEE` |
| `SchemeVRMFee` | DOMESTIC | `VISA_RISK_MANAGER_DOM_FEE` |
| `SchemeVRMFee` | INTERNATIONAL | `VISA_RISK_MANAGER_INT_FEE` |
| `SchemeAuthFee` | DOMESTIC | `ISSUER_TRANSACTION_AUTH_DOM_FEE` |
| `SchemeAuthFee` | INTERNATIONAL | `ISSUER_TRANSACTION_AUTH_INT_FEE` |
| `SchemeSettlementFee` | DOMESTIC | `ISSUER_TRANSACTION_SETTLEMENT_DOM_FEE` |
| `SchemeSettlementFee` | INTERNATIONAL | `ISSUER_TRANSACTION_SETTLEMENT_INT_FEE` |
| `SchemeVerificationFee` | DOMESTIC | `SCHEME_VERIFICATION_DOM_FEE` |
| `SchemeVerificationFee` | INTERNATIONAL | `SCHEME_VERIFICATION_INT_FEE` |
| `SchemeRefundFee` | — | `SCHEME_REFUND_FEE` |
| `SchemeReversalFee` | — | `SCHEME_REVERSAL_FEE` |
| `SchemeFeeSignature` | — | `SCHEME_SIGNATURE_FEE` |

### 无对应 FeeTemplateNameEnum 的 ApiClientFeeEnum（特殊处理）

| ApiClientFeeEnum | 处理方式 |
|------------------|----------|
| `REVENUE_ADJUSTMENT` | 营收补差—来自 cashBackBonusMapper（单独数据源） |
| `REVENUE_ADJUSTMENT` | 营收补差—来自 cashBackBonusMapper（单独数据源） |
| `MONTHLY_COMMITMENT` | 月低消费用—特殊业务逻辑 |
| `DISPUTE_FEE` | 争议手续费—特殊业务 |
| `CONSUMPTION_COLLECT` | 聚合类型（FX + CROSS_BORDER + APPLE_PAY + ATM + SETTLEMENT） |
| `REFUND_COLLECT` | 聚合类型（REFUND_FEE + REFUND_CLIENT_FEE） |
| `SYSTEM_FEE_COLLECT` | 聚合类型（所有 scheme 层费用） |
