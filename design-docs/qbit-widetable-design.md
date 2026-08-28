# 量子卡交易大宽表设计（dwm_quantum_card_transaction_p）

> **摘要**：以 `qbit_card_transaction` 为唯一交易事实源，从 `specialSourceData` JSON 洗出高频 key 成独立列，再关联 `qbitCard`、`account`、`api_account_relation`、`dim_sale_account_relation_p` 补齐分析维度，写入物理分区大宽表。
> **关键决策：** 一行对应一条 `qbit_card_transaction` · 不依赖 `quantum_card_transaction_extend` · 不展开 settlement 明细 · 保留原始 JSON 便于追溯。

> **范围说明**：`quantum_card_transaction_extend` 是旧的交易扩展模型，本次新宽表不读取、不关联、不复用其中字段。若后续需要 settlement 一对多明细，应另建 `dwm_quantum_card_settlement_p`，不能直接展开到本表。

## 0. 粒度与口径

- **事实粒度**：一行 = 一条 `qbit_card_transaction` 记录。
- **业务唯一键**：`qbit_card_transaction.id`。
- **物理主键**：`(id, create_time)`，用于适配分区表主键要求。
- **主分区字段**：`create_time`，直接来源于 `qbit_card_transaction.createTime`，表示交易记录进入交易表的创建时间。
- **业务分析时间**：`transaction_time` 继续保留，用于交易发生时间、成本统计和销售归属，但不作为物理分区键。
- **软删除**：保留源表 `delete_time`，下游默认使用 `WHERE delete_time IS NULL`。
- **settlement 粒度**：不在本表展开；一笔交易对应多条 settlement 时，放入独立明细表。

---

## 1. 数据源与关联关系

| # | 事实/维度 | 源 | JOIN 条件 | 说明 |
|---|---|---|---|---|
| 1 | **事实主表** | `qbit_card_transaction` | — | 唯一交易事实来源 |
| 2 | **卡维度** | `qbitCard` 当前 lookup | 交易 INSERT 时按 `card_id` 查询 | INSERT 时最新卡属性，UPDATE 保留宽表原值 |
| 3 | **账户维度** | `account` 当前 lookup | 交易 INSERT 时按 `account_id` 查询 | INSERT 时最新账户属性，UPDATE 保留宽表原值 |
| 3a | **账户扩展维度** | `accountExtend` 当前 lookup | 交易 INSERT 时按 `account_id` 查询 | `systemType` 来自 accountExtend，INSERT 时固化，UPDATE 保留原值 |
| 4a | **API 子户映射** | `api_account_relation` | LEFT JOIN ON `aar.account_id = txn.account_id::uuid` | 仅 API 场景：子账户→root_id |
| 4b | **销售维度** | `dim_sale_account_relation_p` 当前 lookup | 交易 INSERT 时匹配 direct + root | UPDATE 保留宽表原值 |

> 本表不再读取 `quantum_card_transaction_extend`。`channel_provision`、扩展表中的 `country`、`transaction_id` 等字段不得作为本表必需字段；如果分析需要，优先从主表字段或 `special_source_data` 提取。

---

## 2. 完整表结构（全量逐列）

### ① 主表事实列（来自 `qbit_card_transaction`）

以下为交易事实字段。字段名统一转换为 snake_case；`special_source_data` 原始 JSON 保留，同时将高频字段展开为独立列。

| # | 列名 | 类型 | 注释 |
|---|---|---|---|
| 1 | id | varchar(128) | **业务主键**，直接沿用 `qbit_card_transaction.id` |
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
| 23 | comments | text | 三方备注，保留完整内容 |
| 24 | authorization_code | varchar | Nium 授权码 |
| 25 | is_show | boolean | 是否显示给用户 |
| 26 | released | boolean | 是否释放交易 |
| 27 | third_complete_time | timestamptz | 三方完成时间 |
| 28 | special_source_data | jsonb | 三方源数据 JSON（低频 key 保留在此） |

### ② 反规范化统计列（来自 `special_source_data`）— 共 18 个

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

#### 业务码/清算响应类

