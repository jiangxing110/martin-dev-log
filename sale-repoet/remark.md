-- 作业元信息：
--   作业类型：DDL建表/视图脚本
--   运行方式：非运行作业
--   运行参数：无
--   源库变更响应：不涉及源库变更同步；用于创建 ADBPG 目标表、分区、索引或视图。
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
);


COMMENT ON TABLE "dwm"."dwm_finance_channel_cost_p" IS '金融渠道成本归因明细表，承载量子卡、全球账户、加密账户、收单账户的金融渠道成本';
COMMENT ON COLUMN "dwm"."dwm_finance_channel_cost_p"."id" IS '主键: 日期+账户+产品线+provider+cost_type+source_month+销售+AM业务指纹';
COMMENT ON COLUMN "dwm"."dwm_finance_channel_cost_p"."report_date" IS '成本归属日期-分区键；月度成本按规则展开到当月每日，交易/KYC类成本按业务发生日归属';
COMMENT ON COLUMN "dwm"."dwm_finance_channel_cost_p"."account_id" IS '账户ID';
COMMENT ON COLUMN "dwm"."dwm_finance_channel_cost_p"."account_type" IS '账户类型，来源 dim_account.account_type';
COMMENT ON COLUMN "dwm"."dwm_finance_channel_cost_p"."account_category" IS '账户分类，来源 dim_account.type';
COMMENT ON COLUMN "dwm"."dwm_finance_channel_cost_p"."system_type" IS '系统类型，来源 dim_account.system_type';
COMMENT ON COLUMN "dwm"."dwm_finance_channel_cost_p"."sale_id" IS '销售ID';
COMMENT ON COLUMN "dwm"."dwm_finance_channel_cost_p"."am_id" IS 'AM ID';
COMMENT ON COLUMN "dwm"."dwm_finance_channel_cost_p"."product_line" IS '产品线，如QUANTUM_CARD/GLOBAL_ACCOUNT/CRYPTO_ASSET/ACQUIRING';
COMMENT ON COLUMN "dwm"."dwm_finance_channel_cost_p"."provider" IS '金融渠道方，如BPC/Sumsub/IDEMIA/HZ_BANK/BZ/CL/TZ-wire/TH/Cregis/Safeheron/BS/OD/WP';
COMMENT ON COLUMN "dwm"."dwm_finance_channel_cost_p"."cost_type" IS '成本类型，如ACTIVE_CARD_COST/KYC_FEE/CARD_PRODUCTION_FEE/CONSUME_BANK_FEE/FIXED_FEE/BANK_FEE';
COMMENT ON COLUMN "dwm"."dwm_finance_channel_cost_p"."source_month" IS '来源账单月份，取当月第一天';
COMMENT ON COLUMN "dwm"."dwm_finance_channel_cost_p"."source_tag" IS 'bi_month_tag.tag，如CHANNEL_COST/CARD_CUSTOMIZATION_FEE/OTHER';
COMMENT ON COLUMN "dwm"."dwm_finance_channel_cost_p"."source_amount" IS 'bi_month_tag当月录入总金额';
COMMENT ON COLUMN "dwm"."dwm_finance_channel_cost_p"."month_day_count" IS '当月天数；月度成本按天均摊时参与分摊，事件类成本可为0';
COMMENT ON COLUMN "dwm"."dwm_finance_channel_cost_p"."basis_count" IS '当前客户分摊数量；客户数、KYC次数、实体卡数等';
COMMENT ON COLUMN "dwm"."dwm_finance_channel_cost_p"."month_basis_count" IS '当月总分摊数量';
COMMENT ON COLUMN "dwm"."dwm_finance_channel_cost_p"."basis_amount" IS '当前客户当天分摊金额权重；净消费量等';
COMMENT ON COLUMN "dwm"."dwm_finance_channel_cost_p"."month_basis_amount" IS '当月总分摊金额权重';
COMMENT ON COLUMN "dwm"."dwm_finance_channel_cost_p"."allocation_rate" IS '最终分摊比例，如basis_count/month_basis_count/month_day_count或basis_amount/month_basis_amount';
COMMENT ON COLUMN "dwm"."dwm_finance_channel_cost_p"."cost_amount" IS '已归因到客户和日期的成本金额，source_amount * allocation_rate';
COMMENT ON COLUMN "dwm"."dwm_finance_channel_cost_p"."version" IS '乐观锁版本';
COMMENT ON COLUMN "dwm"."dwm_finance_channel_cost_p"."remarks" IS '备注';
COMMENT ON COLUMN "dwm"."dwm_finance_channel_cost_p"."create_time" IS '记录创建时间';
COMMENT ON COLUMN "dwm"."dwm_finance_channel_cost_p"."update_time" IS '记录更新时间';
COMMENT ON COLUMN "dwm"."dwm_finance_channel_cost_p"."delete_time" IS '逻辑删除时间';

