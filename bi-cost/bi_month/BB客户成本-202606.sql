-- =============================================================================
-- 母客户级别成本报表（完全参数化版本）
-- 每月只需修改 tmp_params 中的参数值即可
-- =============================================================================

-- ==================== 0. 创建参数临时表（每月修改此处） ====================
DROP TABLE IF EXISTS tmp_params;
CREATE TEMP TABLE tmp_params AS
SELECT 
    '2026-06-01'::timestamp AS month_start,          -- 报表月份第一天 00:00:00
    '2026-07-01'::timestamp AS month_end,            -- 报表月份下个月第一天 00:00:00
    '2026-06-01 08:00:00'::timestamp AS txn_start,   -- transaction_time 开始（带时区偏移）
    '2026-07-01 08:00:00'::timestamp AS txn_end,     -- transaction_time 结束（带时区偏移）
    '2026-05-01 00:00:00'::timestamp AS settle_start, -- settle表开始时间前延一个月
    '2026-08-01 00:00:00'::timestamp AS settle_end,   -- settle表结束时间后延一个月
    '2026-06-01'::date AS post_start,                 -- post_date-计算退款 开始时间
    '2026-07-01'::date AS post_end,                   -- post_date-计算退款 结束时间
    '2026-06'::text AS month_label,                   -- 输出月份标签
    0.021195::numeric AS cashback_rate;               -- 每月账单的Cashback 费率

-- =============================================================================
-- 1. 创建账户层级映射临时表
-- =============================================================================
DROP TABLE IF EXISTS tmp_account_master;
CREATE TEMP TABLE tmp_account_master AS
WITH RECURSIVE account_hierarchy AS (
    SELECT 
        a."id", a."displayId", a."parentAccountId",
        a."id" as "root_account_id", a."displayId" as "root_display_id", 1 as level,
        d."nickname" as "bd_nickname",
        CC."systemType",
        CC."access_type",
        DD."business_mode"
    FROM account a
    LEFT JOIN "salesAccountRelation" c ON a."id" = c."accountId" AND c."deleteTime" IS NULL
    LEFT JOIN "user" d ON c."salesId" = d."id"
    LEFT JOIN "accountExtend" CC ON a."id" = CC."accountId"
    LEFT JOIN "caas_open_api_extend" DD ON a."id" = DD."account_id"
    WHERE a."parentAccountId" = '00000000-0000-0000-0000-000000000000'
    UNION ALL
    SELECT 
        a."id", a."displayId", a."parentAccountId",
        at."root_account_id", at."root_display_id", at.level + 1,
        d."nickname",
        at."systemType",
        at."access_type",
        at."business_mode"
    FROM account a
    INNER JOIN account_hierarchy at ON a."parentAccountId" = at."id"
    LEFT JOIN "salesAccountRelation" c ON a."id" = c."accountId" AND c."deleteTime" IS NULL
    LEFT JOIN "user" d ON c."salesId" = d."id"
)
SELECT 
    "id" as account_id,
    CASE WHEN LEFT("root_display_id",6) IN ('042433','932059','989223') THEN '666245'
         ELSE LEFT("root_display_id",6) END as master_client_id
FROM account_hierarchy;

CREATE INDEX idx_tmp_account_master_id ON tmp_account_master (account_id);
CREATE INDEX idx_tmp_account_master_master ON tmp_account_master (master_client_id);

-- =============================================================================
-- 2. 创建交易基础临时表（使用参数）
-- =============================================================================
DROP TABLE IF EXISTS tmp_txn_base;
CREATE TEMP TABLE tmp_txn_base AS
SELECT 
    A."id" as txn_id,
    A."source_id",
    A."card_transaction_id"::text as card_transaction_id,
    A."account_id",
    A."country",
    A."type",
    A."transaction_time",
    A."original_completion_time",
    A."business_code_list",
    A."remarks",
    A."card_id",
    C."type" AS card_type,
    A."delete_time"
FROM "quantum_card_transaction_extend" A
INNER JOIN "qbitCard" C ON A."card_id" = C."id"
CROSS JOIN tmp_params p
WHERE A."channel_provision" = 'BLUEBANC'
  AND A."delete_time" IS NULL
  AND A."type" IN ('Consumption', 'Credit')
  AND C."type" IN ('Master', 'VISA')
  AND A."detail" NOT LIKE 'AUTO CLASS CAR RENTAL%'
  AND (
      (A."transaction_time" >= p.txn_start AND A."transaction_time" < p.txn_end)
      OR
      (A."original_completion_time" >= p.month_start AND A."original_completion_time" < p.month_end)
  );

CREATE INDEX idx_txn_base_source_id ON tmp_txn_base (source_id);
CREATE INDEX idx_txn_base_card_transaction_id ON tmp_txn_base (card_transaction_id);
CREATE INDEX idx_txn_base_account_id ON tmp_txn_base (account_id);
CREATE INDEX idx_txn_base_type ON tmp_txn_base (type);