| # | 列名 | 类型 | jsonb key | 来源路径 | 说明 |
|---|---|---|---|---|---|
| 44 | business_code_list | jsonb | `code` | 顶层数组 | 业务码列表；兼容账户验证等场景按数组包含查询 |
| 45 | spc_system_trace_audit_no | varchar | `systemTraceAuditNumber` | 顶层 | 清算 trace no |
| 46 | spc_fail_reason | text | `failReason` | 顶层 | 失败原因，保留完整内容 |

> `specialSourceData.code` 实际为业务码数组，不是单值响应码；因此不再设计 `spc_code varchar`，直接落为 `business_code_list jsonb`。

> **商户/地理双重取源示例（Flink SQL）：**
> ```sql
> COALESCE(
>   txn.special_source_data->>'mcc',
>   CAST(txn.special_source_data->'card_acceptor' AS json)->>'mcc'
> ) AS spc_mcc
> ```

### ③ 卡维度列（来自 `qbitCard`、`qbitCardGroup`）— LEFT JOIN

> 基于实际 DDL：`CREATE TABLE "public"."qbitCard" (...)`
> 本表只保留交易分析需要的卡属性；卡号、token、持卡人身份和限额等字段继续留在卡维度/ODS 表中。卡和卡组字段必须按交易发生时间取得历史快照，不使用当前状态覆盖历史交易。

| # | 列名 | 类型 | qbitCard 列名 | 说明 |
|---|---|---|---|---|
| 47 | card_no_last_four | varchar | `"qbitCardNoLastFour"` | 卡号后四位，用于明细展示 |
| 48 | card_provider | varchar | `provider` | 发卡提供方 |
| 49 | card_type_dim | varchar | `"type"` | VISA / Master / Amex |
| 50 | label | varchar | `label` | 卡标签 |
| 51 | group_id | uuid | `groupId` | 卡组 id |
| 52 | balance_id | uuid | `balanceId` | 余额关联 id，用于资金和交易核对 |
| 53 | first_six | varchar | `firstSix` | BIN 前六位 |
| 54 | card_belong | varchar | `cardBelong` | 卡归属 |
| 55 | physical_card_status | varchar(30) | `physicalCardStatus` | 实体卡当前状态 |
| 56 | card_mode | varchar(30) | `cardMode` | Virtual / Physical |
| 57 | card_status | varchar(30) | `status` | 卡当前状态 |
| 58 | group_name | varchar(255) | `qbitCardGroup.groupName` | 卡组名称 |
| 59 | group_status | varchar(30) | `qbitCardGroup.status` | 卡组状态 |

> `label`、`card_belong`、`physical_card_status`、`card_mode` 均按交易发生时点取值；卡维度发生变化后，不能用新值覆盖历史交易。
> 卡组字段通过 `qbitCard.groupId = qbitCardGroup.id` 关联，并按交易发生时点获取 `group_name`、`group_status`。

### ④ 账户维度列（来自 `account`、`accountExtend` + 可选 `api_account_relation`）— LEFT JOIN

> 基于实际 DDL：`account` 提供账户基础字段，`accountExtend` 提供注册国家等扩展字段；账户字段同样必须按交易发生时点取历史值。

| # | 列名 | 类型 | account 列名 | 说明 |
|---|---|---|---|---|
| 60 | acc_verified_name | varchar | `"verifiedName"` | 账户实名 |
| 61 | parent_account_id | uuid | `"parentAccountId"` | 父账户 |
| 62 | account_type | varchar(30) | `"accountType"` | 账户类型 |
| 63 | system_type | varchar(50) | `accountExtend."systemType"` | 系统类型 |
| 64 | acc_verified_name_en | varchar(255) | `"verifiedNameEn"` | 账户英文名 |
| 65 | acc_country | varchar | `account."country"` | 注册国家 |
| 66 | referral_code_id | varchar | `"referralCodeId"` | 推荐码 ID |
| 67 | acc_type | varchar(50) | `"type"` | 账户角色（Merchant 等） |
| 68 | acc_display_id | varchar(15) | `"displayId"` | 展示 ID |
| 69 | tenant_id | int8 | `"tenantId"` | 租户 ID |
| 70 | root_account_id | uuid | `api_account_relation.root_id` | **API 场景**：子账户的根账户 id（仅 API 子户有值，通过 oar.account_id = txn.account_id::uuid 关联） |

