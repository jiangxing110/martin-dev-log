# GLOBAL_ACCOUNT BZ 按客户数分摊方案

## 摘要

将 GLOBAL_ACCOUNT / BZ 金融渠道成本改为按 `bi_month_tag` 的月度金额，平均分摊给当月已创建且仍为 Active 的 ZB 客户。分母是去重后的客户 `accountId` 数量，不是子账户数量，也不再使用支付流水金额作为分摊基础。

## 业务规则

- 成本金额来源：`bi_month_tag.amount`。
- 过滤条件：`product_line = 'GLOBAL_ACCOUNT'`、`provider = 'BZ'`、统计月份为目标结算月。
- 分摊客户范围：`globalSubAccount` 中 `provider = 'ZB'`、`status = 'Active'`、未删除，且 `createTime` 早于下月第一天。
- 分母：`COUNT(DISTINCT "accountId")`。
- 单个客户成本：

  `BZ 月度成本金额 / Active ZB 客户数`

- 同一客户拥有多个 Active ZB 子账户时仍只占一份客户配额；子账户数量只用于判断客户是否进入分摊范围。
- CL、OFFLINE 和其他渠道不受本次规则影响。

## 实现范围

- 批处理：`online/batch/total_cost/finance/global_account/dwm_online_global_account_bz_cost-batch-sql.sql`
- CDC v2：`online/cdc/total_cost/finance/global_account/dwm_online_global_account_bz_cost-cdc-v2-sql.sql`
- CDC：`online/cdc/total_cost/finance/global_account/dwm_online_global_account_bz_cost-cdc-sql.sql`

## 验证口径

对任意月份 `M`：

1. `bi_month_tag` BZ 金额总和应等于该月所有 BZ 客户成本之和。
2. 目标客户只要存在一个或多个符合条件的 Active ZB 子账户，就获得一份 `amount / customer_count`。
3. 没有符合条件 Active ZB 子账户的客户不产生 BZ 分摊成本。
