--********************************************************************--
-- Author:         Codex
-- Created Time:   2026-07-20
-- Description:    BB V2 成本口径独立排查 SQL
-- Purpose:
--   1. 不依赖 bi_month 脚本中的 tmp_* 临时表，可单独执行。
--   2. 优先排查差异大的 Dollar Volume / Volume Fee Cost。
--   3. 优先排查为 0 的 Refund 三项。
-- Usage:
--   1. 修改 params 中的 start_time / end_time。
--   2. 分段执行每个 SELECT，部分客户端不支持一次执行多个结果集。
--********************************************************************--

-- =========================================================
-- 1. DWS 当前成本项汇总：对齐 query_bb_card_cost_detail_v2.sql
-- =========================================================

WITH params AS (
    SELECT
        DATE '2026-05-01' AS start_date,
        DATE '2026-06-01' AS end_date
),
bb_base AS (
    SELECT
        COALESCE(SUM(bb.m_dom_auth_count * 0.1090), 0) AS mastercard_domestic_count_fee,
        COALESCE(SUM(bb.m_int_auth_count * 0.4845), 0) AS mastercard_international_count_fee,
        COALESCE(SUM(bb.v_dom_auth_count * 0.0725), 0) AS visa_domestic_count_fee,
        COALESCE(SUM(bb.v_int_auth_count * 0.4770), 0) AS visa_international_count_fee,
        COALESCE(SUM(bb.av_m_dom_count * 0.1090), 0) AS ac_mastercard_domestic_count_fee,
        COALESCE(SUM(bb.av_m_int_count * 0.4845), 0) AS ac_mastercard_international_count_fee,
        COALESCE(SUM(bb.av_v_dom_count * 0.0725), 0) AS ac_visa_domestic_count_fee,
        COALESCE(SUM(bb.av_v_int_count * 0.4770), 0) AS ac_visa_international_count_fee,

        COALESCE(SUM(bb.m_int_reversal_count * 0.7190), 0) AS mastercard_international_reversal_fee,
        COALESCE(SUM(bb.v_int_reversal_count * 0.7140), 0) AS visa_international_reversal_fee,
        COALESCE(SUM(bb.dom_reversal_count * 0.1780), 0) AS domestic_reversal_fee,
        COALESCE(SUM(bb.m_int_refund_count * 0.4845), 0) AS mastercard_international_refund_fee,
        COALESCE(SUM(bb.v_int_refund_count * 0.4770), 0) AS visa_international_refund_fee,
        COALESCE(SUM(bb.dom_decline_count * 0.0890), 0) AS domestic_decline_fee,


        COALESCE(SUM(bb.m_dom_clearing_vol * 0.0021), 0) AS mastercard_domestic_dollar_volume_fee,
        COALESCE(SUM(bb.m_int_clearing_vol * 0.0111), 0) AS mastercard_international_dollar_volume_fee,
        COALESCE(SUM(bb.v_dom_clearing_vol * 0.0016), 0) AS visa_domestic_dollar_volume_fee,
        COALESCE(SUM(bb.v_int_clearing_vol * 0.0116), 0) AS visa_international_dollar_volume_fee,

        COALESCE(SUM(bb.m_int_decline_count * 0.3595), 0) AS mastercard_international_decline_fee,
        COALESCE(SUM(bb.v_int_decline_count * 0.3570), 0) AS visa_international_decline_fee,
        COALESCE(SUM(bb.dom_refund_count * 0.1090), 0) AS domestic_refund_fee,

        COALESCE(SUM(bb.ac_m_int_decline_count * 0.3595), 0) AS ac_mastercard_international_decline_fee,
        COALESCE(SUM(bb.ac_v_int_decline_count * 0.3570), 0) AS ac_visa_international_decline_fee,
        COALESCE(SUM(bb.ac_dom_decline_count * 0.0890), 0) AS ac_domestic_decline_fee,

        COALESCE(SUM(bb.active_card_count * 0.1), 0) AS active_card_account_fee,
        COALESCE(SUM(bb.total_net_amount), 0) AS total_net_amount,
        COALESCE(SUM(bb.cost_fixed_fee), 0) AS fixed_fee
    FROM dws.dws_bb_card_finance_daily_v2_p bb
    CROSS JOIN params p
    WHERE bb.delete_time IS NULL
      AND bb.report_date >= p.start_date
      AND bb.report_date < p.end_date
),
bb_detail AS (
    SELECT
        *,
        CASE
            WHEN total_net_amount = 0 THEN 0
            WHEN total_net_amount <= 5000000 THEN total_net_amount * 0.0055
            WHEN total_net_amount <= 10000000 THEN 5000000 * 0.0055 + (total_net_amount - 5000000) * 0.0045
            ELSE 5000000 * 0.0055 + 5000000 * 0.0045 + (total_net_amount - 10000000) * 0.004
        END AS volume_fee_cost
    FROM bb_base
),
bb_cost_item AS (
    SELECT 1 AS sort_no, 'Mastercard Domestic Count Fee' AS cost_item, mastercard_domestic_count_fee AS cost_amount FROM bb_detail
    UNION ALL SELECT 2, 'Mastercard International Count Fee', mastercard_international_count_fee FROM bb_detail
    UNION ALL SELECT 3, 'VISA Domestic Count Fee', visa_domestic_count_fee FROM bb_detail
    UNION ALL SELECT 4, 'VISA International Count Fee', visa_international_count_fee FROM bb_detail
    UNION ALL SELECT 5, 'AC Mastercard Domestic Count Fee', ac_mastercard_domestic_count_fee FROM bb_detail
    UNION ALL SELECT 6, 'AC Mastercard International Count Fee', ac_mastercard_international_count_fee FROM bb_detail
    UNION ALL SELECT 7, 'AC VISA Domestic Count Fee', ac_visa_domestic_count_fee FROM bb_detail
    UNION ALL SELECT 8, 'AC VISA International Count Fee', ac_visa_international_count_fee FROM bb_detail
    UNION ALL SELECT 9, 'Mastercard Domestic Dollar Volume Fee', mastercard_domestic_dollar_volume_fee FROM bb_detail
    UNION ALL SELECT 10, 'Mastercard International Dollar Volume Fee', mastercard_international_dollar_volume_fee FROM bb_detail
    UNION ALL SELECT 11, 'Visa Domestic Dollar Volume Fee', visa_domestic_dollar_volume_fee FROM bb_detail
    UNION ALL SELECT 12, 'Visa International Dollar Volume Fee', visa_international_dollar_volume_fee FROM bb_detail
    UNION ALL SELECT 13, 'Mastercard International Reversal Fee', mastercard_international_reversal_fee FROM bb_detail
    UNION ALL SELECT 14, 'Visa International Reversal Fee', visa_international_reversal_fee FROM bb_detail
    UNION ALL SELECT 15, 'Domestic Reversal Fee', domestic_reversal_fee FROM bb_detail
    UNION ALL SELECT 16, 'Mastercard International Refund Fee', mastercard_international_refund_fee FROM bb_detail
    UNION ALL SELECT 17, 'VISA International Refund Fee', visa_international_refund_fee FROM bb_detail
    UNION ALL SELECT 18, 'Domestic Refund Fee', domestic_refund_fee FROM bb_detail
    UNION ALL SELECT 19, 'Mastercard International Decline Fee', mastercard_international_decline_fee FROM bb_detail
    UNION ALL SELECT 20, 'Visa International Decline Fee', visa_international_decline_fee FROM bb_detail
    UNION ALL SELECT 21, 'Domestic Decline Fee', domestic_decline_fee FROM bb_detail
    UNION ALL SELECT 22, 'AC Mastercard International Decline Fee', ac_mastercard_international_decline_fee FROM bb_detail
    UNION ALL SELECT 23, 'AC Visa International Decline Fee', ac_visa_international_decline_fee FROM bb_detail
    UNION ALL SELECT 24, 'AC Domestic Decline Fee', ac_domestic_decline_fee FROM bb_detail
    UNION ALL SELECT 25, 'Active Card Account Fee', active_card_account_fee FROM bb_detail
    UNION ALL SELECT 26, 'Volume Fee Cost', volume_fee_cost FROM bb_detail
    UNION ALL SELECT 27, 'Fixed Fee', fixed_fee FROM bb_detail
),
result_detail AS (
    SELECT
        sort_no,
        cost_item,
        CAST(COALESCE(cost_amount, 0) AS NUMERIC(20, 4)) AS cost_amount
    FROM bb_cost_item

    UNION ALL

    SELECT
        999 AS sort_no,
        'TOTAL' AS cost_item,
        CAST(COALESCE(SUM(cost_amount), 0) AS NUMERIC(20, 4)) AS cost_amount
    FROM bb_cost_item
)
SELECT
    cost_item,
    cost_amount
