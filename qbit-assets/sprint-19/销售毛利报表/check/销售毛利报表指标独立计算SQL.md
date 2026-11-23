# 销售毛利报表指标源表计算 SQL

## 文档目的

本文按业务源表说明指标取数与计算逻辑，并保留 `provider` 分组和筛选。实现依据为 [销售毛利估算物化视图 SQL](../sql/table-scripts/mv_sales_gross_profit_recent_estimate.sql) 中的 `recent_sales_metric`、`raw_cost_rows`、`sales_rows`、`api_actual_received_rows`、`monthly_revenue_rows`、`qbit_card_channel_rebate_rows`、`bi_month_adjustment_rows` 和 `calculated` CTE。

每条源表 SQL 保留 `sale_id + root_account_id + product + provider` 维度，并筛选示例客户 `95d362d7-56fe-4f50-82cb-f97a51afc263`、销售 `cfd8b2a8-af2d-474a-9923-3a5ef0335f52`。查询渠道时使用 `provider = 'IQ'` 等条件；查询 NULL 渠道时使用 `provider IS NULL`。日期按左闭右开过滤，以下日期示例是 2026-09。

> 部分指标由多个来源行相加；来源行应先按同一维度归集，再按下方公式计算。不要把月表 `qbit_card/main` 当作额外收入叠加：已核对它与日表 main 扣返现后的金额相符。

## 1. Revenue / Pref_Rev（应收收入：实时收入 + 本月月账单应收）

### 来源口径

`Pref_Rev` 由以下收入构成：

1. `dws_sales_metric_daily` 的 `main/income` 实时收入。
2. `dws_metrics_sales_revenue_monthly` 的 `open_api/month_receivable` 表示 Open API 月账单应收，按结算月首日计入 `Pref_Rev`。
3. 月度汇总表的 `bi_month_tag/offline_api_income_amount` 按结算月首日计入收入；API 月账单实收另见独立 SQL。
4. BB、IQ、BZ 量子卡渠道返现收入，按视图公式计入收入。
5. `ods_bi_month_tag` 收入调整：增加为正，减少为负。

### 日指标来源 SQL：实时收入

```sql
SELECT
    m.report_date::date AS report_date,
    m.root_account_id::varchar AS root_account_id,
    CASE
      WHEN m.product = 'crypto_connect' THEN 'crypto'
      WHEN m.product = 'global_account' THEN 'group_account'
      ELSE m.product
    END AS product,
    NULLIF(TRIM(m.provider), '') AS provider,
    m.sale_id::varchar AS sale_id,
    SUM(m.metric_value) AS real_time_revenue
FROM dws.dws_sales_metric_daily m
WHERE m.delete_time IS NULL
  AND m.report_date >= DATE '2026-09-01'
  AND m.report_date <  DATE '2026-10-01'
  AND m.metric_code = 'main'
  AND m.metric_type = 'income'
  AND m.root_account_id::varchar = '95d362d7-56fe-4f6a-bfab-a44b7cb94be5'
  AND m.sale_id::varchar = 'cfd8b2a8-af2d-474a-9923-3a5ef0335f52'
  -- 渠道过滤示例：AND NULLIF(TRIM(m.provider), '') = 'IQ'
GROUP BY
    m.report_date::date,
    m.root_account_id,
    CASE
      WHEN m.product = 'crypto_connect' THEN 'crypto'
      WHEN m.product = 'global_account' THEN 'group_account'
      ELSE m.product
    END,
    NULLIF(TRIM(m.provider), ''),
    m.sale_id;
```

### Open API 月账单应收 SQL：month_receivable

`month_receivable` 表示 Open API 月账单应收，计入 `Pref_Rev`，不表示实收。按你提供的数据，该指标从 `dws_metrics_sales_revenue_monthly` 读取；来源只有结算月，因此归属结算月首日。

