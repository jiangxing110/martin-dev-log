# API 客户账单体系 — 字段定义、月结流程与数据流

## 0. 相关数据表一览

| 表名 | 角色 | 说明 |
|------|------|------|
| `api_client_transaction` | 交易明细层 | 每笔客户交易记录一条，手续费以 JSON 数组形式存储在 `fees` |
| `api_client_bill_statement` | 费用汇总层 | 按费用类型拆分的结算明细行 |
| `api_client_bill` | 账单主表层 | 月度主账单，含低消/拒付/MVC 等额外费用 |
| `api_client_netting_bill` | 轧差层 | 月账单金额与返现金额的轧差结果 |
| `api_client_debit_record` | 扣款落地层 | 实际扣款/返现的落地记录 |

---

## 1. api_client_transaction（交易明细级）

**说明**：每笔客户交易记录一条，手续费以 JSON 数组形式存储在 `fees` 字段中。

### 1.1 字段列表

| 字段 | 类型 | 说明 |
|------|------|------|
| `id` | `bigint` | 主键（雪花 ID），继承自 `BaseV4` |
| `remarks` | `varchar` | 备注 |
| `create_time` | `timestamp` | 创建时间 |
| `update_time` | `timestamp` | 更新时间 |
| `delete_time` | `timestamp` | 删除时间（软删除） |
| `version` | `int` | 版本号 |
| `account_id` | `varchar` | 绑定的账号 ID |
| `transaction_id` | `varchar` | 交易 ID（关联 `qbit_card_transaction` / `qbitCardWalletTransaction`） |
| `fees` | `jsonb` | **手续费明细**（JSON 数组，每个元素包含 `amount`、`currency`、`type`） |
| `business_module` | `varchar` | 业务模块 |
| `complete_time` | `timestamp` | 完成时间 |
| `provider` | `varchar` | 渠道/供应商（如 stripe、interlace 等卡组织） |
| `status` | `varchar` | 状态（`Closed` 表示已关闭/已结算） |

### 1.2 sourceType 业务推导（非持久化字段）

`ApiClientTransactionSourceType` 根据 `fees` 中的手续费类型动态推导：

| sourceType | 含义 | 判定条件 |
|------------|------|----------|
| `QBIT_CARD_TRANSACTION` | 卡交易类手续费 | fees 包含下列任一类型：`SETTLEMENT_FEE` / `SETTLEMENT_FEE_CLOSED` / `AUTH_FEE` / `AUTH_FEE_CLOSED` / `APPLE_PAY_AUTH_FEE` / `APPLE_PAY_AUTH_FEE_CLOSED` / `CROSS_BORDER_FEE` / `FX_FEE` / `ATM_WITHDRAWAL_FEE` / `REFUND_FEE` / `REFUND_CLIENT_FEE` / `REVERSAL_FEE` / `DECLINE_FEE` / `VERIFICATION_FEE` |
| `QBIT_CARD_WALLET_TRANSACTION` | 钱包/实体卡类手续费 | fees 包含下列任一类型：`CARD_PRODUCTION_FEE` / `POSTAGE_FEE` / `PHYSICALCARD_FEE_CLOSED` / `TOP_UP_FEE` / `TOP_UP_FEE_CLOSED` |
| `TRANSACTION` | 开卡类手续费 | fees 包含下列任一类型：`CARD_CREATION_FEE` / `CARD_CREATION_FEE_CLOSED` |

---

## 2. api_client_bill_statement（费用汇总级）

**说明**：每条记录对应一笔特定类型的费用，按 `bill_id` 汇总到账单。`type` 字段标识费用枚举，`item` 为展示文案，`amount` 为原始金额，`adjust_amount` 为调账后金额，`debit_amount` 为实际扣账金额。

### 2.1 字段列表