> * 注册国家实际使用 `account.country`，英文名使用 `account.verifiedNameEn`，系统类型使用 `accountExtend.systemType`。

> `root_account_id` 匹配逻辑：`api_account_relation WHERE account_id = txn.account_id AND delete_time IS NULL LIMIT 1`

> ⚠️ 注意：`account` 表没有 `email` 列（之前误加），如需邮箱信息需从其他维表获取。

### ⑤ 销售维度列（来自 `dim_sale_account_relation_p`）

| # | 列名 | 类型 | 来源 | 说明 |
|---|---|---|---|---|
| 71 | sale_id | varchar(64) | `sale_id` | 管理人/销售 id |
| 72 | am_id | varchar(64) | `am_id` | AM 用户 id |
| 73 | operation_manager_id | varchar(64) | `operation_manager_id` | 运营管理人 id |

**匹配口径（沿用仓库现有时间线关系逻辑）：**
- **direct 模式**：`relation_account_id = txn.account_id`，在生效窗口内匹配
- **root 模式**：经 `api_account_relation` → `root_id`，再关联 `sale_account_relation.relation_account_id = root_id`
- **优先级**：direct 匹配成功后不再使用 root；只有 direct 匹配不到时才使用 root
- `sale_id`、`am_id` 和 `operation_manager_id` 必须来自同一条关系记录，不能分别对两个来源字段做 `COALESCE`
- 按 `txn.transaction_time` 落在关系生效窗口内筛选，取同一匹配模式下 `relation_start_time` 最新的一条

### ⑥ 审计列

| # | 列名 | 类型 | 来源 | 说明 |
|---|---|---|---|---|
| 72 | create_time | timestamptz | `qct.createTime` | **分区键**，直接来源于交易表创建时间 |
| 73 | update_time | timestamptz | `qct.updateTime` | 增量变更识别依据 |
| 74 | delete_time | timestamptz | `qct.deleteTime` | 软删标记（下游查询 WHERE ... IS NULL） |
| 75 | version | int | 常量 1 | 版本号（重算递增） |

---

**总计 75 列**（28 主表 + 18 spc + 13 卡/卡组维度 + 9 账户 + 3 销售 + 4 审计）。

### 2.1 维度时点关联口径

宽表中的卡、卡组、账户、账户扩展和销售关系字段，统一按 `transaction_time` 取得交易发生时的有效记录。历史维表需要提供 `valid_from`、`valid_to`（或等价的 CDC 快照版本）字段，关联条件示例：

```sql
dim.valid_from <= txn.transaction_time
AND (dim.valid_to > txn.transaction_time OR dim.valid_to IS NULL)
```

本作业采用流式快照口径：交易 INSERT 到达时读取各维度当时最新值并固化到宽表；后续维度 CDC 不触发交易宽表更新。由于当前 `qbitCard`、`qbitCardGroup`、`account`、`accountExtend` 是当前状态表，历史交易不保证能够还原过去的维度值；如需历史修正，使用 batch 作业显式回刷指定时间范围。

---

## 3. 建表 DDL

