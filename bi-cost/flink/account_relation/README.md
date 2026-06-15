# Account Relation Flink SQL

## 1. 目标

维护销售关系时间线维表：

```text
salesAccountRelation -> dim_sale_account_relation_p
```

这张 DIM 只同步销售关系本身，不展开子户。

不做：

- 不把 `api_account_relation` 的所有子户展开进 DIM
- 不生成交易级 `transaction_id -> sale_id/am_id`
- 不替代 `api_account_relation` 的账户层级关系

## 2. 表定位

`dim_sale_account_relation_p` 是销售关系时间线维表。

字段映射：

```text
salesAccountRelation.id                  -> id
salesAccountRelation.accountId           -> relation_account_id
salesAccountRelation.salesId             -> sale_id
salesAccountRelation.amId                -> am_id
salesAccountRelation.operationManagerId  -> operation_manager_id
salesAccountRelation.createTime          -> relation_start_time
salesAccountRelation.deleteTime          -> relation_end_time
```

## 3. DWM 使用口径

BB/QI/SL DWM 挂销售关系时按 DWM 业务时间匹配：

```text
tx_time >= relation_start_time
AND (
  tx_time < relation_end_time
  OR relation_end_time IS NULL
)
```

匹配优先级：

```text
DIRECT > RELATION_ROOT > NONE
```

含义：

- `DIRECT`: 交易 `account_id` 自己命中 `dim_sale_account_relation_p.relation_account_id`
- `RELATION_ROOT`: direct 没命中时，通过 `api_account_relation.root_id` 命中 `dim_sale_account_relation_p.relation_account_id`
- `NONE`: 没有销售关系，DWM 的 `sale_id`、`am_id` 为空

当前 DWM 只需要落 `sale_id`、`am_id`，不落 `sale_relation_source`、`sale_relation_account_id`。

## 4. 文件

- `table-scripts/dim_sale_account_relation_p.sql`: DIM 建表和 2026 月分区
- `sp_sync_dim_sale_account_relation_incremental.sql`: CDC 增量同步
- `sp_init_dim_sale_account_relation_by_fast.sql`: Batch 初始化/回刷
