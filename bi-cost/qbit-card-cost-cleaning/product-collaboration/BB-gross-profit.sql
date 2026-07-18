-- 1、Master Dom Count Fee
SELECT count(*)*0.11, count(*) FROM "qbitCardTransaction" A
LEFT JOIN "qbitCardSettlement" B ON A."sourceId"=B."transactionId"
AND B."provider" = 'BlueBancCard'
AND B."transactionType" NOT IN ('ST-REFUND_ADV','ST-PURCHASE_ADV','ST-ECOMM_ADV','ST-SETT_ADV','ST-ATM_ADV')
LEFT JOIN "qbitCard" C ON A."cardId"=C."id"
WHERE A."businessType" = 'Consumption'
AND A."provider" LIKE 'Blue%'
AND A."createTime" >= '2026-01-01 00:00:00'::timestamp - INTERVAL '8 hours'
AND A."createTime" < '2026-02-01 00:00:00'::timestamp - INTERVAL '8 hours'
AND A."specialSourceData"->>'country' IN ('US','USA')

--需要解析字段
-- AND B."rawData"->>'responseCode'='APPROVE'
AND safe_json_text(B."rawData", 'responseCode')='APPROVE'
AND B."transactionType" IN ('authorization.clearing','authorization.reversal') 
AND C."type" ='Master'



-- 2、Master int Count Fee
SELECT count(*)*0.48 FROM "qbitCardTransaction" A
LEFT JOIN "qbitCardSettlement" B ON A."sourceId"=B."transactionId"
AND B."provider" = 'BlueBancCard'
AND B."transactionType" NOT IN ('ST-REFUND_ADV','ST-PURCHASE_ADV','ST-ECOMM_ADV','ST-SETT_ADV','ST-ATM_ADV')
LEFT JOIN "qbitCard" C ON A."cardId"=C."id"

WHERE A."businessType" = 'Consumption'
AND A."provider" LIKE 'Blue%'
AND A."createTime" >= '2026-01-01 00:00:00'::timestamp - INTERVAL '8 hours'
AND A."createTime" < '2026-02-01 00:00:00'::timestamp - INTERVAL '8 hours'
AND A."specialSourceData"->>'country' NOT IN ('US','USA')
--需要解析字段
-- AND B."rawData"->>'responseCode'='APPROVE'
AND safe_json_text(B."rawData", 'responseCode')='APPROVE'
AND B."transactionType" IN ('authorization.clearing','authorization.reversal') 
AND C."type" ='Master'



-- 3、Master Int Decline  Count  Fee：
-- 目前缺少历史数据，卡关闭、卡冻结导致的失败：
SELECT count(*)*0.36 FROM "qbitCardTransaction" A
LEFT JOIN "qbitCardSettlement" B ON A."sourceId"=B."transactionId"
AND B."provider" = 'BlueBancCard'
AND B."transactionType" NOT IN ('ST-REFUND_ADV','ST-PURCHASE_ADV','ST-ECOMM_ADV','ST-SETT_ADV','ST-ATM_ADV')
LEFT JOIN "qbitCard" C ON A."cardId"=C."id"

WHERE A."businessType" = 'Consumption'
AND A."provider" LIKE 'Blue%'
AND A."createTime" >= '2026-01-01 00:00:00'::timestamp - INTERVAL '8 hours'
AND A."createTime" < '2026-02-01 00:00:00'::timestamp - INTERVAL '8 hours'
AND A."specialSourceData"->>'country' NOT IN ('US','USA')
--需要解析字段
-- AND B."rawData"->>'responseCode'='APPROVE'
AND B."transactionType" NOT IN('refund.clearing','NT-ACC_VERIFY')
AND safe_json_text(B."rawData", 'responseCode')='DECLINE'
AND C."type" ='Master'


-- 4、Master Int Reversal  Count Fee
SELECT count(*)*0.72,count(*) FROM "qbitCardTransaction" A
LEFT JOIN "qbitCardSettlement" B ON A."sourceId"=B."transactionId"
AND B."provider" = 'BlueBancCard'
AND B."transactionType" NOT IN ('ST-REFUND_ADV','ST-PURCHASE_ADV','ST-ECOMM_ADV','ST-SETT_ADV','ST-ATM_ADV')
LEFT JOIN "qbitCard" C ON A."cardId"=C."id"