FROM result_detail
ORDER BY sort_no;


-- =========================================================
-- 2. Refund 专项排查：raw -> dwm -> dws
-- 如果 raw 有值但 dwm 为 0，先重跑 DWM transaction batch。
-- 如果 dwm 有值但 dws 为 0，先重跑 DWS finance daily batch。
-- =========================================================
WITH params AS (
    SELECT
        TIMESTAMP '2026-06-01 00:00:00' AS start_time,
        TIMESTAMP '2026-07-01 00:00:00' AS end_time
),
raw_refund_by_post_date AS (
    SELECT
        'raw_refund_by_post_date' AS layer,
        COUNT(DISTINCT CASE WHEN RIGHT(s.raw_data::json->>'txnLocation', 2) NOT IN ('US', 'USA') AND c."type" = 'Master' THEN t.source_id END) AS master_int_refund_count,
        COUNT(DISTINCT CASE WHEN RIGHT(s.raw_data::json->>'txnLocation', 2) NOT IN ('US', 'USA') AND c."type" = 'VISA' THEN t.source_id END) AS visa_int_refund_count,
        COUNT(DISTINCT CASE WHEN RIGHT(s.raw_data::json->>'txnLocation', 2) IN ('US', 'USA') AND c."type" IN ('Master', 'VISA') THEN t.source_id END) AS dom_refund_count
    FROM public.quantum_card_transaction_extend t
    INNER JOIN public."qbitCard" c
        ON c."id" = t.card_id
    INNER JOIN ods.ods_qbit_card_settlement s
        ON t.card_transaction_id::text = s.qbit_card_transaction_id
    CROSS JOIN params p
    WHERE t.channel_provision = 'BLUEBANC'
      AND t.delete_time IS NULL
      AND t.type = 'Credit'
      AND c."type" IN ('Master', 'VISA')
      AND (t.detail IS NULL OR t.detail NOT LIKE 'AUTO CLASS CAR RENTAL%')
      AND s.delete_time IS NULL
      AND s.provider = 'BlueBancCard'
      AND s.transaction_type = 'refund.clearing'
      AND s.raw_data::json->>'responseCode' = 'APPROVE'
      AND CAST(s.raw_data::json->>'postDate' AS timestamp) >= p.start_time
      AND CAST(s.raw_data::json->>'postDate' AS timestamp) < p.end_time
      AND s.id NOT IN (
          '234e26db-0e1d-424f-952b-053ab2e42d30',
          '82ff7fa6-8035-4c7b-8c18-ace860c3dfae',
          '711e7995-ea26-499f-a1c5-9e4faf15f31f',
          '5e974989-8792-401f-93b6-b107e0b46e51',
          '0af98098-eb5e-4d5b-a5ad-76c1b1c0ae72',
          'a97006e9-2609-4e70-a165-2ae6b9f49689',
          'ad861604-ff4f-4cd1-997e-fe613c67970e',
          '37959ee2-880f-49ea-8d74-976a69382c90',
          'bebf7744-ed33-46cd-8ca6-40bc43d928eb',
          'ece578c8-e8c1-46ec-83b9-116ea049a2e8',
          '69e04460-0cb4-4d9d-9001-2b786cfc3d7b',
          '7fa7ea4f-40fa-4153-9ec1-426f4b2c5470',
          'cff4d9c4-ee01-43fa-9518-62872afbbe91',
          '160b403b-2a16-4b43-afac-a3b37916c968',
          '0fd4e8ed-e208-44e5-b463-ece053a915f3',
          '4a63f4ec-637e-4627-a668-5339fe64b9be'
      )
),
dwm_refund_by_post_date AS (
    SELECT
        'dwm_refund_by_post_date' AS layer,
        COUNT(DISTINCT CASE WHEN card_org = 'Master' AND settle_country NOT IN ('US', 'USA') THEN source_id END) AS master_int_refund_count,
        COUNT(DISTINCT CASE WHEN card_org = 'VISA' AND settle_country NOT IN ('US', 'USA') THEN source_id END) AS visa_int_refund_count,
        COUNT(DISTINCT CASE WHEN settle_country IN ('US', 'USA') THEN source_id END) AS dom_refund_count
    FROM dwm.dwm_bb_card_transaction_detail_v2_p t
    CROSS JOIN params p
    WHERE t.delete_time IS NULL
      AND t.business_type = 'Credit'
      AND t.transaction_type = 'refund.clearing'
      AND t.resp_code = 'APPROVE'
      AND t.settlement_post_date >= p.start_time
      AND t.settlement_post_date < p.end_time
      AND t.settlement_id NOT IN (
          '234e26db-0e1d-424f-952b-053ab2e42d30',
          '82ff7fa6-8035-4c7b-8c18-ace860c3dfae',
          '711e7995-ea26-499f-a1c5-9e4faf15f31f',
          '5e974989-8792-401f-93b6-b107e0b46e51',
          '0af98098-eb5e-4d5b-a5ad-76c1b1c0ae72',
          'a97006e9-2609-4e70-a165-2ae6b9f49689',
          'ad861604-ff4f-4cd1-997e-fe613c67970e',
          '37959ee2-880f-49ea-8d74-976a69382c90',
          'bebf7744-ed33-46cd-8ca6-40bc43d928eb',
          'ece578c8-e8c1-46ec-83b9-116ea049a2e8',
          '69e04460-0cb4-4d9d-9001-2b786cfc3d7b',
          '7fa7ea4f-40fa-4153-9ec1-426f4b2c5470',
          'cff4d9c4-ee01-43fa-9518-62872afbbe91',
          '160b403b-2a16-4b43-afac-a3b37916c968',
          '0fd4e8ed-e208-44e5-b463-ece053a915f3',
          '4a63f4ec-637e-4627-a668-5339fe64b9be'
      )
),
dws_refund_by_report_date AS (
    SELECT
        'dws_refund_by_report_date' AS layer,
        COALESCE(SUM(m_int_refund_count), 0) AS master_int_refund_count,
        COALESCE(SUM(v_int_refund_count), 0) AS visa_int_refund_count,
        COALESCE(SUM(dom_refund_count), 0) AS dom_refund_count
    FROM dws.dws_bb_card_finance_daily_v2_p d
    CROSS JOIN params p
    WHERE d.delete_time IS NULL
      AND d.report_date >= CAST(p.start_time AS date)
      AND d.report_date < CAST(p.end_time AS date)
)
SELECT *
FROM raw_refund_by_post_date
UNION ALL
SELECT *
FROM dwm_refund_by_post_date
UNION ALL
SELECT *
FROM dws_refund_by_report_date;

