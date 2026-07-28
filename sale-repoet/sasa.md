| 字段名                   | 含义          | 备注                                                                                                                                                                                                                                                                                                                                                                                         |
| --------------------- | ----------- | ------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------------ |
| `id`                  | 客户 ID       |                                                                                                                                                                                                                                                                                                                                                                                            |
| `verifiedName`        | 客户名称        |                                                                                                                                                                                                                                                                                                                                                                                            |
| `type`                | 客户类型        | DWM 层已完成子母账户以及 Gateway、Distributor 账户合并，因此只保存最上层客户数据。<br><br>取值范围：`type IN ('ApiClient', 'MasterAccount', 'Merchant', 'TestAccount')`                                                                                                                                                                                                                                                      |
| `status`              | 客户状态        |                                                                                                                                                                                                                                                                                                                                                                                            |
| `systemType`          | 客户系统类型      | accountExtend.systemType 标识客户属于 Qbit 还是 Interlace。                                                                                                                                                                                                                                                                                                                                                                  |
| `business_mode`       | 业务模式        | 来源字段：`caas_open_api_extend.business_mode`                                                                                                                                                                                                                                                                                                                                                  |
| `account_type`        | 对接模式        | 来源字段：`caas_open_api_extend.account_type`                                                                                                                                                                                                                                                                                                                                                   |
| `mor_type`            | MOR 类别      | 来源字段：`caas_open_api_extend.mor_type`                                                                                                                                                                                                                                                                                                                                                       |
| `mor_type_extra`      | MOR 类别扩展字段  | 来源字段：`caas_open_api_extend.mor_type_extra`                                                                                                                                                                                                                                                                                                                                                 |
| `accountRiskLevel`    | 客户风险等级      | 来源字段：`cddRiskRating.accountRiskLevel`                                                                                                                                                                                                                                                                                                                                                      |
| `card_activeTime`     | 客户量子卡激活时间   | 数据来源：`qbitCardWalletTransaction`。<br><br>筛选条件：<br>`business_type IN ('TransferInFromIPeakoin', 'QbitCryptoToQbitCardWallet', 'TransferInFromQbitGlobal', 'Deposit', 'TransferInFromFinancing', 'TransferInFromCryptoAssets', 'AccountDepositCNY')`<br>`status = 'Closed'`<br><br>激活时间定义：按客户累计计算 `SUM(originAmount)`，累计金额首次超过 `5000` 时对应的第一笔交易时间。<br><br>需要合并子母账户以及 Gateway、Distributor 账户。 |
| `global_activeTime`   | 客户全球账户激活时间  | 数据来源：`transfer`。<br><br>计算逻辑：<br>`SELECT "accountId", MIN("transactionTime")`<br>`FROM transfer`<br>`GROUP BY "accountId"`<br><br>需要合并子母账户以及 Gateway、Distributor 账户。                                                                                                                                                                                                                       |
| `crypto_activeTime`   | 客户加密资产激活时间  | 数据来源：`crypto_assets_transfers`。<br><br>筛选条件：<br>`action = 'sell'`<br>`status = 'Closed'`<br>`hidden = FALSE`<br><br>激活时间定义：按客户累计计算 `SUM(origin_amount * usd_rate)`，累计金额首次超过 `200000` 时对应的第一笔交易时间。<br><br>需要合并子母账户以及 Gateway、Distributor 账户。                                                                                                                                                |
| `api_activeTime`      | 客户 API 上线时间 | API 客户上线时间。<br><br>来源字段：`openApiClientConfig.online_time`                                                                                                                                                                                                                                                                                                                                  |
| `treasury_activeTime` | 客户粒子理财激活时间  | 客户第一次使用粒子理财的时间。<br><br>计算逻辑：<br>`SELECT account_id, MIN(create_time)`<br>`FROM fund_orders`<br>`WHERE type = 'purchase'`<br>`  AND status = 'complete'`<br>`GROUP BY account_id`                                                                                                                                                                                                           |

我想要建一张表记录这些东西 dim_account_analysis 
1.看看/Users/martinjiang/VsCodeProjects/martin-dev-log/bi-cost/flink/quantum-v2的逻辑脚本要cdc batch
还有建表的table-scripts



CREATE TABLE "public"."caas_open_api_extend" (
  "id" int8 NOT NULL,
  "account_id" uuid NOT NULL,
  "business_mode" varchar(100) COLLATE "pg_catalog"."default",
  "access_type" varchar(20) COLLATE "pg_catalog"."default",
  "mor_type" varchar(20) COLLATE "pg_catalog"."default",
  "mor_type_extra" varchar(255) COLLATE "pg_catalog"."default",
  "remarks" varchar(255) COLLATE "pg_catalog"."default",
  "create_time" timestamptz(6) NOT NULL DEFAULT now(),
  "update_time" timestamptz(6) NOT NULL DEFAULT now(),
  "delete_time" timestamptz(6),
  "version" int4 NOT NULL,
  "source" varchar(20) COLLATE "pg_catalog"."default" DEFAULT 'OFFLINE'::character varying,
  "infinity_launch_flag" bool NOT NULL DEFAULT false,
  "cardholder_types" jsonb,
  "allow_individual_pay" bool,
  "partner_managed_kyc_flag" bool NOT NULL DEFAULT false,
  CONSTRAINT "caas_open_api_extend_pkey" PRIMARY KEY ("id")
)
;

