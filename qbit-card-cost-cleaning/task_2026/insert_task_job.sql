-- 00. INSERT_DATA ods_sale_am_transaction_2026
-- =========================================
INSERT INTO ods_sale_am_transaction_2026 (transaction_id, sale_id, am_id, create_time, update_time, delete_time, remarks, version)
SELECT  tr.ID AS transaction_id,
        sar."salesId" AS sale_id,
        sar."amId" AS am_id,
        tr."createTime" as "create_time",
        NOW( ) AS update_time,-- 默认当前时间
        NULL AS delete_time,-- 逻辑删除字段，默认 NULL
        NULL AS remarks,-- 备注字段，默认 NULL
        1 AS VERSION -- 版本号，默认 1
FROM "Transaction" tr
LEFT JOIN (
select sar."createTime",sar."deleteTime",sar."salesId",sar."amId",sar."accountId" as "accountId"   
FROM "salesAccountRelation" as sar
UNION ALL
SELECT sar."createTime",sar."deleteTime",sar."salesId",sar."amId",account.id as "accountId"   
FROM account
INNER JOIN "salesAccountRelation" as sar ON sar."accountId"::UUID=account."parentAccountId"::UUID
where account."parentAccountId" !='00000000-0000-0000-0000-000000000000'   
) AS sar ON tr."accountId" :: UUID = sar."accountId" :: UUID AND tr."createTime" >= sar."createTime" AND ( tr."createTime" <= sar."deleteTime" OR sar."deleteTime" IS NULL ) 
WHERE tr."deleteTime" IS NULL 
AND tr."createTime" >= CURRENT_DATE - INTERVAL '1 day' 
AND tr."createTime" < CURRENT_DATE
ON CONFLICT (transaction_id) DO NOTHING;

-- 01. INSERT_DATA dws_qbit_card_wallet_transaction_2026
-- =========================================
INSERT INTO "public"."dws_qbit_card_wallet_transaction_2026" (
  "id", "account_id", "business_type","status", "origin_amount", "transaction_count", 
  "fee", "create_date","version", "create_time", "update_time"
)
SELECT 
  generate_snowflake_id(),
  tr."accountId",
  tr."businessType",
  tr."status",
  COALESCE(SUM(tr."originAmount"), 0) AS origin_amount,
  COUNT(*) AS transaction_count,
  COALESCE(SUM(tr."fee"), 0) AS fee,
  TO_CHAR(tr."createTime", 'YYYY-MM-DD')::DATE AS create_date,
  1 AS version,
  NOW() AS create_time,
  NOW() AS update_time
FROM "qbitCardWalletTransaction" AS tr
WHERE tr."deleteTime" IS NULL
  AND tr."createTime" >= CURRENT_DATE - INTERVAL '1 day' AND tr."createTime" < CURRENT_DATE
GROUP BY tr."accountId", tr."businessType", create_date, tr."status"
ON CONFLICT (id) DO NOTHING;

-- 02. INSERT_DATA dws_qbit_card_transaction_2026
-- =========================================
INSERT INTO "public"."dws_qbit_card_transaction_2026" (
  "id", "account_id", "business_type", "status", "provider", "bin", "origin_amount", "settle_amount", 
  "transaction_count", "fee", "create_date", "version", "create_time","update_time")
SELECT 
  generate_snowflake_id(),
  tr."accountId",
  tr."businessType",
  tr."status",
  tr."provider",
  qc."firstSix" AS "bin",
  COALESCE(SUM(tr."originalAmount"), 0) AS origin_amount,
  COALESCE(SUM(tr."settleAmount"), 0) AS settle_amount,
  COUNT(*) AS transaction_count,
  COALESCE(SUM(tr."fee"), 0) AS fee,
  TO_CHAR(tr."createTime", 'YYYY-MM-DD')::DATE AS create_date,
  1 AS version,
  NOW() AS create_time,
  NOW() AS update_time
FROM "qbit_card_transaction" AS tr
LEFT JOIN "qbitCard" AS qc ON tr."cardId" = qc."id"
WHERE tr."deleteTime" IS NULL 
  AND tr."createTime" >= CURRENT_DATE - INTERVAL '1 day' AND tr."createTime" < CURRENT_DATE
GROUP BY tr."accountId", tr."provider", qc."firstSix", tr."businessType", create_date, tr."status"
ON CONFLICT (id) DO NOTHING;

-- 03. INSERT_DATA dws_qbit_card_transaction_extend_2026
-- =========================================
INSERT INTO "public"."dws_qbit_card_transaction_extend_2026" (
  "id", "account_id", "provider", "bin", "business_type", "status", "settle_amount", "transaction_currency", "country", 
  "transaction_count","fx_fee", "atm_fee", "apple_pay_fee","settle_fee", "create_date", "version", "create_time", "update_time")
SELECT 
  generate_snowflake_id() AS "id",
  tr."accountId" AS "account_id",
  tr."provider" AS "provider",
  qc."firstSix" AS "bin",
  tr."businessType",
  tr."status" AS "status", 
  COALESCE(SUM(tr."settleAmount"), 0) AS "settle_amount",
  tr."transactionCurrency" AS "transaction_currency",
  tr."specialSourceData"->>'country' AS "country",
  COUNT(*) AS "transaction_count",
  COALESCE(SUM((tr."specialSourceData"->>'markupFee')::numeric), 0) AS "fx_fee",
  COALESCE(SUM(CASE WHEN tr.remarks LIKE '%ATM取现费' THEN fee::numeric ELSE 0 END), 0) AS "atm_fee",
  COALESCE(SUM((tr."specialSourceData"->>'applePayFee')::numeric), 0) AS "apple_pay_fee",
  COALESCE(SUM((tr."specialSourceData"->>'settleFee')::numeric), 0) AS "settle_fee",
  TO_CHAR(tr."createTime", 'YYYY-MM-DD')::DATE AS "create_date",
  1 AS "version",
  NOW() AS "create_time",
  NOW() AS "update_time"