WHERE A."businessType" = 'Consumption'
AND A."provider" LIKE 'Blue%'
AND A."createTime" >= '2026-01-01 00:00:00'::timestamp - INTERVAL '8 hours'
AND A."createTime" < '2026-02-01 00:00:00'::timestamp - INTERVAL '8 hours'
AND A."specialSourceData"->>'country' NOT IN ('US','USA')
--需要解析字段
-- AND B."rawData"->>'responseCode'='APPROVE'
AND safe_json_text(B."rawData", 'responseCode')='APPROVE'
AND C."type" ='Master'
AND safe_json_text(B."rawData", 'requestCode') IN ('ST-AUTH_REV','ST-PARTIAL_REV')
AND safe_json_text(B."rawData", 'reasonCode') = 'APPROVE'
AND safe_json_text(B."rawData", 'responseCode') = 'APPROVE'



-- 5、Master Int Refund Count Fee
-- 目前我方缺少很多订单
SELECT count(*)*0.48,COUNT(*) FROM "qbitCardTransaction" A
LEFT JOIN "qbitCardSettlement" B ON A."id"=B."qbitCardTransactionId"::uuid
AND B."provider" = 'BlueBancCard'
AND B."transactionType" NOT IN ('ST-REFUND_ADV','ST-PURCHASE_ADV','ST-ECOMM_ADV','ST-SETT_ADV','ST-ATM_ADV')
LEFT JOIN "qbitCard" C ON A."cardId"=C."id"

WHERE 1=1
-- AND A."businessType" = 'Credit'
AND A."provider" LIKE 'Blue%'
-- AND A."createTime" >= '2026-01-01 08:00:00'
-- AND A."createTime" < '2026-02-01 08:00:00'
-- AND A."specialSourceData"->>'country' NOT IN ('US','USA')
AND RIGHT(safe_json_text(B."rawData", 'txnLocation'), 2) NOT IN ('US','USA')
--需要解析字段
AND C."type" ='Master'
AND safe_json_text(B."rawData", 'settleDate')::timestamp >= '2026-01-01'
AND safe_json_text(B."rawData", 'settleDate')::timestamp < '2026-02-01'
AND safe_json_text(B."rawData", 'responseCode') = 'APPROVE'
AND B."transactionType"='refund.clearing'





-- 6、VISA Dom Count Fee
SELECT count(*)*0.073 FROM "qbitCardTransaction" A
LEFT JOIN "qbitCardSettlement" B ON A."sourceId"=B."transactionId"
AND B."provider" = 'BlueBancCard'
AND B."transactionType" NOT IN ('ST-REFUND_ADV','ST-PURCHASE_ADV','ST-ECOMM_ADV','ST-SETT_ADV','ST-ATM_ADV')
LEFT JOIN "qbitCard" C ON A."cardId"=C."id"

WHERE A."businessType" = 'Consumption'
AND A."provider" LIKE 'Blue%'
AND A."createTime" >= '2026-01-01 00:00:00'::timestamp - INTERVAL '8 hours'
AND A."createTime" < '2026-02-01 00:00:00'::timestamp - INTERVAL '8 hours'
AND A."specialSourceData"->>'country' IN ('US','USA')
--需要解析字段
-- AND B."rawData"->>'responseCode'='APPROVE'
AND safe_json_text(B."rawData", 'responseCode')='APPROVE'
AND B."transactionType" IN ('authorization.clearing','authorization.reversal') 
AND C."type" ='VISA'



-- 7、VISA Int Count Fee
SELECT count(*)*0.48 FROM "qbitCardTransaction" A
LEFT JOIN "qbitCardSettlement" B ON A."sourceId"=B."transactionId"
AND B."provider" = 'BlueBancCard'
AND B."transactionType" NOT IN ('ST-REFUND_ADV','ST-PURCHASE_ADV','ST-ECOMM_ADV','ST-SETT_ADV','ST-ATM_ADV')
LEFT JOIN "qbitCard" C ON A."cardId"=C."id"

