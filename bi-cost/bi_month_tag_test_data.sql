-- bi_month_tag 五月测试数据

INSERT INTO "ods"."ods_bi_month_tag" ("id", "create_time", "update_time", "delete_time", "version", "tag", "statistics_time", "amount", "remarks", "detail", "account_type", "provider", "product_line") VALUES

-- QUANTUM_CARD 线
(10001, NOW(), NOW(), NULL, 1, 'CHANNEL_COST',           '2026-05-01 00:00:00+08', '10000.0000', NULL, '2026-05', 'fullCustomer', 'BPC',     'QUANTUM_CARD'),
(10002, NOW(), NOW(), NULL, 1, 'CARD_CUSTOMIZATION_FEE', '2026-05-01 00:00:00+08',  '2000.0000', NULL, '2026-05', 'fullCustomer', 'BPC',     'QUANTUM_CARD'),
(10003, NOW(), NOW(), NULL, 1, 'CHANNEL_COST',           '2026-05-01 00:00:00+08',  '5000.0000', NULL, '2026-05', 'fullCustomer', 'Sumsub',  'QUANTUM_CARD'),
(10004, NOW(), NOW(), NULL, 1, 'CHANNEL_COST',           '2026-05-01 00:00:00+08',  '3000.0000', NULL, '2026-05', 'fullCustomer', 'IDEMIA',  'QUANTUM_CARD'),
(10005, NOW(), NOW(), NULL, 1, 'CHANNEL_COST',           '2026-05-01 00:00:00+08',  '8000.0000', NULL, '2026-05', 'fullCustomer', 'HZ_BANK', 'QUANTUM_CARD'),
(10006, NOW(), NOW(), NULL, 1, 'CHANNEL_COST',           '2026-05-01 00:00:00+08',  '6000.0000', NULL, '2026-05', 'fullCustomer', 'BB',      'QUANTUM_CARD'),
(10007, NOW(), NOW(), NULL, 1, 'CHANNEL_COST',           '2026-05-01 00:00:00+08',  '4000.0000', NULL, '2026-05', 'fullCustomer', 'QI',      'QUANTUM_CARD'),
(10008, NOW(), NOW(), NULL, 1, 'CHANNEL_COST',           '2026-05-01 00:00:00+08',  '2000.0000', NULL, '2026-05', 'fullCustomer', 'SL',      'QUANTUM_CARD'),

-- GLOBAL_ACCOUNT 线
(10009, NOW(), NOW(), NULL, 1, 'CHANNEL_COST', '2026-05-01 00:00:00+08', '4000.0000', NULL, '2026-05', 'fullCustomer', 'BZ', 'GLOBAL_ACCOUNT'),
(10010, NOW(), NOW(), NULL, 1, 'CHANNEL_COST', '2026-05-01 00:00:00+08', '3500.0000', NULL, '2026-05', 'fullCustomer', 'CL', 'GLOBAL_ACCOUNT'),

-- CRYPTO_ASSET 线
(10011, NOW(), NOW(), NULL, 1, 'CHANNEL_COST', '2026-05-01 00:00:00+08', '6000.0000', NULL, '2026-05', 'fullCustomer', 'TH',        'CRYPTO_ASSET'),
(10012, NOW(), NOW(), NULL, 1, 'CHANNEL_COST', '2026-05-01 00:00:00+08', '2500.0000', NULL, '2026-05', 'fullCustomer', 'Cregis',    'CRYPTO_ASSET'),
(10013, NOW(), NOW(), NULL, 1, 'CHANNEL_COST', '2026-05-01 00:00:00+08', '7000.0000', NULL, '2026-05', 'fullCustomer', 'TZ-wire',   'CRYPTO_ASSET'),
(10014, NOW(), NOW(), NULL, 1, 'CHANNEL_COST', '2026-05-01 00:00:00+08', '3000.0000', NULL, '2026-05', 'fullCustomer', 'TZ-usdt',   'CRYPTO_ASSET'),
(10015, NOW(), NOW(), NULL, 1, 'CHANNEL_COST', '2026-05-01 00:00:00+08', '3000.0000', NULL, '2026-05', 'fullCustomer', 'TZ-usdc',   'CRYPTO_ASSET'),
(10016, NOW(), NOW(), NULL, 1, 'CHANNEL_COST', '2026-05-01 00:00:00+08', '2000.0000', NULL, '2026-05', 'fullCustomer', 'Safeheron', 'CRYPTO_ASSET'),
(10017, NOW(), NOW(), NULL, 1, 'CHANNEL_COST', '2026-05-01 00:00:00+08', '4500.0000', NULL, '2026-05', 'fullCustomer', 'BS',        'CRYPTO_ASSET'),

-- ACQUIRING 线
(10018, NOW(), NOW(), NULL, 1, 'CHANNEL_COST', '2026-05-01 00:00:00+08', '1500.0000', NULL, '2026-05', 'fullCustomer', 'OD', 'ACQUIRING'),
(10019, NOW(), NOW(), NULL, 1, 'CHANNEL_COST', '2026-05-01 00:00:00+08', '1000.0000', NULL, '2026-05', 'fullCustomer', 'WP', 'ACQUIRING');
