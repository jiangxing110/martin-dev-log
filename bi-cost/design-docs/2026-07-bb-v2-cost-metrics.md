# BB V2 成本指标计算逻辑

## 摘要

本文档定义 BB 渠道 v2 从 DWM 到 DWS 的成本指标口径，重点说明：

- DWS 每个指标值怎么计算。
- 每个指标依赖哪些 DWM 字段。
- DWM 为什么需要这样设计字段。
- 当前 Flink 脚本和 BI 月度 SQL 之间还存在什么差异。

参考文件：

- `bi_month/BB客户成本-202606.sql`
- `flink/quantum-v2/bb/table-scripts/dwm_bb_card_transaction_detail_v2_p.sql`
- `flink/quantum-v2/bb/table-scripts/dwm_bb_card_auth_detail_v2_p.sql`
- `flink/quantum-v2/bb/batch/dws_online_bb_card_finance_daily_v2-batch-sql.sql`

## DWS 粒度

BB DWS v2 建议粒度：

| 字段 | 说明 |
|---|---|
| `report_date` | 报表月份，统一落当月 1 号 |
| `account_id` | 账号 |
| `sale_id` | 销售 |
| `am_id` | AM |

BB 当前成本本质是月度账单口径，不适合按日拆分。尤其 `active_card_count` 必须按月去重，所以 DWS 应使用月初 1 号承载整月结果。

## DWM 设计原因

BB 拆两张 DWM 表：

- `dwm_bb_card_transaction_detail_v2_p`
- `dwm_bb_card_auth_detail_v2_p`

这样拆的原因是 BB 成本来源有两套不同事实：

- 交易和清算事实来自 `quantum_card_transaction_extend + qbitCardSettlement`。
- Decline、AC Decline、Active Card 来自 `bb_card_auth_detail_yyyy-mm` 月表。

如果强行放一张 DWM，字段会大量空值，并且月表迟到时不好独立回刷。

## 交易 DWM 字段设计

| DWM 字段 | 来源 | 为什么需要 |
|---|---|---|
| `txn_id` | `quantum_card_transaction_extend.id` | 标识原始交易，支持状态更新和硬删除对账 |
| `settlement_id` | `qbitCardSettlement.id` | 一笔交易可能有清算、退款、冲正等多条 settlement |
| `source_id` | `quantum_card_transaction_extend.source_id` | BB 多个笔数指标按 `source_id` 去重 |
| `card_transaction_id` | `quantum_card_transaction_extend.card_transaction_id` | refund/clearing 部分场景按 qbit card transaction 关联 settlement |
| `account_id` | 交易账号 | DWS 汇总维度 |
| `account_type` | `dim_account.account_type` | 下游总成本和毛利维度 |
| `account_category` | `dim_account.type` | 下游总成本和毛利维度 |
| `system_type` | `dim_account.system_type` | 下游总成本和毛利维度 |
| `card_id` | 卡 ID | 关联卡组织、排查卡维度问题 |
| `transaction_time` | 交易时间 | 笔数类指标统计时间 |
| `original_completion_time` | 三方完成时间 | Dollar Volume Fee 和 Cashback Income 统计时间 |
| `business_type` | `Consumption` / `Credit` | 区分消费、退款 |
| `business_code_list` | 业务编码列表 | 判断 Account Verification，`1010` 表示验证类交易 |
| `remarks` | 交易备注 | 兼容超时自动关单等特殊场景 |
| `detail` | 交易详情 | 排除 `AUTO CLASS CAR RENTAL` |
| `card_org` | `Master` / `VISA` | 区分 Mastercard 和 VISA 费率 |
| `tx_country` | 交易国家 | 笔数类 Domestic / International 判断 |
| `settle_country` | settlement `txnLocation` | 金额类 Domestic / International 判断 |
| `is_dom` | 是否美国地区 | Decline/Auth 类指标可复用 |
| `resp_code` | settlement responseCode | 只统计 `APPROVE` 或排除 `DECLINE` |
| `reason_code` | settlement reasonCode | reversal 需要 `APPROVE` |
| `transaction_type` | settlement transactionType | 区分 clearing、reversal、refund |
| `is_valid_settle` | 排除 advice 类 settlement | 防止无效 settlement 进入成本 |
| `is_clearing` | 是否 authorization.clearing | 金额类计算 |
| `is_reversal` | 是否 authorization.reversal | reversal fee |
| `is_refund` | 是否 refund.clearing | refund fee |
| `billing_amount` | settlement billingAmount | Dollar Volume Fee 和 Cashback Income |
| `settlement_post_date` | settlement postDate | refund fee 统计时间 |
| `settlement_txn_date` | settlement txnDate | 对账和追溯 |
| `sale_id` | 销售关系 | DWS 汇总维度 |
| `am_id` | AM 关系 | DWS 汇总维度 |
| `update_time` | 来源更新时间 | CDC 识别影响月份 |
| `delete_time` | 软删除时间 | 删除后 DWS 重算剔除 |