WHERE A."businessType" = 'Consumption'
AND A."provider" LIKE 'Blue%'
AND A."createTime" >= '2026-01-01 00:00:00'::timestamp - INTERVAL '8 hours'
AND A."createTime" < '2026-02-01 00:00:00'::timestamp - INTERVAL '8 hours'
AND A."specialSourceData"->>'country' NOT IN ('US','USA')
--需要解析字段
-- AND B."rawData"->>'responseCode'='APPROVE'
AND safe_json_text(B."rawData", 'responseCode')='APPROVE'
AND B."transactionType" IN ('authorization.clearing','authorization.reversal') 
AND C."type" ='VISA'


-- 8、VISA Int Decline  Count  Fee：
-- 目前缺少历史数据，卡关闭、卡冻结导致的失败：
SELECT count(*)*0.36 FROM "qbitCardTransaction" A
LEFT JOIN "qbitCardSettlement" B ON A."sourceId"=B."transactionId"
AND B."provider" = 'BlueBancCard'
AND B."transactionType" NOT IN ('ST-REFUND_ADV','ST-PURCHASE_ADV','ST-ECOMM_ADV','ST-SETT_ADV','ST-ATM_ADV')
LEFT JOIN "qbitCard" C ON A."cardId"=C."id"

WHERE A."businessType" = 'Consumption'
AND A."provider" LIKE 'Blue%'
AND A."createTime" >= '2026-01-01 00:00:00'::timestamp - INTERVAL '8 hours'
AND A."createTime" < '2026-02-01 00:00:00'::timestamp - INTERVAL '8 hours'
AND A."specialSourceData"->>'country' NOT IN ('US','USA')
--需要解析字段
-- AND B."rawData"->>'responseCode'='APPROVE'
AND B."transactionType" NOT IN('refund.clearing','NT-ACC_VERIFY')
AND safe_json_text(B."rawData", 'responseCode')='DECLINE'
AND C."type" ='VISA'


-- 9、VISA Int Reversal  Count Fee
SELECT count(*)*0.71 FROM "qbitCardTransaction" A
LEFT JOIN "qbitCardSettlement" B ON A."sourceId"=B."transactionId"
AND B."provider" = 'BlueBancCard'
AND B."transactionType" NOT IN ('ST-REFUND_ADV','ST-PURCHASE_ADV','ST-ECOMM_ADV','ST-SETT_ADV','ST-ATM_ADV')
LEFT JOIN "qbitCard" C ON A."cardId"=C."id"

WHERE A."businessType" = 'Consumption'
AND A."provider" LIKE 'Blue%'
AND A."createTime" >= '2026-01-01 00:00:00'::timestamp - INTERVAL '8 hours'
AND A."createTime" < '2026-02-01 00:00:00'::timestamp - INTERVAL '8 hours'
AND A."specialSourceData"->>'country' NOT IN ('US','USA')
--需要解析字段
-- AND B."rawData"->>'responseCode'='APPROVE'
AND safe_json_text(B."rawData", 'responseCode')='APPROVE'
AND C."type" ='VISA'
AND safe_json_text(B."rawData", 'requestCode') IN ('ST-AUTH_REV','ST-PARTIAL_REV')
AND safe_json_text(B."rawData", 'reasonCode') = 'APPROVE'
AND safe_json_text(B."rawData", 'responseCode') = 'APPROVE'



-- 10、VISA Int Refund Count Fee
-- 目前我方缺少很多订单
SELECT count(*)*0.48 FROM "qbitCardTransaction" A
LEFT JOIN "qbitCardSettlement" B ON A."id"=B."qbitCardTransactionId"::uuid
AND B."provider" = 'BlueBancCard'
AND B."transactionType" NOT IN ('ST-REFUND_ADV','ST-PURCHASE_ADV','ST-ECOMM_ADV','ST-SETT_ADV','ST-ATM_ADV')
LEFT JOIN "qbitCard" C ON A."cardId"=C."id"

