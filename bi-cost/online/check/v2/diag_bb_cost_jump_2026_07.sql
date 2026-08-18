--********************************************************************--
-- Author:         WorkBuddy
-- Created Time:   2026-08-18
-- Description:    定位 BB 7 月（已完结月份）成本一夜 +26,404 的归因脚本
-- 背景：
--   DWS 层存在两套写入者，会互相覆盖：
--     A. 每日 DWS CDC (dws_online_bb_card_finance_daily_v2-cdc-v2-sql.sql, remarks='bb_v2_cdc')
--        - 按 DWM 近 24h update_time/delete_time 变更扫描，命中 (月份+账户) 后整月重算，upsert，不删除
--        - 口径：无 is_excluded_settlement 过滤；auth 计数无 business_code_list 1010 排除；
--                refund 计数要求 is_valid_settle=TRUE；rebate base 要求 settlement_match_type='card_transaction_id'
--     B. 月度 Batch 回刷 (dws_online_bb_card_finance_daily_v2-monthly-cdc-v2-sql.sql, remarks='bb_v2_batch_q3_refund_net_20260721')
--        - fn_delete 删上月 DWS 后整月重插，writeMode='insert'
--        - 口径：16 个黑名单 settlement 排除 (is_excluded_settlement)；auth 计数排除 1010；
--                refund 计数按 transaction_type='refund.clearing'（不要求 is_valid_settle）
-- 用法：在 ADBPG 上执行，逐段观察结果。
--********************************************************************--

-- ① 7 月 DWS 各行由谁写入（remarks 分组）→ 确认是否被 CDC 覆盖
SELECT report_date,
       remarks,
       COUNT(*)                                        AS row_cnt,
       SUM(total_net_amount)                           AS total_net,
       SUM(bb_channel_cashback_comm)                   AS cashback_base,
       SUM(cashback_income)                            AS cashback_income,
       SUM(cost_fixed_fee)                             AS fixed_fee,
       MAX(update_time)                                AS last_written
FROM dws.dws_bb_card_finance_daily_v2_p
WHERE report_date >= DATE '2026-07-01'
  AND report_date <  DATE '2026-08-01'
  AND delete_time IS NULL
GROUP BY report_date, remarks
ORDER BY remarks;

-- ② 同月同账户是否出现多行（sale/am 归属变更 → 新 id + 旧行残留 → 双计）
SELECT report_date,
       account_id,
       COUNT(*) AS row_cnt,
       STRING_AGG(DISTINCT COALESCE(sale_id, ''), ',') AS sale_ids,
       STRING_AGG(DISTINCT COALESCE(am_id, ''), ',')   AS am_ids,
       SUM(total_net_amount) AS total_net
FROM dws.dws_bb_card_finance_daily_v2_p
WHERE report_date >= DATE '2026-07-01'
  AND report_date <  DATE '2026-08-01'
  AND delete_time IS NULL
GROUP BY report_date, account_id
HAVING COUNT(*) > 1
ORDER BY row_cnt DESC
LIMIT 50;

-- ③ 近 24h 被 touch 的 7 月 DWM 行（DWS CDC 的触发源）
SELECT COUNT(*)          AS touched_rows,
       SUM(billing_amount) AS touched_amount,
       COUNT(*) FILTER (WHERE delete_time IS NOT NULL) AS deleted_rows
FROM dwm.dwm_bb_card_transaction_detail_v2_p
WHERE ( (update_time >= CURRENT_DATE - INTERVAL '1 day' AND update_time < CURRENT_DATE)
     OR (delete_time >= CURRENT_DATE - INTERVAL '1 day' AND delete_time < CURRENT_DATE) )
  AND ( (transaction_time        >= DATE '2026-07-01' AND transaction_time        < DATE '2026-08-01')
     OR (original_completion_time >= DATE '2026-07-01' AND original_completion_time < DATE '2026-08-01')
     OR (settlement_post_date     >= DATE '2026-07-01' AND settlement_post_date     < DATE '2026-08-01') );

-- ④ 16 个黑名单 settlement 在 7 月是否命中（batch 排除、CDC 未排除 → 口径漂移）
WITH excluded_settlements AS (
    SELECT unnest(ARRAY[
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
    ]) AS settlement_id
)
SELECT COUNT(*) AS excluded_settle_rows,
       SUM(billing_amount) AS excluded_settle_amount
FROM dwm.dwm_bb_card_transaction_detail_v2_p d
WHERE d.delete_time IS NULL
  AND EXISTS (SELECT 1 FROM excluded_settlements e WHERE e.settlement_id = d.settlement_id)
  AND ( (d.transaction_time        >= DATE '2026-07-01' AND d.transaction_time        < DATE '2026-08-01')
     OR (d.original_completion_time >= DATE '2026-07-01' AND d.original_completion_time < DATE '2026-08-01')
     OR (d.settlement_post_date     >= DATE '2026-07-01' AND d.settlement_post_date     < DATE '2026-08-01') );

