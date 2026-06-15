-- QI 客户毛利2026-01
-- 1. 设置会话参数
SET myapp.start_time = '2026-01-01 00:00:00';
SET myapp.end_time = '2026-02-01 00:00:00';
SET myapp.param_a = '1.0084';
SET myapp.param_b = '0.9852';
SET myapp.param_c = '1.1146';
SET myapp.param_d = '1.2239';
SET myapp.param_e = '0.9946';

-- 2. 主查询
WITH params AS (
    SELECT 
        current_setting('myapp.start_time')::timestamp AS start_time,
        current_setting('myapp.end_time')::timestamp AS end_time,
        current_setting('myapp.param_a')::numeric AS param_a,
        current_setting('myapp.param_b')::numeric AS param_b,
        current_setting('myapp.param_c')::numeric AS param_c,
        current_setting('myapp.param_d')::numeric AS param_d,
        current_setting('myapp.param_e')::numeric AS param_e
),

-- 递归CTE获取账户层级关系，找到每个账户的根母客户，目前有三层API客户关系
account_hierarchy AS (
    -- 获取所有账户及其层级信息
    WITH RECURSIVE account_tree AS (
        -- 基础情况：找出所有根母客户（一级客户）
        SELECT 
            a."id",
            a."displayId",
            a."parentAccountId",
            a."id" as "root_account_id",  -- 根账户ID
            a."displayId" as "root_display_id",  -- 根账户显示ID
            1 as level,
            d."nickname" as "bd_nickname"  -- 获取BD信息
        FROM account a
        LEFT JOIN "salesAccountRelation" c ON a."id" = c."accountId" AND c."deleteTime" IS NULL
        LEFT JOIN "user" d ON c."salesId" = d."id"
        WHERE a."parentAccountId" = '00000000-0000-0000-0000-000000000000'
        
        UNION ALL
        
        -- 递归情况：找出子客户
        SELECT 
            a."id",
            a."displayId",
            a."parentAccountId",
            at."root_account_id",  -- 继承根账户ID
            at."root_display_id",  -- 继承根账户显示ID
            at.level + 1 as level,
            d."nickname" as "bd_nickname"  -- 获取BD信息
        FROM account a
        INNER JOIN account_tree at ON a."parentAccountId" = at."id"
        LEFT JOIN "salesAccountRelation" c ON a."id" = c."accountId" AND c."deleteTime" IS NULL
        LEFT JOIN "user" d ON c."salesId" = d."id"
    )
    SELECT 
        "id" as "account_id",
        -- 修改：将指定displayid合并到666245
        CASE 
            WHEN LEFT("root_display_id", 6) IN ('042433', '932059', '989223') THEN '666245'
            ELSE LEFT("root_display_id", 6)
        END as "母客户id",
        "displayId" as "original_display_id",
        "root_display_id",
        level,
        LEFT("root_display_id", 6) as "原始母客户id",  -- 保留原始母客户id用于调试
        "bd_nickname" as "BD"  -- 保留BD信息
    FROM account_tree A
),

-- 获取每个母客户的主要BD（如果有多个账户有不同BD，取第一个非空的）
master_client_bd AS (
    SELECT DISTINCT ON ("母客户id")
        "母客户id",
        "BD"
    FROM account_hierarchy
    WHERE "BD" IS NOT NULL
    ORDER BY "母客户id", level ASC  -- 按层级排序，优先取更高级别的BD
),

-- 获取所有母客户列表（用于确保每个客户都出现在结果中）
all_master_clients AS (
    SELECT DISTINCT 
        ah."母客户id",
        COALESCE(mbd."BD", '未分配') as "BD"  -- 如果没有BD，显示为'未分配'
    FROM account_hierarchy ah
    LEFT JOIN master_client_bd mbd ON ah."母客户id" = mbd."母客户id"
),

