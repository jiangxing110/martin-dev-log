工作安排
1.新增量子ls渠道成本 8
3.金融渠道成本按产品线均摊到客户每天(13+8)
量子卡,全球账户,加密资产,收单 按自己的规则均摊每个客户
4.客户成本毛利总维度聚合 + 页面接口 13

1.核心指标
有效收入=总收入 - 客户返现
毛利=有效收入 - COGS（产品成本）
毛利率=毛利 / 有效收入

/Users/martinjiang/martin-dev-log/bi-cost 这个我文件夹 
acquiring文件夹是我的同事基于阿里云实时计算 Flink 版 
写的对与acquiring写的,作业运维也有sql

参考bi-model.md文件
我现在要新增sl的渠道成本
可以参考qi渠道的
然后 bb 和qi 都需要
新增 
1.cost_fixed_fee(固定渠道成本),
2.am_id,sale_id (销售amId)(INSERT INTO "public"."dws_sale_transfer_2026" (
  "id", "account_id", "sale_or_am_id", "business_type_detail", "settlement_currency", "status", "usd_amount", 
  "transaction_count", "fee", "currency", "create_date", "version", "create_time", "update_time")
SELECT 
  generate_snowflake_id(),
  tr."accountId",
  ids."sale_or_am_id",
  tr."businessTypeDetail",
  tr."settlementCurrency",
  tr."status",
  COALESCE(SUM(tr."usdAmount"), 0) AS usd_amount,
  COUNT(*) AS transaction_count,
  COALESCE(SUM(tr."fee" * tr."usdRate"), 0) AS fee,
  tr."currency",
  TO_CHAR(tr."createTime", 'YYYY-MM-DD')::DATE AS create_date,
  1 AS version,
  NOW() AS create_time,
  NOW() AS update_time
FROM "transfer" AS tr
LEFT JOIN "ods_sale_am_transaction_2026" AS osat ON tr."transactionId"::UUID = osat.transaction_id::UUID
LEFT JOIN LATERAL (SELECT unnest(ARRAY[osat."sale_id", osat."am_id"]) AS sale_or_am_id) AS ids ON TRUE
WHERE tr."deleteTime" IS NULL
  AND tr."createTime" >= CURRENT_DATE - INTERVAL '1 day' AND tr."createTime" < CURRENT_DATE
GROUP BY tr."accountId", tr."businessTypeDetail", tr."settlementCurrency", tr."status", tr."currency", TO_CHAR(tr."createTime", 'YYYY-MM-DD')::DATE, ids."sale_or_am_id"
ON CONFLICT (id) DO NOTHING; 我以前是一笔交易如果是id 一样就是一笔 不一样就是两笔 现在你是两个字段
ods_sale_am_transaction_2026 每年都是新的表
)
历史qi bb 的参考qbit-card-cost-cleaning下面的
我现在想参考
写一版阿里云实时计算 Flink 版 的
最后文档输出到
/Users/martinjiang/martin-dev-log/bi-cost/flink


就是我可能 
量子账户交易数据进来->bb
                 ->qi.    --->quantum-cost
                 ->Sl 

全球账户数据
                          
             "id" int8 NOT NULL,
  "report_date" date NOT NULL,
  "account_id" varchar(36) COLLATE "pg_catalog"."default" NOT NULL,
  "version" int4 DEFAULT 1,
  "remarks" varchar(255) COLLATE "pg_catalog"."default",
  "create_time" timestamp(6) NOT NULL DEFAULT now(),
  "update_time" timestamp(6) NOT NULL DEFAULT now(),
  "delete_time" timestamp(6),

一笔交易进来是怎么变的嘛
ods->dwm->dws  

然后ods_sl_transaction 这个表不需要 ods_sale_am_transaction_2026这个表已经记录了 每一笔交易的销售关系了

ods_sl_transaction可以不需要,输出吧
然后dwd这层是干嘛的呢我觉得ods->dwm->dws  可以只要这三个就行了啊

关联/Users/martinjiang/IdeaProjects/qbit-assets 项目
ods表qbit_card_transaction已经做了分区,现在需要根据transactionId 去确定sale_id 和am_id,我觉得
我们的dwm 表
id 沿用qbit_card_transaction的id,然后新增sale_id和am_id字段,这样就可以关联到销售了
  "report_date" 不需要了
  "account_id" varchar(36) COLLATE "pg_catalog"."default" NOT NULL,
  "version" int4 DEFAULT 1,
  "remarks" varchar(255) COLLATE "pg_catalog"."default",
  "create_time" timestamp(6) NOT NULL DEFAULT now(),
  "update_time" timestamp(6) NOT NULL DEFAULT now(),
  "delete_time" timestamp(6),
  这几个字段风格使用这样的风格 现在的dwm_sl_card_transaction_detail_p不好

然后我看bi-model.md 里面的dwm_sl_card_transaction_detail_p的其实我觉得那个是最后的dws
rebate_base(返现基数
"qbitCardSettlement"表，provider like '%Slash%'
("rawData"->>'date')::date  筛选时间
sum("billingAmount")
rebate_amt(返现金额)
获取国家"rawData"->'merchantData'->'location'->>'country'  ， 
country='US' , rebate_base * 0.02
country!='US' , rebate_base * 0.005
cost_fixed(LS固定成本)
LS卡交易手续费 ， 取当月bi_month_tag  ,  provider ='LS' ,  tag='量子卡-渠道固定成本',根据返现基数均摊
可能我们这里的dwm 得基于qbitCardSettlement来了


下面要更深层的清洗
