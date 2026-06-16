金额数据均来源于bi_month_tag
--量子账户 quantum_account 
1.BPC  是Qi活跃卡成本
来源从每月明细数据获,根据所有有QI活跃卡的客户均摊,统计时间记为当月第一天
均摊到每一个有qi卡的客户,且删卡时间在本月的第一天之后假设统计4月：
select "accountId" from "qbitCard"
where provider like '%Qbit%'
and ("deleteCardTime">'2026-04-01 00:00:00' or "deleteCardTime" is null)
group by "accountId"

2.Sumsub 是我们的kyc 认证成本
后置计算，获取每月账单均摊到每条KYC记录，再合并到客户 ， 时间记为对应KYC的时间
根据每个客户的每条KYC记录均摊
select account_id,count(1)
from idv_channel_request_record
where  request_channel='sumsub' and request_type='POST'
and 'createTime' BETWEEN '2026-04-01 00:00:00' and '2026-04-30 23:59:59'
group by account_id

3.IDEMIA制卡费  就是我们之前说的制卡成本
每月后置计算,均摊到当月所有实体卡上,统计时间记为当月第一天
根据每个客户的每张实体卡均摊
select "accountId",count(1) from "qbitPhysicalCard"
where "createTime" BETWEEN '2026-04-01 00:00:00' and '2026-04-30 23:59:59'
group by "accountId"

4.HZ银行手续费   是Qi消费成本
每月后置计算,根据所有量子卡消费均摊,统计时间记为对应消费时间
参考Card Spending Vol,并且附加条件provider like '%Qbit%'
Card Spending
卡的净消费量 （pending+closed）
SELECT
(SUM(CASE WHEN "businessType" ='Consumption' and status in ('Closed', 'Pending') THEN "settleAmount" ELSE 0 END)
-SUM(CASE WHEN "businessType" ='Reversal' and status in ('Closed', 'Pending') THEN "settleAmount" ELSE 0 END)
-SUM(CASE WHEN "businessType" ='Credit' and status in ('Closed') THEN "settleAmount" ELSE 0 END))AS "amount",
tr."accountId",
to_char("transactionTime" ::DATE, 'YYYY-MM-DD') transactionDate,
FROM "qbit_card_transaction" tr
where
"businessType" in('Credit','Consumption','Reversal')
AND tr."deleteTime" IS NULL and provider like '%Qbit%'
and "transactionTime" BETWEEN '2026-04-01 00:00:00' and '2026-04-30 23:59:59'

--全球账户 business_account
Payout
1.ZB
系统内：我方数据库直接计算,时间按对应的交易时间
系统外：后置计算,均摊到所有用ZB付款的客户,统计时间记为对应交易时间
以下为我方数据库内能算到的部分
SELECT
account_id, SUM(extra ->> 'fee_cost'),SUM (settle_amount) AS "amount",
to_char("submitTime" ::DATE, 'YYYY-MM-DD') "transactionDate"
FROM payment_transaction_record 
WHERE
channel = 'ZB' AND payout_direction_type = 'SubToPayee' AND status = 'Closed' 
AND extra ->> 'third_party_created_time'>'2026-05-01 00:00:00'
AND extra ->> 'third_party_created_time'<'2026-06-01 00:00:00'
GROUP BY "transactionDate",account_id     
系统外:根据以上sum(settle_amount)数据均摊

2.CL
每个月按有CL活跃子账户的客户拆分，固定成本记为每月第一天
按客户数进行拆分
select "accountId" from "globalSubAccount"
where provider ='Column' and status='Active'
group by "accountId"

--加密账户 crypto_account
1.thunes
银行手续费+固定成本
固定成本3500只需要写1月,所有用过thunes代付的客户
银行手续费来源从每月明细数据获取，根据代付金额均摊，目前已下线只需处理历史数据
根据
select account_id,sum(origin_amount * usd_rate) 
from crypto_assets_transfers
where recipient_type='wire'and status='Closed' and delete_time is null
and extend_field->>'platform'='THUNES'
and create_time  BETWEEN '2026-04-01 00:00:00' and '2026-04-30 23:59:59'
group by account_id;
固定成本按客户数均摊，交易手续费按交易量均摊

2.Cregis
拆分到有cregis的账户的客户,每个月1号
按客户数进行拆分
select account_id from crypto_assets_addresses
where platform='CREGIS' and "enable"=true  
group by account_id


3.TZ-wire
后置计算，代付部分 固定成本按客户数均摊，交易手续费按交易量均摊
代付部分记为对应交易时间，固定成本记为每月第一天
根据
select account_id,sum(origin_amount * usd_rate) 
from crypto_assets_transfers
where recipient_type='wire' and status='Closed' and extend_field->>'platform'='TZ'
and create_time  BETWEEN '2026-04-01 00:00:00' and '2026-04-30 23:59:59'
group by account_id ;


4.TZ-sell
CryptoConnect - Payout
后置计算,换汇费用均摊到所有用TZ付款的客户
分为2部分,一部分是USDT->USD,一部分是USDC->USD
select account_id,sum(origin_amount * usd_rate) 
from crypto_assets_transfers
where action='sell' and status='Closed' and delete_time is null and currency='USDT'
and create_time BETWEEN '2026-04-01 00:00:00' and '2026-04-30 23:59:59'
group by account_id

select account_id,sum(origin_amount * usd_rate) 
from crypto_assets_transfers
where action='sell' and status='Closed' and delete_time is null and currency='USDC'
and create_time BETWEEN '2026-04-01 00:00:00' and '2026-04-30 23:59:59'
group by account_id

5.Safeheron
2500的固定成本,拆分到有Safeheron的账户的客户,每个月1号,额外成本后置计算
SELECT account_id  
FROM view_crypto_assets_blockchain_transfers 
WHERE "action"='out' 
and create_time BETWEEN '2026-04-01 00:00:00' and '2026-04-30 23:59:59'
and status='Closed'and platform='SAFEHERON'
group by account_id;

6.Bitstamp
交易手续费,后置计算,拆分到所有有加密承兑的客户
select account_id , sum(origin_amount * usd_rate) 
from crypto_assets_transfers
where action='sell' and status='Closed' and delete_time and currency='USDT'
and create_time BETWEEN '2026-04-01 00:00:00' and '2026-04-30 23:59:59'
group by account_id
成本按客户承兑量均摊，交易手续费按交易量均摊


--收单账户 acquiring_account
1.Orenda
dwm_acquiring_clearing,account_type='2',sum(Acquiring_usd_amount) * 0.0025,
但是会和实际的有差距,比如按照上述算出来是600,实际是800,那么需要将每一天的数据都乘以这个比例
数据库统计：
4.1  400
4.2  200
bi_month_tag手动输入的是800
更新每日数据：
4.1 400 * 800/600 = 533.333
4.2 200 * 800/ 600 = 266.663
2.World Pay
dwm_acquiring_clearing ,  account_type='1' , sum(acquiring_usd_amount) 
关于按每个客户收单金额比例均摊，




