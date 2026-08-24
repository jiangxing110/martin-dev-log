# 量子卡交易大宽表设计（dwm_quantum_card_transaction_p）

> **摘要**：以 `qbit_card_transaction` 为唯一主线，从 `specialSourceData` jsonb 洗出高频 key 成独立列，JOIN `qbitCard`/`account`/`api_account_relation`/`dim_sale_account_relation_p` 补齐维度，写入物理分区大宽表。用 **Flink SQL CDC 流脚本**实现分钟级更新。
> **关键决策：** 不用物化视图 · 不用 JDBC T+1 批处理 · 不依赖 quantum_card_transaction_extend 表 · 只从主表和实时维表构建。

---

## 1. 数据源与关联关系

| # | 事实/维度 | 源 | JOIN 条件 | 说明 |
|---|---|---|---|---|
| 1 | **事实主表** | `qbit_card_transaction` | — | 唯一事实来源 |
| 2 | **卡维度** | `qbitCard` | LEFT JOIN ON `"qbitCard".id = txn.card_id::uuid` | 通过 card_id 关联 |
| 3 | **账户维度** | `account` | LEFT JOIN ON `"account".id = txn.account_id::uuid` | 通过 account_id 关联 |
| 4a | **API 子户映射** | `api_account_relation` | LEFT JOIN ON `aar.account_id = txn.account_id::uuid` | 仅 API 场景：子账户→root_id |
| 4b | **销售维度** | `dim_sale_account_relation_p` | 维表匹配 direct + root 合并 | 见 §3.5 |

---

## 2. 完整表结构（全量逐列）

### ① 主表事实列（来自 `qbit_card_transaction`）— 全部保留

| # | 列名 | 类型 | 注释 |
|---|---|---|---|
| 1 | txn_id | varchar(128) | **主键**，交易唯一标识 |
| 2 | account_id | uuid | 所属账户 |
| 3 | card_id | uuid | 量子卡 id |
| 4 | provider | varchar | 平台/发卡方（PennyCard/TripLink 等） |
| 5 | business_type | varchar | Consumption / Refund / Credit / Reversal / TransferIn / TransferOut |
| 6 | status | varchar | Pending / Closed |
| 7 | display_status | varchar(30) | 展示状态 |
| 8 | currency | varchar(30) | USD / CNY / EUR |
| 9 | settle_amount | numeric(20,4) | 结算金额 |
| 10 | original_amount | numeric(20,4) | 原始金额 |
| 11 | transaction_currency | varchar(30) | 三方交易币种 |
| 12 | transaction_amount | numeric(20,4) | 三方交易金额 |
| 13 | fee | numeric(20,4) | 费用 |
| 14 | detail | text | 交易详情 |
| 15 | source_id | varchar | 三方订单 id |
| 16 | transaction_time | timestamptz | **交易时间（业务发生）** |
| 17 | complete_time | timestamptz | 我方完成时间 |
| 18 | transaction_ref_id | uuid | 动钱表 id（回滚用） |
| 19 | related_qbit_tx_id | uuid | 退款来源交易 id |
| 20 | payment_label | varchar | 付款标签 |
| 21 | platform_label | varchar | 平台标签 |
| 22 | second_label | varchar | 二级标签 |
| 23 | comments | varchar | 三方备注 |
| 24 | authorization_code | varchar | Nium 授权码 |
| 25 | is_show | boolean | 是否显示给用户 |
| 26 | released | boolean | 是否释放交易 |
| 27 | third_complete_time | timestamptz | 三方完成时间 |
| 28 | special_source_data | jsonb | 三方源数据 JSON（低频 key 保留在此） |

### ② 反规范化统计列（来自 `special_source_data->>'key'`）— 共 17 个

> Flink SQL 中用 `CAST(txn.special_source_data->>'key' AS type)` 解析。商户/地理字段走 COALESCE 双重取（顶层已回填 → card_acceptor 嵌套路径兜底）。

#### 高频统计用（≥3次查询）