-- =============================================================================
-- 3. 创建结算基础临时表（使用参数）
-- =============================================================================
DROP TABLE IF EXISTS tmp_settlement_base;
CREATE TEMP TABLE tmp_settlement_base AS
SELECT 
    "id" as settlement_id,
    "transactionId"::text as transaction_id,
    "qbitCardTransactionId"::text as qbit_card_transaction_id,
    "provider",
    "transactionType" as transaction_type,
    "billingAmount" as billing_amount,
    "rawData"->>'responseCode' AS response_code,
    "rawData"->>'reasonCode' AS reason_code,
    "rawData"->>'txnLocation' AS txn_location,
    ("rawData"->>'postDate')::timestamp AS post_date,
    ("rawData"->>'txnDate')::timestamp AS txn_date,
    "rawData"->>'approvalCode' AS approval_code
FROM "qbitCardSettlement"
CROSS JOIN tmp_params p
WHERE "provider" = 'BlueBancCard'
  AND "createTime" >= p.settle_start
  AND "createTime" < p.settle_end
  AND "rawData"::text NOT LIKE '%\\u0000%';

CREATE INDEX idx_settlement_transaction_id ON tmp_settlement_base (transaction_id);
CREATE INDEX idx_settlement_qbit_card_transaction_id ON tmp_settlement_base (qbit_card_transaction_id);
CREATE INDEX idx_settlement_response_code ON tmp_settlement_base (response_code);
CREATE INDEX idx_settlement_type ON tmp_settlement_base (transaction_type);

-- =============================================================================
-- 4. 排除ID临时表（固定，无需调整）
-- =============================================================================
DROP TABLE IF EXISTS tmp_excluded_settlement_ids;
CREATE TEMP TABLE tmp_excluded_settlement_ids AS
SELECT unnest(ARRAY[
    '234e26db-0e1d-424f-952b-053ab2e42d30'::uuid,
    '82ff7fa6-8035-4c7b-8c18-ace860c3dfae'::uuid,
    '711e7995-ea26-499f-a1c5-9e4faf15f31f'::uuid,
    '5e974989-8792-401f-93b6-b107e0b46e51'::uuid,
    '0af98098-eb5e-4d5b-a5ad-76c1b1c0ae72'::uuid,
    'a97006e9-2609-4e70-a165-2ae6b9f49689'::uuid,
    'ad861604-ff4f-4cd1-997e-fe613c67970e'::uuid,
    '37959ee2-880f-49ea-8d74-976a69382c90'::uuid,
    'bebf7744-ed33-46cd-8ca6-40bc43d928eb'::uuid,
    'ece578c8-e8c1-46ec-83b9-116ea049a2e8'::uuid,
    '69e04460-0cb4-4d9d-9001-2b786cfc3d7b'::uuid,
    '7fa7ea4f-40fa-4153-9ec1-426f4b2c5470'::uuid,
    'cff4d9c4-ee01-43fa-9518-62872afbbe91'::uuid,
    '160b403b-2a16-4b43-afac-a3b37916c968'::uuid,
    '0fd4e8ed-e208-44e5-b463-ece053a915f3'::uuid,
    '4a63f4ec-637e-4627-a668-5339fe64b9be'::uuid
]) AS settlement_id;--每月调整

CREATE INDEX idx_excluded_ids ON tmp_excluded_settlement_ids (settlement_id);

-- =============================================================================
-- 5. 最终汇总查询（所有日期条件均引用 tmp_params）
-- =============================================================================
WITH 
all_clients AS (
    SELECT DISTINCT master_client_id FROM tmp_account_master
),

-- 查询1：正常交易笔数
q1 AS (
    SELECT 
        AM.master_client_id,
        COUNT(DISTINCT CASE WHEN T.country IN ('US', 'USA') AND T.card_type = 'Master' THEN T.source_id END) AS master_dom_txn_count,
        COUNT(DISTINCT CASE WHEN T.country NOT IN ('US', 'USA') AND T.card_type = 'Master' THEN T.source_id END) AS master_int_txn_count,
        COUNT(DISTINCT CASE WHEN T.country IN ('US', 'USA') AND T.card_type = 'VISA' THEN T.source_id END) AS visa_dom_txn_count,
        COUNT(DISTINCT CASE WHEN T.country NOT IN ('US', 'USA') AND T.card_type = 'VISA' THEN T.source_id END) AS visa_int_txn_count
    FROM tmp_txn_base T
    INNER JOIN tmp_account_master AM ON T.account_id = AM.account_id
    LEFT JOIN tmp_settlement_base S ON T.source_id = S.transaction_id
    CROSS JOIN tmp_params p
    WHERE T.type = 'Consumption'
      AND T.business_code_list::TEXT NOT LIKE '%1010%'
      AND T.transaction_time >= p.txn_start
      AND T.transaction_time < p.txn_end
      AND (S.settlement_id IS NOT NULL OR T.remarks = '超时自动关单')
      AND S.response_code = 'APPROVE'
      AND S.transaction_type IN ('authorization.clearing', 'authorization.reversal')
      AND NOT EXISTS (SELECT 1 FROM tmp_excluded_settlement_ids E WHERE E.settlement_id = S.settlement_id)
    GROUP BY AM.master_client_id
),