关于成本:
1:全球账户成本
SELECT sum(cost_amount) FROM dwm.dwm_finance_channel_cost_p
WHERE product_line= 'GLOBAL_ACCOUNT' 
and  provider= 'CL' 
全球账户有两个渠道
'BZ' 'CL' AS provider,

2:加密资产成本
②海外销售一部加密承兑成本为： fee>0 , (original_amount * usd_rate) *  0.09%
特殊处理: 
海外销售二部加密承兑成本为： (original_amount * usd_rate) *  0.09%

3.量子卡成本
BB渠道的成本

QI渠道的成本

SL渠道的成本

--********************************************************************--
-- Author:         martinJiang
-- Created Time:   2026-07-17
-- Base Script:     dws_online_total_channel_cost_daily_v2-batch-sql.sql
-- Description:    总渠道成本 DWS 批量初始化/回刷 V3
-- 作业元信息：
--   作业类型：批处理
--   运行方式：一次性初始化/回刷或调度执行
--   运行参数：start_date, end_date
--   源库变更响应：源库变化不会自动触发本作业，需调度重跑或由上游 CDC ODS/DIM 提供最新数据。
-- Notes:
--   1. BB/QI/SL 作为量子卡卡渠道成本来源。
--   2. dwm_finance_channel_cost_p 承载所有产品线金融渠道成本。
--   3. 金融渠道成本按 product_line 分别进入 acquiring/business/quantum/crypto 成本桶。
--   4. V3 调整 QI 量子卡渠道成本口径：改用 dws_qi_card_finance_daily_v2_p。
--   5. QI v2 按 base * rate 计算成本，补齐 HK Regular/HK VIP/DCSF；返现字段不计入成本桶。
--********************************************************************--

SET 'parallelism.default' = '1';
SET 'table.dml-sync' = 'true';
SET 'restart-strategy.type' = 'fixed-delay';
SET 'restart-strategy.fixed-delay.attempts' = '3';
SET 'restart-strategy.fixed-delay.delay' = '60s';

SET 'execution.checkpointing.interval' = '10s';
SET 'execution.checkpointing.max-concurrent-checkpoints' = '1';
SET 'pipeline.operator-chaining' = 'false';
SET 'table.exec.mini-batch.enabled' = 'false';
SET 'execution.checkpointing.timeout' = '30min';

SET 'table.exec.mini-batch.enabled' = 'true';
SET 'table.exec.mini-batch.allow-latency' = '5s';
SET 'table.exec.mini-batch.size' = '5000';