-- 实收金额CTE（新增） - 现在account_hierarchy已经定义，可以引用了
ActualReceivedAmount AS (
    WITH receivable_summary AS (
        -- 应收金额
        SELECT 
            abs."account_id",
            COALESCE(SUM(CASE WHEN abs."type" IN ('monthlyCommitment') THEN abs."amount" ELSE 0 END), 0) AS "低消应收金额",
            COALESCE(SUM(CASE WHEN abs."type" IN ('additionalFee') THEN abs."amount" ELSE 0 END), 0) AS "月结手续费应收金额",
            COALESCE(SUM(CASE WHEN abs."type" NOT IN ('monthlyCommitment','additionalFee') THEN abs."amount" ELSE 0 END), 0) AS "其他手续费应收金额",
            COALESCE(SUM(abs."amount"), 0) AS "应收金额"
        FROM "api_client_bill_statement" abs
        WHERE abs."bill_id" IN (
            SELECT A."bill_id"
            FROM "api_client_debit_record" A
            CROSS JOIN params p
            WHERE A."create_time" >= p.start_time
                AND A."create_time" < p.end_time
        )
        AND abs."delete_time" IS NULL
        AND abs."is_sum" = true
        AND abs."type" NOT IN (
            'topUpFeeClosed',
            'cardCreationFeeClosed', 
            'settlementFeeClosed',
            'physicalCardFeeClosed',
            'authFeeClosed',
            'applePayAuthFeeClosed'
        )
        GROUP BY abs."account_id"
    ),
    received_summary AS (
        -- 实收金额
        SELECT 
            AC."id" AS account_id,
            COALESCE(SUM(A."real_amount"), 0) AS "实收金额"
        FROM "api_client_debit_record" A
        LEFT JOIN (SELECT DISTINCT A."account_id", A."id", A."type" FROM "api_client_bill" A) B ON A."bill_id" = B."id"
        LEFT JOIN "account" AC ON AC."id" = B."account_id"
        CROSS JOIN params p
        WHERE A."create_time" >= p.start_time
            AND A."create_time" < p.end_time
            AND B."type" != 'Rebate'
						AND A."delete_time" IS NULL
        GROUP BY AC."id"
    ),
    account_received AS (
        SELECT 
            COALESCE(r1."account_id", r2.account_id) AS account_id,
            -- 按比例划分实收金额（避免除以0）
            CASE 
                WHEN r1."应收金额" = 0 THEN 0
                ELSE ROUND((r1."低消应收金额" / r1."应收金额") * r2."实收金额", 2)
            END AS "低消实收金额",
            CASE 
                WHEN r1."应收金额" = 0 THEN 0
                ELSE ROUND((r1."月结手续费应收金额" / r1."应收金额") * r2."实收金额", 2)
            END AS "月结手续费实收金额",
            CASE 
                WHEN r1."应收金额" = 0 THEN 0
                ELSE ROUND((r1."其他手续费应收金额" / r1."应收金额") * r2."实收金额", 2)
            END AS "其他手续费实收金额",
            -- 总实收金额
            COALESCE(r2."实收金额", 0) AS "总实收金额"
        FROM receivable_summary r1
        FULL OUTER JOIN received_summary r2 ON r1."account_id" = r2.account_id
    )
    SELECT 
        ah."母客户id",
        SUM(COALESCE(ar."低消实收金额", 0)) AS "低消实收金额",
        SUM(COALESCE(ar."月结手续费实收金额", 0)) AS "月结手续费实收金额",
        SUM(COALESCE(ar."其他手续费实收金额", 0)) AS "其他手续费实收金额",
        SUM(COALESCE(ar."总实收金额", 0)) AS "总实收金额"
    FROM account_received ar
    LEFT JOIN account_hierarchy ah ON ah."account_id" = ar."account_id"
    WHERE ah."母客户id" IS NOT NULL
    GROUP BY ah."母客户id"
),

-- 基础交易数据，使用账户层级关系
transaction_base AS (
    SELECT 
        ah."母客户id",
        B."transactionId",
        B."businessType",
        B."status",
        B."remarks",
        D.usd_amount,
        D.channel_provision,
        D.country,
        B."specialSourceData",
        B."fee",
        B."transactionTime"
    FROM "qbitCardTransaction" B
    LEFT JOIN account_hierarchy ah ON ah."account_id" = B."accountId"
    LEFT JOIN quantum_card_transaction_extend D ON B."transactionId" = D."transaction_id"
    CROSS JOIN params p
    WHERE B."transactionTime" >= p.start_time 
        AND B."transactionTime" < p.end_time
				AND B."deleteTime" IS NULL
        AND ah."母客户id" IS NOT NULL  
),


-- 先计算每个客户的消费金额
customer_consumption AS (
    SELECT 
        "母客户id",
        SUM(CASE 
            WHEN channel_provision = 'QBIT' AND "businessType" = 'Consumption' AND "status" IN ('Closed', 'Pending') THEN usd_amount
            WHEN channel_provision = 'QBIT' AND "businessType" IN ('Reversal', 'Credit') AND "status" IN ('Closed', 'Pending') THEN -usd_amount
            ELSE 0 
        END) as "QBIT渠道净消费",
        SUM(CASE 
            WHEN "businessType" = 'Consumption' AND "status" IN ('Closed', 'Pending') THEN usd_amount
            WHEN "businessType" IN ('Reversal', 'Credit') AND "status" IN ('Closed', 'Pending') THEN -usd_amount
            ELSE 0 
        END) as "所有渠道净消费"
    FROM transaction_base
    GROUP BY "母客户id"
),

