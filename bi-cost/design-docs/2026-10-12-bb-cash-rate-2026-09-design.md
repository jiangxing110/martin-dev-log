# BB 2026-09 月度返现系数方案

## 摘要

将 BI 提供的 BB 月度返现基数 `0.021067` 乘以调整系数 `0.9940` 后写入 `ods.ods_bi_month_tag`，配置月份为 2026-09。最终系数为 `0.020940598`。BB batch / CDC 已按 `BB_CASH_RATE` 读取月度系数，本次不修改计算逻辑。

## 处理方案

新增 `month-tag/bb_bi_month_tag_seed_2026_09.sql`，写入一条配置：`provider='BB'`、`product_line='BB'`、`account_type='fullCustomer'`、`tag='BB_CASH_RATE'`、`detail='2026-09'`、`statistics_time='2026-09-01 00:00:00+08'`、`amount=0.021067 * 0.9940 = 0.020940598`。复用现有 seed 模式，对相同月份旧有效配置软删除，并按固定 ID 幂等更新或插入。

本次只生成 SQL 文件，不连接数据库或触发 BB DWS 重算。

## 验证

- 仅一条 2026-09 `BB_CASH_RATE` 配置，系数表达式为 `0.021067 * 0.9940`，结果为 `0.020940598`。
- SQL 包含更新、插入、旧记录软删除和执行后核对。
- `git diff --check` 通过。