CREATE TEMPORARY TABLE source_dws_bb_card_finance_daily_p (
    id                       BIGINT,
    report_date              DATE,
    account_id               STRING,
    m_dom_auth_count         INT,
    m_int_auth_count         INT,
    v_dom_auth_count         INT,
    v_int_auth_count         INT,
    m_int_decline_count      INT,
    v_int_decline_count      INT,
    dom_decline_count        INT,
    m_int_reversal_count     INT,
    v_int_reversal_count     INT,
    dom_reversal_count       INT,
    m_int_refund_count       INT,
    v_int_refund_count       INT,
    dom_refund_count         INT,
    av_m_dom_count           INT,
    av_m_int_count           INT,
    av_v_dom_count           INT,
    av_v_int_count           INT,
    m_dom_clearing_vol       DECIMAL(20, 4),
    m_int_clearing_vol       DECIMAL(20, 4),
    v_dom_clearing_vol       DECIMAL(20, 4),
    v_int_clearing_vol       DECIMAL(20, 4),
    bb_rebate_base_amt       DECIMAL(20, 4),
    bb_channel_cashback_comm DECIMAL(20, 4),
    active_card_count        INT,
    cost_fixed_fee           DECIMAL(20, 4),
    sale_id                  STRING,
    am_id                    STRING,
    delete_time              TIMESTAMP(6)
) WITH (
    'connector' = 'jdbc',
    'url' = 'jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}?stringtype=unspecified',
    'table-name' = '(SELECT id, report_date, account_id, m_dom_auth_count, m_int_auth_count, v_dom_auth_count, v_int_auth_count, m_int_decline_count, v_int_decline_count, dom_decline_count, m_int_reversal_count, v_int_reversal_count, dom_reversal_count, m_int_refund_count, v_int_refund_count, dom_refund_count, av_m_dom_count, av_m_int_count, av_v_dom_count, av_v_int_count, m_dom_clearing_vol, m_int_clearing_vol, v_dom_clearing_vol, v_int_clearing_vol, bb_rebate_base_amt, bb_channel_cashback_comm, active_card_count, cost_fixed_fee, sale_id, am_id, delete_time FROM dws.dws_bb_card_finance_daily_p WHERE report_date >= CAST(''${start_date}'' AS date) AND report_date < CAST(''${end_date}'' AS date)) AS dws_bb_card_finance_daily_p_f',
    'username' = '${secret_values.ADB_PG_USERNAME}',
    'password' = '${secret_values.ADB_PG_PASSWORD}',
    'driver' = 'org.postgresql.Driver',
    'scan.fetch-size' = '20000',
    'scan.auto-commit' = 'false'
);

CREATE TEMPORARY TABLE source_dws_qi_card_finance_daily_v2_p (
    id                           BIGINT,
    report_date                  DATE,
    account_id                   STRING,
    sale_id                      STRING,
    am_id                        STRING,
    cost_reimbursement_base_amt  DECIMAL(20, 4),
    cost_service_base_amt        DECIMAL(20, 4),
    cost_acs_regular_base_amt    DECIMAL(20, 4),
    cost_acs_vip_base_amt        DECIMAL(20, 4),
    cost_vrm_base_amt            DECIMAL(20, 4),
    cost_hk_regular_base_amt     DECIMAL(20, 4),
    cost_hk_vip_base_amt         DECIMAL(20, 4),
    cost_dcsf_base_amt           DECIMAL(20, 4),
    cost_reimbursement_rate      DECIMAL(20, 8),
    cost_service_rate            DECIMAL(20, 8),
    cost_acs_regular_rate        DECIMAL(20, 8),
    cost_acs_vip_rate            DECIMAL(20, 8),
    cost_vrm_rate                DECIMAL(20, 8),
    cost_hk_regular_rate         DECIMAL(20, 8),
    cost_hk_vip_rate             DECIMAL(20, 8),
    cost_dcsf_rate               DECIMAL(20, 8),
    cost_fixed_fee               DECIMAL(20, 4),
    delete_time                  TIMESTAMP(6)
) WITH (
    'connector' = 'jdbc',
    'url' = 'jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}?stringtype=unspecified',
    'table-name' = '(SELECT id, report_date, account_id, sale_id, am_id, cost_reimbursement_base_amt, cost_service_base_amt, cost_acs_regular_base_amt, cost_acs_vip_base_amt, cost_vrm_base_amt, cost_hk_regular_base_amt, cost_hk_vip_base_amt, cost_dcsf_base_amt, cost_reimbursement_rate, cost_service_rate, cost_acs_regular_rate, cost_acs_vip_rate, cost_vrm_rate, cost_hk_regular_rate, cost_hk_vip_rate, cost_dcsf_rate, cost_fixed_fee, delete_time FROM dws.dws_qi_card_finance_daily_v2_p WHERE report_date >= CAST(''${start_date}'' AS date) AND report_date < CAST(''${end_date}'' AS date)) AS dws_qi_card_finance_daily_v2_p_f',
    'username' = '${secret_values.ADB_PG_USERNAME}',
    'password' = '${secret_values.ADB_PG_PASSWORD}',
    'driver' = 'org.postgresql.Driver',
    'scan.fetch-size' = '20000',
    'scan.auto-commit' = 'false'
);