-- 计算所有客户的总消费
total_consumption AS (
    SELECT 
        SUM("QBIT渠道净消费") as "总QBIT渠道净消费",
        COUNT(*) as "总客户数"
    FROM customer_consumption
    WHERE "QBIT渠道净消费" > 0
),

-- 完整的消费统计
Consumption AS (
    SELECT 
        cc."母客户id",
        cc."QBIT渠道净消费",
        cc."所有渠道净消费",
        -- QI渠道净消费占比（该客户QI渠道净消费/该客户所有渠道净消费）
        CASE 
            WHEN cc."所有渠道净消费" > 0 
            THEN ROUND(cc."QBIT渠道净消费" * 100.0 / cc."所有渠道净消费", 2)
            ELSE 0 
        END as "QI渠道净消费占比",
        -- 客户QI渠道净消费占比（该客户QI渠道消费额/所有客户的QI渠道消费总额）
        CASE 
            WHEN cc."QBIT渠道净消费" > 0 AND tc."总QBIT渠道净消费" > 0
            THEN cc."QBIT渠道净消费" * 100.0 / tc."总QBIT渠道净消费"
            ELSE 0 
        END as "客户QI渠道净消费占比_原始"
    FROM customer_consumption cc
    CROSS JOIN total_consumption tc
),

-- 调整百分比，确保总和为100%
AdjustedConsumption AS (
    SELECT 
        c."母客户id",
        c."QBIT渠道净消费",
        c."所有渠道净消费",
        c."QI渠道净消费占比",
        -- 调整百分比：按原始比例重新分配，确保总和为100%
        CASE 
            WHEN SUM(c."客户QI渠道净消费占比_原始") OVER () = 0 THEN 0
            ELSE ROUND(
                c."客户QI渠道净消费占比_原始" * 100.0 / 
                SUM(c."客户QI渠道净消费占比_原始") OVER (),
                2
            )
        END as "客户QI渠道净消费占比"
    FROM Consumption c
),

-- 成本计算
cost1 AS (
    SELECT 
        "母客户id",
        SUM(
            CASE 
                WHEN ABS(usd_amount) < 5 THEN usd_amount * 0.00095
                WHEN ABS(usd_amount) < 10 THEN usd_amount * 0.00145
                WHEN ABS(usd_amount) < 50 THEN usd_amount * 0.0022
                WHEN ABS(usd_amount) < 250 THEN usd_amount * 0.0037
                ELSE usd_amount * 0.00445
            END * 
            CASE "businessType"
                WHEN 'Consumption' THEN 1
                WHEN 'Reversal' THEN -1
                WHEN 'Credit' THEN -1
                ELSE 0
            END
        )*(SELECT param_a FROM params) as "成本一金额"
    FROM transaction_base
    WHERE channel_provision = 'QBIT' 
        AND country NOT IN('HK', 'HKG')
        AND "status" IN ('Closed', 'Pending')
        AND "businessType" IN ('Consumption', 'Reversal', 'Credit')
    GROUP BY "母客户id"
),

cost2 AS (
    SELECT 
        "母客户id",
        SUM(
            CASE 
                WHEN usd_amount < 5 THEN 0.01
                WHEN usd_amount < 10 THEN 0.055
                WHEN usd_amount < 50 THEN 0.08
                WHEN usd_amount < 250 THEN 0.12
                ELSE 0.14
            END
        ) * (SELECT param_b FROM params) as "成本二金额"
    FROM transaction_base
    WHERE "businessType" = 'Consumption'
        AND "status" IN ('Closed', 'Pending')
        AND channel_provision = 'QBIT' 
        AND country NOT IN('HK', 'HKG')
    GROUP BY "母客户id"
),

cost3 AS (
    SELECT 
        "母客户id",
        SUM(
            CASE 
                WHEN usd_amount < 5 THEN 0.04
                WHEN usd_amount < 10 THEN 0.22
                WHEN usd_amount < 50 THEN 0.255
                WHEN usd_amount < 250 THEN 0.48
                ELSE 0.56
            END
        ) * (SELECT param_c FROM params) as "成本三金额"
    FROM transaction_base
    WHERE "businessType" = 'Consumption'
        AND channel_provision = 'QBIT'
        AND country NOT IN('HK', 'HKG')
        AND NOT (
            ("specialSourceData"->>'code')::JSONB @> '[1001]' OR
            ("specialSourceData"->>'code')::JSONB @> '[1103]' OR
            ("specialSourceData"->>'code')::JSONB @> '[1105]'
        )
        AND usd_amount IS NOT NULL
    GROUP BY "母客户id"
),

