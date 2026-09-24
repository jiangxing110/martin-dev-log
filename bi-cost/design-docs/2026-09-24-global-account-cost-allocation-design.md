# 全球账户成本按客户级分摊方案

## 摘要

修复销售佣金物化视图中 `group_account` 成本为 0 的问题。全球账户收入通常没有 `provider`，而底层成本按 BZ、CL、OFFLINE 等渠道记录；成本不能按渠道与收入匹配，应先按客户和结算月汇总后作为未分渠道成本分摊。

## 处理方案

- `group_account` 的 BZ、CL 渠道成本统一输出 `provider = NULL`。
- `group_account` 的结汇成本、线下 `fee_cost` 统一输出 `provider = NULL`。
- 这样成本进入现有 `unscoped_cogs` 分摊逻辑，按同一客户、结算月的全球账户收入分摊。
- `qbit_card`、`crypto`、`open_api` 继续保留原有 provider 级匹配逻辑。

## 验证口径

2026-08 全球账户成本应包含 BZ、CL、OFFLINE 三类来源；视图刷新后，`group_account` 的成本不应再因为收入 `provider` 为空而丢失。