| 字段 | 类型 | 说明 |
|------|------|------|
| `id` | `bigint` | 主键（雪花 ID），继承自 `BaseV4` |
| `remarks` | `varchar` | 备注 |
| `create_time` | `timestamp` | 创建时间 |
| `update_time` | `timestamp` | 更新时间 |
| `delete_time` | `timestamp` | 删除时间（软删除） |
| `version` | `int` | 版本号 |
| `bill_id` | `bigint` | 绑定的账单 ID（关联 `api_client_bill`） |
| `account_id` | `varchar` | 绑定的账号 ID |
| `item` | `varchar` | 收费款项展示文案（如"结算手续费"、"开卡费"等） |
| `type` | `varchar` | **收费款项归类**（对应 `ApiClientFeeEnum` 的 `value`） |
| `amount` | `decimal` | 待结算金额（原始金额） |
| `adjust_amount` | `decimal` | 调账金额（调账优先级：`adjust_amount` > `amount`） |
| `debit_amount` | `decimal` | 记账金额（实际扣账） |
| `provider` | `varchar` | 渠道/供应商 |
| `is_sum` | `boolean` | 是否为汇总值（`true` 汇总行，`false` 明细行） |
| `reject_info` | `varchar` | 当前拒付明细（争议/拒付相关信息） |
| `debit_time` | `timestamp` | 记账时间 |

### 2.2 特殊类型过滤

- **closedFees（已实收费用，计算账单总额时需排除）**：
  `settlementFeeClosed`, `cardCreationFeeClosed`, `authFeeClosed`, `applePayAuthFeeClosed`, `topUpFeeClosed`, `physicalCardFeeClosed`, `atmWithdrawalFeeClosed`

- **NO_DIFFERENCES_PROVIDER（无法区分渠道的费用类型）**：
  `inactiveCardManagementFee`, `monthlyCommitment`, `disputeFee`, `additionalFee`, `apiSubscription`, `complianceDueDiligence`, `apiIntegration`, `identityVerification`, `revenueAdjustment`, `minimumVolumeCommitmentFee`

- **realTimeButMonthlyFees（客户实时收取但月结处理的费用）**：
  `identityVerification`, `monthlyCardFee`

---

## 3. ApiClientFeeEnum 手续费枚举全表

### 3.1 卡交易类手续费（对应实际发生的卡交易）

| value（数据库存储） | 中文名 | 英文名 | 说明 |
|---------------------|--------|--------|------|
| `settlementFee` | 结算手续费 | Settlement fee | 每笔消费交易的结算手续费 |
| `settlementFeeClosed` | 结算手续费(实收) | Settlement fee Closed | 结算手续费（已实时收取，月结时需排除） |
| `authFee` | 授权费 | Auth Fee | 每笔授权交易的手续费 |
| `authFeeClosed` | 授权费实收 | Auth Fee Closed | 授权费（已实时收取，月结时需排除） |
| `verificationFee` | 绑卡费 | Verification Fee | 卡片验证/绑卡手续费 |
| `applePayAuthFee` | Apple Pay 服务费 | Apple Pay Auth Fee | Apple Pay 授权服务费 |
| `applePayAuthFeeClosed` | Apple Pay 服务费实收 | Apple Pay Auth Fee Closed | Apple Pay 服务费（已实时收取） |
| `crossBorderFee` | 跨境手续费 | Cross Border Fee | 跨境交易手续费 |
| `fxFee` | 汇兑费用 | FX Fee | 货币兑换手续费 |
| `atmWithdrawalFee` | ATM 取现手续费 | ATM Withdrawal Fee | ATM 取现手续费 |
| `atmWithdrawalFeeClosed` | ATM 取现手续费 Closed | ATM Withdrawal Fee Closed | ATM 取现手续费（已实时收取） |
| `refundFee` | 退款手续费 | Refund Fee | 退款交易的手续费 |
| `refundClientFee` | 退款客户退款手续费 | Refund Client Fee | 退款时退还给客户的手续费 |
| `reversalFee` | 撤销手续费 | Reversal Fee | 交易撤销的手续费 |
| `declineFee` | 交易失败手续费 | Decline Fee | 交易被拒绝的手续费 |

### 3.2 开卡相关手续费

| value（数据库存储） | 中文名 | 英文名 | 说明 |
|---------------------|--------|--------|------|
| `cardCreationFee` | 开卡费 | Card Creation | 创建卡片（虚拟卡）的费用 |
| `cardCreationFeeClosed` | 实时开卡费 | Card Creation | 开卡费（已实时收取，月结时需排除） |
| `cardProductionFee` | 制卡费 | Card Production Fee | 实体卡制作费用 |
| `physicalCardFeeClosed` | 实体卡制卡费实收 | Card Production Fee Closed | 实体卡制卡费（已实时收取） |
| `postageFee` | 邮寄费 | Postage Fee | 实体卡邮寄费用 |