```sql
-- 主表 + 分区
CREATE TABLE "dwm"."dwm_quantum_card_transaction_p" (
  "id"                    varchar(128) NOT NULL,
  "transaction_time"      timestamptz NOT NULL,
  "create_time"           timestamptz NOT NULL,
  -- ... 全部上述 75 列 ...
  CONSTRAINT "pk_dwm_quantum_card_txn" PRIMARY KEY ("id", "create_time")
) PARTITION BY RANGE ("create_time" "pg_catalog"."timestamptz_ops");

-- 月分区
CREATE TABLE "dwm"."dwm_quantum_card_txn_2025_08"
PARTITION OF "dwm"."dwm_quantum_card_transaction_p"
FOR VALUES FROM ('2025-08-01 00:00:00+08') TO ('2025-09-01 00:00:00+08');

-- 交易时间 + 账户：账户交易明细、日成本统计
CREATE INDEX idx_dwm_qct_time_account
  ON "dwm"."dwm_quantum_card_transaction_p" USING btree (
    "transaction_time", "account_id"
  );

-- 账户 + 交易时间：按账户查询时间范围时使用
CREATE INDEX idx_dwm_qct_account_time
  ON "dwm"."dwm_quantum_card_transaction_p" USING btree (
    "account_id", "transaction_time"
  );

-- 销售/AM 归属 + 交易时间：销售成本和业绩分析
CREATE INDEX idx_dwm_qct_sale_time
  ON "dwm"."dwm_quantum_card_transaction_p" USING btree (
    "sale_id", "am_id", "transaction_time"
  );

-- 运营管理人 + 交易时间：运营管理分析
CREATE INDEX idx_dwm_qct_operation_manager_time
  ON "dwm"."dwm_quantum_card_transaction_p" USING btree (
    "operation_manager_id", "transaction_time"
  );

-- 卡维度查询：按卡追溯交易
CREATE INDEX idx_dwm_qct_card_time
  ON "dwm"."dwm_quantum_card_transaction_p" USING btree (
    "card_id", "transaction_time"
  );

-- 渠道/业务类型/状态：交易量和成本聚合
CREATE INDEX idx_dwm_qct_provider_business_status
  ON "dwm"."dwm_quantum_card_transaction_p" USING btree (
    "provider", "business_type", "status", "transaction_time"
  );

-- 卡状态 + 交易时间：卡状态交易分析
CREATE INDEX idx_dwm_qct_card_status_time
  ON "dwm"."dwm_quantum_card_transaction_p" USING btree (
    "card_status", "transaction_time"
  );

-- 三方订单追溯和对账
CREATE INDEX idx_dwm_qct_source_id
  ON "dwm"."dwm_quantum_card_transaction_p" USING btree ("source_id");

-- 源记录变更扫描/补数辅助
CREATE INDEX idx_dwm_qct_update_time
  ON "dwm"."dwm_quantum_card_transaction_p" USING btree ("update_time");
```

---

## 4. Flink SQL 流作业管道

**流水线：**
```
qbit_card_transaction (txn) ──────────────────────────┐
                                                       ├──→ 维度补齐 → 幂等 Upsert → dwm_quantum_card_transaction_p
qbitCard (cd)                                          │
account (acc)                                          │
accountExtend (ae)                                     │
api_account_relation (aar)                             │
dim_sale_account_relation_p (sr)                       │
```

**关键配置：**
- **第一版同步方式**：以 `qbit_card_transaction` 为唯一 CDC 驱动源；INSERT 读取当前维度并固化，UPDATE 读取目标宽表已有维度值后，仅替换交易主表字段。
- **维度变更**：`qbitCard`、`qbitCardGroup`、`account`、`accountExtend` 和销售关系不作为宽表作业驱动源，维度变化不会更新已落表交易。
- **JSON 反规范化**：先在解析视图中提取 JSON 字段，再统一完成类型转换；不得直接假定 PostgreSQL `->>` 语法可在 Flink SQL 中执行。
- **幂等**：使用稳定业务键 `(id, create_time)` + upsert；主表软删除时同步写入 `delete_time`。`create_time` 应视为源表不可变字段。
- **真正 WAL CDC**：本版只消费交易主表 WAL CDC；维度表通过 lookup 读取，不注册为会传播变更的普通 CDC JOIN。
- **参考模板**：[ods_online_qbit_card_settlement-cdc-sql.sql](bi-cost/flink/ods/ods_online_qbit_card_settlement-cdc-sql.sql)（CDC 源）+ [dwm_online_bb_card_transaction_detail_v2-cdc-sql.sql](bi-cost/flink/quantum-v2/bb/cdc/dwm_online_bb_card_transaction_detail_v2-cdc-sql.sql)（维表合并口径）

**落地文件：**

| 文件 | 内容 | 参考模板 |
|---|---|---|
| `design-docs/qbit-widetable-ddl.sql` | 建表 DDL + 列注释 + 月分区 + 预设索引 | `flink/quantum-v2/qi/table-scripts/dwm_qi_card_transaction_detail_v2_p.sql` |
| `flink/quantum-v2/qbit-card-transaction-widetable/cdc/dwm_online_qbit_card_transaction_widetable-cdc-sql.sql` | 交易 CDC 驱动；INSERT 固化维度，UPDATE 保留原维度 | `quantum-v2/sl/cdc/dwm_online_sl_card_transaction_detail_v2-cdc-sql.sql` |
| `flink/quantum-v2/qbit-card-transaction-widetable/batch/dwm_online_qbit_card_transaction_widetable-batch-sql.sql` | 按时间范围批量初始化/回刷 | `quantum-v2/sl/batch/dwm_online_sl_card_transaction_detail_v2-batch-sql.sql` |
| `flink/quantum-v2/qbit-card-transaction-widetable/table-scripts/dwm_qbit_card_transaction_widetable_p.sql` | 宽表 DDL、分区和索引 | `quantum-v2/sl/table-scripts/dwm_sl_card_transaction_detail_p.sql` |