-- 查询2：账户验证笔数
q2 AS (
    SELECT 
        AM.master_client_id,
        COUNT(DISTINCT CASE WHEN T.country IN ('US', 'USA') AND T.card_type = 'Master' THEN T.source_id END) AS ac_master_dom_count,
        COUNT(DISTINCT CASE WHEN T.country NOT IN ('US', 'USA') AND T.card_type = 'Master' THEN T.source_id END) AS ac_master_int_count,
        COUNT(DISTINCT CASE WHEN T.country IN ('US', 'USA') AND T.card_type = 'VISA' THEN T.source_id END) AS ac_visa_dom_count,
        COUNT(DISTINCT CASE WHEN T.country NOT IN ('US', 'USA') AND T.card_type = 'VISA' THEN T.source_id END) AS ac_visa_int_count
    FROM tmp_txn_base T
    INNER JOIN tmp_account_master AM ON T.account_id = AM.account_id
    LEFT JOIN tmp_settlement_base S ON T.source_id = S.transaction_id
    CROSS JOIN tmp_params p
    WHERE T.type = 'Consumption'
      AND T.business_code_list::TEXT LIKE '%1010%'
      AND T.transaction_time >= p.txn_start
      AND T.transaction_time < p.txn_end
      AND (S.settlement_id IS NULL 
           OR (NOT EXISTS (SELECT 1 FROM tmp_excluded_settlement_ids E WHERE E.settlement_id = S.settlement_id)
               AND (S.response_code IS NULL OR S.response_code != 'DECLINE')))
    GROUP BY AM.master_client_id
),

-- 查询3：金额成本
q3 AS (
    WITH amount_detail AS (
        SELECT 
            AM.master_client_id,
            CASE WHEN RIGHT(S.txn_location, 2) IN ('US','USA') THEN 'Domestic' ELSE 'International' END AS region,
            T.card_type,
            COALESCE(SUM(S.billing_amount), 0) AS amount
        FROM tmp_txn_base T
        INNER JOIN tmp_account_master AM ON T.account_id = AM.account_id
        LEFT JOIN tmp_settlement_base S 
            ON T.card_transaction_id = S.qbit_card_transaction_id
            AND S.provider = 'BlueBancCard'
            AND S.transaction_type = 'authorization.clearing'
            AND NOT EXISTS (SELECT 1 FROM tmp_excluded_settlement_ids E WHERE E.settlement_id = S.settlement_id)
        CROSS JOIN tmp_params p
        WHERE T.type IN ('Credit','Consumption')
          AND T.original_completion_time >= p.month_start
          AND T.original_completion_time < p.month_end
          AND S.response_code = 'APPROVE'
          AND T.card_type IN ('Master', 'VISA')
        GROUP BY AM.master_client_id, region, T.card_type
        UNION ALL
        SELECT 
            AM.master_client_id,
            CASE WHEN RIGHT(S.txn_location, 2) IN ('US','USA') THEN 'Domestic' ELSE 'International' END AS region,
            T.card_type,
            COALESCE(SUM(S.billing_amount), 0) AS amount
        FROM tmp_txn_base T
        INNER JOIN tmp_account_master AM ON T.account_id = AM.account_id
        LEFT JOIN tmp_settlement_base S 
            ON T.card_transaction_id = S.qbit_card_transaction_id
            AND S.provider = 'BlueBancCard'
            AND S.transaction_type = 'refund.clearing'
            AND NOT EXISTS (SELECT 1 FROM tmp_excluded_settlement_ids E WHERE E.settlement_id = S.settlement_id)
        CROSS JOIN tmp_params p
        WHERE T.type IN ('Credit','Consumption')
          AND T.original_completion_time >= p.month_start
          AND T.original_completion_time < p.month_end
          AND S.response_code = 'APPROVE'
          AND T.card_type IN ('Master', 'VISA')
        GROUP BY AM.master_client_id, region, T.card_type
    )
    SELECT 
        master_client_id,
        -COALESCE(SUM(CASE WHEN region = 'Domestic' AND card_type = 'Master' THEN net_amount END), 0) AS master_dom_net_amount,
        -COALESCE(SUM(CASE WHEN region = 'International' AND card_type = 'Master' THEN net_amount END), 0) AS master_int_net_amount,
        -COALESCE(SUM(CASE WHEN region = 'Domestic' AND card_type = 'VISA' THEN net_amount END), 0) AS visa_dom_net_amount,
        -COALESCE(SUM(CASE WHEN region = 'International' AND card_type = 'VISA' THEN net_amount END), 0) AS visa_int_net_amount,
        -COALESCE(SUM(CASE WHEN region = 'Domestic' AND card_type = 'Master' THEN net_amount END), 0)*0.0021 AS master_dom_vol_fee,
        -COALESCE(SUM(CASE WHEN region = 'International' AND card_type = 'Master' THEN net_amount END), 0)*0.0111 AS master_int_vol_fee,
        -COALESCE(SUM(CASE WHEN region = 'Domestic' AND card_type = 'VISA' THEN net_amount END), 0)*0.0016 AS visa_dom_vol_fee,
        -COALESCE(SUM(CASE WHEN region = 'International' AND card_type = 'VISA' THEN net_amount END), 0)*0.0116 AS visa_int_vol_fee
    FROM (
        SELECT 
            master_client_id,
            region,
            card_type,
            SUM(amount) AS net_amount
        FROM amount_detail
        GROUP BY master_client_id, region, card_type
    ) net_amount
    GROUP BY master_client_id
),

