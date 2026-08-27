-- ==============================================================
-- 增量物化视图：dws.dws_revenue_summary_daily_mv v2
-- 说明    : 从 dws.dws_revenue_daily + dws.dws_channel_cashback_daily 汇总营收
--           v2 新增：从 ods_bi_month_tag 读取月度卡类收入及调整项
-- 刷新    : 自动增量刷新，基表写入后实时同步
-- ==============================================================

DROP MATERIALIZED VIEW IF EXISTS dws.dws_revenue_summary_daily_mv;

CREATE INCREMENTAL MATERIALIZED VIEW dws.dws_revenue_summary_daily_mv AS

SELECT
    stat_date                                                                       AS stat_date,
    CASE WHEN product = 'crypto' THEN 'crypto_assets' ELSE product END              AS category,
    CASE metric_code
        WHEN 'fx_fee_amount'                                THEN 'qbit_fx_fee'
        WHEN 'atm_fee_amount'                               THEN 'qbit_atm_fee'
        WHEN 'apple_pay_fee_amount'                         THEN 'qbit_apple_pay_fee'
        WHEN 'settle_fee_amount'                            THEN 'qbit_settle_fee'
        WHEN 'card_authorization_fee_amount'                THEN 'qbit_authorization_fee'
        WHEN 'card_refund_fee_amount'                       THEN 'qbit_refund_fee'
        WHEN 'card_declined_fee_amount'                     THEN 'qbit_declined_fee'
        WHEN 'card_reversal_fee_amount'                     THEN 'qbit_reversal_fee'
        WHEN 'active_card_fee_amount'                       THEN 'qbit_active_card_fee'
        WHEN 'qbit_account_recharge_fee_amount'             THEN 'qbit_card_recharge_fee'
        WHEN 'virtual_card_create_fee_amount'               THEN 'qbit_card_opening_fee'
        WHEN 'physical_card_service_fee_amount'             THEN 'physical_card_fee'
        WHEN 'interchange_revenue_amount'                   THEN 'interchange_revenue'
        WHEN 'global_account_payment_fee_amount'            THEN 'overseas_payment_fee'
        WHEN 'global_account_deposit_fee_amount'            THEN 'global_recharge_fee'
        WHEN 'global_account_fx_income_amount'              THEN 'global_fx_income'
        WHEN 'crypto_assets_acceptance_fee_amount'          THEN 'crypto_exchange_fee'
        WHEN 'crypto_assets_withdrawal_fee_amount'          THEN 'crypto_payment_fee'
        WHEN 'crypto_assets_deposit_fee_amount'             THEN 'crypto_inbound_fee'
        WHEN 'treasury_service_fee_amount'                  THEN 'treasury_service_fee'
        WHEN 'acquiring_fee'                                THEN 'acquiring_fee'
        WHEN 'api_client_bill_monthly_fee_receivable_amount'         THEN 'api_client_receivable_fee'
        WHEN 'api_client_bill_monthly_fx_fee_receivable_amount'      THEN 'api_client_receivable_fee'
        WHEN 'api_client_bill_monthly_kyc_fee_receivable_amount'     THEN 'api_client_receivable_fee'
        WHEN 'api_client_bill_monthly_crypto_fee_receivable_amount'  THEN 'api_client_receivable_fee'
        WHEN 'api_client_bill_monthly_api_fee_receivable_amount'     THEN 'api_client_receivable_fee'
        WHEN 'api_client_bill_uncategorized_fee_receivable_amount'   THEN 'api_client_receivable_fee'
        WHEN 'api_client_bill_minimum_commitment_receivable_amount'  THEN 'api_client_receivable_fee'
        ELSE metric_code
    END                                                                             AS revenue_source,
    COALESCE(account_id, '')                                                           AS account_id,
    ''                                                                               AS account_type,
    ''                                                                               AS system_type,
    SUM(metric_value)                                                                AS amount
FROM dws.dws_revenue_daily
WHERE metric_code IN (
    'fx_fee_amount',
    'api_client_bill_monthly_fx_fee_receivable_amount',
    'crypto_assets_deposit_fee_amount',
    'atm_fee_amount',
    'card_reversal_fee_amount',
    'card_authorization_fee_amount',
    'crypto_assets_withdrawal_fee_amount',
    'active_card_fee_amount',
    'apple_pay_fee_amount',
    'acquiring_fee',
    'api_client_bill_monthly_kyc_fee_receivable_amount',
    'qbit_account_recharge_fee_amount',
    'card_refund_fee_amount',
    'treasury_service_fee_amount',
    'global_account_payment_fee_amount',
    'card_declined_fee_amount',
    'settle_fee_amount',
    'api_client_bill_monthly_fee_receivable_amount',
    'physical_card_service_fee_amount',
    'global_account_deposit_fee_amount',
    'crypto_assets_acceptance_fee_amount',
    'virtual_card_create_fee_amount',
    'api_client_bill_monthly_api_fee_receivable_amount',
    'api_client_bill_uncategorized_fee_receivable_amount',
    'interchange_revenue_amount',
    'api_client_bill_minimum_commitment_receivable_amount',
    'api_client_bill_monthly_crypto_fee_receivable_amount',
    'global_account_fx_income_amount'
)
GROUP BY
    stat_date,
    CASE WHEN product = 'crypto' THEN 'crypto_assets' ELSE product END,
    metric_code,
    account_id

UNION ALL

-- ==================== 渠道返现（从 dws_channel_cashback_daily 透传） ====================
SELECT
    stat_date,
    category,
    revenue_source,
    account_id,
    account_type,
    system_type,
    amount
FROM dws.dws_channel_cashback_daily

UNION ALL

-- ==================== v2: 月度卡类收入及调整项（从 ods_bi_month_tag 读取） ====================
SELECT
    t.statistics_time::date AS stat_date,
    'card' AS category,
    CASE t.tag
        WHEN 'OFFLINE_PHYSICAL_CARD_FEE' THEN 'offline_physical_card_fee'
        WHEN 'INCOME_ADJUSTMENT_DECREASE' THEN 'income_adjustment_decrease'
        WHEN 'INCOME_ADJUSTMENT_INCREASE' THEN 'income_adjustment_increase'
        WHEN 'API_MINIMUM_CONSUMPTION_ADJUSTMENT_DECREASE' THEN 'api_minimum_consumption_adjustment_decrease'
    END AS revenue_source,
    t.account_id,
    '' AS account_type,
    '' AS system_type,
    SUM(
        CASE
            WHEN t.tag IN (
                'INCOME_ADJUSTMENT_DECREASE',
                'API_MINIMUM_CONSUMPTION_ADJUSTMENT_DECREASE'
            ) THEN -ABS(COALESCE(t.amount, 0))
            ELSE ABS(COALESCE(t.amount, 0))
        END
    ) AS amount
FROM ods.ods_bi_month_tag t
WHERE t.delete_time IS NULL
  AND t.tag IN (
      'OFFLINE_PHYSICAL_CARD_FEE',
      'INCOME_ADJUSTMENT_DECREASE',
      'INCOME_ADJUSTMENT_INCREASE',
      'API_MINIMUM_CONSUMPTION_ADJUSTMENT_DECREASE'
  )
  AND t.account_id IS NOT NULL
GROUP BY t.statistics_time::date, t.tag, t.account_id;

COMMENT ON MATERIALIZED VIEW dws.dws_revenue_summary_daily_mv IS '收入日维度汇总 v2（dws_revenue_daily + channel_cashback_daily + card month tags），增量自动刷新';