---

## 4.1 历史回填月度数据量

以下为 `qbit_card_transaction` 按 `createTime` 月份统计的笔数，用于估算 batch 回填窗口。首次回填从 `2020-06-23 00:00:00` 开始；batch 参数统一使用 `[start_time, end_time)` 左闭右开区间，避免重复或遗漏边界交易。

| 月份（createTime） | 交易笔数 |
|---|---:|
| 2020-06-01 | 35 |
| 2020-07-01 | 30 |
| 2020-08-01 | 238 |
| 2020-09-01 | 7,468 |
| 2020-10-01 | 7,009 |
| 2020-11-01 | 20,247 |
| 2020-12-01 | 85,204 |
| 2021-01-01 | 96,507 |
| 2021-02-01 | 60,968 |
| 2021-03-01 | 175,532 |
| 2021-04-01 | 149,379 |
| 2021-05-01 | 199,168 |
| 2021-06-01 | 157,050 |
| 2021-07-01 | 144,049 |
| 2021-08-01 | 230,172 |
| 2021-09-01 | 143,456 |
| 2021-10-01 | 121,067 |
| 2021-11-01 | 121,448 |
| 2021-12-01 | 244,128 |
| 2022-01-01 | 227,629 |
| 2022-02-01 | 174,184 |
| 2022-03-01 | 314,552 |
| 2022-04-01 | 512,114 |
| 2022-05-01 | 492,576 |
| 2022-06-01 | 783,315 |
| 2022-07-01 | 1,552,187 |
| 2022-08-01 | 1,024,484 |
| 2022-09-01 | 962,470 |
| 2022-10-01 | 1,277,848 |
| 2022-11-01 | 1,436,935 |
| 2022-12-01 | 1,241,278 |
| 2023-01-01 | 1,391,630 |
| 2023-02-01 | 1,976,480 |
| 2023-03-01 | 2,580,307 |
| 2023-04-01 | 1,443,982 |
| 2023-05-01 | 819,900 |
| 2023-06-01 | 662,023 |
| 2023-07-01 | 1,521,874 |
| 2023-08-01 | 2,209,282 |
| 2023-09-01 | 2,279,488 |
| 2023-10-01 | 3,591,594 |
| 2023-11-01 | 1,620,493 |
| 2023-12-01 | 1,517,507 |
| 2024-01-01 | 1,390,426 |
| 2024-02-01 | 1,181,155 |
| 2024-03-01 | 1,933,189 |
| 2024-04-01 | 1,965,287 |
| 2024-05-01 | 2,214,880 |
| 2024-06-01 | 2,016,092 |
| 2024-07-01 | 1,936,110 |
| 2024-08-01 | 1,894,682 |
| 2024-09-01 | 1,682,437 |
| 2024-10-01 | 1,683,534 |
| 2024-11-01 | 1,909,954 |
| 2024-12-01 | 2,298,269 |
| 2025-01-01 | 2,199,298 |
| 2025-02-01 | 2,052,329 |
| 2025-03-01 | 2,627,629 |
| 2025-04-01 | 2,730,752 |
| 2025-05-01 | 2,956,645 |
| 2025-06-01 | 2,877,152 |
| 2025-07-01 | 3,567,513 |
| 2025-08-01 | 3,974,703 |
| 2025-09-01 | 2,653,402 |
| 2025-10-01 | 3,384,229 |
| 2025-11-01 | 3,847,122 |
| 2025-12-01 | 5,127,855 |
| 2026-01-01 | 6,065,034 |
| 2026-02-01 | 5,139,622 |
| 2026-03-01 | 6,274,878 |
| 2026-04-01 | 5,952,729 |
| 2026-05-01 | 5,348,182 |
| 2026-06-01 | 5,567,550 |
| 2026-07-01 | 5,799,827 |
| 2026-08-01 | 4,336,913 |