cost4 AS (
    SELECT 
        "母客户id",
        COUNT(*) * 0.07 * (SELECT param_d FROM params) as "成本四金额"
    FROM transaction_base
    WHERE "businessType" = 'Consumption'
        AND channel_provision = 'QBIT'
        AND country NOT IN('HK', 'HKG')
        AND NOT (
            ("specialSourceData"->>'code')::JSONB @> '[1001]' OR
            ("specialSourceData"->>'code')::JSONB @> '[1103]' OR
            ("specialSourceData"->>'code')::JSONB @> '[1105]'
        )
        AND usd_amount IS NOT NULL
    GROUP BY "母客户id"
),

cost5 AS (
    SELECT 
        "母客户id",
        SUM(
            CASE "businessType"
                WHEN 'Consumption' THEN usd_amount
                WHEN 'Reversal' THEN -usd_amount
                WHEN 'Credit' THEN -usd_amount
                ELSE 0
            END
        ) * 0.0135 * (SELECT param_e FROM params) as "成本五金额"
    FROM transaction_base
    WHERE channel_provision = 'QBIT'
        AND country NOT IN('HK', 'HKG')
        AND "status" IN ('Closed', 'Pending')
        AND "businessType" IN ('Consumption')
    GROUP BY "母客户id"
),
cost6 AS (
    SELECT 
        ah."母客户id",
        SUM(B."cash_back_amount") as "成本六金额"
    FROM "cash_back_bonuses" B
    LEFT JOIN account_hierarchy ah ON ah."account_id" = B."account_id"
    CROSS JOIN params p
    WHERE B."month" = TO_CHAR(p.start_time, 'YYYY-MM')
        AND B."status" = 'Closed'
        AND B."delete_time" is NULL
        AND B."project" IN ('QuantumCardQIConsumptionCashBack','QuantumCardQICreateCashBack','QuantumCardIPRAndQIConsumptionCashBack')
        AND ah."母客户id" IS NOT NULL
    GROUP BY ah."母客户id"
),

hk_transactions AS (
    SELECT *
    FROM transaction_base
    WHERE channel_provision = 'QBIT'
        AND country IN('HK', 'HKG')
        AND "status" IN ('Closed', 'Pending')
),

cost7 AS (
    SELECT 
        "母客户id",
        SUM(
            CASE 
                WHEN usd_amount < 5 THEN 0.004
                WHEN usd_amount < 50 THEN 0.018
                ELSE 0.032
            END
        ) as "成本七金额"
    FROM hk_transactions
    WHERE "businessType" = 'Consumption'
        AND usd_amount IS NOT NULL
    GROUP BY "母客户id"
),

cost8 AS (
    SELECT 
        "母客户id",
        SUM(
            CASE 
                WHEN usd_amount < 5 THEN 0.006
                WHEN usd_amount < 50 THEN 0.027
                ELSE 0.048
            END
        ) as "成本八金额"
    FROM hk_transactions
    WHERE "businessType" = 'Consumption'
        AND NOT (
            ("specialSourceData"->>'code')::JSONB @> '[1001]' OR
            ("specialSourceData"->>'code')::JSONB @> '[1103]' OR
            ("specialSourceData"->>'code')::JSONB @> '[1105]'
        )
        AND usd_amount IS NOT NULL
    GROUP BY "母客户id"
),

-- 修改：将母客户id为'666245'的客户返现成本强行设置为262393.83
combined_costs AS (
    SELECT 
        cc."母客户id",
        COALESCE(c1."成本一金额", 0) as "成本一",
        COALESCE(c2."成本二金额", 0) as "成本二",
        COALESCE(c3."成本三金额", 0) as "成本三",
        COALESCE(c4."成本四金额", 0) as "成本四",
        COALESCE(c5."成本五金额", 0) as "成本五",
        -- 关键修改：将母客户id为'666245'的客户返现成本设置为262393.83
        CASE 
            WHEN cc."母客户id" = '666245' THEN 262393.83
            ELSE COALESCE(c6."成本六金额", 0)
        END as "成本六",
        COALESCE(c7."成本七金额", 0) as "成本七",
        COALESCE(c8."成本八金额", 0) as "成本八"
    FROM customer_consumption cc
    LEFT JOIN cost1 c1 USING("母客户id")
    LEFT JOIN cost2 c2 USING("母客户id")
    LEFT JOIN cost3 c3 USING("母客户id")
    LEFT JOIN cost4 c4 USING("母客户id")
    LEFT JOIN cost5 c5 USING("母客户id")
    LEFT JOIN cost6 c6 USING("母客户id")
    LEFT JOIN cost7 c7 USING("母客户id")
    LEFT JOIN cost8 c8 USING("母客户id")
),