| # | 列名 | 类型 | jsonb key | 频率 | 来源路径 | 说明 |
|---|---|---|---|---|---|---|
| 29 | spc_authorization_time | timestamptz | `authorizationTime` | 8 | 顶层 | 授权时间 |
| 30 | spc_authorization_date | date | `authorizationDate` | 8 | 顶层 | 授权日期 |
| 31 | spc_thirdparty_settle_amount | numeric(20,4) | `thirdpartySettleAmount` | 7 | 顶层 | 三方结算金额 |
| 32 | spc_markup_fee | numeric(20,4) | `markupFee`/`markUpFee` | 6 | 顶层 | **加价费（消费成本核心指标）** |
| 33 | spc_qbit_card_recharge_type | varchar | `qbitCardRechargeType` | 4 | 顶层 | 充值类型 |
| 34 | spc_transaction_id | varchar | `transactionId` | 4 | 顶层 | 交易 id |
| 35 | spc_merchant_source_amount | numeric(20,4) | `merchantSourceAmount` | 3 | 顶层 | 商户源金额 |
| 36 | spc_date | date | `date` | 3 | 顶层 | 日期 |

#### 商户/地理信息（每次看交易必备）

| # | 列名 | 类型 | jsonb key | 来源路径 | 说明 |
|---|---|---|---|---|---|
| 37 | spc_merchant_name | varchar | `name`/`merchName` | `card_acceptor.name` 或顶层 | 商户名 |
| 38 | spc_mid | varchar | `mid` | `card_acceptor.mid` 或顶层 | 商户 ID |
| 39 | spc_mcc | varchar | `mcc` | `card_acceptor.mcc` 或顶层 | MCC 码 |
| 40 | spc_city | varchar | `city` | `card_acceptor.city` 或顶层 | 城市 |
| 41 | spc_country | varchar | `country` | `card_acceptor.country` 或顶层 | 国家 |
| 42 | spc_state | varchar | `state` | `card_acceptor.state` 或顶层 | 省/州 |
| 43 | spc_zip_code | varchar | `zipCode`/`merchPostCode` | `card_acceptor.zip_code` 或顶层 | 邮编 |

#### 清算/响应类

| # | 列名 | 类型 | jsonb key | 来源路径 | 说明 |
|---|---|---|---|---|---|
| 44 | spc_code | varchar | `code` | 顶层 | 响应码 / 业务码 |
| 45 | spc_system_trace_audit_no | varchar | `systemTraceAuditNumber` | 顶层 | 清算 trace no |
| 46 | spc_fail_reason | varchar | `failReason` | 顶层 | 失败原因 |

> **商户/地理双重取源示例（Flink SQL）：**
> ```sql
> COALESCE(
>   txn.special_source_data->>'mcc',
>   CAST(txn.special_source_data->'card_acceptor' AS json)->>'mcc'
> ) AS spc_mcc
> ```

### ③ 卡维度列（来自 `qbitCard`）— LEFT JOIN

> 基于实际 DDL：`CREATE TABLE "public"."qbitCard" (...)`

