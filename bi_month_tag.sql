--量子账户 quantum_account
1.BPC  是Qi活跃卡成本
2.Sumsub 是我们的kyc 认证成本
3.IDEMIA制卡费  就是我们之前说的制卡成本
4.HZ银行手续费   是Qi消费成本

--全球账户 business_account
Payout
1.ZB
系统内：我方数据库直接计算,时间按对应的交易时间
系统外：后置计算,均摊到所有用ZB付款的客户,统计时间记为对应交易时间

以下为我方数据库内能算到的部分
payment_transaction_record ,
channel='ZB', payout_direction_type='SubToPayee' , status='Closed' , sum(extra->>'fee_cost')  , sum(settle_amount)
时间筛选： extra->>'third_party_created_time'        

系统外：根据以上sum(settle_amount)数据均摊

金额数据均来源于bi_month_tag
2.CL
每个月按有CL活跃子账户的客户拆分，固定成本记为每月第一天
按客户数进行拆分
select "accountId" from "globalSubAccount"
where provider ='Column'
and status='Active'
group by "accountId"

金额数据均来源于bi_month_tag

--加密账户 crypto_account
1.thunes

2.Cregis
3.TZ-wire
4.TZ-sell
5.Safeheron
6.Bitstamp


--收单账户 acquiring_account
1.Orenda
dwm_acquiring_clearing,account_type='2',sum(Acquiring_usd_amount) * 0.0025,但是会和实际的有差距,比如按照上述算出来是7000,实际是7100或者6900 ，那么需要将每一天的数据都乘以这个比例
数据库统计：
4.1  400
4.2  200
bi_month_tag手动输入的是800
更新每日数据：
4.1   400 * 800/600 = 533.333
4.2   200 * 800/ 600 = 266.663
2.World Pay
dwm_acquiring_clearing ,  account_type='1' , sum(acquiring_usd_amount) 
关于按每个客户收单金额比例均摊，
金额数据均来源于bi_month_tag



acquiring_cost,business_cost,quantum_cost,crypto_cost