-- 查询4：Reversal笔数
q4 AS (
    SELECT 
        AM.master_client_id,
        COUNT(DISTINCT CASE WHEN T.country NOT IN ('US','USA') AND T.card_type = 'Master' THEN T.source_id END) AS master_int_reversal_count,
        COUNT(DISTINCT CASE WHEN T.country NOT IN ('US','USA') AND T.card_type = 'VISA' THEN T.source_id END) AS visa_int_reversal_count,
        COUNT(DISTINCT CASE WHEN T.country IN ('US','USA') AND T.card_type IN ('VISA','Master') THEN T.source_id END) AS dom_reversal_count
    FROM tmp_txn_base T
    INNER JOIN tmp_account_master AM ON T.account_id = AM.account_id
    INNER JOIN tmp_settlement_base S ON T.source_id = S.transaction_id
    CROSS JOIN tmp_params p
    WHERE T.type = 'Consumption'
      AND T.business_code_list::TEXT NOT LIKE '%1010%'
      AND T.transaction_time >= p.txn_start
      AND T.transaction_time < p.txn_end
      AND S.response_code = 'APPROVE'
      AND S.reason_code = 'APPROVE'
      AND S.transaction_type = 'authorization.reversal'
      AND NOT EXISTS (SELECT 1 FROM tmp_excluded_settlement_ids E WHERE E.settlement_id = S.settlement_id)
    GROUP BY AM.master_client_id
),

-- 查询5：Refund笔数
q5 AS (
    SELECT 
        AM.master_client_id,
        COUNT(DISTINCT CASE 
            WHEN RIGHT(S.txn_location, 2) NOT IN ('US','USA') AND T.card_type = 'Master' 
            THEN T.source_id 
        END) AS master_int_refund_count,
        COUNT(DISTINCT CASE 
            WHEN RIGHT(S.txn_location, 2) NOT IN ('US','USA') AND T.card_type = 'VISA' 
            THEN T.source_id 
        END) AS visa_int_refund_count,
        COUNT(DISTINCT CASE 
            WHEN RIGHT(S.txn_location, 2) IN ('US','USA') AND T.card_type IN ('VISA','Master')
            THEN T.source_id 
        END) AS dom_refund_count
    FROM tmp_txn_base T
    INNER JOIN tmp_account_master AM ON T.account_id = AM.account_id
    INNER JOIN tmp_settlement_base S ON T.card_transaction_id = S.qbit_card_transaction_id
    CROSS JOIN tmp_params p
    WHERE T.type = 'Credit'
      AND S.transaction_type = 'refund.clearing'
      AND S.post_date >= p.post_start
      AND S.post_date < p.post_end
      AND S.response_code = 'APPROVE'
      AND NOT EXISTS (SELECT 1 FROM tmp_excluded_settlement_ids E WHERE E.settlement_id = S.settlement_id)
    GROUP BY AM.master_client_id
),

-- 查询6：非验证 Decline 笔数
q6 AS (
    SELECT 
        AM.master_client_id,
        COUNT(DISTINCT CASE 
            WHEN A."Program Name" IN (
                'QBitHV513989','QBitHV512631','QBitHV537100','Qbit537100',
                'QBitHV543691','QBitHV517746','Qbit517746'
            )
            AND A."Merchant Country" != 'USA'
            AND A."Request Description" != 'Account Verification'
            THEN A."Auth Txn GUID" 
        END) AS master_int_decline_count,

        COUNT(DISTINCT CASE 
            WHEN A."Program Name" IN (
                'QBitHV428852','QBitHV486555','QBitHV428820','Qbit428852'
            )
            AND A."Merchant Country" != 'USA'
            AND A."Request Description" != 'Account Verification'
            THEN A."Auth Txn GUID" 
        END) AS visa_int_decline_count,

        COUNT(DISTINCT CASE 
            WHEN A."Merchant Country" = 'USA'
            AND A."Request Description" != 'Account Verification'
            THEN A."Auth Txn GUID" 
        END) AS dom_decline_count
    FROM "bb_card_auth_detail_2026-06" A --每月调整
    LEFT JOIN "qbitCard" C ON A."Card Proxy" = C."token"
    LEFT JOIN "account" B ON C."accountId" = B."id"
    INNER JOIN tmp_account_master AM ON B."id" = AM.account_id
    CROSS JOIN tmp_params p
    WHERE 1=1
        AND TO_TIMESTAMP(A."Trans Date / Time", 'MM/DD/YYYY HH12:MI:SS AM') >= p.month_start
        AND TO_TIMESTAMP(A."Trans Date / Time", 'MM/DD/YYYY HH12:MI:SS AM') < p.month_end
        AND A."Request Description" NOT IN (
            'Settlement Advice',
            'Card load via OCT Advice',
            'Refund Advice',
            'Refund Advice Completion',
            'E-Commerce or MOTO Advice',
            'ATM Cash Withdrawal Advice',
            'Purchase Advice'
        )
        AND A."Response Code" = 'DECLINE'
    GROUP BY AM.master_client_id
),