-- =========================================================
-- 3. 大差异专项排查：Dollar Volume / Volume Fee Cost
-- 看 16 个手工排除 settlement id 对金额差异的贡献。
-- =========================================================
WITH params AS (
    SELECT
        TIMESTAMP '2026-06-01 00:00:00' AS start_time,
        TIMESTAMP '2026-07-01 00:00:00' AS end_time
),
dwm_amount AS (
    SELECT
        COUNT(*) AS settlement_rows,
        SUM(CASE WHEN settlement_id IN (
            '234e26db-0e1d-424f-952b-053ab2e42d30',
            '82ff7fa6-8035-4c7b-8c18-ace860c3dfae',
            '711e7995-ea26-499f-a1c5-9e4faf15f31f',
            '5e974989-8792-401f-93b6-b107e0b46e51',
            '0af98098-eb5e-4d5b-a5ad-76c1b1c0ae72',
            'a97006e9-2609-4e70-a165-2ae6b9f49689',
            'ad861604-ff4f-4cd1-997e-fe613c67970e',
            '37959ee2-880f-49ea-8d74-976a69382c90',
            'bebf7744-ed33-46cd-8ca6-40bc43d928eb',
            'ece578c8-e8c1-46ec-83b9-116ea049a2e8',
            '69e04460-0cb4-4d9d-9001-2b786cfc3d7b',
            '7fa7ea4f-40fa-4153-9ec1-426f4b2c5470',
            'cff4d9c4-ee01-43fa-9518-62872afbbe91',
            '160b403b-2a16-4b43-afac-a3b37916c968',
            '0fd4e8ed-e208-44e5-b463-ece053a915f3',
            '4a63f4ec-637e-4627-a668-5339fe64b9be'
        ) THEN 1 ELSE 0 END) AS excluded_rows,
        COALESCE(SUM(CASE WHEN card_org = 'Master' AND settle_country IN ('US', 'USA') AND transaction_type = 'authorization.clearing' AND resp_code = 'APPROVE' THEN -billing_amount ELSE 0 END), 0) AS m_dom_vol_before_exclude,
        COALESCE(SUM(CASE WHEN card_org = 'Master' AND settle_country NOT IN ('US', 'USA') AND transaction_type = 'authorization.clearing' AND resp_code = 'APPROVE' THEN -billing_amount ELSE 0 END), 0) AS m_int_vol_before_exclude,
        COALESCE(SUM(CASE WHEN card_org = 'VISA' AND settle_country IN ('US', 'USA') AND transaction_type = 'authorization.clearing' AND resp_code = 'APPROVE' THEN -billing_amount ELSE 0 END), 0) AS v_dom_vol_before_exclude,
        COALESCE(SUM(CASE WHEN card_org = 'VISA' AND settle_country NOT IN ('US', 'USA') AND transaction_type = 'authorization.clearing' AND resp_code = 'APPROVE' THEN -billing_amount ELSE 0 END), 0) AS v_int_vol_before_exclude,
        COALESCE(SUM(CASE WHEN card_org = 'Master' AND settle_country IN ('US', 'USA') AND transaction_type = 'authorization.clearing' AND resp_code = 'APPROVE' AND settlement_id NOT IN (
            '234e26db-0e1d-424f-952b-053ab2e42d30', '82ff7fa6-8035-4c7b-8c18-ace860c3dfae', '711e7995-ea26-499f-a1c5-9e4faf15f31f', '5e974989-8792-401f-93b6-b107e0b46e51', '0af98098-eb5e-4d5b-a5ad-76c1b1c0ae72', 'a97006e9-2609-4e70-a165-2ae6b9f49689', 'ad861604-ff4f-4cd1-997e-fe613c67970e', '37959ee2-880f-49ea-8d74-976a69382c90', 'bebf7744-ed33-46cd-8ca6-40bc43d928eb', 'ece578c8-e8c1-46ec-83b9-116ea049a2e8', '69e04460-0cb4-4d9d-9001-2b786cfc3d7b', '7fa7ea4f-40fa-4153-9ec1-426f4b2c5470', 'cff4d9c4-ee01-43fa-9518-62872afbbe91', '160b403b-2a16-4b43-afac-a3b37916c968', '0fd4e8ed-e208-44e5-b463-ece053a915f3', '4a63f4ec-637e-4627-a668-5339fe64b9be'
        ) THEN -billing_amount ELSE 0 END), 0) AS m_dom_vol_after_exclude,
        COALESCE(SUM(CASE WHEN card_org = 'Master' AND settle_country NOT IN ('US', 'USA') AND transaction_type = 'authorization.clearing' AND resp_code = 'APPROVE' AND settlement_id NOT IN (
            '234e26db-0e1d-424f-952b-053ab2e42d30', '82ff7fa6-8035-4c7b-8c18-ace860c3dfae', '711e7995-ea26-499f-a1c5-9e4faf15f31f', '5e974989-8792-401f-93b6-b107e0b46e51', '0af98098-eb5e-4d5b-a5ad-76c1b1c0ae72', 'a97006e9-2609-4e70-a165-2ae6b9f49689', 'ad861604-ff4f-4cd1-997e-fe613c67970e', '37959ee2-880f-49ea-8d74-976a69382c90', 'bebf7744-ed33-46cd-8ca6-40bc43d928eb', 'ece578c8-e8c1-46ec-83b9-116ea049a2e8', '69e04460-0cb4-4d9d-9001-2b786cfc3d7b', '7fa7ea4f-40fa-4153-9ec1-426f4b2c5470', 'cff4d9c4-ee01-43fa-9518-62872afbbe91', '160b403b-2a16-4b43-afac-a3b37916c968', '0fd4e8ed-e208-44e5-b463-ece053a915f3', '4a63f4ec-637e-4627-a668-5339fe64b9be'
        ) THEN -billing_amount ELSE 0 END), 0) AS m_int_vol_after_exclude,
        COALESCE(SUM(CASE WHEN card_org = 'VISA' AND settle_country IN ('US', 'USA') AND transaction_type = 'authorization.clearing' AND resp_code = 'APPROVE' AND settlement_id NOT IN (
            '234e26db-0e1d-424f-952b-053ab2e42d30', '82ff7fa6-8035-4c7b-8c18-ace860c3dfae', '711e7995-ea26-499f-a1c5-9e4faf15f31f', '5e974989-8792-401f-93b6-b107e0b46e51', '0af98098-eb5e-4d5b-a5ad-76c1b1c0ae72', 'a97006e9-2609-4e70-a165-2ae6b9f49689', 'ad861604-ff4f-4cd1-997e-fe613c67970e', '37959ee2-880f-49ea-8d74-976a69382c90', 'bebf7744-ed33-46cd-8ca6-40bc43d928eb', 'ece578c8-e8c1-46ec-83b9-116ea049a2e8', '69e04460-0cb4-4d9d-9001-2b786cfc3d7b', '7fa7ea4f-40fa-4153-9ec1-426f4b2c5470', 'cff4d9c4-ee01-43fa-9518-62872afbbe91', '160b403b-2a16-4b43-afac-a3b37916c968', '0fd4e8ed-e208-44e5-b463-ece053a915f3', '4a63f4ec-637e-4627-a668-5339fe64b9be'
        ) THEN -billing_amount ELSE 0 END), 0) AS v_dom_vol_after_exclude,
        COALESCE(SUM(CASE WHEN card_org = 'VISA' AND settle_country NOT IN ('US', 'USA') AND transaction_type = 'authorization.clearing' AND resp_code = 'APPROVE' AND settlement_id NOT IN (
            '234e26db-0e1d-424f-952b-053ab2e42d30', '82ff7fa6-8035-4c7b-8c18-ace860c3dfae', '711e7995-ea26-499f-a1c5-9e4faf15f31f', '5e974989-8792-401f-93b6-b107e0b46e51', '0af98098-eb5e-4d5b-a5ad-76c1b1c0ae72', 'a97006e9-2609-4e70-a165-2ae6b9f49689', 'ad861604-ff4f-4cd1-997e-fe613c67970e', '37959ee2-880f-49ea-8d74-976a69382c90', 'bebf7744-ed33-46cd-8ca6-40bc43d928eb', 'ece578c8-e8c1-46ec-83b9-116ea049a2e8', '69e04460-0cb4-4d9d-9001-2b786cfc3d7b', '7fa7ea4f-40fa-4153-9ec1-426f4b2c5470', 'cff4d9c4-ee01-43fa-9518-62872afbbe91', '160b403b-2a16-4b43-afac-a3b37916c968', '0fd4e8ed-e208-44e5-b463-ece053a915f3', '4a63f4ec-637e-4627-a668-5339fe64b9be'
        ) THEN -billing_amount ELSE 0 END), 0) AS v_int_vol_after_exclude
    FROM dwm.dwm_bb_card_transaction_detail_v2_p t
    CROSS JOIN params p
    WHERE t.delete_time IS NULL
      AND t.original_completion_time >= p.start_time
      AND t.original_completion_time < p.end_time
      AND t.business_type IN ('Credit', 'Consumption')
)
SELECT
    settlement_rows,
    excluded_rows,
    m_dom_vol_before_exclude * 0.0021 AS m_dom_fee_before_exclude,
    m_dom_vol_after_exclude * 0.0021 AS m_dom_fee_after_exclude,
    (m_dom_vol_before_exclude - m_dom_vol_after_exclude) * 0.0021 AS m_dom_fee_excluded_delta,
    m_int_vol_before_exclude * 0.0111 AS m_int_fee_before_exclude,
    m_int_vol_after_exclude * 0.0111 AS m_int_fee_after_exclude,
    (m_int_vol_before_exclude - m_int_vol_after_exclude) * 0.0111 AS m_int_fee_excluded_delta,
    v_dom_vol_before_exclude * 0.0016 AS v_dom_fee_before_exclude,
    v_dom_vol_after_exclude * 0.0016 AS v_dom_fee_after_exclude,
    (v_dom_vol_before_exclude - v_dom_vol_after_exclude) * 0.0016 AS v_dom_fee_excluded_delta,
    v_int_vol_before_exclude * 0.0116 AS v_int_fee_before_exclude,
    v_int_vol_after_exclude * 0.0116 AS v_int_fee_after_exclude,
    (v_int_vol_before_exclude - v_int_vol_after_exclude) * 0.0116 AS v_int_fee_excluded_delta
