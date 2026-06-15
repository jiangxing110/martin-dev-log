# 数据仓库建模

## 数据规则：

* [ ] 所有数值类数据保留3位小数

* [ ] 目前先统计25，26年的数据

* [ ] 手动输入数据来源月度明细表bi\_month\_tag ，需要后置更新的数据均来源于此

## TO DO:

### 1\.新增整体报表：

没有原表逻辑，全部逻辑都需要重新计算

#### dwm\_cashback\_daily

#### dwm\_api\_daily

#### dwm\_ls\_card\_finance\_daily\_p

#### dwm\_bz\_card\_finance\_daily\_p

#### dwm\_qbit\_channel\_cost

#### dwm\_transfer\_channel\_cost

#### dwm\_crypto\_channel\_cost

#### dwm\_acquiring\_clearing

#### dws\_account\_wide

### 2\.原始报表新增字段

整体逻辑已经在之前的报表有了，需要新增部分字段，需要新增的字段已标红

#### dwm\_qi\_card\_finance\_daily\_p

#### dwm\_bb\_card\_finance\_daily\_p

#### **dwm\_qbit\_card\_transaction**

#### **dwm\_qbit\_card\_transaction\_extend**

#### **dwm\_qbit\_card\_wallet\_transaction**

#### **dwm\_transfer**

#### **dwm\_transfer\_extend**

#### **dwm\_crypto\_assets\_transfers**

#### dwm\_treasury

#### dwm\_physical\_card

## 指标口径:

