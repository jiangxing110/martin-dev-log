# Quantum v2 月度补偿 CDC 执行说明

## 调度

建议在 VVR 或外部编排系统配置每月 8 号执行：

```cron
0 0 8 * *
```

每次执行窗口为上月 1 号 00:00:00 到本月 1 号 00:00:00。

## 目录

月度补偿脚本统一放在独立包 `{bb,qi,sl}/monthly-cdc/` 下：

- `bb/monthly-cdc/`
- `qi/monthly-cdc/`
- `sl/monthly-cdc/`

## 执行顺序

### BB

1. `bb/monthly-cdc/dwm_online_bb_card_auth_detail_v2-monthly-cdc-sql.sql`
2. `bb/monthly-cdc/dwm_online_bb_card_transaction_detail_v2-monthly-cdc-sql.sql`
3. `bb/monthly-cdc/dws_online_bb_card_finance_daily_v2-monthly-cdc-delete-sql.sql`
4. `bb/monthly-cdc/dws_online_bb_card_finance_daily_v2-monthly-cdc-sql.sql`
5. `bb/monthly-cdc/dws_online_bb_active_card_count_v2-monthly-cdc-delete-sql.sql`
6. `bb/monthly-cdc/dws_online_bb_active_card_count_v2-monthly-cdc-sql.sql`
7. `bb/monthly-cdc/dws_online_bb_channel_fixed_fee_v2-monthly-cdc-delete-sql.sql`
8. `bb/monthly-cdc/dws_online_bb_channel_fixed_fee_v2-monthly-cdc-sql.sql`

### QI

1. `qi/monthly-cdc/dwm_online_qi_card_transaction_detail_v2-monthly-cdc-sql.sql`
2. `qi/monthly-cdc/dws_online_qi_card_finance_daily_v2-monthly-cdc-delete-sql.sql`
3. `qi/monthly-cdc/dws_online_qi_card_finance_daily_v2-monthly-cdc-sql.sql`
4. `qi/monthly-cdc/dws_online_qi_channel_fixed_fee_v2-monthly-cdc-delete-sql.sql`
5. `qi/monthly-cdc/dws_online_qi_channel_fixed_fee_v2-monthly-cdc-sql.sql`

### SL

1. `sl/monthly-cdc/dwm_online_sl_card_transaction_detail_v2-monthly-cdc-sql.sql`
2. `sl/monthly-cdc/dws_online_sl_card_finance_daily_v2-monthly-cdc-delete-sql.sql`
3. `sl/monthly-cdc/dws_online_sl_card_finance_daily_v2-monthly-cdc-sql.sql`
4. `sl/monthly-cdc/dws_online_sl_channel_fixed_fee_v2-monthly-cdc-delete-sql.sql`
5. `sl/monthly-cdc/dws_online_sl_channel_fixed_fee_v2-monthly-cdc-sql.sql`

## 注意

DWS 的 delete 和 insert 不要合并到同一个 Flink SQL 作业里执行。
之前 VVR 对多 DML 单作业有额外限制，拆开部署更稳定。

`bb/monthly-cdc/dwm_online_bb_card_auth_detail_v2-monthly-cdc-sql.sql` 仍需要配置 `auth_table_name`，例如 `bb_card_auth_detail_2026-07`。
所有 monthly-cdc 脚本的时间窗口均自动取上月，不需要再传 `start_time/end_time` 或 `start_date/end_date`。
BB transaction DWM 的 settlement `createTime` 扩窗为上月前 1 个月到本月 9 号 00:00 前，用于对齐 BB 原始成本对账口径。