```sql
SELECT
    r.settlement_month::date AS report_date,
    r.root_account_id::varchar AS root_account_id,
    r.product,
    NULLIF(TRIM(r.provider), '') AS provider,
    r.sale_id::varchar AS sale_id,
    SUM(COALESCE(r.income_value, 0)) AS api_month_receivable
FROM dws.dws_metrics_sales_revenue_monthly r
WHERE r.delete_time IS NULL
  AND r.product = 'open_api'
  AND r.metric_code = 'month_receivable'
  AND r.settlement_month >= DATE '2026-09-01'
  AND r.settlement_month <  DATE '2026-10-01'
  AND r.root_account_id::varchar = '95d362d7-56fe-4f6a-bfab-a44b7cb94be5'
  AND r.sale_id::varchar = 'cfd8b2a8-af2d-474a-9923-3a5ef0335f52'
  -- 渠道过滤示例：AND NULLIF(TRIM(r.provider), '') = 'IQ'
GROUP BY r.settlement_month, r.root_account_id, r.product,
         NULLIF(TRIM(r.provider), ''), r.sale_id;
```

### 月度汇总表来源 SQL：BI 离线 API 收入

```sql
SELECT
    r.settlement_month::date AS report_date,
    r.root_account_id::varchar AS root_account_id,
    'open_api'::varchar AS product,
    NULLIF(TRIM(r.provider), '') AS provider,
    r.sale_id::varchar AS sale_id,
    SUM(COALESCE(r.income_value, 0)) AS offline_api_income_amount
FROM dws.dws_metrics_sales_revenue_monthly r
WHERE r.delete_time IS NULL
  AND r.product = 'bi_month_tag'
  AND r.metric_code = 'offline_api_income_amount'
  AND r.settlement_month >= DATE '2026-09-01'
  AND r.settlement_month <  DATE '2026-10-01'
  AND r.root_account_id::varchar = '95d362d7-56fe-4f6a-bfab-a44b7cb94be5'
  AND r.sale_id::varchar = 'cfd8b2a8-af2d-474a-9923-3a5ef0335f52'
  -- 渠道筛选示例：AND NULLIF(TRIM(r.provider), '') = 'IQ'
GROUP BY r.settlement_month, r.root_account_id,
         NULLIF(TRIM(r.provider), ''), r.sale_id;
```

### 量子卡渠道返现收入 SQL

```sql
SELECT
    source.report_date,
    source.root_account_id,
    source.product,
    source.provider,
    source.sale_id,
    SUM(source.channel_rebate) AS pref_rev_source
FROM (
    SELECT
        b.report_date::date AS report_date,
        COALESCE(aar.root_id, b.account_id)::varchar AS root_account_id,
        'qbit_card'::varchar AS product,
        'BB'::varchar AS provider,
        b.sale_id::varchar AS sale_id,
        SUM(COALESCE(b.cashback_income, 0)) AS channel_rebate
    FROM dws.dws_bb_card_finance_daily_v2_p b
    LEFT JOIN public.api_account_relation aar
      ON aar.account_id = b.account_id::varchar AND aar.delete_time IS NULL
    WHERE b.delete_time IS NULL
      AND b.report_date >= DATE '2026-09-01'
      AND b.report_date <  DATE '2026-10-01'
    GROUP BY b.report_date::date, COALESCE(aar.root_id, b.account_id), b.sale_id

    UNION ALL

    SELECT
        q.report_date::date,
        COALESCE(aar.root_id, q.account_id)::varchar,
        'qbit_card'::varchar,
        'IQ'::varchar,
        q.sale_id::varchar,
        SUM(COALESCE(q.rebate_interchange_base_amt, 0)
          + COALESCE(q.rebate_incentive_base_amt, 0) * COALESCE(q.rebate_incentive_rate, 0))
    FROM dws.dws_qi_card_finance_daily_v2_p q
    LEFT JOIN public.api_account_relation aar
      ON aar.account_id = q.account_id::varchar AND aar.delete_time IS NULL
    WHERE q.delete_time IS NULL
      AND q.report_date >= DATE '2026-09-01'
      AND q.report_date <  DATE '2026-10-01'
    GROUP BY q.report_date::date, COALESCE(aar.root_id, q.account_id), q.sale_id

    UNION ALL

    SELECT
        z.report_date::date,
        COALESCE(aar.root_id, z.account_id)::varchar,
        'qbit_card'::varchar,
        'BZ'::varchar,
        z.sale_id::varchar,
        SUM(COALESCE(z.clearing_base_amt, 0) * COALESCE(z.reimbursement_rate, 0))
    FROM dws.dws_bz_card_finance_daily_v2_p z
    LEFT JOIN public.api_account_relation aar
      ON aar.account_id = z.account_id::varchar AND aar.delete_time IS NULL
    WHERE z.delete_time IS NULL
      AND z.report_date >= DATE '2026-09-01'
      AND z.report_date <  DATE '2026-10-01'
    GROUP BY z.report_date::date, COALESCE(aar.root_id, z.account_id), z.sale_id
) source
WHERE source.root_account_id = '95d362d7-56fe-4f50-82cb-f97a51afc263'
  AND source.sale_id = 'cfd8b2a8-af2d-474a-9923-3a5ef0335f52'
  -- provider过滤示例：AND source.provider = 'BB'
GROUP BY source.report_date, source.root_account_id,
         source.product, source.provider, source.sale_id;
```