回填切分建议：2022 年及以前可按月、2023-2024 年按半月、2025 年按 7 天、2026 年按 3 天执行；每次部署只传入一个切片的 `start_time` 与 `end_time`。

---

## 5. 验证

1. 执行建表 DDL，确认无语法冲突和分区越界
2. 回填后按 `id` 对账，确认目标表有效记录与 `qbit_card_transaction WHERE delete_time IS NULL` 一一对应
3. 验证目标表不存在同一 `(id, create_time)` 多行
4. 抽查 `settle_amount / spc_mcc / spc_markup_fee / sale_id / card_no_last_four` 与主表及维表结果一致
5. 验证按 `create_time` 过滤时 EXPLAIN 能够裁剪到对应月分区；按 `transaction_time` 查询时使用索引但不保证分区裁剪
6. 分别验证交易主表 INSERT/UPDATE 会更新宽表，卡/卡组/账户/销售维度变更不会更新既有交易宽表
7. 跑一次日消费成本统计，对照线上 API 输出做金额一致性校验

---

## 6. 后续字段扩展规范

### 6.1 总体原则

- **只增不删**：已上线字段不直接删除或改名，避免下游 SQL、报表和 Flink 作业失效。
- **新增字段默认可空**：先 `ADD COLUMN`，不要给历史数据增加强制非空约束。
- **显式列清单**：Flink source、view、sink 和目标 DDL 均使用显式字段，不使用 `SELECT *` 作为长期接口。
- **先扩结构，再发作业，再回填**：确保新旧作业切换期间目标表结构兼容。
- **不滥加字段**：低频、结构不稳定的 JSON key 继续保留在 `special_source_data`，只有稳定且高频使用的字段才展开。

### 6.2 不同类型字段的增加方式

| 字段类型 | 处理方式 | 是否需要历史回填 |
|---|---|---|
| `qbit_card_transaction` 主表字段 | 目标表新增同名 snake_case 字段，更新 source/view/sink | 通常需要 |
| `special_source_data` 高频 JSON key | 增加 `spc_` 前缀字段，在解析视图中统一转换 | 通常需要 |
| `qbitCard` / `qbitCardGroup` 卡组维度字段 | INSERT 时读取当前 lookup 值并固化；UPDATE 时保留目标宽表原值 | 仅显式 batch 回刷时更新 |
| `account` / `accountExtend` 字段 | INSERT 时读取当前 lookup 值并固化；UPDATE 时保留目标宽表原值 | 仅显式 batch 回刷时更新 |
| 销售关系字段 | INSERT 时按 direct 优先、root 兜底读取并固化；UPDATE 时保留原值 | 仅显式 batch 回刷时更新 |
| settlement 一对多字段 | 不加入本交易宽表，另建 settlement 明细表 | 不适用 |

### 6.3 标准变更步骤

```text
1. 确认字段定义、来源、类型、空值口径和查询场景
2. 在目标宽表 ADD COLUMN
3. 更新设计文档中的字段清单和总列数
4. 更新 Flink source / view / sink 的显式列清单
5. 先发布兼容版本，验证新字段能写入
6. 首次按 create_time 分区回填交易，并按当前维度值生成快照
7. 对比源表与宽表，验证空值、类型、行数和金额不变
8. 在 changelogs/ 记录字段变更
```

### 6.4 DDL 示例

```sql
-- 示例：新增交易主表字段
ALTER TABLE "dwm"."dwm_quantum_card_transaction_p"
  ADD COLUMN "new_analysis_field" varchar(100);
```

新增字段不需要修改主键和分区键。历史回填时只更新受影响的 `id/create_time` 记录，不能通过重新生成主键写入副本。

### 6.5 兼容性要求

- 新字段上线前，查询应允许字段为空。
- Flink 作业发布顺序应保证“目标表先有字段，作业后写字段”。
- 如果字段来自卡、账户或销售维度，交易 INSERT 固化 lookup 值，交易 UPDATE 保留宽表原值；只有历史数据修正任务才触发关联交易回刷。
- `version` 继续表示记录处理版本，不用于表示表结构版本；如确实需要追踪结构版本，再单独增加 `schema_version`。