ALTER TABLE "public"."caas_open_api_extend" 
  OWNER TO "qbit_admin";

COMMENT ON COLUMN "public"."caas_open_api_extend"."business_mode" IS '业务模式';

COMMENT ON COLUMN "public"."caas_open_api_extend"."access_type" IS '对接模式';

COMMENT ON COLUMN "public"."caas_open_api_extend"."mor_type" IS 'mor类别';

COMMENT ON COLUMN "public"."caas_open_api_extend"."mor_type_extra" IS 'mor类别扩展字段';

COMMENT ON COLUMN "public"."caas_open_api_extend"."infinity_launch_flag" IS '是否为Infinity Launch';

COMMENT ON COLUMN "public"."caas_open_api_extend"."partner_managed_kyc_flag" IS '无需kyc标志';

COMMENT ON TABLE "public"."caas_open_api_extend" IS 'Caas-open-api扩展表';


CREATE TABLE "public"."cddRiskRating" (
  "id" uuid NOT NULL,
  "remarks" varchar COLLATE "pg_catalog"."default",
  "createTime" timestamptz(6) NOT NULL DEFAULT now(),
  "updateTime" timestamptz(6) NOT NULL DEFAULT now(),
  "deleteTime" timestamptz(6),
  "version" int4 NOT NULL,
  "accountId" uuid NOT NULL,
  "updateUserId" uuid,
  "registryCountry" varchar COLLATE "pg_catalog"."default",
  "entityType" varchar COLLATE "pg_catalog"."default",
  "registryTime" varchar COLLATE "pg_catalog"."default",
  "scale" varchar COLLATE "pg_catalog"."default",
  "businessType" varchar COLLATE "pg_catalog"."default",
  "industry" varchar COLLATE "pg_catalog"."default",
  "ownershipTransparency" varchar COLLATE "pg_catalog"."default",
  "directorAge" varchar COLLATE "pg_catalog"."default",
  "workplace" varchar COLLATE "pg_catalog"."default",
  "directorNationality" varchar COLLATE "pg_catalog"."default",
  "UBONationality" varchar COLLATE "pg_catalog"."default",
  "product" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "PEPRelated" bool NOT NULL,
  "negativeNews" varchar COLLATE "pg_catalog"."default",
  "identityProofType" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "accountRiskLevel" varchar COLLATE "pg_catalog"."default",
  "comment" varchar COLLATE "pg_catalog"."default",
  "attachments" json,
  "businessOperationCountry" varchar COLLATE "pg_catalog"."default",
  "businessScene" varchar COLLATE "pg_catalog"."default",
  "individualNegativeNews" varchar COLLATE "pg_catalog"."default",
  "threeElementsVerification" varchar COLLATE "pg_catalog"."default",
  "nationality" varchar COLLATE "pg_catalog"."default",
  "sourceId" uuid,
  "sourceType" varchar COLLATE "pg_catalog"."default" NOT NULL DEFAULT 'Cdd'::character varying,
  CONSTRAINT "PK_08b12b74561ef2941a552899bfa" PRIMARY KEY ("id")
)
;

ALTER TABLE "public"."cddRiskRating" 
  OWNER TO "qbit_admin";

COMMENT ON COLUMN "public"."cddRiskRating"."remarks" IS '备注';

COMMENT ON COLUMN "public"."cddRiskRating"."accountId" IS '被评测的账户ID';

COMMENT ON COLUMN "public"."cddRiskRating"."updateUserId" IS '最后处理人';

COMMENT ON COLUMN "public"."cddRiskRating"."registryCountry" IS '注册国家';

COMMENT ON COLUMN "public"."cddRiskRating"."entityType" IS '公司主体类型';

COMMENT ON COLUMN "public"."cddRiskRating"."registryTime" IS '注册时间';

COMMENT ON COLUMN "public"."cddRiskRating"."scale" IS '公司规模';

COMMENT ON COLUMN "public"."cddRiskRating"."businessType" IS '业务类型';

COMMENT ON COLUMN "public"."cddRiskRating"."industry" IS '行业风险等级';

COMMENT ON COLUMN "public"."cddRiskRating"."ownershipTransparency" IS '股权透明度';

COMMENT ON COLUMN "public"."cddRiskRating"."directorAge" IS '法代/董事年龄';

COMMENT ON COLUMN "public"."cddRiskRating"."workplace" IS '办公场所';

COMMENT ON COLUMN "public"."cddRiskRating"."directorNationality" IS '董事/法人国籍的风险等级';

COMMENT ON COLUMN "public"."cddRiskRating"."UBONationality" IS 'UBO国籍的风险等级';

COMMENT ON COLUMN "public"."cddRiskRating"."product" IS '产品的风险等级';

COMMENT ON COLUMN "public"."cddRiskRating"."PEPRelated" IS '政治公众人物相关';

COMMENT ON COLUMN "public"."cddRiskRating"."negativeNews" IS '负面新闻';

