# QI 2026-08 月度系数记录方案

## 摘要

将 QI 客户毛利脚本中确认的 2026-08 六个参数写入 `ods.ods_bi_month_tag`，生成可重复执行的月度系数 seed 脚本。

## 参数映射

- `param_a` → `QI_COST_SERVICE_RATE`
- `param_b` → `QI_COST_ACS_REGULAR_RATE`
- `param_c` → `QI_COST_ACS_VIP_RATE`
- `param_d` → `QI_COST_VRM_RATE`
- `param_e` → `QI_COST_HK_REGULAR_RATE`、`QI_COST_HK_VIP_RATE`、`QI_REBATE_INTERCHANGE_RATE`、`QI_REBATE_INCENTIVE_RATE`
- `param_f` → `QI_COST_DCSF_RATE`

## 处理方案

基于 2026-07 QI seed 脚本新增 2026-08 版本，先软删除 2026-08 同 tag 的旧有效记录，再按固定 ID 更新或插入 9 条记录。保留既有 `provider='IQ'`、`product_line='QI'` 数据约定和 fallback 配置。

## 验证

- 脚本包含 9 个 QI 2026-08 tag。
- `statistics_time` 均为 `2026-08-01 00:00:00+08`。
- 金额与已确认的 6 个参数一致。
- `git diff --check` 通过。