FROM "qbit_card_transaction" AS tr
LEFT JOIN "qbitCard" AS qc ON tr."cardId" = qc."id"
WHERE 
  tr."deleteTime" IS NULL
  AND tr."createTime" >= CURRENT_DATE - INTERVAL '1 day' AND tr."createTime" < CURRENT_DATE
GROUP BY 
  tr."accountId", tr."provider", qc."firstSix", tr."businessType", tr."status",
  tr."transactionCurrency", tr."specialSourceData"->>'country',TO_CHAR(tr."createTime", 'YYYY-MM-DD')::DATE
ON CONFLICT (id) DO NOTHING;

-- 04. INSERT_DATA dws_qbit_card_group_transaction_2026
-- =========================================
INSERT INTO "public"."dws_qbit_card_group_transaction_2026" (
  "id", "account_id", "business_type", "status", "origin_amount", "transaction_count", 
  "fee","create_date", "version", "create_time", "update_time")
SELECT 
  generate_snowflake_id(),
  tr."accountId",
  tr."businessType",
  tr."status",
  COALESCE(SUM(tr."originalAmount"), 0) AS origin_amount,
  COUNT(*) AS transaction_count,
  COALESCE(SUM(tr."fee"), 0) AS fee,
  TO_CHAR(tr."createTime", 'YYYY-MM-DD')::DATE AS create_date,
  1 AS version, 
  NOW() AS create_time,
  NOW() AS update_time
FROM "qbitCardGroupTransaction" AS tr
WHERE tr."deleteTime" IS NULL 
  AND tr."createTime" >= CURRENT_DATE - INTERVAL '1 day' AND tr."createTime" < CURRENT_DATE
GROUP BY tr."accountId", tr."businessType", create_date, tr."status"
ON CONFLICT (id) DO NOTHING;

-- 05. INSERT_DATA dws_transfer_2026
-- =========================================
INSERT INTO "public"."dws_transfer_2026" (
  "id", "account_id", "business_type_detail","business_type_code", "settlement_currency", "status", "usd_amount", 
  "transaction_count", "fee", "currency","create_date", "version", "create_time", "update_time")
SELECT 
  generate_snowflake_id(),
  tr."accountId",
  tr."businessTypeDetail",
	tr."businessCode",
  tr."settlementCurrency",
  tr."status",
  COALESCE(SUM(tr."usdAmount"), 0) AS usd_amount,
  COUNT(*) AS transaction_count,
  COALESCE(SUM("fee" * "usdRate"), 0) AS fee,
  "currency",
  TO_CHAR(tr."createTime", 'YYYY-MM-DD')::DATE AS create_date,
  1 AS version,
  NOW() AS create_time,
  NOW() AS update_time
FROM "transfer" AS tr
WHERE tr."deleteTime" IS NULL
  AND tr."createTime" >= CURRENT_DATE - INTERVAL '1 day' AND tr."createTime" < CURRENT_DATE
GROUP BY tr."accountId", tr."businessTypeDetail",tr."businessCode", tr."settlementCurrency", create_date, status, "currency"
ON CONFLICT (id) DO NOTHING;

-- 06. INSERT_DATA dws_transfer_extend_2026
-- =========================================
INSERT INTO "public"."dws_transfer_extend_2026" (
  "id", "account_id", "status","dbs_receive", "cl_receive", "ep_receive", "rd_receive", "settle_fx_fee", 
  "conversion_fx_amount", "conversion_fx_fee", "create_date", "version", "create_time", "update_time")
SELECT 
  generate_snowflake_id(),
  tr."accountId",
  tr."status",
  COALESCE(SUM(CASE WHEN tr."businessTypeDetail" IN ('OtherChannelInbound') AND UPPER((tr."rawData"::jsonb->> 0)::jsonb->>'source') IN ('OTT','寻汇','BEEPAY') THEN "usdAmount" ELSE 0 END), 0) AS "dbs_receive",
  COALESCE(SUM(CASE WHEN tr."businessTypeDetail" IN ('OtherChannelInbound','CCInbound') AND tr."provider" = 'Column' THEN "usdAmount" ELSE 0 END), 0) AS "cl_receive",
  COALESCE(SUM(CASE WHEN tr."businessTypeDetail" IN ('OtherChannelInbound','CCInbound') AND tr."provider" = 'EP'THEN "usdAmount" ELSE 0 END), 0) AS "ep_receive",
  COALESCE(SUM(CASE WHEN tr."businessTypeDetail" IN ('OtherChannelInbound','CCInbound') AND tr."provider" = 'RD' THEN "usdAmount" ELSE 0 END), 0) AS "rd_receive",
  COALESCE(SUM(CASE WHEN ta."toCurrency" = 'CNY' AND tr."status" = 'Closed' AND ta.status = 'Closed' THEN ta."rateDiffIncomeFromUsdAmount" ELSE 0 END), 0) AS "settle_fx_fee",
  COALESCE(SUM(CASE WHEN tr."settlementCurrency" != 'CNY' AND tr."status" = 'Closed' AND ta.status = 'Closed'  AND tr."businessTypeDetail" IN ('Payment','ConversionOut','InnerTransferOut') THEN tr."usdAmount" ELSE 0 END), 0) AS "conversion_fx_amount",
  COALESCE(SUM(CASE WHEN ta."toCurrency" != 'CNY' AND tr."status" = 'Closed' AND ta.status = 'Closed' THEN ta."rateDiffIncomeFromUsdAmount" ELSE 0 END), 0) AS "conversion_fx_fee",
  TO_CHAR(tr."createTime", 'YYYY-MM-DD')::DATE AS create_date,
  1 AS version,
  NOW() AS create_time,
  NOW() AS update_time