COMMENT ON COLUMN "public"."cddRiskRating"."identityProofType" IS '身份证明文件类型';

COMMENT ON COLUMN "public"."cddRiskRating"."accountRiskLevel" IS '账户风险评级';

COMMENT ON COLUMN "public"."cddRiskRating"."comment" IS '备注';

COMMENT ON COLUMN "public"."cddRiskRating"."attachments" IS '附件列表';

COMMENT ON COLUMN "public"."cddRiskRating"."individualNegativeNews" IS '个人负面新闻';

COMMENT ON COLUMN "public"."cddRiskRating"."threeElementsVerification" IS '三要素是否一致';

COMMENT ON COLUMN "public"."cddRiskRating"."nationality" IS '国籍风险级别';

COMMENT ON COLUMN "public"."cddRiskRating"."sourceId" IS '源ID';

COMMENT ON COLUMN "public"."cddRiskRating"."sourceType" IS '源类型';


CREATE TABLE "public"."qbitCardWalletTransaction" (
  "id" uuid NOT NULL,
  "remarks" varchar COLLATE "pg_catalog"."default",
  "createTime" timestamptz(6) NOT NULL DEFAULT now(),
  "updateTime" timestamptz(6) NOT NULL DEFAULT now(),
  "deleteTime" timestamptz(6),
  "version" int4 NOT NULL,
  "accountId" uuid NOT NULL,
  "balanceId" uuid,
  "groupId" uuid,
  "cardId" uuid,
  "status" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "statusLog" varchar COLLATE "pg_catalog"."default",
  "settleAmount" float8 NOT NULL DEFAULT '0'::double precision,
  "businessType" varchar COLLATE "pg_catalog"."default" NOT NULL DEFAULT ''::character varying,
  "sourceId" varchar COLLATE "pg_catalog"."default" NOT NULL DEFAULT ''::character varying,
  "transactionTime" timestamptz(6),
  "transactionId" uuid DEFAULT '00000000-0000-0000-0000-000000000000'::uuid,
  "originAmount" float8 NOT NULL DEFAULT 0,
  "fee" float8 NOT NULL DEFAULT 0,
  "imageUrlList" json,
  "serialNo" varchar COLLATE "pg_catalog"."default" DEFAULT ''::character varying,
  "depositSourceUserName" varchar COLLATE "pg_catalog"."default" DEFAULT ''::character varying,
  "depositSource" varchar COLLATE "pg_catalog"."default" DEFAULT ''::character varying,
  "lastOperationUserId" varchar COLLATE "pg_catalog"."default" DEFAULT ''::character varying,
  "currency" varchar COLLATE "pg_catalog"."default",
  "processStatus" varchar COLLATE "pg_catalog"."default",
  "processStatusLog" json,
  "originFee" float8 NOT NULL DEFAULT '0'::double precision,
  "channelFee" numeric NOT NULL DEFAULT 0,
  "transactionCurrency" varchar COLLATE "pg_catalog"."default" NOT NULL DEFAULT 'USD'::character varying,
  "id_" int8,
  "transactionDisplayId" int8,
  CONSTRAINT "PK_617c58ff1cf0a8f00e1993d1e78" PRIMARY KEY ("id")
)
;

ALTER TABLE "public"."qbitCardWalletTransaction" 
  OWNER TO "qbit_admin";

CREATE INDEX "IDX_7a2fe2082037815cb715dee9fa" ON "public"."qbitCardWalletTransaction" USING btree (
  "cardId" "pg_catalog"."uuid_ops" ASC NULLS LAST
);

CREATE INDEX "IDX_qbitCardWalletTransaction_cardId" ON "public"."qbitCardWalletTransaction" USING btree (
  "cardId" "pg_catalog"."uuid_ops" ASC NULLS LAST
);

CREATE INDEX "accountid_businesstype" ON "public"."qbitCardWalletTransaction" USING btree (
  "accountId" "pg_catalog"."uuid_ops" ASC NULLS LAST,
  "businessType" COLLATE "pg_catalog"."default" "pg_catalog"."text_ops" ASC NULLS LAST
);

COMMENT ON COLUMN "public"."qbitCardWalletTransaction"."remarks" IS '备注';

COMMENT ON COLUMN "public"."qbitCardWalletTransaction"."accountId" IS 'account id';

COMMENT ON COLUMN "public"."qbitCardWalletTransaction"."balanceId" IS '量子卡 id';

COMMENT ON COLUMN "public"."qbitCardWalletTransaction"."groupId" IS '交易的balanceId';

COMMENT ON COLUMN "public"."qbitCardWalletTransaction"."cardId" IS '交易的cardId';

COMMENT ON COLUMN "public"."qbitCardWalletTransaction"."status" IS '交易状态';

COMMENT ON COLUMN "public"."qbitCardWalletTransaction"."settleAmount" IS '结算金额';

COMMENT ON COLUMN "public"."qbitCardWalletTransaction"."businessType" IS '业务类别';

COMMENT ON COLUMN "public"."qbitCardWalletTransaction"."sourceId" IS '三方订单Id';

