# qbit_card_transaction 与 quantum_card_transaction_extend 使用分析

> 摘要：本文分析 `qbit_card_transaction`（量子卡交易主表）和 `quantum_card_transaction_extend`（量子卡交易扩展表，即需求中的 `quantum_card_transaction_extend_p`）在 qbitpay_service 与 qbit-assets 两个项目中的使用情况，包括使用频率、使用场景、关联表与字段。
> 说明：需求中写的 `quantum_card_transaction_extend_p` 在两个项目里都没有精确匹配，实际表名为 **`quantum_card_transaction_extend`**（无 `_p` 后缀）。

---

## 1. 结论速览

| 表 | 使用频率 | 定位 |
|---|---|---|
| `qbit_card_transaction` | **高频**（两个项目共 42+ 处） | 量子卡交易主表，承载交易/清算/统计/导出核心逻辑 |
| `quantum_card_transaction_extend` | **低频**（各项目 2-3 处） | 量子卡交易扩展表，补充商户/渠道额外信息，作为主表 join 源 |

---

## 2. 使用分析情况

### 2.1 qbit_card_transaction

#### 使用频率
- **qbitpay_service（Node / NestJS）**：42 处引用
- **qbit-assets（Java / MyBatis）**：数十处引用

这是量子卡最核心的交易主表，两个项目都高频使用。

#### 使用场景

**qbitpay_service（业务侧，交易/结算/统计/导出）：**
- **日消费成本统计**：`modules/qbit-card/qbit-card/qbit-card.transaction.service.ts` — 按 `Consumption + status=Closed` 聚合 `settleAmount`，带 Redis 缓存与 md5 签名
- **卡片/账户交易查询与导出**：`modules/qbit-card/qbit-card/service/qbit-card.service.ts`、`modules/export/qbit-card/*`（qbit-card / prepaid-card / budget-card 导出）
- **钱包交易统计**：`modules/qbit-card/qbit-card/service/qbit-card-wallet.service.ts`
- **结算（清算）**：`scripts/settle/settle.ts`、`modules/qbit-card/settle/**`
- **CNY 额度分配**：`modules/cny-settle/service/cny-settle-quota.service.ts`（以 `business_table='qbit_card_transaction'` 作为业务表标识）
- **一次性修复脚本（运维向）**：`scripts/**`（marqeta 修复、thepennyinc 修复等）

**qbit-assets（数据/分析侧，ODS 数仓）：**
- 集中在 `mapper/ods/OdsQbitCardTransactionMapper.xml`、`OdsQbitCardSettlementMapper.xml`、`TransactionMapper.xml`
- 用途为对账（Mismatch 检测）、量子卡交易统计、手续费取值
- `sharding.yaml` 中参与分片配置

#### 使用人群/使用方
- **业务/清算方**：CNY 结算、卡结算（settle）、comdata 渠道结算
- **数据分析方**：统计、导出、ODS 数仓对账
- **运维方**：一次性数据修复脚本

### 2.2 quantum_card_transaction_extend

#### 使用频率
- **qbitpay_service**：实体定义 1 处 + thepennyinc 修复脚本 2 处
- **qbit-assets**：ODS 对账 join 源若干处

#### 使用场景
- 作为 `qbit_card_transaction` 的扩展信息表，补充商户名、渠道来源等
- thepennyinc 渠道交易修复（补商户/编码/时间状态）
- ODS 层 Mismatch 对账

---

## 3. 关联查询

### 3.1 qbit_card_transaction 常见关联表与字段

**关联表：**
- **`qbitCard`（量子卡）**：
  - 关联字段：`qbitCard.id = qbit_card_transaction.cardId`（`q."id"=qt."cardId"`）
  - 典型：[qbit-card.service.ts:4079](qbitpay_service/src/modules/qbit-card/qbit-card/service/qbit-card.service.ts#L4079)、[:4562](qbitpay_service/src/modules/qbit-card/qbit-card/service/qbit-card.service.ts#L4562)
- **`transaction`（动钱/主交易流水）**：
  - 关联字段：`qbit_card_transaction.transactionId = transaction.id`（`qtx."transactionId"=t.id`）
  - 典型：[qbit-card.service.ts:4042](qbitpay_service/src/modules/qbit-card/qbit-card/service/qbit-card.service.ts#L4042)、[qbit-card-wallet.service.ts:162](qbitpay_service/src/modules/qbit-card/qbit-card/service/qbit-card-wallet.service.ts#L162)
- **自关联（remarks 修复）**：
  - 关联字段：`qct.id = re.relatedQbitTxId`（[remarks.ts:29](qbitpay_service/src/scripts/marqeta/remarks.ts#L29)）
- **`sourceId` 关联（marqeta 修复）**：`qt.sourceId`（[issuer-expiration.ts:42](qbitpay_service/src/scripts/marqeta/issuer-expiration.ts#L42)）

**表内常用过滤/统计字段：**
- `businessType`（Consumption / Refund / Credit / Reversal / TransferIn / TransferOut）
- `status`（Pending / Closed）
- `settleAmount`、`fee`、`provider`、`platformLabel`（平台）、`accountId`、`cardId`
- `transactionTime`、`createTime`、`sourceId`、`transactionId`
- `specialSourceData`（JSONB，取 `markupFee` 等）
- 软删过滤：`deleteTime IS NULL`

### 3.2 quantum_card_transaction_extend 关联方式

**表内字段（来自实体）：**
`account_id`、`card_id`、`card_transaction_id`、`source_id`、`transaction_id`、`related_transaction_id`、`related_card_transaction_id`、`user_id`、`transaction_display_id`

**与主表关联（唯一常见关联）：**
```
quantum_card_transaction_extend.card_transaction_id = qbit_card_transaction.id
```
- 典型：[handler-extend.ts:81](qbitpay_service/src/scripts/qbit-card/thepennyinc/handler-extend.ts#L81)、[OdsQbitCardTransactionMapper.xml:12](qbit-assets/qbit-core/src/main/resources/mapper/ods/OdsQbitCardTransactionMapper.xml#L12)（`e.card_transaction_id = q."id"`）

---

## 4. 相关项目文件索引

### qbitpay_service
- 实体：[qbit-card-transaction.entity.ts:12](qbitpay_service/src/entity/qbit-card/qbit-card-transaction.entity.ts#L12)（`qbit_card_transaction`）
- 实体：[quantum-card-transaction-extend.ts:5](qbitpay_service/src/entity/qbit-card/quantum-card-transaction-extend.ts#L5)（`quantum_card_transaction_extend`）
- 核心服务：`modules/qbit-card/qbit-card/**`、`modules/qbit-card/settle/**`、`modules/cny-settle/**`、`modules/export/**`
- 修复脚本：`scripts/**`

### qbit-assets
- ODS Mapper：`mapper/ods/OdsQbitCardTransactionMapper.xml`、`OdsQbitCardSettlementMapper.xml`
- 通用 Mapper：`mapper/TransactionMapper.xml`
- 分片配置：`sharding.yaml`
- 实体：`QbitCardTransaction`、`OdsQbitCardTransaction`、`DwsQbitCardTransaction`、`DwsQbitCardTransactionExtend` 等
