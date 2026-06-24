--********************************************************************--
-- Author:         zhanghaoran
-- Created Time:   2026-06-22
-- Description:    Full DWD -> DWM/DWS card transaction metric batch job
-- Notes:
--   1. Statistical date uses DWD field dt directly.
--   2. Run adbpg_card_transaction_dwm_dws_ddl.sql before this job.
--   3. Before a complete rebuild, truncate only the card DWM table.
--      In the shared DWS table, delete only rows matching:
--      product_line = 'Card', business_domain = 'Card Transaction',
--      metric_code = 'card_consumption_amount'. Never truncate shared DWS.
--********************************************************************--

SET 'parallelism.default' = '1';
SET 'pipeline.operator-chaining' = 'true';
SET 'table.optimizer.reuse-source-enabled' = 'true';
SET 'table.optimizer.reuse-sub-plan-enabled' = 'true';

SET 'restart-strategy.type' = 'fixed-delay';
SET 'restart-strategy.fixed-delay.attempts' = '3';
SET 'restart-strategy.fixed-delay.delay' = '60s';



CREATE TEMPORARY TABLE source_api_client_bill_statement (
    bill_id        BIGINT,
    statement_account_id STRING,
    item           STRING,
    statement_type STRING,
    amount         DECIMAL(20, 3),
    is_sum         BOOLEAN,
    delete_time    TIMESTAMP(6)
) WITH (
    'connector' = 'jdbc',
    'url' = 'jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}?stringtype=unspecified',
    'username' = '${secret_values.ADB_PG_USERNAME}',
    'password' = '${secret_values.ADB_PG_PASSWORD}',
    'table-name' = '(SELECT bill_id, account_id::text AS statement_account_id, item, type AS statement_type, amount, is_sum, delete_time FROM public.api_client_bill_statement) AS api_client_bill_statement_all',
    'driver' = 'org.postgresql.Driver',
    'scan.fetch-size' = '30000',
    'scan.auto-commit' = 'false'
);

CREATE TEMPORARY TABLE source_api_client_bill (
    id          BIGINT,
    account_id  STRING,
    bill_month  STRING,
    bill_type   STRING,
    delete_time TIMESTAMP(6)
) WITH (
    'connector' = 'jdbc',
    'url' = 'jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}?stringtype=unspecified',
    'username' = '${secret_values.ADB_PG_USERNAME}',
    'password' = '${secret_values.ADB_PG_PASSWORD}',
    'table-name' = '(SELECT id, account_id::text AS account_id, bill_month, type AS bill_type, delete_time FROM public.api_client_bill) AS api_client_bill_all',
    'driver' = 'org.postgresql.Driver',
    'scan.fetch-size' = '20000',
    'scan.auto-commit' = 'false'
);

-- Keep the debit source logic aligned with the original SQL sample. Potential filters such as
-- delete_time/status/is_show are intentionally not added until the business owner confirms them.
CREATE TEMPORARY TABLE source_api_client_debit_record (
    bill_id     BIGINT,
    real_amount DECIMAL(20, 3)
) WITH (
    'connector' = 'jdbc',
    'url' = 'jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}?stringtype=unspecified',
    'username' = '${secret_values.ADB_PG_USERNAME}',
    'password' = '${secret_values.ADB_PG_PASSWORD}',
    'table-name' = '(SELECT bill_id, real_amount FROM public.api_client_debit_record) AS api_client_debit_record_all',
    'driver' = 'org.postgresql.Driver',
    'scan.fetch-size' = '30000',
    'scan.auto-commit' = 'false'
);

-- Keep all netting rebate_amount rows as in the original SQL sample.
-- status/type/delete_time filters are pending confirmation.
CREATE TEMPORARY TABLE source_api_client_netting_bill (
    bill_id       BIGINT,
    rebate_amount DECIMAL(20, 3)
) WITH (
    'connector' = 'jdbc',
    'url' = 'jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}?stringtype=unspecified',
    'username' = '${secret_values.ADB_PG_USERNAME}',
    'password' = '${secret_values.ADB_PG_PASSWORD}',
    'table-name' = '(SELECT bill_id, rebate_amount FROM public.api_client_netting_bill) AS api_client_netting_bill_all',
    'driver' = 'org.postgresql.Driver',
    'scan.fetch-size' = '30000',
    'scan.auto-commit' = 'false'
);

CREATE TEMPORARY TABLE source_dim_account (
    id   STRING,
    type STRING,
    PRIMARY KEY (id) NOT ENFORCED
) WITH (
    'connector' = 'jdbc',
    'url' = 'jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}?stringtype=unspecified',
    'username' = '${secret_values.ADB_PG_USERNAME}',
    'password' = '${secret_values.ADB_PG_PASSWORD}',
    'table-name' = '(SELECT id::text AS id, type FROM dim.dim_account) AS dim_account',
    'driver' = 'org.postgresql.Driver',
    'scan.fetch-size' = '20000',
    'scan.auto-commit' = 'false'
);

