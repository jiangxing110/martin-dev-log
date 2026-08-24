--********************************************************************--
-- Author:         martinJiang
-- Created Time:   2026-08-23 22:58:00
-- Description:    BB v2 DWS 按月分批重算过程
-- Notes:
--   1. 数据库内循环处理 2026-01-01 至 CURRENT_DATE（不包含当天）。
--   2. 每个月先删除普通行，再 INSERT，最后 COMMIT。
--   3. active_card 和 channel_fixed_fee 特殊行由独立过程/CDC 脚本维护，不在本过程删除。
--   4. 用于替代一次性全历史 Flink INSERT，避免 TaskManager heartbeat timeout。
--********************************************************************--

CREATE OR REPLACE PROCEDURE dws.sp_rebuild_bb_card_finance_daily_v2_monthly()
LANGUAGE plpgsql
AS $procedure$
DECLARE
    v_curr_start DATE := DATE '2026-01-01';
    v_curr_end   DATE;
    v_end_date   DATE := CURRENT_DATE;
BEGIN
    WHILE v_curr_start < v_end_date LOOP
        v_curr_end := LEAST((v_curr_start + INTERVAL '1 month')::date, v_end_date);

        SET LOCAL synchronous_commit = off;
        SET LOCAL work_mem = '256MB';

        RAISE NOTICE 'BB DWS monthly rebuild: % to %', v_curr_start, v_curr_end;

        DELETE FROM dws.dws_bb_card_finance_daily_v2_p AS target
        WHERE target.report_date >= v_curr_start
          AND target.report_date < v_curr_end
          AND (target.special_fee_type IS NULL
               OR target.special_fee_type NOT IN ('ACTIVE_CARD_ACCOUNT_FEE', 'CHANNEL_FIXED_FEE'));

        INSERT INTO dws.dws_bb_card_finance_daily_v2_p (
            id, report_date, account_id, account_type, account_category, system_type,
            m_dom_auth_count, m_int_auth_count, v_dom_auth_count, v_int_auth_count,
            m_int_decline_count, v_int_decline_count, dom_decline_count,
            ac_m_int_decline_count, ac_v_int_decline_count, ac_dom_decline_count,
            m_int_reversal_count, v_int_reversal_count, dom_reversal_count,
            m_int_refund_count, v_int_refund_count, dom_refund_count,
            av_m_dom_count, av_m_int_count, av_v_dom_count, av_v_int_count,
            m_dom_clearing_vol, m_int_clearing_vol, v_dom_clearing_vol, v_int_clearing_vol,
            bb_rebate_base_amt, bb_channel_cashback_comm, active_card_count,
            total_net_amount, volume_fee_cost, cashback_rate, cashback_income, cost_fixed_fee,
            special_fee_type, sale_id, am_id, version, remarks, create_time, update_time, delete_time
        )
        WITH tx_rows AS (
            SELECT t.*, e.report_date, e.metric_basis
            FROM dwm.dwm_bb_card_transaction_detail_v2_p t
            CROSS JOIN LATERAL (
                VALUES
                    (t.transaction_time::date, 'txn_time'),
                    (t.original_completion_time::date, 'completion_time'),
                    (t.settlement_post_date::date, 'post_date')
            ) e(report_date, metric_basis)
            WHERE t.delete_time IS NULL
              AND (
                    (t.transaction_time >= v_curr_start AND t.transaction_time < v_curr_end)
                 OR (t.original_completion_time >= v_curr_start AND t.original_completion_time < v_curr_end)
                 OR (t.settlement_post_date >= v_curr_start AND t.settlement_post_date < v_curr_end)
              )
              AND e.report_date >= v_curr_start
              AND e.report_date < v_curr_end
        ),
        tx AS (
            SELECT
                report_date, account_id, account_type, account_category, system_type,
                sale_id, am_id,
                COUNT(DISTINCT source_id) FILTER (WHERE metric_basis = 'txn_time' AND business_type = 'Consumption' AND business_code_list NOT LIKE '%1010%' AND card_org = 'Master' AND is_dom IS TRUE AND resp_code = 'APPROVE' AND (is_clearing IS TRUE OR is_reversal IS TRUE) AND COALESCE(settlement_id, '') NOT IN ('234e26db-0e1d-424f-952b-053ab2e42d30', '82ff7fa6-8035-4c7b-8c18-ace860c3dfae', '711e7995-ea26-499f-a1c5-9e4faf15f31f', '5e974989-8792-401f-93b6-b107e0b46e51', '0af98098-eb5e-4d5b-a5ad-76c1b1c0ae72', 'a97006e9-2609-4e70-a165-2ae6b9f49689', 'ad861604-ff4f-4cd1-997e-fe613c67970e', '37959ee2-880f-49ea-8d74-976a69382c90', 'bebf7744-ed33-46cd-8ca6-40bc43d928eb', 'ece578c8-e8c1-46ec-83b9-116ea049a2e8', '69e04460-0cb4-4d9d-9001-2b786cfc3d7b', '7fa7ea4f-40fa-4153-9ec1-426f4b2c5470', 'cff4d9c4-ee01-43fa-9518-62872afbbe91', '160b403b-2a16-4b43-afac-a3b37916c968', '0fd4e8ed-e208-44e5-b463-ece053a915f3', '4a63f4ec-637e-4627-a668-5339fe64b9be')) AS m_dom_auth_count,
                COUNT(DISTINCT source_id) FILTER (WHERE metric_basis = 'txn_time' AND business_type = 'Consumption' AND business_code_list NOT LIKE '%1010%' AND card_org = 'Master' AND is_dom IS FALSE AND resp_code = 'APPROVE' AND (is_clearing IS TRUE OR is_reversal IS TRUE)) AS m_int_auth_count,
                COUNT(DISTINCT source_id) FILTER (WHERE metric_basis = 'txn_time' AND business_type = 'Consumption' AND business_code_list NOT LIKE '%1010%' AND card_org = 'VISA' AND is_dom IS TRUE AND resp_code = 'APPROVE' AND (is_clearing IS TRUE OR is_reversal IS TRUE)) AS v_dom_auth_count,
                COUNT(DISTINCT source_id) FILTER (WHERE metric_basis = 'txn_time' AND business_type = 'Consumption' AND business_code_list NOT LIKE '%1010%' AND card_org = 'VISA' AND is_dom IS FALSE AND resp_code = 'APPROVE' AND (is_clearing IS TRUE OR is_reversal IS TRUE)) AS v_int_auth_count,
                COUNT(*) FILTER (WHERE metric_basis = 'txn_time' AND business_type = 'Consumption' AND business_code_list LIKE '%1010%' AND card_org = 'Master' AND tx_country IN ('US', 'USA') AND (resp_code IS NULL OR resp_code <> 'DECLINE')) AS av_m_dom_count,
                COUNT(*) FILTER (WHERE metric_basis = 'txn_time' AND business_type = 'Consumption' AND business_code_list LIKE '%1010%' AND card_org = 'Master' AND tx_country NOT IN ('US', 'USA') AND (resp_code IS NULL OR resp_code <> 'DECLINE')) AS av_m_int_count,
                COUNT(*) FILTER (WHERE metric_basis = 'txn_time' AND business_type = 'Consumption' AND business_code_list LIKE '%1010%' AND card_org = 'VISA' AND tx_country IN ('US', 'USA') AND (resp_code IS NULL OR resp_code <> 'DECLINE')) AS av_v_dom_count,
                COUNT(*) FILTER (WHERE metric_basis = 'txn_time' AND business_type = 'Consumption' AND business_code_list LIKE '%1010%' AND card_org = 'VISA' AND tx_country NOT IN ('US', 'USA') AND (resp_code IS NULL OR resp_code <> 'DECLINE')) AS av_v_int_count,
                COUNT(*) FILTER (WHERE metric_basis = 'txn_time' AND business_type = 'Consumption' AND card_org = 'Master' AND tx_country NOT IN ('US', 'USA') AND resp_code = 'APPROVE' AND reason_code = 'APPROVE' AND transaction_type = 'authorization.reversal') AS m_int_reversal_count,
                COUNT(*) FILTER (WHERE metric_basis = 'txn_time' AND business_type = 'Consumption' AND card_org = 'VISA' AND tx_country NOT IN ('US', 'USA') AND resp_code = 'APPROVE' AND reason_code = 'APPROVE' AND transaction_type = 'authorization.reversal') AS v_int_reversal_count,
                COUNT(*) FILTER (WHERE metric_basis = 'txn_time' AND business_type = 'Consumption' AND tx_country IN ('US', 'USA') AND resp_code = 'APPROVE' AND reason_code = 'APPROVE' AND transaction_type = 'authorization.reversal') AS dom_reversal_count,
                COUNT(*) FILTER (WHERE metric_basis = 'post_date' AND business_type = 'Credit' AND card_org = 'Master' AND settle_country NOT IN ('US', 'USA') AND is_refund IS TRUE AND resp_code = 'APPROVE') AS m_int_refund_count,
                COUNT(*) FILTER (WHERE metric_basis = 'post_date' AND business_type = 'Credit' AND card_org = 'VISA' AND settle_country NOT IN ('US', 'USA') AND is_refund IS TRUE AND resp_code = 'APPROVE') AS v_int_refund_count,
                COUNT(*) FILTER (WHERE metric_basis = 'post_date' AND business_type = 'Credit' AND settle_country NOT IN ('US', 'USA') AND is_refund IS TRUE AND resp_code = 'APPROVE') AS dom_refund_count,
                SUM(-billing_amount) FILTER (WHERE metric_basis = 'completion_time' AND business_type IN ('Credit', 'Consumption') AND card_org = 'Master' AND settle_country IN ('US', 'USA') AND transaction_type IN ('authorization.clearing', 'refund.clearing') AND resp_code = 'APPROVE') AS m_dom_clearing_vol,
                SUM(-billing_amount) FILTER (WHERE metric_basis = 'completion_time' AND business_type IN ('Credit', 'Consumption') AND card_org = 'Master' AND settle_country NOT IN ('US', 'USA') AND transaction_type IN ('authorization.clearing', 'refund.clearing') AND resp_code = 'APPROVE') AS m_int_clearing_vol,
                SUM(-billing_amount) FILTER (WHERE metric_basis = 'completion_time' AND business_type IN ('Credit', 'Consumption') AND card_org = 'VISA' AND settle_country IN ('US', 'USA') AND transaction_type IN ('authorization.clearing', 'refund.clearing') AND resp_code = 'APPROVE') AS v_dom_clearing_vol,
                SUM(-billing_amount) FILTER (WHERE metric_basis = 'completion_time' AND business_type IN ('Credit', 'Consumption') AND card_org = 'VISA' AND settle_country NOT IN ('US', 'USA') AND transaction_type IN ('authorization.clearing', 'refund.clearing') AND resp_code = 'APPROVE') AS v_int_clearing_vol,
                SUM(-billing_amount) FILTER (WHERE metric_basis = 'completion_time' AND business_type IN ('Credit', 'Consumption') AND card_org IN ('Master', 'VISA') AND transaction_type IN ('authorization.clearing', 'refund.clearing') AND settlement_match_type = 'card_transaction_id' AND resp_code = 'APPROVE') AS bb_rebate_base_amt
            FROM tx_rows
            GROUP BY report_date, account_id, account_type, account_category, system_type, sale_id, am_id
        ),
        auth AS (
            SELECT
                auth_time::date AS report_date, account_id, account_type, account_category, system_type, sale_id, am_id,
                COUNT(DISTINCT auth_txn_guid) FILTER (WHERE is_decline IS TRUE AND is_account_verification IS FALSE AND is_excluded_request IS FALSE AND card_org = 'Master' AND is_dom IS FALSE) AS m_int_decline_count,
                COUNT(DISTINCT auth_txn_guid) FILTER (WHERE is_decline IS TRUE AND is_account_verification IS FALSE AND is_excluded_request IS FALSE AND card_org = 'VISA' AND is_dom IS FALSE) AS v_int_decline_count,
                COUNT(DISTINCT auth_txn_guid) FILTER (WHERE is_decline IS TRUE AND is_account_verification IS FALSE AND is_excluded_request IS FALSE AND is_dom IS TRUE) AS dom_decline_count,
                COUNT(DISTINCT auth_txn_guid) FILTER (WHERE is_decline IS TRUE AND is_account_verification IS TRUE AND is_excluded_request IS FALSE AND card_org = 'Master' AND is_dom IS FALSE) AS ac_m_int_decline_count,
                COUNT(DISTINCT auth_txn_guid) FILTER (WHERE is_decline IS TRUE AND is_account_verification IS TRUE AND is_excluded_request IS FALSE AND card_org = 'VISA' AND is_dom IS FALSE) AS ac_v_int_decline_count,
                COUNT(DISTINCT auth_txn_guid) FILTER (WHERE is_decline IS TRUE AND is_account_verification IS TRUE AND is_excluded_request IS FALSE AND is_dom IS TRUE) AS ac_dom_decline_count
            FROM dwm.dwm_bb_card_auth_detail_v2_p
            WHERE delete_time IS NULL AND auth_time >= v_curr_start AND auth_time < v_curr_end
            GROUP BY auth_time::date, account_id, account_type, account_category, system_type, sale_id, am_id
        ),
        base AS (
            SELECT
                COALESCE(t.report_date, a.report_date) AS report_date,
                COALESCE(t.account_id, a.account_id) AS account_id,
                COALESCE(t.account_type, a.account_type) AS account_type,
                COALESCE(t.account_category, a.account_category) AS account_category,
                COALESCE(t.system_type, a.system_type) AS system_type,
                COALESCE(t.sale_id, a.sale_id, '') AS sale_id,
                COALESCE(t.am_id, a.am_id, '') AS am_id,
                COALESCE(t.m_dom_auth_count, 0)::int AS m_dom_auth_count,
                COALESCE(t.m_int_auth_count, 0)::int AS m_int_auth_count,
                COALESCE(t.v_dom_auth_count, 0)::int AS v_dom_auth_count,
                COALESCE(t.v_int_auth_count, 0)::int AS v_int_auth_count,
                COALESCE(a.m_int_decline_count, 0)::int AS m_int_decline_count,
                COALESCE(a.v_int_decline_count, 0)::int AS v_int_decline_count,
                COALESCE(a.dom_decline_count, 0)::int AS dom_decline_count,
                COALESCE(a.ac_m_int_decline_count, 0)::int AS ac_m_int_decline_count,
                COALESCE(a.ac_v_int_decline_count, 0)::int AS ac_v_int_decline_count,
                COALESCE(a.ac_dom_decline_count, 0)::int AS ac_dom_decline_count,
                COALESCE(t.m_int_reversal_count, 0)::int AS m_int_reversal_count,
                COALESCE(t.v_int_reversal_count, 0)::int AS v_int_reversal_count,
                COALESCE(t.dom_reversal_count, 0)::int AS dom_reversal_count,
                COALESCE(t.m_int_refund_count, 0)::int AS m_int_refund_count,
                COALESCE(t.v_int_refund_count, 0)::int AS v_int_refund_count,
                COALESCE(t.dom_refund_count, 0)::int AS dom_refund_count,
                COALESCE(t.av_m_dom_count, 0)::int AS av_m_dom_count,
                COALESCE(t.av_m_int_count, 0)::int AS av_m_int_count,
                COALESCE(t.av_v_dom_count, 0)::int AS av_v_dom_count,
                COALESCE(t.av_v_int_count, 0)::int AS av_v_int_count,
                COALESCE(t.m_dom_clearing_vol, 0)::numeric(20,4) AS m_dom_clearing_vol,
                COALESCE(t.m_int_clearing_vol, 0)::numeric(20,4) AS m_int_clearing_vol,
                COALESCE(t.v_dom_clearing_vol, 0)::numeric(20,4) AS v_dom_clearing_vol,
                COALESCE(t.v_int_clearing_vol, 0)::numeric(20,4) AS v_int_clearing_vol,
                COALESCE(t.bb_rebate_base_amt, 0)::numeric(20,4) AS bb_rebate_base_amt,
                (COALESCE(t.m_dom_clearing_vol, 0) + COALESCE(t.m_int_clearing_vol, 0) + COALESCE(t.v_dom_clearing_vol, 0) + COALESCE(t.v_int_clearing_vol, 0))::numeric(20,4) AS total_net_amount
            FROM tx t
            FULL JOIN auth a
              ON t.report_date = a.report_date
             AND t.account_id = a.account_id
             AND COALESCE(t.sale_id, '') = COALESCE(a.sale_id, '')
             AND COALESCE(t.am_id, '') = COALESCE(a.am_id, '')
        ),
        month_total AS (
            SELECT COALESCE(SUM(total_net_amount), 0)::numeric(20,4) AS total_net_amount FROM base
        ),
        month_cost AS (
            SELECT
                total_net_amount,
                CASE
                    WHEN total_net_amount <= 0 THEN 0
                    WHEN total_net_amount <= 5000000 THEN total_net_amount * 0.0055
                    WHEN total_net_amount <= 10000000 THEN 5000000 * 0.0055 + (total_net_amount - 5000000) * 0.0045
                    ELSE 5000000 * 0.0055 + 5000000 * 0.0045 + (total_net_amount - 10000000) * 0.004
                END::numeric(20,4) AS volume_fee_cost
            FROM month_total
        ),
        cash_rate AS (
            SELECT COALESCE(
                MAX(amount) FILTER (WHERE statistics_time >= v_curr_start AND statistics_time < v_curr_end AND detail <> 'DEFAULT_FALLBACK'),
                MAX(amount) FILTER (WHERE detail = 'DEFAULT_FALLBACK'),
                0.02059391
            )::numeric(20,8) AS rate
            FROM ods.ods_bi_month_tag
            WHERE delete_time IS NULL AND provider = 'BB' AND product_line = 'BB' AND tag = 'BB_CASH_RATE'
        )
        SELECT
            abs(('x' || substr(md5(concat(report_date::text, ':', account_id, ':', sale_id, ':', am_id)), 1, 15))::bit(60)::bigint),
            report_date, account_id, account_type, account_category, system_type,
            m_dom_auth_count, m_int_auth_count, v_dom_auth_count, v_int_auth_count,
            m_int_decline_count, v_int_decline_count, dom_decline_count,
            ac_m_int_decline_count, ac_v_int_decline_count, ac_dom_decline_count,
            m_int_reversal_count, v_int_reversal_count, dom_reversal_count,
            m_int_refund_count, v_int_refund_count, dom_refund_count,
            av_m_dom_count, av_m_int_count, av_v_dom_count, av_v_int_count,
            m_dom_clearing_vol, m_int_clearing_vol, v_dom_clearing_vol, v_int_clearing_vol,
            bb_rebate_base_amt, bb_rebate_base_amt, 0,
            total_net_amount,
            CASE WHEN mc.total_net_amount = 0 THEN 0 ELSE total_net_amount / mc.total_net_amount * mc.volume_fee_cost END::numeric(20,4),
            cr.rate,
            (bb_rebate_base_amt * cr.rate)::numeric(20,4),
            0, 'NORMAL', sale_id, am_id, 1, 'bb_v2_monthly_procedure', now(), now(), NULL
        FROM base
        CROSS JOIN month_cost mc
        CROSS JOIN cash_rate cr;

        COMMIT;
        v_curr_start := v_curr_end;
    END LOOP;
END;
$procedure$;

-- 执行：CALL dws.sp_rebuild_bb_card_finance_daily_v2_monthly();
