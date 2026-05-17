CREATE TABLE public.dws_account_metric_2025 (
    id              BIGINT NOT NULL,
    account_id      VARCHAR(36) NOT NULL,
    metric_code     INT NOT NULL,
    metric_value    NUMERIC(38, 10) NOT NULL DEFAULT 0,

    create_date     TIMESTAMP(6) NOT NULL,
    extra           JSONB,
    version         INT4 DEFAULT 1,
    create_time     TIMESTAMP(6) NOT NULL DEFAULT now(),
    update_time     TIMESTAMP(6) NOT NULL DEFAULT now(),
    delete_time     TIMESTAMP(6),
    remarks         VARCHAR(255),

    CONSTRAINT dws_account_metric_di_pkey PRIMARY KEY (id)
);

COMMENT ON TABLE public.dws_account_metric_2025 IS
'账户级指标事实表（DWS层竖表模型），统一承载量子账户、量子卡、全球账户、加密资产等资金类指标，支持多时间口径、多业务维度的日级统计与分析';

COMMENT ON COLUMN public.dws_account_metric_2025.id IS
'主键ID，全局唯一，由应用或调度层生成，不依赖业务唯一约束';

COMMENT ON COLUMN public.dws_account_metric_2025.account_id IS
'账户ID，统一账户体系下的唯一标识（量子账户 / 全球账户 / 加密账户等）';

COMMENT ON COLUMN public.dws_account_metric_2025.metric_code IS
'指标编码（整型），由 Java 项目内 MetricEnum 定义，代表具体统计指标';

COMMENT ON COLUMN public.dws_account_metric_2025.metric_value IS
'指标数值，高精度数值类型，金额类指标统一按标准币种口径存储';

COMMENT ON COLUMN public.dws_account_metric_2025.create_date IS
'指标归属日期（统计日期），用于日维度聚合，与数据写入时间无关';

COMMENT ON COLUMN public.dws_account_metric_2025.extra IS
'扩展字段（JSON），用于存储非标准化维度或临时业务属性，避免频繁表结构调整';

COMMENT ON COLUMN public.dws_account_metric_2025.version IS
'数据版本号或批次号，用于支持补数、回刷及多批次统计';

COMMENT ON COLUMN public.dws_account_metric_2025.create_time IS
'数据创建时间，记录该行数据首次写入数据库的时间';

COMMENT ON COLUMN public.dws_account_metric_2025.update_time IS
'数据更新时间，记录该行数据最近一次被更新的时间';

COMMENT ON COLUMN public.dws_account_metric_2025.delete_time IS
'逻辑删除时间，非空表示该条指标数据已被废弃';

COMMENT ON COLUMN public.dws_account_metric_2025.remarks IS
'备注说明，用于记录指标口径说明、异常标注或人工修正信息';

101 001 001


量子账户入金：
量子账户充值 ： 'TransferInFromIPeakoin', 'QbitCryptoToQbitCardWallet','TransferInFromQbitGlobal', 'Deposit', 'TransferInFromFinancing', 'TransferInFromCryptoAssets', 'AccountDepositCNY'   , status='Closed' ， 创建时间 ，  细分每一项入金类型
手动转入: TransferIn ,status='Closed'  ， 创建时间
退款：Credit   , status='Closed' ， 创建时间 ， 细分交易币种， 国家 ，渠道 ，  金额还是以美金为单位
撤销 ： Reversal  , status='Closed'  ， 创建时间 ， 细分交易币种， 国家 ，渠道  ， 金额还是以美金为单位
量子卡返现： 'QuantumCreateCardCashBack', 'QuantumAccountCashBack' , 'QuantumAccountDepositCashBack' ,  status='Closed'   ，   完成时间

量子账户出金：
量子卡消费（创建时间）: Consumption ,  创建时间 ， status in ('Closed','Pending') ， 需要细分交易币种， 国家 ，渠道 ， 金额还是以美金为单位
手动转出 ： TransferOut , status='Closed'  ，  创建时间
量子卡手续费 ： 充值手续费 + 开卡费 + settlementFee +  fx / cross border  fee  + atmFee + 退款费 + 撤销费+ 授权费（绑卡验证）  + 制卡费 + 邮寄费 + ATM取现 + 交易失败费 + 非活跃用卡费 ，  创建时间 ， status in ('Closed','Pending')  ， 和消费一起收的需要包含pending ， 不和消费一起的只算closed ，细分每一项手续费类型 
量子卡月账单（实收） : API账单实际还款记录 ， 还款时间

全球账户入金：
全球账户充值：CCInbound , OtherChannelInbound  ，  完成时间（completeTime） ， status='Closed'
账户互转转入 : InnerTransferIn    , status='Closed'  ,    完成时间（completeTime）
付款退款 ：PaymentRefunds  , status='Closed'   , 完成时间（completeTime）

全球账户出金：
全球账户付款：Payment  ， status='Closed' ，  创建时间（createTime）
账户互转转出：InnerTransferIn  ,  status='Closed'  ， 创建时间（createTime）
全球账户手续费：全球账户充值手续费+全球账户付款手续费+全球账户fx费 + 子账户开户费 ,   status='Closed'  ， 创建时间（createTime） ， 细分每一项手续费类型

加密入金:
转入到加密资产 ： action='in' ， status='Closed' ， 完成时间(close_time)
加密资产出金退款 : action='refund' ,  status='Closed'  , 完成时间 (close_time)
加密资产返现 : 'CryptoAssetTradeCashBack'  ， 完成时间(close_time)

加密出金:
从加密资产转出 : action='out'  ，status='Closed'  , 创建时间(create_time)
手续费 ： fee  > 0  , 并且当action='out'时 ， recipient_type !='virtual_card'   ,   字段：fee+cross_chain_fee    ，  创建时间(create_time)  ， 细分每一项手续费类型

加密承兑:
加密承兑: action='sell' and hidden=False  , status='Closed'  ，  创建时间(create_time)
加密承兑(hidden): action='sell' and hidden=True  ， status='Closed' ， 创建时间(create_time)

其他指标：
量子卡月账单（应收） : API账单总计   ， 创建时间
量子卡消费（完成时间）:Consumption , 完成时间 ， status in ('Closed') ，  需要细分交易币种， 国家 ，渠道

余额数据用updateTime ， 需要细分可用余额(available)和冻结余额(frozen) ， 以及币种
量子账户余额：QbitCardWallet
量子卡余额： BlueBancRechargeWallet , ComdataRechargeWallet , ConnexRechargeWallet , GroupWallet , I2cRechargeWallet , MarqetaRechargeWallet , NiumRechargeWallet , PennyCardWallet , QbitIssuingRechargeWallet , RainRechargeWallet , ReapRechargeWallet , SlashRechargeWallet , SolidFIWallet ,ThepennyincRechargeWallet , TripLinkRechargeWallet
全球账户余额：ColumnWallet , CurrencyCloudWallet , EPWallet , HfWallet , L2Wallet , PaymentWallet ,  PingXXWallet , PyvioWallet , RDWallet , ZBWallet
加密资产余额: CircleWallet , CryptoSubWallet , OkxWallet  , VirtualUSD
闪付钱包余额: QBWallet

DwsAccountMetricEnum我要对这个进行改造如
   PENNY(800003,"PennyCardWallet", "Penny 卡钱包"), 要类似这种的