WHERE 1=1
-- AND A."businessType" = 'Credit'
AND A."provider" LIKE 'Blue%'
-- AND A."createTime" >= '2026-01-01 08:00:00'
-- AND A."createTime" < '2026-02-01 08:00:00'
-- AND A."specialSourceData"->>'country' NOT IN ('US','USA')
AND RIGHT(safe_json_text(B."rawData", 'txnLocation'), 2) NOT IN ('US','USA')
--需要解析字段
AND C."type" ='VISA'
AND safe_json_text(B."rawData", 'settleDate')::timestamp >= '2026-01-01'
AND safe_json_text(B."rawData", 'settleDate')::timestamp < '2026-02-01'
AND safe_json_text(B."rawData", 'responseCode') = 'APPROVE'
-- AND safe_json_text(B."rawData", 'txnCountry') = NOT IN ('US','USA')
AND B."transactionType"='refund.clearing'





-- 本地

-- 11、DOM Decline  Count  Fee：
-- 目前缺少历史数据，卡关闭、卡冻结导致的失败：
SELECT count(*)*0.089 FROM "qbitCardTransaction" A
LEFT JOIN "qbitCardSettlement" B ON A."sourceId"=B."transactionId"
AND B."provider" = 'BlueBancCard'
AND B."transactionType" NOT IN ('ST-REFUND_ADV','ST-PURCHASE_ADV','ST-ECOMM_ADV','ST-SETT_ADV','ST-ATM_ADV')
LEFT JOIN "qbitCard" C ON A."cardId"=C."id"

WHERE A."businessType" = 'Consumption'
AND A."provider" LIKE 'Blue%'
AND A."createTime" >= '2026-01-01 00:00:00'::timestamp - INTERVAL '8 hours'
AND A."createTime" < '2026-02-01 00:00:00'::timestamp - INTERVAL '8 hours'
AND A."specialSourceData"->>'country' IN ('US','USA')
--需要解析字段
-- AND B."rawData"->>'responseCode'='APPROVE'
AND B."transactionType" NOT IN('refund.clearing','NT-ACC_VERIFY')
AND safe_json_text(B."rawData", 'responseCode')='DECLINE'






-- 12、DOM Reversal Count Fee
SELECT count(*)*0.18 FROM "qbitCardTransaction" A
LEFT JOIN "qbitCardSettlement" B ON A."sourceId"=B."transactionId"
AND B."provider" = 'BlueBancCard'
AND B."transactionType" NOT IN ('ST-REFUND_ADV','ST-PURCHASE_ADV','ST-ECOMM_ADV','ST-SETT_ADV','ST-ATM_ADV')
LEFT JOIN "qbitCard" C ON A."cardId"=C."id"

WHERE A."businessType" = 'Consumption'
AND A."provider" LIKE 'Blue%'
AND A."createTime" >= '2026-01-01 00:00:00'::timestamp - INTERVAL '8 hours'
AND A."createTime" < '2026-02-01 00:00:00'::timestamp - INTERVAL '8 hours'
AND A."specialSourceData"->>'country' IN ('US','USA')
--需要解析字段
-- AND B."rawData"->>'responseCode'='APPROVE'
AND safe_json_text(B."rawData", 'responseCode')='APPROVE'
AND safe_json_text(B."rawData", 'requestCode') IN ('ST-AUTH_REV','ST-PARTIAL_REV')
AND safe_json_text(B."rawData", 'reasonCode') = 'APPROVE'


-- 13、DOM Refund Count Fee
SELECT count(*)*0.11 FROM "qbitCardTransaction" A
LEFT JOIN "qbitCardSettlement" B ON A."id"=B."qbitCardTransactionId"::uuid
AND B."provider" = 'BlueBancCard'
AND B."transactionType" NOT IN ('ST-REFUND_ADV','ST-PURCHASE_ADV','ST-ECOMM_ADV','ST-SETT_ADV','ST-ATM_ADV')
LEFT JOIN "qbitCard" C ON A."cardId"=C."id"

