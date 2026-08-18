-- 01. DELETE_DATA dws_qbit_card_wallet_transaction_2026
-- =========================================
DELETE FROM "dws_qbit_card_wallet_transaction_2026" AS d
WHERE EXISTS (
  SELECT 1
  FROM "qbitCardWalletTransaction" AS tr
  WHERE tr."accountId"::VARCHAR = d."account_id"
    AND TO_CHAR(tr."createTime",'YYYY-MM-DD')::DATE = d."create_date"
    AND tr."businessType" = d."business_type"
    AND tr."updateTime" >= CURRENT_DATE - INTERVAL '1 day' AND tr."updateTime" < CURRENT_DATE
    AND TO_CHAR(tr."createTime",'YYYY-MM-DD')::DATE <> TO_CHAR(tr."updateTime",'YYYY-MM-DD')::DATE
);

-- 02. DELETE_DATA dws_qbit_card_transaction_2026
-- =========================================
DELETE FROM "dws_qbit_card_transaction_2026" AS d
WHERE EXISTS (
  SELECT 1
  FROM "qbitCardTransaction" AS tr
  LEFT JOIN "qbitCard" AS qc ON tr."cardId" = qc."id"
  WHERE tr."accountId"::VARCHAR = d."account_id"
    AND tr."provider" = d."provider" 
    AND qc."firstSix" = d."bin"
    AND tr."businessType" = d."business_type"
    AND TO_CHAR(tr."createTime",'YYYY-MM-DD')::DATE = d."create_date"     
    AND tr."updateTime" >= CURRENT_DATE - INTERVAL '1 day' AND tr."updateTime" < CURRENT_DATE
    AND TO_CHAR(tr."createTime",'YYYY-MM-DD')::DATE <> TO_CHAR(tr."updateTime",'YYYY-MM-DD')::DATE
);

-- 03. DELETE_DATA dws_qbit_card_transaction_extend_2026
-- =========================================
DELETE FROM "dws_qbit_card_transaction_extend_2026" AS d
WHERE EXISTS (
  SELECT 1
  FROM "qbitCardTransaction" AS tr
  LEFT JOIN "qbitCard" AS qc ON tr."cardId" = qc."id"
  WHERE tr."accountId"::VARCHAR = d."account_id"
    AND tr."provider" = d."provider" 
    AND COALESCE(qc."firstSix",'') = COALESCE(d."bin",'')
    AND tr."businessType"= d."business_type"
    AND TO_CHAR(tr."createTime",'YYYY-MM-DD')::DATE = d."create_date"
    AND tr."transactionCurrency" = d."transaction_currency"
    AND tr."specialSourceData"->>'country' = d."country"
    AND tr."updateTime" >= CURRENT_DATE - INTERVAL '1 day' AND tr."updateTime" < CURRENT_DATE
    AND TO_CHAR(tr."createTime",'YYYY-MM-DD')::DATE <> TO_CHAR(tr."updateTime",'YYYY-MM-DD')::DATE
);

-- 04. DELETE_DATA dws_qbit_card_group_transaction_2026
-- =========================================
DELETE FROM "dws_qbit_card_group_transaction_2026" AS d
WHERE EXISTS (
  SELECT 1
  FROM "qbitCardGroupTransaction" AS tr
  WHERE tr."accountId"::VARCHAR = d."account_id"
    AND tr."businessType" = d."business_type"
    AND TO_CHAR(tr."createTime",'YYYY-MM-DD')::DATE = d."create_date"
    AND tr."updateTime" >= CURRENT_DATE - INTERVAL '1 day' AND tr."updateTime" < CURRENT_DATE
    AND tr."createTime"::DATE <> tr."updateTime"::DATE
);

-- 05. DELETE_DATA dws_transfer_2026
-- =========================================
DELETE FROM "dws_transfer_2026" AS d
WHERE EXISTS (
  SELECT 1
  FROM "transfer" AS tr
  WHERE tr."accountId"::VARCHAR = d."account_id"
    AND tr."businessTypeDetail" = d."business_type_detail"
    AND tr."settlementCurrency" = d."settlement_currency"
    AND tr."currency" = d."currency"
    AND tr."createTime"::DATE = d."create_date"
    AND tr."updateTime" >= CURRENT_DATE - INTERVAL '1 day' AND tr."updateTime" < CURRENT_DATE
    AND tr."createTime"::DATE <> tr."updateTime"::DATE
);