-- ⑤ 复现 v4 查询 7 月成本，并按大类拆解（与"实际" 432,056 对比，定位增量来自哪类费用）
WITH bb_base AS (
    SELECT
        COALESCE(SUM(m_dom_auth_count * 0.1090), 0) AS auth_dom_mc,
        COALESCE(SUM(m_int_auth_count * 0.4845), 0) AS auth_int_mc,
        COALESCE(SUM(v_dom_auth_count * 0.0725), 0) AS auth_dom_visa,
        COALESCE(SUM(v_int_auth_count * 0.4770), 0) AS auth_int_visa,
        COALESCE(SUM(av_m_dom_count * 0.1090), 0)   AS av_dom_mc,
        COALESCE(SUM(av_m_int_count * 0.4845), 0)   AS av_int_mc,
        COALESCE(SUM(av_v_dom_count * 0.0725), 0)   AS av_dom_visa,
        COALESCE(SUM(av_v_int_count * 0.4770), 0)   AS av_int_visa,
        COALESCE(SUM(m_int_reversal_count * 0.7190), 0) AS rev_int_mc,
        COALESCE(SUM(v_int_reversal_count * 0.7140), 0) AS rev_int_visa,
        COALESCE(SUM(dom_reversal_count * 0.1780), 0)   AS rev_dom,
        COALESCE(SUM(m_int_refund_count * 0.4845), 0)   AS refund_int_mc,
        COALESCE(SUM(v_int_refund_count * 0.4770), 0)   AS refund_int_visa,
        COALESCE(SUM(dom_refund_count * 0.1090), 0)     AS refund_dom,
        COALESCE(SUM(m_int_decline_count * 0.3595), 0)  AS decl_int_mc,
        COALESCE(SUM(v_int_decline_count * 0.3570), 0)  AS decl_int_visa,
        COALESCE(SUM(dom_decline_count * 0.0890), 0)    AS decl_dom,
        COALESCE(SUM(ac_m_int_decline_count * 0.3595), 0) AS ac_decl_int_mc,
        COALESCE(SUM(ac_v_int_decline_count * 0.3570), 0) AS ac_decl_int_visa,
        COALESCE(SUM(ac_dom_decline_count * 0.0890), 0)   AS ac_decl_dom,
        COALESCE(SUM(m_dom_clearing_vol * 0.0021), 0)  AS vol_dom_mc,
        COALESCE(SUM(m_int_clearing_vol * 0.0111), 0)  AS vol_int_mc,
        COALESCE(SUM(v_dom_clearing_vol * 0.0016), 0)  AS vol_dom_visa,
        COALESCE(SUM(v_int_clearing_vol * 0.0116), 0)  AS vol_int_visa,
        COALESCE(SUM(total_net_amount), 0)             AS total_net,
        COALESCE(SUM(active_card_count * 0.1), 0)      AS active_card_fee,
        COALESCE(SUM(cost_fixed_fee), 0)               AS fixed_fee
    FROM dws.dws_bb_card_finance_daily_v2_p
    WHERE report_date >= DATE '2026-07-01'
      AND report_date <  DATE '2026-08-01'
      AND delete_time IS NULL
), vol AS (
    SELECT CASE
        WHEN total_net = 0 THEN 0
        WHEN total_net <= 5000000 THEN total_net * 0.0055
        WHEN total_net <= 10000000 THEN 5000000 * 0.0055 + (total_net - 5000000) * 0.0045
        ELSE 5000000 * 0.0055 + 5000000 * 0.0045 + (total_net - 10000000) * 0.004
    END AS volume_fee_cost
    FROM bb_base
)
SELECT
    (SELECT auth_dom_mc + auth_int_mc + auth_dom_visa + auth_int_visa
       + av_dom_mc + av_int_mc + av_dom_visa + av_int_visa FROM bb_base) AS auth_count_fee,
    (SELECT rev_int_mc + rev_int_visa + rev_dom + refund_int_mc + refund_int_visa + refund_dom FROM bb_base) AS reversal_refund_fee,
    (SELECT decl_int_mc + decl_int_visa + decl_dom + ac_decl_int_mc + ac_decl_int_visa + ac_decl_dom FROM bb_base) AS decline_fee,
    (SELECT vol_dom_mc + vol_int_mc + vol_dom_visa + vol_int_visa FROM bb_base) AS dollar_vol_fee,
    (SELECT volume_fee_cost FROM vol) AS volume_fee_cost,
    (SELECT active_card_fee FROM bb_base) AS active_card_fee,
    (SELECT fixed_fee FROM bb_base) AS fixed_fee,
    (SELECT auth_dom_mc + auth_int_mc + auth_dom_visa + auth_int_visa
       + av_dom_mc + av_int_mc + av_dom_visa + av_int_visa
       + rev_int_mc + rev_int_visa + rev_dom + refund_int_mc + refund_int_visa + refund_dom
       + decl_int_mc + decl_int_visa + decl_dom + ac_decl_int_mc + ac_decl_int_visa + ac_decl_dom
       + vol_dom_mc + vol_int_mc + vol_dom_visa + vol_int_visa
       + volume_fee_cost + active_card_fee + fixed_fee FROM bb_base, vol) AS v4_total;