CREATE TEMPORARY TABLE source_dws_sl_card_finance_daily_p (
    id              BIGINT,
    report_date     DATE,
    account_id      STRING,
    sale_id         STRING,
    am_id           STRING,
    rebate_base     DECIMAL(20, 4),
    rebate_amt      DECIMAL(20, 4),
    cost_fixed_fee  DECIMAL(20, 4),
    delete_time     TIMESTAMP(6)
) WITH (
    'connector' = 'jdbc',
    'url' = 'jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}?stringtype=unspecified',
    'table-name' = '(SELECT id, report_date, account_id, sale_id, am_id, rebate_base, rebate_amt, cost_fixed_fee, delete_time FROM dws.dws_sl_card_finance_daily_p WHERE report_date >= CAST(''${start_date}'' AS date) AND report_date < CAST(''${end_date}'' AS date)) AS dws_sl_card_finance_daily_p_f',
    'username' = '${secret_values.ADB_PG_USERNAME}',
    'password' = '${secret_values.ADB_PG_PASSWORD}',
    'driver' = 'org.postgresql.Driver',
    'scan.fetch-size' = '20000',
    'scan.auto-commit' = 'false'
);

CREATE TEMPORARY TABLE source_dwm_finance_channel_cost_p (
    id               BIGINT,
    report_date      DATE,
    account_id       STRING,
    product_line      STRING,
    provider         STRING,
    cost_type        STRING,
    cost_amount      DECIMAL(20, 4),
    sale_id          STRING,
    am_id            STRING,
    delete_time      TIMESTAMP(6)
) WITH (
    'connector' = 'jdbc',
    'url' = 'jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}?stringtype=unspecified',
    'table-name' = '(SELECT id, report_date, account_id, product_line, provider, cost_type, cost_amount, sale_id, am_id, delete_time FROM dwm.dwm_finance_channel_cost_p WHERE report_date >= CAST(''${start_date}'' AS date) AND report_date < CAST(''${end_date}'' AS date)) AS dwm_finance_channel_cost_p_f',
    'username' = '${secret_values.ADB_PG_USERNAME}',
    'password' = '${secret_values.ADB_PG_PASSWORD}',
    'driver' = 'org.postgresql.Driver',
    'scan.fetch-size' = '20000',
    'scan.auto-commit' = 'false'
);