WHERE 1=1
AND A."businessType" = 'Credit'
AND A."provider" LIKE 'Blue%'
-- AND A."createTime" >= '2026-01-01 08:00:00'
-- AND A."createTime" < '2026-02-01 08:00:00'
-- AND A."specialSourceData"->>'country' NOT IN ('US','USA')
AND RIGHT(safe_json_text(B."rawData", 'txnLocation'), 2) NOT IN ('US','USA')
--需要解析字段
AND safe_json_text(B."rawData", 'settleDate')::timestamp >= '2026-01-01'
AND safe_json_text(B."rawData", 'settleDate')::timestamp < '2026-02-01'
AND safe_json_text(B."rawData", 'responseCode') = 'APPROVE'
-- AND safe_json_text(B."rawData", 'txnCountry') = NOT IN ('US','USA')
AND B."transactionType"='refund.clearing'



-- 14、量子卡Cashback收入，渠道返给我们的收入
-- 这里拿总金额*BB渠道返点，返点每次都是由BB渠道给出，这里没有任何规则可以参考，因为这是他们上游给的：2026-01为2.21%、2025-12为2.34%
SELECT 
    '消费金额' as "交易类型",
    SUM(B."billingAmount") as "消费金额",
		SUM(B."billingAmount")*0.0221 as "fee"
FROM "qbitCardTransaction" A
LEFT JOIN "qbitCardSettlement" B ON A."sourceId" = B."transactionId"
    AND B."provider" = 'BlueBancCard'
    AND B."transactionType" NOT IN ('ST-REFUND_ADV','ST-PURCHASE_ADV','ST-ECOMM_ADV','ST-SETT_ADV','ST-ATM_ADV')
    AND B."transactionType" = 'authorization.clearing'
LEFT JOIN "qbitCard" D ON A."cardId" = D."id"
WHERE 1=1
    AND A."businessType" IN ('Credit','Consumption')
    AND A."provider" LIKE 'Blue%'
    AND A."thirdCompleteTime" >= '2026-01-01 00:00:00'
    AND A."thirdCompleteTime" < '2026-02-01 00:00:00'
    AND safe_json_text(B."rawData", 'responseCode') = 'APPROVE'

UNION ALL

-- 退款金额
SELECT 
    '退款金额' as "交易类型",
    SUM(B."billingAmount") as "退款金额",
		SUM(B."billingAmount")*0.0021 as "fee"
FROM "qbitCardTransaction" A
LEFT JOIN "qbitCardSettlement" B ON A."id" = B."qbitCardTransactionId"::uuid
    AND B."provider" = 'BlueBancCard'
    AND B."transactionType" NOT IN ('ST-REFUND_ADV','ST-PURCHASE_ADV','ST-ECOMM_ADV','ST-SETT_ADV','ST-ATM_ADV')
    AND B."transactionType" = 'refund.clearing'
LEFT JOIN "qbitCard" D ON A."cardId" = D."id"
WHERE 1=1
    AND A."businessType" IN ('Credit','Consumption')
    AND A."provider" LIKE 'Blue%'
    AND A."thirdCompleteTime" >= '2026-01-01 00:00:00'
    AND A."thirdCompleteTime" < '2026-02-01 00:00:00'
    AND safe_json_text(B."rawData", 'responseCode') = 'APPROVE'


--15、Volume Fee成本
-- 1、先计算上面的
-- 消费金额+退款金额=（-18240127.68+394793.06）=17845333.87
-- 
-- 2、参考公式：
-- 5000000*0.55%+5000000*0.45%+(17845333.87-10000000)*0.4%




-- 16、Master Dom Volume Fee
SELECT 
    '消费金额' as "交易类型",
    SUM(B."billingAmount") as "金额",
		SUM(B."billingAmount")*0.0021 as "fee"
FROM "qbitCardTransaction" A
LEFT JOIN "qbitCardSettlement" B ON A."sourceId" = B."transactionId"
    AND B."provider" = 'BlueBancCard'
    AND B."transactionType" NOT IN ('ST-REFUND_ADV','ST-PURCHASE_ADV','ST-ECOMM_ADV','ST-SETT_ADV','ST-ATM_ADV')
    AND B."transactionType" = 'authorization.clearing'