-- 查询7：验证 Decline 笔数
q7 AS (
    SELECT 
        AM.master_client_id,
        COUNT(DISTINCT CASE 
            WHEN A."Program Name" IN (
                'QBitHV513989','QBitHV512631','QBitHV537100','Qbit537100',
                'QBitHV543691','QBitHV517746','Qbit517746'
            )
            AND A."Merchant Country" != 'USA'
            AND A."Request Description" = 'Account Verification'
            THEN A."Auth Txn GUID" 
        END) AS ac_master_int_decline_count,

        COUNT(DISTINCT CASE 
            WHEN A."Program Name" IN (
                'QBitHV428852','QBitHV486555','QBitHV428820','Qbit428852'
            )
            AND A."Merchant Country" != 'USA'
            AND A."Request Description" = 'Account Verification'
            THEN A."Auth Txn GUID" 
        END) AS ac_visa_int_decline_count,

        COUNT(DISTINCT CASE 
            WHEN A."Merchant Country" = 'USA'
            AND A."Request Description" = 'Account Verification'
            THEN A."Auth Txn GUID" 
        END) AS ac_dom_decline_count
    FROM "bb_card_auth_detail_2026-06" A --每月调整
    LEFT JOIN "qbitCard" C ON A."Card Proxy" = C."token"
    LEFT JOIN "account" B ON C."accountId" = B."id"
    INNER JOIN tmp_account_master AM ON B."id" = AM.account_id
    CROSS JOIN tmp_params p
    WHERE 1=1
        AND TO_TIMESTAMP(A."Trans Date / Time", 'MM/DD/YYYY HH12:MI:SS AM') >= p.month_start
        AND TO_TIMESTAMP(A."Trans Date / Time", 'MM/DD/YYYY HH12:MI:SS AM') < p.month_end
        AND A."Request Description" NOT IN (
            'Settlement Advice',
            'Card load via OCT Advice',
            'Refund Advice',
            'Refund Advice Completion',
            'E-Commerce or MOTO Advice',
            'ATM Cash Withdrawal Advice',
            'Purchase Advice'
        )
        AND A."Response Code" = 'DECLINE'
    GROUP BY AM.master_client_id
),

-- 查询8：Active Card Account Fee
q8 AS (
    SELECT 
        AM.master_client_id,
        COUNT(DISTINCT A."Card Proxy") * 0.1 AS active_card_account_fee
    FROM "bb_card_auth_detail_2026-06" A--每月调整
    LEFT JOIN "qbitCard" C ON A."Card Proxy" = C."token"
    LEFT JOIN "account" B ON C."accountId" = B."id"
    INNER JOIN tmp_account_master AM ON B."id" = AM.account_id
    CROSS JOIN tmp_params p
    WHERE TO_TIMESTAMP(A."Trans Date / Time", 'MM/DD/YYYY HH12:MI:SS AM') >= p.month_start
      AND TO_TIMESTAMP(A."Trans Date / Time", 'MM/DD/YYYY HH12:MI:SS AM') < p.month_end
    GROUP BY AM.master_client_id
),