FROM dwm_amount;

-- =========================================================
-- 4. Refund 三项：DWM 结果 vs 原始月度 SQL 源表结果
-- 两段查询使用同一月份、同一 postDate 条件，便于定位 DWM 是否漏数。
-- =========================================================

-- 4.1 基于 DWM 计算
WITH params AS (
    SELECT
        TIMESTAMP '2026-06-01 00:00:00' AS post_start,
        TIMESTAMP '2026-07-01 00:00:00' AS post_end
)
SELECT
    'DWM' AS source_layer,
    COUNT(DISTINCT CASE
        WHEN card_org = 'Master'
         AND settle_country NOT IN ('US', 'USA')
        THEN source_id
    END) AS master_int_refund_count,
    COUNT(DISTINCT CASE
        WHEN card_org = 'VISA'
         AND settle_country NOT IN ('US', 'USA')
        THEN source_id
    END) AS visa_int_refund_count,
    COUNT(DISTINCT CASE
        WHEN card_org IN ('Master', 'VISA')
         AND settle_country IN ('US', 'USA')
        THEN source_id
    END) AS dom_refund_count
FROM dwm.dwm_bb_card_transaction_detail_v2_p t
CROSS JOIN params p
WHERE t.delete_time IS NULL
  AND t.business_type = 'Credit'
  AND t.transaction_type = 'refund.clearing'
  AND t.resp_code = 'APPROVE'
  AND t.settlement_post_date >= p.post_start
  AND t.settlement_post_date < p.post_end
  AND t.settlement_id NOT IN (
      '234e26db-0e1d-424f-952b-053ab2e42d30',
      '82ff7fa6-8035-4c7b-8c18-ace860c3dfae',
      '711e7995-ea26-499f-a1c5-9e4faf15f31f',
      '5e974989-8792-401f-93b6-b107e0b46e51',
      '0af98098-eb5e-4d5b-a5ad-76c1b1c0ae72',
      'a97006e9-2609-4e70-a165-2ae6b9f49689',
      'ad861604-ff4f-4cd1-997e-fe613c67970e',
      '37959ee2-880f-49ea-8d74-976a69382c90',
      'bebf7744-ed33-46cd-8ca6-40bc43d928eb',
      'ece578c8-e8c1-46ec-83b9-116ea049a2e8',
      '69e04460-0cb4-4d9d-9001-2b786cfc3d7b',
      '7fa7ea4f-40fa-4153-9ec1-426f4b2c5470',
      'cff4d9c4-ee01-43fa-9518-62872afbbe91',
      '160b403b-2a16-4b43-afac-a3b37916c968',
      '0fd4e8ed-e208-44e5-b463-ece053a915f3',
      '4a63f4ec-637e-4627-a668-5339fe64b9be'
  );