| # | 列名 | 类型 | qbitCard 列名 | 说明 |
|---|---|---|---|---|
| 47 | card_no | varchar | `"qbitCardNo"` | 量子卡号 |
| 48 | card_no_last_four | varchar | `"qbitCardNoLastFour"` | 后四位 |
| 49 | card_provider | varchar | `provider` | 发卡提供方 |
| 50 | card_type_dim | varchar | `"type"` | VISA / Master / Amex |
| 51 | card_token | varchar | `token` | 卡在三方的唯一 id |
| 52 | label | varchar | `label` | 卡标签 |
| 53 | group_id | uuid | `groupId` | 卡组 id |
| 54 | card_user_id | uuid | `userId` | 创建人 id |
| 55 | balance_id | uuid | `balanceId` | 余额 id |
| 56 | life_time_amount_limit | numeric(20,4) | `lifeTimeAmountLimit` | 终身消费限额 |
| 57 | frozen_type | varchar | `frozenType` | 冻结类型 |
| 58 | previous_status | varchar(30) | `previousStatus` | 冻结前状态 |
| 59 | first_six | varchar | `firstSix` | BIN 前六位 |
| 60 | card_belong | varchar | `cardBelong` | 卡归属 |
| 61 | physical_card_status | varchar(30) | `physicalCardStatus` | 实体卡状态 |
| 62 | card_mode | varchar(30) | `cardMode` | Virtual / Physical |
| 63 | no_upload_reimburse | boolean | `noUploadReimburse` | 是否免上传报销单 |
| 64 | source_type | varchar | `sourceType` | 开卡来源 |
| 65 | cardholder_id | varchar | `cardholderId` | 持卡人 id |
| 66 | card_first_name | varchar | `firstName` | 用户名（名） |
| 67 | card_last_name | varchar | `lastName` | 用户姓 |
| 68 | card_user_name | varchar | `"userName"` | 用户名（姓+名组合） |
| 69 | qbit_card_customer_id | uuid | `qbitCardCustomerId` | 开户 id |
| 70 | card_is_master | boolean | `isMasterCard` | 是否主卡 |

### ④ 账户维度列（来自 `account` + 可选 `api_account_relation`）— LEFT JOIN

> 基于实际 DDL：`CREATE TABLE "public"."account" ("id", "parentAccountId", "verifiedName", "accountType", "country", "referralCodeId", "type", "displayId", "tenantId")`

| # | 列名 | 类型 | account 列名 | 说明 |
|---|---|---|---|---|
| 71 | acc_verified_name | varchar | `"verifiedName"` | 账户实名 |
| 72 | parent_account_id | uuid | `"parentAccountId"` | 父账户 |
| 73 | account_type | varchar(30) | `"accountType"` | 账户类型 |
| 74 | acc_country | varchar | `"country"` | 注册国家 |
| 75 | referral_code_id | varchar | `"referralCodeId"` | 推荐码 ID |
| 76 | acc_type | varchar(50) | `"type"` | 账户角色（Merchant 等） |
| 77 | acc_display_id | varchar(15) | `"displayId"` | 展示 ID |
| 78 | tenant_id | int8 | `"tenantId"` | 租户 ID |
| 79 | root_account_id | uuid | `api_account_relation.root_id` | **API 场景**：子账户的根账户 id（仅 API 子户有值，通过 oar.account_id = txn.account_id::uuid 关联） |

> `root_account_id` 匹配逻辑：`api_account_relation WHERE account_id = txn.account_id AND delete_time IS NULL LIMIT 1`

> ⚠️ 注意：`account` 表没有 `email` 列（之前误加），如需邮箱信息需从其他维表获取。

### ⑤ 销售维度列（来自 `dim_sale_account_relation_p`）

| # | 列名 | 类型 | 来源 | 说明 |
|---|---|---|---|---|
| 75 | sale_id | varchar(64) | `sale_id` | 管理人/销售 id |
| 76 | am_id | varchar(64) | `am_id` | AM 用户 id |

**匹配口径（沿用仓库现有 `bb_sale_relation_f` 逻辑）：**
- **direct 模式**：`relation_account_id = txn.account_id`，在生效窗口内匹配
- **root 模式**：经 `api_account_relation` → `root_id`，再关联 `sale_account_relation.relation_account_id = root_id`
- 取 `COALESCE(direct.sale_id, root.sale_id)`，按 `txn.transaction_time` 落在关系生效窗口内筛选最新一条

### ⑥ 审计列

| # | 列名 | 类型 | 来源 | 说明 |
|---|---|---|---|---|
| 77 | create_time | timestamptz | `qct.createTime` | **分区键** |
| 78 | update_time | timestamptz | `qct.updateTime` | CDC 变更识别依据 |
| 79 | delete_time | timestamptz | `qct.deleteTime` | 软删标记（下游查询 WHERE ... IS NULL） |
| 80 | version | int | 常量 1 | 版本号（重算递增） |

---