### 3.3 充值相关手续费

| value（数据库存储） | 中文名 | 英文名 | 说明 |
|---------------------|--------|--------|------|
| `topUpFee` | 实时充值手续费 | Top up fee | 充值手续费（月结） |
| `topUpFeeClosed` | 实时充值手续费 | Top up fee Closed | 充值手续费（已实时收取） |

### 3.4 月费/管理费

| value（数据库存储） | 中文名 | 英文名 | 说明 |
|---------------------|--------|--------|------|
| `monthlyCardFee` | 活跃卡月费 | Monthly Card Fee | 活跃卡月度管理费 |
| `inactiveCardManagementFee` | 非活跃卡管理费 | Inactive Card Management Fee | 不活跃卡管理费用 |
| `monthlyCommitment` | 月低消费用 | Monthly Commitment | 月最低消费承诺费用（MCF） |

### 3.5 系统级/发卡行费用（按笔计费）

| value（数据库存储） | 中文名 | 英文名 |
|---------------------|--------|--------|
| `issuerCardServiceIntFee` | 发卡行卡服务费（国际） | Issuer Card Service Fee (International) |
| `issuerCardServiceDomFee` | 发卡行卡服务费（国内） | Issuer Card Service Fee (Domestic) |
| `visaRiskManagerIntFee` | Visa 风险订单服务费（国际） | Visa Risk Manager Fee (International) |
| `visaRiskManagerDomFee` | Visa 风险订单服务费（国内） | Visa Risk Manager Fee (Domestic) |
| `issuerTransactionAuthIntFee` | 发行人交易费-授权（国际） | Issuer Transaction Fee - Auth (International) |
| `issuerTransactionAuthDomFee` | 发行人交易费-授权（国内） | Issuer Transaction Fee - Auth (Domestic) |
| `issuerTransactionSettlementIntFee` | 发行人交易费-清算（国际） | Issuer Transaction Fee - Settlement (International) |
| `issuerTransactionSettlementDomFee` | 发行人交易费-清算（国内） | Issuer Transaction Fee - Settlement (Domestic) |
| `schemeVerificationIntFee` | Scheme 验证费（国际） | Scheme Verification Fee (International) |
| `schemeVerificationDomFee` | Scheme 验证费（国内） | Scheme Verification Fee (Domestic) |
| `schemeRefundFee` | Scheme 退款费 | Scheme Refund Fee |
| `schemeReversalFee` | Scheme 撤销费 | Scheme Reversal Fee |
| `schemeSignatureFee` | Scheme 签名费 | Scheme Signature Fee |
| `minimumVolumeCommitmentFee` | 最低交易量承诺费用 | Minimum Volume Commitment (MVC) Fee |

### 3.6 其他费用

| value（数据库存储） | 中文名 | 英文名 | 说明 |
|---------------------|--------|--------|------|
| `disputeFee` | 争议手续费 | Dispute Fee | 交易争议/拒付处理费 |
| `additionalFee` | 额外手续费 | Additional Fee | 额外杂项费用 |
| `apiSubscription` | 接口订阅费 | API Subscription | API 接口订阅费用 |
| `complianceDueDiligence` | CDD 费用 | Compliance Due Diligence | 合规尽职调查费用 |
| `apiIntegration` | 接口服务费 | API Integration | API 集成服务费 |
| `rebate` | 返现 | Rebate | 返现/奖励 |
| `identityVerification` | 身份验证费用 | Identity Verification | KYC 身份验证费用 |
| `revenueAdjustment` | 营收补差 | Revenue Adjustment | 营收差额调整 |

### 3.7 聚合类型（非实际存储，用于汇总分组）

| value（数据库存储） | 中文名 | 包含的子类型 |
|---------------------|--------|-------------|
| `consumptionCollect` | 消费多手续费聚合 | `FX_FEE`, `CROSS_BORDER_FEE`, `APPLE_PAY_AUTH_FEE`, `ATM_WITHDRAWAL_FEE`, `SETTLEMENT_FEE` |
| `refundCollect` | 退款费用聚合 | `REFUND_FEE`, `REFUND_CLIENT_FEE` |
| `system_fee` | 系统费用聚合 | 3.5 节中所有发卡行/Scheme 相关费用 |

---

