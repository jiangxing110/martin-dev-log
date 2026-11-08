# 2026-10 BB / QI 渠道成本月度 tag 配置方案

## 摘要

新增一份 2026-10 `ods.ods_bi_month_tag` 配置 SQL，包含 BB 月度返现率和 QI 月度成本系数。QI 销售口径返现系数设为 1；客户毛利口径的 CROSS 系数由客户毛利 SQL 单独应用。成本金额和返现金额作为核对数据，不写入费率 tag。

## 范围

- 新增 `month-tag/bi_month_tag_seed_2026_10.sql`。
- 写入 1 条 BB 配置及 10 条 QI 配置，范围限定为 2026-10。
- 不修改 Flink 计算逻辑，不连接数据库执行，不触发重算。

## 配置映射

| provider / tag | amount | 来源 / 口径 |
|---|---:|---|
| BB / `BB_CASH_RATE` | 0.022698 | 2.2698% |
| IQ / `QI_COST_SERVICE_RATE` | 1.0122 | param_a |
| IQ / `QI_COST_ACS_REGULAR_RATE` | 0.9079 | param_b |
| IQ / `QI_COST_ACS_VIP_RATE` | 1.1059 | param_c |
| IQ / `QI_COST_VRM_RATE` | 1.0131 | param_d |
| IQ / `QI_COST_HK_REGULAR_RATE` | 1.0848 | param_e / CROSS |
| IQ / `QI_COST_HK_VIP_RATE` | 1.0848 | param_e / CROSS |
| IQ / `QI_COST_DCSF_RATE` | 0.9676 | param_f |
| IQ / `QI_COST_REIMBURSEMENT_RATE` | 1.0848 | 按现有月度配置约定使用 param_e |
| IQ / `QI_REBATE_INTERCHANGE_RATE` | 1.0000 | 销售返现不乘月度参数 |
| IQ / `QI_REBATE_INCENTIVE_RATE` | 1.0000 | 沿用现有配置 |

所有行使用 `detail='2026-10'`、`statistics_time='2026-10-01 00:00:00+08'` 和 `account_type='fullCustomer'`。BB 的 provider/product_line 为 `BB`；QI 为 `IQ` / `QI`。

## 写入方式

沿用现有 seed 模式：临时表列出全部目标行；软删除同月份、同 provider/product_line/account_type/tag 的其他有效行；使用固定 ID 更新并重新激活；ID 不存在时插入；最后按 provider 和月份查询核对。SQL 可重复执行，不改其他月份或 `DEFAULT_FALLBACK`。

## 核对数据与限制

- BB 成本 486,815、返现 313,979.6；QI 总成本 814,079、固定成本 82,434、销售返现 823,901，均为报表核对值，不写入月度 tag。
- QI 毛利口径返现金额尚未计算；客户毛利查询应使用 param_e=1.0848，不得复用销售口径的 1.0000 返现 tag 代替。
- 固定 ID 采用本脚本独立编号段；执行前需在数据库确认无 ID 冲突。

## 验证

- SQL 应包含 11 行目标配置，月份、scope、tag 与金额一致。
- 旧配置软删除限定在 2026-10 的目标 tag 和目标 scope。
- 包含固定 ID 更新、缺失时插入和执行后核对查询。
- 运行 `git diff --check`。