-- =========================================================
-- 5. 只读模拟 DWM Refund 链路，不写入任何表
-- 用 WITH 复现 DWM：原始交易 -> settlement 直接关联 -> DWM 字段 -> 三项计数。
-- =========================================================
WITH params AS (
    SELECT
        TIMESTAMP '2026-05-01 00:00:00' AS post_start,
        TIMESTAMP '2026-06-01 00:00:00' AS post_end
),
refund_settlement AS (
    SELECT
        s.id::text AS settlement_id,
        s.transaction_id::text AS transaction_id,
        s.qbit_card_transaction_id::text AS qbit_card_transaction_id,
        s.transaction_type,
        s.billing_amount,
        s.raw_data,
        CAST(s.raw_data::json->>'postDate' AS timestamp) AS settlement_post_date,
        s.raw_data::json->>'responseCode' AS resp_code,
        RIGHT(s.raw_data::json->>'txnLocation', 2) AS settle_country
    FROM ods.ods_qbit_card_settlement s
    CROSS JOIN params p
    WHERE s.delete_time IS NULL
      AND s.provider = 'BlueBancCard'
      AND s.transaction_type = 'refund.clearing'
      AND s.raw_data::json->>'responseCode' = 'APPROVE'
      AND CAST(s.raw_data::json->>'postDate' AS timestamp) >= p.post_start
      AND CAST(s.raw_data::json->>'postDate' AS timestamp) < p.post_end
),
refund_transaction AS (
    SELECT
        t.id AS txn_id,
        t.source_id,
        t.card_transaction_id::text AS card_transaction_id,
        t.account_id::text AS account_id,
        t.country AS tx_country,
        t.type AS business_type,
        t.transaction_time,
        t.original_completion_time,
        t.business_code_list,
        t.remarks,
        t.card_id::text AS card_id,
        t.detail,
        c."type" AS card_org
    FROM public.quantum_card_transaction_extend t
    INNER JOIN public."qbitCard" c
        ON c."id" = t.card_id
    WHERE t.channel_provision = 'BLUEBANC'
      AND t.delete_time IS NULL
      AND t.type = 'Credit'
      AND c."type" IN ('Master', 'VISA')
      AND (t.detail IS NULL OR t.detail NOT LIKE 'AUTO CLASS CAR RENTAL%')
),
refund_dwm_shape AS (
    SELECT
        t.txn_id,
        t.source_id,
        t.card_transaction_id,
        t.account_id,
        t.business_type,
        t.card_org,
        t.tx_country,
        r.settle_country,
        r.resp_code,
        r.transaction_type,
        r.settlement_id,
        r.settlement_post_date,
        r.billing_amount
    FROM refund_transaction t
    INNER JOIN refund_settlement r
        ON t.card_transaction_id = r.qbit_card_transaction_id
),
refund_counts AS (
    SELECT
        COUNT(*) AS joined_rows,
        COUNT(DISTINCT source_id) AS distinct_refund_transactions,
        COUNT(DISTINCT CASE
            WHEN card_org = 'Master'
             AND settle_country NOT IN ('US', 'USA')
            THEN source_id
        END) AS master_int_refund_count,
        COUNT(DISTINCT CASE
            WHEN card_org = 'VISA'
             AND settle_country NOT IN ('US', 'USA')
            THEN source_id
        END) AS visa_int_refund_count,
        COUNT(DISTINCT CASE
            WHEN card_org IN ('Master', 'VISA')
             AND settle_country IN ('US', 'USA')
            THEN source_id
        END) AS dom_refund_count
    FROM refund_dwm_shape
)
SELECT *
FROM refund_counts;

