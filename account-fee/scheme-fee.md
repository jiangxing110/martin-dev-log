feature/scheme-fee 分支基于 develop，共 6 个 commit，修改了 16 个文件。核心目标是：新增 Scheme Fee（卡组/品牌手续费）的计算逻辑，与原有的 settle fee、refund fee 等费用并行。

变更总结
1. 新增费用枚举 — AccountFeeType.java
新增了 7 个卡组费用类型，覆盖三种场景，区分国际/国内：
场景枚举值Settle（结算）IssuerTransactionFeesSettlementInt（国际/笔）、IssuerTransactionFeesSettlementIntByDomestic（国内/笔）、IssuerTransactionFeesSettlementIntRate（国际/费率）、IssuerTransactionFeesSettlementDomRate（国内/费率）Refund（退款）SchemeRefundByInternational、SchemeRefundByDomesticReversal（撤销）SchemeReversalByDomestic、SchemeReversalByInternationalSignature Fee（签名费）SchemeSignatureFee
2. 新增 DTO — CalculateFeeDTO.java
封装计算 scheme fee 的入参：accountId、amount、cardBin、feeType、date，自带 check() 校验。
3. 费用计算结果扩展 — IFXResultDTO.java

新增 schemeSettleFeeRate、schemeSettleFee 字段
getTotalFee() 中把 schemeSettleFee 纳入总费用计算

4. 费率查询支持阶梯费 — FeeInput.java
新增 tieredFee 布尔字段，标识是否启用阶梯费率（涉及 low/high 范围查询）
5. Service 层 — AccountFeeService / AccountFeeServiceImpl.java

getAccountSchemeFee()：通用 scheme 费率查询（用于 refund/reversal），支持阶梯费
getSchemeSettleFee()：结算场景下的 scheme 费率查询，根据 isDomestic 选择对应的枚举类型
calculateSchemeSettlementFees()：整合到 getExchangeRateInfo() 主流程中，目前仅 I2C 渠道生效
getBestAccountFee() 底层：新增 tieredFee 判断，按金额区间 low/high 过滤

6. 结算处理器改造（6 个文件）
AbstractSettlementHandler（核心抽象类）：

新增 getSchemeRefundFeeAmount() — 退款场景计算 scheme fee
新增 getReversalSchemeFee() — 撤销场景计算 scheme fee
新增抽象方法 isDomestic() — 要求各渠道实现，判断交易是国内还是国际，决定用哪个费率枚举
在 buildSpecialSourceData() 中把 schemeSettleFee / schemeSettleFeeRate 写入 SpecialSourceDataBo

各渠道实现 isDomestic()：

I2C (AbstractI2cSettlementHandler)：依据商户所在地 acceptorLocation == US/USA 判断
BB (AbstractBBSettlementHandler)：固定返回 false
SL (AbstractSlSettlementHandler)：固定返回 false
Script (ScriptSettlementHandler)：固定返回 false

7. 具体业务处理器改造（3 个 I2C 处理器）
处理器改动I2cSettleHandler部分撤销交易中，fee 加上 reversalSchemeFeeI2cRefundHandlerrefund 交易的 fee 加上 schemeRefundFee，并记录到 SpecialSourceDataBo.schemeRefundFeeI2cReversedHandlerreversal 交易的 fee 加上 reversalSchemeFeeAbstractI2cSettlementHandlerdelta 清算中减去原交易的 schemeSettleFee
8. 数据模型 — SpecialSourceDataBo.java
新增 schemeSettleFeeRate、schemeSettleFee、schemeRefundFee 三个字段
9. 测试 — AccountFeeServiceTest.java
测试用例从原有的 I2C 换汇费用测试，改为测试 getAccountSchemeFee(AccountFeeType.SchemeReversalByDomestic) 场景

整体架构图
getExchangeRateInfo() 主流程
  ├── calculateQbitRate()       ← 原有
  ├── calculateSettlementFees() ← 原有
  └── calculateSchemeSettlementFees()  ← 新增（仅 I2C）
  
各处理器调用
  ├── I2cSettleHandler  →  getReversalSchemeFee()
  ├── I2cRefundHandler  →  getSchemeRefundFeeAmount()
  └── I2cReversedHandler →  getReversalSchemeFee()