-- 收入计算
RechargeSummary AS (
    SELECT 
        ah."母客户id",
        SUM(A."settleAmount") AS "充值总金额",
        ROUND(SUM(COALESCE(A.fee, 0))) AS "充值费"
    FROM "qbitCardWalletTransaction" A
    LEFT JOIN account_hierarchy ah ON ah."account_id" = A."accountId"
    CROSS JOIN params p
    WHERE A."status" = 'Closed'
        AND A."businessType" IN ('Deposit','TransferInFromFinancing','TransferInFromCryptoAssets',
                                'TransferInFromIPeakoin','TransferInFromQbitGlobal',
                                'AccountDepositCNY','QbitCryptoToQbitCardWallet')
        AND A."transactionTime" >= p.start_time
        AND A."transactionTime" < p.end_time
        AND ah."母客户id" IS NOT NULL
				AND A."deleteTime" IS NULL
    GROUP BY ah."母客户id"
),

VirtualCardFee AS (
    SELECT 
        ah."母客户id",
        ROUND(SUM(COALESCE(B."senderFee", 0))) AS "虚拟开卡费"
    FROM "Transaction" B
    LEFT JOIN account_hierarchy ah ON ah."account_id" = NULLIF(B."accountId", '')::uuid
    LEFT JOIN "qbitCard" E ON E."id" = NULLIF(B."sourceId", '')::uuid
    CROSS JOIN params p
    WHERE B."type" IN ('CreateCard','QbitCardFee') 
        AND B."transactionTime" >= p.start_time 
        AND B."transactionTime" < p.end_time
        AND B."status"='Closed'
        AND E."provider" like 'Qb%'
        AND ah."母客户id" IS NOT NULL
				AND B."deleteTime" IS NULL
    GROUP BY ah."母客户id"
),

PhysicalCardFee AS (
    SELECT 
        ah."母客户id",
        ROUND(SUM(COALESCE(B."senderCost", 0))) AS "实体卡制卡费"
    FROM "Transaction" B
    LEFT JOIN account_hierarchy ah ON ah."account_id" = NULLIF(B."accountId", '')::uuid
    LEFT JOIN "qbitCard" E ON E."id" = NULLIF(B."sourceId", '')::uuid
    CROSS JOIN params p
    WHERE B.remarks = '制卡费'
        AND B."transactionTime" >= p.start_time 
        AND B."transactionTime" < p.end_time
        AND B."status"='Closed'
        AND E."provider" like 'Qb%'
				AND B."deleteTime" IS NULL
        AND ah."母客户id" IS NOT NULL
    GROUP BY ah."母客户id"
),

FXFee AS (
    SELECT 
        tb."母客户id",
        ROUND(SUM(COALESCE((tb."specialSourceData"->>'markupFee')::NUMERIC, 0))) AS "FX_Cross费用"
    FROM transaction_base tb
    WHERE tb."businessType" = 'Consumption'
        AND tb."status" IN ('Closed', 'Pending')
        AND tb.channel_provision = 'QBIT'
    GROUP BY tb."母客户id"
),

SettlementAuthFee AS (
    SELECT 
        tb."母客户id",
        ROUND(SUM(
            COALESCE(CASE WHEN tb."businessType" = 'Fee_Consumption' THEN CAST(tb."fee" AS NUMERIC) ELSE 0 END, 0) +
            COALESCE((tb."specialSourceData"->>'settleFee')::NUMERIC, 0)
        )) AS "Settlement_Auth_Fee"
    FROM transaction_base tb
    WHERE tb."businessType" IN ('Consumption','Fee_Consumption')
        AND tb."status" IN ('Closed', 'Pending')
        AND tb.channel_provision = 'QBIT'
    GROUP BY tb."母客户id"
),

OtherFee AS (
    SELECT 
        tb."母客户id",
        ROUND(SUM(
            COALESCE(CASE WHEN tb."businessType" IN ('Credit', 'Refund', 'Fee_Credit' ,'Reversal','Declined_Fee') 
                AND tb."status" IN ('Closed', 'Pending')
                THEN CAST(tb."fee" AS NUMERIC) ELSE 0 END, 0) +
            COALESCE((tb."specialSourceData"->>'applePayFee')::NUMERIC, 0) +
            COALESCE((tb."specialSourceData"->>'atmFee')::NUMERIC, 0)
        )) AS "其他费用"
    FROM transaction_base tb
    WHERE tb.channel_provision = 'QBIT'
        AND tb."status" IN ('Closed', 'Pending')
    GROUP BY tb."母客户id"
),

