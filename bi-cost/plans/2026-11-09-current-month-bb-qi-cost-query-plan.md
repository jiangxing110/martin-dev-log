# 当前月 BB / QI 成本查询执行计划

- [x] 核对现有 BB、QI v2 DWS 字段和成本公式。
- [x] 新增 BB 当前月成本及 cashback 汇总 SQL。
- [x] 新增 QI 当前月成本、固定成本及返现汇总 SQL。
- [x] 将两条查询以中文文件名分别放在 `online/check/v2/`。
- [x] 加入 `public.api_account_relation` 归并逻辑，将子户纳入 API 主户，并保留普通账户自身汇总。
- [x] 静态核对日期范围、特殊固定成本行和返现字段。

## 运行说明

在两个 SQL 的 `params` CTE 中分别填写 `account_id`、`start_date`、`end_date` 后，在 ADBPG 执行。日期范围左闭右开。传入 API 主户或子户时，主户及有效子户合并统计。