-- 查看模拟 DWM 实际会写入的 Refund 明细。
WITH params AS (
    SELECT
        TIMESTAMP '2026-05-01 00:00:00' AS post_start,
        TIMESTAMP '2026-06-01 00:00:00' AS post_end
)
SELECT
    s.id AS settlement_id,
    t.id AS txn_id,
    t.source_id,
    t.card_transaction_id,
    c."type" AS card_org,
    RIGHT(s.raw_data::json->>'txnLocation', 2) AS settle_country,
    s.raw_data::json->>'responseCode' AS resp_code,
    s.raw_data::json->>'postDate' AS post_date,
    s.transaction_type,
    s.billing_amount
FROM ods.ods_qbit_card_settlement s
INNER JOIN public.quantum_card_transaction_extend t
    ON t.card_transaction_id::text = s.qbit_card_transaction_id
INNER JOIN public."qbitCard" c
    ON c."id" = t.card_id
CROSS JOIN params p
WHERE s.delete_time IS NULL
  AND s.provider = 'BlueBancCard'
  AND s.transaction_type = 'refund.clearing'
  AND s.raw_data::json->>'responseCode' = 'APPROVE'
  AND CAST(s.raw_data::json->>'postDate' AS timestamp) >= p.post_start
  AND CAST(s.raw_data::json->>'postDate' AS timestamp) < p.post_end
  AND t.channel_provision = 'BLUEBANC'
  AND t.delete_time IS NULL
  AND t.type = 'Credit'
  AND c."type" IN ('Master', 'VISA')
