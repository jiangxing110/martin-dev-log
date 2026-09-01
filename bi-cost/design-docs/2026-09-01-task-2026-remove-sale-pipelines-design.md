# task_2026 销售中间层移除与维表直连方案

## 摘要

保留销售/AM 维度统计输出，移除旧的 `ods_sale_am_transaction` 中间层。销售统计直接读取 `dim.dim_sale_account_relation_p`，按照交易发生时间匹配有效关系，并将不同的 `sale_id`、`am_id` 展开为两条维度记录。

## 范围

仅移除 `ods_sale_am_transaction` 对应的 CDC、batch、DDL 和删除函数脚本。以下销售统计输出继续保留：

- `dws_sale_*`
- `ods_sale_fund_profits`
- `ods_sale_qbit_card`

## 方案

1. 从 `gen_all_jobs.py` 删除 `ods_sale_am_transaction` 的 ODS 配置，但保留 `SALE_SET` 销售输出配置。
2. 销售输出统一直接读取 `dim.dim_sale_account_relation_p`。
3. 优先匹配账户自身关系，匹配不到时通过 `api_account_relation.root_id` 匹配根账户关系。
4. 使用交易时间匹配关系有效期，并选取最新关系。
5. 使用 `UNION` 展开 `sale_id`、`am_id`：两者不同生成两条，相同只生成一条，空值不生成。
6. 不删除线上已有销售表，不修改其他目录中的历史销售任务。

## 验证

- `ods_sale_am_transaction` 不再被 task_2026 销售任务引用。
- 销售输出文件和 `SALE_SET` 仍然存在。
- 销售 SQL 包含维表关系匹配和 sale/am 去重展开逻辑。
- `python3 -m py_compile task_2026/flink_reference/gen_all_jobs.py` 通过。
- `git diff --check` 通过。