## Auth DWM 字段设计

| DWM 字段 | 来源 | 为什么需要 |
|---|---|---|
| `auth_txn_guid` | Auth 月表 `Auth Txn GUID` | Decline 指标去重主键 |
| `card_proxy` | Auth 月表 `Card Proxy` | Active Card 按月去重 |
| `account_id` | `qbitCard.accountId` | DWS 汇总维度 |
| `auth_time` | Auth 月表 `Trans Date / Time` | 月份归属 |
| `program_name` | Auth 月表 `Program Name` | 原 BI 用于识别卡组织，DWM 同时保留用于追溯 |
| `merchant_country` | Auth 月表 `Merchant Country` | Domestic / International 判断 |
| `request_description` | Auth 月表 `Request Description` | 区分 Account Verification 和排除 Advice |
| `response_code` | Auth 月表 `Response Code` | Decline 判断 |
| `card_org` | `qbitCard.type` | Master / VISA 费率 |
| `is_dom` | `merchant_country = 'USA'` | Domestic / International 判断 |
| `is_decline` | `response_code = 'DECLINE'` | Decline 指标 |
| `is_account_verification` | `request_description = 'Account Verification'` | AC Decline 指标 |
| `is_excluded_request` | Advice 类 request | 排除不计费请求 |
| `source_table` | 月表名 | 月表迟到和回刷追溯 |
| `sale_id` | 销售关系 | DWS 汇总维度 |
| `am_id` | AM 关系 | DWS 汇总维度 |

## DWS 指标计算

### 普通交易笔数

| DWS 字段 | BI 指标 | 过滤条件 | DWS 值 |
|---|---|---|---|
| `m_dom_auth_count` | Mastercard Domestic Transaction Count | `metric_basis = 'txn_time'`，`business_type = 'Consumption'`，`business_code_list NOT LIKE '%1010%'`，`card_org = 'Master'`，`tx_country IN ('US','USA')`，`resp_code = 'APPROVE'`，`transaction_type IN ('authorization.clearing','authorization.reversal')` | `COUNT(DISTINCT source_id)` |
| `m_int_auth_count` | Mastercard International Transaction Count | 同上，`card_org = 'Master'`，`tx_country NOT IN ('US','USA')` | `COUNT(DISTINCT source_id)` |
| `v_dom_auth_count` | VISA Domestic Transaction Count | 同上，`card_org = 'VISA'`，`tx_country IN ('US','USA')` | `COUNT(DISTINCT source_id)` |
| `v_int_auth_count` | VISA International Transaction Count | 同上，`card_org = 'VISA'`，`tx_country NOT IN ('US','USA')` | `COUNT(DISTINCT source_id)` |

费用结果建议在 DWS v2 直接记录：