### BI 月度收入调整 SQL

```sql
WITH account_root_relation AS (
    SELECT account_id::varchar AS account_id, root_id::varchar AS root_id
    FROM public.api_account_relation
    WHERE delete_time IS NULL
)
SELECT
    date_trunc('month', t.statistics_time AT TIME ZONE 'Asia/Shanghai')::date AS report_date,
    COALESCE(aar.root_id, t.account_id)::varchar AS root_account_id,
    CASE t.product_line
      WHEN 'GLOBAL_ACCOUNT' THEN 'group_account'
      WHEN 'QUANTUM_CARD' THEN 'qbit_card'
      WHEN 'CRYPTO_ASSET' THEN 'crypto'
    END AS product,
    NULLIF(TRIM(t.provider), '') AS provider,
    sale_owner.sale_id::varchar AS sale_id,
    t.tag AS metric_code,
    SUM(CASE
      WHEN t.tag IN ('OFFLINE_PHYSICAL_CARD_FEE', 'INCOME_ADJUSTMENT_INCREASE')
        THEN COALESCE(t.amount, 0)
      WHEN t.tag IN ('INCOME_ADJUSTMENT_DECREASE', 'API_MINIMUM_CONSUMPTION_ADJUSTMENT_DECREASE')
        THEN -COALESCE(t.amount, 0)
      ELSE 0
    END) AS income_adjustment
FROM ods.ods_bi_month_tag t
LEFT JOIN account_root_relation aar ON aar.account_id = t.account_id::varchar
LEFT JOIN LATERAL (
    SELECT sr.sale_id
    FROM dim.dim_sale_account_relation_p sr
    WHERE sr.relation_account_id = COALESCE(aar.root_id, t.account_id)
      AND sr.delete_time IS NULL
      AND sr.relation_start_time <= t.statistics_time
    ORDER BY
      CASE WHEN sr.relation_end_time IS NULL OR t.statistics_time < sr.relation_end_time THEN 0 ELSE 1 END,
      sr.relation_start_time DESC, sr.id DESC
    LIMIT 1
) sale_owner ON TRUE
WHERE t.delete_time IS NULL
  AND t.account_id IS NOT NULL
  AND t.tag IN ('OFFLINE_PHYSICAL_CARD_FEE', 'INCOME_ADJUSTMENT_INCREASE',
                'INCOME_ADJUSTMENT_DECREASE', 'API_MINIMUM_CONSUMPTION_ADJUSTMENT_DECREASE')
  AND date_trunc('month', t.statistics_time AT TIME ZONE 'Asia/Shanghai')::date >= DATE '2026-09-01'
  AND date_trunc('month', t.statistics_time AT TIME ZONE 'Asia/Shanghai')::date <  DATE '2026-10-01'
  AND COALESCE(aar.root_id, t.account_id)::varchar = '95d362d7-56fe-4f50-82cb-f97a51afc263'
  AND sale_owner.sale_id::varchar = 'cfd8b2a8-af2d-474a-9923-3a5ef0335f52'
  -- 渠道过滤示例：AND NULLIF(TRIM(t.provider), '') = 'IQ'
GROUP BY 1, 2, 3, 4, 5, 6;
```

