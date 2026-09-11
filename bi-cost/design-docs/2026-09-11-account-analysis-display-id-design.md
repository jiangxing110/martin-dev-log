# 客户分析维表补充 display_id 设计

## 摘要

为 `dim.dim_account_analysis` 补充账户展示 ID，并增加 OpenAPI 属性补偿回填，解决账户记录先生成、OpenAPI 配置后生成时目标维表不更新的问题。

## 范围

- 目标表新增 `display_id`，来源为 `public.account."displayId"`。
- CDC 作业读取并同步该字段。
- batch 作业读取并回刷该字段。
- 提供目标表结构迁移 SQL。
- 提供 OpenAPI 属性幂等回填 SQL，补偿 CDC 未捕获或历史遗漏。
- 仅修改 `flink/account_analysis` 下的同步链路，不修改 `online/` 下的副本。

## 数据流

`public.account."displayId"` → CDC/batch account source → `v_dim_account_analysis.display_id` → `dim.dim_account_analysis.display_id`

`public.caas_open_api_extend` → CDC 实时关联 → `dim.dim_account_analysis`；同时由回填 SQL 定期校正 `business_mode`、`access_type`、`mor_type` 和 `mor_type_extra`。

## 验收标准

1. 目标表 DDL 和迁移脚本包含 `display_id`。
2. CDC 与 batch 的 source、view、sink 字段顺序一致。
3. 所有账户分析同步脚本均使用 `a."displayId"` 或其等价字段映射。