CREATE TEMPORARY TABLE sink_dwm_api_client_bill_receivable_received_daily (
    account_id        STRING,
    state_date        DATE,
    bill_month        STRING,
    account_type      STRING,
    account_type_desc STRING,
    fee_category      STRING,
    receivable_amount DECIMAL(20, 3),
    received_amount   DECIMAL(20, 3),
    source_bill_count BIGINT,
    create_time       TIMESTAMP(6),
    update_time       TIMESTAMP(6),
    delete_time       TIMESTAMP(6)
) WITH (
    'connector' = 'jdbc',
    'url' = 'jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}?stringtype=unspecified',
    'username' = '${secret_values.ADB_PG_USERNAME}',
    'password' = '${secret_values.ADB_PG_PASSWORD}',
    'table-name' = 'dwm.dwm_api_client_bill_receivable_received_daily',
    'driver' = 'org.postgresql.Driver',
    'sink.buffer-flush.max-rows' = '5000',
    'sink.buffer-flush.interval' = '2s',
    'sink.max-retries' = '3'
);

CREATE TEMPORARY VIEW dim_account_classified AS
SELECT
    id,
    COALESCE(NULLIF(TRIM(type), ''), 'Unknown') AS account_type,
    CASE
        WHEN type IN ('ApiClientCustomer', 'ApiClient') THEN 'API客户'
        WHEN type IS NULL OR TRIM(type) = '' THEN '其他类型'
        ELSE '直客'
    END AS account_type_desc
FROM source_dim_account;

CREATE TEMPORARY VIEW bill_statement_base AS
SELECT
    stmt.bill_id,
    bill.account_id,
    bill.bill_month,
    CAST(CONCAT(bill.bill_month, '-01') AS DATE) AS state_date,
    stmt.item,
    LOWER(COALESCE(stmt.item, '')) AS item_lower,
    stmt.statement_type,
    CAST(COALESCE(stmt.amount, CAST(0 AS DECIMAL(20, 3))) AS DECIMAL(38, 6)) AS amount
FROM source_api_client_bill_statement AS stmt
INNER JOIN source_api_client_bill AS bill
    ON stmt.bill_id = bill.id
WHERE stmt.is_sum IS TRUE
  AND stmt.delete_time IS NULL
  AND stmt.statement_type NOT LIKE '%Closed%'
  AND bill.delete_time IS NULL
  AND bill.bill_type = 'MonthlyStatement'
  AND bill.bill_month IS NOT NULL
  AND CAST(CONCAT(bill.bill_month, '-01') AS DATE) >= DATE '${start_date}'
  AND CAST(CONCAT(bill.bill_month, '-01') AS DATE) < DATE '${end_date}'
  AND bill.account_id IS NOT NULL
  AND TRIM(bill.account_id) <> ''
  AND stmt.statement_type IS NOT NULL;

-- Expand categories with UNION ALL on purpose. Some rows can belong to multiple categories under the original logic;
-- for example Add rows for Identity Verification may still be part of monthly_fee. Keep this non-mutual behavior.
CREATE TEMPORARY VIEW bill_fee_rows AS
SELECT
    bill_id,
    account_id,
    bill_month,
    state_date,
    'monthly_fee' AS fee_category,
    amount
FROM bill_statement_base
WHERE statement_type IN (
    'topUpFee',
    'settlementFee',
    'reversalFee',
    'refundFee',
    'declineFee',
    'cardCreationFee',
    'refundClientFee',
    'postageFee',
    'applePayAuthFee',
    'verificationFee',
    'monthlyCardFee',
    'authFee',
    'atmWithdrawalFee',
    'cardProductionFee',
    'issuerCardServiceIntFee',
    'issuerCardServiceDomFee',
    'visaRiskManagerIntFee',
    'visaRiskManagerDomFee',
    'issuerTransactionAuthIntFee',
    'issuerTransactionAuthDomFee',
    'issuerTransactionSettlementIntFee',
    'issuerTransactionSettlementDomFee',
    'schemeVerificationIntFee',
    'schemeVerificationDomFee',
    'schemeRefundFee',
    'schemeReversalFee',
    'schemeSignatureFee'
)
OR (
    statement_type = 'Add'
    AND item_lower NOT LIKE '%crypto fee%'
    AND item_lower NOT LIKE '%cross chain fee%'
    AND item_lower NOT LIKE '%cross border fee%'
)