LEFT JOIN "qbitCard" D ON A."cardId" = D."id"
WHERE 1=1
    AND A."businessType" IN ('Credit','Consumption')
    AND A."provider" LIKE 'Blue%'
    AND A."thirdCompleteTime" >= '2026-01-01 00:00:00'
    AND A."thirdCompleteTime" < '2026-02-01 00:00:00'
    AND safe_json_text(B."rawData", 'responseCode') = 'APPROVE'
    AND RIGHT(safe_json_text(B."rawData", 'txnLocation'), 2)  IN ('US','USA')
    AND D."type" = 'Master'

UNION ALL

-- 退款金额
SELECT 
    '退款金额' as "交易类型",
    SUM(B."billingAmount") as "金额",
		SUM(B."billingAmount")*0.0021 as "fee"
FROM "qbitCardTransaction" A
LEFT JOIN "qbitCardSettlement" B ON A."id" = B."qbitCardTransactionId"::uuid
    AND B."provider" = 'BlueBancCard'
    AND B."transactionType" NOT IN ('ST-REFUND_ADV','ST-PURCHASE_ADV','ST-ECOMM_ADV','ST-SETT_ADV','ST-ATM_ADV')
    AND B."transactionType" = 'refund.clearing'
LEFT JOIN "qbitCard" D ON A."cardId" = D."id"
WHERE 1=1
    AND A."businessType" IN ('Credit','Consumption')
    AND A."provider" LIKE 'Blue%'
    AND A."thirdCompleteTime" >= '2026-01-01 00:00:00'
    AND A."thirdCompleteTime" < '2026-02-01 00:00:00'
    AND safe_json_text(B."rawData", 'responseCode') = 'APPROVE'
    AND RIGHT(safe_json_text(B."rawData", 'txnLocation'), 2)  IN ('US','USA')
    AND D."type" = 'Master';
		
		
-- 17、Master Int Volume Fee
SELECT 
    '消费金额' as "交易类型",
    SUM(B."billingAmount") as "金额",
		SUM(B."billingAmount")*0.0111 as "fee"
FROM "qbitCardTransaction" A
LEFT JOIN "qbitCardSettlement" B ON A."sourceId" = B."transactionId"
    AND B."provider" = 'BlueBancCard'
    AND B."transactionType" NOT IN ('ST-REFUND_ADV','ST-PURCHASE_ADV','ST-ECOMM_ADV','ST-SETT_ADV','ST-ATM_ADV')
    AND B."transactionType" = 'authorization.clearing'
LEFT JOIN "qbitCard" D ON A."cardId" = D."id"
WHERE 1=1
    AND A."businessType" IN ('Credit','Consumption')
    AND A."provider" LIKE 'Blue%'
    AND A."thirdCompleteTime" >= '2026-01-01 00:00:00'
    AND A."thirdCompleteTime" < '2026-02-01 00:00:00'
    AND safe_json_text(B."rawData", 'responseCode') = 'APPROVE'
    AND RIGHT(safe_json_text(B."rawData", 'txnLocation'), 2) NOT IN ('US','USA')
    AND D."type" = 'Master'

UNION ALL

-- 退款金额
SELECT 
    '退款金额' as "交易类型",
    SUM(B."billingAmount") as "金额",
		SUM(B."billingAmount")*0.0111 as "fee"
FROM "qbitCardTransaction" A
LEFT JOIN "qbitCardSettlement" B ON A."id" = B."qbitCardTransactionId"::uuid
    AND B."provider" = 'BlueBancCard'
    AND B."transactionType" NOT IN ('ST-REFUND_ADV','ST-PURCHASE_ADV','ST-ECOMM_ADV','ST-SETT_ADV','ST-ATM_ADV')
    AND B."transactionType" = 'refund.clearing'
LEFT JOIN "qbitCard" D ON A."cardId" = D."id"
WHERE 1=1
    AND A."businessType" IN ('Credit','Consumption')
    AND A."provider" LIKE 'Blue%'
    AND A."thirdCompleteTime" >= '2026-01-01 00:00:00'
    AND A."thirdCompleteTime" < '2026-02-01 00:00:00'
    AND safe_json_text(B."rawData", 'responseCode') = 'APPROVE'
    AND RIGHT(safe_json_text(B."rawData", 'txnLocation'), 2) NOT IN ('US','USA')
    AND D."type" = 'Master';
		
		
		
		
		-- 18、VISA Dom Volume Fee