-- 06. DELETE_DATA dws_transfer_extend_2026
-- =========================================
DELETE FROM "dws_transfer_extend_2026" AS d
WHERE EXISTS (
  SELECT 1
  FROM "transfer" AS tr
  WHERE tr."accountId"::VARCHAR = d."account_id"
    AND tr."createTime"::DATE = d."create_date"
    AND tr."updateTime" >= CURRENT_DATE - INTERVAL '1 day' AND tr."updateTime" < CURRENT_DATE
    AND tr."createTime"::DATE <> tr."updateTime"::DATE
);

-- 07. DELETE_DATA dws_crypto_assets_transfers_2026
-- =========================================
DELETE FROM "dws_crypto_assets_transfers_2026" AS d
WHERE EXISTS (
  SELECT 1
  FROM "crypto_assets_transfers" AS tr
  WHERE tr."account_id"::VARCHAR = d."account_id"
    AND tr."sender_type" = d."sender_type"
    AND tr."recipient_type" = d."recipient_type"
    AND tr."hidden" = d."hidden"
    AND tr."currency" = d."currency"
    AND tr."action" = d."action"
    AND tr."create_time"::DATE = d."create_date"
    AND tr."update_time" >= CURRENT_DATE - INTERVAL '1 day'AND tr."update_time" < CURRENT_DATE
    AND tr."create_time"::DATE <> tr."update_time"::DATE
);

-- 08. DELETE_DATA ods_fund_profits_2026
-- =========================================
DELETE FROM "ods_fund_profits_2026" AS d
WHERE EXISTS (
  SELECT 1
  FROM "fund_profits" AS tr
  WHERE tr."id" = d."fund_id"
    AND tr."update_time" >= CURRENT_DATE - INTERVAL '1 day' AND tr."update_time" < CURRENT_DATE
    AND tr."create_time"::DATE <> tr."update_time"::DATE
);

-- 09. DELETE_DATA ods_qbit_card_2026
-- =========================================
DELETE FROM "ods_qbit_card_2026" AS d
WHERE EXISTS (
  SELECT 1
  FROM "qbitCard" AS tr
  WHERE tr."id" = d."card_id"
    AND tr."updateTime" >= CURRENT_DATE - INTERVAL '1 day' AND tr."updateTime" < CURRENT_DATE
    AND TO_CHAR(tr."createTime",'YYYY-MM-DD')::DATE <> TO_CHAR(tr."updateTime",'YYYY-MM-DD')::DATE
);

-- 10. DELETE_DATA dws_open_card_2026
-- =========================================
DELETE FROM "dws_open_card_2026" AS d
WHERE EXISTS (
  SELECT 1
  FROM "Transaction" AS tr
  LEFT JOIN "qbitCard" AS qc ON qc."id"::VARCHAR = tr."sourceId"
  WHERE tr."accountId"::VARCHAR = d."account_id" 
    AND qc."provider"=d."provider"
    AND qc."firstSix"=COALESCE(d."bin",'')
    AND tr."type" IN ('CreateCard','QbitCardFee')
    AND TO_CHAR(tr."createTime",'YYYY-MM-DD')::DATE = d."create_date"
    AND tr."updateTime" >= CURRENT_DATE - INTERVAL '1 day'AND tr."updateTime" < CURRENT_DATE
    AND TO_CHAR(tr."createTime",'YYYY-MM-DD')::DATE <> TO_CHAR(tr."updateTime",'YYYY-MM-DD')::DATE
);

-- 11. DELETE_DATA dws_physical_card_2026
-- =========================================
DELETE FROM "dws_physical_card_2026" AS d
WHERE EXISTS (
  SELECT 1
  FROM "qbitCardWalletTransaction" AS tr
  LEFT JOIN "qbitCard" AS qc ON tr."cardId" = qc."id"
  WHERE tr."accountId"::VARCHAR = d."account_id" 
    AND tr."businessType" = 'TransferOut'
    AND tr."remarks" IN ('邮寄费','制卡费','批量邮寄运费')
    AND qc."provider" = d."provider"
    AND qc."firstSix" = d."bin"
    AND TO_CHAR(tr."createTime",'YYYY-MM-DD')::DATE = d."create_date"
    AND tr."updateTime" >= CURRENT_DATE - INTERVAL '1 day' AND tr."updateTime" < CURRENT_DATE
    AND TO_CHAR(tr."createTime",'YYYY-MM-DD')::DATE <> TO_CHAR(tr."updateTime",'YYYY-MM-DD')::DATE
);