`Pref_Rev` 是以上来源的 `real_time_revenue + Open API month_receivable + offline_api_income_amount + channel_rebate + income_adjustment` 之和。Open API 的 `month_receivable` 是应收，不是实收；月度汇总源按结算月首日计入日期筛选。

Open API 月账单实收不计入 `Pref_Rev`。整体实收 `Cashflow_Rev` 直接取 `api_client_bill_actual_received_amount`；销售维度实收 `Cashflow_Rev_sale` 从该指标中扣除月结 KYC、实体卡手续费和最低承诺三项。该实际实收指标不区分 provider。

## API 月账单实收 / API Actual Received（独立 SQL）

### Cashflow_Rev 整体实收（保留原值，不扣月结费用）

Open API 实收直接取 `api_client_bill_actual_received_amount`，按客户、日期和销售归集，不区分 provider。该金额进入 `Cashflow_Rev`，不进入 `Pref_Rev`。

```sql
SELECT
    m.report_date::date AS report_date,
    m.root_account_id::varchar AS root_account_id,
    m.product,
    m.sale_id::varchar AS sale_id,
    SUM(COALESCE(m.metric_value, 0)) AS api_actual_received_amount
FROM dws.dws_sales_metric_daily m
WHERE m.delete_time IS NULL
  AND m.product = 'open_api'
  AND m.metric_type = 'income'
  AND m.metric_code = 'api_client_bill_actual_received_amount'
  AND m.report_date >= DATE '2026-09-01'
  AND m.report_date <  DATE '2026-10-01'
  AND m.root_account_id::varchar = '95d362d7-56fe-4f6a-bfab-a44b7cb94be5'
  AND m.sale_id::varchar = 'cfd8b2a8-af2d-474a-9923-3a5ef0335f52'
GROUP BY m.report_date::date, m.root_account_id, m.product, m.sale_id;
```

### Cashflow_Rev_sale 销售维度实收（扣除三项月结费用）



单独核算销售维度的 Open API 月账单实收：`api_client_bill_actual_received_amount` 减去 `api_client_bill_monthly_kyc_fee_received_amount`、`api_client_bill_physical_card_fee_received_amount`、`api_client_bill_minimum_commitment_received_amount`，按来源 `report_date`、根账户和销售汇总，不区分 provider。该值只作为实收收入，不计入 `Pref_Rev`；第 10 节的 `Cashflow_Rev_sale` 会包含此净额。

```sql
SELECT
    m.report_date::date AS report_date,
    m.root_account_id::varchar AS root_account_id,
    m.product,
    m.sale_id::varchar AS sale_id,
    SUM(CASE
        WHEN m.metric_code = 'api_client_bill_actual_received_amount'
            THEN COALESCE(m.metric_value, 0)
        ELSE -COALESCE(m.metric_value, 0)
    END) AS api_actual_received_amount
FROM dws.dws_sales_metric_daily m
WHERE m.delete_time IS NULL
  AND m.product = 'open_api'
  AND m.metric_type = 'income'
  AND m.metric_code IN (
      'api_client_bill_actual_received_amount',
      'api_client_bill_monthly_kyc_fee_received_amount',
      'api_client_bill_physical_card_fee_received_amount',
      'api_client_bill_minimum_commitment_received_amount'
  )
  AND m.report_date >= DATE '2026-09-01'
  AND m.report_date <  DATE '2026-10-01'
  AND m.root_account_id::varchar = '95d362d7-56fe-4f6a-bfab-a44b7cb94be5'
  AND m.sale_id::varchar = 'cfd8b2a8-af2d-474a-9923-3a5ef0335f52'
GROUP BY
    m.report_date::date,
    m.root_account_id,
    m.product,
    m.sale_id;
```

## 2. Client Rebate（客户返现）

来源是日指标 `client_rebate/cost`，加上 BI 月度返现调整；返现调整增加为正、减少为负。QI/BZ RS 毛利返现已清洗并并入日指标 `client_rebate`，不从 `cash_back_bonuses` 再读一次。