FROM "transfer" AS tr
LEFT JOIN "globalConversion" AS ta ON ta."recordId"::UUID = tr.id
WHERE tr."deleteTime" IS NULL AND ta."deleteTime" IS NULL
  AND tr."createTime" >= CURRENT_DATE - INTERVAL '1 day' AND tr."createTime" < CURRENT_DATE
GROUP BY tr."accountId", create_date, tr.status
ON CONFLICT (id) DO NOTHING;

-- 07. INSERT_DATA dws_crypto_assets_transfers_2026
-- =========================================
INSERT INTO "public"."dws_crypto_assets_transfers_2026" (
  "id", "account_id", "status", "sender_type", "recipient_type", "transaction_count", "origin_amount", "settlement_amount", "fee", 
  "fee2", "cross_chain_fee","hidden", "create_date", "currency", "action", "version", "create_time", "update_time")
SELECT 
  generate_snowflake_id(),
  "account_id",
  "status",
  "sender_type",
  "recipient_type",
  COUNT(*) AS transaction_count,
  SUM("origin_amount" * "usd_rate") AS origin_amount,
  SUM("settlement_amount" * "usd_rate") AS settlement_amount,
  SUM("fee" * "usd_rate") AS fee,
  SUM("fee2" * "usd_rate") AS fee2,
  SUM("cross_chain_fee" * "usd_rate") AS cross_chain_fee,
  "hidden",
  TO_CHAR("create_time", 'YYYY-MM-DD')::DATE AS create_date,
  "currency",
  "action",
  1 AS version,
  NOW() AS create_time,
  NOW() AS update_time
FROM "crypto_assets_transfers" AS tr
WHERE
  tr."delete_time" IS NULL 
  AND tr."create_time" >= CURRENT_DATE - INTERVAL '1 day' AND tr."create_time" < CURRENT_DATE
GROUP BY "account_id","status","sender_type","recipient_type","hidden",create_date,"currency","action"
ON CONFLICT (id) DO NOTHING;

-- 08. INSERT_DATA ods_fund_profits_2026
-- =========================================
INSERT INTO ods_fund_profits_2026 (
  "id", "fund_id", "create_time", "update_time", "delete_time", "version", "remarks", "account_id",
  "product_id", "date", "currency", "profit", "service_fee", "status", "apr", "share", "net_value")
SELECT 
  generate_snowflake_id(),
  tr."id",
  tr."create_time",
  tr."update_time",
  tr."delete_time",
  tr."version",
  tr."remarks",
  tr."account_id",
  tr."product_id",
  tr."date",
  tr."currency",
  tr."profit",
  (CASE WHEN fee->>'type' = 'SERVICE' THEN (fee->>'amount')::numeric ELSE 0 END) AS "service_fee",
  tr."status",
  tr."apr",
  tr."share",
  tr."net_value"
FROM "fund_profits" AS tr
CROSS JOIN LATERAL jsonb_array_elements(fees) AS fee
WHERE tr."delete_time" IS NULL 
  AND tr."create_time" >= CURRENT_DATE - INTERVAL '1 day' AND tr."create_time" < CURRENT_DATE
ON CONFLICT (id) DO NOTHING;

-- 09. INSERT_DATA ods_qbit_card_2026
-- =========================================
INSERT INTO "ods_qbit_card_2026" (
  "id", "create_time", "update_time", "delete_time", "version", "remarks","card_id", "account_id", "currency", "status",
  "provider", "type", "token", "user_delete_time", "delete_card_time","first_six", "card_belong", "physical_card_status", "card_mode")
SELECT 
  generate_snowflake_id(),
  tr."createTime", tr."updateTime", tr."deleteTime", tr."version", tr."remarks",
  tr."id", tr."accountId", tr."currency", tr."status",
  tr."provider", tr."type", tr."token", tr."userDeleteTime",
  tr."deleteCardTime", tr."firstSix", tr."cardBelong",
  tr."physicalCardStatus", tr."cardMode"
FROM "qbitCard" AS tr
WHERE 
  tr."deleteTime" IS NULL
  AND tr."createTime" >= CURRENT_DATE - INTERVAL '1 day' AND tr."createTime" < CURRENT_DATE
ON CONFLICT (id) DO NOTHING;

-- 10. INSERT_DATA dws_open_card_2026
-- =========================================
INSERT INTO "public"."dws_open_card_2026" (
  "id", "account_id", "provider", "bin", "status", "fee", "count", "create_date", "version", "create_time", "update_time")
