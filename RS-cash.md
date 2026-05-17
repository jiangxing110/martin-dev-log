RS毛利返现金
我们只从客户那边收取渠道成本部分，也就是scheme fee这部分的费用，其他的费用是不收取的。但是如果对客户配置了其他费用，还是正常进行收取。对客按照Pass Through形式进行报价。
渠道会按照月度对我们进行返现奖励。此时，我们会按照渠道返现总额扣除渠道交易成本后的那部分毛利，跟客户进行分账处理。
1.2 公式
自然月毛利返现金额 = (渠道返现金额 - scheme fee) * 返现比例
渠道返现金额 = (渠道净消费金额 - 返现门槛) * 返现比例
git 渠道净消费金额 = 消费交易金额 - 退款交易金额 - 撤销交易金额
Scheme Fee = Auth Fee(Domestic+international) + Settlement Fee(Domestic+international) + Service Fee + VRM(Domestic+international) + Card Verification Fee(Domestic+international) + Reversal(Domestic+international) + Refund(Domestic+international) + Signature Fee
这个在qbitCardTranscation SELECT fee FROM "qbitCardTransaction" WHERE "businessType"='System_Fee'  


- QI：消费国家=HK，为Domestic，其他为International；
- BZ：消费国家=US，为Domestic，其他为International；
这个参考 
body.setCountry("NON_HK");
List<SaleTrendVO> trends = cardProviderCostBaseService.getAccountPurchaseNetAmounts(body, QbitCardOnlineProviderEnum.IQ);

注意：
- 对费用名称以及收费标准进行微调，以及新增了Verification Fee。
- 故需要对目前所有scheme fee逻辑进行调整。
3. Revenue Sharing
- 在量子卡返现配置页面，新增“QI卡-RS毛利返现”和“BZ卡-RS毛利返现”，配置交互同净消费返现(偷个懒不高兴画图了)

- 当返现申请审核通过后，需要将默认的scheme fee写入账户费率表中。其他量子卡账户费率由销售自己提修改为0的审批。
- 需要在返现明细报表处，手动返现表单-返现项目中，同步增加枚举值：“QI卡-RS毛利返现”和“BZ卡-RS毛利返现”

4. 渠道返现比例
QI渠道返现比例默认值：3%
BZ渠道返现比例默认值：1.6%
这部分可以直接在代码中写死，不做配置，也不做展示。
统一按照交易完成时间进行统计。
QI：净消费交易额=消费支出-交易退款-交易撤销(只统计international交易)
BZ：净消费交易额=消费支出-交易退款-交易撤销(统计所有交易)


5. 毛利返现账单
- 渠道返现金额 - scheme fee ≥ 0 时，跟随每个月的返现账单正常出；
- 渠道返现金额 - scheme fee < 0 时，需要在月账单invoice 中增加这部分的差额补缴，费用名称“Revenue Adjustment” / “营收补差”，且补差金额 = 渠道返现金额 - scheme fee
- 返现交易统计维度是所有子户及母户本身的交易，返现至母户中；

新增QI卡-RS毛利返现”和“BZ卡-RS毛利返现 
参考 CashBackJob 我们先家费率类型 返现类型


    <select id="getRsSchemeFee" resultType="java.math.BigDecimal">
这个方法还得

calculateRsProfitCashBack 这个方法
是一个阶梯费率 我们要的只是找到对应的阶梯就好了 在这个class 应该有习惯的方法因为其他返现费率也是阶梯的

feature/scheme-fee

scheme fee 计算月结逻辑
关联
/Users/martinjiang/IdeaProjects/qbit-assets
/Users/martinjiang/WebstormProjects/qbitpay_service
这两个项目
assets我现在的分支是基于feature/scheme-fee切出来的
qbitpay_service是基于wjc/scheme-fee-20260423 

参考ApiClientTransactionJob syncTxJob定时任务的SYSTEM_FEE_COLLECT （里面是之前的）处理逻辑
我想要确定目前assets我现在的分支是基于feature/scheme-fee切出来的
qbitpay_service是基于wjc/scheme-fee-20260423 这里干原始分支是否满足需要


if (isRsProfitCashBack(type)) {
                    BigDecimal channelCashBackAmount = purchaseNetAmount.multiply(getRsChannelCashBackRatio(type)).setScale(2, RoundingMode.HALF_UP);
                    BigDecimal schemeFee = Func.getValue(statistic.getCost(), BigDecimal.ZERO);
                    BigDecimal rsProfitAmount = channelCashBackAmount.subtract(schemeFee);
                    amount = feeService.getFee(rsProfitAmount, rate, 2);
                    bonus.setIncome(channelCashBackAmount);
                    bonus.setCost(schemeFee);
                    bonus.setProfit(rsProfitAmount.subtract(amount).setScale(2, RoundingMode.DOWN));
} else {
                    amount = feeService.getFee(purchaseNetAmount, rate, 2);
} 你没有判断负数 和创建营收补差这部分是应该在ApiClientFeeEnum 这里有体现
月账单List<ApiClientMonthFeeVO> apiClientMonthlySettlementFee = apiClientTransactionService.getApiClientMonthlySettlementFee(filterDTO);
因为返现业务是每月三号0点 月账单是10号的12点 所有我想如果是api 客户 直接放到redis里或者说基于
在 
bonus.setIncome(channelCashBackAmount);
bonus.setCost(schemeFee);基于这两个在减一下


getRsSchemeFee 还有一个问题是
/**
     * Scheme 签名费
     */
SCHEME_SIGNATURE_FEE("schemeSignatureFee", "Scheme签名费", "Scheme Signature Fee", null),
这个在获取比较复杂 我只能每月1号去拉取上个月的 订单汇总 目前来说我只针对api 客户处理会写入到

INSERT INTO "public"."api_client_transaction" ("id", "create_time", "update_time", "delete_time", "version", "remarks", "account_id", "transaction_id", "fees", "business_module", "complete_time", "provider", "status") VALUES (2034142452964659203, '2026-03-18 13:38:47.983+08', '2026-03-18 13:38:47.983+08', NULL, 1, '', '8bb5dd09-24ee-40b6-9b2a-d0f882d8e98c', 'f71c81d8-346f-4422-be4b-7239e625577c', '[{"type": "schemeSignatureFee", "amount": "1000.01", "currency": "USD"}]', 'quantum', '2026-01-29 16:21:37.765+08', 'QbitIssuingCardRecharge49387520', 'Closed');
这种的但是关联不到订单 这部分要根据费率计算(后面会记录到账单里但那是10号生成账单的定时任务了)
    /**
     * 签名费 - signature(International) (笔)
     */
    SchemeSignatureFee("SchemeSignatureFee"),

    /**
     * 签名费 (笔)
     */
    SCHEME_SIGNATURE_FEE_CAAS("SchemeSignatureFee_Caas"),
    