```sql
WITH account_root_relation AS (
    SELECT account_id::varchar AS account_id, root_id::varchar AS root_id
    FROM public.api_account_relation
    WHERE delete_time IS NULL
), rebate_sources AS (
    SELECT
        m.report_date::date AS report_date,
        m.root_account_id::varchar AS root_account_id,
        CASE WHEN m.product = 'crypto_connect' THEN 'crypto'
             WHEN m.product = 'global_account' THEN 'group_account'
             ELSE m.product END AS product,
        NULLIF(TRIM(m.provider), '') AS provider,
        m.sale_id::varchar AS sale_id,
        SUM(m.metric_value) AS client_rebate
    FROM dws.dws_sales_metric_daily m
    WHERE m.delete_time IS NULL
      AND m.report_date >= DATE '2026-09-01'
      AND m.report_date <  DATE '2026-10-01'
      AND m.metric_code = 'client_rebate'
      AND m.metric_type = 'cost'
      AND m.root_account_id::varchar = '95d362d7-56fe-4f50-82cb-f97a51afc263'
      AND m.sale_id::varchar = 'cfd8b2a8-af2d-474a-9923-3a5ef0335f52'
    GROUP BY m.report_date::date, m.root_account_id,
             CASE WHEN m.product = 'crypto_connect' THEN 'crypto'
                  WHEN m.product = 'global_account' THEN 'group_account'
                  ELSE m.product END,
             NULLIF(TRIM(m.provider), ''), m.sale_id

    UNION ALL

    SELECT
        date_trunc('month', t.statistics_time AT TIME ZONE 'Asia/Shanghai')::date,
        COALESCE(aar.root_id, t.account_id)::varchar,
        CASE t.product_line WHEN 'GLOBAL_ACCOUNT' THEN 'group_account'
             WHEN 'QUANTUM_CARD' THEN 'qbit_card' WHEN 'CRYPTO_ASSET' THEN 'crypto' END,
        NULLIF(TRIM(t.provider), ''),
        sale_owner.sale_id::varchar,
        SUM(CASE WHEN t.tag = 'CASHBACK_ADJUSTMENT_INCREASE' THEN COALESCE(t.amount, 0)
                 WHEN t.tag = 'CASHBACK_ADJUSTMENT_DECREASE' THEN -COALESCE(t.amount, 0)
                 ELSE 0 END)
    FROM ods.ods_bi_month_tag t
    LEFT JOIN account_root_relation aar ON aar.account_id = t.account_id::varchar
    LEFT JOIN LATERAL (
        SELECT sr.sale_id
        FROM dim.dim_sale_account_relation_p sr
        WHERE sr.relation_account_id = COALESCE(aar.root_id, t.account_id)
          AND sr.delete_time IS NULL
          AND sr.relation_start_time <= t.statistics_time
        ORDER BY CASE WHEN sr.relation_end_time IS NULL OR t.statistics_time < sr.relation_end_time THEN 0 ELSE 1 END,
                 sr.relation_start_time DESC, sr.id DESC
        LIMIT 1
    ) sale_owner ON TRUE
    WHERE t.delete_time IS NULL
      AND t.account_id IS NOT NULL
      AND t.tag IN ('CASHBACK_ADJUSTMENT_INCREASE', 'CASHBACK_ADJUSTMENT_DECREASE')
      AND COALESCE(aar.root_id, t.account_id)::varchar = '95d362d7-56fe-4f50-82cb-f97a51afc263'
      AND sale_owner.sale_id::varchar = 'cfd8b2a8-af2d-474a-9923-3a5ef0335f52'
      AND date_trunc('month', t.statistics_time AT TIME ZONE 'Asia/Shanghai')::date >= DATE '2026-09-01'
      AND date_trunc('month', t.statistics_time AT TIME ZONE 'Asia/Shanghai')::date <  DATE '2026-10-01'
    GROUP BY 1, 2, 3, 4, 5
)
SELECT root_account_id, product, provider, sale_id, SUM(client_rebate) AS client_rebate
FROM rebate_sources
WHERE sale_id IS NOT NULL
  -- 渠道过滤示例：AND provider = 'IQ'
GROUP BY root_account_id, product, provider, sale_id;
```

