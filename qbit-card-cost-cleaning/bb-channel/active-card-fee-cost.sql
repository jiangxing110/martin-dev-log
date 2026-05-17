-- 1.每日活跃卡fee归零
UPDATE dws_bb_card_finance_daily_p
SET active_card_count = 0,
    update_time = NOW(),
    version = version + 1
WHERE report_date >= DATE '2026-04-01'
  AND report_date < DATE '2026-05-01';

-- 2.写入月活跃卡fee 数据
INSERT INTO dws_bb_card_finance_daily_p (
    id,
    report_date,
    account_id,
    version,
    update_time,

    m_dom_auth_count,
    m_int_auth_count,
    v_dom_auth_count,
    v_int_auth_count,
    m_int_decline_count,
    v_int_decline_count,
    dom_decline_count,
    m_int_reversal_count,
    v_int_reversal_count,
    dom_reversal_count,
    m_int_refund_count,
    v_int_refund_count,
    dom_refund_count,
    av_m_dom_count,
    av_m_int_count,
    av_v_dom_count,
    av_v_int_count,

    m_dom_clearing_vol,
    m_int_clearing_vol,
    v_dom_clearing_vol,
    v_int_clearing_vol,
    bb_rebate_base_amt,
    bb_channel_cashback_comm,

    active_card_count
)
SELECT
    -- ✅ 月首ID
    ('9'
     || to_char(month_dt, 'YYYYMMDD')
     || abs(hashtext(account_id::text))
    )::int8,

    -- ✅ report_date 直接用月第一天
    month_dt,
    account_id,
    1,
    NOW(),

    -- 全部置0
    0,0,0,0,
    0,0,0,
    0,0,0,
    0,0,0,
    0,0,0,0,

    0,0,0,0,
    0,0,

    -- ✅ 月活（核心）
    COUNT(DISTINCT card_id)

FROM (
    SELECT
        date_trunc('month',
            (transaction_time AT TIME ZONE 'Asia/Shanghai')::date
        )::date AS month_dt,
        account_id,
        card_id
    FROM dwm_bb_card_transaction_detail_p
    WHERE transaction_time >= TIMESTAMP '2026-04-01 00:00:00'
      AND transaction_time < TIMESTAMP '2026-05-01 00:00:00'
      AND delete_time IS NULL
) t
GROUP BY month_dt, account_id;