fee5 AS (
    SELECT 
        "母客户id",
        (SUM(
            CASE 
                WHEN "businessType" = 'Consumption' AND country NOT IN ('HK','HKG') AND "status" IN ('Closed', 'Pending') THEN usd_amount
                WHEN "businessType" IN ('Reversal', 'Credit') AND country NOT IN ('HK','HKG') AND "status" IN ('Closed', 'Pending') THEN -usd_amount
                ELSE 0 
            END
        ) * 0.02 +
        SUM(
            CASE 
                WHEN "businessType" = 'Consumption' AND "status" IN ('Closed', 'Pending') THEN usd_amount
                WHEN "businessType" IN ('Reversal', 'Credit') AND "status" IN ('Closed', 'Pending') THEN -usd_amount
                ELSE 0 
            END
        ) * 0.0118)* (SELECT param_e FROM params) as "新增收入"
    FROM transaction_base
    CROSS JOIN params p
    WHERE channel_provision = 'QBIT'
        AND "status" IN ('Closed', 'Pending')
        AND "businessType" IN ('Consumption')
    GROUP BY "母客户id"
),

-- 合并所有收入
combined_revenue AS (
    SELECT 
        COALESCE(r."母客户id", v."母客户id", p."母客户id", f."母客户id", 
                 s."母客户id", o."母客户id", f5."母客户id") as "母客户id",
        COALESCE(r."充值费", 0) as "充值费",
        COALESCE(r."充值总金额", 0) as "充值总金额",
        COALESCE(v."虚拟开卡费", 0) as "虚拟开卡费收入",
        COALESCE(p."实体卡制卡费", 0) as "实体卡制卡费收入",
        COALESCE(f."FX_Cross费用", 0) as "FX_Cross费用收入",
        COALESCE(s."Settlement_Auth_Fee", 0) as "Settlement_Auth_Fee收入",
        COALESCE(o."其他费用", 0) as "其他费用收入",
        COALESCE(f5."新增收入", 0) as "新增收入"
    FROM RechargeSummary r
    FULL OUTER JOIN VirtualCardFee v USING("母客户id")
    FULL OUTER JOIN PhysicalCardFee p USING("母客户id")
    FULL OUTER JOIN FXFee f USING("母客户id")
    FULL OUTER JOIN SettlementAuthFee s USING("母客户id")
    FULL OUTER JOIN OtherFee o USING("母客户id")
    FULL OUTER JOIN fee5 f5 USING("母客户id")
),

-- 最终汇总（修正：以 all_master_clients 为基础）
final_summary AS (
    SELECT 
        amc."母客户id",
        amc."BD",
        -- 成本
        COALESCE(c."成本一", 0) as "成本一",
        COALESCE(c."成本二", 0) as "成本二",
        COALESCE(c."成本三", 0) as "成本三",
        COALESCE(c."成本四", 0) as "成本四",
        COALESCE(c."成本五", 0) as "成本五",
        COALESCE(c."成本六", 0) as "成本六",
        COALESCE(c."成本七", 0) as "成本七",
        COALESCE(c."成本八", 0) as "成本八",
        -- 成本十：固定成本分摊（基于占比）
        28000 * COALESCE(cons."客户QI渠道净消费占比", 0) / 100 as "成本十",
        -- 收入（调整充值费收入）
        COALESCE(r."充值费", 0) * 0.7236 as "充值费收入_QI",
        COALESCE(r."充值费", 0) as "充值费收入",
        COALESCE(r."虚拟开卡费收入", 0) as "虚拟开卡费收入",
        COALESCE(r."实体卡制卡费收入", 0) as "实体卡制卡费收入",
        COALESCE(r."FX_Cross费用收入", 0) as "FX_Cross费用收入",
        COALESCE(r."Settlement_Auth_Fee收入", 0) as "Settlement_Auth_Fee收入",
        COALESCE(r."其他费用收入", 0) as "其他费用收入",
        COALESCE(r."新增收入", 0) as "新增收入",
        -- 实收金额（新增）
        COALESCE(ara."低消实收金额", 0) * 0.7236 as "低消实收金额_QI",
        COALESCE(ara."月结手续费实收金额", 0) * 0.7236 as "月结手续费实收金额_QI",
        COALESCE(ara."其他手续费实收金额", 0) * 0.7236 as "其他手续费实收金额_QI",
        COALESCE(ara."总实收金额", 0) * 0.7236 as "总实收金额_QI",
        -- 消费数据
        COALESCE(cons."QBIT渠道净消费", 0) as "QBIT渠道净消费",
        COALESCE(cons."所有渠道净消费", 0) as "所有渠道净消费",
        COALESCE(cons."QI渠道净消费占比", 0) as "QI渠道净消费占比",
        COALESCE(cons."客户QI渠道净消费占比", 0) as "客户QI渠道净消费占比"
    FROM all_master_clients amc
    LEFT JOIN AdjustedConsumption cons ON amc."母客户id" = cons."母客户id"
    LEFT JOIN combined_costs c ON amc."母客户id" = c."母客户id"
    LEFT JOIN combined_revenue r ON amc."母客户id" = r."母客户id"
    LEFT JOIN ActualReceivedAmount ara ON amc."母客户id" = ara."母客户id"
)