## 4. 关键辅助表定义

### 4.1 api_client_bill（月度主账单）

**说明**：每个客户每月一条主账单，记录该月汇总金额、状态、低消等信息。

| 字段 | 类型 | 说明 |
|------|------|------|
| `id` | `bigint` | 主键 |
| `account_id` | `varchar` | 客户账号 ID |
| `bill_month` | `varchar` | 账单月，格式 `yyyy-MM` |
| `status` | `varchar` | 账单状态：`Pending`(待结算) / `FREE`(免费) / `Settled`(已结清) / `PartSettled`(部分结清) |
| `month_amount` | `decimal` | 低消月费 |
| `min_amount` | `decimal` | 最低消费额 |
| `recharge_fee` | `decimal` | 充值手续费 |
| `open_card_amount` | `decimal` | 开卡金额 |
| `other_amount` | `decimal` | 其他金额 |
| `total_amount` | `decimal` | 账单总金额 |
| `reject_fine` | `decimal` | 拒付罚款 |
| `bill_history_config` | `json` | 账单历史配置（折扣/计费模式快照） |
| `is_latest` | `boolean` | 是否为最新版本 |
| `check_status` | `varchar` | 复核状态 |
| `debit_type` | `varchar` | 扣款方式：`Online`(自动扣款) / `Offline`(线下转账) |
| `type` | `varchar` | 账单类型：`MonthlyStatement`(月结) / `Rebate`(返现) |
| `detail_url` | `varchar` | 明细文件链接 |
| `statement_url` | `varchar` | 账单对账单链接 |

### 4.2 api_client_netting_bill（轧差账单）

**说明**：月账单与返现的轧差结果，确定当月最终应收/应付。

| 字段 | 类型 | 说明 |
|------|------|------|
| `id` | `bigint` | 主键 |
| `account_id` | `varchar` | 客户账号 ID |
| `bill_month` | `varchar` | 账单月 |
| `rebate_id` | `bigint` | 返现账单 ID |
| `bill_id` | `bigint` | 月结账单 ID |
| `amount` | `decimal` | 轧差金额（`billAmount - rebateAmount`） |
| `type` | `varchar` | 轧差类型：`NettingEqual`(平账) / `NettingDebit`(需扣款) / `NettingRebate`(需返现) |
| `status` | `varchar` | 状态：`Pending` / `PartSettled` / `Settled` |
| `deal_amount` | `decimal` | 已处理金额 |
| `bill_amount` | `decimal` | 月账单金额 |
| `rebate_amount` | `decimal` | 返现金额 |

### 4.3 api_client_debit_record（扣款记录）

**说明**：每次扣款或返现的实际落地记录。

| 字段 | 类型 | 说明 |
|------|------|------|
| `id` | `bigint` | 主键 |
| `bill_id` | `bigint` | 关联账单 ID |
| `debit_amount` | `decimal` | 应扣金额 |
| `real_amount` | `decimal` | 实扣金额 |
| `wallet_type` | `varchar` | 钱包类型 |
| `source_id` | `varchar` | 来源交易 ID |
| `debit_channel` | `varchar` | 扣款渠道 |
| `debit_type` | `varchar` | 扣款方式：`Online` / `Offline` |
| `is_sale_commissions` | `boolean` | 是否计入销售提成 |
| `is_show` | `boolean` | 是否对客户可见 |
| `description` | `varchar` | 描述 |

---

## 5. 核心字段间的逻辑关系

### 5.1 api_client_transaction

- **fees (JSONB)** — 手续费明细数组：
  ```json
  [
    {
      "amount": 0.50,
      "currency": "USD",
      "type": "settlementFee",
      "count": 1
    }
  ]
  ```

- **transaction_id** — 关联的具体交易：
  - 卡交易类 → 关联 `qbit_card_transaction`
  - 钱包/实体卡类 → 关联 `qbitCardWalletTransaction`

- **status** — `Closed` 表示交易已关闭/完成，是月结统计的前提条件

### 5.2 api_client_bill_statement

- **amount vs adjust_amount vs debit_amount**：
  - `amount`：原始待结算金额
  - `adjust_amount`：调账金额，查询时优先取 `COALESCE(adjust_amount, amount)`
  - `debit_amount`：实际记账扣款金额

- **is_sum**：`true` 汇总行，`false` 明细行