SELECT
  generate_snowflake_id() AS "id",
  tr."accountId",
  qc."provider",
  qc."firstSix" AS "bin",
  tr."status",
  COALESCE(SUM(tr."senderFee"), 0) AS "fee",
  COUNT(*) AS "count",
  TO_CHAR(tr."createTime", 'YYYY-MM-DD')::DATE AS "create_date",
  1 AS "version",
  NOW() AS "create_time",
  NOW() AS "update_time"
FROM "Transaction" AS tr
LEFT JOIN "qbitCard" AS qc ON qc."id"::VARCHAR = tr."sourceId"
WHERE tr."deleteTime" IS NULL AND tr."type" IN ('CreateCard', 'QbitCardFee')
  AND tr."createTime" >= CURRENT_DATE - INTERVAL '1 day' AND tr."createTime" < CURRENT_DATE
GROUP BY tr."status", tr."accountId", qc."provider", qc."firstSix", TO_CHAR(tr."createTime", 'YYYY-MM-DD')::DATE
ON CONFLICT (id) DO NOTHING;

-- 11. INSERT_DATA dws_physical_card_2026
-- =========================================
INSERT INTO "public"."dws_physical_card_2026" ("id", "account_id", "provider", "bin", "status","transaction_count", "physical_card_fee","create_date", "version", "create_time", "update_time")
SELECT 
  generate_snowflake_id() AS "id",
  tr."accountId" AS "account_id",
  qc."provider" AS "provider",
  qc."firstSix" AS "bin",
  tr."status" AS "status", 
  COUNT(*) AS "transaction_count",
  SUM(tr."originAmount"::numeric) AS "physical_card_fee",
  TO_CHAR(tr."createTime", 'YYYY-MM-DD')::DATE AS "create_date",
  1 AS "version",
  NOW() AS "create_time",
  NOW() AS "update_time"
FROM "qbitCardWalletTransaction" AS tr
LEFT JOIN "qbitCard" AS qc ON tr."cardId" = qc."id"
WHERE 
  tr."deleteTime" IS NULL AND tr."businessType" = 'TransferOut' AND tr."remarks" IN ('邮寄费', '制卡费', '批量邮寄运费')
  AND tr."createTime" >= CURRENT_DATE - INTERVAL '1 day' AND tr."createTime" < CURRENT_DATE
GROUP BY tr."accountId", qc."provider", qc."firstSix", tr."status", TO_CHAR(tr."createTime", 'YYYY-MM-DD')::DATE
ON CONFLICT (id) DO NOTHING;

-- 12. INSERT_DATA dws_sale_card_wallet_transaction_2026
-- =========================================
INSERT INTO "public"."dws_sale_card_wallet_transaction_2026" ("id", "account_id", "sale_or_am_id", "business_type", "status","origin_amount", "transaction_count", "fee", "create_date", "version", "create_time", "update_time")
SELECT 
  generate_snowflake_id(),
  tr."accountId",
  ids."sale_or_am_id",
  tr."businessType",
  tr."status",
  COALESCE(SUM(tr."originAmount"), 0) AS origin_amount,
  COUNT(*) AS transaction_count,
  COALESCE(SUM(tr."fee"), 0) AS fee,
  TO_CHAR(tr."createTime", 'YYYY-MM-DD')::DATE AS create_date,
  1 AS version,
  NOW() AS create_time,
  NOW() AS update_time
FROM "qbitCardWalletTransaction" AS tr
LEFT JOIN "public"."ods_sale_am_transaction_2026" AS osat ON tr."transactionId"::UUID = osat.transaction_id::UUID
LEFT JOIN LATERAL (SELECT unnest(ARRAY[osat."sale_id", osat."am_id"]) AS sale_or_am_id) AS ids ON TRUE
WHERE 
  tr."deleteTime" IS NULL AND tr."createTime" >= CURRENT_DATE - INTERVAL '1 day' AND tr."createTime" < CURRENT_DATE
GROUP BY   tr."accountId", tr."businessType", tr."status", create_date, ids."sale_or_am_id"
ON CONFLICT (id) DO NOTHING;

-- 13. INSERT_DATA dws_sale_card_transaction_2026
-- =========================================
INSERT INTO "public"."dws_sale_card_transaction_2026" ("id", "account_id", "sale_or_am_id", "business_type", "status",
  "provider", "bin", "origin_amount", "settle_amount", "transaction_count", "fee", "create_date","version", "create_time", "update_time")
SELECT 
  generate_snowflake_id(),
  tr."accountId",
  ids."sale_or_am_id",
  tr."businessType",
  tr."status",
  tr."provider",
  qc."firstSix" AS "bin",
  COALESCE(SUM(tr."originalAmount"), 0) AS origin_amount,
  COALESCE(SUM(tr."settleAmount"), 0) AS settle_amount,
  COUNT(*) AS transaction_count,
  COALESCE(SUM(tr."fee"), 0) AS fee,
  TO_CHAR(tr."createTime", 'YYYY-MM-DD')::DATE AS create_date,
  1 AS version,
  NOW() AS create_time,
  NOW() AS update_time
FROM "qbit_card_transaction" AS tr
LEFT JOIN "qbitCard" AS qc ON tr."cardId" = qc."id"
LEFT JOIN "public"."ods_sale_am_transaction_2026" AS osat ON tr."transactionId"::UUID = osat.transaction_id::UUID
LEFT JOIN LATERAL (SELECT unnest(ARRAY[osat."sale_id", osat."am_id"]) AS sale_or_am_id) AS ids ON TRUE
WHERE tr."deleteTime" IS NULL
  AND tr."createTime" >= CURRENT_DATE - INTERVAL '1 day' AND tr."createTime" < CURRENT_DATE
