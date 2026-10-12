# QI 2026-09 月度系数 seed 方案

## 摘要

将 BI 提供的 6 个 QI 参数写入 `ods.ods_bi_month_tag`，按现有映射并结合附件中的两项覆盖值，生成 10 条 2026-09 月度配置。QI DWS 和销售佣金物化视图已经消费这些 tag，本次不改计算逻辑。

## 参数映射

- `param_a = 1.0411` → `QI_COST_SERVICE_RATE`
- `param_b = 0.9052` → `QI_COST_ACS_REGULAR_RATE`
- `param_c = 1.0967` → `QI_COST_ACS_VIP_RATE`
- `param_d = 1.0362` → `QI_COST_VRM_RATE`
- `param_e = 1.1275` → `QI_COST_HK_REGULAR_RATE`、`QI_COST_HK_VIP_RATE`、`QI_REBATE_INTERCHANGE_RATE`
- `param_f = 0.8994` → `QI_COST_DCSF_RATE`
- 附件覆盖：`QI_COST_REIMBURSEMENT_RATE = 1.1275`，`QI_REBATE_INCENTIVE_RATE = 1`

## 处理方案

新增 `month-tag/qi_bi_month_tag_seed_2026_09.sql`，配置范围固定为 `provider='IQ'`、`product_line='QI'`、`account_type='fullCustomer'`、`detail='2026-09'`，统计时间为 `2026-09-01 00:00:00+08`。复用现有 seed 的软删除旧同月记录、固定 ID 更新/插入和执行后核对方式。

本次只生成配置 SQL，不直接连接数据库，不触发 QI DWS 重算或销售佣金快照重建。执行 seed 后需重跑 9 月 QI DWS，再刷新销售毛利物化视图，才能让计算结果采用新系数。

## 验证

- SQL 包含 10 个 tag，映射值与 BI 参数一致。
- 所有月度行使用 `2026-09` / `2026-09-01 00:00:00+08`。
- `git diff --check` 通过。