-- 最终输出（修正：只显示有实际数据的客户）
SELECT 
    AC."id" AS "accountid",
    f."母客户id",
    f."BD",
    -- 获取客户名称
    CASE 
        WHEN f."母客户id" = '666245' OR f."母客户id" IN ('042433', '932059', '989223')
        THEN (SELECT "verifiedName" FROM account WHERE "displayId" LIKE '666245%' 
              AND ("parentAccountId" = '00000000-0000-0000-0000-000000000000' OR "parentAccountId" IS NULL) 
              LIMIT 1)
        ELSE (SELECT "verifiedName" FROM account WHERE "displayId" LIKE f."母客户id" || '%' 
              AND ("parentAccountId" = '00000000-0000-0000-0000-000000000000' OR "parentAccountId" IS NULL) 
              LIMIT 1)
    END as "verifiedName",
    -- 消费数据
    ROUND(f."QBIT渠道净消费")::INTEGER AS "QBIT渠道净消费",
    f."QI渠道净消费占比" || '%' AS "QI渠道净消费占比",
    f."客户QI渠道净消费占比" || '%' AS "客户QI渠道净消费占比",
    -- 成本明细
    ROUND(f."成本一")::INTEGER AS "Issuer Card Service Fees",
    ROUND(f."成本二")::INTEGER AS "Issuer Authorization, Clearing and Settlement Fees",
    ROUND(f."成本三")::INTEGER AS "Issuer Authorization, Clearing and Settlement Fees_VIP", 
    ROUND(f."成本四")::INTEGER AS "Visa Risk Manager (VRM)",
    ROUND(f."成本五")::INTEGER AS "Crossborder/FX",
    -- 关键修改：这里会显示为262393.83 （强制设置的值）
    ROUND(f."成本六")::INTEGER AS "客户返现成本",
    ROUND(f."成本七")::INTEGER AS "BaseII Dom",
    ROUND(f."成本八")::INTEGER AS "VIP Dom",
    ROUND(f."成本十")::INTEGER AS "固定成本+账户验证",
    -- 总成本
    ROUND(COALESCE(f."成本一", 0) + COALESCE(f."成本二", 0) + COALESCE(f."成本三", 0) + 
          COALESCE(f."成本四", 0) + COALESCE(f."成本五", 0) + COALESCE(f."成本六", 0) + 
          COALESCE(f."成本七", 0) + COALESCE(f."成本八", 0) + COALESCE(f."成本十", 0))::INTEGER as "总成本",
    -- 收入明细
    ROUND(f."充值费收入_QI")::INTEGER AS "充值费收入_QI",
    ROUND(f."充值费收入")::INTEGER AS "充值费收入",
    ROUND(f."虚拟开卡费收入")::INTEGER AS "虚拟开卡费收入",
    ROUND(f."实体卡制卡费收入")::INTEGER AS "实体卡制卡费收入",
    ROUND(f."FX_Cross费用收入")::INTEGER AS "FX_Cross费用收入",
    ROUND(f."Settlement_Auth_Fee收入")::INTEGER AS "Settlement_Auth_Fee收入",
    ROUND(f."其他费用收入")::INTEGER AS "其他费用收入",
    ROUND(f."新增收入")::INTEGER AS "量子卡Cashback",
    -- 实收金额明细（新增）
    ROUND(f."低消实收金额_QI")::INTEGER AS "低消实收金额_QI",
    ROUND(f."月结手续费实收金额_QI")::INTEGER AS "月结手续费实收金额_QI",
    ROUND(f."其他手续费实收金额_QI")::INTEGER AS "其他手续费实收金额_QI",
    ROUND(f."总实收金额_QI")::INTEGER AS "总实收金额_QI",
    -- 总收入（包含实收金额）
    ROUND(COALESCE(f."充值费收入_QI", 0) + COALESCE(f."虚拟开卡费收入", 0) + 
          COALESCE(f."实体卡制卡费收入", 0) + COALESCE(f."FX_Cross费用收入", 0) + 
          COALESCE(f."Settlement_Auth_Fee收入", 0) + COALESCE(f."其他费用收入", 0) + 
          COALESCE(f."新增收入", 0) + COALESCE(f."总实收金额_QI", 0))::INTEGER as "总收入",

    -- 去除实体卡相关数据
    ROUND(COALESCE(f."充值费收入_QI", 0) + COALESCE(f."虚拟开卡费收入", 0) + 
          COALESCE(f."FX_Cross费用收入", 0) + COALESCE(f."Settlement_Auth_Fee收入", 0) + 
          COALESCE(f."其他费用收入", 0) + COALESCE(f."新增收入", 0) + COALESCE(f."总实收金额_QI", 0))::INTEGER as "去除实体卡收入",
    ROUND(
        (COALESCE(f."充值费收入_QI", 0) + COALESCE(f."虚拟开卡费收入", 0) + 
         COALESCE(f."FX_Cross费用收入", 0) + COALESCE(f."Settlement_Auth_Fee收入", 0) + 
         COALESCE(f."其他费用收入", 0) + COALESCE(f."新增收入", 0) + COALESCE(f."总实收金额_QI", 0)) -
        (COALESCE(f."成本一", 0) + COALESCE(f."成本二", 0) + COALESCE(f."成本三", 0) + 
         COALESCE(f."成本四", 0) + COALESCE(f."成本五", 0) + COALESCE(f."成本六", 0) + 
         COALESCE(f."成本七", 0) + COALESCE(f."成本八", 0) + COALESCE(f."成本十", 0))
    )::INTEGER as "去除实体卡净收入",
		
		    -- 净收入
    ROUND(
        (COALESCE(f."充值费收入_QI", 0) + COALESCE(f."虚拟开卡费收入", 0) + 
         COALESCE(f."实体卡制卡费收入", 0) + COALESCE(f."FX_Cross费用收入", 0) + 
         COALESCE(f."Settlement_Auth_Fee收入", 0) + COALESCE(f."其他费用收入", 0) + 
         COALESCE(f."新增收入", 0) + COALESCE(f."总实收金额_QI", 0)-COALESCE(f."实体卡制卡费收入", 0)-COALESCE(f."低消实收金额_QI", 0)-COALESCE(f."月结手续费实收金额_QI", 0)) -
        (COALESCE(f."成本一", 0) + COALESCE(f."成本二", 0) + COALESCE(f."成本三", 0) + 
         COALESCE(f."成本四", 0) + COALESCE(f."成本五", 0) + COALESCE(f."成本六", 0) + 
         COALESCE(f."成本七", 0) + COALESCE(f."成本八", 0) + COALESCE(f."成本十", 0))
    )::INTEGER as "销售毛利",
		
				-- 毛利
    ROUND(
        (COALESCE(f."充值费收入_QI", 0) + COALESCE(f."虚拟开卡费收入", 0) + 
         COALESCE(f."实体卡制卡费收入", 0) + COALESCE(f."FX_Cross费用收入", 0) + 
         COALESCE(f."Settlement_Auth_Fee收入", 0) + COALESCE(f."其他费用收入", 0) + 
         COALESCE(f."新增收入", 0) + COALESCE(f."总实收金额_QI", 0)) -
        (COALESCE(f."成本一", 0) + COALESCE(f."成本二", 0) + COALESCE(f."成本三", 0) + 
         COALESCE(f."成本四", 0) + COALESCE(f."成本五", 0) + COALESCE(f."成本六", 0) + 
         COALESCE(f."成本七", 0) + COALESCE(f."成本八", 0) + COALESCE(f."成本十", 0))
    )::INTEGER as "毛利"
		
		
FROM final_summary f
LEFT JOIN "account" AC ON f."母客户id"=AC."displayId"
WHERE f."母客户id" IS NOT NULL
    AND (
        -- 至少有一项数据不为0
        f."充值费收入_QI" > 0 
        OR f."虚拟开卡费收入" > 0 
        OR f."实体卡制卡费收入" > 0
        OR f."FX_Cross费用收入" > 0 
        OR f."Settlement_Auth_Fee收入" > 0 
        OR f."其他费用收入" > 0 
        OR f."新增收入" > 0 
        OR f."总实收金额_QI" > 0
        OR f."成本一" > 0 
        OR f."成本二" > 0 
        OR f."成本三" > 0 
        OR f."成本四" > 0 
        OR f."成本五" > 0 
        OR f."成本六" > 0 
        OR f."成本七" > 0 
        OR f."成本八" > 0
        OR f."成本十" > 0
    )
ORDER BY 
    CASE WHEN f."母客户id" = '666245' THEN 1 ELSE 2 END,  -- 确保666245在最前面
    f."QBIT渠道净消费" DESC,  -- 按消费降序排列
    f."母客户id";