GROUP BY tr."accountId", ids."sale_or_am_id", tr."businessType",tr."status", tr."provider", qc."firstSix",TO_CHAR(tr."createTime", 'YYYY-MM-DD')::DATE
ON CONFLICT (id) DO NOTHING;

-- 14. INSERT_DATA dws_sale_card_transaction_extend_2026
-- =========================================
INSERT INTO "public"."dws_sale_card_transaction_extend_2026" (
  "id", "account_id", "sale_or_am_id", "business_type", "provider", "bin", "status", "settle_amount", "transaction_currency", "country", 
  "transaction_count", "fx_fee", "atm_fee", "apple_pay_fee","settle_fee", "create_date", "version", "create_time", "update_time")
SELECT 
  generate_snowflake_id() AS id,
  tr."accountId" AS account_id,
  ids."sale_or_am_id",
  tr."businessType",
  tr."provider",
  qc."firstSix" AS bin,
  tr."status",
  COALESCE(SUM(tr."settleAmount"), 0) AS settle_amount,
  tr."transactionCurrency",
  tr."specialSourceData"->>'country' AS country,
  COUNT(*) AS transaction_count,
  COALESCE(SUM((tr."specialSourceData"->>'markupFee')::numeric), 0) AS fx_fee,
  COALESCE(SUM(CASE WHEN tr.remarks LIKE '%ATM取现费' THEN fee::numeric ELSE 0 END), 0) AS atm_fee,
  COALESCE(SUM((tr."specialSourceData"->>'applePayFee')::numeric), 0) AS apple_pay_fee,
  COALESCE(SUM((tr."specialSourceData"->>'settleFee')::numeric), 0) AS settle_fee,
  TO_CHAR(tr."createTime", 'YYYY-MM-DD')::DATE AS create_date,
  1 AS version,
  NOW() AS create_time,
  NOW() AS update_time
FROM "qbit_card_transaction" AS tr
LEFT JOIN "qbitCard" AS qc ON tr."cardId" = qc.id
LEFT JOIN "ods_sale_am_transaction_2026" AS osat ON tr."transactionId"::UUID = osat.transaction_id::UUID
LEFT JOIN LATERAL (SELECT unnest(ARRAY[osat."sale_id", osat."am_id"]) AS sale_or_am_id) AS ids ON TRUE
WHERE 
  tr."deleteTime" IS NULL
  AND tr."createTime" >= CURRENT_DATE - INTERVAL '1 day' AND tr."createTime" < CURRENT_DATE
GROUP BY 
  tr."accountId", tr."provider", qc."firstSix", tr."businessType", tr."status",tr."transactionCurrency", tr."specialSourceData"->>'country',
  TO_CHAR(tr."createTime", 'YYYY-MM-DD')::DATE, ids."sale_or_am_id"
ON CONFLICT (id) DO NOTHING;  

-- 15. INSERT_DATA dws_sale_card_group_transaction_2026
-- =========================================
INSERT INTO "public"."dws_sale_card_group_transaction_2026" (
  "id", "account_id", "sale_or_am_id", "business_type", "status","origin_amount", "transaction_count", "fee","create_date", "version", "create_time", "update_time")
SELECT 
  generate_snowflake_id(),
  tr."accountId",
  ids."sale_or_am_id",
  tr."businessType",
  tr."status",
  COALESCE(SUM(tr."originalAmount"), 0) AS origin_amount,
  COUNT(*) AS transaction_count,
  COALESCE(SUM(tr."fee"), 0) AS fee,
  TO_CHAR(tr."createTime", 'YYYY-MM-DD')::DATE AS create_date,
  1 AS version,
  NOW() AS create_time,
  NOW() AS update_time
FROM "qbitCardGroupTransaction" AS tr
LEFT JOIN "ods_sale_am_transaction_2026" AS osat ON tr."transactionId"::UUID = osat.transaction_id::UUID
LEFT JOIN LATERAL (SELECT unnest(ARRAY[osat."sale_id", osat."am_id"]) AS sale_or_am_id) AS ids ON TRUE
WHERE tr."deleteTime" IS NULL
  AND tr."createTime" >= CURRENT_DATE - INTERVAL '1 day' AND tr."createTime" < CURRENT_DATE
GROUP BY tr."accountId", tr."businessType", tr."status",TO_CHAR(tr."createTime", 'YYYY-MM-DD')::DATE,ids."sale_or_am_id"
ON CONFLICT (id) DO NOTHING;    

-- 16. INSERT_DATA dws_sale_transfer_2026
-- =========================================
INSERT INTO "public"."dws_sale_transfer_2026" (
  "id", "account_id", "sale_or_am_id", "business_type_detail", "business_type_code", "settlement_currency", "status", "usd_amount", 
  "transaction_count", "fee", "currency", "create_date", "version", "create_time", "update_time")
SELECT 
  generate_snowflake_id(),
  tr."accountId",
  ids."sale_or_am_id",
  tr."businessTypeDetail",
	tr."businessCode",
  tr."settlementCurrency",
  tr."status",
  COALESCE(SUM(tr."usdAmount"), 0) AS usd_amount,
  COUNT(*) AS transaction_count,
  COALESCE(SUM(tr."fee" * tr."usdRate"), 0) AS fee,
  tr."currency",
  TO_CHAR(tr."createTime", 'YYYY-MM-DD')::DATE AS create_date,
  1 AS version,
  NOW() AS create_time,
  NOW() AS update_time