COMMENT ON COLUMN "public"."qbitCardWalletTransaction"."transactionTime" IS '交易时间，如果Qbit时间，则为创建时间，不是则为三方的创建时间';

COMMENT ON COLUMN "public"."qbitCardWalletTransaction"."transactionId" IS 'transactionId 用于回滚';

COMMENT ON COLUMN "public"."qbitCardWalletTransaction"."originAmount" IS '原始金额';

COMMENT ON COLUMN "public"."qbitCardWalletTransaction"."fee" IS '费用';

COMMENT ON COLUMN "public"."qbitCardWalletTransaction"."currency" IS '结算币种';

COMMENT ON COLUMN "public"."qbitCardWalletTransaction"."processStatus" IS '流转状态';

COMMENT ON COLUMN "public"."qbitCardWalletTransaction"."originFee" IS '原始费用';

COMMENT ON COLUMN "public"."qbitCardWalletTransaction"."channelFee" IS '渠道手续费';

COMMENT ON COLUMN "public"."qbitCardWalletTransaction"."transactionCurrency" IS '原始交易币种';


CREATE TABLE "public"."transfer" (
  "id" uuid NOT NULL,
  "remarks" varchar COLLATE "pg_catalog"."default",
  "createTime" timestamptz(6) NOT NULL DEFAULT now(),
  "updateTime" timestamptz(6) NOT NULL DEFAULT now(),
  "deleteTime" timestamptz(6),
  "version" int4 NOT NULL,
  "accountId" varchar COLLATE "pg_catalog"."default" NOT NULL,
  "currency" varchar(30) COLLATE "pg_catalog"."default" NOT NULL DEFAULT 'USD'::character varying,
  "counterparty" varchar(5000) COLLATE "pg_catalog"."default",
  "originAmount" float8 NOT NULL DEFAULT '0'::double precision,
  "settlementAmount" float8 NOT NULL DEFAULT '0'::double precision,
  "sourceId" varchar COLLATE "pg_catalog"."default",
  "fee" float8 NOT NULL DEFAULT '0'::double precision,
  "rawData" json,
  "statusLog" json,
  "transactionId" uuid DEFAULT '00000000-0000-0000-0000-000000000000'::uuid,
  "transactionTime" timestamptz(6) NOT NULL DEFAULT now(),
  "transactionDisplayId" varchar COLLATE "pg_catalog"."default",
  "settlesTime" timestamptz(6),
  "completedTime" timestamptz(6),
  "reviewTime" timestamptz(6),
  "provider" varchar(255) COLLATE "pg_catalog"."default",
  "businessType" varchar(255) COLLATE "pg_catalog"."default",
  "businessTypeDetail" varchar(255) COLLATE "pg_catalog"."default",
  "status" varchar(255) COLLATE "pg_catalog"."default" NOT NULL DEFAULT 'Pending'::character varying,
  "originTransferId" uuid,
  "settlementCurrency" varchar COLLATE "pg_catalog"."default",
  "receiverId" uuid,
  "reference" varchar COLLATE "pg_catalog"."default" NOT NULL DEFAULT ''::character varying,
  "merchantShow" bool NOT NULL DEFAULT true,
  "accountRelation" varchar COLLATE "pg_catalog"."default",
  "whitelistId" uuid,
  "fromBalanceId" uuid,
  "toBalanceId" uuid,
  "transferType" varchar COLLATE "pg_catalog"."default",
  "usdRate" numeric(25,12),
  "usdAmount" float8,
  "purposeCode" varchar COLLATE "pg_catalog"."default",
  "clientTransactionId" varchar COLLATE "pg_catalog"."default",
  "qbitCardTransactionId" uuid,
  "actualAccountId" uuid,
  "mainAccountId" uuid,
  "batchNo" varchar COLLATE "pg_catalog"."default" DEFAULT ''::character varying,
  "appendFee" float8 NOT NULL DEFAULT '0'::double precision,
  "transferFlow" jsonb,
  "data" json,
  "shopType" varchar COLLATE "pg_catalog"."default",
  "settleType" varchar COLLATE "pg_catalog"."default",
  "rates" json,
  "feeType" varchar COLLATE "pg_catalog"."default",
  "batchPaymentStatus" varchar COLLATE "pg_catalog"."default",
  "spotCheck" bool,
  "transferWhiteListStatus" varchar COLLATE "pg_catalog"."default",
  "originFee" float8 NOT NULL DEFAULT '0'::double precision,
  "droolsStatus" jsonb,
  "shopAutoInboundStatus" varchar COLLATE "pg_catalog"."default",
  "shortReference" varchar COLLATE "pg_catalog"."default",
  "conversionShortReference" varchar COLLATE "pg_catalog"."default",
  "realPaymentCurrency" varchar COLLATE "pg_catalog"."default",
  "extraData" json,
  "channelDiffAmount" float8 NOT NULL DEFAULT '0'::double precision,
  "reexamineId" uuid,
  "passport" varchar COLLATE "pg_catalog"."default",
  "reexamineTime" timestamptz(6),
  "isNewPayment" bool DEFAULT false,
  "businessCode" varchar(30) COLLATE "pg_catalog"."default",
  CONSTRAINT "PK_fd9ddbdd49a17afcbe014401295" PRIMARY KEY ("id")
)
;