### 5.3 api_client_bill 金额计算关系

- **totalAmount = monthAmount（低消） + otherAmount（其他费用） + rejectFine（拒付罚款） + sum(statement.adjust_amount)**
- 金额来源分层：
  - `monthAmount` → 折扣/低消计算后得出
  - `rejectFine` → `dealMonthlyRejectPayByAccount()` 计算拒付罚款
  - `statementAmount` → 从 `api_client_bill_statement` 按账单汇总
  - MVC 费用 → `minimumVolumeCommitmentsByAccount()` 计算最低交易量承诺费用

---

## 6. 月账单生成与月结处理流程

### 6.1 时间线一览

| 时间节点 | XxlJob | 操作 | 说明 |
|----------|--------|------|------|
| 每月 1 号 | `quantum_card_api_customer_bill` | 生成上个月账单 | 调用 `ApiClientBillServiceImpl.initBill()` |
| 每月 1 号 | `month_bill_export_job` | 对账单 PDF 导出 | `MonthBillJob` 导出 PDF/CSV |
| 每月 1 号后 | `quantum_card_api_customer_bill_notice` | 邮件通知客户 | 发送账单通知邮件 |
| 每月 7/14/21/28 号 | `month_bill_debit_notice` | 催缴通知 | 对有未结清账单的客户发送催缴通知 |
| 每月 7/14/21/28 号 | `month_netting_bill_debit_notice` | 轧差催缴通知 | 对有未结清轧差账单的客户发送催缴通知 |
| 每月 20 号 | `quantum_card_api_customer_netting_bill_debit` | 轧差扣款/返现 | 处理月账单与返现的轧差 |
| 每月 20 号 | `quantum_card_api_customer_bill_debit` | 账单自动扣款 | 对线上扣款客户执行扣款 |
| 次月 | `quantum_card_api_customer_last_month_bill_debit` | 处理上个月未结清账单 | 兜底处理 |

### 6.2 账单生成完整流程（initBill）

```
时间窗口计算
  start = 上月1号 00:00:00
  end   = 上月最后一天 23:59:59
  账单月 = yyyy-MM（上月）

       │
       ▼

Step 1: 获取所有活跃API客户
  → openApiClientMapper.customerList()
  → 含折扣配置、最低消费额、计费模式

       │
       ▼

Step 2: 处理折扣优惠（dealDiscountV2）
  → 按客户折扣配置（百分比/固定金额）减免低消
  → 新客户按实际上线天数占比计算

       │
       ▼

Step 3: 从 api_client_transaction 汇总月度费用
  → apiClientTransactionService.getApiClientMonthlySettlementFee()
  → 读取 status='Closed' 且 complete_time 在时间窗口内的交易
  → 解析 fees JSONB，按 type 汇总金额
  → 返回每个 accountId 的费用明细

       │
       ▼

Step 4: 生成账单结算明细（createApiClientBillStatement）
  → 写入 api_client_bill_statement 表
  → type 存储费用枚举值，item 存储中文展示文案
  → is_sum=true（汇总行）
  → 有 provider 的生成渠道维度明细

       │
       ▼

Step 5: 计算额外费用
  → 拒付罚款（dealMonthlyRejectPayByAccount）
  → 最低交易量承诺费 MVC（minimumVolumeCommitmentsByAccount）

       │
       ▼

Step 6: 生成主账单（initApiBill）
  → 为每个客户创建 ApiClientBill
  → totalAmount = monthAmount + otherAmount + rejectFine + statementAmount
  → totalAmount > 0 → status=Pending；否则 status=FREE
  → 记录 billHistoryConfig（折扣/计费模式快照）
  → is_latest=true

       │
       ▼

Step 7: 金额汇总口径差异
  ┌─ 月结客户（StatementTypeEnum.Monthly）──┐
  │ 取所有非实收（not in closedFees）的      │
  │ statement 金额之和                       │
  ├─ 实时客户（StatementTypeEnum.Realtime）──┤
  │ 取属于 realTimeButMonthlyFees 的         │
  │ statement 金额之和                       │
  └─────────────────────────────────────────┘
```

### 6.3 扣款流程

#### 6.3.1 自动扣款（debit — 每月20号）