SELECT 
    '消费金额' as "交易类型",
    SUM(B."billingAmount") as "金额",
		SUM(B."billingAmount")*0.0016 as "fee"
FROM "qbitCardTransaction" A
LEFT JOIN "qbitCardSettlement" B ON A."sourceId" = B."transactionId"
    AND B."provider" = 'BlueBancCard'
    AND B."transactionType" NOT IN ('ST-REFUND_ADV','ST-PURCHASE_ADV','ST-ECOMM_ADV','ST-SETT_ADV','ST-ATM_ADV')
    AND B."transactionType" = 'authorization.clearing'
LEFT JOIN "qbitCard" D ON A."cardId" = D."id"
WHERE 1=1
    AND A."businessType" IN ('Credit','Consumption')
    AND A."provider" LIKE 'Blue%'
    AND A."thirdCompleteTime" >= '2026-01-01 00:00:00'
    AND A."thirdCompleteTime" < '2026-02-01 00:00:00'
    AND safe_json_text(B."rawData", 'responseCode') = 'APPROVE'
    AND RIGHT(safe_json_text(B."rawData", 'txnLocation'), 2)  IN ('US','USA')
    AND D."type" = 'VISA'

UNION ALL

-- 退款金额
SELECT 
    '退款金额' as "交易类型",
    SUM(B."billingAmount") as "金额",
		SUM(B."billingAmount")*0.0016 as "fee"
FROM "qbitCardTransaction" A
LEFT JOIN "qbitCardSettlement" B ON A."id" = B."qbitCardTransactionId"::uuid
    AND B."provider" = 'BlueBancCard'
    AND B."transactionType" NOT IN ('ST-REFUND_ADV','ST-PURCHASE_ADV','ST-ECOMM_ADV','ST-SETT_ADV','ST-ATM_ADV')
    AND B."transactionType" = 'refund.clearing'
LEFT JOIN "qbitCard" D ON A."cardId" = D."id"
WHERE 1=1
    AND A."businessType" IN ('Credit','Consumption')
    AND A."provider" LIKE 'Blue%'
    AND A."thirdCompleteTime" >= '2026-01-01 00:00:00'
    AND A."thirdCompleteTime" < '2026-02-01 00:00:00'
    AND safe_json_text(B."rawData", 'responseCode') = 'APPROVE'
    AND RIGHT(safe_json_text(B."rawData", 'txnLocation'), 2)  IN ('US','USA')
    AND D."type" = 'VISA';
		
		
-- 19、VISA Int Volume Fee
SELECT 
    '消费金额' as "交易类型",
    SUM(B."billingAmount") as "金额",
		SUM(B."billingAmount")*0.0116 as "fee"
FROM "qbitCardTransaction" A
LEFT JOIN "qbitCardSettlement" B ON A."sourceId" = B."transactionId"
    AND B."provider" = 'BlueBancCard'
    AND B."transactionType" NOT IN ('ST-REFUND_ADV','ST-PURCHASE_ADV','ST-ECOMM_ADV','ST-SETT_ADV','ST-ATM_ADV')
    AND B."transactionType" = 'authorization.clearing'
LEFT JOIN "qbitCard" D ON A."cardId" = D."id"
WHERE 1=1
    AND A."businessType" IN ('Credit','Consumption')
    AND A."provider" LIKE 'Blue%'
    AND A."thirdCompleteTime" >= '2026-01-01 00:00:00'
    AND A."thirdCompleteTime" < '2026-02-01 00:00:00'
    AND safe_json_text(B."rawData", 'responseCode') = 'APPROVE'
    AND RIGHT(safe_json_text(B."rawData", 'txnLocation'), 2) NOT IN ('US','USA')
    AND D."type" = 'VISA'

UNION ALL

-- 退款金额
SELECT 
    '退款金额' as "交易类型",
    SUM(B."billingAmount") as "金额",
		SUM(B."billingAmount")*0.0116 as "fee"