CREATE TEMPORARY VIEW v_channel_cost_source AS
SELECT
    report_date,
    account_id,
    sale_id,
    am_id,
    'QUANTUM_CARD' AS product_line,
    'BB' AS cost_source,
    CAST(
        COALESCE(m_dom_auth_count, 0) * 0.1090
      + COALESCE(m_int_auth_count, 0) * 0.4845
      + COALESCE(v_dom_auth_count, 0) * 0.0725
      + COALESCE(v_int_auth_count, 0) * 0.4700
      + COALESCE(m_int_decline_count, 0) * 0.3595
      + COALESCE(v_int_decline_count, 0) * 0.3570
      + COALESCE(dom_decline_count, 0) * 0.0890
      + COALESCE(m_int_reversal_count, 0) * 0.7190
      + COALESCE(v_int_reversal_count, 0) * 0.7140
      + COALESCE(dom_reversal_count, 0) * 0.1780
      + COALESCE(m_int_refund_count, 0) * 0.4845
      + COALESCE(v_int_refund_count, 0) * 0.4770
      + COALESCE(dom_refund_count, 0) * 0.1090
      + COALESCE(av_m_dom_count, 0) * 0.1090
      + COALESCE(av_m_int_count, 0) * 0.4845
      + COALESCE(av_v_dom_count, 0) * 0.0725
      + COALESCE(av_v_int_count, 0) * 0.4770
      + COALESCE(m_int_decline_count, 0) * 0.3595
      + COALESCE(v_int_decline_count, 0) * 0.3570
      + COALESCE(dom_decline_count, 0) * 0.0890
      + COALESCE(m_dom_clearing_vol, CAST(0 AS DECIMAL(20, 4))) * -0.0021
      + COALESCE(m_int_clearing_vol, CAST(0 AS DECIMAL(20, 4))) * -0.0111
      + COALESCE(v_dom_clearing_vol, CAST(0 AS DECIMAL(20, 4))) * -0.0016
      + COALESCE(v_int_clearing_vol, CAST(0 AS DECIMAL(20, 4))) * -0.0116
      + COALESCE(active_card_count, 0) * 0.1000
      + COALESCE(cost_fixed_fee, CAST(0 AS DECIMAL(20, 4)))
        AS DECIMAL(20, 4)
    ) AS cost_amount
FROM source_dws_bb_card_finance_daily_p
WHERE delete_time IS NULL

UNION ALL

SELECT
    report_date,
    account_id,
    sale_id,
    am_id,
    'QUANTUM_CARD' AS product_line,
    'QI' AS cost_source,
    CAST(
        COALESCE(cost_reimbursement_base_amt, CAST(0 AS DECIMAL(20, 4))) * COALESCE(cost_reimbursement_rate, CAST(0 AS DECIMAL(20, 8)))
      + COALESCE(cost_service_base_amt, CAST(0 AS DECIMAL(20, 4))) * COALESCE(cost_service_rate, CAST(0 AS DECIMAL(20, 8)))
      + COALESCE(cost_acs_regular_base_amt, CAST(0 AS DECIMAL(20, 4))) * COALESCE(cost_acs_regular_rate, CAST(0 AS DECIMAL(20, 8)))
      + COALESCE(cost_acs_vip_base_amt, CAST(0 AS DECIMAL(20, 4))) * COALESCE(cost_acs_vip_rate, CAST(0 AS DECIMAL(20, 8)))
      + COALESCE(cost_vrm_base_amt, CAST(0 AS DECIMAL(20, 4))) * COALESCE(cost_vrm_rate, CAST(0 AS DECIMAL(20, 8)))
      + COALESCE(cost_hk_regular_base_amt, CAST(0 AS DECIMAL(20, 4))) * COALESCE(cost_hk_regular_rate, CAST(0 AS DECIMAL(20, 8)))
      + COALESCE(cost_hk_vip_base_amt, CAST(0 AS DECIMAL(20, 4))) * COALESCE(cost_hk_vip_rate, CAST(0 AS DECIMAL(20, 8)))
      + COALESCE(cost_dcsf_base_amt, CAST(0 AS DECIMAL(20, 4))) * COALESCE(cost_dcsf_rate, CAST(0 AS DECIMAL(20, 8)))
      + COALESCE(cost_fixed_fee, CAST(0 AS DECIMAL(20, 4)))
        AS DECIMAL(20, 4)
    ) AS cost_amount
FROM source_dws_qi_card_finance_daily_v2_p
WHERE delete_time IS NULL

