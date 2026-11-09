# 2026-10 BB / QI 指定客户成本比对查询方案

## 摘要

新增一条可直接在 ADBPG 执行的只读 SQL，按用户给出的 9 个客户 ID、2026-10 日期范围，分别计算 BB/QI DWS 渠道成本，按 API 主户归集子户，并与销售毛利附件中的渠道成本分项对比。

## 比较口径

- 查询范围固定为 `2026-10-01` 至 `2026-11-01`，左闭右开。
- BB DWS 渠道成本沿用 v2 查询的授权、清算、拒付、退款、活跃卡、Volume Fee 和固定成本公式；渠道返现收入单独列示。
- QI DWS 渠道成本沿用 v2 查询的 base × rate 与渠道固定成本公式；Interchange / Incentive 返现单独列示。
- API 主户/子户通过 `public.api_account_relation` 的 `root_id` 归集。
- 附件渠道成本分项作为 Excel 对比值，不把含客户返现/银行手续费的 `Pref_Cost` 混入渠道成本差额。
- 最终输出：渠道、客户名称、客户 ID、DWS 单渠道总成本、Excel 渠道成本、差值（DWS - Excel）。

## 文件

- `online/check/v2/查询_2026-10_BB_QI客户成本比对.sql`

## 限制

数据库执行由用户在 ADBPG 完成。若 DWS 无匹配数据，DWS 成本和差值将为 NULL，避免将缺数误认为零成本。
