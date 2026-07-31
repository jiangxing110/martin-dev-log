# BB Auth 2026-02 月表字段兼容方案

## 摘要

2026-02 的 `public."bb_card_auth_detail_2026-02"` 月表只有 BB Auth 成本计算必需字段，不包含 2026-01 月表里的 `"Merchant Name"`、`"MCC"` 等扩展字段。

本次调整批处理和 CDC DWM 导入链路，避免 JDBC source 访问 2026-02 不存在的列。成本计算继续依赖已有字段完成，DWM 目标表结构保持不变，缺失的 `merchant_name`、`mcc` 写入 `NULL`。

## 问题

作业启动时报错：

```text
ERROR: column "Merchant Name" does not exist
```

原因是 `flink/quantum-v2/bb/batch/dwm_online_bb_card_auth_detail_v2-batch-sql.sql` 的 PostgreSQL 子查询，以及 CDC 使用的 `public.fn_bb_card_auth_detail_by_window` 函数固定读取 `"Merchant Name"` 和 `"MCC"`，但 2026-02 月表实际不存在这些列。

## 2026-02 必需字段

2026-02 月表保留了当前 Auth DWM/DWS 计算需要的核心字段：

| 字段 | 用途 |
|---|---|
| `"Trans Date / Time"` | Auth 时间和回刷窗口过滤 |
| `"Program GUID"` | 追溯字段 |
| `"Program Name"` | 追溯字段 |
| `"Card Proxy"` | 关联卡和 Active Card 去重 |
| `"Person Name"` | 追溯字段 |
| `"Request Code"` | 请求代码 |
| `"Request Description"` | Account Verification / Advice 排除 |
| `"Local Trans Date / Time"` | 追溯字段 |
| `"Auth Txn GUID"` | Decline 去重 |
| `"Response Code"` | Decline 判断 |
| `"Reason Code"` | 原因码 |
| `"Txn Amount"` | 金额追溯 |
| `"Settle Amount"` | 金额追溯 |
| `"Txn Currency"` | 币种 |
| `"Merchant Country"` | Domestic / International 判断 |
| `"Transmission Date"` | 追溯字段 |

## 方案

- JDBC 子查询只读取 2026-02 确认存在的字段。
- `merchant_name` 使用 `CAST(NULL AS varchar)` 输出。
- `mcc` 使用 `CAST(NULL AS varchar)` 输出。
- CDC 使用的 `fn_bb_card_auth_detail_by_window` 保持返回结构不变，但扩展字段统一返回 `NULL`。
- 保持 `dwm.dwm_bb_card_auth_detail_v2_p` 表结构和下游 DWS 读取逻辑不变。

## 影响

- 2026-02 回刷不再因缺失 `"Merchant Name"` 或 `"MCC"` 失败。
- `merchant_name`、`mcc` 在本批处理脚本产出的记录中为空。
- Decline、AC Decline、Active Card 等现有成本指标不依赖 `merchant_name` 或 `mcc`，计算口径不变。