FROM "transfer" AS tr
LEFT JOIN "ods_sale_am_transaction_2026" AS osat ON tr."transactionId"::UUID = osat.transaction_id::UUID
LEFT JOIN LATERAL (SELECT unnest(ARRAY[osat."sale_id", osat."am_id"]) AS sale_or_am_id) AS ids ON TRUE
WHERE tr."deleteTime" IS NULL
  AND tr."createTime" >= CURRENT_DATE - INTERVAL '1 day' AND tr."createTime" < CURRENT_DATE
GROUP BY tr."accountId", tr."businessTypeDetail",tr."businessCode", tr."settlementCurrency", tr."status", tr."currency", TO_CHAR(tr."createTime", 'YYYY-MM-DD')::DATE, ids."sale_or_am_id"
ON CONFLICT (id) DO NOTHING;    

-- 17. INSERT_DATA dws_sale_transfer_extend_2026
-- =========================================
INSERT INTO "public"."dws_sale_transfer_extend_2026" ("id", "account_id" , "sale_or_am_id","status", "dbs_receive","cl_receive", "ep_receive", "rd_receive","settle_fx_fee","conversion_fx_amount","conversion_fx_fee","inbound_profit","conversion_fx_profit", "create_date", "version", "create_time", "update_time")
SELECT
generate_snowflake_id(),
"accountId",
"sale_or_am_id",
"status",
COALESCE(SUM("dbsReceive"),0) AS "dbsReceive",
COALESCE(SUM("clReceive"),0) AS "clReceive",
COALESCE(SUM("epReceive"),0) AS "epReceive",
COALESCE(SUM("rdReceive"),0) AS "rdReceive",
COALESCE(SUM("settleFxFee"),0) AS "settleFxFee" ,
COALESCE(SUM("conversionFxAmount"),0) AS "conversionFxAmount" ,
COALESCE(SUM("conversionFxFee"),0) AS "conversionFxFee",
COALESCE(SUM(CASE WHEN "businessTypeDetail" in ('OtherChannelInbound', 'CCInbound') and (fee - "clReceive"*0.0005 - "epReceive"*0.0005 - "rdReceive"*0.0005) > 0 THEN 
               (fee - "clReceive"*0.0005 - "epReceive"*0.0005 - "rdReceive"*0.0005)  ELSE 0 END),0) AS "inboundProfit",
COALESCE(SUM (CASE WHEN ("conversionFxFee"-"conversionFxAmount"*0.001)>0 THEN ("conversionFxFee"-"conversionFxAmount"*0.001) ELSE 0 END ),0) AS "conversionFxProfit",
create_date,
1 AS version, -- 初始版本号
NOW() AS create_time,
NOW() AS update_time
from (  
SELECT 
tr."accountId",
ids."sale_or_am_id",
tr."status",
tr."businessTypeDetail",
tr."settlementCurrency",
tr."fee"*"usdRate" AS "fee",
ta."fromAmount",
"usdAmount",
ta."rateDiffIncomeFromUsdAmount",
(CASE WHEN tr."businessTypeDetail" in ('OtherChannelInbound') and UPPER((tr."rawData"::jsonb->> 0)::jsonb->>'source') IN ('OTT','寻汇','BEEPAY') THEN "usdAmount" ELSE 0 END ) AS "dbsReceive",
(CASE WHEN tr."businessTypeDetail" in ('OtherChannelInbound', 'CCInbound') and tr."provider" = 'Column' THEN "usdAmount" ELSE 0 END) AS "clReceive",
(CASE WHEN tr."businessTypeDetail" in ('OtherChannelInbound', 'CCInbound') and tr."provider"  = 'EP' THEN "usdAmount" ELSE 0 END) AS "epReceive",
(CASE WHEN tr."businessTypeDetail" in ('OtherChannelInbound', 'CCInbound') and tr."provider"  = 'RD' THEN "usdAmount" ELSE 0 END) AS "rdReceive",
(CASE WHEN ta."toCurrency" = 'CNY' and tr."status" = 'Closed' and ta.status='Closed' THEN ta."rateDiffIncomeFromUsdAmount" ELSE 0 END ) AS "settleFxFee" ,
(CASE WHEN tr."settlementCurrency" != 'CNY' and tr."status" = 'Closed' and ta.status='Closed'and tr."businessTypeDetail" in ('Payment','ConversionOut','InnerTransferOut') THEN tr."usdAmount" ELSE 0 END ) AS "conversionFxAmount" ,
(CASE WHEN ta."toCurrency" != 'CNY' and tr."status" = 'Closed' and ta.status='Closed' THEN ta."rateDiffIncomeFromUsdAmount" ELSE 0 END ) AS "conversionFxFee",
TO_CHAR(tr."createTime", 'YYYY-MM-DD')::DATE AS create_date
FROM "transfer" as tr 
LEFT JOIN "globalConversion" as ta on ta."recordId"::UUID = tr.id
LEFT JOIN "ods_sale_am_transaction_2026" AS osat ON tr."transactionId"::UUID = osat.transaction_id::UUID
LEFT JOIN LATERAL (SELECT unnest(ARRAY[osat."sale_id", osat."am_id"]) AS sale_or_am_id) AS ids ON TRUE
WHERE
tr."deleteTime" IS NULL and ta."deleteTime" IS NULL
AND tr."createTime" >= CURRENT_DATE - INTERVAL '1 day' 
AND tr."createTime" < CURRENT_DATE
) as tt
GROUP BY "accountId",create_date, status,"sale_or_am_id";

