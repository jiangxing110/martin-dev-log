CREATE TABLE "dws"."dws_sales_revenue_monthly" (
  "root_account_id" varchar(64) COLLATE "pg_catalog"."default" NOT NULL,
  "report_date" date NOT NULL,
  "settlement_month" date NOT NULL,
  "product" varchar(64) COLLATE "pg_catalog"."default" NOT NULL,
  "metric_code" varchar(50) COLLATE "pg_catalog"."default" NOT NULL,
  "provider" varchar(255) COLLATE "pg_catalog"."default" NOT NULL,
  "sale_id" varchar(64) COLLATE "pg_catalog"."default",
  "sale_department" varchar(100) COLLATE "pg_catalog"."default",
  "operation_manager_id" varchar(64) COLLATE "pg_catalog"."default",
  "am_id" varchar(64) COLLATE "pg_catalog"."default",
  "income_value" numeric(20,3) NOT NULL,
  "real_income_value" numeric(20,3),
  "loaded_at" timestamp(6) NOT NULL,
  "version" int4 NOT NULL DEFAULT 1,
  "remarks" varchar(2000) COLLATE "pg_catalog"."default",
  "create_time" timestamp(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "update_time" timestamp(6) NOT NULL DEFAULT CURRENT_TIMESTAMP,
  "delete_time" timestamp(6),
  CONSTRAINT "dws_sales_revenue_monthly_pkey" PRIMARY KEY (
    "root_account_id",
    "report_date",
    "settlement_month",
    "product",
    "metric_code",
    "provider"
  )
)
PARTITION BY RANGE (
  "report_date" "pg_catalog"."date_ops"
);

CREATE TABLE "dws"."dws_sales_revenue_monthly_2026" PARTITION OF "dws"."dws_sales_revenue_monthly"
FOR VALUES FROM ('2026-01-01') TO ('2027-01-01');

COMMENT ON TABLE "dws"."dws_sales_revenue_monthly" IS '销售收入月度汇总表-按年分区';

COMMENT ON COLUMN "dws"."dws_sales_revenue_monthly"."root_account_id" IS '根账户ID';
COMMENT ON COLUMN "dws"."dws_sales_revenue_monthly"."report_date" IS '报表日期-分区键';
COMMENT ON COLUMN "dws"."dws_sales_revenue_monthly"."settlement_month" IS '结算月份';
COMMENT ON COLUMN "dws"."dws_sales_revenue_monthly"."product" IS '产品';
COMMENT ON COLUMN "dws"."dws_sales_revenue_monthly"."metric_code" IS '指标编码';
COMMENT ON COLUMN "dws"."dws_sales_revenue_monthly"."provider" IS '服务商';
COMMENT ON COLUMN "dws"."dws_sales_revenue_monthly"."sale_id" IS '销售ID';
COMMENT ON COLUMN "dws"."dws_sales_revenue_monthly"."sale_department" IS '销售部门';
COMMENT ON COLUMN "dws"."dws_sales_revenue_monthly"."operation_manager_id" IS '运营经理ID';
COMMENT ON COLUMN "dws"."dws_sales_revenue_monthly"."am_id" IS '客户经理ID';
COMMENT ON COLUMN "dws"."dws_sales_revenue_monthly"."income_value" IS '收入金额';
COMMENT ON COLUMN "dws"."dws_sales_revenue_monthly"."real_income_value" IS '实际收入金额';
COMMENT ON COLUMN "dws"."dws_sales_revenue_monthly"."loaded_at" IS '数据加载时间';
COMMENT ON COLUMN "dws"."dws_sales_revenue_monthly"."version" IS '版本号';
COMMENT ON COLUMN "dws"."dws_sales_revenue_monthly"."remarks" IS '备注';
COMMENT ON COLUMN "dws"."dws_sales_revenue_monthly"."create_time" IS '记录创建时间';
COMMENT ON COLUMN "dws"."dws_sales_revenue_monthly"."update_time" IS '记录更新时间';
COMMENT ON COLUMN "dws"."dws_sales_revenue_monthly"."delete_time" IS '逻辑删除时间';


product:
crypto（加密资产）
treasury（理财）
qbit_card（量子卡）
group_account （全球账户）
open_api（API）

provider:
qbit_card: BB QI PC SL BZ
group_account:BZ CL

metric_code:
main(默认这个汇总)

open_api:
month_receivable
month_revenue

qbit_card:
physical_card_cost

crypto:
assets_acceptance_fee_gt_zero
assets_acceptance_fee_eq_zero


上面的收入表 dws_sales_revenue_monthly
成本表
1.金融渠道成本记录 全球账户
CREATE TABLE "dwm"."dwm_finance_channel_cost_p" (
  "id" int8 NOT NULL,
  "report_date" date NOT NULL,
  "account_id" varchar(36) COLLATE "pg_catalog"."default" NOT NULL,
  "account_type" varchar(30) COLLATE "pg_catalog"."default",
  "account_category" varchar(50) COLLATE "pg_catalog"."default",
  "system_type" varchar(64) COLLATE "pg_catalog"."default",
  "sale_id" varchar(64) COLLATE "pg_catalog"."default",
  "am_id" varchar(64) COLLATE "pg_catalog"."default",
  "product_line" varchar(50) COLLATE "pg_catalog"."default" NOT NULL,
  "provider" varchar(50) COLLATE "pg_catalog"."default" NOT NULL,
  "cost_type" varchar(80) COLLATE "pg_catalog"."default" NOT NULL,
  "source_month" date NOT NULL,
  "source_tag" varchar(80) COLLATE "pg_catalog"."default" NOT NULL,
  "source_amount" numeric(20,4) DEFAULT 0,
  "month_day_count" int4 DEFAULT 0,
  "basis_count" numeric(20,4) DEFAULT 0,
  "month_basis_count" numeric(20,4) DEFAULT 0,
  "basis_amount" numeric(20,4) DEFAULT 0,
  "month_basis_amount" numeric(20,4) DEFAULT 0,
  "allocation_rate" numeric(20,10) DEFAULT 0,
  "cost_amount" numeric(20,4) DEFAULT 0,
  "version" int4 DEFAULT 1,
  "remarks" varchar(255) COLLATE "pg_catalog"."default",
  "create_time" timestamp(6) NOT NULL DEFAULT now(),
  "update_time" timestamp(6) NOT NULL DEFAULT now(),
  "delete_time" timestamp(6),
  CONSTRAINT "dwm_finance_channel_cost_pkey" PRIMARY KEY ("id", "report_date")
)
PARTITION BY RANGE (
  "report_date" "pg_catalog"."date_ops"
)

'GLOBAL_ACCOUNT' AS product_line,
'BZ|CL' AS provider,

成本加密
crypto 
assets_acceptance_fee_gt_zero*0.09%
assets_acceptance_fee_eq_zero*0.09%

量子卡成本
/Users/martinjiang/VsCodeProjects/martin-dev-log/bi-cost/flink/total_cost/dws_online_total_channel_cost_daily_v3-batch-sql.sql
BB QI

但是注意 dwm_finance_channel_cost_p 和 dws_sales_revenue_monthly都是精确到最底层account的 我们现在的维度要到root_account_id

SELECT aar.root_id,qi.account_id FROM dws_qi_card_finance_daily_v2_p as qi LEFT JOIN api_account_relation as aar ON aar.account_id=qi.account_id 这个表qi 里的数据有可能在aar 里有数据那就要 返回aar.root_id 不然就是qi.account_id


这些有效收入我们
只是 real_income_value 是 （incom -客户返现的） 还需要加渠道返现金（量子卡部分）才是最后到 有效收入
bb
COMMENT ON COLUMN "dws"."dws_bb_card_finance_daily_v2_p"."cashback_income" IS 'bb_rebate_base_amt * cashback_rate';
qi
      + COALESCE(cost_hk_regular_base_amt, CAST(0 AS DECIMAL(20, 4))) * COALESCE(cost_hk_regular_rate, CAST(0 AS DECIMAL(20, 8)))
      + COALESCE(cost_hk_vip_base_amt, CAST(0 AS DECIMAL(20, 4))) * COALESCE(cost_hk_vip_rate, CAST(0 AS DECIMAL(20, 8)))
参考 /Users/martinjiang/VsCodeProjects/martin-dev-log/bi-cost/flink/total_cost/dws_online_total_channel_cost_daily_v3-batch-sql.sql


SELECT product_line,provider FROM dwm_finance_channel_cost_p
GROUP BY product_line,provider 
QUANTUM_CARD	BPC qi 的成本还要加这个

然后部门表
SELECT * FROM system_department WHERE delete_time  is null and department_type='1'
2077248232127864834	销售四部
1740320716902932481	大客户管理部
1851130772357509121	海外业务销售部 - 2
2066369412858433538	销售三部
1740319905791647746	销售一部
1740319923059597313	销售二部
1760576792068489218	创新业务部
1762301052057112578	其他
1740320675756810242	海外业务销售部 - 1
如果要判断的那就是强行判断了

 SELECT sur.user_id
 FROM system_user_role sur
<if test="departmentId != null">
  INNER JOIN system_user_department sud ON sud.user_id=sur.user_id
</if>
WHERE sur.role_id=#{roleId} AND sur.delete_time IS NULL
<if test="departmentId != null">
  AND sud.department_id=#{departmentId} AND sud.delete_time IS NULL
</if>

然后
--********************************************************************--
-- Author:         martinJiang
-- Created Time:   2026-07-28
-- Description:    客户分析维表 dim_account_analysis
-- 作业元信息：
--   作业类型：DDL建表/视图脚本
--   运行方式：非运行作业
--   运行参数：无
--   源库变更响应：不涉及源库变更同步；用于创建 ADBPG 目标表和索引。
--********************************************************************--

CREATE TABLE "dim"."dim_account_analysis" (
  "account_id" varchar(64) COLLATE "pg_catalog"."default" NOT NULL,
  "verified_name" varchar(255) COLLATE "pg_catalog"."default",
  "account_category" varchar(64) COLLATE "pg_catalog"."default",
  "status" varchar(64) COLLATE "pg_catalog"."default",
  "system_type" varchar(64) COLLATE "pg_catalog"."default",
  "business_mode" varchar(128) COLLATE "pg_catalog"."default",
  "access_type" varchar(128) COLLATE "pg_catalog"."default",
  "mor_type" varchar(128) COLLATE "pg_catalog"."default",
  "mor_type_extra" text COLLATE "pg_catalog"."default",
  "account_risk_level" varchar(64) COLLATE "pg_catalog"."default",
  "card_active_time" timestamp(6),
  "global_active_time" timestamp(6),
  "crypto_active_time" timestamp(6),
  "api_active_time" timestamp(6),
  "treasury_active_time" timestamp(6),
  "create_time" timestamp(6) NOT NULL DEFAULT now(),
  "update_time" timestamp(6) NOT NULL DEFAULT now(),
  "delete_time" timestamp(6),
  CONSTRAINT "dim_account_analysis_pkey" PRIMARY KEY ("account_id")
);

ALTER TABLE "dim"."dim_account_analysis"
  OWNER TO "qbit_admin";

COMMENT ON TABLE "dim"."dim_account_analysis" IS '客户分析维表，按最上层客户沉淀基础属性、扩展属性、风险等级和业务激活时间';
COMMENT ON COLUMN "dim"."dim_account_analysis"."account_id" IS '客户ID，来源 dim_account.id';
COMMENT ON COLUMN "dim"."dim_account_analysis"."verified_name" IS '客户名称，来源 dim_account.verified_name';
COMMENT ON COLUMN "dim"."dim_account_analysis"."account_category" IS '客户类型，来源 dim_account.type';
COMMENT ON COLUMN "dim"."dim_account_analysis"."status" IS '客户状态，来源 dim_account.status';
COMMENT ON COLUMN "dim"."dim_account_analysis"."system_type" IS '客户系统类型，来源 accountExtend.systemType / dim_account.system_type';
COMMENT ON COLUMN "dim"."dim_account_analysis"."business_mode" IS '业务模式，来源 caas_open_api_extend.business_mode';
COMMENT ON COLUMN "dim"."dim_account_analysis"."access_type" IS '对接模式，来源 caas_open_api_extend.access_type';
COMMENT ON COLUMN "dim"."dim_account_analysis"."mor_type" IS 'MOR类别，来源 caas_open_api_extend.mor_type';
COMMENT ON COLUMN "dim"."dim_account_analysis"."mor_type_extra" IS 'MOR类别扩展字段，来源 caas_open_api_extend.mor_type_extra';
COMMENT ON COLUMN "dim"."dim_account_analysis"."account_risk_level" IS '客户风险等级，来源 cddRiskRating.accountRiskLevel';
COMMENT ON COLUMN "dim"."dim_account_analysis"."card_active_time" IS '客户量子卡激活时间：卡钱包入金累计首次超过5000的交易时间';
COMMENT ON COLUMN "dim"."dim_account_analysis"."global_active_time" IS '客户全球账户激活时间：transfer 最早交易时间';
COMMENT ON COLUMN "dim"."dim_account_analysis"."crypto_active_time" IS '客户加密资产激活时间：sell/Closed/hidden=false 累计USD首次超过200000的交易时间';
COMMENT ON COLUMN "dim"."dim_account_analysis"."api_active_time" IS '客户API上线时间，来源 openApiClientConfig.online_time';
COMMENT ON COLUMN "dim"."dim_account_analysis"."treasury_active_time" IS '客户粒子理财激活时间，来源 fund_orders 首次 complete purchase';
COMMENT ON COLUMN "dim"."dim_account_analysis"."create_time" IS '维表记录创建时间';
COMMENT ON COLUMN "dim"."dim_account_analysis"."update_time" IS '维表记录更新时间';
COMMENT ON COLUMN "dim"."dim_account_analysis"."delete_time" IS '逻辑删除时间';

CREATE INDEX "idx_dim_account_analysis_status_type" ON "dim"."dim_account_analysis" USING btree (
  "account_category" COLLATE "pg_catalog"."default" "pg_catalog"."text_ops" ASC NULLS LAST,
  "status" COLLATE "pg_catalog"."default" "pg_catalog"."text_ops" ASC NULLS LAST,
  "system_type" COLLATE "pg_catalog"."default" "pg_catalog"."text_ops" ASC NULLS LAST
);

CREATE INDEX "idx_dim_account_analysis_active_times" ON "dim"."dim_account_analysis" USING btree (
  "card_active_time" "pg_catalog"."timestamp_ops" ASC NULLS LAST,
  "global_active_time" "pg_catalog"."timestamp_ops" ASC NULLS LAST,
  "crypto_active_time" "pg_catalog"."timestamp_ops" ASC NULLS LAST,
  "api_active_time" "pg_catalog"."timestamp_ops" ASC NULLS LAST,
  "treasury_active_time" "pg_catalog"."timestamp_ops" ASC NULLS LAST
);
这个是记录account_id 各个业务激活时间的表
如果当前时间还没有到达激活时间的标准的话那直接取最大基数
 # Sales Commission Dashboard指标口径定义

UI页面：

[Sales dashboard](https://axss9gjoff.feishu.cn/wiki/ScWnwKt7YiNvDzkGJ2KcJpN0nkh?from=from_copylink)

|## 数据规则||
|---|---|
|数据维度|量子卡，全球账户：客户\-销售\-渠道（关于渠道描述补充在数仓文档里\)<br>其他模块： 客户\-销售|
|时间维度|月|
|运行时间|暂定每月8号运行代码数据入库，之后不再变动，确保回头看数据是不变的|

# 指标定义:

|**指标名**|**销售部门**|**计算公式**|**备注**|
|---|---|---|---|
|Real\-time processing<br>|销售一部，销售二部|量子卡收入（需要按渠道拆分，充值手续费需按consumption amount拆分到各个渠道 ，排除实体卡的邮寄费，月账单）\+全球账户收入（入金，付款，汇差）<br>|1、全球账户收入（入金，付款，汇差）\- 可以拆分渠道 @张皓然<br>2、量子卡收入 \-渠道拆分 @张皓然<br>|
||海外销售一部 ， 海外销售二部<br>|量子卡收入（需要按渠道拆分，充值手续费需按consumption amount拆分到各个渠道 ，排除实体卡的邮寄费，月账单）\+全球账户收入（入金，付款，汇差） \+加密账户收入（承兑）\+粒子理财收入<br>|1、量子卡收入 \-渠道拆分 @张皓然<br>2、全球账户收入（入金，付款，汇差）@张皓然<br>3、加密账户收入（承兑）@张皓然<br>4、粒子理财收入  @张皓然|
|Effective Revenue<br>@张皓然|销售一部，销售二部, 海外销售一部  , 海外销售二部|Real\-time processing \-  client Rebate<br>|全量（量子卡 \+ 加密账户 \+ 全球账户）<br>@张皓然|
|Gross Profit<br>@江星|销售一部，销售二部, 海外销售一部|Effective Revenue \- COGS（排除实体卡部分\)<br>（最后当月总计算出来单模块毛利为负就为0 ，量子卡模块需要按渠道拆分为负就为0， 就是单客户不影响其他客户）<br><br>无特殊处理的则与核心数据看板一致|特殊处理: <br>①销售一部，销售二部实体卡制卡费毛利 ， QI卡/张 ：\(实际收到的制卡费 \- 4 \) \* 0\.15  ），其余部门毛利不算实体卡）<br><br>②海外销售一部加密承兑成本为： fee\>0 , \(original\_amount \* usd\_rate\) \*  0\.09%|
||海外销售二部|Effective Revenue \- COGS（排除实体卡部分\)<br>（单客户算出来是多少就是多少，客户之间能互相影响）<br><br>无特殊处理的则与核心数据看板一致|特殊处理: <br>海外销售二部加密承兑成本为： \(original\_amount \* usd\_rate\) \*  0\.09%<br>|
|Regular billing \& conditional  declined fees<br>@张皓然<br>|销售一部，销售二部, 海外销售一部 , 海外销售二部<br>|所有当月账单金额\( 排除低消，KYC手续费）<br>|API客户账单\-一次性API费（应收）\+<br>API客户账单\-月度API费（应收）\+<br>API客户账单\-月结手续费（应收）<br>@张皓然<br>|
|Past due Invoice<br>@张皓然|销售一部，销售二部, 海外销售一部 , 海外销售二部<br>|历史所有月账单在当月实际收到的金额\( 排除低消，KYC手续费）<br>|手续费项同Regular billing \& conditional  declined fees ， 但需要按本月实际收到的钱来拆分@张皓然|
|Commision<br>@江星|销售一部，销售二部，海外销售一部<br>|Gross Profit \* Commision  Rate\(对应不同的活跃天数,  具体参考下图 , 如果未激活则按对应的最高一档计算\)<br>最后当月总计算出来为负就为0 ， 单客户不影响其他客户<br>|各模块对应各模块的费率 （ API客户账单\-月结手续费（应收）按量子卡的费率 ， 活跃天数也按量子卡的活跃天数计算规则 ， 其他按API费用规则）<br>|
||海外销售二部<br>|Gross Profit \* Rate\(对应直邀客户和非直邀客户\)<br>直邀客户：0\.2<br>非直邀客户：0\.1|直邀客户： 客户邀请码和销售的邀请码一致<br>非直邀客户： 客户邀请码和销售的邀请码不一致或为空等其他一切不满足一致的条件<br>（特殊处理  id=’0aa5962b\-cecd\-43d1\-974e\-ac181f1403e9‘  Aliniex UAB当销售为 'salesId' ='1ca4e51c\-b57a\-497d\-a5e4\-166d29ac2709' Rob 时，算直邀 ）|





# Commision  Rate:

适用范围: 

销售一部，销售二部 , 海外销售一部

|Product|Commission Base|0 \- 180 days|181\-365 days|366\-1095 days|活跃天数取值<br>|
|---|---|---|---|---|---|
|量子卡 \- 各类手续费，虚拟卡或实体卡卡费，卡活跃月费<br>|产品毛利|12\.00%|6\.00%|3\.60%|下个月第一天 \- 客户量子卡激活时间<br>Ep: 客户量子卡激活时间是2\.01<br>算4月的收入，就用5\.01 \- 2\.01 <br>算5月的收入，就用6\.01 \-2\.01<br>各项业务激活时间计算参考 dim\_account|
|加密账户 \- 承兑|产品毛利|12\.00%|6\.00%|3\.60%|下个月第一天 \- 客户加密激活时间|
|全球账户 \- payin, payout, fx|产品毛利|12\.00%|6\.00%|3\.60%|下个月第一天 \- 客户全球账户激活时间|
|粒子理财|产品毛利|20\.00%|6\.00%|3\.60%|下个月第一天 \- 粒子理财激活时间|
|收单|产品毛利|12\.00%|6\.00%|3\.60%|暂无销售先不管|
|ScanToPay|产品毛利|12\.00%|6\.00%|3\.60%|暂无销售先不管|
|API 费用 \- 一次性合规 \& 接入费，卡面设计费，白标系统部署费|实际收费<br>|15\.00%<br>|15\.00%|15\.00%<br>|下个月第一天 \- API上线时间<br>|
|API 费用 \- 月费（技术服务费）|实际收费|10\.00%|10\.00%|0\.00%|下个月第一天 \- API上线时间|









sales_commission_snapshot （汇总）
sales_commission_snapshot_detail（明细）
但是这个明细
本表 `source_type` 枚举：
| source_type | 页面展示建议 | 说明 |
|---|---|---|
| real_time_processing_fee | 处理费 | 实时处理费回款 |
| billing_decline_fee | 账单/拒付 | 月账单、条件拒付等回款 |
| past_due_invoice | 逾期发票 | 历史逾期发票回款 |
| api_monthly_billing | API 月账单 | API 月账单类收入；通常在次月 20 号生成，可能只进入未来发薪展示 |

本表 `product_type` 枚举：

| product_type | 页面展示建议 | 说明 |
|---|---|---|
| quantum_card | 量子卡 | 卡产品 |
| global_account | 全球账户 | 入金、付款、汇差 |
| crypto_account | 加密账户 | 承兑 |
| particle_finance | 粒子理财 | 理财产品 |
| acquiring | 收单 | 收单产品，当前可先预留 |
| scan_to_pay | ScanToPay | ScanToPay 产品，当前可先预留 |
| api | API | API 接入费、设计费、部署费、月费 |
这个确实是我可以
我记录这几个就可以了呀
| effective_revenue | decimal | 有效收入 |
| cogs | decimal | 成本 |
| gp | decimal | 毛利 |



ok 我希望更新一下/Users/martinjiang/VsCodeProjects/martin-dev-log/sale-repoet/销售佣金发薪看板开发文档.md 
我们说的 8号前后的查询逻辑 还要新的建返佣规则的逻辑
并且给一个建表的sql脚本到/Users/martinjiang/VsCodeProjects/martin-dev-log/sale-repoet （要字段都有备注）
然后我希望你可以给我 安装之前提过的文档摩擦返佣规则
department_code 要用部门ID
国内业务
1740319905791647746	销售一部
1740319923059597313	销售二部
2066369412858433538	销售三部
2077248232127864834	销售四部
存在海外 加密资产业务
1740320716902932481	大客户管理部
1740320675756810242	海外业务销售部 - 1
1851130772357509121	海外业务销售部 - 2
1762301052057112578	其他
1760576792068489218	创新业务部
但是这部分只有
特殊处理: 
海外销售二部加密承兑成本为： (original_amount * usd_rate) *  0.09%
assets_acceptance_fee_gt_zero*0.09%
assets_acceptance_fee_eq_zero*0.09% 两个相加 其他的如果现在加密 assets_acceptance_fee_gt_zero*0.09%按这个来

海外销售二部
Gross Profit * Rate(对应直邀客户和非直邀客户)
直邀客户：0.2
非直邀客户：0.1
这个特殊处理
其他的


然后
/Users/martinjiang/VsCodeProjects/martin-dev-log/bi-cost/flink/account_analysis/table-scripts/dim_account_analysis.sql关于昨天这个表 
我们缺了一个邀请码直邀和非直邀的判断
"public"."account"."referralCodeId" varchar 
SELECT * FROM account WHERE id='286d8d9b-cba7-4f6b-9d09-d5f8a314ddc2'
and "referralCodeId"='3b168ab5-4353-40e3-be55-05ae02c768ad'
SELECT * FROM "referralCode" WHERE id='3b168ab5-4353-40e3-be55-05ae02c768ad'
SELECT * FROM "user" WHERE id='cfd8b2a8-af2d-474a-9923-3a5ef0335f52'
SELECT * FROM "salesAccountRelation" 
WHERE "accountId"='286d8d9b-cba7-4f6b-9d09-d5f8a314ddc2'
就是邀请码对应的userId 是否和salesAccountRelation的salesId 一样


gp_1740319905791647746_group_account_181_365 rule_code 不要绑定部门ID
department_code 字段改名 department_id 
收单
ScanToPay
这两个先不管

end_time这个默认2099年1月1号