ALTER TABLE "public"."transfer" 
  OWNER TO "qbit_admin";

COMMENT ON COLUMN "public"."transfer"."remarks" IS '备注';

COMMENT ON COLUMN "public"."transfer"."accountId" IS '所属账户id';

COMMENT ON COLUMN "public"."transfer"."currency" IS '币种';

COMMENT ON COLUMN "public"."transfer"."originAmount" IS '原始金额';

COMMENT ON COLUMN "public"."transfer"."settlementAmount" IS '清算金额';

COMMENT ON COLUMN "public"."transfer"."fee" IS '源费用';

COMMENT ON COLUMN "public"."transfer"."transactionId" IS 'transaction表的Id';

COMMENT ON COLUMN "public"."transfer"."transactionTime" IS '交易时间，如：三方的交易时间，我方的创建时间';

COMMENT ON COLUMN "public"."transfer"."transactionDisplayId" IS '统一订单号，全局唯一，用于展示';

COMMENT ON COLUMN "public"."transfer"."settlesTime" IS '清算时间';

COMMENT ON COLUMN "public"."transfer"."completedTime" IS '完成时间';

COMMENT ON COLUMN "public"."transfer"."reviewTime" IS '审核时间';

COMMENT ON COLUMN "public"."transfer"."provider" IS '生产者';

COMMENT ON COLUMN "public"."transfer"."businessType" IS '状态';

COMMENT ON COLUMN "public"."transfer"."businessTypeDetail" IS '详细业务类型';

COMMENT ON COLUMN "public"."transfer"."status" IS '状态';

COMMENT ON COLUMN "public"."transfer"."originTransferId" IS '原始转账订单';

COMMENT ON COLUMN "public"."transfer"."settlementCurrency" IS '原始转账订单';

COMMENT ON COLUMN "public"."transfer"."receiverId" IS '接收方ID';

COMMENT ON COLUMN "public"."transfer"."reference" IS '付款备注';

COMMENT ON COLUMN "public"."transfer"."merchantShow" IS '此条记录是否对用户展示';

COMMENT ON COLUMN "public"."transfer"."accountRelation" IS '出入金账户关系';

COMMENT ON COLUMN "public"."transfer"."whitelistId" IS '白名单ID，通过白名单入账时记录';

COMMENT ON COLUMN "public"."transfer"."fromBalanceId" IS '付款、转账账户的BalanceId';

COMMENT ON COLUMN "public"."transfer"."toBalanceId" IS '接收方账户的BalanceId';

COMMENT ON COLUMN "public"."transfer"."usdRate" IS '兑换美元的汇率';

COMMENT ON COLUMN "public"."transfer"."usdAmount" IS '换汇后的美元金额';

COMMENT ON COLUMN "public"."transfer"."purposeCode" IS '付款目的代码';

COMMENT ON COLUMN "public"."transfer"."clientTransactionId" IS '系统编号';

COMMENT ON COLUMN "public"."transfer"."qbitCardTransactionId" IS 'qbit卡的交易ID';

COMMENT ON COLUMN "public"."transfer"."actualAccountId" IS '实际应用此收款人的账户ID';

COMMENT ON COLUMN "public"."transfer"."mainAccountId" IS '主体的账户ID';

COMMENT ON COLUMN "public"."transfer"."batchNo" IS '批量号';

COMMENT ON COLUMN "public"."transfer"."appendFee" IS '使用方最近的手续费';

COMMENT ON COLUMN "public"."transfer"."transferFlow" IS '全球账户付款交易详情';

COMMENT ON COLUMN "public"."transfer"."rates" IS '订单初始汇率json';

COMMENT ON COLUMN "public"."transfer"."feeType" IS '全球账户付款收费模式';

COMMENT ON COLUMN "public"."transfer"."originFee" IS '原始费用';

COMMENT ON COLUMN "public"."transfer"."droolsStatus" IS '事中风控状态';

COMMENT ON COLUMN "public"."transfer"."shopAutoInboundStatus" IS '店铺自动入金状态';

COMMENT ON COLUMN "public"."transfer"."shortReference" IS '国际通用的交易唯一标识';

COMMENT ON COLUMN "public"."transfer"."conversionShortReference" IS '国际通用的交易唯一标识-换汇';

COMMENT ON COLUMN "public"."transfer"."realPaymentCurrency" IS '实际支出币种';

COMMENT ON COLUMN "public"."transfer"."channelDiffAmount" IS '渠道差额（盈利金额）';

COMMENT ON COLUMN "public"."transfer"."reexamineId" IS '复审标识id';

COMMENT ON COLUMN "public"."transfer"."passport" IS '护照号';