UNION ALL

SELECT
    bill_id,
    account_id,
    bill_month,
    state_date,
    'fx_fee' AS fee_category,
    amount
FROM bill_statement_base
WHERE statement_type IN ('fxFee', 'crossBorderFee')
   OR (
       statement_type = 'Add'
       AND item_lower LIKE '%cross border fee%'
   )

UNION ALL

SELECT
    bill_id,
    account_id,
    bill_month,
    state_date,
    'kyc_fee' AS fee_category,
    amount
FROM bill_statement_base
WHERE statement_type = 'identityVerification'
   OR (
       statement_type = 'Add'
       AND item = 'Identity Verification (Supplementary Debit)'
   )

UNION ALL

SELECT
    bill_id,
    account_id,
    bill_month,
    state_date,
    'api_fee' AS fee_category,
    amount
FROM bill_statement_base
WHERE statement_type IN (
    'monthlyCommitment',
    'additionalFee',
    'apiSubscription',
    'apiIntegration',
    'minimumVolumeCommitmentFee'
)

UNION ALL

SELECT
    bill_id,
    account_id,
    bill_month,
    state_date,
    'crypto_fee' AS fee_category,
    amount
FROM bill_statement_base
WHERE statement_type = 'Add'
  AND (
      item_lower LIKE '%crypto fee%'
      OR item_lower LIKE '%cross chain fee%'
  );

CREATE TEMPORARY VIEW bill_statement_sum AS
SELECT
    bill_id,
    SUM(amount) AS bill_statement_sum_amount
FROM bill_statement_base
WHERE amount <> CAST(0 AS DECIMAL(38, 6))
GROUP BY bill_id;

CREATE TEMPORARY VIEW bill_received_events AS
SELECT
    bill_id,
    CAST(COALESCE(real_amount, CAST(0 AS DECIMAL(20, 3))) AS DECIMAL(38, 6)) AS received_amount
FROM source_api_client_debit_record

UNION ALL

SELECT
    bill_id,
    CAST(COALESCE(rebate_amount, CAST(0 AS DECIMAL(20, 3))) AS DECIMAL(38, 6)) AS received_amount
FROM source_api_client_netting_bill;

CREATE TEMPORARY VIEW bill_received_rate AS
SELECT
    events.bill_id,
    CASE
        WHEN sums.bill_statement_sum_amount IS NULL
          OR sums.bill_statement_sum_amount = CAST(0 AS DECIMAL(38, 6))
        THEN CAST(0 AS DECIMAL(38, 12))
        ELSE CAST(SUM(events.received_amount) AS DECIMAL(38, 12)) / CAST(sums.bill_statement_sum_amount AS DECIMAL(38, 12))
    END AS debit_rate
FROM bill_received_events AS events
LEFT JOIN bill_statement_sum AS sums
    ON events.bill_id = sums.bill_id
GROUP BY
    events.bill_id,
    sums.bill_statement_sum_amount;

CREATE TEMPORARY VIEW dwm_api_client_bill_receivable_received_daily AS
SELECT
    rs.account_id,
    rs.state_date,
    rs.bill_month,
    COALESCE(acc.account_type, 'Unknown') AS account_type,
    COALESCE(acc.account_type_desc, '其他类型') AS account_type_desc,
    rs.fee_category,
    CAST(ROUND(SUM(rs.amount), 3) AS DECIMAL(20, 3)) AS receivable_amount,
    CAST(ROUND(SUM(rs.amount * COALESCE(rate.debit_rate, CAST(0 AS DECIMAL(38, 12)))), 3) AS DECIMAL(20, 3)) AS received_amount,
    COUNT(DISTINCT rs.bill_id) AS source_bill_count
FROM bill_fee_rows AS rs
LEFT JOIN bill_received_rate AS rate
    ON rs.bill_id = rate.bill_id
LEFT JOIN dim_account_classified AS acc
    ON rs.account_id = acc.id
GROUP BY
    rs.account_id,
    rs.state_date,
    rs.bill_month,
    COALESCE(acc.account_type, 'Unknown'),
    COALESCE(acc.account_type_desc, '其他类型'),
    rs.fee_category;

INSERT INTO sink_dwm_api_client_bill_receivable_received_daily
SELECT
    account_id,
    state_date,
    bill_month,
    account_type,
    account_type_desc,
    fee_category,
    receivable_amount,
    received_amount,
    source_bill_count,
    CURRENT_TIMESTAMP AS create_time,
    CURRENT_TIMESTAMP AS update_time,
    CAST(NULL AS TIMESTAMP(6)) AS delete_time
FROM dwm_api_client_bill_receivable_received_daily;
