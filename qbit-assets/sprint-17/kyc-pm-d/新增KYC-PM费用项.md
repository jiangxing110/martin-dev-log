# 新增KYC\-PM费用项

**需求背景：**

目前我们系统针对有能力做kyc的客户，开放了一种“Partner Manage”的模式，也就是客户自己三方kyc系统，并将check过的信息传给我们，我方系统不再全部进行三方check的流程，只有在渠道侧进行抽查时，才进行三方check的模式。针对此类模式的kyc，会给客户稍低的报价。且目前该功能是需要申请开通，且根据卡渠道的政策来处理的。



**需求范围：**

|**模块**|**需求点**|**优先级**|
|---|---|---|
||||
||||
||||
||||
||||





# 数据落库逻辑

原逻辑，只有在调用三方时，才会在 `idv_channel_request_record` 中落数据，因目前增加了kyc\_pm的合规模式\(也就是该类型的客户提交的kyc信息都不送三方检查，按照抽检规则才会送三方检查\)，但是我们需要对该类型的客户，所有上送的次数进行收费。

- 需要在 `idv_channel_request_record` 中新增字段 ：
`checkType` ：校验类型，枚举：THIRD\_PARTY\(三方\)，SELF\_CHECK\(自检\)

- 当客户调用KYC、cardholder、实体卡url接口时\(按照现有逻辑判断唯一性\)，且客户开通的KYC\-PM模式，则需要在 `idv_channel_request_record` 中落一条数据，`checkType = SELF_CHECK` 的记录。

- KYC\-PM模式下，后续触发自动抽检任务时，上送三方校验的数据暂不落该表统计。

- 该表其他字段定义不变，且新增字段后，历史数据关于`checkType` 字段的初始值 = THIRD\_PARTY。





# 新增费用项

- 本期需要新增费用项：身份托管验证费\(KYC\-PM Verification Fee\)，按月统计，在月结账单中收取。
相关费用名称及说明，以及只支持固定值的配置，等说明已经更新到[账户费率合集](https://axss9gjoff.feishu.cn/wiki/DfndwFvH0iJqcgky195cmeKynMg)表中。新老账户费率都需要新增，默认费率：0\.85 usd / 次

- 计费公式：客户月度KYC费用 = \(`checkType = THIRD_PARTY` 的次数 \* KYC Verification Fee\) \+ \(`checkType = SELF_CHECK`的次数 \* KYC\-PM Verification Fee\)
统计维度：该客户该自然月按照checkType分类统计次数。











