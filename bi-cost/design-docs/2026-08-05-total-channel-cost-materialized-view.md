# 总渠道成本普通物化视图方案

## 摘要

使用 ADBPG 普通物化视图替代总渠道成本的 Flink batch/CDC 维护方式。
物化视图每 5 小时全量刷新一次，不依赖 BB、BZ、QI、SL 和金融渠道成本
的具体更新时间。现有 V2 结果表和 batch 脚本暂时保留，用于上线前数据核对
和应急回刷。

## 对象

- 新物化视图：`dws.mv_channel_cost_daily`
- 创建脚本：`flink/total_cost/mv_channel_cost_daily.sql`
- 刷新脚本：`flink/total_cost/schedule_refresh_mv_channel_cost_daily.sql`
- 旧结果表：`dws.dws_total_channel_cost_daily_v2_p`
- 下游毛利视图：`dws.mv_gross_profit_daily`

脚本结构参考 `flink/profit/mv_gross_profit_daily.sql` 和
`flink/profit/schedule_refresh_mv_gross_profit_daily.sql`。

## 数据来源

物化视图完整复刻
`flink/total_cost/dws_online_total_channel_cost_daily-batch-sql.sql` 的五路来源：

- `dws.dws_bb_card_finance_daily_v2_p`
- `dws.dws_bz_card_finance_daily_v2_p`
- `dws.dws_qi_card_finance_daily_v2_p`
- `dws.dws_sl_card_finance_daily_p`
- `dwm.dwm_finance_channel_cost_p`

所有来源只读取 `delete_time IS NULL` 的有效记录。

## 计算口径

- BB 保留月度 `total_net_amount` 分档费率、授权、清算、拒付、冲正、
  退款、Active Card 和固定成本公式。
- BZ 保留基础金额或笔数乘对应费率以及固定成本的公式。
- QI 保留八类基础金额乘对应费率以及固定成本的公式。
- SL 继续只取 `cost_fixed_fee`。
- 金融渠道成本按 `product_line` 进入四个成本桶。
- 最终粒度为
  `report_date + account_id + sale_id + am_id`。
- `create_time` 取参与汇总来源记录的最早创建时间。
- `update_time` 取参与汇总来源记录的最晚更新时间，避免每次刷新改写未变化行。
- `ACQUIRING` 进入 `acquiring_cost`。
- `GLOBAL_ACCOUNT` 进入 `business_cost`。
- `QUANTUM_CARD` 进入 `quantum_cost`。
- `CRYPTO_ASSET` 进入 `crypto_cost`。

视图不再接收 `start_date/end_date`，每次刷新根据全部有效来源数据重新生成。

## 主键与索引

- 使用日期、账户、销售和 AM 生成稳定的 bigint `id`。
- 创建 `(id)` 唯一索引，供
  `REFRESH MATERIALIZED VIEW CONCURRENTLY` 使用。
- 创建 `(report_date, account_id)` 普通索引，支持毛利查询和数据核对。

## 刷新

使用 `pg_cron` 每 5 小时整点刷新：

```cron
0 */5 * * *
```

执行命令：

```sql
REFRESH MATERIALIZED VIEW CONCURRENTLY
    dws.mv_channel_cost_daily;
```

渠道成本每 5 小时刷新一次，毛利视图每 30 分钟刷新一次。毛利可以及时
反映有效收入变化，渠道成本则在自身刷新完成后的下一次毛利刷新中生效；
首次刷新或并发刷新不可用时，可手动执行非并发
`REFRESH MATERIALIZED VIEW`。

## 上线与回滚

1. 创建总渠道成本物化视图和索引。
2. 注册每 5 小时刷新任务。
3. 按月份、成本桶和账户比较 V2 表与新物化视图。
4. 核对通过后，单独修改毛利视图的成本来源为 V3。
5. 观察期内保留 V2 表、现有 batch 和毛利视图原定义。
6. 出现异常时停用新物化视图刷新任务，毛利视图继续读取 V2，不影响现有链路。

本次实现不直接修改毛利视图，也不删除或重命名现有 V2 表。
