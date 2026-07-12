-- QI 的 `ods_bi_month_tag` 月度 rate 种子数据
-- 说明:
-- 1. 2026-01 ~ 2026-06 为正式月度配置
-- 2. 2022-01 为兜底配置，供月度配置暂缺时使用
-- 3. 这里按你贴出来的 7 个 rate 口径落表

INSERT INTO "ods"."ods_bi_month_tag"
    ("id", "create_time", "update_time", "delete_time", "version", "tag", "statistics_time", "amount", "remarks", "detail", "account_type", "provider", "product_line")
VALUES
    -- 2026-01
    (20260101, NOW(), NOW(), NULL, 1, 'QI_COST_REIMBURSEMENT_RATE',   '2026-01-01 00:00:00+08', 0.9946,     'QI monthly rate seed', '2026-01', 'fullCustomer', 'IQ', 'QI'),
    (20260102, NOW(), NOW(), NULL, 1, 'QI_COST_SERVICE_RATE',         '2026-01-01 00:00:00+08', 1.0084,     'QI monthly rate seed', '2026-01', 'fullCustomer', 'IQ', 'QI'),
    (20260103, NOW(), NOW(), NULL, 1, 'QI_COST_ACS_REGULAR_RATE',     '2026-01-01 00:00:00+08', 0.9852,     'QI monthly rate seed', '2026-01', 'fullCustomer', 'IQ', 'QI'),
    (20260104, NOW(), NOW(), NULL, 1, 'QI_COST_ACS_VIP_RATE',         '2026-01-01 00:00:00+08', 1.1146,     'QI monthly rate seed', '2026-01', 'fullCustomer', 'IQ', 'QI'),
    (20260105, NOW(), NOW(), NULL, 1, 'QI_COST_VRM_RATE',             '2026-01-01 00:00:00+08', 1.2239,     'QI monthly rate seed', '2026-01', 'fullCustomer', 'IQ', 'QI'),
    (20260106, NOW(), NOW(), NULL, 1, 'QI_REBATE_INTERCHANGE_RATE',   '2026-01-01 00:00:00+08', 0.019892,   'QI monthly rate seed', '2026-01', 'fullCustomer', 'IQ', 'QI'),
    (20260107, NOW(), NOW(), NULL, 1, 'QI_REBATE_INCENTIVE_RATE',     '2026-01-01 00:00:00+08', 0.01173628, 'QI monthly rate seed', '2026-01', 'fullCustomer', 'IQ', 'QI'),

    -- 2026-02
    (20260201, NOW(), NOW(), NULL, 1, 'QI_COST_REIMBURSEMENT_RATE',   '2026-02-01 00:00:00+08', 0.9946,     'QI monthly rate seed', '2026-02', 'fullCustomer', 'IQ', 'QI'),
    (20260202, NOW(), NOW(), NULL, 1, 'QI_COST_SERVICE_RATE',         '2026-02-01 00:00:00+08', 1.0084,     'QI monthly rate seed', '2026-02', 'fullCustomer', 'IQ', 'QI'),
    (20260203, NOW(), NOW(), NULL, 1, 'QI_COST_ACS_REGULAR_RATE',     '2026-02-01 00:00:00+08', 0.9852,     'QI monthly rate seed', '2026-02', 'fullCustomer', 'IQ', 'QI'),
    (20260204, NOW(), NOW(), NULL, 1, 'QI_COST_ACS_VIP_RATE',         '2026-02-01 00:00:00+08', 1.1146,     'QI monthly rate seed', '2026-02', 'fullCustomer', 'IQ', 'QI'),
    (20260205, NOW(), NOW(), NULL, 1, 'QI_COST_VRM_RATE',             '2026-02-01 00:00:00+08', 1.2239,     'QI monthly rate seed', '2026-02', 'fullCustomer', 'IQ', 'QI'),
    (20260206, NOW(), NOW(), NULL, 1, 'QI_REBATE_INTERCHANGE_RATE',   '2026-02-01 00:00:00+08', 0.019892,   'QI monthly rate seed', '2026-02', 'fullCustomer', 'IQ', 'QI'),
    (20260207, NOW(), NOW(), NULL, 1, 'QI_REBATE_INCENTIVE_RATE',     '2026-02-01 00:00:00+08', 0.01173628, 'QI monthly rate seed', '2026-02', 'fullCustomer', 'IQ', 'QI'),

    -- 2026-03
    (20260301, NOW(), NOW(), NULL, 1, 'QI_COST_REIMBURSEMENT_RATE',   '2026-03-01 00:00:00+08', 0.9946,     'QI monthly rate seed', '2026-03', 'fullCustomer', 'IQ', 'QI'),
    (20260302, NOW(), NOW(), NULL, 1, 'QI_COST_SERVICE_RATE',         '2026-03-01 00:00:00+08', 1.0084,     'QI monthly rate seed', '2026-03', 'fullCustomer', 'IQ', 'QI'),
    (20260303, NOW(), NOW(), NULL, 1, 'QI_COST_ACS_REGULAR_RATE',     '2026-03-01 00:00:00+08', 0.9852,     'QI monthly rate seed', '2026-03', 'fullCustomer', 'IQ', 'QI'),
    (20260304, NOW(), NOW(), NULL, 1, 'QI_COST_ACS_VIP_RATE',         '2026-03-01 00:00:00+08', 1.1146,     'QI monthly rate seed', '2026-03', 'fullCustomer', 'IQ', 'QI'),
    (20260305, NOW(), NOW(), NULL, 1, 'QI_COST_VRM_RATE',             '2026-03-01 00:00:00+08', 1.2239,     'QI monthly rate seed', '2026-03', 'fullCustomer', 'IQ', 'QI'),
    (20260306, NOW(), NOW(), NULL, 1, 'QI_REBATE_INTERCHANGE_RATE',   '2026-03-01 00:00:00+08', 0.019892,   'QI monthly rate seed', '2026-03', 'fullCustomer', 'IQ', 'QI'),
    (20260307, NOW(), NOW(), NULL, 1, 'QI_REBATE_INCENTIVE_RATE',     '2026-03-01 00:00:00+08', 0.01173628, 'QI monthly rate seed', '2026-03', 'fullCustomer', 'IQ', 'QI'),

    -- 2026-04
    (20260401, NOW(), NOW(), NULL, 1, 'QI_COST_REIMBURSEMENT_RATE',   '2026-04-01 00:00:00+08', 0.9946,     'QI monthly rate seed', '2026-04', 'fullCustomer', 'IQ', 'QI'),
    (20260402, NOW(), NOW(), NULL, 1, 'QI_COST_SERVICE_RATE',         '2026-04-01 00:00:00+08', 1.0084,     'QI monthly rate seed', '2026-04', 'fullCustomer', 'IQ', 'QI'),
    (20260403, NOW(), NOW(), NULL, 1, 'QI_COST_ACS_REGULAR_RATE',     '2026-04-01 00:00:00+08', 0.9852,     'QI monthly rate seed', '2026-04', 'fullCustomer', 'IQ', 'QI'),
    (20260404, NOW(), NOW(), NULL, 1, 'QI_COST_ACS_VIP_RATE',         '2026-04-01 00:00:00+08', 1.1146,     'QI monthly rate seed', '2026-04', 'fullCustomer', 'IQ', 'QI'),
    (20260405, NOW(), NOW(), NULL, 1, 'QI_COST_VRM_RATE',             '2026-04-01 00:00:00+08', 1.2239,     'QI monthly rate seed', '2026-04', 'fullCustomer', 'IQ', 'QI'),
    (20260406, NOW(), NOW(), NULL, 1, 'QI_REBATE_INTERCHANGE_RATE',   '2026-04-01 00:00:00+08', 0.019892,   'QI monthly rate seed', '2026-04', 'fullCustomer', 'IQ', 'QI'),
    (20260407, NOW(), NOW(), NULL, 1, 'QI_REBATE_INCENTIVE_RATE',     '2026-04-01 00:00:00+08', 0.01173628, 'QI monthly rate seed', '2026-04', 'fullCustomer', 'IQ', 'QI'),

    -- 2026-05
    (20260501, NOW(), NOW(), NULL, 1, 'QI_COST_REIMBURSEMENT_RATE',   '2026-05-01 00:00:00+08', 0.9946,     'QI monthly rate seed', '2026-05', 'fullCustomer', 'IQ', 'QI'),
    (20260502, NOW(), NOW(), NULL, 1, 'QI_COST_SERVICE_RATE',         '2026-05-01 00:00:00+08', 1.0084,     'QI monthly rate seed', '2026-05', 'fullCustomer', 'IQ', 'QI'),
    (20260503, NOW(), NOW(), NULL, 1, 'QI_COST_ACS_REGULAR_RATE',     '2026-05-01 00:00:00+08', 0.9852,     'QI monthly rate seed', '2026-05', 'fullCustomer', 'IQ', 'QI'),
    (20260504, NOW(), NOW(), NULL, 1, 'QI_COST_ACS_VIP_RATE',         '2026-05-01 00:00:00+08', 1.1146,     'QI monthly rate seed', '2026-05', 'fullCustomer', 'IQ', 'QI'),
    (20260505, NOW(), NOW(), NULL, 1, 'QI_COST_VRM_RATE',             '2026-05-01 00:00:00+08', 1.2239,     'QI monthly rate seed', '2026-05', 'fullCustomer', 'IQ', 'QI'),
    (20260506, NOW(), NOW(), NULL, 1, 'QI_REBATE_INTERCHANGE_RATE',   '2026-05-01 00:00:00+08', 0.019892,   'QI monthly rate seed', '2026-05', 'fullCustomer', 'IQ', 'QI'),
    (20260507, NOW(), NOW(), NULL, 1, 'QI_REBATE_INCENTIVE_RATE',     '2026-05-01 00:00:00+08', 0.01173628, 'QI monthly rate seed', '2026-05', 'fullCustomer', 'IQ', 'QI'),

    -- 2026-06
    (20260601, NOW(), NOW(), NULL, 1, 'QI_COST_REIMBURSEMENT_RATE',   '2026-06-01 00:00:00+08', 0.9946,     'QI monthly rate seed', '2026-06', 'fullCustomer', 'IQ', 'QI'),
    (20260602, NOW(), NOW(), NULL, 1, 'QI_COST_SERVICE_RATE',         '2026-06-01 00:00:00+08', 1.0084,     'QI monthly rate seed', '2026-06', 'fullCustomer', 'IQ', 'QI'),
    (20260603, NOW(), NOW(), NULL, 1, 'QI_COST_ACS_REGULAR_RATE',     '2026-06-01 00:00:00+08', 0.9852,     'QI monthly rate seed', '2026-06', 'fullCustomer', 'IQ', 'QI'),
    (20260604, NOW(), NOW(), NULL, 1, 'QI_COST_ACS_VIP_RATE',         '2026-06-01 00:00:00+08', 1.1146,     'QI monthly rate seed', '2026-06', 'fullCustomer', 'IQ', 'QI'),
    (20260605, NOW(), NOW(), NULL, 1, 'QI_COST_VRM_RATE',             '2026-06-01 00:00:00+08', 1.2239,     'QI monthly rate seed', '2026-06', 'fullCustomer', 'IQ', 'QI'),
    (20260606, NOW(), NOW(), NULL, 1, 'QI_REBATE_INTERCHANGE_RATE',   '2026-06-01 00:00:00+08', 0.019892,   'QI monthly rate seed', '2026-06', 'fullCustomer', 'IQ', 'QI'),
    (20260607, NOW(), NOW(), NULL, 1, 'QI_REBATE_INCENTIVE_RATE',     '2026-06-01 00:00:00+08', 0.01173628, 'QI monthly rate seed', '2026-06', 'fullCustomer', 'IQ', 'QI'),

    -- 兜底配置
    (29990101, NOW(), NOW(), NULL, 1, 'QI_COST_REIMBURSEMENT_RATE',   '2022-01-01 00:00:00+08', 0.9946,     'QI fallback rate', 'DEFAULT_FALLBACK', 'fullCustomer', 'IQ', 'QI'),
    (29990102, NOW(), NOW(), NULL, 1, 'QI_COST_SERVICE_RATE',         '2022-01-01 00:00:00+08', 1.0084,     'QI fallback rate', 'DEFAULT_FALLBACK', 'fullCustomer', 'IQ', 'QI'),
    (29990103, NOW(), NOW(), NULL, 1, 'QI_COST_ACS_REGULAR_RATE',     '2022-01-01 00:00:00+08', 0.9852,     'QI fallback rate', 'DEFAULT_FALLBACK', 'fullCustomer', 'IQ', 'QI'),
    (29990104, NOW(), NOW(), NULL, 1, 'QI_COST_ACS_VIP_RATE',         '2022-01-01 00:00:00+08', 1.1146,     'QI fallback rate', 'DEFAULT_FALLBACK', 'fullCustomer', 'IQ', 'QI'),
    (29990105, NOW(), NOW(), NULL, 1, 'QI_COST_VRM_RATE',             '2022-01-01 00:00:00+08', 1.2239,     'QI fallback rate', 'DEFAULT_FALLBACK', 'fullCustomer', 'IQ', 'QI'),
    (29990106, NOW(), NOW(), NULL, 1, 'QI_REBATE_INTERCHANGE_RATE',   '2022-01-01 00:00:00+08', 0.019892,   'QI fallback rate', 'DEFAULT_FALLBACK', 'fullCustomer', 'IQ', 'QI'),
    (29990107, NOW(), NOW(), NULL, 1, 'QI_REBATE_INCENTIVE_RATE',     '2022-01-01 00:00:00+08', 0.01173628, 'QI fallback rate', 'DEFAULT_FALLBACK', 'fullCustomer', 'IQ', 'QI');