| 建议 DWS 字段 | 公式 |
|---|---|
| `m_dom_auth_fee` | `m_dom_auth_count * 0.1090` |
| `m_int_auth_fee` | `m_int_auth_count * 0.4845` |
| `v_dom_auth_fee` | `v_dom_auth_count * 0.0725` |
| `v_int_auth_fee` | `v_int_auth_count * 0.4770` |

当前 Flink DWS 脚本只记录 count，没有单独记录 fee 字段。v2 表建议补齐 fee 字段。

### Account Verification 笔数

| DWS 字段 | BI 指标 | 过滤条件 | DWS 值 |
|---|---|---|---|
| `av_m_dom_count` | AC Mastercard Domestic Count | `metric_basis = 'txn_time'`，`business_type = 'Consumption'`，`business_code_list LIKE '%1010%'`，`card_org = 'Master'`，`tx_country IN ('US','USA')`，`resp_code IS NULL OR resp_code <> 'DECLINE'` | `COUNT(DISTINCT source_id)` |
| `av_m_int_count` | AC Mastercard International Count | 同上，`tx_country NOT IN ('US','USA')` | `COUNT(DISTINCT source_id)` |
| `av_v_dom_count` | AC VISA Domestic Count | 同上，`card_org = 'VISA'`，`tx_country IN ('US','USA')` | `COUNT(DISTINCT source_id)` |
| `av_v_int_count` | AC VISA International Count | 同上，`card_org = 'VISA'`，`tx_country NOT IN ('US','USA')` | `COUNT(DISTINCT source_id)` |

费用结果建议：

| 建议 DWS 字段 | 公式 |
|---|---|
| `av_m_dom_fee` | `av_m_dom_count * 0.1090` |
| `av_m_int_fee` | `av_m_int_count * 0.4845` |
| `av_v_dom_fee` | `av_v_dom_count * 0.0725` |
| `av_v_int_fee` | `av_v_int_count * 0.4770` |

### Dollar Volume

| DWS 字段 | BI 指标 | 过滤条件 | DWS 值 |
|---|---|---|---|
| `m_dom_clearing_vol` | Mastercard Domestic Net Amount | `metric_basis = 'completion_time'`，`business_type IN ('Credit','Consumption')`，`card_org = 'Master'`，`settle_country IN ('US','USA')`，`transaction_type IN ('authorization.clearing','refund.clearing')`，`resp_code = 'APPROVE'` | `SUM(-billing_amount)` |
| `m_int_clearing_vol` | Mastercard International Net Amount | 同上，`settle_country NOT IN ('US','USA')` | `SUM(-billing_amount)` |
| `v_dom_clearing_vol` | VISA Domestic Net Amount | 同上，`card_org = 'VISA'`，`settle_country IN ('US','USA')` | `SUM(-billing_amount)` |
| `v_int_clearing_vol` | VISA International Net Amount | 同上，`card_org = 'VISA'`，`settle_country NOT IN ('US','USA')` | `SUM(-billing_amount)` |

费用结果建议：

| 建议 DWS 字段 | 公式 |
|---|---|
| `m_dom_clearing_fee` | `m_dom_clearing_vol * 0.0021` |
| `m_int_clearing_fee` | `m_int_clearing_vol * 0.0111` |
| `v_dom_clearing_fee` | `v_dom_clearing_vol * 0.0016` |
| `v_int_clearing_fee` | `v_int_clearing_vol * 0.0116` |

### Reversal

| DWS 字段 | BI 指标 | 过滤条件 | DWS 值 |
|---|---|---|---|
| `m_int_reversal_count` | Mastercard International Reversal Count | `metric_basis = 'txn_time'`，`business_type = 'Consumption'`，`business_code_list NOT LIKE '%1010%'`，`card_org = 'Master'`，`tx_country NOT IN ('US','USA')`，`resp_code = 'APPROVE'`，`reason_code = 'APPROVE'`，`transaction_type = 'authorization.reversal'` | `COUNT(DISTINCT source_id)` |
| `v_int_reversal_count` | Visa International Reversal Count | 同上，`card_org = 'VISA'` | `COUNT(DISTINCT source_id)` |
| `dom_reversal_count` | Domestic Reversal Count | 同上，`tx_country IN ('US','USA')` | `COUNT(DISTINCT source_id)` |