-- 12. DELETE_DATA dws_sale_card_wallet_transaction_2026
-- =========================================
DELETE FROM "dws_sale_card_wallet_transaction_2026" AS d
WHERE EXISTS (
  SELECT 1
  FROM "qbitCardWalletTransaction" AS tr
  LEFT JOIN "public"."ods_sale_am_transaction_2026" AS osat ON tr."transactionId"::UUID = osat.transaction_id::UUID
  LEFT JOIN LATERAL (SELECT unnest(ARRAY[osat."sale_id", osat."am_id"]) AS sale_or_am_id) AS ids ON TRUE
  WHERE tr."accountId"::VARCHAR = d."account_id" 
    AND tr."businessType" = d."business_type"
    AND ids."sale_or_am_id" = d."sale_or_am_id"
    AND TO_CHAR(tr."createTime",'YYYY-MM-DD')::DATE = d."create_date"
    AND tr."updateTime" >= CURRENT_DATE - INTERVAL '1 day' AND tr."updateTime" < CURRENT_DATE
    AND TO_CHAR(tr."createTime",'YYYY-MM-DD')::DATE <> TO_CHAR(tr."updateTime",'YYYY-MM-DD')::DATE
);

-- 13. DELETE_DATA dws_qbit_card_transaction_2026
-- =========================================
DELETE FROM "dws_sale_card_transaction_2026" AS d
WHERE EXISTS (
  SELECT 1
  FROM "qbitCardTransaction" AS tr
  LEFT JOIN "qbitCard" AS qc ON tr."cardId" = qc."id"
  LEFT JOIN "ods_sale_am_transaction_2026" AS osat ON tr."transactionId"::UUID = osat.transaction_id::UUID
  LEFT JOIN LATERAL ( SELECT unnest(ARRAY[osat."sale_id", osat."am_id"]) AS sale_or_am_id) AS ids ON TRUE
  WHERE tr."accountId"::VARCHAR = d."account_id"
    AND ids."sale_or_am_id" = d."sale_or_am_id" 
    AND tr."businessType" = d."business_type"
    AND tr."provider" = d."provider"
    AND qc."firstSix" = d."bin"
    AND TO_CHAR(tr."createTime",'YYYY-MM-DD')::DATE = d."create_date"
    AND tr."updateTime" >= CURRENT_DATE - INTERVAL '1 day' AND tr."updateTime" < CURRENT_DATE
    AND tr."createTime"::DATE <> tr."updateTime"::DATE
);

-- 14. DELETE_DATA dws_sale_card_transaction_extend_2026
-- =========================================
DELETE FROM "dws_sale_card_transaction_extend_2026" AS d
WHERE EXISTS (
  SELECT 1
  FROM "qbitCardTransaction" AS tr
  LEFT JOIN "qbitCard" AS qc ON tr."cardId" = qc.id
  LEFT JOIN "ods_sale_am_transaction_2026" AS osat ON tr."transactionId"::UUID = osat.transaction_id::UUID
  LEFT JOIN LATERAL ( SELECT unnest(ARRAY[osat."sale_id", osat."am_id"]) AS sale_or_am_id) AS ids ON TRUE
  WHERE tr."accountId"::VARCHAR = d."account_id"
    AND ids."sale_or_am_id" = d."sale_or_am_id"
    AND tr."businessType" = d."business_type" 
    AND tr."provider" = d."provider"
    AND qc."firstSix" = d."bin"
    AND tr."transactionCurrency" = d."transaction_currency"
    AND tr."specialSourceData"->>'country' = d."country"
    AND TO_CHAR(tr."createTime",'YYYY-MM-DD')::DATE = d."create_date"
    AND tr."updateTime" >= CURRENT_DATE - INTERVAL '1 day'AND tr."updateTime" < CURRENT_DATE
    AND TO_CHAR(tr."createTime",'YYYY-MM-DD')::DATE <> TO_CHAR(tr."updateTime",'YYYY-MM-DD')::DATE
);  