-- 18. INSERT_DATA dws_sale_crypto_assets_transfers_2026
-- =========================================
INSERT INTO "public"."dws_sale_crypto_assets_transfers_2026" (
  "id", "account_id", "sale_or_am_id", "status", "sender_type", "recipient_type","transaction_count", "origin_amount", "settlement_amount", 
  "fee", "fee2", "cross_chain_fee", "exchange_profit", "payment_profit", "hidden","create_date", "currency", "action", "version", "create_time", "update_time")
SELECT 
  generate_snowflake_id(),
  "account_id",
  ids."sale_or_am_id",
  "status",
  "sender_type",
  "recipient_type",
  COUNT(*) AS transaction_count,
  SUM("origin_amount" * "usd_rate") AS origin_amount,
  SUM("settlement_amount" * "usd_rate") AS settlement_amount,
  SUM("fee" * "usd_rate") AS fee,
  SUM("fee2" * "usd_rate") AS fee2,
  SUM("cross_chain_fee" * "usd_rate") AS cross_chain_fee,
  SUM(CASE WHEN tr."status" = 'Closed' AND tr."action" = 'sell' AND tr.hidden = FALSE AND (tr."fee" - tr."origin_amount" * 0.0009) > 0 THEN (tr."fee" - tr."origin_amount" * 0.0009) ELSE 0 END) AS exchange_profit,
  SUM(CASE WHEN tr."recipient_type" IN ('wire','outside_bank') AND tr."status" IN ('Processing','Closed') AND (tr."fee" - 25) > 0 THEN (tr."fee" - 25) ELSE 0 END) AS withdraw_fee_diff,
  "hidden",
  TO_CHAR(tr."create_time", 'YYYY-MM-DD')::DATE AS create_date,
  "currency",
  "action",
  1 AS version, 
  NOW() AS create_time,
  NOW() AS update_time
FROM "crypto_assets_transfers" AS tr
LEFT JOIN "ods_sale_am_transaction_2026" AS osat ON tr."transaction_id"::UUID = osat.transaction_id::UUID
LEFT JOIN LATERAL (SELECT unnest(ARRAY[osat."sale_id", osat."am_id"]) AS sale_or_am_id) AS ids ON TRUE
WHERE tr."delete_time" IS NULL 
  AND tr."create_time" >= CURRENT_DATE - INTERVAL '1 day' AND tr."create_time" < CURRENT_DATE
GROUP BY "account_id", "status", "sender_type", "recipient_type","hidden", create_date, "currency", "action", ids."sale_or_am_id"
ON CONFLICT (id) DO NOTHING;             

-- 19. INSERT_DATA ods_sale_fund_profits_2026
-- =========================================
INSERT INTO ods_sale_fund_profits_2026 (
    "id", "fund_id", "create_time", "update_time", "delete_time", "version", "remarks", "account_id", "sale_or_am_id", 
    "product_id", "date", "currency", "profit", "service_fee", "status", "apr", "share", "net_value")
SELECT 
    generate_snowflake_id(),
    tr."id",
    "create_time",
    "update_time",
    "delete_time",
    tr."version",
    tr."remarks",
    "account_id",
    ids."sale_or_am_id",
    "product_id",
    "date",
    "currency",
    "profit",
    (CASE WHEN fee->>'type' = 'SERVICE' THEN (fee->>'amount')::numeric ELSE 0 END) AS "service_fee",
    tr."status",
    "apr",
    "share",
    "net_value"
FROM fund_profits AS tr
CROSS JOIN LATERAL jsonb_array_elements(fees) AS fee
LEFT JOIN (
    SELECT sar."createTime", sar."deleteTime", sar."salesId", sar."amId", sar."accountId"
    FROM "salesAccountRelation" AS sar
    UNION ALL
    SELECT sar."createTime", sar."deleteTime", sar."salesId", sar."amId", account.id AS "accountId"
    FROM account
    INNER JOIN "salesAccountRelation" AS sar ON sar."accountId"::UUID = account."parentAccountId"::UUID
    WHERE account."parentAccountId" != '00000000-0000-0000-0000-000000000000'
) AS sar ON tr."account_id"::UUID = sar."accountId"::UUID
AND tr."create_time" >= sar."createTime" AND (tr."create_time" <= sar."deleteTime" OR sar."deleteTime" IS NULL)
LEFT JOIN LATERAL (SELECT unnest(ARRAY[sar."salesId"::uuid, sar."amId"::uuid]) AS sale_or_am_id) AS ids ON TRUE
WHERE tr."delete_time" IS NULL
    AND tr."create_time" >= CURRENT_DATE - INTERVAL '1 day' AND tr."create_time" < CURRENT_DATE
ON CONFLICT (id) DO NOTHING;             

-- 20. INSERT_DATA ods_sale_qbit_card_2026
-- =========================================
INSERT INTO ods_sale_qbit_card_2026 (
  "id", "create_time", "update_time", "delete_time", "version", "remarks", "sale_or_am_id", "card_id", "account_id", "currency", "status",
  "provider", "type", "token", "user_delete_time", "delete_card_time", "first_six", "card_belong", "physical_card_status", "card_mode")