费用结果建议：

| 建议 DWS 字段 | 公式 |
|---|---|
| `m_int_reversal_fee` | `m_int_reversal_count * 0.7190` |
| `v_int_reversal_fee` | `v_int_reversal_count * 0.7140` |
| `dom_reversal_fee` | `dom_reversal_count * 0.1780` |

### Refund

| DWS 字段 | BI 指标 | 过滤条件 | DWS 值 |
|---|---|---|---|
| `m_int_refund_count` | Mastercard International Refund Count | `metric_basis = 'post_date'`，`business_type = 'Credit'`，`card_org = 'Master'`，`settle_country NOT IN ('US','USA')`，`transaction_type = 'refund.clearing'`，`resp_code = 'APPROVE'` | `COUNT(DISTINCT source_id)` |
| `v_int_refund_count` | VISA International Refund Count | 同上，`card_org = 'VISA'` | `COUNT(DISTINCT source_id)` |
| `dom_refund_count` | Domestic Refund Count | 同上，`settle_country IN ('US','USA')` | `COUNT(DISTINCT source_id)` |

费用结果建议：

| 建议 DWS 字段 | 公式 |
|---|---|
| `m_int_refund_fee` | `m_int_refund_count * 0.4845` |
| `v_int_refund_fee` | `v_int_refund_count * 0.4770` |
| `dom_refund_fee` | `dom_refund_count * 0.1090` |

### 非验证 Decline

| DWS 字段 | BI 指标 | 过滤条件 | DWS 值 |
|---|---|---|---|
| `m_int_decline_count` | Mastercard International Decline Count Non-Verify | Auth DWM，`is_decline = TRUE`，`is_account_verification = FALSE`，`is_excluded_request = FALSE`，`card_org = 'Master'`，`is_dom = FALSE` | `COUNT(DISTINCT auth_txn_guid)` |
| `v_int_decline_count` | Visa International Decline Count Non-Verify | 同上，`card_org = 'VISA'` | `COUNT(DISTINCT auth_txn_guid)` |
| `dom_decline_count` | Domestic Decline Count Non-Verify | 同上，`is_dom = TRUE` | `COUNT(DISTINCT auth_txn_guid)` |

费用结果建议：

| 建议 DWS 字段 | 公式 |
|---|---|
| `m_int_decline_fee` | `m_int_decline_count * 0.3595` |
| `v_int_decline_fee` | `v_int_decline_count * 0.3570` |
| `dom_decline_fee` | `dom_decline_count * 0.0890` |

### 验证 AC Decline

当前 BB Auth DWM 已经保留 `is_account_verification`，但现有 DWS 表没有单独字段承接 AC Decline。v2 DWS 建议补齐。

| 建议 DWS 字段 | BI 指标 | 过滤条件 | DWS 值 |
|---|---|---|---|
| `ac_m_int_decline_count` | AC Mastercard International Decline Count Verify | Auth DWM，`is_decline = TRUE`，`is_account_verification = TRUE`，`is_excluded_request = FALSE`，`card_org = 'Master'`，`is_dom = FALSE` | `COUNT(DISTINCT auth_txn_guid)` |
| `ac_v_int_decline_count` | AC Visa International Decline Count Verify | 同上，`card_org = 'VISA'` | `COUNT(DISTINCT auth_txn_guid)` |
| `ac_dom_decline_count` | AC Domestic Decline Count Verify | 同上，`is_dom = TRUE` | `COUNT(DISTINCT auth_txn_guid)` |

费用结果建议：

| 建议 DWS 字段 | 公式 |
|---|---|
| `ac_m_int_decline_fee` | `ac_m_int_decline_count * 0.3595` |
| `ac_v_int_decline_fee` | `ac_v_int_decline_count * 0.3570` |
| `ac_dom_decline_fee` | `ac_dom_decline_count * 0.0890` |