ORDER BY post_date, settlement_id
LIMIT 100;

-- 4.2 基于原始月度 SQL 的源表计算
WITH params AS (
    SELECT
        DATE '2026-06-01' AS post_start,
        DATE '2026-07-01' AS post_end
)
SELECT
    'ORIGINAL' AS source_layer,
    COUNT(DISTINCT CASE
        WHEN RIGHT(s.raw_data::json->>'txnLocation', 2) NOT IN ('US', 'USA')
         AND c."type" = 'Master'
        THEN t.source_id
    END) AS master_int_refund_count,
    COUNT(DISTINCT CASE
        WHEN RIGHT(s.raw_data::json->>'txnLocation', 2) NOT IN ('US', 'USA')
         AND c."type" = 'VISA'
        THEN t.source_id
    END) AS visa_int_refund_count,
    COUNT(DISTINCT CASE
        WHEN RIGHT(s.raw_data::json->>'txnLocation', 2) IN ('US', 'USA')
         AND c."type" IN ('Master', 'VISA')
        THEN t.source_id
    END) AS dom_refund_count
FROM public.quantum_card_transaction_extend t
INNER JOIN public."qbitCard" c
    ON c."id" = t.card_id
INNER JOIN ods.ods_qbit_card_settlement s
    ON t.card_transaction_id::text = s.qbit_card_transaction_id
