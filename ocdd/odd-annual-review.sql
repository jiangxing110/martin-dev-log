-- odd
SELECT "accountId" FROM "oddAccountReview" 
-- account
SELECT * FROM account WHERE id in (SELECT "accountId" FROM "oddAccountReview" ) and status='Readonly'
-- kyc
SELECT * FROM "cddKyc" WHERE "accountId"::UUID in (SELECT "accountId" FROM "oddAccountReview" ) and "kycType" like '%Odd'
-- kyb
SELECT * FROM "cddKyb" WHERE "accountId"::UUID in (SELECT "accountId" FROM "oddAccountReview" ) and "businessType" like '%Odd'
UPDATE "cddKyc" SET "deleteTime" = now(),remarks='2025-12-16test' WHERE "deleteTime" IS NULL AND "kycType" LIKE '%Odd'
AND "accountId"::uuid IN (SELECT "accountId" FROM "oddAccountReview" WHERE "deleteTime" IS NULL);
UPDATE "cddKyb" SET "deleteTime" = now(),remarks='2025-12-16test' WHERE "deleteTime" IS NULL AND "businessType" LIKE '%Odd'
AND "accountId"::uuid IN ( SELECT "accountId" FROM "oddAccountReview" WHERE "deleteTime" IS NULL);
UPDATE "oddAccountReview" SET "deleteTime" = now(),remarks='2025-12-16test' WHERE "deleteTime" IS NULL;  


SELECT * FROM "accountUser" WHERE "accountId"='cfc90aae-4e93-44d8-aeaa-14ce4172ed3f'
SELECT * FROM "user" WHERE "id"='60e110c2-3b1c-4a80-93fb-0fd5b33b4530'
SELECT * FROM "cddKyb" WHERE "accountId"='cfc90aae-4e93-44d8-aeaa-14ce4172ed3f' and "businessType"='MultiCurrencyAccountOdd'

1.KYC、KYB、风险评级 逻辑与CDD一致
2.名单筛查 逻辑与CDD一致,重跑一遍名单筛查
3.海外证件验证 最新ODD的证件验证结果、操作日志与CDD的操作日志字段一致
4.店铺列表与CDD内展示的店铺一致

this.namesScreeningService.businessKycNamesScreening({
    personList: cddKycBusinessPeopleList,
    businessKycDetail: cddKycBusinessDetail,
    accountId: accountId,
    kyCaseId: kyCase.id,
    triggerReason: res.kycType === KycTypeEnum.BusinessOdd ? TriggerReasonEnum.PeriodicalReview : TriggerReasonEnum.Onboarding,
    version: 'v2',
});



9200-3600-2000
query: SELECT "Account"."id" AS "Account_id", "Account"."status" AS "Account_status" FROM "account" "Account" 
WHERE ( "Account"."verifiedName" ILIKE $1 AND "Account"."type" != $2 AND "Account"."accountType" = $3 AND "Account"."id" != $4 AND "Account"."tenantId" IS NULL ) AND ( "Account"."deleteTime" IS NULL ) 
-- PARAMETERS: ["测","SubAccount","Business","4a3fc350-b6fa-4c21-93e5-7eb4f608815b"]


-- odd
SELECT * FROM "oddAccountReview" 
-- account
SELECT * FROM account WHERE id in (SELECT "accountId" FROM "oddAccountReview" ) and status='Readonly'
-- kyc
SELECT * FROM "cddKyc" WHERE "accountId"::UUID in (SELECT "accountId" FROM "oddAccountReview" ) and "kycType" like '%Odd'
-- kyb
SELECT * FROM "cddKyb" WHERE "accountId"::UUID in (SELECT "accountId" FROM "oddAccountReview" ) and "businessType" like '%Odd'

SELECT * FROM "cddKyc" WHERE "deleteTime" IS NULL AND "kycType" LIKE '%Odd'
DELETE FROM "cddKyc" WHERE "deleteTime" IS NULL AND "kycType" LIKE '%Odd'
AND "accountId"::uuid IN (SELECT "accountId" FROM "oddAccountReview" WHERE "deleteTime" IS NULL);

DELETE FROM "cddKyb" WHERE "deleteTime" IS NULL AND "businessType" LIKE '%Odd'
AND "accountId"::uuid IN ( SELECT "accountId" FROM "oddAccountReview" WHERE "deleteTime" IS NULL);


DELETE FROM "oddAccountReview" WHERE "deleteTime" IS NULL;  

SELECT * FROM account WHERE id='4a3fc350-b6fa-4c21-93e5-7eb4f608815b'

SELECT * FROM account WHERE "verifiedName" like '%测试%'


SELECT *
FROM "cddKyc" "CddKyc" 
WHERE ( "CddKyc"."accountId" IN ('135f716b-4fdf-44ec-af67-2caed138c95a') AND "CddKyc"."isLatest" = 'true' ) AND ( "CddKyc"."deleteTime" IS NULL )

SELECT * FROM "account"  
WHERE ( "verifiedName" ILIKE '测' AND "type" != 'SubAccount' AND "accountType" = 'Business'
AND "id" != '4a3fc350-b6fa-4c21-93e5-7eb4f608815b' AND "tenantId" IS NULL ) AND ( "deleteTime" IS NULL ) 

SELECT * FROM account WHERE "id"='4a3fc350-b6fa-4c21-93e5-7eb4f608815b'
SELECT type from api_client_bill_statement GROUP BY type


UPDATE "cddKyc" SET "deleteTime" = now(),remarks='2025-12-16test' WHERE "deleteTime" IS NULL AND "kycType" LIKE '%Odd'
AND "accountId"::uuid IN (SELECT "accountId" FROM "oddAccountReview" WHERE "deleteTime" IS NULL);
UPDATE "cddKyb" SET "deleteTime" = now(),remarks='2025-12-16test' WHERE "deleteTime" IS NULL AND "businessType" LIKE '%Odd'
AND "accountId"::uuid IN ( SELECT "accountId" FROM "oddAccountReview" WHERE "deleteTime" IS NULL);
UPDATE "oddAccountReview" SET "deleteTime" = now(),remarks='2025-12-16test' WHERE "deleteTime" IS NULL;  











SELECT * FROM "cddKyb" WHERE "accountId"='566e0fa8-e756-4b35-a8cf-8cd4a0a86a3b' and "businessType" like '%MultiCurrencyAccount%' and "isLatest"='t'
SELECT * FROM account WHERE "displayId"='138555'

AwaitAdditional


SELECT * FROM "cddKyb" WHERE "accountId"='566e0fa8-e756-4b35-a8cf-8cd4a0a86a3b' and "businessType" like '%Odd%'

SELECT * FROM "cddKyc" WHERE "accountId"='566e0fa8-e756-4b35-a8cf-8cd4a0a86a3b' and "kycType"='BusinessOdd'

SELECT * FROM "accountToDo" WHERE "accountId"='566e0fa8-e756-4b35-a8cf-8cd4a0a86a3b' 

SELECT * FROM "messageCenter" WHERE "accountId"='566e0fa8-e756-4b35-a8cf-8cd4a0a86a3b' 

SELECT * FROM "shopAuth" WHERE "accountId"='566e0fa8-e756-4b35-a8cf-8cd4a0a86a3b' 

SELECT * FROM "oddAccountReview" WHERE "accountId"='566e0fa8-e756-4b35-a8cf-8cd4a0a86a3b' 

hasShopUrl