CREATE TABLE "public"."crypto_assets_transfers" (
  "id" uuid NOT NULL,
  "balance_id" varchar(64) COLLATE "pg_catalog"."default" NOT NULL,
  "status" varchar(255) COLLATE "pg_catalog"."default" NOT NULL,
  "create_time" timestamptz(6) NOT NULL,
  "update_time" timestamptz(6) NOT NULL,
  "delete_time" timestamptz(6),
  "version" int4 NOT NULL DEFAULT 1,
  "action" varchar(20) COLLATE "pg_catalog"."default" NOT NULL,
  "address" varchar(64) COLLATE "pg_catalog"."default",
  "settlement_amount" numeric NOT NULL DEFAULT 0,
  "fee" numeric NOT NULL DEFAULT 0,
  "trade_id" varchar(255) COLLATE "pg_catalog"."default" NOT NULL,
  "handle_user_id" varchar(64) COLLATE "pg_catalog"."default",
  "chain" varchar(20) COLLATE "pg_catalog"."default" NOT NULL,
  "currency" varchar(30) COLLATE "pg_catalog"."default" NOT NULL,
  "reason" varchar(255) COLLATE "pg_catalog"."default",
  "transaction_id" varchar(100) COLLATE "pg_catalog"."default",
  "transaction_time" timestamptz(6),
  "account_id" uuid NOT NULL,
  "origin_amount" numeric DEFAULT 0,
  "rate" numeric DEFAULT 1,
  "display_status" varchar(30) COLLATE "pg_catalog"."default",
  "quote_currency" varchar(30) COLLATE "pg_catalog"."default",
  "business_type_detail" varchar(60) COLLATE "pg_catalog"."default",
  "sender_type" varchar(60) COLLATE "pg_catalog"."default",
  "recipient_type" varchar(60) COLLATE "pg_catalog"."default",
  "payee_id" varchar(36) COLLATE "pg_catalog"."default",
  "counter_party" varchar(255) COLLATE "pg_catalog"."default",
  "raw_data" jsonb,
  "account_relation" varchar(255) COLLATE "pg_catalog"."default",
  "inbound_type" varchar(255) COLLATE "pg_catalog"."default",
  "related_qbit_tx_id" varchar(255) COLLATE "pg_catalog"."default",
  "fee2" numeric NOT NULL DEFAULT 0,
  "close_time" timestamp(6),
  "hidden" bool NOT NULL DEFAULT false,
  "cross_chain_fee" numeric NOT NULL DEFAULT 0,
  "tags" jsonb,
  "fees" jsonb,
  "mode" varchar(32) COLLATE "pg_catalog"."default",
  "transaction_display_id" varchar(255) COLLATE "pg_catalog"."default",
  "operation_user_id" varchar(255) COLLATE "pg_catalog"."default",
  "quote_amount" numeric,
  "deal_rate" numeric,
  "balance" numeric,
  "memo" varchar(255) COLLATE "pg_catalog"."default",
  "reexamine_time" timestamptz(6),
  "usd_rate" numeric,
  "extend_field" jsonb,
  "risk_level" varchar(30) COLLATE "pg_catalog"."default",
  "fund_type" varchar(64) COLLATE "pg_catalog"."default",
  "is_operating_cost" bool,
  "fund_comment" varchar(255) COLLATE "pg_catalog"."default",
  "idempotency_key" uuid,
  "cross_chain_amount" numeric,
  CONSTRAINT "crypto_assets_transactions_copy1_pkey1" PRIMARY KEY ("id")
)
;

ALTER TABLE "public"."crypto_assets_transfers" 
  OWNER TO "qbit_admin";

COMMENT ON COLUMN "public"."crypto_assets_transfers"."id" IS '主键';

COMMENT ON COLUMN "public"."crypto_assets_transfers"."balance_id" IS '关联的balance id';

COMMENT ON COLUMN "public"."crypto_assets_transfers"."status" IS '交易状态';

COMMENT ON COLUMN "public"."crypto_assets_transfers"."create_time" IS '交易时间(和三方交易时间同步)';

COMMENT ON COLUMN "public"."crypto_assets_transfers"."update_time" IS '数据更新时间';

COMMENT ON COLUMN "public"."crypto_assets_transfers"."delete_time" IS '删除时间';

COMMENT ON COLUMN "public"."crypto_assets_transfers"."version" IS '乐观锁';

COMMENT ON COLUMN "public"."crypto_assets_transfers"."action" IS '交易类型(in/out)(转入/转出)';

COMMENT ON COLUMN "public"."crypto_assets_transfers"."address" IS '对方加密货币地址';

COMMENT ON COLUMN "public"."crypto_assets_transfers"."settlement_amount" IS '交易金额';

COMMENT ON COLUMN "public"."crypto_assets_transfers"."fee" IS '交易手续费';

COMMENT ON COLUMN "public"."crypto_assets_transfers"."trade_id" IS '关联的三方交易id';

COMMENT ON COLUMN "public"."crypto_assets_transfers"."handle_user_id" IS '最新处理人';

COMMENT ON COLUMN "public"."crypto_assets_transfers"."chain" IS '链';

COMMENT ON COLUMN "public"."crypto_assets_transfers"."currency" IS '结算币种';

COMMENT ON COLUMN "public"."crypto_assets_transfers"."reason" IS '拒绝原因';

COMMENT ON COLUMN "public"."crypto_assets_transfers"."transaction_time" IS '交易时间';