CROSS JOIN params p
WHERE t.channel_provision = 'BLUEBANC'
  AND t.delete_time IS NULL
  AND t.type = 'Credit'
  AND c."type" IN ('Master', 'VISA')
  AND (t.detail IS NULL OR t.detail NOT LIKE 'AUTO CLASS CAR RENTAL%')
  AND s.delete_time IS NULL
  AND s.provider = 'BlueBancCard'
  AND s.transaction_type = 'refund.clearing'
  AND s.raw_data::json->>'responseCode' = 'APPROVE'
  AND CAST(s.raw_data::json->>'postDate' AS timestamp) >= p.post_start
  AND CAST(s.raw_data::json->>'postDate' AS timestamp) < p.post_end
  AND s.id NOT IN (
      '234e26db-0e1d-424f-952b-053ab2e42d30',
      '82ff7fa6-8035-4c7b-8c18-ace860c3dfae',
      '711e7995-ea26-499f-a1c5-9e4faf15f31f',
      '5e974989-8792-401f-93b6-b107e0b46e51',
      '0af98098-eb5e-4d5b-a5ad-76c1b1c0ae72',
      'a97006e9-2609-4e70-a165-2ae6b9f49689',
      'ad861604-ff4f-4cd1-997e-fe613c67970e',
      '37959ee2-880f-49ea-8d74-976a69382c90',
      'bebf7744-ed33-46cd-8ca6-40bc43d928eb',
      'ece578c8-e8c1-46ec-83b9-116ea049a2e8',
      '69e04460-0cb4-4d9d-9001-2b786cfc3d7b',
      '7fa7ea4f-40fa-4153-9ec1-426f4b2c5470',
      'cff4d9c4-ee01-43fa-9518-62872afbbe91',
      '160b403b-2a16-4b43-afac-a3b37916c968',
      '0fd4e8ed-e208-44e5-b463-ece053a915f3',
      '4a63f4ec-637e-4627-a668-5339fe64b9be'
  );