SELECT 
  generate_snowflake_id(),
  tr."createTime", tr."updateTime", tr."deleteTime", tr."version", tr."remarks",
  ids."sale_or_am_id", 
  tr."id", tr."accountId", tr."currency", tr."status",
  tr."provider", tr."type", tr."token", tr."userDeleteTime",
  tr."deleteCardTime", tr."firstSix", tr."cardBelong",
  tr."physicalCardStatus", tr."cardMode"
FROM "qbitCard" AS tr
LEFT JOIN (
    SELECT sar."createTime", sar."deleteTime", sar."salesId", sar."amId", sar."accountId" AS "accountId"   
    FROM "salesAccountRelation" AS sar
    UNION ALL
    SELECT sar."createTime", sar."deleteTime", sar."salesId", sar."amId", account.id AS "accountId"   
    FROM account
    INNER JOIN "salesAccountRelation" AS sar ON sar."accountId"::UUID = account."parentAccountId"::UUID
    WHERE account."parentAccountId" != '00000000-0000-0000-0000-000000000000'
) AS sar ON tr."accountId"::UUID = sar."accountId"::UUID
AND tr."createTime" >= sar."createTime" AND (tr."createTime" <= sar."deleteTime" OR sar."deleteTime" IS NULL)
LEFT JOIN LATERAL (SELECT unnest(ARRAY[sar."salesId"::uuid, sar."amId"::uuid]) AS sale_or_am_id) AS ids ON TRUE
WHERE tr."deleteTime" IS NULL
  AND tr."createTime" >= CURRENT_DATE - INTERVAL '1 day' AND tr."createTime" < CURRENT_DATE
ON CONFLICT (id) DO NOTHING;             

-- 21. INSERT_DATA dws_sale_open_card_2026
-- =========================================
INSERT INTO "public"."dws_sale_open_card_2026" ("id", "account_id", "provider", "bin", "status", "sale_or_am_id", "fee", "count", "create_date", "version", "create_time", "update_time")
SELECT
      generate_snowflake_id() as "id",
       tr."accountId",
       qc.provider,
       qc."firstSix",
       tr."status",
       ids."sale_or_am_id",
       COALESCE(sum("senderFee"),0) fee,
       count(*) count,
       TO_CHAR(tr."createTime", 'YYYY-MM-DD')::DATE AS "create_date",
       1 AS "version", -- 初始版本号
       NOW() AS "create_time",
       NOW() AS "update_time"
FROM "Transaction" as "tr"
LEFT JOIN "qbitCard" qc ON qc."id" :: VARCHAR = "tr"."sourceId"
LEFT JOIN "public"."ods_sale_am_transaction_2026" AS osat ON tr."id"::VARCHAR = osat.transaction_id::VARCHAR
LEFT JOIN LATERAL (SELECT unnest(ARRAY[osat."sale_id", osat."am_id"]) AS sale_or_am_id) AS ids ON TRUE
where
tr."deleteTime" is NULL and tr."type" IN ('CreateCard', 'QbitCardFee') 
AND tr."createTime" >= CURRENT_DATE - INTERVAL '1 day' AND tr."createTime" < CURRENT_DATE
GROUP BY tr."status",tr."accountId",qc.provider,qc."firstSix",ids."sale_or_am_id", TO_CHAR(tr."createTime", 'YYYY-MM-DD')::DATE
ON CONFLICT (id) DO NOTHING;             

-- 22. INSERT_DATA dws_sale_physical_card_2026
-- =========================================
INSERT INTO "public"."dws_sale_physical_card_2026" ("id", "account_id", "sale_or_am_id", "provider", "bin", "status",
    "transaction_count", "physical_card_fee", "create_date", "version", "create_time", "update_time")
SELECT 
    generate_snowflake_id() AS "id",
    tr."accountId" AS "account_id",
    ids."sale_or_am_id",
    qc."provider" AS "provider",
    qc."firstSix" AS "bin",
    tr."status" AS "status", 
    COUNT(*) AS "transaction_count",
    SUM("originAmount"::numeric) AS "physical_card_fee",
    TO_CHAR(tr."createTime", 'YYYY-MM-DD')::DATE AS "create_date",
    1 AS "version",
    NOW() AS "create_time",
    NOW() AS "update_time"
FROM "qbitCardWalletTransaction" AS tr
LEFT JOIN "qbitCard" AS qc ON tr."cardId" = qc."id"
LEFT JOIN "public"."ods_sale_am_transaction_2026" AS osat ON tr."transactionId"::VARCHAR = osat.transaction_id::VARCHAR
LEFT JOIN LATERAL (SELECT unnest(ARRAY[osat."sale_id", osat."am_id"]) AS sale_or_am_id) AS ids ON TRUE
WHERE tr."deleteTime" IS NULL
  AND tr."businessType" = 'TransferOut' AND tr."remarks" IN ('邮寄费', '制卡费', '批量邮寄运费')
  AND tr."createTime" >= CURRENT_DATE - INTERVAL '1 day' AND tr."createTime" < CURRENT_DATE
GROUP BY tr."accountId", ids."sale_or_am_id", qc."provider", qc."firstSix", tr."status",TO_CHAR(tr."createTime", 'YYYY-MM-DD')::DATE
ON CONFLICT (id) DO NOTHING;             



