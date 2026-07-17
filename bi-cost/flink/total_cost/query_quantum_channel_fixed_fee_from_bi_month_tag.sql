--********************************************************************--
-- Author:         Codex
-- Created Time:   2026-07-16
-- Description:    量子卡渠道固定成本 bi_month_tag 原始配置查询
-- Usage:
--   1. 修改 params 中的 start_date / end_date。
--   2. end_date 左闭右开，不包含当天。
--   3. 固定成本只看 ods.ods_bi_month_tag: tag = 'CHANNEL_COST'。
--   4. provider 映射：BB=BB, QI=IQ, SL=LS。
--   5. 每月优先取当月正式配置；没有当月配置时，才取 2099-01 / DEFAULT_FALLBACK 兜底配置。
--********************************************************************--

WITH RECURSIVE params AS (
    SELECT
        DATE '2026-05-01' AS start_date,
        DATE '2026-06-01' AS end_date
),
month_scope AS (
    SELECT DATE_TRUNC('month', start_date)::date AS report_month
    FROM params

    UNION ALL

    SELECT (report_month + INTERVAL '1 month')::date
    FROM month_scope
    CROSS JOIN params
    WHERE report_month + INTERVAL '1 month' < params.end_date
),
channel_map AS (
    SELECT *
    FROM (
        VALUES
            ('BB', 'BB'),
            ('QI', 'IQ'),
            ('SL', 'LS')
    ) AS c(channel_name, provider)
),
raw_fixed_fee AS (
    SELECT
        id,
        provider,
        product_line,
        tag,
        DATE_TRUNC('month', statistics_time)::date AS statistics_month,
        statistics_time,
        amount,
        detail,
        remarks,
        update_time,
        delete_time
    FROM ods.ods_bi_month_tag
    WHERE delete_time IS NULL
      AND tag = 'CHANNEL_COST'
      AND provider IN (SELECT provider FROM channel_map)
),
candidate_fixed_fee AS (
    SELECT
        m.report_month,
        c.channel_name,
        c.provider,
        r.id AS bi_month_tag_id,
        r.product_line,
        r.statistics_month,
        r.statistics_time,
        r.amount AS month_fixed_fee,
        r.detail,
        r.remarks,
        r.update_time,
        CASE
            WHEN r.statistics_month = m.report_month THEN 'MONTH_CONFIG'
            WHEN r.statistics_month = DATE '2099-01-01' OR r.detail = 'DEFAULT_FALLBACK' THEN 'DEFAULT_FALLBACK'
            ELSE 'OTHER'
        END AS source_type,
        ROW_NUMBER() OVER (
            PARTITION BY m.report_month, c.provider
            ORDER BY
                CASE
                    WHEN r.statistics_month = m.report_month THEN 1
                    WHEN r.statistics_month = DATE '2099-01-01' OR r.detail = 'DEFAULT_FALLBACK' THEN 2
                    ELSE 9
                END,
                r.update_time DESC,
                r.id DESC
        ) AS rn
    FROM month_scope m
    CROSS JOIN channel_map c
    LEFT JOIN raw_fixed_fee r
        ON r.provider = c.provider
       AND (
              r.statistics_month = m.report_month
           OR r.statistics_month = DATE '2099-01-01'
           OR r.detail = 'DEFAULT_FALLBACK'
       )
)
SELECT
    report_month,
    channel_name,
    provider,
    COALESCE(source_type, 'MISSING') AS source_type,
    bi_month_tag_id,
    product_line,
    statistics_month,
    statistics_time,
    CAST(COALESCE(month_fixed_fee, 0) AS NUMERIC(20, 4)) AS month_fixed_fee,
    detail,
    remarks,
    update_time
FROM candidate_fixed_fee
WHERE rn = 1
ORDER BY report_month, channel_name;