UNION ALL

SELECT
    report_date,
    account_id,
    sale_id,
    am_id,
    'QUANTUM_CARD' AS product_line,
    'SL' AS cost_source,
    CAST(COALESCE(cost_fixed_fee, CAST(0 AS DECIMAL(20, 4))) AS DECIMAL(20, 4)) AS cost_amount
FROM source_dws_sl_card_finance_daily_p
WHERE delete_time IS NULL

UNION ALL

SELECT
    report_date,
    account_id,
    sale_id,
    am_id,
    UPPER(TRIM(product_line)) AS product_line,
    CONCAT('FINANCE:', COALESCE(provider, ''), ':', COALESCE(cost_type, '')) AS cost_source,
    CAST(COALESCE(cost_amount, CAST(0 AS DECIMAL(20, 4))) AS DECIMAL(20, 4)) AS cost_amount
FROM source_dwm_finance_channel_cost_p
WHERE delete_time IS NULL;

CREATE TEMPORARY VIEW v_total_channel_cost_daily AS
SELECT
    CAST(ABS(HASH_CODE(CONCAT(DATE_FORMAT(CAST(report_date AS TIMESTAMP(6)), 'yyyyMMdd'), ':', account_id, ':', COALESCE(sale_id, ''), ':', COALESCE(am_id, '')))) AS BIGINT) AS id,
    report_date,
    account_id,
    sale_id,
    am_id,
    CAST(SUM(CASE WHEN UPPER(TRIM(product_line)) = 'ACQUIRING' THEN cost_amount ELSE CAST(0 AS DECIMAL(20, 4)) END) AS DECIMAL(20, 4)) AS acquiring_cost,
    CAST(SUM(CASE WHEN UPPER(TRIM(product_line)) = 'GLOBAL_ACCOUNT' THEN cost_amount ELSE CAST(0 AS DECIMAL(20, 4)) END) AS DECIMAL(20, 4)) AS business_cost,
    CAST(SUM(CASE WHEN UPPER(TRIM(product_line)) = 'QUANTUM_CARD' THEN cost_amount ELSE CAST(0 AS DECIMAL(20, 4)) END) AS DECIMAL(20, 4)) AS quantum_cost,
    CAST(SUM(CASE WHEN UPPER(TRIM(product_line)) = 'CRYPTO_ASSET' THEN cost_amount ELSE CAST(0 AS DECIMAL(20, 4)) END) AS DECIMAL(20, 4)) AS crypto_cost,
    CAST(SUM(cost_amount) AS DECIMAL(20, 4)) AS total_channel_cost,
    1 AS version,
    CAST(NULL AS STRING) AS remarks,
    CAST(CURRENT_TIMESTAMP AS TIMESTAMP(6)) AS create_time,
    CAST(CURRENT_TIMESTAMP AS TIMESTAMP(6)) AS update_time,
    CAST(NULL AS TIMESTAMP(6)) AS delete_time
FROM v_channel_cost_source
GROUP BY report_date, account_id, sale_id, am_id;

CREATE TEMPORARY TABLE sink_dws_total_channel_cost_daily_v2_p (
    id                            BIGINT,
    report_date                   DATE,
    account_id                    STRING,
    sale_id                       STRING,
    am_id                         STRING,
    acquiring_cost                DECIMAL(20, 4),
    business_cost                 DECIMAL(20, 4),
    quantum_cost                  DECIMAL(20, 4),
    crypto_cost                   DECIMAL(20, 4),
    total_channel_cost            DECIMAL(20, 4),
    version                       INT,
    remarks                       STRING,
    create_time                   TIMESTAMP(6),
    update_time                   TIMESTAMP(6),
    delete_time                   TIMESTAMP(6),
    PRIMARY KEY (id, report_date) NOT ENFORCED
) WITH (
    'connector' = 'adbpg',
    'url' = 'jdbc:postgresql://${secret_values.ADB_PG_VPC_HOSTNAME}:${secret_values.ADB_PG_VPC_PORT}/${secret_values.ADB_PG_DATABASE}',
    'tableName' = 'dws_total_channel_cost_daily_v2_p',
    'targetSchema' = 'dws',
    'userName' = '${secret_values.ADB_PG_USERNAME}',
    'password' = '${secret_values.ADB_PG_PASSWORD}',
    'writeMode' = 'upsert',
    'batchSize' = '2000'
);