## 3. Collection Rebate（代收返现）

来源仅为日指标 `client_collection_rebate/cost`；按 `root_account_id + product + provider + sale_id + report_date` 归集。

```sql
SELECT
    m.root_account_id::varchar AS root_account_id,
    CASE WHEN m.product = 'crypto_connect' THEN 'crypto'
         WHEN m.product = 'global_account' THEN 'group_account'
         ELSE m.product END AS product,
    NULLIF(TRIM(m.provider), '') AS provider,
    m.sale_id::varchar AS sale_id,
    SUM(m.metric_value) AS client_collection_rebate
FROM dws.dws_sales_metric_daily m
WHERE m.delete_time IS NULL
  AND m.report_date >= DATE '2026-09-01'
  AND m.report_date <  DATE '2026-10-01'
  AND m.metric_code = 'client_collection_rebate'
  AND m.metric_type = 'cost'
  AND m.root_account_id::varchar = '95d362d7-56fe-4f50-82cb-f97a51afc263'
  AND m.sale_id::varchar = 'cfd8b2a8-af2d-474a-9923-3a5ef0335f52'
  -- 渠道过滤示例：AND NULLIF(TRIM(m.provider), '') = 'IQ'
GROUP BY m.root_account_id,
         CASE WHEN m.product = 'crypto_connect' THEN 'crypto'
              WHEN m.product = 'global_account' THEN 'group_account'
              ELSE m.product END,
         NULLIF(TRIM(m.provider), ''), m.sale_id;
```

## 4. Gross Profit Rebate（毛利返现；当前已并入客户返现来源）

目前视图将此字段置为 0；QI/BZ RS 毛利返现已由上游清洗进 `dws_sales_metric_daily.client_rebate`。不要重复读取返现奖金表。

```sql
SELECT
    0::numeric(20,4) AS gross_profit_rebate;
```

## 5. Rebate（总返现：客户返现 + 代收返现 + 毛利返现）

```sql
SELECT
    (COALESCE(client_rebate, 0)
     + COALESCE(client_collection_rebate, 0)
     + COALESCE(gross_profit_rebate, 0))::numeric(20,4) AS rebate;
```

对应物化视图公式：`client_rebate + client_collection_rebate + gross_profit_rebate`。其中客户返现包含 BI cashback 调整；正负号原样保留。

## 6. Effective Revenue / Pref_Rev_effective（应收有效收入：应收收入 - 总返现）

```sql
SELECT
    (COALESCE(pref_rev, 0) - COALESCE(client_rebate, 0)
     - COALESCE(client_collection_rebate, 0)
     - COALESCE(gross_profit_rebate, 0))::numeric(20,4) AS pref_rev_effective;
```

`pref_rev` 按第 1 节源表求和；返现按第 2–5 节来源计算。

## 7. Cost（总成本）

成本来源及 provider 归属均沿用估算视图 `raw_cost_rows -> mapped_cost_rows -> cost_by_sale_dimension`：

| 源表 | 产品/provider 映射 | 成本计算 |
|---|---|---|
| `dwm.dwm_finance_channel_cost_p` | GLOBAL_ACCOUNT 映射 `group_account`；QUANTUM_CARD 映射 `qbit_card`；BPC 映射 IQ | 直接 `SUM(cost_amount)`；该表已按客户/日期分摊 |
| `dws.dws_bb_card_finance_daily_v2_p` | `qbit_card / BB` | 日交易笔数、清算量、退款、拒付、卡量等乘费率后，加 `volume_fee_cost` 和 `cost_fixed_fee` |
| `dws.dws_qi_card_finance_daily_v2_p` | `qbit_card / IQ` | 各 `*_base_amt * *_rate` 加 `cost_fixed_fee` |
| `dws.dws_sl_card_finance_daily_p` | `qbit_card / SL` | `SUM(cost_fixed_fee)` |
| `dws.dws_bz_card_finance_daily_v2_p` | `qbit_card / BZ` | 各笔数/金额乘对应费率，加 `cost_fixed_fee` |
| `dws.dws_sales_metric_daily` | 按日指标中的产品/provider/sale | `assets_acceptance_fee_gt_zero` 与 `assets_acceptance_fee_eq_zero` 的 cost 指标值 |
| `ods.ods_payment_transaction_record` | `group_account`，provider NULL | 从 `extra.fee_cost` 提取并转为 numeric；限 `Closed` 状态 |
| `ods.ods_bi_month_tag` | 按产品线映射产品，provider 沿用源字段 | `OFFLINE_REFUND` 金额按上海业务月份 1 号入账 |