-- 合并所有成本数据
merged AS (
    SELECT 
        COALESCE(q1.master_client_id, q2.master_client_id, q3.master_client_id, q4.master_client_id, q5.master_client_id, q6.master_client_id, q7.master_client_id, q8.master_client_id) AS master_client_id,
        -- 笔数
        COALESCE(q1.master_dom_txn_count,0) AS master_dom_txn_count,
        COALESCE(q1.master_int_txn_count,0) AS master_int_txn_count,
        COALESCE(q1.visa_dom_txn_count,0) AS visa_dom_txn_count,
        COALESCE(q1.visa_int_txn_count,0) AS visa_int_txn_count,
        COALESCE(q2.ac_master_dom_count,0) AS ac_master_dom_count,
        COALESCE(q2.ac_master_int_count,0) AS ac_master_int_count,
        COALESCE(q2.ac_visa_dom_count,0) AS ac_visa_dom_count,
        COALESCE(q2.ac_visa_int_count,0) AS ac_visa_int_count,
        COALESCE(q3.master_dom_vol_fee,0) AS master_dom_vol_fee,
        COALESCE(q3.master_int_vol_fee,0) AS master_int_vol_fee,
        COALESCE(q3.visa_dom_vol_fee,0) AS visa_dom_vol_fee,
        COALESCE(q3.visa_int_vol_fee,0) AS visa_int_vol_fee,
        COALESCE(q4.master_int_reversal_count,0) AS master_int_reversal_count,
        COALESCE(q4.visa_int_reversal_count,0) AS visa_int_reversal_count,
        COALESCE(q4.dom_reversal_count,0) AS dom_reversal_count,
        COALESCE(q5.master_int_refund_count,0) AS master_int_refund_count,
        COALESCE(q5.visa_int_refund_count,0) AS visa_int_refund_count,
        COALESCE(q5.dom_refund_count,0) AS dom_refund_count,
        -- 非验证 Decline
        COALESCE(q6.master_int_decline_count,0) AS master_int_decline_count,
        COALESCE(q6.visa_int_decline_count,0) AS visa_int_decline_count,
        COALESCE(q6.dom_decline_count,0) AS dom_decline_count,
        -- 验证 Decline
        COALESCE(q7.ac_master_int_decline_count,0) AS ac_master_int_decline_count,
        COALESCE(q7.ac_visa_int_decline_count,0) AS ac_visa_int_decline_count,
        COALESCE(q7.ac_dom_decline_count,0) AS ac_dom_decline_count,
        -- 总净金额
        COALESCE(q3.master_dom_net_amount,0) + COALESCE(q3.master_int_net_amount,0) + COALESCE(q3.visa_dom_net_amount,0) + COALESCE(q3.visa_int_net_amount,0) AS total_net_amount,

        -- 费用计算
        COALESCE(q1.master_dom_txn_count,0)*0.1090 AS master_dom_count_fee,
        COALESCE(q1.master_int_txn_count,0)*0.4845 AS master_int_count_fee,
        COALESCE(q1.visa_dom_txn_count,0)*0.0725 AS visa_dom_count_fee,
        COALESCE(q1.visa_int_txn_count,0)*0.4770 AS visa_int_count_fee,
			  COALESCE(q2.ac_master_dom_count,0)*0.1090 AS ac_master_dom_count_fee,
        COALESCE(q2.ac_master_int_count,0)*0.4845 AS ac_master_int_count_fee,
        COALESCE(q2.ac_visa_dom_count,0)*0.0725 AS ac_visa_dom_count_fee,
        COALESCE(q2.ac_visa_int_count,0)*0.4770 AS ac_visa_int_count_fee,
				
				
        COALESCE(q4.master_int_reversal_count,0)*0.7190 AS master_int_reversal_fee,
        COALESCE(q4.visa_int_reversal_count,0)*0.7140 AS visa_int_reversal_fee,
        COALESCE(q4.dom_reversal_count,0)*0.1780 AS dom_reversal_fee,
        COALESCE(q5.master_int_refund_count,0)*0.4845 AS master_int_refund_fee,
        COALESCE(q5.visa_int_refund_count,0)*0.4770 AS visa_int_refund_fee,
        COALESCE(q5.dom_refund_count,0)*0.1090 AS dom_refund_fee,
				
        COALESCE(q6.master_int_decline_count,0)* 0.3595 AS master_int_decline_fee,
        COALESCE(q6.visa_int_decline_count,0) * 0.3570 AS visa_int_decline_fee,
        COALESCE(q6.dom_decline_count,0)* 0.0890 AS dom_decline_fee,
				
				COALESCE(q7.ac_master_int_decline_count,0) * 0.3595 AS ac_master_int_decline_fee,
        COALESCE(q7.ac_visa_int_decline_count,0) * 0.3570 AS ac_visa_int_decline_fee,
        COALESCE(q7.ac_dom_decline_count,0) * 0.0890 AS ac_dom_decline_fee,
				
        COALESCE(q8.active_card_account_fee, 0) AS active_card_account_fee
    FROM q1
    FULL OUTER JOIN q2 ON q1.master_client_id = q2.master_client_id
    FULL OUTER JOIN q3 ON COALESCE(q1.master_client_id, q2.master_client_id) = q3.master_client_id
    FULL OUTER JOIN q4 ON COALESCE(q1.master_client_id, q2.master_client_id, q3.master_client_id) = q4.master_client_id
    FULL OUTER JOIN q5 ON COALESCE(q1.master_client_id, q2.master_client_id, q3.master_client_id, q4.master_client_id) = q5.master_client_id
    FULL OUTER JOIN q6 ON COALESCE(q1.master_client_id, q2.master_client_id, q3.master_client_id, q4.master_client_id, q5.master_client_id) = q6.master_client_id
    FULL OUTER JOIN q7 ON COALESCE(q1.master_client_id, q2.master_client_id, q3.master_client_id, q4.master_client_id, q5.master_client_id, q6.master_client_id) = q7.master_client_id
    FULL OUTER JOIN q8 ON COALESCE(q1.master_client_id, q2.master_client_id, q3.master_client_id, q4.master_client_id, q5.master_client_id, q6.master_client_id, q7.master_client_id) = q8.master_client_id
),