```
查询待扣款账单
  → status IN (Pending, PartSettled)
  → debit_type = Online
  → bill_month = 上个月

       │
       ▼

计算待结金额
  pendingAmount = totalAmount - 已扣金额

       │
       ▼

获取扣款钱包
  → 根据 SettledWalletTypeEnum 映射：
    QbitCardWallet / QBWallet / VirtualUSD

       │
       ▼

执行扣款（subBalance）
  → min(pendingAmount, walletBalance) 作为实扣金额
  → 按钱包类型走不同资金转移通道：

  ┌─ QBWallet（闪付） ──────────────────────┐
  │  创建 GlobalAccountTransfer             │
  │  type = MonthBillDebit                 │
  ├─ VirtualUSD（加密资产） ─────────────────┤
  │  创建 CryptoAssetsTransfer             │
  ├─ QbitCardWallet（量子卡） ───────────────┤
  │  创建 InfinityAccountWalletTransfer     │
  │  type = QuantumAccountMonthBillDebit   │
  └─────────────────────────────────────────┘

       │
       ▼

更新账单状态
  → 实扣 < 应扣 → status = PartSettled
  → 实扣 = 应扣 → status = Settled

       │
       ▼

插入扣款记录
  → 写入 api_client_debit_record
  → is_sale_commissions = true
```

#### 6.3.2 线下扣款（addApiClientDebitRecordOffline）

- 管理端手动操作
- 校验金额格式、账单状态、剩余待还金额
- 插入 `ApiClientDebitRecord`，标记 `DebitTypeEnum.Offline`
- 更新账单状态

### 6.4 轧差处理流程

#### 6.4.1 轧差计算（initApiClientNettingBill）

```
时间窗口
  账单月 yyyy-MM
  计费起始 = 账单月+1月20号 00:00:00
  计费结束 = 上限+1个月

       │
       ▼

获取已复核完成的月结账单和返现账单
  → checkStatus = Done
  → is_latest = true

       │
       ▼

轧差计算
  amount = billAmount - rebateAmount

  ┌─ amount == 0 ────→ NettingEqual（平账，无需付款）
  ├─ amount < 0  ────→ NettingRebate（需返现，返现 > 账单）
  └─ amount > 0  ────→ NettingDebit（需扣款，账单 > 返现）

       │
       ▼

写入 api_client_netting_bill
  → status = Pending
```

#### 6.4.2 轧差扣款/返现（dealNettingDebit — 每月20号）

```
处理 NettingEqual
  → 直接标记结清
  → 生成偏移记录（用于销售提成核算）

处理 NettingDebit（需扣款）
  → 从 QbitCardWallet 扣款
  → 逻辑同自动扣款

处理 NettingRebate（需返现）
  → 从 QBWallet（闪付）返现到客户

       │
       ▼

生成偏移记录（dealBillOffset / dealRebateOffset）
  → 月结账单应收偏移：is_show=false, is_sale_commissions=true
  → 返现账单偏移：is_show=false, is_sale_commissions=false
```

#### 6.4.3 多钱包组合扣款（multiWalletDehit）

- 商户端手动选择多个钱包组合扣款
- 优先级：QBWallet > QbitCardWallet > VirtualUSD
- 逐个钱包扣款，直到结清或余额不足
- 2026年3月后账单走轧差逻辑，之前走非轧差逻辑

---

## 7. 全链路数据流向

