-- 作业元信息：
--   作业类型：批处理参考SQL
--   运行方式：手动/调度执行
--   运行参数：无
--   源库变更响应：历史 PostgreSQL 清洗参考脚本，不是阿里云 Flink SQL 常驻作业。
销售关系表
"salesAccountRelation"
客户关系表:这个表记录的是api的子母账户层级关系 
api_account_relation

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
我现在觉得不能用这个表 感觉我之前的api 子户查询不到



 SELECT
        aar.root_id AS "accountId",
        COALESCE(SUM(("feeObj"->>'amount')::NUMERIC), 0) AS "fee"
        FROM api_client_transaction AS tr
        LEFT JOIN api_account_relation as aar ON aar.account_id=tr.account_id
        INNER JOIN "qbitCardWalletTransaction" AS ta ON tr.transaction_id::UUID = ta.id
        LEFT JOIN "qbitPhysicalCard" as qp ON ta."cardId"=qp."cardId"
        LEFT JOIN "qbitCard" as qc ON ta."cardId"=qc."id"