Cost 按报表日、根账户、产品、provider、sale 汇总。源 sale_id 为空时，按 `dim.dim_sale_account_relation_p` 的账户/日期归属补销售；DWM/CARD 日成本不再进行收入权重二次分摊。

以下是直接成本源的查询示例，金额计算公式请对照物化视图 SQL 中 `raw_cost_rows` 的同名 UNION 分支；provider 可以筛选或分组：

```sql
SELECT
    c.report_date::date AS report_date,
    COALESCE(aar.root_id, c.account_id)::varchar AS root_account_id,
    CASE c.product_line WHEN 'GLOBAL_ACCOUNT' THEN 'group_account'
                        WHEN 'QUANTUM_CARD' THEN 'qbit_card' END AS product,
    CASE WHEN c.product_line = 'GLOBAL_ACCOUNT' AND c.cost_type = 'SETTLEMENT_COST' THEN NULL
         WHEN c.product_line = 'QUANTUM_CARD' AND c.provider = 'BPC' THEN 'IQ'
         ELSE NULLIF(TRIM(c.provider), '') END AS provider,
    c.sale_id::varchar AS sale_id,
    SUM(COALESCE(c.cost_amount, 0)) AS cost
FROM dwm.dwm_finance_channel_cost_p c
LEFT JOIN public.api_account_relation aar
  ON aar.account_id = c.account_id::varchar AND aar.delete_time IS NULL
WHERE c.delete_time IS NULL
  AND c.report_date >= DATE '2026-09-01'
  AND c.report_date <  DATE '2026-10-01'
  AND ((c.product_line = 'GLOBAL_ACCOUNT' AND (c.provider IN ('BZ', 'CL') OR c.cost_type = 'SETTLEMENT_COST'))
       OR (c.product_line = 'QUANTUM_CARD' AND c.provider = 'BPC'))
  AND COALESCE(aar.root_id, c.account_id)::varchar = '95d362d7-56fe-4f50-82cb-f97a51afc263'
  AND c.sale_id::varchar = 'cfd8b2a8-af2d-474a-9923-3a5ef0335f52'
  -- 渠道过滤示例：AND c.provider = 'BPC'；BPC 在报表中映射为 IQ
GROUP BY c.report_date::date, COALESCE(aar.root_id, c.account_id), c.product_line,
         CASE WHEN c.product_line = 'GLOBAL_ACCOUNT' AND c.cost_type = 'SETTLEMENT_COST' THEN NULL
              WHEN c.product_line = 'QUANTUM_CARD' AND c.provider = 'BPC' THEN 'IQ'
              ELSE NULLIF(TRIM(c.provider), '') END,
         c.sale_id;
```

## 8. Gross Profit / Pref_GP（应收毛利：有效应收收入 - 成本 + 实体卡毛利）

```sql
SELECT
    (COALESCE(pref_rev_effective, 0) - COALESCE(cost, 0)
     + COALESCE(physical_card_gp, 0))::numeric(20,4) AS pref_gp;
```

实体卡毛利来源是日指标 `physical_card_gp`，仅取 `qbit_card / IQ`，单独加到毛利，不计入成本，也不计入返现。应收收入来源见第 1 节；Cost 来源见第 7 节。

## 9. Cash Flow Revenue / Cashflow_Rev（整体实收收入）

整体口径保留 Open API 月账单的原始实际收款总额，不扣除 KYC、实体卡手续费或最低承诺实收。