|指标名|所属指标|所属产品线|指标口径|
|---|---|---|---|
|授权手续费<br>|Revenue<br>|Card<br>|**dwm\_qbit\_card\_transaction**<br>businessType=\&\#39;Fee\_Consumption\&\#39; , status=\&\#39;Closed\&\#39;<br>sum\(fee\)<br>|
|退款手续费|||**dwm\_qbit\_card\_transaction**<br>businessType=\&\#39;Credit\&\#39; ,status=\&\#39;Closed\&\#39;,    sum\(fee\)|
|撤销手续费|||**dwm\_qbit\_card\_transaction**<br>businessType=\&\#39;Reversal\&\#39; , status=\&\#39;Closed\&\#39;,   sum\(fee\)|
|拒付手续费|||**dwm\_qbit\_card\_transaction**<br><br>businessType=\&\#39;Declined\_Fee\&\#39; , status=\&\#39;Closed\&\#39;,   sum\(fee\)|
|跨境交易手续费<br>|||**dwm\_qbit\_card\_transaction\_extend **<br>businessType=\&\#39;Consumption\&\#39; , status=\&\#39;Closed\&\#39;<br><br>sum\(fx\_fee\)<br>|
|ATM取现手续费|||**dwm\_qbit\_card\_transaction\_extend **<br>businessType=\&\#39;Consumption\&\#39; , status=\&\#39;Closed\&\#39;<br><br>sum\(atm\_fee\)|
|APPLEPAY手续费|||**dwm\_qbit\_card\_transaction\_extend  **<br>businessType=\&\#39;Consumption\&\#39; , status=\&\#39;Closed\&\#39;<br><br>sum\(apple\_pay\_fee\)|
|结算手续费|||**dwm\_qbit\_card\_transaction\_extend **<br>businessType=\&\#39;Consumption\&\#39; , status=\&\#39;Closed\&\#39;<br><br>sum\(settle\_fee\)|
|虚拟卡开卡费<br>|||**dwm\_qbit\_card\_wallet\_transaction**<br><br>business\_type=\&\#39;CreateCardFee\&\#39;  , status=\&\#39;Closed\&\#39;<br><br>sum\(fee\)|
|量子账户充值手续费<br>|||**dwm\_qbit\_card\_wallet\_transaction**<br><br>business\_type in \(\&\#39;TransferInFromIPeakoin\&\#39;, \&\#39;QbitCryptoToQbitCardWallet\&\#39;,\&\#39;TransferInFromQbitGlobal\&\#39;, \&\#39;Deposit\&\#39;, \&\#39;TransferInFromFinancing\&\#39;, \&\#39;TransferInFromCryptoAssets\&\#39;, \&\#39;AccountDepositCNY\&\#39;\) , status=\&\#39;Closed\&\#39;<br><br>sum\(fee\)|
|实体卡制卡费与邮寄费<br>|||dwm\_physical\_card\.sum\(physical\_card\_fee\) , status=\&\#39;Closed\&\#39;|
|API客户账单\-月结手续费（应收）<br>|||select item , type , sum\(amount\) from api\_client\_bill\_statement a left join  api\_client\_bill b  on a\.bill\_id = b\.id<br>where  create\_time BETWEEN \&\#39;2026\-04\-01 00:00:00\&\#39; and \&\#39;2026\-04\-30 23:59:59\&\#39;<br>and is\_sum=true<br>and a\.delete\_time is null <br>and b\.delete\_time is null <br>and b\.type=\&\#39;MonthlyStatement\&\#39;<br>and type not like \&\#39;%Closed%\&\#39;<br>and b\.bill\_month=\&\#39;2026\-04\&\#39;<br>group by item , type;<br><br>**月结手续费：**<br>1\.type in \(\&\#39;topUpFee\&\#39;,\&\#39;settlementFee\&\#39;,\&\#39;reversalFee\&\#39;,\&\#39;refundFee\&\#39;,\&\#39;declineFee\&\#39;,\&\#39;cardCreationFee\&\#39;,\&\#39;refundClientFee\&\#39;,\&\#39;postageFee\&\#39;,\&\#39;applePayAuthFee\&\#39;,\&\#39;verificationFee\&\#39;,\&\#39;monthlyCardFee\&\#39;,\&\#39;authFee\&\#39;,\&\#39;atmWithdrawalFee\&\#39;,\&\#39;cardProductionFee\&\#39;,<br>\&\#39;issuerCardServiceIntFee\&\#39;,\&\#39;issuerCardServiceDomFee\&\#39;,\&\#39;visaRiskManagerIntFee\&\#39;,\&\#39;visaRiskManagerDomFee\&\#39;,\&\#39;issuerTransactionAuthIntFee\&\#39;,\&\#39;issuerTransactionAuthDomFee\&\#39;,\&\#39;issuerTransactionSettlementIntFee\&\#39;,\&\#39;issuerTransactionSettlementDomFee\&\#39;,\&\#39;schemeVerificationIntFee\&\#39;,\&\#39;schemeVerificationDomFee\&\#39;,\&\#39;schemeRefundFee\&\#39;,\&\#39;schemeReversalFee\&\#39;,\&\#39;schemeSignatureFee\&\#39;\)<br>2\.  type=\&\#39;Add\&\#39; , <br>item not ilike \&\#39;%crypto fee%\&\#39; and  item not ilike  \&\#39;%cross chain fee%\&\#39;  and item not ilike \&\#39;%cross border fee%\&\#39;<br><br>**月结FX手续费**：type in \(\&\#39;fxFee\&\#39;,\&\#39;crossBorderFee\&\#39;\)<br>or type=\&\#39;Add\&\#39; and  item  ilike \&\#39;%cross border fee%\&\#39;<br><br>**KYC手续费：**<br>1\.item=\&\#39;Identity Verification \(Supplementary Debit\)\&\#39; , type=\&\#39;Add\&\#39;<br>2\.type=\&\#39;identityVerification\&\#39;<br>**API费：**type in \(\&\#39;monthlyCommitment\&\#39;,\&\#39;additionalFee\&\#39;,\&\#39;apiSubscription\&\#39;,\&\#39;apiIntegration\&\#39; , \&\#39;minimumVolumeCommitmentFee\&\#39;\)|
|API客户账单\-月结FX手续费（应收）||||
|API客户账单\-KYC手续费（应收）<br>||||
|API客户账单\-API费（应收）||||
|API客户账单\-月结手续费（实收）||||
|API客户账单\-月结FX手续费（实收）||||
|API客户账单\-KYC手续费（实收）<br>||||
|API客户账单\-API费（实收）||||
|QI渠道返现|||**dwm\_qi\_card\_finance\_daily\_p**\.sum\(rebate\_interchange\_vol\+rebate\_incentive\_vol\)|
|BB渠道返现|||**dwm\_bb\_card\_finance\_daily\_p**\.sum\(bb\_rebate\_base\_amt\_Revenue\)|
|BZ渠道返现|||**dwm\_bz\_card\_finance\_daily\_p\(待定\)**|
|LS渠道返现|||**dwm\_ls\_card\_finance\_daily\_p\(待定\)**|
|全球账户入金手续费||GlobalAccount<br>|**dwm\_transfer**<br>business\_type\_detail in \(\&\#39;CCInbound\&\#39;,\&\#39;OtherChannelInbound\&\#39;\)  , status=\&\#39;Closed\&\#39;<br>sum\(fee\)|
|全球账户付款手续费|||**dwm\_transfer**<br>business\_type\_detail in \(\&\#39;Payment\&\#39;\)  , status=\&\#39;Closed\&\#39;<br>sum\(fee\)|
|全球账户汇差收入|||**dwm\_transfer\_extend**<br>sum\(conversion\_fx\_fee\) , status=\&\#39;Closed\&\#39;|
|全球账户子账户创建收入|||**dwm\_transfer**<br>business\_type\_detail in \(\&\#39;CreateSubAccountFee\&\#39;\)  , status=\&\#39;Closed\&\#39;<br>sum\(fee\)|
|加密资产入金手续费||CryptoConnect<br>|**dwm\_crypto\_assets\_transfers**<br>action=\&\#39;in\&\#39; , status=\&\#39;Closed\&\#39;<br>sum\(sumfee\_usd\)|
|加密资产承兑手续费|||**dwm\_crypto\_assets\_transfers**<br>action=\&\#39;sell\&\#39; , status=\&\#39;Closed\&\#39;<br>sum\(sumfee\_usd\)|
|加密资产出金手续费|||**dwm\_crypto\_assets\_transfers**<br>action=\&\#39;out\&\#39; , 并且排除\(sender\_type=\&\#39;wallet\&\#39; and recipient\_type=\&\#39;virtual\_card\&\#39;\) , status=\&\#39;Closed\&\#39;<br><br>sum\(sumfee\_usd\)|
|API客户账单\-加密资产（应收）<br>|||select item , type , sum\(amount\) from api\_client\_bill\_statement a left join  api\_client\_bill b  on a\.bill\_id = b\.id<br>where  create\_time BETWEEN \&\#39;2026\-04\-01 00:00:00\&\#39; and \&\#39;2026\-04\-30 23:59:59\&\#39;<br>and is\_sum=true<br>and a\.delete\_time is null <br>and b\.delete\_time is null <br>and b\.type=\&\#39;MonthlyStatement\&\#39;<br>and type not like \&\#39;%Closed%\&\#39;<br>and b\.bill\_month=\&\#39;2026\-04\&\#39;<br>group by item , type;<br><br>加密资产：type=\&\#39;Add\&\#39;<br>item ilike \&\#39;%crypto fee%\&\#39; or item ilike  \&\#39;%cross chain fee%\&\#39;|
|API客户账单\-加密资产（实收）||||
|技术服务手续费||Treasury|**dwm\_treasury**\.sum\(fees\)|
|收单手续费||Acquiring|**dwm\_acquiring\_clearing**<br>所有收入项求和|
|客户返现 |Client Rebate|Card: \&\#39;QuantumCreateCardCashBack\&\#39;,\&\#39;QuantumAccountCashBack\&\#39;, QuantumAccountHandlingFeeOnBehalfCashBack<br><br>GlobalAccount: GlobalAccountDepositCashBack<br><br>CryptoConnect: CryptoAssetTradeCashBack<br>|**dwm\_cashback\_daily **, sum\(cash\_back\_amount\)<br>project in \(\&\#39;QuantumCreateCardCashBack\&\#39;,\&\#39;QuantumAccountCashBack\&\#39;,\&\#39;CryptoAssetTradeCashBack\&\#39;,\&\#39;QuantumAccountHandlingFeeOnBehalfCashBack\&\#39;,\&\#39;GlobalAccountDepositCashBack\&\#39;\)<br>and status \!=\&\#39;Cancelled\&\#39;<br>|
|Effective Revenue|Effective Revenue||Revenue \-  客户返现|
|卡消费量<br>|Card Spending Vol<br>|Card<br>|**\&\#34;qbitCardTransaction\&\#34;**<br><br>businessType in \(\&\#39;Consumption\&\#39;,\&\#39;Reversal\&\#39;,\&\#39;Credit\&\#39; ,\&\#39;Refund\&\#39; \) ，<br>sum\(case when \&\#34;businessType\&\#34;=\&\#39;Consumption\&\#39; then \&\#34;settleAmount\&\#34; else \-\&\#34;settleAmount\&\#34; end\) , status in \(\&\#39;Closed\&\#39;,\&\#39;Pending\&\#39;\)|
|加密承兑|Crypto on/off ramp<br>|CryptoConnect|**crypto\_assets\_transfers **<br>action=\&\#39;sell\&\#39; , stauts=\&\#39;Closed\&\#39; , hidden=Flase<br>currency in \(\&\#39;USD\&\#39;,\&\#39;USDC\&\#39;,\&\#39;USDT\&\#39;,\&\#39;WUSD\&\#39;\)<br>quote\_currency in  \(\&\#39;USD\&\#39;,\&\#39;USDC\&\#39;,\&\#39;USDT\&\#39;,\&\#39;WUSD\&\#39;\)<br><br>sum\(origin\_amount \* usd\_rate\)|
|加密转出|Crypto Payout||**crypto\_assets\_transfers**<br><br>action=\&\#39;out\&\#39; , status=\&\#39;Closed\&\#39;  ,recipient\_type in \(\&\#39;wire\&\#39;,\&\#39;chain\&\#39;,\&\#39;outside\_bank\&\#39;\)<br>sum\(origin\_amount \* usd\_rate\)<br>|
|全球账户转入|GlobalAccount payin|GlobalAccount|**dwm\_transfer**<br><br>\&\#34;businessTypeDetail\&\#34; in <br>\(\&\#39;OtherChannelInbound\&\#39;,\&\#39;CCInbound\&\#39;\) , status=\&\#39;Closed\&\#39;<br><br>sum\(\&\#34;usdAmount\&\#34;\)|
|全球账户转出|GlobalAccount payout||**dwm\_transfer**<br>\&\#34;businessTypeDetail\&\#34; =\&\#39;Payment\&\#39; , status=\&\#39;Closed\&\#39;<br>sum\(\&\#34;usdAmount\&\#34;\)|
|收单金额|acquiring<br>|acquiring|**dwm\_acquiring\_clearing**  , account\_type=\&\#39;2\&\#39;<br>sum\(acquiring\_usd\_amount\)<br>|
|API客户数|Active API Clients||Card Spending Vol , Crypto on/off ramp ,Crypto Payout, GlobalAccount payin , GlobalAccount payout , acquiring任意有一条记录就算<br><br>type=\&\#39;ApiClient\&\#39;，子母账户合并，gateway , distributor都合并到最高一层|
|直客客户数<br>|Active Direct Clients<br>||Card Spending Vol , Crypto on/off ramp ,Crypto Payout, GlobalAccount payin , GlobalAccount payout , acquiring任意有一条记录就算<br><br>type \!=\&\#39;ApiClient\&\#39;以外的所有客户 ，子母账户合并，gateway , distributor都合并到最高一层|
|量子卡渠道返现|Interchange Revenue<br>|card<br>|QI渠道返现 \+ BB渠道返现\+LS渠道返现\+BZ渠道返现<br>LS,BZ待定|
||Fees||API客户账单\-月结手续费（应收） \+  量子卡除FX markup之外的所有手续费|
||FX markup||API客户账单\-月结FX手续费（应收） \+ 量子卡FX mark手续费|
||API Fee||API客户账单\-API手续费（应收）|
||KYC Fee||API客户账单\-KYC手续费（应收）|
|实体卡手续费|Physical Cards||实体卡制卡费与邮寄费|
||Client Rebate||参考客户返现card部分|
|量子卡成本|COGS<br>||QI渠道成本 \+ BB渠道成本 ， 先只算这2个|
|全球账户成本||||
|加密资产成本||||
|粒子理财成本||||
|收单成本||||
|毛利|Gross Profit||Effective Revenue \-  COGS|
|量子卡余额|Funds by product<br>|Card|客资部分|
|全球账户余额||GlobalAccount|客资部分|
|加密资产余额||CryptoConnect, |客资部分|
|粒子理财余额||Treasury|客资部分|

## 整体架构：

ODS\-\&gt;DWM\-DWS

## DWM数据中间层：

### 按产品线拆分**轻度事实表**

维度：日期、用户、交易类型、状态等

渠道事实：交易金额、笔数、手续费



所有用户子母账户合并 ，gateway , distributor都合并到最高一层

### BD，AM实时匹配逻辑:

所有dwm表都没有匹配实收BD和AM ， 都需要重新匹配

参考该笔交易创建/完成的时间（汇总的日期是创建时间就用创建时间，是完成时间就按完成时间）

参考\&\#34;salesAccountRelation\&\#34;销售客户关系表



2026\-04\-01 00:00:00   \- 2026\-04\-02 00:00:00  客户A  销售A

2026\-04\-02 00:00:00   \- 2026\-04\-03 00:00:00  客户A  销售B



当客户在2026\-04\-01 02:00:00的交易销售为A

当客户在2026\-04\-02 02:00:00的交易销售为B



### dwm\_cashback\_daily客户返现表

将月维度的返现金额拆散到每日（具体返现逻辑参考生成cash\_back\_bonuses表的代码）

并且特殊处理 ，如果cash\_back\_bonuses中有ratio字段为0的，则为手动添加的记录，默认改为当月1号

cash\_back\_bounses是根据终态来计算返现的， 可能存在4\.1\-4\.29号是1%，到了5\.2号就是变成了1\.5%，那么最终是按1\.5%算的， 以及状态也会有变更，可能从pending变为fail ， 因此需要等终态之后再更新一次

|**字段名称**|**数据类型**|**字段含义（业务说明）**|备注|
|---|---|---|---|
|id|int8|主键 ID（唯一标识）||
|account\_id|uuid|用户账户 ID（UUID 格式）||
|createDate<br>||统计日期（如：2025\-12\-1）|这里需要用订单的完成时间|
|project|varchar\(100\)|返现项目|原表有总计和拆分明细的项，只保存明细项|
|purchase\_amount|numeric|消费 / 购买总金额||
|refund\_amount|numeric|退款总金额<br>||
|reversal\_amount|numeric|冲正金额||
|purchase\_net\_amount|numeric|消费净金额（扣减退款 / 冲正后）||
|ratio|numeric|比例 / 费率 / 返佣比例||
|cash\_back\_amount|numeric|返现金额||
|remarks|varchar|备注||
|create\_time|timestamptz\(6\)|创建时间（带时区）||
|update\_time|timestamptz\(6\)|更新时间（带时区）||
|delete\_time|timestamptz\(6\)|删除时间（软删除）||
|status|varchar\(100\)|状态（待处理 / 已完成 / 失败）||
|sale||销售经理id|如果是按每天统计的，需要匹配实时的BD ， 如果是固定每月的成本则按当时的最新销售|
|am||大客户经理id|如果是按每天统计的，需要匹配实时的BD ， 如果是固定每月的成本则按当时的最新销售|



### dwm\_api\_daily客户月账单表

将每月的月账单拆散到每日\(具体逻辑参考生成api\_client\_bill ， api\_client\_transaction  ，api\_client\_bill\_statement表的代码\)  同返现表一样，会出现某些费用项的修改，也需要等到最终态再更新一遍

实收：以实际扣款时间为准， 如账单完全付清则按账单计算，如账单只有部分付清则按比例分摊

Ep:

账单10000 ， 5000为低消，5000是月结的fx手续费 ， 但是实际只付了8000

低消实收：5000 \* 8000/10000 = 4000  

fx月结实收:  5000 \* 8000/10000 = 4000  

|**字段名称**|**数据类型**|**字段含义（业务说明）**|备注|
|---|---|---|---|
|id|int8|主键 ID（唯一标识）||
|createDate||统计日期（如：2025\-12\-1）|参考上述用到的表的逻辑里面的具体时间<br>|
|bill\_id|int8|账单 ID（关联主账单）|可以先为空，等账单生成之后再更新|
|account\_id|uuid|用户账户 ID（UUID 格式）||
|item|varchar\(1024\)|账单项目 / 费用项名称|拒付和低消等账单出来之后再插入表里，日期按账单月的1号 ， 其他的固定收入需要取配置项， 看这个月是否还有配置项 ，在\&\#34;openApiClientConfig\&\#34;\.other\_amount ,  如果有值就也放到每月的1号|
|type|varchar\(64\)|类型（费用类型 / 交易类型）||
|bill\_type||账单类型|区分是应收还是实收 ,  取值为ar , cr|
|provider|varchar\(64\)|服务商 / 渠道方 / 供应商||
|amount|numeric\(20,2\)|金额（原始账单金额）||
|create\_time|timestamptz\(6\)|创建时间<br>||
|update\_time|timestamptz\(6\)|更新时间||
|delete\_time|timestamptz\(6\)|删除时间||
|version|int4|数据版本号（乐观锁）||
|remarks|varchar|备注||
|sale||销售经理id|如果是按每天统计的，需要匹配实时的BD ， 如果是固定每月的成本则按当时的最新销售|
|am||大客户经理id|如果是按每天统计的，需要匹配实时的BD ， 如果是固定每月的成本则按当时的最新销售|



### 量子卡渠道毛利规则：

[客户量子卡渠道毛利](https://axss9gjoff.feishu.cn/wiki/Ssr7wcf8Si7nqzkHuqicVqhFnBf?from=from_copylink)

### dwm\_qi\_card\_finance\_daily\_p QI卡成本表

原dwm\_qi\_card\_finance\_daily\_p表

|**字段名称**|**数据类型**|**字段含义 / 业务说明**|备注|
|---|---|---|---|
|id|int8|主键 ID（自增 / 唯一标识）||
|createDate<br>|date|统计日期 / 报表日期（日分区核心）|交易的创建时间|
|account\_id|varchar\(36\)|用户账号 ID（客户唯一标识）||
|version|int4|数据版本号（乐观锁 / 更新版本）||
|remarks|varchar\(255\)|备注字段||
|create\_time|timestamp\(6\)|数据创建时间||
|update\_time|timestamp\(6\)|数据最后更新时间||
|delete\_time|timestamp\(6\)|删除时间（软删除标记）||
|cost\_reimbursement\_vol|numeric\(20,4\)|**corssborder成本金额**|QI卡渠道成本<br>|
|cost\_service\_vol|numeric\(20,4\)|**service成本金额**<br>||
|cost\_acs\_regular\_count|numeric\(20,4\)|asc成本||
|cost\_acs\_vip\_count|numeric\(20,4\)|asc\_vip成本||
|cost\_vrm\_count|numeric\(20,4\)|vrm成本||
|cost\_fixed\_fee<br>|numeric\(20,4\)<br>|QI固定成本 ， 统计日期定每月第一天 ， 取bi\_month\_tag  ,  provider =\&\#39;IQ\&\#39; ,  tag=\&\#39;量子卡\-渠道固定成本\&\#39;  ,  均摊到所有有QI卡且状态为active的客户 ，因为可能有所变化， 取值如果没有当月数据，则取最新的一条 ， 后续更新了当月数据，则以当月数据重新更新||
|rebate\_interchange\_vol|numeric\(20,4\)|**月度渠道返现**<br>|QI卡渠道返佣收入<br>|
|rebate\_incentive\_vol|numeric\(20,4\)|**年度渠道返现**<br>||
|sale||销售经理id|需要匹配实时的BD|
|am||大客户经理id|需要匹配实时的大客户经理|



### dwm\_bb\_card\_finance\_daily\_p BB卡成本表 

原dws\_bb\_card\_finance\_daily\_p表 ，需要把每项的成本都计算出来，目前只算了基数 ， 以下标红为新增字段

|**字段名称**|**数据类型**|**字段含义（业务解释）**|备注|
|---|---|---|---|
|id|int8|主键 ID||
|createDate<br>|date|报表日期 / 统计日期|交易的创建时间|
|account\_id|varchar\(36\)|用户 ID / 账户 ID||
|m\_dom\_auth\_count|int4|主卡 国内 授权交易笔数||
|m\_int\_auth\_count|int4|主卡 国际 授权交易笔数||
|v\_dom\_auth\_count|int4|副卡 国内 授权交易笔数||
|v\_int\_auth\_count|int4|副卡 国际 授权交易笔数||
|m\_int\_decline\_count|int4|主卡 国际 拒绝笔数||
|v\_int\_decline\_count|int4|副卡 国际 拒绝笔数||
|dom\_decline\_count|int4|国内 拒绝笔数||
|m\_int\_reversal\_count|int4|主卡 国际 冲正笔数||
|v\_int\_reversal\_count|int4|副卡 国际 冲正笔数||
|dom\_reversal\_count|int4|国内 冲正笔数||
|m\_int\_refund\_count|int4|主卡 国际 退款笔数||
|v\_int\_refund\_count|int4|副卡 国际 退款笔数||
|dom\_refund\_count|int4|国内 退款笔数||
|av\_m\_dom\_count|int4|主卡 国内 可用交易笔数||
|av\_m\_int\_count|int4|主卡 国际 可用交易笔数||
|av\_v\_dom\_count|int4|副卡 国内 可用交易笔数||
|av\_v\_int\_count|int4|副卡 国际 可用交易笔数||
|m\_dom\_clearing\_vol|numeric\(20,4\)|主卡 国内 清算金额||
|m\_int\_clearing\_vol|numeric\(20,4\)|主卡 国际 清算金额||
|v\_dom\_clearing\_vol|numeric\(20,4\)|副卡 国内 清算金额||
|v\_int\_clearing\_vol|numeric\(20,4\)|副卡 国际 清算金额||
|bb\_rebate\_base\_amt|numeric\(20,4\)|BB 返佣基数金额<br>||
|active\_card\_count||活跃卡数||
|以下为需要新增的字段||||
|m\_dom\_auth\_count\_fee||master卡段国内交易笔数手续费（授权\+绑卡验证）<br>COALESCE\(SUM\(m\_dom\_auth\_count \* 0\.1090\), 0\) \+ COALESCE\(SUM\(av\_m\_dom\_count \* 0\.1090\), 0\) <br>|BB卡渠道成本|
|m\_int\_auth\_count\_fee<br>||master卡段国内交易笔数手续费（授权\+绑卡验证）<br>COALESCE\(SUM\(m\_int\_auth\_count \* 0\.4845\), 0\)  \+ COALESCE\(SUM\(av\_m\_int\_count \* 0\.4845\), 0\)<br>||
|v\_dom\_auth\_count\_fee||visa卡段国内交易笔数手续费（授权\+绑卡验证）<br>COALESCE\(SUM\(v\_dom\_auth\_count \* 0\.0725\), 0\) \+ <br>COALESCE\(SUM\(av\_v\_dom\_count \* 0\.0725\), 0\)||
|v\_int\_auth\_count\_fee||visa卡段国际交易笔数手续费（授权\+绑卡验证）<br>COALESCE\(SUM\(v\_int\_auth\_count \* 0\.4700\), 0\) \+ <br>COALESCE\(SUM\(av\_v\_int\_count \* 0\.4770\), 0\) ||
|m\_int\_decline\_count\_fee||master卡段国际拒付交易笔数手续费<br><br>COALESCE\(SUM\(m\_int\_decline\_count \* 0\.3595\), 0\) \+ ||
|v\_int\_decline\_count\_fee||visa卡段国际拒付交易笔数手续费<br>COALESCE\(SUM\(v\_int\_decline\_count \* 0\.3570\), 0\)||
|dom\_decline\_count\_fee||国内拒付交易笔数手续费<br>COALESCE\(SUM\(dom\_decline\_count \* 0\.0890\), 0\)||
|m\_int\_reversal\_count\_fee||master卡段国际撤销交易笔数手续费<br><br>COALESCE\(SUM\(m\_int\_reversal\_count \* 0\.7190\), 0\)||
|v\_int\_reversal\_count\_fee||visa卡段国际撤销交易笔数手续费<br>COALESCE\(SUM\(v\_int\_reversal\_count \* 0\.7140\), 0\) ||
|dom\_reversal\_count\_fee||国内撤销交易笔数手续费<br>COALESCE\(SUM\(dom\_decline\_count \* 0\.0890\), 0\)||
|m\_int\_refund\_count\_fee||master卡段国际退款交易笔数手续费<br><br>COALESCE\(SUM\(m\_int\_refund\_count \* 0\.4845\), 0\)||
|v\_int\_refund\_count\_fee||visa卡段国际退款交易笔数手续费<br><br>COALESCE\(SUM\(v\_int\_refund\_count \* 0\.4770\), 0\)||
|dom\_refund\_count\_fee||国内退款交易笔数手续费<br><br>COALESCE\(SUM\(dom\_refund\_count \* 0\.1090\), 0\)||
|m\_dom\_clearing\_vol\_fee||master卡段国内交易清算返现<br><br>COALESCE\(SUM\(m\_dom\_clearing\_vol \* \-0\.0021\), 0\)<br>因为消费的符号是负的，所以费率需要乘负的||
|m\_int\_clearing\_vol||master卡段国内交易清算返现<br>COALESCE\(SUM\(m\_int\_clearing\_vol \* \-0\.0111\), 0\)<br>因为消费的符号是负的，所以费率需要乘负的||
|v\_dom\_clearing\_vol||visa卡段国内交易清算返现<br>COALESCE\(SUM\(v\_dom\_clearing\_vol \* \-0\.0016\), 0\)<br>因为消费的符号是负的，所以费率需要乘负的||
|v\_int\_clearing\_vol||master卡段国内交易清算返现<br><br>COALESCE\(SUM\(v\_int\_clearing\_vol \* \-0\.0116\), 0\)<br>因为消费的符号是负的，所以费率需要乘负的||
|active\_card\_count\_fee||活跃卡手续费<br><br>COALESCE\(SUM\(active\_card\_count \* 0\.1\), 0\)||
|bb\_volume\_fee||\&gt;50000000                  0\.30%<br>20000000\-50000000      0\.35%<br>10000000\-20000000      0\.40%<br>5000000\-10000000        0\.45%<br>0\-5000000                    0\.55%<br>使用梯度计算：<br>假设是17785353\.04<br>5000000\*0\.55%\+5000000\*0\.45%\+\(17785353\.04\-10000000\)\*0\.4%<br><br><br>||
|cost\_fixed\_fee<br>|numeric\(20,4\)<br>|BB固定成本 ， 统计日期定每月第一天 ， 取bi\_month\_tag  ,  provider =\&\#39;BB\&\#39; ,  tag=\&\#39;量子卡\-渠道固定成本\&\#39;  ,  均摊到所有有BB卡且状态为active的客户 ，因为可能有所变化， 取值如果没有当月数据，则取最新的一条 ， 后续更新了当月数据，则以当月数据重新更新||
|bb\_rebate\_base\_amt\_Revenue||渠道返现收入<br>COALESCE\(SUM\(bb\_rebate\_base\_amt \* 0\.02167\), 0\) |BB卡渠道返佣收入|
|sale||销售经理id|需要匹配实时的BD|
|am||大客户经理id|需要匹配实时的大客户经理|

### dwm\_ls\_card\_finance\_daily\_p  ls卡成本表

|**字段名称**|**数据类型**|**字段含义（业务解释）**|备注|
|---|---|---|---|
|id|int8|主键 ID||
|createTime||创建时间||
|updateTIme||更新时间||
|createDate<br>|date|报表日期 / 统计日期|\(\&\#34;rawData\&\#34;\-\&gt;\&gt;\&\#39;date\&\#39;\)::date |
|account\_id|varchar\(36\)|用户 ID / 账户 ID||
|fee||LS卡交易手续费，但是只有三方才有数据|LS卡交易手续费 ， 取当月bi\_month\_tag  ,  provider =\&\#39;LS\&\#39; ,  tag=\&\#39;量子卡\-渠道交易手续费成本\&\#39;  ,  根据返现基数均摊|
|cost\_fixed||LS固定成本||
|rebate\_base||返现基数|\&\#34;qbitCardSettlement\&\#34;表，provider like \&\#39;%Slash%\&\#39;<br>\(\&\#34;rawData\&\#34;\-\&gt;\&gt;\&\#39;date\&\#39;\)::date  筛选时间<br>sum\(\&\#34;billingAmount\&\#34;\)|
|rebate\_amt||返现金额|获取国家\&\#34;rawData\&\#34;\-\&gt;\&\#39;merchantData\&\#39;\-\&gt;\&\#39;location\&\#39;\-\&gt;\&gt;\&\#39;country\&\#39;  ， <br>country=\&\#39;US\&\#39; , rebate\_base \* 0\.02<br>country\!=\&\#39;US\&\#39; , rebate\_base \* 0\.005|

### dwm\_bz\_card\_finance\_daily\_p bz卡成本表（待定）











### **dwm\_qbit\_card\_transaction（卡片交易汇总表）**

**原dws\_qbit\_card\_transaction（卡片交易汇总表）**

|字段|类型|含义|枚举值|备注|
|---|---|---|---|---|
|id|Long|主键（雪花ID）|||
|remarks|String|备注|||
|createTime|Date|创建时间|||
|updateTime|Date|更新时间|||
|deleteTime|Date|删除时间|||
|version|Integer|版本号|||
|accountId|String|账户ID|||
|provider|String|渠道||参考channel\_provision\.quantum\_card\_transaction\_extend 规则，进行渠道映射|
|businessType|QbitCardTransactionTypeEnum|业务类型<br>|Credit=退款, Consumption=消费, TransferIn=转入, TransferOut=转出 等||
|status|TransactionStatusEnum|状态|Pending=处理中, Closed=正常结束, Fail=失败||
|originAmount|BigDecimal|原始金额|||
|settleAmount|BigDecimal|结算金额|||
|transactionCount|BigDecimal|交易笔数|||
|fee|BigDecimal|手续费|||
|datecreateDate|Date|统计日期|交易的创建时间||
|sale||销售经理id|需要匹配实时的BD||
|am||大客户经理id|需要匹配实时的大客户经理||

### **dwm\_qbit\_card\_transaction\_extend（卡片交易扩展汇总表）**

原**dws\_qbit\_card\_transaction\_extend（卡片交易扩展汇总表）**

|字段|类型|含义|枚举值|备注|
|---|---|---|---|---|
|id|Long|主键（雪花ID）|||
|remarks|String|备注|||
|createTime|Date|创建时间|||
|updateTime|Date|更新时间|||
|deleteTime|Date|删除时间|||
|version|Integer|版本号|||
|accountId|String|账户ID|||
|provider|String|渠道||参考channel\_provision\.quantum\_card\_transaction\_extend 规则，进行渠道映射|
|bin|String|BIN号|||
|businessType|String|业务类型|||
|relatedTransaction|Integer|关联订单数|||
|status|TransactionStatusEnum|状态|||
|originAmount|BigDecimal|原始金额|||
|transactionCurrency|CryptoConversionCurrencyEnum|交易币种|USD, EUR, GBP 等40\+币种||
|country|String|国家|||
|transactionCount|Long|交易笔数|||
|fxFee|BigDecimal|外汇手续费|||
|atmFee|BigDecimal|ATM手续费|||
|applePayFee|BigDecimal|Apple Pay手续费|||
|createDate|Date|统计日期|交易的创建时间||
|sale||销售经理id|需要匹配实时的BD||
|am||大客户经理id|需要匹配实时的大客户经理||

### **dwm\_qbit\_card\_wallet\_transaction（卡片钱包交易汇总表）**

**dws\_qbit\_card\_wallet\_transaction（卡片钱包交易汇总表）**

|字段|类型|含义|枚举值|
|---|---|---|---|
|id|Long|主键（雪花ID）||
|remarks|String|备注||
|createTime|Date|创建时间||
|updateTime|Date|更新时间||
|deleteTime|Date|删除时间||
|version|Integer|版本号||
|accountId|String|账户ID||
|businessType|QbitCardTransactionWalletTypeEnum|业务类型|PreDeposit=预充值, Deposit=外部充值, TransferIn=转入 等|
|status|TransactionStatusEnum|状态||
|originAmount|BigDecimal|原始金额||
|transactionCount|BigDecimal|交易笔数||
|fee|BigDecimal|手续费||
|createDate|Date|统计日期|交易的创建时间|
|sale||销售经理id|需要匹配实时的BD|
|am||大客户经理id|需要匹配实时的大客户经理|

### **dwm\_transfer（转账汇总表）**

**原dws\_transfer改为dwm\_transfer**

|字段|类型|含义|枚举值|
|---|---|---|---|
|id|Long|主键（雪花ID）||
|remarks|String|备注||
|createTime|Date|创建时间||
|updateTime|Date|更新时间||
|deleteTime|Date|删除时间||
|version|Integer|版本号||
|accountId|String|账户ID||
|businessTypeDetail|GlobalAccountBusinessTypeDetailEnum|业务类型明细<br>|CCInbound=CC入金, Payment=付款 等|
|settlementCurrency|CryptoConversionCurrencyEnum|结算币种||
|status|TransactionDisplayStatusEnum|状态||
|currency|CryptoConversionCurrencyEnum|币种||
|usdAmount|BigDecimal|USD金额||
|transactionCount|BigDecimal|交易笔数||
|fee|BigDecimal|手续费||
|createDate|Date|统计日期|交易的创建时间|
|sale||销售经理id|需要匹配实时的BD|
|am||大客户经理id|需要匹配实时的大客户经理|



### **dwm\_transfer\_extend（转账扩展汇总表）**

**原dws\_transfer\_extend**

|字段|类型|含义|枚举值|
|---|---|---|---|
|id|Long|主键（雪花ID）||
|remarks|String|备注||
|createTime|Date|创建时间||
|updateTime|Date|更新时间||
|deleteTime|Date|删除时间||
|version|Integer|版本号||
|accountId|String|账户ID||
|status|TransactionDisplayStatusEnum|状态||
|dbsReceive|BigDecimal|DBS收款||
|clReceive|BigDecimal|CL收款||
|epReceive|BigDecimal|EP收款||
|rdReceive|BigDecimal|RD收款||
|settleFxFee|BigDecimal|结算外汇手续费||
|conversionFxAmount|BigDecimal|换汇金额||
|conversionFxFee|BigDecimal|换汇手续费||
|globalAll|BigDecimal|全球账户总额||
|createDate|Date|统计日期|交易的创建时间|
|sale||销售经理id|需要匹配实时的BD|
|am||大客户经理id|需要匹配实时的大客户经理|

### **dwm\_crypto\_assets\_transfers（加密资产转账汇总表）**

**原dws\_crypto\_assets\_transfers**

|字段|类型|含义|枚举值|
|---|---|---|---|
|id|Long|主键（雪花ID）||
|remarks|String|备注||
|createTime|Date|创建时间||
|updateTime|Date|更新时间||
|deleteTime|Date|删除时间||
|version|Integer|版本号||
|accountId|String|账户ID||
|status|CryptoAssetsTransferStatus|状态|Na=未知, Pending=等待, Closed=正常结束 等|
|senderType|CounterpartyType|发送方类型|chain=链, wallet=钱包, virtual\_card=量子账户 等|
|recipientType|CounterpartyType|接收方类型||
|transactionCount|BigDecimal|交易笔数||
|originAmount|BigDecimal|原始金额||
|settlementAmount|BigDecimal|结算金额||
|originAmount\_USD|BigDecimal|将原始金额全部都换算为美金|汇率在ods层的crypto\_assets\_transfers表中有一个usd\_rate字段|
|currency|CryptoConversionCurrencyEnum|币种||
|action<br>|CryptoAssetsTransferAction|动作|in=充值, out=转出, buy=买入 等|
|fee|BigDecimal|手续费||
|fee2|BigDecimal|手续费加点||
|crossChainFee|BigDecimal|跨链费||
|sumfee\_usd<br>|BigDecimal<br>|所有手续费总计换算为USD|fee\+fee2\+crossChainFee合并后，再根据汇率换算， 汇率字段同上|
|hidden|Boolean|是否隐藏||
|createDate|Date|统计日期|交易的创建时间|
|sale||销售经理id|需要匹配实时的BD|
|am||大客户经理id|需要匹配实时的大客户经理|

### dwm\_acquiring\_clearing收单数据表

|**字段名称**|**数据类型**|**字段业务含义**|备注|
|---|---|---|---|
|id|int8|主键 ID||
|create\_time|int8|创建时间（时间戳）||
|update\_time|int8|更新时间（时间戳）||
|delete\_time|int8|删除时间（软删除，时间戳）||
|create\_date|Date|统计日期|用acquiring\_clearing\.create\_time统计|
|remarks|varchar\(255\)|备注||
|version|int4|版本号（乐观锁）||
|account\_id|varchar|账户 ID|关联表:<br>acquiring\_clearing t left join account\_map\_qbit amq ON  t\.account\_id=amq\.id<br>LEFT JOIN  account\_qbit aq ON amq\.account\_id=aq\.id<br>以此将acquiring\_clearing映射到pg库和数仓中的account\.id|
|account\_type|int2|账户类型|account\_type=\&\#39;2\&\#39;为商户交易account\_type=\&\#39;1\&\#39;为渠道交易|
|acquiring\_usd\_amount|numeric|收单美元金额||
|card\_scheme\_fee|numeric|卡组织费用（如 Visa/Mastercard 手续费）|当account\_type=\&\#39;2\&\#39;为收入<br>account\_type=\&\#39;1\&\#39;为成本<br>|
|issuing\_bank\_fee|numeric|发卡行手续费||
|tax\_fee|numeric|税费||
|miscellaneous\_fee|numeric|杂费 / 其他费用||
|fix\_fee|numeric|固定手续费||
|percent\_fee|numeric|比例手续费||
|back\_fix\_fee|numeric|退回固定手续费||
|back\_percent\_fee|numeric|退回比例手续费||
|sale||销售经理id|当前暂无，可以不需要匹配|
|am||大客户经理id|当前暂无，可以不需要匹配|

### dwm\_treasury粒子理财数据表

当前表已经是按日维度的收益fund\_profits

|**字段名称**|**数据类型**|**字段业务含义**|备注|
|---|---|---|---|
|id|int8|主键 ID||
|create\_time|timestamptz\(6\)|创建时间（带时区）||
|update\_time|timestamptz\(6\)|更新时间（带时区）||
|delete\_time|timestamptz\(6\)|删除时间（软删除标记）||
|version|int4|数据版本号（乐观锁）||
|remarks|varchar\(255\)|备注||
|account\_id|uuid|用户账户 ID（UUID）||
|product\_id|int8|理财产品 ID / 基金产品 ID||
|date|date|收益统计日期（日维度）||
|currency|varchar\(32\)|收益币种||
|profit|numeric|**当日收益金额**|实际为我方每日成本|
|fees|jsonb|费用明细（JSON 数组格式，存储各类手续费）|\[\{\&\#34;type\&\#34;: \&\#34;SERVICE\&\#34;, \&\#34;amount\&\#34;: \&\#34;0\.173319\&\#34;, \&\#34;currency\&\#34;: \&\#34;USD\&\#34;\}\]  拆出amount就是我方的每日收入|
|status|varchar|收益状态（已发放 / 处理中 / 作废）||
|apr|numeric|年化收益率||
|share|numeric|持有份额||
|net\_value|numeric|单位净值||
|sale||销售经理id|需要匹配实时的BD|
|am||大客户经理id|需要匹配实时的大客户经理|

### dwm\_physical\_card实体卡收益表

原dws\_physical\_card\_2026

|**字段名称**|**数据类型**|**字段含义（业务说明）**|备注|
|---|---|---|---|
|id|int8|主键 ID（唯一标识）||
|account\_id|varchar\(36\)|用户账户 ID||
|provider|varchar\(50\)|卡供应商 / 渠道方||
|bin|varchar\(50\)|银行卡 BIN 号（卡前 6 位）||
|status|varchar\(50\)|卡片状态（正常 / 注销 / 冻结）||
|transaction\_count|int4|交易笔数<br>||
|physical\_card\_fee|numeric\(18,2\)|制卡费和邮寄费||
|create\_date|timestamp\(6\)|记录创建日期||
|version|int4|数据版本号（乐观锁）||
|remarks|varchar\(255\)|备注||
|create\_time|timestamp\(6\)|数据创建时间||
|update\_time|timestamp\(6\)|数据更新时间||
|delete\_time|timestamp\(6\)|删除时间（软删除标记）||
|sale|varchar\(50\)|销售Id|需要匹配实时的BD|
|am|varchar\(50\)|大客户经理 ID|需要匹配实时的大客户经理|



dwm\_partner\_cost合伙人/渠道返佣



### dwm\_qbit\_channel\_cost量子卡金额渠道成本

thunes:银行手续费\+固定成本

固定成本3500只需要写1月，  所有用过thunes代付的客户

银行手续费来源从每月明细数据获取，根据代付金额均摊，目前已下线只需处理历史数据

BPC： 来源从每月明细数据获，根据所有有QI活跃卡的客户均摊

Sumsb: 后置计算，获取每月账单均摊到每条KYC记录，再合并到客户

IDEMIA制卡费:  每月后置计算 ， 均摊到当月所有实体卡上

HZ银行手续费：每月后置计算 ， 根据所有量子卡消费均摊



|指标名|含义|备注||
|---|---|---|---|
|id|int8|主键 ID（唯一标识）||
|create\_time|timestamptz\(6\)|创建时间（带时区）||
|update\_time|timestamptz\(6\)|更新时间（带时区）||
|delete\_time|timestamptz\(6\)|删除时间（软删除标记）||
|version|int4|数据版本号（乐观锁）||
|createDate<br>|date|统计日期 / 报表日期（日分区核心）|交易的创建时间|
|account\_id|varchar\(36\)|用户账户 ID||
|provider|varchar\(50\)|渠道方||
|cost||手续费||



### dwm\_transfer\_channel\_cost全球账户金额渠道成本

ZB：系统内：payment\_transaction\_record  ， channel=\&\#39;ZB\&\#39; ， sum\(extra\-\&gt;\&gt;\&\#39;fee\_cost\&\#39;\) , status=\&\#39;Closed\&\#39;

transfer , provider=\&\#39;ZB\&\#39;  , \&\#34;rawData\&\#34;\-\&gt;0\-\&gt;\&gt;\&\#39;payoutMode\&\#39;=\&\#39;SUB\&\#39; , sum\(\(\&\#34;rawData\&\#34;\-\&gt;0\-\&gt;\&\#39;inquiryResponse\&\#39;\-\&gt;\&gt;\&\#39;fee\&\#39;\)::numeric\)

系统外： 后置计算，均摊到所有用ZB付款的客户

Tz:  代付计算：

cl:固定费用每个月100000 ，每个月按有CL活跃子账户的客户拆分



### dwm\_crypto\_channel\_cost加密金额渠道成本

Cregis:  固定每月5000 ， 这个等有了再计算没有就是0 ， 拆分到有cregis的账户的客户，每个月1号

tz: 后置计算 ， 换汇费用均摊到所有用ZB付款的客户

Safeheron： 2500的固定成本 ，拆分到有Safeheron的账户的客户，每个月1号， 额外成本后置计算

Bitstamp: 交易手续费 ， 后置计算 ， 拆分到所有有加密承兑的客户

Orenda:收单金额 \* 0\.25%  先按这个预估计算 ， 之后再根据月度明细表的数据乘一个比例系数













### \#其他量子卡渠道成本表（待定）

dwm\_nm\_card\_finance\_daily\_p
dwm\_rc\_card\_finance\_daily\_p

dwm\_rp\_card\_finance\_daily\_p
dwm\_rd\_card\_finance\_daily\_p





## DIM公共维度层

用来统计公共的维度信息

### dim\_account客户信息维度表

由\&\#34;account\&\#34;和\&\#34;accountExtend\&\#34;组成

取数逻辑参考：

select id , \&\#34;verifiedName\&\#34; , type , \&\#34;systemType\&\#34;

from account a left join \&\#34;accountExtend\&\#34; b on a\.id = b\.id

where type in \(\&\#39;ApiClient\&\#39;,\&\#39;MasterAccount\&\#39;,\&\#39;Merchant\&\#39;,\&\#39;TestAccount\&\#39;\)

|字段名|含义|备注|
|---|---|---|
|id|客户id||
|verifiedName|客户名称||
|type|客户类型|因为在dwm层已经合并了子母账户和gateway,distributor， 因此只保存最上层用户的数据<br><br>type in \(\&\#39;ApiClient\&\#39;,\&\#39;MasterAccount\&\#39;,\&\#39;Merchant\&\#39;,\&\#39;TestAccount\&\#39;\)|
|status|客户状态||
|systemType|客户系统类型|是qbit还是interlace|
|card\_activeTime|客户量子卡激活时间<br>|\&\#34;qbitCardWalletTransaction\&\#34;<br>business\_type in \(\&\#39;TransferInFromIPeakoin\&\#39;, \&\#39;QbitCryptoToQbitCardWallet\&\#39;,\&\#39;TransferInFromQbitGlobal\&\#39;, \&\#39;Deposit\&\#39;, \&\#39;TransferInFromFinancing\&\#39;, \&\#39;TransferInFromCryptoAssets\&\#39;, \&\#39;AccountDepositCNY\&\#39;\) , status=\&\#39;Closed\&\#39;  <br><br>累计sum\(originAmount\)\&gt;5000的第一笔<br>需要子母账户和gateway,distributor合并 |
|global\_activeTime|客户全球账户激活时间|select \&\#34;accountId\&\#34; , min\(\&\#34;transactionTime\&\#34;\) from transfer group by  \&\#34;accountId\&\#34;<br><br>需要子母账户和gateway,distributor合并|
|crypto\_activeTime|客户加密资产激活时间<br>|crypto\_assets\_transfers <br>action=\&\#39;sell\&\#39; , status=\&\#39;Closed\&\#39;<br>hidden=False<br><br>累计SUM\(origin\_amount \*  usd\_rate\)  \&gt; 200000的第一笔<br><br>需要子母账户和gateway,distributor合并<br>|







### dim\_sale销售AM信息维度表

\&\#34;user“和\&\#34;userExtend\&\#34; , \&\#34;salesAccountRelation\&\#34; 组成

取数逻辑参考：

select a\.\&\#34;createTime\&\#34; , a\.\&\#34;updateTime\&\#34; , a\.id , nickname , b\.name from 

\(select a\.\&\#34;createTime\&\#34; , a\.\&\#34;updateTime\&\#34;   ,a\.id, nickname , department\-\&gt;\&gt;0 as departmentId  from \&\#34;user\&\#34;  a left join \&\#34;userExtend\&\#34; b  on a\.id = b\.\&\#34;userId\&\#34;

where  a\.id in \(select  \&\#34;salesId\&\#34; from  \&\#34;salesAccountRelation\&\#34; group by \&\#34;salesId\&\#34;\) or 

a\.id in \(select  \&\#34;operationManagerId\&\#34; from  \&\#34;salesAccountRelation\&\#34; group by \&\#34;operationManagerId\&\#34;\)

and  a\.\&\#34;deleteTime\&\#34; is null \) a left join department b 

on a\.departmentId::VARCHAR = b\.id::VARCHAR

|字段名|含义|备注|
|---|---|---|
|createTime|创建时间||
|updateTime|更新时间||
|id|用户id|包含销售id和am|
|nickname|用户名称|销售名称和AM名称|
|department|所属部门名称||







## DWS汇总层

把多业务合并成**一张统一大事实宽表**

- 统一打上**客户维度**

- 所有**成本、金额、手续费**全部作为事实指标预聚合

- 交易类型 / 状态做**维度枚举降维**（维度标准化）

### dws\_account\_wide客户维度宽表

按时间，客户id关联所有dwm层的表 ， 关联account表 ， 关联\&\#34;accountExtend\&\#34; ，形成DWS汇总表

|字段名|含义|备注|来源|
|---|---|---|---|
||创建时间|||
||更新时间|||
||删除时间|||
||统计时间|||
||客户Id||account\.id|
||客户名||account\.\&\#34;verifiedName\&\#34;|
||客户类型||account\.type|
||系统类型||\&\#34;accountExtend\&\#34;\.\&\#34;systemType\&\#34;|
||量子卡收入\-Fees|量子卡收入<br>|同指标Fees|
||量子卡收入\-Fees\_month\_ar||同指标API客户账单\-月结手续费（应收）|
||量子卡收入\-Fees\_month\_cr||待定|
||量子卡收入\-Fx||同指标FX手续费|
||量子卡收入\-Fx\_month\_ar||同指标API客户账单\-月结FX手续费（应收）|
||量子卡收入\-Fx\_month\_cr||待定|
||量子卡收入\-API Fee ar||同指标API客户账单\-API费（应收）|
||量子卡收入\-API Fee cr||待定|
||量子卡收入\-Kyc Fee ar||同指标API客户账单\-KYC手续费（应收）|
||量子卡收入\-Kyc Fee cr||待定|
||量子卡渠道返现||QI渠道收入\+LS渠道收入\+BZ渠道收入\+BB渠道收入|
||全球账户收入||指标Revenue\-globalAccount|
||加密资产收入||指标Revenue\-crtyptoConnect|
||技术服务手续费|粒子理财收入|dwm\_treasury\.sum\(fees\)|
||收单收入<br>|收单收入<br>|**dwm\_acquiring\_clearing**<br>所有收入项求和|
||量子卡消费量<br>|TPV<br>|**dwm\_qbit\_card\_transaction**<br><br>businessType in \(\&\#39;Consumption\&\#39;,\&\#39;Reversal\&\#39;,\&\#39;Credit\&\#39; ,\&\#39;Refund\&\#39; \) ，<br>sum\(case when \&\#34;businessType\&\#34;=\&\#39;Consumption\&\#39; then \&\#34;settleAmount\&\#34; else \-\&\#34;settleAmount\&\#34; end\) , status in \(\&\#39;Closed\&\#39;,\&\#39;Pending\&\#39;\)|
||量子卡充值金额||**dwm\_qbit\_card\_wallet\_transaction**<br><br>\&\#34;businessType\&\#34; in\(\&\#39;TransferInFromIPeakoin\&\#39;, \&\#39;QbitCryptoToQbitCardWallet\&\#39;,\&\#39;TransferInFromQbitGlobal\&\#39;, \&\#39;Deposit\&\#39;, \&\#39;TransferInFromFinancing\&\#39;,\&\#39;TransferInFromCryptoAssets\&\#39;, \&\#39;AccountDepositCNY\&\#39;\) , status=\&\#39;Closed\&\#39;<br><br>sum\(\&\#34;originAmount\&\#34;\)|
||全球账户\-in||**dwm\_transfer**<br><br>\&\#34;businessTypeDetail\&\#34; in <br>\(\&\#39;TransferOutFromQbitMasterAccountForVirtualUSD\&\#39;,\&\#39;TransferOutFromParticleTreasury\&\#39; , \&\#39;CNYSettleTransferIn\&\#39;,\&\#39;TransferOutFromQbitMasterAccountForFinancing\&\#39; ,\&\#39;TransferOutFromQbitCardWallet\&\#39;,\&\#39;OtherChannelInbound\&\#39;,\&\#39;CCInbound\&\#39;\) , status=\&\#39;Closed\&\#39;<br><br>|
||全球账户\-out||**dwm\_transfer**<br>\&\#34;businessTypeDetail\&\#34; =\&\#39;Payment\&\#39; , status=\&\#39;Closed\&\#39;|
||加密资产\-payout||**dwm\_crypto\_assets\_transfers**<br>action=\&\#39;out\&\#39; , status=\&\#39;Closed\&\#39; sum\(originAmount\_usd\) |
||加密资产\-payin||**dwm\_crypto\_assets\_transfers**<br>action=\&\#39;in\&\#39; , status=\&\#39;Closed\&\#39;<br>sum\(originAmount\_usd\)|
||加密资产\-on/off ramp||**dwm\_crypto\_assets\_transfers**<br>action=\&\#39;sell\&\#39; , status=\&\#39;Closed\&\#39; ， hidden=False<br>sum\(originAmount\_usd\)|
||收单金额||dwm\_acquiring\_clearing ,<br>account\_type=\&\#39;2\&\#39; , sum\(acquiring\_usd\_amount\)|
|||量子卡成本||
|||全球账户成本||
|||加密资产成本||
|||收单成本|**dwm\_treasury**\.sum\(profit\)|
|||量子卡返现<br>\(包含消费返现\+代收返现\+手续费退回\+争议订单退回\)||
|||全球账户返现||
|||加密资产返现||
|sale||销售经理id|需要匹配实时的BD|
|am||大客户经理id|需要匹配实时的大客户经理|

### dws\_account\_channel\_wide客户渠道维度宽表\(待定\)

只需要量子卡渠道

|字段名|含义|备注|来源|
|---|---|---|---|
||创建时间|||
||更新时间|||
||删除时间|||
||统计时间|||
||客户Id||account\.id|
||客户名||account\.\&\#34;verifiedName\&\#34;|
||客户类型||account\.type|
||渠道名称|||
||量子卡收入\-Fees<br>|充值手续费需要按TPV的量子卡消费比例划分到各个渠道||
||量子卡收入\-Fees\_month\_ar|||
||量子卡收入\-Fees\_month\_cr|||
||量子卡收入\-Fx|||
||量子卡收入\-Fx\_month\_ar|||
||量子卡收入\-Fx\_month\_cr|||
||量子卡渠道返现|||
||量子卡渠道成本|||
||量子卡净消费|用完成时间||





