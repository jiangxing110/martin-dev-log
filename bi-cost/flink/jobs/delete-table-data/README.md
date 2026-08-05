# delete-table-data

通用 Flink JAR 删除作业，用于在阿里云实时计算 Flink/VVR 中保留删除动作的作业执行记录。

## 打包

```bash
cd flink/jobs/delete-table-data
mvn -DskipTests package
```

打包产物：

```text
target/delete-table-data-1.0.0.jar
```

## VVR 部署参数

Main class：

```text
com.qbit.flink.deletetable.DeleteTableDataJob
```

### 按日期范围删除

当前 `ods_crypto_blockchain_transfers` 删除任务参数：

```text
--delete-type date-range
--pg-url jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}
--pg-user ${secret_values.ADB_PG_USERNAME}
--pg-password ${secret_values.ADB_PG_PASSWORD}
--schema ods
--table-name ods_crypto_blockchain_transfers
--date-column dt
--start-date 2021-01-01
--end-date 2027-01-01
--dry-run false
```

### BB Channel Fixed Fee CDC 删除

替代 `dws_online_bb_channel_fixed_fee_v2-cdc-delete-sql.sql`：

```text
--delete-type bb-channel-fixed-fee-cdc
--pg-url jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}
--pg-user ${secret_values.ADB_PG_USERNAME}
--pg-password ${secret_values.ADB_PG_PASSWORD}
--dry-run false
```

该类型会删除 `dws.dws_bb_card_finance_daily_v2_p` 中 `special_fee_type = 'CHANNEL_FIXED_FEE'`，并且月份范围来自前一天更新的 `ods.ods_bi_month_tag` 中 BB `CHANNEL_COST` 配置。

先验证范围但不删除时，把 `--dry-run` 改成 `true`。作业会输出匹配行数，不会执行 `DELETE`。

## 参数说明

| 参数 | 必填 | 说明 |
|---|---:|---|
| `--pg-url` / `--jdbc-url` | 是 | ADBPG PostgreSQL JDBC 地址 |
| `--pg-user` / `--username` | 是 | 数据库用户名 |
| `--pg-password` / `--password` | 是 | 数据库密码 |
| `--delete-type` | 否 | 删除类型，默认 `date-range` |
| `--schema` | `date-range` 必填 | schema 名，例如 `ods` |
| `--table-name` | `date-range` 必填 | 表名，例如 `ods_crypto_blockchain_transfers` |
| `--start-date` | `date-range` 必填 | 删除起始日期，闭区间，例如 `2021-01-01` |
| `--end-date` | `date-range` 必填 | 删除结束日期，开区间，例如 `2027-01-01` |
| `--date-column` | 否 | 日期字段，默认 `dt` |
| `--dry-run` | 否 | `true` 只统计不删除，默认 `false` |

## 注意

- 这是 Flink 作业，不是 ADBPG Console 手动 SQL；在 VVR 中按 JAR 部署后启动，运维中心会保留执行记录。
- `schema`、`table-name`、`date-column` 只允许普通 SQL 标识符，避免把任意 SQL 拼进参数。
- 删除成功后，再运行对应的 batch 写入作业。