```sql
SELECT
    SUM(COALESCE(m.metric_value, 0)) AS api_actual_received_amount
FROM dws.dws_sales_metric_daily m
WHERE m.delete_time IS NULL
  AND m.product = 'open_api'
  AND m.metric_type = 'income'
  AND m.metric_code = 'api_client_bill_actual_received_amount'
  AND m.report_date >= DATE '2026-09-01'
  AND m.report_date <  DATE '2026-10-01'
  AND m.root_account_id::varchar = '95d362d7-56fe-4f6a-bfab-a44b7cb94be5'
  AND m.sale_id::varchar = 'cfd8b2a8-af2d-474a-9923-3a5ef0335f52';
```

整体实收还包括实时收入、量子卡渠道返现收入及 BI 收入调账。`Cashflow_Rev_effective = Cashflow_Rev - Rebate`；`Cashflow_GP = Cashflow_Rev_effective - Cost + physical_card_gp`。

## 10. Cash Flow Revenue / Cashflow_Rev_sale（销售维度实收收入）

`Cashflow_Rev_sale` 按销售维度统计实收总额，包含实时收入、API 月账单实收、量子卡渠道返现收入及 BI 收入调账。API 月账单实收单独核算 SQL 见“API 月账单实收 / API Actual Received”章节；汇入总额时不再叠加月度汇总表的 Open API `month_revenue`。月表 `qbit_card/main` 不额外相加，避免与日表 main/返现形成重复。

## 11. Cash Flow Effective Revenue / Cashflow_Rev_sale_effective（销售维度实收有效收入）

```sql
SELECT
    (COALESCE(cashflow_rev_sale, 0) - COALESCE(client_rebate, 0)
     - COALESCE(client_collection_rebate, 0)
     - COALESCE(gross_profit_rebate, 0))::numeric(20,4) AS cashflow_rev_sale_effective;
```

`cashflow_rev_sale` 按第 10 节来源计算；返现按第 2–5 节来源计算。

## 12. Cash Flow Gross Profit / Cashflow_GP_sale（销售维度实收毛利）

```sql
SELECT
    (COALESCE(cashflow_rev_sale_effective, 0) - COALESCE(cost, 0)
     + COALESCE(physical_card_gp, 0))::numeric(20,4) AS cashflow_gp_sale;
```

`cashflow_rev_sale` 按第 10 节来源计算；Cost 按第 7 节计算；实体卡毛利按本节第 8 节来源计算。毛利不归零，负数保留。

## Provider 筛选说明

- 源表有渠道字段时，按 `NULLIF(TRIM(provider), '')` 归一化后 `GROUP BY provider`。
- 过滤具体渠道：`AND provider = 'IQ'`。
- 过滤 NULL 渠道：`AND provider IS NULL`。
- DWM 的 QUANTUM_CARD/BPC 成本映射到报表 provider `IQ`；GLOBAL_ACCOUNT/SETTLEMENT_COST 的 provider 为 NULL。
- BI 月度调账、月账单按源 `provider` 归属；不根据金额猜渠道。

## Open API 月账单应收/实收拆分

- 应收来源：`dws_metrics_sales_revenue_monthly` 中 `product = 'open_api'`、`metric_code = 'month_receivable'`，按结算月首日归属。
- 实收来源：`dws_sales_metric_daily` 中 `product = 'open_api'`、`metric_type = 'income'`、`metric_code = 'api_client_bill_actual_received_amount'`；按客户、日期和销售归集，不区分 provider。
- `Cashflow_Rev_sale` 在上述实收基数上扣除 `api_client_bill_monthly_kyc_fee_received_amount`、`api_client_bill_physical_card_fee_received_amount`、`api_client_bill_minimum_commitment_received_amount`，不按渠道拆分。
- 详情展示仅区分应收/实收，拆为 `open_api_receivable`、`open_api_received` 两种 product 行；应收保留 provider，实收 provider 为 NULL，不再按渠道拆分。内部 `api_bill_type` 不属于 API/导出字段。月账单应收为月粒度，report_date 按结算月首日筛选。
