# 当前月 BB / QI 成本查询方案

## 摘要

新增两条独立 PostgreSQL 查询，分别按传入的 `account_id`、`start_date`、`end_date` 查询 BB 与 QI 渠道成本，并单独展示渠道返现。结果按 API 主户归集：传入 API 主户或子户 ID 时，API 主户本身及映射到该主户的子户会合并；非 API 账户仍按自身 account_id 展示。

## 口径

- 参数放在各 SQL 的 `params` CTE：`account_id`、`start_date`、`end_date`。日期采用左闭右开，示例为 2026-05 整月。
- BB 成本包含交易/清算费用、Active Card、Volume Fee 和固定成本；BB cashback 另列，不从成本中扣减。
- QI 成本按各 base × DWS 月度 rate 汇总，固定费用只取 `special_fee_type = 'CHANNEL_FIXED_FEE'`；Interchange / Incentive 返现另列，并使用 DWS 保存的 rate。
- 两个脚本分别查询 BB、QI，均输出输入账号、归集后的 `report_account_id`、纳入账户数、数据日期范围和金额。

## 文件

- `online/check/v2/查询_BB当月成本.sql`
- `online/check/v2/查询_QI当月成本.sql`
