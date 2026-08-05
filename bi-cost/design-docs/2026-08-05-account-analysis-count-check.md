# Account Analysis 数量核对方案

## 摘要

为 `dim_online_account_analysis-cdc-sql.sql` 提供源表与目标表的数量核对脚本。
源库和目标库分别执行查询，按 CDC 实际账户类型口径比较总量、分类数量、
逻辑删除数量和更新时间水位。

## 核对口径

- 源表：`public.account`
- 目标表：`dim.dim_account_analysis`
- 账户类型：`ApiClient`、`MasterAccount`、`Merchant`、`TestAccount`
- 源端保留 `deleteTime` 非空记录，与 CDC 逻辑一致
- 不进行跨数据库 JOIN

