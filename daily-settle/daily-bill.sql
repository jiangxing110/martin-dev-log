SELECT 
aa.root_id,
aa.ccc,
ae.access_type
FROM (
SELECT root_id,
count(*) as ccc
FROM "qbitCardTransaction" as tr
INNER JOIN api_account_relation as aar ON tr."accountId"=aar.account_id
WHERE 
tr."transactionTime" >='2026-06-02 00:00:00'
and tr."transactionTime" <'2026-06-03 00:00:00'
and tr.status='Closed'
GROUP BY root_id) as aa
LEFT JOIN "accountExtend" as ae ON aa.root_id=ae."accountId"
ORDER BY aa.ccc desc


SELECT * FROM account WHERE "id" in (
'95d362d7-56fe-4f50-82cb-f97a51afc263', mor
'451fb6b9-54b7-4e6b-b690-cbe4f77670ed',
'd2de18e4-5bc7-40dc-a299-3c7d02d5ef1b')

SELECT * FROM "accountExtend" WHERE "accountId"='451fb6b9-54b7-4e6b-b690-cbe4f77670ed'

-- mor
https://qbitnetwork-test.oss-cn-hangzhou.aliyuncs.com/export/3.0/daily-statement-95d362d7-56fe-4f50-82cb-f97a51afc263-2026-06-02-20260603114320218.zip

-- Distributor
https://qbitnetwork-test.oss-cn-hangzhou.aliyuncs.com/export/3.0/daily-statement-451fb6b9-54b7-4e6b-b690-cbe4f77670ed-2026-06-02-20260603115712525.zip

--Gateway
https://qbitnetwork-test.oss-cn-hangzhou.aliyuncs.com/export/3.0/daily-statement-d2de18e4-5bc7-40dc-a299-3c7d02d5ef1b-2026-06-02-20260603120032200.zip

--香港創鑫互動有限公司
https://qbitnetwork-test.oss-cn-hangzhou.aliyuncs.com/export/3.0/daily-statement-791d41b4-cdc6-4dae-8c22-c4e05bd68fd8-2026-06-02-20260603121453559.zip