-- 15. DELETE_DATA dws_sale_card_group_transaction_2026
-- =========================================
DELETE FROM "dws_sale_card_group_transaction_2026" AS d
WHERE EXISTS (
  SELECT 1
  FROM "qbitCardGroupTransaction" AS tr
  LEFT JOIN "ods_sale_am_transaction_2026" AS osat ON tr."transactionId"::UUID = osat.transaction_id::UUID
  LEFT JOIN LATERAL (SELECT unnest(ARRAY[osat."sale_id", osat."am_id"]) AS sale_or_am_id) AS ids ON TRUE
  WHERE tr."accountId"::VARCHAR = d."account_id" 
    AND tr."businessType" = d."business_type"
    AND ids."sale_or_am_id" = d."sale_or_am_id"
    AND TO_CHAR(tr."createTime",'YYYY-MM-DD')::DATE = d."create_date"
    AND tr."updateTime" >= CURRENT_DATE - INTERVAL '1 day' AND tr."updateTime" < CURRENT_DATE
    AND tr."createTime"::DATE <> tr."updateTime"::DATE
);

-- 16. DELETE_DATA dws_sale_transfer_2026
-- =========================================
DELETE FROM "dws_sale_transfer_2026" AS d
WHERE EXISTS (
  SELECT 1
  FROM "transfer" AS tr
  LEFT JOIN "ods_sale_am_transaction_2026" AS osat ON tr."transactionId"::UUID = osat.transaction_id::UUID
  LEFT JOIN LATERAL ( SELECT unnest(ARRAY[osat."sale_id", osat."am_id"]) AS sale_or_am_id) AS ids ON TRUE
  WHERE tr."accountId"::VARCHAR = d."account_id" 
    AND ids."sale_or_am_id" = d."sale_or_am_id"
    AND tr."businessTypeDetail" = d."business_type_detail"
    AND tr."settlementCurrency" = d."settlement_currency"
    AND tr."currency" = d."currency"
    AND TO_CHAR(tr."createTime",'YYYY-MM-DD')::DATE = d."create_date"
    AND tr."updateTime" >= CURRENT_DATE - INTERVAL '1 day' AND tr."updateTime" < CURRENT_DATE
    AND tr."createTime"::DATE <> tr."updateTime"::DATE
);

-- 17. DELETE_DATA dws_sale_transfer_extend_2026
-- =========================================
DELETE FROM "dws_sale_transfer_extend_2026" AS d
WHERE EXISTS (
  SELECT 1
  FROM "transfer" as tr 
  LEFT JOIN "globalConversion" as ta on ta."recordId"::UUID = tr.id
  LEFT JOIN "ods_sale_am_transaction_2026" AS osat ON tr."transactionId"::UUID = osat.transaction_id::UUID
  LEFT JOIN LATERAL (SELECT unnest(ARRAY[osat."sale_id", osat."am_id"]) AS sale_or_am_id) AS ids ON TRUE
  WHERE tr."accountId"::VARCHAR = d."account_id" 
    AND ids."sale_or_am_id" = d."sale_or_am_id"
    AND tr."createTime"::DATE = d."create_date"
    AND tr."updateTime" >= CURRENT_DATE - INTERVAL '1 day' AND tr."updateTime" < CURRENT_DATE
    AND tr."createTime"::DATE <> tr."updateTime"::DATE
);

-- 18. DELETE_DATA dws_sale_crypto_assets_transfers_2026
-- =========================================
DELETE FROM "dws_sale_crypto_assets_transfers_2026" AS d
WHERE EXISTS (
  SELECT 1
  FROM "crypto_assets_transfers" AS tr
  LEFT JOIN "ods_sale_am_transaction_2026" AS osat ON tr."transaction_id"::UUID = osat.transaction_id::UUID
  LEFT JOIN LATERAL (SELECT unnest(ARRAY[osat."sale_id", osat."am_id"]) AS sale_or_am_id) AS ids ON TRUE
  WHERE tr."account_id"::VARCHAR = d."account_id" 
    AND ids."sale_or_am_id" = d."sale_or_am_id"
    AND tr."sender_type" = d."sender_type"
    AND tr."recipient_type" = d."recipient_type"
    AND tr."hidden" = d."hidden"
    AND tr."currency" = d."currency"
    AND tr."action" = d."action"
    AND tr."create_time"::DATE = d."create_date"
    AND tr."update_time" >= CURRENT_DATE - INTERVAL '1 day' AND tr."update_time" < CURRENT_DATE
    AND tr."create_time"::DATE <> tr."update_time"::DATE
);