COMMENT ON COLUMN "public"."crypto_assets_transfers"."account_id" IS '关联账号';

COMMENT ON COLUMN "public"."crypto_assets_transfers"."rate" IS '汇率';

COMMENT ON COLUMN "public"."crypto_assets_transfers"."display_status" IS '交易状态';

COMMENT ON COLUMN "public"."crypto_assets_transfers"."quote_currency" IS '交易发起方币种';

COMMENT ON COLUMN "public"."crypto_assets_transfers"."sender_type" IS '发送方类型';

COMMENT ON COLUMN "public"."crypto_assets_transfers"."recipient_type" IS '接收方类型';

COMMENT ON COLUMN "public"."crypto_assets_transfers"."payee_id" IS '收款人id';

COMMENT ON COLUMN "public"."crypto_assets_transfers"."counter_party" IS '对手方';

COMMENT ON COLUMN "public"."crypto_assets_transfers"."related_qbit_tx_id" IS '退款来源的交易ID(transaction display id)';

COMMENT ON COLUMN "public"."crypto_assets_transfers"."fee2" IS '交易手续费加点';

COMMENT ON COLUMN "public"."crypto_assets_transfers"."close_time" IS '交易完成时间';

COMMENT ON COLUMN "public"."crypto_assets_transfers"."hidden" IS '对商户端隐藏(admin可以查看)';

COMMENT ON COLUMN "public"."crypto_assets_transfers"."cross_chain_fee" IS '跨链费';

COMMENT ON COLUMN "public"."crypto_assets_transfers"."tags" IS '交易标签';

COMMENT ON COLUMN "public"."crypto_assets_transfers"."fees" IS '交易手续费';

COMMENT ON COLUMN "public"."crypto_assets_transfers"."mode" IS '银行卡出金手续费类型';

COMMENT ON COLUMN "public"."crypto_assets_transfers"."transaction_display_id" IS '交易订单ID';

COMMENT ON COLUMN "public"."crypto_assets_transfers"."operation_user_id" IS '操作人ID';

COMMENT ON COLUMN "public"."crypto_assets_transfers"."idempotency_key" IS '幂等key';


CREATE TABLE "public"."openApiClientConfig" (
  "id" uuid NOT NULL,
  "remarks" varchar COLLATE "pg_catalog"."default" DEFAULT ''::character varying,
  "createTime" timestamptz(6) NOT NULL DEFAULT now(),
  "updateTime" timestamptz(6) NOT NULL DEFAULT now(),
  "deleteTime" timestamptz(6),
  "version" int4 NOT NULL,
  "clientId" uuid NOT NULL DEFAULT '00000000-0000-0000-0000-000000000000'::uuid,
  "hooksUrl" varchar COLLATE "pg_catalog"."default",
  "kybType" json NOT NULL DEFAULT '["VirtualCard"]'::json,
  "alias" varchar COLLATE "pg_catalog"."default" NOT NULL DEFAULT ''::character varying,
  "ipWhiteList" json NOT NULL DEFAULT '[]'::json,
  "cardType" json NOT NULL DEFAULT '[]'::json,
  "cardAddress" json,
  "kybFields" json NOT NULL DEFAULT '[]'::json,
  "divideHook" varchar COLLATE "pg_catalog"."default",
  "kycFields" json NOT NULL DEFAULT '[]'::json,
  "cardLimit" int4 NOT NULL DEFAULT 0,
  "isCardPrivacy" bool NOT NULL DEFAULT false,
  "maxNumber" int4 NOT NULL DEFAULT 0,
  "isGoldInput" bool NOT NULL DEFAULT false,
  "isGoldOut" bool NOT NULL DEFAULT false,
  "isSendOtpEmail" bool NOT NULL DEFAULT true,
  "sign_time" timestamptz(6),
  "min_amount" numeric(20,2),
  "online_time" timestamptz(6),
  "discount_type" varchar(255) COLLATE "pg_catalog"."default",
  "permissions" jsonb NOT NULL DEFAULT '["crypto_asset", "quantum_account", "global_account"]'::jsonb,
  "ship_address_id" uuid,
  "discount_duration" numeric,
  "discount_percent" numeric,
  "other_amount" jsonb,
  "times" numeric DEFAULT 50,
  "expire" numeric DEFAULT 300,
  "webhook_status" varchar(64) COLLATE "pg_catalog"."default" DEFAULT 'RECOVER'::character varying,
  "interval_nanos" numeric DEFAULT 60000,
  "extra_tokens" jsonb,
  "access_type" varchar(255) COLLATE "pg_catalog"."default",
  "debit_type" varchar(64) COLLATE "pg_catalog"."default" NOT NULL DEFAULT 'Online'::character varying,
  "statement_type" varchar(64) COLLATE "pg_catalog"."default" NOT NULL DEFAULT 'Realtime'::character varying,
  "authUrl" varchar COLLATE "pg_catalog"."default",
  "physical_card_bin_ids" jsonb NOT NULL DEFAULT '[]'::jsonb,
  "discount_config" jsonb,
  "emails" jsonb NOT NULL DEFAULT '[]'::jsonb,
  "authVersion" varchar(255) COLLATE "pg_catalog"."default" NOT NULL DEFAULT 'v2'::character varying,
  "minimum_volume_commitments_config" jsonb,
  "webhook_event_disable_ids" text COLLATE "pg_catalog"."default",
  "webhook_version_disable" varchar(255) COLLATE "pg_catalog"."default",
  CONSTRAINT "PK_492bfb7e01d6a4de0057f66a242" PRIMARY KEY ("id")
)
;