FROM "qbitCardTransaction" A
LEFT JOIN "qbitCardSettlement" B ON A."id" = B."qbitCardTransactionId"::uuid
    AND B."provider" = 'BlueBancCard'
    AND B."transactionType" NOT IN ('ST-REFUND_ADV','ST-PURCHASE_ADV','ST-ECOMM_ADV','ST-SETT_ADV','ST-ATM_ADV')
    AND B."transactionType" = 'refund.clearing'
LEFT JOIN "qbitCard" D ON A."cardId" = D."id"
WHERE 1=1
    AND A."businessType" IN ('Credit','Consumption')
    AND A."provider" LIKE 'Blue%'
    AND A."thirdCompleteTime" >= '2026-01-01 00:00:00'
    AND A."thirdCompleteTime" < '2026-02-01 00:00:00'
    AND safe_json_text(B."rawData", 'responseCode') = 'APPROVE'
    AND RIGHT(safe_json_text(B."rawData", 'txnLocation'), 2) NOT IN ('US','USA')
    AND D."type" = 'VISA';


-- 20、Active Card Account Fee
SELECT COUNT(*)*0.1 FROM (
SELECT DISTINCT A."cardId" 
FROM "qbitCardTransaction" A 
WHERE 1=1
    AND A."provider" LIKE 'Blue%'
		AND A."createTime" >= '2026-01-01 00:00:00'::timestamp - INTERVAL '8 hours'
		AND A."createTime" < '2026-02-01 00:00:00'::timestamp - INTERVAL '8 hours'
)A

-- 剩下的是账户验证费，账户验证费包含在这些收费项里面，但是由于目前我方账户验证费无法区分成功与失败，且目前缺少数据，需要进一步完善,目前先这样计算，不区分失败与成功的状态
1、AV Master Dom Count Fee
2、AV Master int Count Fee
3、AV Master Int Decline Count Fee 无法区分
6、AV VISA Dom Count Fee
7、AV VISA int Count Fee
8、AV VISA Int Decline Count Fee 无法区分
11、AV DOM Decline Count Fee 无法区分


-- 基础查询：按跨境判断和卡段分组统计数量
WITH base_data AS (
    SELECT 
        A.*,
        CASE WHEN C."specialSourceData"->>'country' IN('US','USA') THEN '本地' ELSE '国际' END AS "跨境判断",
        CASE 
            WHEN D."type" = 'VISA' THEN 'VISA' 
            WHEN D."type" = 'Master' THEN 'Master' 
            ELSE '其他' 
        END AS "卡段"
    FROM "qbitCardTransaction" A
    LEFT JOIN "qbitCardTransaction" C ON A."relatedQbitTxId" = C."id"
    LEFT JOIN "qbitCard" D ON A."cardId" = D."id"
    WHERE A."provider" LIKE 'BlueBanc%'
        AND A."businessType" = 'Fee_Consumption'
        AND A."remarks" = '绑卡验证手续费'
        AND A.status = 'Closed'
				AND A."createTime" >= '2026-01-01 00:00:00'::timestamp - INTERVAL '8 hours'
				AND A."createTime" < '2026-02-01 00:00:00'::timestamp - INTERVAL '8 hours'
)
-- 统计并计算手续费
SELECT 
    "跨境判断",
    "卡段",
    COUNT(*) AS "交易数量",
    CASE 
        WHEN "跨境判断" = '本地' AND "卡段" = 'Master' THEN COUNT(*) * 0.11 --21、AV Master Dom Count Fee
        WHEN "跨境判断" = '国际' AND "卡段" = 'Master' THEN COUNT(*) * 0.48 --22、AV Master int Count Fee
        WHEN "跨境判断" = '本地' AND "卡段" = 'VISA' THEN COUNT(*) * 0.073 --23、AV VISA Dom Count Fee
        WHEN "跨境判断" = '国际' AND "卡段" = 'VISA' THEN COUNT(*) * 0.48 --24、AV VISA int Count Fee
        ELSE 0
    END AS "手续费金额"
FROM base_data
GROUP BY "跨境判断", "卡段"
ORDER BY "跨境判断", "卡段";

-- 最后得出
21、AV Master Dom Count Fee
22、AV Master int Count Fee
23、AV VISA Dom Count Fee
24、AV VISA int Count Fee