一句话总结：这是对 I2C 渠道结算/退款/撤销场景新增了一套卡组手续费（Scheme Fee），按国内/国际区分费率，支持阶梯定价，与原费用并行叠加计算。



getBestAccountFee 

   @PostMapping("/api-customer/sub/card-bin/parent-list")
    @Operation(summary = "获取子户母户支持的card bin列表")
    public Result<List<CardPermissionVO>> getSubParentCardBinList(@RequestBody @Valid ApiClientCustomerDetailDTO detailDTO) {
        return Result.ok(apiCustomerComplianceService.getSubParentCardPermissionList(detailDTO.getAccountId()));
    }


    @PostMapping("/sub/card-bin/parent-list")
    @Operation(summary = "获取子户母户支持的card bin列表")
    public Result<List<CardPermissionVO>> getSubParentCardBinList(@RequestBody @Valid ApiClientCustomerDetailDTO detailDTO) {
        return Result.ok(merchantApiCustomerComplianceService.getParentCardPermissionList(detailDTO.getAccountId()));
    }



只针对BZ渠道
Scheme - Reversal
Scheme - Refund
Scheme - Signature Fee

然后我看 这个在java也有一部分
    public AccountFee getSchemeSettleFee(IFXCalculateDTO request, BigDecimal costAfterExchange, String type, boolean isRate) {
        log.info("getSchemeSettleFee request: {}, costAfterExchange: {}, type: {}, isRate: {}", JSON.toJSONString(request), costAfterExchange, type, isRate);
        AccountFeeType feeType;
        boolean isDom = StringUtils.equalsAnyIgnoreCase("dom", type);
        if (isRate) {
            feeType = isDom ? AccountFeeType.IssuerTransactionFeesSettlementDomRate : AccountFeeType.IssuerTransactionFeesSettlementIntRate;
        } else {
            feeType = isDom ? AccountFeeType.IssuerTransactionFeesSettlementIntByDomestic : AccountFeeType.IssuerTransactionFeesSettlementInt;
        }

 getSignatureFee 暂时为0        


 -- ==================== 默认配置（nil UUID，无 provider）====================
INSERT INTO "public"."accountFee" ("remarks", "createTime", "updateTime", "deleteTime", "version", "accountId", "feeType", "rate", "mathType", "startTime", "endTime", "type", "low", "high", "threshold", "childFeeType", "raw", "provider", "providerField", "enable", "collectionRate")
VALUES ('', now(), now(), NULL, 1, '00000000-0000-0000-0000-000000000000', 'SchemeVerificationFeeByInternational_Caas', '0', 'Count', now(), '2099-02-01 23:59:59+08', 'Tiered', '0', NULL, NULL, 'MasterAccount', NULL, NULL, NULL, 't', '0');
INSERT INTO "public"."accountFee" ("remarks", "createTime", "updateTime", "deleteTime", "version", "accountId", "feeType", "rate", "mathType", "startTime", "endTime", "type", "low", "high", "threshold", "childFeeType", "raw", "provider", "providerField", "enable", "collectionRate")
VALUES ('', now(), now(), NULL, 1, '00000000-0000-0000-0000-000000000000', 'SchemeVerificationFeeByDomestic_Caas', '0', 'Count', now(), '2099-02-01 23:59:59+08', 'Tiered', '0', NULL, NULL, 'MasterAccount', NULL, NULL, NULL, 't', '0');
INSERT INTO "public"."accountFee" ("remarks", "createTime", "updateTime", "deleteTime", "version", "accountId", "feeType", "rate", "mathType", "startTime", "endTime", "type", "low", "high", "threshold", "childFeeType", "raw", "provider", "providerField", "enable", "collectionRate")
VALUES ('', now(), now(), NULL, 1, '00000000-0000-0000-0000-000000000000', 'SchemeReversalByInternational_Caas', '0', 'Count', now(), '2099-02-01 23:59:59+08', 'Tiered', '0', NULL, NULL, 'MasterAccount', NULL, NULL, NULL, 't', '0');
INSERT INTO "public"."accountFee" ("remarks", "createTime", "updateTime", "deleteTime", "version", "accountId", "feeType", "rate", "mathType", "startTime", "endTime", "type", "low", "high", "threshold", "childFeeType", "raw", "provider", "providerField", "enable", "collectionRate")
VALUES ('', now(), now(), NULL, 1, '00000000-0000-0000-0000-000000000000', 'SchemeReversalByDomestic_Caas', '0', 'Count', now(), '2099-02-01 23:59:59+08', 'Tiered', '0', NULL, NULL, 'MasterAccount', NULL, NULL, NULL, 't', '0');
INSERT INTO "public"."accountFee" ("remarks", "createTime", "updateTime", "deleteTime", "version", "accountId", "feeType", "rate", "mathType", "startTime", "endTime", "type", "low", "high", "threshold", "childFeeType", "raw", "provider", "providerField", "enable", "collectionRate")
VALUES ('', now(), now(), NULL, 1, '00000000-0000-0000-0000-000000000000', 'SchemeRefundByInternational_Caas', '0', 'Count', now(), '2099-02-01 23:59:59+08', 'Tiered', '0', NULL, NULL, 'MasterAccount', NULL, NULL, NULL, 't', '0');
INSERT INTO "public"."accountFee" ("remarks", "createTime", "updateTime", "deleteTime", "version", "accountId", "feeType", "rate", "mathType", "startTime", "endTime", "type", "low", "high", "threshold", "childFeeType", "raw", "provider", "providerField", "enable", "collectionRate")
VALUES ('', now(), now(), NULL, 1, '00000000-0000-0000-0000-000000000000', 'SchemeRefundByDomestic_Caas', '0', 'Count', now(), '2099-02-01 23:59:59+08', 'Tiered', '0', NULL, NULL, 'MasterAccount', NULL, NULL, NULL, 't', '0');
INSERT INTO "public"."accountFee" ("remarks", "createTime", "updateTime", "deleteTime", "version", "accountId", "feeType", "rate", "mathType", "startTime", "endTime", "type", "low", "high", "threshold", "childFeeType", "raw", "provider", "providerField", "enable", "collectionRate")
VALUES ('', now(), now(), NULL, 1, '00000000-0000-0000-0000-000000000000', 'SchemeSignatureFee_Caas', '0', 'Count', now(), '2099-02-01 23:59:59+08', 'Tiered', '0', NULL, NULL, 'MasterAccount', NULL, NULL, NULL, 't', '0');

-- ==================== BZ 渠道（I2c）配置 ====================
INSERT INTO "public"."accountFee" ("remarks", "createTime", "updateTime", "deleteTime", "version", "accountId", "feeType", "rate", "mathType", "startTime", "endTime", "type", "low", "high", "threshold", "childFeeType", "raw", "provider", "providerField", "enable", "collectionRate")
VALUES ('BZ 授权费', now(), now(), NULL, 1, '00000000-0000-0000-0000-000000000000', 'IssuerTransactionFeesByAuthInt_Caas', '0.15', 'Count', now(), '2099-02-01 23:59:59+08', 'Tiered', '0', NULL, NULL, 'MasterAccount', NULL, 'I2c', NULL, 't', '0');
INSERT INTO "public"."accountFee" ("remarks", "createTime", "updateTime", "deleteTime", "version", "accountId", "feeType", "rate", "mathType", "startTime", "endTime", "type", "low", "high", "threshold", "childFeeType", "raw", "provider", "providerField", "enable", "collectionRate")
VALUES ('BZ 授权费（国内）', now(), now(), NULL, 1, '00000000-0000-0000-0000-000000000000', 'IssuerTransactionFeesByAuthIntByDomestic_Caas', '0.15', 'Count', now(), '2099-02-01 23:59:59+08', 'Tiered', '0', NULL, NULL, 'MasterAccount', NULL, 'I2c', NULL, 't', '0');
INSERT INTO "public"."accountFee" ("remarks", "createTime", "updateTime", "deleteTime", "version", "accountId", "feeType", "rate", "mathType", "startTime", "endTime", "type", "low", "high", "threshold", "childFeeType", "raw", "provider", "providerField", "enable", "collectionRate")
VALUES ('BZ 结算费', now(), now(), NULL, 1, '00000000-0000-0000-0000-000000000000', 'IssuerTransactionFeesSettlementInt_Caas', '0.10', 'Count', now(), '2099-02-01 23:59:59+08', 'Tiered', '0', NULL, NULL, 'MasterAccount', NULL, 'I2c', NULL, 't', '0');
INSERT INTO "public"."accountFee" ("remarks", "createTime", "updateTime", "deleteTime", "version", "accountId", "feeType", "rate", "mathType", "startTime", "endTime", "type", "low", "high", "threshold", "childFeeType", "raw", "provider", "providerField", "enable", "collectionRate")
VALUES ('BZ 结算费（国内）', now(), now(), NULL, 1, '00000000-0000-0000-0000-000000000000', 'IssuerTransactionFeesSettlementIntByDomestic_Caas', '0.10', 'Count', now(), '2099-02-01 23:59:59+08', 'Tiered', '0', NULL, NULL, 'MasterAccount', NULL, 'I2c', NULL, 't', '0');
INSERT INTO "public"."accountFee" ("remarks", "createTime", "updateTime", "deleteTime", "version", "accountId", "feeType", "rate", "mathType", "startTime", "endTime", "type", "low", "high", "threshold", "childFeeType", "raw", "provider", "providerField", "enable", "collectionRate")
VALUES ('BZ 验证费', now(), now(), NULL, 1, '00000000-0000-0000-0000-000000000000', 'SchemeVerificationFeeByInternational_Caas', '0.10', 'Count', now(), '2099-02-01 23:59:59+08', 'Tiered', '0', NULL, NULL, 'MasterAccount', NULL, 'I2c', NULL, 't', '0');
INSERT INTO "public"."accountFee" ("remarks", "createTime", "updateTime", "deleteTime", "version", "accountId", "feeType", "rate", "mathType", "startTime", "endTime", "type", "low", "high", "threshold", "childFeeType", "raw", "provider", "providerField", "enable", "collectionRate")
VALUES ('BZ 验证费（国内）', now(), now(), NULL, 1, '00000000-0000-0000-0000-000000000000', 'SchemeVerificationFeeByDomestic_Caas', '0.10', 'Count', now(), '2099-02-01 23:59:59+08', 'Tiered', '0', NULL, NULL, 'MasterAccount', NULL, 'I2c', NULL, 't', '0');
INSERT INTO "public"."accountFee" ("remarks", "createTime", "updateTime", "deleteTime", "version", "accountId", "feeType", "rate", "mathType", "startTime", "endTime", "type", "low", "high", "threshold", "childFeeType", "raw", "provider", "providerField", "enable", "collectionRate")
VALUES ('BZ 撤销费', now(), now(), NULL, 1, '00000000-0000-0000-0000-000000000000', 'SchemeReversalByInternational_Caas', '0.10', 'Count', now(), '2099-02-01 23:59:59+08', 'Tiered', '0', NULL, NULL, 'MasterAccount', NULL, 'I2c', NULL, 't', '0');
INSERT INTO "public"."accountFee" ("remarks", "createTime", "updateTime", "deleteTime", "version", "accountId", "feeType", "rate", "mathType", "startTime", "endTime", "type", "low", "high", "threshold", "childFeeType", "raw", "provider", "providerField", "enable", "collectionRate")
VALUES ('BZ 撤销费（国内）', now(), now(), NULL, 1, '00000000-0000-0000-0000-000000000000', 'SchemeReversalByDomestic_Caas', '0.10', 'Count', now(), '2099-02-01 23:59:59+08', 'Tiered', '0', NULL, NULL, 'MasterAccount', NULL, 'I2c', NULL, 't', '0');
INSERT INTO "public"."accountFee" ("remarks", "createTime", "updateTime", "deleteTime", "version", "accountId", "feeType", "rate", "mathType", "startTime", "endTime", "type", "low", "high", "threshold", "childFeeType", "raw", "provider", "providerField", "enable", "collectionRate")
VALUES ('BZ 退款费', now(), now(), NULL, 1, '00000000-0000-0000-0000-000000000000', 'SchemeRefundByInternational_Caas', '0.20', 'Count', now(), '2099-02-01 23:59:59+08', 'Tiered', '0', NULL, NULL, 'MasterAccount', NULL, 'I2c', NULL, 't', '0');
INSERT INTO "public"."accountFee" ("remarks", "createTime", "updateTime", "deleteTime", "version", "accountId", "feeType", "rate", "mathType", "startTime", "endTime", "type", "low", "high", "threshold", "childFeeType", "raw", "provider", "providerField", "enable", "collectionRate")
VALUES ('BZ 退款费（国内）', now(), now(), NULL, 1, '00000000-0000-0000-0000-000000000000', 'SchemeRefundByDomestic_Caas', '0.20', 'Count', now(), '2099-02-01 23:59:59+08', 'Tiered', '0', NULL, NULL, 'MasterAccount', NULL, 'I2c', NULL, 't', '0');
INSERT INTO "public"."accountFee" ("remarks", "createTime", "updateTime", "deleteTime", "version", "accountId", "feeType", "rate", "mathType", "startTime", "endTime", "type", "low", "high", "threshold", "childFeeType", "raw", "provider", "providerField", "enable", "collectionRate")
VALUES ('BZ 签名费', now(), now(), NULL, 1, '00000000-0000-0000-0000-000000000000', 'SchemeSignatureFee_Caas', '0.04', 'Count', now(), '2099-02-01 23:59:59+08', 'Tiered', '0', NULL, NULL, 'MasterAccount', NULL, 'I2c', NULL, 't', '0');

-- ==================== QI 渠道（QbitIssuing）配置 ====================
INSERT INTO "public"."accountFee" ("remarks", "createTime", "updateTime", "deleteTime", "version", "accountId", "feeType", "rate", "mathType", "startTime", "endTime", "type", "low", "high", "threshold", "childFeeType", "raw", "provider", "providerField", "enable", "collectionRate")
VALUES ('QI 授权费 0-5', now(), now(), NULL, 1, '00000000-0000-0000-0000-000000000000', 'IssuerTransactionFeesByAuthInt_Caas', '0.04', 'Count', now(), '2099-02-01 23:59:59+08', 'Tiered', '0', '5', NULL, 'MasterAccount', NULL, 'QbitIssuing', NULL, 't', '0');
INSERT INTO "public"."accountFee" ("remarks", "createTime", "updateTime", "deleteTime", "version", "accountId", "feeType", "rate", "mathType", "startTime", "endTime", "type", "low", "high", "threshold", "childFeeType", "raw", "provider", "providerField", "enable", "collectionRate")
VALUES ('QI 授权费 5-10', now(), now(), NULL, 1, '00000000-0000-0000-0000-000000000000', 'IssuerTransactionFeesByAuthInt_Caas', '0.22', 'Count', now(), '2099-02-01 23:59:59+08', 'Tiered', '5', '10', NULL, 'MasterAccount', NULL, 'QbitIssuing', NULL, 't', '0');
INSERT INTO "public"."accountFee" ("remarks", "createTime", "updateTime", "deleteTime", "version", "accountId", "feeType", "rate", "mathType", "startTime", "endTime", "type", "low", "high", "threshold", "childFeeType", "raw", "provider", "providerField", "enable", "collectionRate")
VALUES ('QI 授权费 10-50', now(), now(), NULL, 1, '00000000-0000-0000-0000-000000000000', 'IssuerTransactionFeesByAuthInt_Caas', '0.26', 'Count', now(), '2099-02-01 23:59:59+08', 'Tiered', '10', '50', NULL, 'MasterAccount', NULL, 'QbitIssuing', NULL, 't', '0');
INSERT INTO "public"."accountFee" ("remarks", "createTime", "updateTime", "deleteTime", "version", "accountId", "feeType", "rate", "mathType", "startTime", "endTime", "type", "low", "high", "threshold", "childFeeType", "raw", "provider", "providerField", "enable", "collectionRate")
VALUES ('QI 授权费 50-250', now(), now(), NULL, 1, '00000000-0000-0000-0000-000000000000', 'IssuerTransactionFeesByAuthInt_Caas', '0.48', 'Count', now(), '2099-02-01 23:59:59+08', 'Tiered', '50', '250', NULL, 'MasterAccount', NULL, 'QbitIssuing', NULL, 't', '0');
INSERT INTO "public"."accountFee" ("remarks", "createTime", "updateTime", "deleteTime", "version", "accountId", "feeType", "rate", "mathType", "startTime", "endTime", "type", "low", "high", "threshold", "childFeeType", "raw", "provider", "providerField", "enable", "collectionRate")
VALUES ('QI 授权费 250+', now(), now(), NULL, 1, '00000000-0000-0000-0000-000000000000', 'IssuerTransactionFeesByAuthInt_Caas', '0.56', 'Count', now(), '2099-02-01 23:59:59+08', 'Tiered', '250', NULL, NULL, 'MasterAccount', NULL, 'QbitIssuing', NULL, 't', '0');
INSERT INTO "public"."accountFee" ("remarks", "createTime", "updateTime", "deleteTime", "version", "accountId", "feeType", "rate", "mathType", "startTime", "endTime", "type", "low", "high", "threshold", "childFeeType", "raw", "provider", "providerField", "enable", "collectionRate")
VALUES ('QI 结算费 0-5', now(), now(), NULL, 1, '00000000-0000-0000-0000-000000000000', 'IssuerTransactionFeesSettlementInt_Caas', '0.01', 'Count', now(), '2099-02-01 23:59:59+08', 'Tiered', '0', '5', NULL, 'MasterAccount', NULL, 'QbitIssuing', NULL, 't', '0');
INSERT INTO "public"."accountFee" ("remarks", "createTime", "updateTime", "deleteTime", "version", "accountId", "feeType", "rate", "mathType", "startTime", "endTime", "type", "low", "high", "threshold", "childFeeType", "raw", "provider", "providerField", "enable", "collectionRate")
VALUES ('QI 结算费 5-10', now(), now(), NULL, 1, '00000000-0000-0000-0000-000000000000', 'IssuerTransactionFeesSettlementInt_Caas', '0.06', 'Count', now(), '2099-02-01 23:59:59+08', 'Tiered', '5', '10', NULL, 'MasterAccount', NULL, 'QbitIssuing', NULL, 't', '0');
INSERT INTO "public"."accountFee" ("remarks", "createTime", "updateTime", "deleteTime", "version", "accountId", "feeType", "rate", "mathType", "startTime", "endTime", "type", "low", "high", "threshold", "childFeeType", "raw", "provider", "providerField", "enable", "collectionRate")
VALUES ('QI 结算费 10-50', now(), now(), NULL, 1, '00000000-0000-0000-0000-000000000000', 'IssuerTransactionFeesSettlementInt_Caas', '0.08', 'Count', now(), '2099-02-01 23:59:59+08', 'Tiered', '10', '50', NULL, 'MasterAccount', NULL, 'QbitIssuing', NULL, 't', '0');
INSERT INTO "public"."accountFee" ("remarks", "createTime", "updateTime", "deleteTime", "version", "accountId", "feeType", "rate", "mathType", "startTime", "endTime", "type", "low", "high", "threshold", "childFeeType", "raw", "provider", "providerField", "enable", "collectionRate")
VALUES ('QI 结算费 50-250', now(), now(), NULL, 1, '00000000-0000-0000-0000-000000000000', 'IssuerTransactionFeesSettlementInt_Caas', '0.12', 'Count', now(), '2099-02-01 23:59:59+08', 'Tiered', '50', '250', NULL, 'MasterAccount', NULL, 'QbitIssuing', NULL, 't', '0');
INSERT INTO "public"."accountFee" ("remarks", "createTime", "updateTime", "deleteTime", "version", "accountId", "feeType", "rate", "mathType", "startTime", "endTime", "type", "low", "high", "threshold", "childFeeType", "raw", "provider", "providerField", "enable", "collectionRate")
VALUES ('QI 结算费 250+', now(), now(), NULL, 1, '00000000-0000-0000-0000-000000000000', 'IssuerTransactionFeesSettlementInt_Caas', '0.14', 'Count', now(), '2099-02-01 23:59:59+08', 'Tiered', '250', NULL, NULL, 'MasterAccount', NULL, 'QbitIssuing', NULL, 't', '0');
INSERT INTO "public"."accountFee" ("remarks", "createTime", "updateTime", "deleteTime", "version", "accountId", "feeType", "rate", "mathType", "startTime", "endTime", "type", "low", "high", "threshold", "childFeeType", "raw", "provider", "providerField", "enable", "collectionRate")
VALUES ('QI 服务费 0-5', now(), now(), NULL, 1, '00000000-0000-0000-0000-000000000000', 'IssuerCardServiceFeesInt_Caas', '0.00095', 'Percent', now(), '2099-02-01 23:59:59+08', 'Tiered', '0', '5', NULL, 'MasterAccount', NULL, 'QbitIssuing', NULL, 't', '0');
INSERT INTO "public"."accountFee" ("remarks", "createTime", "updateTime", "deleteTime", "version", "accountId", "feeType", "rate", "mathType", "startTime", "endTime", "type", "low", "high", "threshold", "childFeeType", "raw", "provider", "providerField", "enable", "collectionRate")
VALUES ('QI 服务费 5-10', now(), now(), NULL, 1, '00000000-0000-0000-0000-000000000000', 'IssuerCardServiceFeesInt_Caas', '0.00145', 'Percent', now(), '2099-02-01 23:59:59+08', 'Tiered', '5', '10', NULL, 'MasterAccount', NULL, 'QbitIssuing', NULL, 't', '0');
INSERT INTO "public"."accountFee" ("remarks", "createTime", "updateTime", "deleteTime", "version", "accountId", "feeType", "rate", "mathType", "startTime", "endTime", "type", "low", "high", "threshold", "childFeeType", "raw", "provider", "providerField", "enable", "collectionRate")
VALUES ('QI 服务费 10-50', now(), now(), NULL, 1, '00000000-0000-0000-0000-000000000000', 'IssuerCardServiceFeesInt_Caas', '0.00220', 'Percent', now(), '2099-02-01 23:59:59+08', 'Tiered', '10', '50', NULL, 'MasterAccount', NULL, 'QbitIssuing', NULL, 't', '0');
INSERT INTO "public"."accountFee" ("remarks", "createTime", "updateTime", "deleteTime", "version", "accountId", "feeType", "rate", "mathType", "startTime", "endTime", "type", "low", "high", "threshold", "childFeeType", "raw", "provider", "providerField", "enable", "collectionRate")
VALUES ('QI 服务费 50-250', now(), now(), NULL, 1, '00000000-0000-0000-0000-000000000000', 'IssuerCardServiceFeesInt_Caas', '0.00370', 'Percent', now(), '2099-02-01 23:59:59+08', 'Tiered', '50', '250', NULL, 'MasterAccount', NULL, 'QbitIssuing', NULL, 't', '0');
INSERT INTO "public"."accountFee" ("remarks", "createTime", "updateTime", "deleteTime", "version", "accountId", "feeType", "rate", "mathType", "startTime", "endTime", "type", "low", "high", "threshold", "childFeeType", "raw", "provider", "providerField", "enable", "collectionRate")
VALUES ('QI 服务费 250+', now(), now(), NULL, 1, '00000000-0000-0000-0000-000000000000', 'IssuerCardServiceFeesInt_Caas', '0.00445', 'Percent', now(), '2099-02-01 23:59:59+08', 'Tiered', '250', NULL, NULL, 'MasterAccount', NULL, 'QbitIssuing', NULL, 't', '0');
INSERT INTO "public"."accountFee" ("remarks", "createTime", "updateTime", "deleteTime", "version", "accountId", "feeType", "rate", "mathType", "startTime", "endTime", "type", "low", "high", "threshold", "childFeeType", "raw", "provider", "providerField", "enable", "collectionRate")
VALUES ('QI 风险费', now(), now(), NULL, 1, '00000000-0000-0000-0000-000000000000', 'VisaRiskManagerInt_Caas', '0.07', 'Count', now(), '2099-02-01 23:59:59+08', 'Tiered', '0', NULL, NULL, 'MasterAccount', NULL, 'QbitIssuing', NULL, 't', '0');