INSERT INTO sink_dws_total_channel_cost_daily_v2_p
SELECT * FROM v_total_channel_cost_daily;
可以参考一下这部分队员BB QI

SL的说取 cost_fixed_fee
CREATE TABLE "dws"."dws_sl_card_finance_daily_p" (
  "id" int8 NOT NULL,
  "report_date" date NOT NULL,
  "account_id" varchar(36) COLLATE "pg_catalog"."default" NOT NULL,
  "account_type" varchar(30) COLLATE "pg_catalog"."default",
  "account_category" varchar(50) COLLATE "pg_catalog"."default",
  "system_type" varchar(64) COLLATE "pg_catalog"."default",
  "version" int4 DEFAULT 1,
  "remarks" varchar(255) COLLATE "pg_catalog"."default",
  "create_time" timestamp(6) NOT NULL DEFAULT now(),
  "update_time" timestamp(6) NOT NULL DEFAULT now(),
  "delete_time" timestamp(6),
  "sale_id" varchar(64) COLLATE "pg_catalog"."default",
  "am_id" varchar(64) COLLATE "pg_catalog"."default",
  "rebate_base" numeric(20,4) DEFAULT 0,
  "rebate_amt" numeric(20,4) DEFAULT 0,
  "cost_fixed_fee" numeric(20,4) DEFAULT 0,
  "special_fee_type" varchar(64) COLLATE "pg_catalog"."default",
  CONSTRAINT "dws_sl_daily_pkey" PRIMARY KEY ("id", "report_date")
)
PARTITION BY RANGE (
  "report_date" "pg_catalog"."date_ops"
);

然后呢 bb qi 两个渠道还有渠道给我我们的返现金
COMMENT ON COLUMN "dws"."dws_qi_card_finance_daily_v2_p"."rebate_interchange_base_amt" IS 'Interchange 返现计费基数，非港消费金额 * 0.02';
COMMENT ON COLUMN "dws"."dws_qi_card_finance_daily_v2_p"."rebate_incentive_base_amt" IS 'Incentive 返现计费基数，消费金额 * 0.0118';
COMMENT ON COLUMN "dws"."dws_qi_card_finance_daily_v2_p"."rebate_interchange_rate" IS 'Interchange 返现月度系数，来源 ods_bi_month_tag.QI_REBATE_INTERCHANGE_RATE';
COMMENT ON COLUMN "dws"."dws_qi_card_finance_daily_v2_p"."rebate_incentive_rate" IS 'Incentive 返现月度系数，来源 ods_bi_month_tag.QI_REBATE_INCENTIVE_RATE';

BB QI 的总收入是
metric_code:
main(默认这个汇总)这个收入汇总+ 渠道返现 -成本
量子卡的毛利是上面处理完再减physical_card_cost
特殊处理: 
①销售一部，销售二部实体卡制卡费毛利 ， QI卡/张 ：(实际收到的制卡费 - 4 ) * 0.15  ），其余部门毛利不算实体卡）
physical_card_cost
还有一个特殊的
SELECT sum(cost_amount) FROM dwm.dwm_finance_channel_cost_p
WHERE 1=1
and provider= 'BPC' 这个也是量子卡qi的成本


如果收入-成本（最后算出来月）<0 的那就=0 不能按负数计算


我想你每一个产品线都写一个总结的成本计算的
crypto_acceptance_cost
注意渠道返现金