```
┌─────────────────────────────────────────────────────────┐
│                   交易发生阶段                            │
│                                                         │
│  qbit_card_transaction / qbitCardWalletTransaction      │
│         │                                               │
│         │ 扣手续费，写入 fees 明细                       │
│         ▼                                               │
│  api_client_transaction                                 │
│  (逐笔交易，status=Closed 表示已结算)                    │
└───────────────────────┬─────────────────────────────────┘
                        │
                        │ 每月1号：initBill()
                        │ 按 account_id + complete_time 月度窗口
                        │ 解析 fees JSONB，按 type 汇总金额
                        ▼
┌─────────────────────────────────────────────────────────┐
│                   费用汇总阶段                            │
│                                                         │
│  api_client_bill_statement                              │
│  (按费用类型拆分，is_sum=true 汇总行)                    │
│         │                                               │
│         │ 1:N                                           │
│         ▼                                               │
│  api_client_bill                                        │
│  (月度主账单，含低消/拒付/MVC)                           │
│  status: Pending / FREE / PartSettled / Settled         │
└───────────────────────┬─────────────────────────────────┘
                        │
                        │ 每月20号：轧差处理
                        │ billAmount - rebateAmount = nettingAmount
                        ▼
┌─────────────────────────────────────────────────────────┐
│                   轧差阶段                                │
│                                                         │
│  api_client_netting_bill                                 │
│  (NettingEqual / NettingDebit / NettingRebate)          │
│         │                                               │
│         │ 扣款/返现落地                                  │
│         ▼                                               │
└───────────────────────┬─────────────────────────────────┘
                        │
┌─────────────────────────────────────────────────────────┐
│                   扣款落地阶段                            │
│                                                         │
│  api_client_debit_record                                 │
│  (实际扣款/返现记录)                                     │
│         │                                               │
│         ├── GlobalAccountTransfer        (QBWallet)     │
│         ├── CryptoAssetsTransfer         (VirtualUSD)   │
│         └── InfinityAccountWalletTransfer (QbitCardWallet)│
│                                                         │
│  销售提成：is_sale_commissions=true                      │
│  偏移记录：is_show=false                                 │
└─────────────────────────────────────────────────────────┘
```

**关键汇总口径**：

| 步骤 | 口径 | SQL/逻辑关键点 |
|------|------|---------------|
| transaction → statement | `status='Closed'` + `complete_time` 月度范围 | `CROSS JOIN LATERAL jsonb_array_elements(fees)` 展开 JSON |
| 月结客户 totalAmount | 排除 `closedFees` 后的所有 fee | `WHERE type NOT IN (settlementFeeClosed, cardCreationFeeClosed, ...)` |
| 实时客户 totalAmount | 仅取 `realTimeButMonthlyFees` | `WHERE type IN (identityVerification, monthlyCardFee)` |
| 轧差金额 | `billAmount - rebateAmount` | 月结账单 vs 返现账单 |
| 实扣金额 | `min(pendingAmount, walletBalance)` | 余额不足时部分结清 |

---

## 8. 源码位置

| 类/文件 | 路径 |
|---------|------|
| `ApiClientTransaction` Entity | `qbit-core/.../openapi/domain/entity/ApiClientTransaction.java` |
| `ApiClientBillStatement` Entity | `qbit-core/.../openapi/domain/entity/ApiClientBillStatement.java` |
| `ApiClientBill` Entity | `qbit-core/.../openapi/domain/entity/ApiClientBill.java` |
| `ApiClientNettingBill` Entity | `qbit-core/.../openapi/domain/entity/ApiClientNettingBill.java` |
| `ApiClientDebitRecord` Entity | `qbit-core/.../openapi/domain/entity/ApiClientDebitRecord.java` |
| `ApiClientFeeEnum` | `qbit-core/.../openapi/domain/enums/ApiClientFeeEnum.java` |
| `ApiClientFeeDTO` | `qbit-core/.../openapi/domain/dto/ApiClientFeeDTO.java` |
| `ApiClientTransactionSourceType` | `qbit-core/.../openapi/domain/enums/ApiClientTransactionSourceType.java` |
| `ApiClientBillServiceImpl` | `qbit-core/.../api/client/bill/service/impl/ApiClientBillServiceImpl.java` |
| `ApiClientNettingBillServiceImpl` | `qbit-core/.../impl/ApiClientNettingBillServiceImpl.java` |
| `ApiClientBillStatementServiceImpl` | `qbit-core/.../impl/ApiClientBillStatementServiceImpl.java` |
| `ApiClientDebitRecordServiceImpl` | `qbit-core/.../impl/ApiClientDebitRecordServiceImpl.java` |
| `ApiClientTransactionServiceImpl` | `qbit-core/.../service/impl/ApiClientTransactionServiceImpl.java` |
| `ApiCustomerJob`（所有 XxlJob 入口） | `qbit-core/.../job/qbitcard/ApiCustomerJob.java` |
| `MonthBillJob`（对账单导出） | `qbit-core/.../job/settle/MonthBillJob.java` |
| `ApiClientBillStatementMapper.xml` | `qbit-core/src/main/resources/mapper/quantum/card/ApiClientBillStatementMapper.xml` |
| `OdsApiClientTransactionMapper.xml` | `qbit-core/src/main/resources/mapper/ods/OdsApiClientTransactionMapper.xml` |