### Active Card Account Fee

| DWS 字段 | BI 指标 | 过滤条件 | DWS 值 |
|---|---|---|---|
| `active_card_count` | Active Card Count | Auth DWM，当月所有 auth 记录 | `COUNT(DISTINCT card_proxy)` |
| `active_card_account_fee` | Active Card Account Fee | 基于 `active_card_count` | `active_card_count * 0.1` |

注意：

- `active_card_count` 必须按月去重。
- 不能按天先去重再相加。
- DWS 建议只在当月 1 号记录该值。

### BB Rebate Base 与 Cashback Income

| DWS 字段 | BI 指标 | 公式 |
|---|---|---|
| `bb_rebate_base_amt` | BB 净消费基础金额 | `SUM(-billing_amount)`，条件同 Dollar Volume clearing/refund approved |
| `bb_channel_cashback_comm` | 当前脚本中的 cashback base | 当前等于 `bb_rebate_base_amt` |
| `cashback_income` | Cashback Income | `bb_rebate_base_amt * cashback_rate` |

`cashback_rate` 当前 BI 月度 SQL 中为 `0.021195`，v2 建议从 `ods_bi_month_tag` 取月度配置。

### Volume Fee Cost

BI 中 Volume Fee Cost 是全月总净额阶梯后按客户净额占比分摊：

```sql
month_volume_fee =
CASE
  WHEN month_total_net_amount <= 5000000
    THEN month_total_net_amount * 0.0055
  WHEN month_total_net_amount <= 10000000
    THEN 5000000 * 0.0055 + (month_total_net_amount - 5000000) * 0.0045
  ELSE 5000000 * 0.0055 + 5000000 * 0.0045 + (month_total_net_amount - 10000000) * 0.004
END
```

行级分摊：

```sql
volume_fee_cost = row_total_net_amount / month_total_net_amount * month_volume_fee
```

建议 DWS v2 增加：

| 建议 DWS 字段 | 公式 |
|---|---|
| `total_net_amount` | `m_dom_clearing_vol + m_int_clearing_vol + v_dom_clearing_vol + v_int_clearing_vol` |
| `volume_fee_cost` | 按全月阶梯金额分摊 |

## 当前脚本差异

当前 `dws_online_bb_card_finance_daily_v2-batch-sql.sql` 已实现：

- 普通交易笔数 base。
- AC 笔数 base。
- Dollar Volume base。
- Reversal / Refund base。
- 非验证 Decline base。
- Active Card Count。
- 固定成本均摊。

当前还需要补齐：

- DWS sink 改为 `dws_bb_card_finance_daily_v2_p`。
- v2 DWS 表结构脚本。
- 各指标 fee amount 字段。
- AC Decline count 和 fee 字段。
- Active Card Account Fee 字段。
- Volume Fee Cost 字段。
- Cashback Income 字段。
- `cashback_rate` 从 `ods_bi_month_tag` 取值。

## 状态与一致性

BB DWS 的一致性策略：

- DWM 记录当前交易、清算、Auth 状态。
- CDC 或 batch 识别影响月份。
- DWS 删除该月份 BB v2 结果。
- 从 DWM 重新聚合插入。

必须触发重算的变化：

| 变化 | 影响 |
|---|---|
| 交易软删除 | 从所有交易类指标中剔除 |
| settlement 到达或变化 | clearing/reversal/refund/count/volume 变化 |
| `original_completion_time` 变化 | Dollar Volume 和 Cashback 月份变化 |
| `settlement_post_date` 变化 | Refund 月份变化 |
| Auth 月表迟到 | Decline 和 Active Card 变化 |
| 销售关系历史变更 | `sale_id`、`am_id` 归属变化 |

硬删除需要通过 ODS/DWM 主键对账发现，然后将对应月份加入回刷范围。