-- 获取每个母客户的一个 account_id
account_per_client AS (
    SELECT 
        tam.master_client_id,
        MIN(a."id"::text) AS account_id
    FROM tmp_account_master tam
    LEFT JOIN account a ON tam.account_id = a."id"
    GROUP BY tam.master_client_id
),

-- 获取参数中的 month_label 和 cashback_rate
params_final AS (
    SELECT month_label, cashback_rate FROM tmp_params
)

-- 最终输出
SELECT 
    ac.master_client_id AS "displayid",
    apc.account_id,
    pf.month_label AS "month",
    -- 四项笔数费用字段（非验证）
    COALESCE(m.master_dom_count_fee,0) AS "Mastercard Domestic Count Fee",
    COALESCE(m.master_int_count_fee,0) AS "Mastercard International Count Fee",
    COALESCE(m.visa_dom_count_fee,0) AS "VISA Domestic Count Fee",
    COALESCE(m.visa_int_count_fee,0) AS "VISA International Count Fee",
    -- ⭐ 新增：四项笔数费用字段（验证 AC）
    COALESCE(m.ac_master_dom_count_fee,0) AS "AC Mastercard Domestic Count Fee",
    COALESCE(m.ac_master_int_count_fee,0) AS "AC Mastercard International Count Fee",
    COALESCE(m.ac_visa_dom_count_fee,0) AS "AC VISA Domestic Count Fee",
    COALESCE(m.ac_visa_int_count_fee,0) AS "AC VISA International Count Fee",
    -- 四项金额费用字段
    COALESCE(m.master_dom_vol_fee,0) AS "Mastercard Domestic Dollar Volume Fee",
    COALESCE(m.master_int_vol_fee,0) AS "Mastercard International Dollar Volume Fee",
    COALESCE(m.visa_dom_vol_fee,0) AS "Visa Domestic Dollar Volume Fee",
    COALESCE(m.visa_int_vol_fee,0) AS "Visa International Dollar Volume Fee",
    -- 撤销费用字段
    COALESCE(m.master_int_reversal_fee,0) AS "Mastercard International Reversal Fee",
    COALESCE(m.visa_int_reversal_fee,0) AS "Visa International Reversal Fee",
    COALESCE(m.dom_reversal_fee,0) AS "Domestic Reversal Fee",
    -- 退款费用字段
    COALESCE(m.master_int_refund_fee,0) AS "Mastercard International Refund Fee",
    COALESCE(m.visa_int_refund_fee,0) AS "VISA International Refund Fee",
    COALESCE(m.dom_refund_fee,0) AS "Domestic Refund Fee",
    -- 失败费用字段（非验证 Decline）
    COALESCE(m.master_int_decline_fee,0) AS "Mastercard International Decline Fee",
    COALESCE(m.visa_int_decline_fee,0) AS "Visa International Decline Fee",
    COALESCE(m.dom_decline_fee,0) AS "Domestic Decline Fee",
    -- ⭐ 新增：失败费用字段（验证 AC Decline）
    COALESCE(m.ac_master_int_decline_fee,0) AS "AC Mastercard International Decline Fee",
    COALESCE(m.ac_visa_int_decline_fee,0) AS "AC Visa International Decline Fee",
    COALESCE(m.ac_dom_decline_fee,0) AS "AC Domestic Decline Fee",
    -- 活跃卡费成本
    COALESCE(m.active_card_account_fee, 0) AS "Active Card Account Fee",
    -- Volume Fee Cost
    CASE 
        WHEN SUM(m.total_net_amount) OVER () = 0 THEN 0
        ELSE (m.total_net_amount / SUM(m.total_net_amount) OVER ()) *
             (CASE 
                 WHEN SUM(m.total_net_amount) OVER () <= 5000000 THEN SUM(m.total_net_amount) OVER () * 0.0055
                 WHEN SUM(m.total_net_amount) OVER () <= 10000000 THEN 5000000*0.0055 + (SUM(m.total_net_amount) OVER () - 5000000)*0.0045
                 ELSE 5000000*0.0055 + 5000000*0.0045 + (SUM(m.total_net_amount) OVER () - 10000000)*0.004
              END)
    END AS "Volume Fee Cost",
    -- Cashback Income（使用参数中的费率）
    (m.total_net_amount * pf.cashback_rate) AS "Cashback Income",
    -- 非验证四项交易笔数
    COALESCE(m.master_dom_txn_count,0) AS "Mastercard Domestic Transaction Count",
    COALESCE(m.master_int_txn_count,0) AS "Mastercard International Transaction Count",
    COALESCE(m.visa_dom_txn_count,0) AS "VISA Domestic Transaction Count",
    COALESCE(m.visa_int_txn_count,0) AS "VISA International Transaction Count",
    -- 验证四项交易笔数
    COALESCE(m.ac_master_dom_count,0) AS "AC Mastercard Domestic Count",
    COALESCE(m.ac_master_int_count,0) AS "AC Mastercard International Count",
    COALESCE(m.ac_visa_dom_count,0) AS "AC VISA Domestic Count",
    COALESCE(m.ac_visa_int_count,0) AS "AC VISA International Count",
    -- Reversal/Refund 笔数
    COALESCE(m.master_int_reversal_count,0) AS "Mastercard International Reversal Count",
    COALESCE(m.visa_int_reversal_count,0) AS "Visa International Reversal Count",
    COALESCE(m.dom_reversal_count,0) AS "Domestic Reversal Count",
    COALESCE(m.master_int_refund_count,0) AS "Mastercard International Refund Count",
    COALESCE(m.visa_int_refund_count,0) AS "VISA International Refund Count",
    COALESCE(m.dom_refund_count,0) AS "Domestic Refund Count",
    -- 非验证 Decline 笔数
    COALESCE(m.master_int_decline_count,0) AS "Mastercard International Decline Count (Non-Verify)",
    COALESCE(m.visa_int_decline_count,0) AS "Visa International Decline Count (Non-Verify)",
    COALESCE(m.dom_decline_count,0) AS "Domestic Decline Count (Non-Verify)",
    -- 验证 Decline 笔数
    COALESCE(m.ac_master_int_decline_count,0) AS "AC Mastercard International Decline Count (Verify)",
    COALESCE(m.ac_visa_int_decline_count,0) AS "AC Visa International Decline Count (Verify)",
    COALESCE(m.ac_dom_decline_count,0) AS "AC Domestic Decline Count (Verify)"