ALTER TABLE "public"."openApiClientConfig" 
  OWNER TO "qbit_admin";

COMMENT ON COLUMN "public"."openApiClientConfig"."remarks" IS '备注';

COMMENT ON COLUMN "public"."openApiClientConfig"."clientId" IS 'client表主键, 非client id字段';

COMMENT ON COLUMN "public"."openApiClientConfig"."hooksUrl" IS 'web hooks url';

COMMENT ON COLUMN "public"."openApiClientConfig"."kybType" IS 'kyb类型';

COMMENT ON COLUMN "public"."openApiClientConfig"."alias" IS '别名';

COMMENT ON COLUMN "public"."openApiClientConfig"."ipWhiteList" IS 'ip白名单';

COMMENT ON COLUMN "public"."openApiClientConfig"."cardType" IS '开卡类型';

COMMENT ON COLUMN "public"."openApiClientConfig"."cardAddress" IS '默认卡地址';

COMMENT ON COLUMN "public"."openApiClientConfig"."kybFields" IS 'kyb字段';

COMMENT ON COLUMN "public"."openApiClientConfig"."divideHook" IS '退税分成hook';

COMMENT ON COLUMN "public"."openApiClientConfig"."kycFields" IS 'kyc字段';

COMMENT ON COLUMN "public"."openApiClientConfig"."cardLimit" IS '卡数量上限';

COMMENT ON COLUMN "public"."openApiClientConfig"."isCardPrivacy" IS '是否可以使用卡信息私密信息接口';

COMMENT ON COLUMN "public"."openApiClientConfig"."maxNumber" IS '全球账户上限个数';

COMMENT ON COLUMN "public"."openApiClientConfig"."isGoldInput" IS '入金是否为白名单';

COMMENT ON COLUMN "public"."openApiClientConfig"."isGoldOut" IS '出金是否为白名单';

COMMENT ON COLUMN "public"."openApiClientConfig"."isSendOtpEmail" IS '是否发送otp邮件';

COMMENT ON COLUMN "public"."openApiClientConfig"."sign_time" IS '签约日期';

COMMENT ON COLUMN "public"."openApiClientConfig"."min_amount" IS '低消金额';

COMMENT ON COLUMN "public"."openApiClientConfig"."online_time" IS '上线日期';

COMMENT ON COLUMN "public"."openApiClientConfig"."discount_type" IS '低消优惠方式：[ 无：Na；前两月免费：TwoMonthFree；前三月减半：ThreeMonthHalf ]';

COMMENT ON COLUMN "public"."openApiClientConfig"."permissions" IS 'API权限';

COMMENT ON COLUMN "public"."openApiClientConfig"."ship_address_id" IS 'API客户签约的实体卡邮寄地址';

COMMENT ON COLUMN "public"."openApiClientConfig"."discount_duration" IS '减免时长';

COMMENT ON COLUMN "public"."openApiClientConfig"."discount_percent" IS '减免比例';

COMMENT ON COLUMN "public"."openApiClientConfig"."other_amount" IS '其他费用';

COMMENT ON COLUMN "public"."openApiClientConfig"."times" IS '配置时间内webhook请求第一次失败的次数';

COMMENT ON COLUMN "public"."openApiClientConfig"."expire" IS 'webhook请求第一次失败的次数的时间配置(单位秒)';

COMMENT ON COLUMN "public"."openApiClientConfig"."webhook_status" IS 'webhook状态:[SUSPEND:暂停;RECOVER:恢复]';

COMMENT ON COLUMN "public"."openApiClientConfig"."interval_nanos" IS '时间窗口间隔默认1分钟，单位为ms,所以默认为60000';

COMMENT ON COLUMN "public"."openApiClientConfig"."extra_tokens" IS '额外的链上资产';

COMMENT ON COLUMN "public"."openApiClientConfig"."access_type" IS 'api接入类型';

COMMENT ON COLUMN "public"."openApiClientConfig"."debit_type" IS '还款方式[Online:线上，Offline:线下]';

COMMENT ON COLUMN "public"."openApiClientConfig"."statement_type" IS '报价方式[Realtime:实时，Monthly:月结]';

COMMENT ON COLUMN "public"."openApiClientConfig"."authUrl" IS '自发卡openapi客户的authorization的url';

COMMENT ON COLUMN "public"."openApiClientConfig"."physical_card_bin_ids" IS '实体卡权限id';

COMMENT ON COLUMN "public"."openApiClientConfig"."discount_config" IS '减免配置';

COMMENT ON COLUMN "public"."openApiClientConfig"."authVersion" IS 'auth 版本';

COMMENT ON COLUMN "public"."openApiClientConfig"."minimum_volume_commitments_config" IS 'Mvc月度承诺fee';