-- 19. DELETE_DATA ods_sale_fund_profits_2026
-- =========================================
DELETE FROM "ods_sale_fund_profits_2026" AS d
WHERE EXISTS (
  SELECT 1
  FROM "fund_profits" AS tr
  WHERE tr."id" = d."fund_id"
    AND tr."update_time" >= CURRENT_DATE - INTERVAL '1 day' AND tr."update_time" < CURRENT_DATE
    AND tr."create_time"::DATE <> tr."update_time"::DATE
);

-- 20. DELETE_DATA ods_sale_qbit_card_2026
-- =========================================
DELETE FROM "ods_sale_qbit_card_2026" AS d
WHERE EXISTS (
  SELECT 1
  FROM "qbitCard" AS tr
  WHERE tr."id" = d."card_id"
    AND tr."updateTime" >= CURRENT_DATE - INTERVAL '1 day' AND tr."updateTime" < CURRENT_DATE
    AND tr."updateTime"::DATE <> tr."createTime"::DATE
);

-- 21. DELETE_DATA dws_sale_open_card_2026
-- =========================================
DELETE FROM "dws_sale_open_card_2026" AS d
WHERE EXISTS (
  SELECT 1
  FROM "Transaction" AS tr
  LEFT JOIN "qbitCard" qc ON qc."id"::VARCHAR = tr."sourceId"
  LEFT JOIN "public"."ods_sale_am_transaction_2026" AS osat ON tr."transactionId"::VARCHAR = osat.transaction_id::VARCHAR
  LEFT JOIN LATERAL (SELECT unnest(ARRAY[osat."sale_id", osat."am_id"]) AS sale_or_am_id) AS ids ON TRUE
  WHERE tr."accountId"::VARCHAR = d."account_id"
    AND tr."type" IN ('CreateCard','QbitCardFee')
    AND qc."provider" = d."provider"
    AND qc."firstSix" = d."bin"
    AND ids."sale_or_am_id" = d."sale_or_am_id"
    AND TO_CHAR(tr."createTime",'YYYY-MM-DD')::DATE = d."create_date"
    AND tr."updateTime" >= CURRENT_DATE - INTERVAL '1 day' AND tr."updateTime" < CURRENT_DATE
    AND TO_CHAR(tr."createTime",'YYYY-MM-DD')::DATE <> TO_CHAR(tr."updateTime",'YYYY-MM-DD')::DATE
);

-- 22. DELETE_DATA dws_sale_physical_card_2026
-- =========================================
DELETE FROM "dws_sale_physical_card_2026" AS d
WHERE EXISTS (
    SELECT 1
    FROM "qbitCardWalletTransaction" AS tr
    LEFT JOIN "qbitCard" AS qc ON tr."cardId" = qc."id"
    LEFT JOIN "public"."ods_sale_am_transaction_2026" AS osat ON tr."transactionId"::VARCHAR = osat.transaction_id::VARCHAR
    LEFT JOIN LATERAL (SELECT unnest(ARRAY[osat."sale_id", osat."am_id"]) AS sale_or_am_id) AS ids ON TRUE
    WHERE tr."accountId"::VARCHAR = d."account_id"
      AND tr."businessType" = 'TransferOut' 
      AND tr."remarks" IN ('邮寄费','制卡费','批量邮寄运费')
      AND qc."provider" = d."provider"
      AND qc."firstSix" = d."bin"
      AND ids."sale_or_am_id" = d."sale_or_am_id"
      AND TO_CHAR(tr."createTime",'YYYY-MM-DD')::DATE = d."create_date"
      AND tr."updateTime" >= CURRENT_DATE - INTERVAL '1 day' AND tr."updateTime" < CURRENT_DATE
      AND TO_CHAR(tr."createTime",'YYYY-MM-DD')::DATE <> TO_CHAR(tr."updateTime",'YYYY-MM-DD')::DATE
);