FROM all_clients ac
LEFT JOIN merged m ON ac.master_client_id = m.master_client_id
LEFT JOIN account_per_client apc ON ac.master_client_id = apc.master_client_id
CROSS JOIN params_final pf
WHERE 
    -- 排除所有笔数和费用都为0的客户（包含AC字段）
    NOT (
        COALESCE(m.master_dom_txn_count,0) = 0 AND COALESCE(m.master_int_txn_count,0) = 0 AND
        COALESCE(m.visa_dom_txn_count,0) = 0 AND COALESCE(m.visa_int_txn_count,0) = 0 AND
        COALESCE(m.ac_master_dom_count,0) = 0 AND COALESCE(m.ac_master_int_count,0) = 0 AND
        COALESCE(m.ac_visa_dom_count,0) = 0 AND COALESCE(m.ac_visa_int_count,0) = 0 AND
        COALESCE(m.master_dom_vol_fee,0) = 0 AND COALESCE(m.master_int_vol_fee,0) = 0 AND
        COALESCE(m.visa_dom_vol_fee,0) = 0 AND COALESCE(m.visa_int_vol_fee,0) = 0 AND
        COALESCE(m.master_int_reversal_count,0) = 0 AND COALESCE(m.visa_int_reversal_count,0) = 0 AND
        COALESCE(m.dom_reversal_count,0) = 0 AND
        COALESCE(m.master_int_refund_count,0) = 0 AND COALESCE(m.visa_int_refund_count,0) = 0 AND
        COALESCE(m.dom_refund_count,0) = 0 AND
        COALESCE(m.master_int_decline_count,0) = 0 AND COALESCE(m.visa_int_decline_count,0) = 0 AND
        COALESCE(m.dom_decline_count,0) = 0 AND
        COALESCE(m.ac_master_int_decline_count,0) = 0 AND COALESCE(m.ac_visa_int_decline_count,0) = 0 AND
        COALESCE(m.ac_dom_decline_count,0) = 0 AND
        COALESCE(m.master_dom_count_fee,0) = 0 AND COALESCE(m.master_int_count_fee,0) = 0 AND
        COALESCE(m.visa_dom_count_fee,0) = 0 AND COALESCE(m.visa_int_count_fee,0) = 0 AND
        -- ⭐ 新增：AC费用字段也需要排除
        COALESCE(m.ac_master_dom_count_fee,0) = 0 AND COALESCE(m.ac_master_int_count_fee,0) = 0 AND
        COALESCE(m.ac_visa_dom_count_fee,0) = 0 AND COALESCE(m.ac_visa_int_count_fee,0) = 0 AND
        COALESCE(m.master_int_reversal_fee,0) = 0 AND COALESCE(m.visa_int_reversal_fee,0) = 0 AND
        COALESCE(m.dom_reversal_fee,0) = 0 AND
        COALESCE(m.master_int_refund_fee,0) = 0 AND COALESCE(m.visa_int_refund_fee,0) = 0 AND
        COALESCE(m.dom_refund_fee,0) = 0 AND
        COALESCE(m.master_int_decline_fee,0) = 0 AND COALESCE(m.visa_int_decline_fee,0) = 0 AND
        COALESCE(m.dom_decline_fee,0) = 0 AND
        -- ⭐ 新增：AC Decline费用字段也需要排除
        COALESCE(m.ac_master_int_decline_fee,0) = 0 AND COALESCE(m.ac_visa_int_decline_fee,0) = 0 AND
        COALESCE(m.ac_dom_decline_fee,0) = 0 AND
        COALESCE(m.active_card_account_fee,0) = 0 AND
        COALESCE(m.total_net_amount,0) = 0
    )
ORDER BY ac.master_client_id;