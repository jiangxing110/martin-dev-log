-- QI 的 `ods_bi_month_tag` 月度系数种子数据
-- 说明:
-- 1. 2026-01 ~ 2026-06 为正式月度配置
-- 2. 2022-01 为兜底配置，供月度配置暂缺时使用
-- 3. tag 名称按 rate 语义做了可读化映射，方便后续 SQL 统一引用

INSERT INTO "ods"."ods_bi_month_tag"
    ("id", "create_time", "update_time", "delete_time", "version", "tag", "statistics_time", "amount", "remarks", "detail", "account_type", "provider", "product_line")
VALUES
    -- 2026-01
    (20260101, NOW(), NOW(), NULL, 1, 'QI_ISSUER_CARD_SERVICE_RATE',                '2026-01-01 00:00:00+08', 0.9749, 'QI monthly coefficient seed', '2026-01', 'fullCustomer', 'IQ', 'QI'),
    (20260102, NOW(), NOW(), NULL, 1, 'QI_ISSUER_AUTH_CLEARING_SETTLEMENT_RATE',    '2026-01-01 00:00:00+08', 0.9019, 'QI monthly coefficient seed', '2026-01', 'fullCustomer', 'IQ', 'QI'),
    (20260103, NOW(), NOW(), NULL, 1, 'QI_ISSUER_AUTH_CLEARING_SETTLEMENT_VIP_RATE', '2026-01-01 00:00:00+08', 1.0636, 'QI monthly coefficient seed', '2026-01', 'fullCustomer', 'IQ', 'QI'),
    (20260104, NOW(), NOW(), NULL, 1, 'QI_VRM_RATE',                               '2026-01-01 00:00:00+08', 1.3434, 'QI monthly coefficient seed', '2026-01', 'fullCustomer', 'IQ', 'QI'),
    (20260105, NOW(), NOW(), NULL, 1, 'QI_CROSSBORDER_FX_RATE',                     '2026-01-01 00:00:00+08', 0.9904, 'QI monthly coefficient seed', '2026-01', 'fullCustomer', 'IQ', 'QI'),
    (20260106, NOW(), NOW(), NULL, 1, 'QI_DCSF_RATE',                               '2026-01-01 00:00:00+08', 1.1263, 'QI monthly coefficient seed', '2026-01', 'fullCustomer', 'IQ', 'QI'),

    -- 2026-02
    (20260201, NOW(), NOW(), NULL, 1, 'QI_ISSUER_CARD_SERVICE_RATE',                '2026-02-01 00:00:00+08', 0.9749, 'QI monthly coefficient seed', '2026-02', 'fullCustomer', 'IQ', 'QI'),
    (20260202, NOW(), NOW(), NULL, 1, 'QI_ISSUER_AUTH_CLEARING_SETTLEMENT_RATE',    '2026-02-01 00:00:00+08', 0.9019, 'QI monthly coefficient seed', '2026-02', 'fullCustomer', 'IQ', 'QI'),
    (20260203, NOW(), NOW(), NULL, 1, 'QI_ISSUER_AUTH_CLEARING_SETTLEMENT_VIP_RATE', '2026-02-01 00:00:00+08', 1.0636, 'QI monthly coefficient seed', '2026-02', 'fullCustomer', 'IQ', 'QI'),
    (20260204, NOW(), NOW(), NULL, 1, 'QI_VRM_RATE',                               '2026-02-01 00:00:00+08', 1.3434, 'QI monthly coefficient seed', '2026-02', 'fullCustomer', 'IQ', 'QI'),
    (20260205, NOW(), NOW(), NULL, 1, 'QI_CROSSBORDER_FX_RATE',                     '2026-02-01 00:00:00+08', 0.9904, 'QI monthly coefficient seed', '2026-02', 'fullCustomer', 'IQ', 'QI'),
    (20260206, NOW(), NOW(), NULL, 1, 'QI_DCSF_RATE',                               '2026-02-01 00:00:00+08', 1.1263, 'QI monthly coefficient seed', '2026-02', 'fullCustomer', 'IQ', 'QI'),

    -- 2026-03
    (20260301, NOW(), NOW(), NULL, 1, 'QI_ISSUER_CARD_SERVICE_RATE',                '2026-03-01 00:00:00+08', 0.9749, 'QI monthly coefficient seed', '2026-03', 'fullCustomer', 'IQ', 'QI'),
    (20260302, NOW(), NOW(), NULL, 1, 'QI_ISSUER_AUTH_CLEARING_SETTLEMENT_RATE',    '2026-03-01 00:00:00+08', 0.9019, 'QI monthly coefficient seed', '2026-03', 'fullCustomer', 'IQ', 'QI'),
    (20260303, NOW(), NOW(), NULL, 1, 'QI_ISSUER_AUTH_CLEARING_SETTLEMENT_VIP_RATE', '2026-03-01 00:00:00+08', 1.0636, 'QI monthly coefficient seed', '2026-03', 'fullCustomer', 'IQ', 'QI'),
    (20260304, NOW(), NOW(), NULL, 1, 'QI_VRM_RATE',                               '2026-03-01 00:00:00+08', 1.3434, 'QI monthly coefficient seed', '2026-03', 'fullCustomer', 'IQ', 'QI'),
    (20260305, NOW(), NOW(), NULL, 1, 'QI_CROSSBORDER_FX_RATE',                     '2026-03-01 00:00:00+08', 0.9904, 'QI monthly coefficient seed', '2026-03', 'fullCustomer', 'IQ', 'QI'),
    (20260306, NOW(), NOW(), NULL, 1, 'QI_DCSF_RATE',                               '2026-03-01 00:00:00+08', 1.1263, 'QI monthly coefficient seed', '2026-03', 'fullCustomer', 'IQ', 'QI'),

    -- 2026-04
    (20260401, NOW(), NOW(), NULL, 1, 'QI_ISSUER_CARD_SERVICE_RATE',                '2026-04-01 00:00:00+08', 0.9749, 'QI monthly coefficient seed', '2026-04', 'fullCustomer', 'IQ', 'QI'),
    (20260402, NOW(), NOW(), NULL, 1, 'QI_ISSUER_AUTH_CLEARING_SETTLEMENT_RATE',    '2026-04-01 00:00:00+08', 0.9019, 'QI monthly coefficient seed', '2026-04', 'fullCustomer', 'IQ', 'QI'),
    (20260403, NOW(), NOW(), NULL, 1, 'QI_ISSUER_AUTH_CLEARING_SETTLEMENT_VIP_RATE', '2026-04-01 00:00:00+08', 1.0636, 'QI monthly coefficient seed', '2026-04', 'fullCustomer', 'IQ', 'QI'),
    (20260404, NOW(), NOW(), NULL, 1, 'QI_VRM_RATE',                               '2026-04-01 00:00:00+08', 1.3434, 'QI monthly coefficient seed', '2026-04', 'fullCustomer', 'IQ', 'QI'),
    (20260405, NOW(), NOW(), NULL, 1, 'QI_CROSSBORDER_FX_RATE',                     '2026-04-01 00:00:00+08', 0.9904, 'QI monthly coefficient seed', '2026-04', 'fullCustomer', 'IQ', 'QI'),
    (20260406, NOW(), NOW(), NULL, 1, 'QI_DCSF_RATE',                               '2026-04-01 00:00:00+08', 1.1263, 'QI monthly coefficient seed', '2026-04', 'fullCustomer', 'IQ', 'QI'),

    -- 2026-05
    (20260501, NOW(), NOW(), NULL, 1, 'QI_ISSUER_CARD_SERVICE_RATE',                '2026-05-01 00:00:00+08', 0.9749, 'QI monthly coefficient seed', '2026-05', 'fullCustomer', 'IQ', 'QI'),
    (20260502, NOW(), NOW(), NULL, 1, 'QI_ISSUER_AUTH_CLEARING_SETTLEMENT_RATE',    '2026-05-01 00:00:00+08', 0.9019, 'QI monthly coefficient seed', '2026-05', 'fullCustomer', 'IQ', 'QI'),
    (20260503, NOW(), NOW(), NULL, 1, 'QI_ISSUER_AUTH_CLEARING_SETTLEMENT_VIP_RATE', '2026-05-01 00:00:00+08', 1.0636, 'QI monthly coefficient seed', '2026-05', 'fullCustomer', 'IQ', 'QI'),
    (20260504, NOW(), NOW(), NULL, 1, 'QI_VRM_RATE',                               '2026-05-01 00:00:00+08', 1.3434, 'QI monthly coefficient seed', '2026-05', 'fullCustomer', 'IQ', 'QI'),
    (20260505, NOW(), NOW(), NULL, 1, 'QI_CROSSBORDER_FX_RATE',                     '2026-05-01 00:00:00+08', 0.9904, 'QI monthly coefficient seed', '2026-05', 'fullCustomer', 'IQ', 'QI'),
    (20260506, NOW(), NOW(), NULL, 1, 'QI_DCSF_RATE',                               '2026-05-01 00:00:00+08', 1.1263, 'QI monthly coefficient seed', '2026-05', 'fullCustomer', 'IQ', 'QI'),

    -- 2026-06
    (20260601, NOW(), NOW(), NULL, 1, 'QI_ISSUER_CARD_SERVICE_RATE',                '2026-06-01 00:00:00+08', 0.9749, 'QI monthly coefficient seed', '2026-06', 'fullCustomer', 'IQ', 'QI'),
    (20260602, NOW(), NOW(), NULL, 1, 'QI_ISSUER_AUTH_CLEARING_SETTLEMENT_RATE',    '2026-06-01 00:00:00+08', 0.9019, 'QI monthly coefficient seed', '2026-06', 'fullCustomer', 'IQ', 'QI'),
    (20260603, NOW(), NOW(), NULL, 1, 'QI_ISSUER_AUTH_CLEARING_SETTLEMENT_VIP_RATE', '2026-06-01 00:00:00+08', 1.0636, 'QI monthly coefficient seed', '2026-06', 'fullCustomer', 'IQ', 'QI'),
    (20260604, NOW(), NOW(), NULL, 1, 'QI_VRM_RATE',                               '2026-06-01 00:00:00+08', 1.3434, 'QI monthly coefficient seed', '2026-06', 'fullCustomer', 'IQ', 'QI'),
    (20260605, NOW(), NOW(), NULL, 1, 'QI_CROSSBORDER_FX_RATE',                     '2026-06-01 00:00:00+08', 0.9904, 'QI monthly coefficient seed', '2026-06', 'fullCustomer', 'IQ', 'QI'),
    (20260606, NOW(), NOW(), NULL, 1, 'QI_DCSF_RATE',                               '2026-06-01 00:00:00+08', 1.1263, 'QI monthly coefficient seed', '2026-06', 'fullCustomer', 'IQ', 'QI'),

    -- 兜底配置
    (29990101, NOW(), NOW(), NULL, 1, 'QI_ISSUER_CARD_SERVICE_RATE',                '2022-01-01 00:00:00+08', 0.9749, 'QI fallback coefficient', 'DEFAULT_FALLBACK', 'fullCustomer', 'IQ', 'QI'),
    (29990102, NOW(), NOW(), NULL, 1, 'QI_ISSUER_AUTH_CLEARING_SETTLEMENT_RATE',    '2022-01-01 00:00:00+08', 0.9019, 'QI fallback coefficient', 'DEFAULT_FALLBACK', 'fullCustomer', 'IQ', 'QI'),
    (29990103, NOW(), NOW(), NULL, 1, 'QI_ISSUER_AUTH_CLEARING_SETTLEMENT_VIP_RATE', '2022-01-01 00:00:00+08', 1.0636, 'QI fallback coefficient', 'DEFAULT_FALLBACK', 'fullCustomer', 'IQ', 'QI'),
    (29990104, NOW(), NOW(), NULL, 1, 'QI_VRM_RATE',                               '2022-01-01 00:00:00+08', 1.3434, 'QI fallback coefficient', 'DEFAULT_FALLBACK', 'fullCustomer', 'IQ', 'QI'),
    (29990105, NOW(), NOW(), NULL, 1, 'QI_CROSSBORDER_FX_RATE',                     '2022-01-01 00:00:00+08', 0.9904, 'QI fallback coefficient', 'DEFAULT_FALLBACK', 'fullCustomer', 'IQ', 'QI'),
    (29990106, NOW(), NOW(), NULL, 1, 'QI_DCSF_RATE',                               '2022-01-01 00:00:00+08', 1.1263, 'QI fallback coefficient', 'DEFAULT_FALLBACK', 'fullCustomer', 'IQ', 'QI');