**总计约 80 列**（28 主表 + 17 spc + 24 卡维度 + 9 账户 + 2 销售 + 4 审计）。

---

## 3. 建表 DDL

```sql
-- 主表 + 分区
CREATE TABLE "dwm"."dwm_quantum_card_transaction_p" (
  "txn_id"                varchar(128) NOT NULL,
  "create_time"           timestamp(6) NOT NULL DEFAULT now(),
  -- ... 全部上述 80 列 ...
  CONSTRAINT "pk_dwm_quantum_card_txn" PRIMARY KEY ("txn_id", "create_time")
) PARTITION BY RANGE ("create_time" "pg_catalog"."timestamp_ops");

-- 月分区
CREATE TABLE "dwm"."dwm_quantum_card_txn_2025_08"
PARTITION OF "dwm"."dwm_quantum_card_transaction_p"
FOR VALUES FROM ('2025-08-01') TO ('2025-09-01');

-- 常用索引
CREATE INDEX idx_qct_txn_on_time_acc
  ON "dwm"."dwm_quantum_card_transaction_p" USING btree ("transaction_time", "account_id");
CREATE INDEX idx_qct_txn_on_sale_time
  ON "dwm"."dwm_quantum_card_transaction_p" USING btree ("sale_id", "transaction_time");
CREATE INDEX idx_qct_txn_on_provider_business
  ON "dwm"."dwm_quantum_card_transaction_p" USING btree ("provider", "business_type");
```

---

## 4. Flink SQL 流作业管道

**流水线：**
```
postgres-cdc ── qbit_card_transaction (txn) ─────────┐
                                                       ├──→ Stream Join → Upsert JDBC Sink → dwm_quantum_card_transaction_p
postgres-cdc ── qbitCard (cd)                          │
postgres-cdc ── account (acc)                          │
postgres-cdc ── api_account_relation (oar)             │      (多维 LEFT JOIN)
postgres-cdc ── dim_sale_account_relation_p (sr)       │
```

**关键配置：**
- **Connector**：`postgres-cdc`（WAL 流式，秒~分钟级延迟）
- **增量同步**：全量初始化 + 增量实时（upsert/delete 都支持）
- **jsonb 反规范化**：Flink SQL `CAST(txn.special_source_data->>'key' AS type)`
- **商户/地理双重取源**：`COALESCE(txn.special_source_data->>'mcc', CAST(txn.special_source_data->'card_acceptor' AS json)->>'mcc')`
- **幂等**：分区键 + upsert sink，不需要额外删除函数
- **参考模板**：[ods_online_qbit_card_settlement-cdc-sql.sql](bi-cost/flink/ods/ods_online_qbit_card_settlement-cdc-sql.sql)（CDC 源）+ [dwm_online_bb_card_transaction_detail_v2-cdc-sql.sql](bi-cost/flink/quantum-v2/bb/cdc/dwm_online_bb_card_transaction_detail_v2-cdc-sql.sql)（维表合并口径）

**落地文件：**

| 文件 | 内容 | 参考模板 |
|---|---|---|
| `table-scripts/dwm_quantum_card_transaction_p.sql` | 建表 DDL + 列注释 + 子分区 + 索引 | `dwm_bb_card_transaction_detail_v2_p.sql` |
| `cdc/dwm_online_quantum_card_transaction-cdc-sql.sql` | Flink SQL 流脚本（CDC 源 + join + sink） | `dwm_online_bb_card_transaction_detail_v2-cdc-sql.sql` |

---

## 5. 验证

1. 执行建表 DDL，确认无语法冲突和分区越界
2. CDC 回填后 `SELECT count(*)` 与 `qbit_card_transaction WHERE delete_time IS NULL` 一致
3. 抽查交易的 `settle_amount / spc_mcc / spc_markup_fee / sale_id / card_no` 与源表 JOIN 结果一致
4. 验证分区裁剪：WHERE 按 `create_time` 过滤时 EXPLAIN 只扫对应月分区
5. 跑一次日消费成本统计，对照线上 API 输出做金额一致性校验
