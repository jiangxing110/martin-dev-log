-- QI客户毛利2026-06（完整版，增加KYC应收金额已去除，增加DCSF成本，手动实收）
-- VISA另一份账单、活跃卡费、还没出
-- 注释掉：低消应收、月结手续费应收、低消实收、月结手续费实收
SET myapp.start_time = '2026-06-01 00:00:00';
SET myapp.end_time = '2026-07-01 00:00:00';
SET myapp.param_a = '0.9749';
SET myapp.param_b = '0.9019';
SET myapp.param_c = '1.0636';
SET myapp.param_d = '1.3434'; --VRM
SET myapp.param_e = '0.9904'; --CROSS
SET myapp.param_f = '1.1263'; --DCSF

WITH params AS (
    SELECT 
        current_setting('myapp.start_time')::timestamp AS start_time,
        current_setting('myapp.end_time')::timestamp AS end_time,
        current_setting('myapp.param_a')::numeric AS param_a,
        current_setting('myapp.param_b')::numeric AS param_b,
        current_setting('myapp.param_c')::numeric AS param_c,
        current_setting('myapp.param_d')::numeric AS param_d,
        current_setting('myapp.param_e')::numeric AS param_e,
        current_setting('myapp.param_f')::numeric AS param_f
),

-- ================= 账户层级（含 systemType） =================
account_hierarchy AS (
    WITH RECURSIVE account_tree AS (
        SELECT 
            a."id",
            a."displayId",
            a."parentAccountId",
            a."id" as "root_account_id",
            a."displayId" as "root_display_id",
            1 as level,
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
            a."id",
            a."displayId",
            a."parentAccountId",
            at."root_account_id",
            at."root_display_id",
            at.level + 1,
            d."nickname",
            at."systemType",
            at."access_type",
            at."business_mode"
        FROM account a
        INNER JOIN account_tree at ON a."parentAccountId" = at."id"
        LEFT JOIN "salesAccountRelation" c ON a."id" = c."accountId" AND c."deleteTime" IS NULL
        LEFT JOIN "user" d ON c."salesId" = d."id"
    )
    SELECT 
        "id" as "account_id",
        CASE 
            WHEN LEFT("root_display_id", 6) IN ('042433', '932059', '989223') THEN '666245'
            ELSE LEFT("root_display_id", 6)
        END as "母客户id",
        "displayId" as "original_display_id",
        "root_display_id",
        level,
        LEFT("root_display_id", 6) as "原始母客户id",
        "bd_nickname" as "BD",
        "access_type",
        "business_mode",
        "systemType"
    FROM account_tree
),

master_client_bd AS (
    SELECT DISTINCT ON ("母客户id")
        "母客户id",
        "BD"
    FROM account_hierarchy
    WHERE "BD" IS NOT NULL
    ORDER BY "母客户id", level ASC
),

-- ================= 真实客户汇总 =================
real_master_clients AS (
    SELECT 
        "母客户id",
        COALESCE(MIN("BD") FILTER (WHERE "BD" != '未分配'), '未分配') as "BD",
        MIN("systemType") as "systemType",
        MIN("access_type") as "access_type",
        MIN("business_mode") as "business_mode"
    FROM (
        SELECT 
            ah."母客户id",
            COALESCE(mbd."BD", '未分配') as "BD",
            ah."systemType",
            ah."access_type",
            ah."business_mode"
        FROM account_hierarchy ah
        LEFT JOIN master_client_bd mbd ON ah."母客户id" = mbd."母客户id"
    ) t
    GROUP BY "母客户id"
),

-- ================= 所有客户（仅真实客户，已删除虚拟客户） =================
all_master_clients AS (
    SELECT 
        "母客户id",
        "BD",
        "systemType",
        "access_type",
        "business_mode"
    FROM real_master_clients
),

-- ================= 原 QI 业务逻辑（交易基础、成本、收入等） =================
transaction_base AS MATERIALIZED (
    SELECT 
        ah."母客户id",
        B."transactionId",
        B."businessType",
        B."status",
        B."remarks",
        D.usd_amount,
        D.channel_provision,
        D.country,
        B."transactionCurrency",
        D."bin",
        B."specialSourceData",
        B."fee",
        B."transactionTime"
    FROM "qbit_card_transaction" B
    LEFT JOIN account_hierarchy ah ON ah."account_id" = B."accountId"
    LEFT JOIN quantum_card_transaction_extend D ON B."transactionId" = D."transaction_id"
    CROSS JOIN params p
    WHERE B."createTime" >= p.start_time 
        AND B."createTime" < p.end_time
        AND B."deleteTime" IS NULL
        AND ah."母客户id" IS NOT NULL  
),

cross_border_summary AS (
    SELECT 
        "母客户id",
        SUM(CASE 
            WHEN channel_provision = 'QBIT' 
                 AND "businessType" = 'Consumption' 
                 AND "status" IN ('Closed', 'Pending')
                 AND "country" NOT IN ('HK', 'HKG')
                 AND (
                     (bin = '49387519' AND "transactionCurrency" = 'USD')
                     OR (bin = '49387520' AND "transactionCurrency" = 'HKD')
                 )
            THEN usd_amount
            WHEN channel_provision = 'QBIT' 
                 AND "businessType" IN ('Reversal', 'Credit') 
                 AND "status" IN ('Closed', 'Pending')
                 AND "country" NOT IN ('HK', 'HKG')
                 AND (
                     (bin = '49387519' AND "transactionCurrency" = 'USD')
                     OR (bin = '49387520' AND "transactionCurrency" = 'HKD')
                 )
            THEN -usd_amount
            ELSE 0 
        END) AS "跨境USD_HKD交易金额",
        SUM(CASE 
            WHEN channel_provision = 'QBIT' 
                 AND "businessType" = 'Consumption' 
                 AND "status" IN ('Closed', 'Pending')
                 AND "country" NOT IN ('HK', 'HKG') 
            THEN usd_amount
            WHEN channel_provision = 'QBIT' 
                 AND "businessType" IN ('Reversal', 'Credit') 
                 AND "status" IN ('Closed', 'Pending')
                 AND "country" NOT IN ('HK', 'HKG') 
            THEN -usd_amount
            ELSE 0 
        END) AS "跨境交易金额"
    FROM transaction_base
    GROUP BY "母客户id"
),

cross_border_ratio AS (
    SELECT 
        "母客户id",
        "跨境USD_HKD交易金额",
        "跨境交易金额",
        CASE 
            WHEN "跨境交易金额" = 0 THEN 0
            ELSE ROUND("跨境USD_HKD交易金额" * 100.0 / "跨境交易金额", 2)
        END AS "跨境USD_HKD交易占比"
    FROM cross_border_summary
),

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

total_consumption AS (
    SELECT 
        SUM("QBIT渠道净消费") as "总QBIT渠道净消费",
        COUNT(*) as "总客户数"
    FROM customer_consumption
    WHERE "QBIT渠道净消费" > 0
),

Consumption AS (
    SELECT 
        cc."母客户id",
        cc."QBIT渠道净消费",
        cc."所有渠道净消费",
        CASE 
            WHEN cc."所有渠道净消费" > 0 
            THEN ROUND(cc."QBIT渠道净消费" * 100.0 / cc."所有渠道净消费", 2)
            ELSE 0 
        END as "QI渠道净消费占比",
        CASE 
            WHEN cc."QBIT渠道净消费" > 0 AND tc."总QBIT渠道净消费" > 0
            THEN cc."QBIT渠道净消费" * 100.0 / tc."总QBIT渠道净消费"
            ELSE 0 
        END as "客户QI渠道净消费占比_原始"
    FROM customer_consumption cc
    CROSS JOIN total_consumption tc
),

AdjustedConsumption AS (
    SELECT 
        c."母客户id",
        c."QBIT渠道净消费",
        c."所有渠道净消费",
        c."QI渠道净消费占比",
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

-- ================= 应收分配逻辑（使用 adjust_amount，排除 KYC） =================
receivable_allocation AS (
    WITH bill_ids AS (
        SELECT id, bill_month FROM api_client_bill
        WHERE delete_time IS NULL AND is_latest='t' AND bill_month='2026-06'--每月调整
    ),
    summary AS (
        SELECT abs.bill_id, abs.account_id, abs.type, abs.item, 
               SUM(COALESCE(abs."adjust_amount", abs."amount")) AS total_adjusted
        FROM api_client_bill_statement abs
        JOIN bill_ids b ON abs.bill_id=b.id
        WHERE abs.delete_time IS NULL AND abs.is_sum='t' 
          AND abs.item NOT LIKE 'Identity%'   -- 排除 KYC 应收
          AND abs.type NOT IN ('topUpFeeClosed','cardCreationFeeClosed','settlementFeeClosed',
                               'physicalCardFeeClosed','authFeeClosed','applePayAuthFeeClosed','atmWithdrawalFeeClosed')
        GROUP BY abs.bill_id, abs.account_id, abs.type, abs.item
    ),
    details AS (
        SELECT abs.bill_id, abs.account_id, abs.type, abs.item, abs.provider, 
               SUM(COALESCE(abs."adjust_amount", abs."amount")) AS original_amount
        FROM api_client_bill_statement abs
        JOIN bill_ids b ON abs.bill_id=b.id
        WHERE abs.delete_time IS NULL AND abs.is_sum='f' 
          AND abs.item NOT LIKE 'Identity%'
          AND abs.type NOT IN ('topUpFeeClosed','cardCreationFeeClosed','settlementFeeClosed',
                               'physicalCardFeeClosed','authFeeClosed','applePayAuthFeeClosed','atmWithdrawalFeeClosed')
        GROUP BY abs.bill_id, abs.account_id, abs.type, abs.item, abs.provider
    ),
    swd AS (
        SELECT s.bill_id, s.account_id, s.type, s.item, s.total_adjusted,
               COALESCE(SUM(d.original_amount),0) AS total_original_details
        FROM summary s
        LEFT JOIN details d ON s.bill_id=d.bill_id AND s.account_id=d.account_id 
                           AND s.type=d.type AND s.item=d.item
        GROUP BY s.bill_id, s.account_id, s.type, s.item, s.total_adjusted
    ),
    allocated AS (
        SELECT d.bill_id, b.bill_month, d.account_id, d.type, d.item, d.provider, d.original_amount,
               swd.total_adjusted AS adjusted_summary,
               ROUND(swd.total_adjusted * d.original_amount / swd.total_original_details, 2) AS adjusted_detail,
               'allocated' AS allocation_type
        FROM details d
        JOIN swd ON d.bill_id=swd.bill_id AND d.account_id=swd.account_id 
                AND d.type=swd.type AND d.item=swd.item
        JOIN bill_ids b ON d.bill_id=b.id
        WHERE swd.total_original_details > 0 AND d.original_amount > 0
    ),
    unallocated AS (
        SELECT s.bill_id, b.bill_month, s.account_id, s.type, s.item, NULL AS provider, 
               NULL::numeric AS original_amount,
               s.total_adjusted AS adjusted_summary, s.total_adjusted AS adjusted_detail,
               'unallocated' AS allocation_type
        FROM swd s
        JOIN bill_ids b ON s.bill_id=b.id
        WHERE s.total_original_details = 0
    )
    SELECT * FROM allocated UNION ALL SELECT * FROM unallocated
),

ReceivableByAccountnew AS (
    SELECT 
        account_id,
        SUM(CASE WHEN type in ('monthlyCommitment','minimumVolumeCommitmentFee') THEN adjusted_detail ELSE 0 END) AS "低消应收金额",
        SUM(CASE WHEN type = 'additionalFee' THEN adjusted_detail ELSE 0 END) AS "月结手续费应收金额",
        SUM(CASE 
            WHEN type NOT IN ('monthlyCommitment', 'additionalFee','minimumVolumeCommitmentFee') 
                 AND allocation_type = 'allocated' 
                 AND provider = 'IQ' 
            THEN adjusted_detail 
            ELSE 0 
        END) AS "其他手续费应收金额",
        SUM(adjusted_detail) AS "总应收金额"
    FROM receivable_allocation
    WHERE adjusted_detail IS NOT NULL AND adjusted_detail != 0
    GROUP BY account_id
),

AccountReceivableAmount AS (
    SELECT 
        ah."母客户id",
        SUM(COALESCE(rba."低消应收金额", 0)) AS "低消应收金额",
        SUM(COALESCE(rba."月结手续费应收金额", 0)) AS "月结手续费应收金额",
        SUM(COALESCE(rba."其他手续费应收金额", 0)) AS "其他手续费应收金额",
        SUM(COALESCE(rba."总应收金额", 0)) AS "总应收金额"
    FROM ReceivableByAccountnew rba
    LEFT JOIN account_hierarchy ah ON ah."account_id" = rba."account_id"
    WHERE ah."母客户id" IS NOT NULL
    GROUP BY ah."母客户id"
),

-- ================= 不可拆分应收（按 QI渠道净消费占比 分配） =================
UnallocatedReceivable AS (
    SELECT 
        account_id,
        SUM(adjusted_detail) as total_unallocated
    FROM receivable_allocation
    WHERE allocation_type = 'unallocated'
      AND type NOT IN ('monthlyCommitment', 'additionalFee', 'minimumVolumeCommitmentFee','Add')
			AND item IS NULL
      AND adjusted_detail IS NOT NULL AND adjusted_detail != 0
    GROUP BY account_id
),

-- 修改点：确保不可拆分应收不为负数（若占比为负则乘积累积为0）
UnallocatedReceivableByMaster AS (
    SELECT 
        ah."母客户id",
        SUM(GREATEST(ur.total_unallocated * COALESCE(cons."QI渠道净消费占比", 0) / 100, 0)) AS "不可拆分应收"
    FROM UnallocatedReceivable ur
    LEFT JOIN account_hierarchy ah ON ah.account_id = ur.account_id
    LEFT JOIN AdjustedConsumption cons ON ah."母客户id" = cons."母客户id"
    WHERE ah."母客户id" IS NOT NULL
    GROUP BY ah."母客户id"
),

-- ================= 从 provider Collection 获取新实收（QI渠道） =================
new_receipts AS (
    SELECT 
        A."accountId" AS "account_id",
        A."Parent ID" AS "母客户id",
        SUM(A."Minimum Commitment Collection") AS "低消实收金额_QI",
        SUM(A."Monthly Api Collection") AS "月结手续费实收金额_QI",
        SUM(A."Other Fee Collection" + A."Manual Collection") AS "其他手续费实收金额_QI",
        MAX(A."Total Collection") AS "总实收金额_所有渠道",
        SUM((A."Minimum Commitment Collection" + A."Monthly Api Collection" + A."Other Fee Collection" + A."Manual Collection")) AS "总实收金额_QI"
    FROM "provider Collection" A
    WHERE A."Collection Month" = '2026-06' --每月调整
      AND A."Provider" = 'IQ'
    GROUP BY A."accountId", A."Parent ID"
),

-- ================= 成本相关 CTE =================
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
        COUNT(*) * 0.09 * (SELECT param_d FROM params) as "成本四金额"
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
        AND B."status" != 'Cancelled'
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

cost_dcsf AS (
    SELECT 
        "母客户id",
        SUM(
            CASE 
                WHEN usd_amount <= 50 THEN 0.025
                WHEN usd_amount <= 1000 THEN usd_amount * 0.0005
                WHEN usd_amount > 1000 THEN 0.5
                ELSE 0
            END
        ) * (SELECT param_f FROM params) AS "DCSF成本"
    FROM transaction_base
    WHERE "businessType" = 'Consumption'
        AND channel_provision = 'QBIT'
        AND country NOT IN ('HK', 'HKG')
        AND NOT (
            ("specialSourceData"->>'code')::JSONB @> '[1001]' OR
            ("specialSourceData"->>'code')::JSONB @> '[1103]' OR
            ("specialSourceData"->>'code')::JSONB @> '[1105]'
        )
        AND usd_amount IS NOT NULL
    GROUP BY "母客户id"
),

combined_costs AS (
    SELECT 
        cc."母客户id",
        COALESCE(c1."成本一金额", 0) as "成本一",
        COALESCE(c2."成本二金额", 0) as "成本二",
        COALESCE(c3."成本三金额", 0) as "成本三",
        COALESCE(c4."成本四金额", 0) as "成本四",
        COALESCE(c5."成本五金额", 0) as "成本五",
        CASE 
            WHEN cc."母客户id" = '666245' THEN 10728.35 --每月调整
            ELSE COALESCE(c6."成本六金额", 0)
        END as "成本六",
        COALESCE(c7."成本七金额", 0) as "成本七",
        COALESCE(c8."成本八金额", 0) as "成本八",
        COALESCE(c9."DCSF成本", 0) as "成本九"
    FROM customer_consumption cc
    LEFT JOIN cost1 c1 USING("母客户id")
    LEFT JOIN cost2 c2 USING("母客户id")
    LEFT JOIN cost3 c3 USING("母客户id")
    LEFT JOIN cost4 c4 USING("母客户id")
    LEFT JOIN cost5 c5 USING("母客户id")
    LEFT JOIN cost6 c6 USING("母客户id")
    LEFT JOIN cost7 c7 USING("母客户id")
    LEFT JOIN cost8 c8 USING("母客户id")
    LEFT JOIN cost_dcsf c9 USING("母客户id")
),

-- ================= 收入相关 CTE（充值费由 provider top up fee 提供） =================

-- 新增：从 provider top up fee 获取充值费
ProviderTopUpFee AS (
    SELECT 
        ah."母客户id",
        COALESCE(SUM(ptf."top up fee_all"), 0) AS "充值费_总",
        COALESCE(SUM(ptf."top up fee_qi"), 0) AS "充值费_QI"
    FROM "provider top up fee" ptf
    LEFT JOIN account_hierarchy ah ON ah."account_id" = ptf."accountId"
    CROSS JOIN params p
    WHERE ptf."Collection Month" = '2026-06'   -- 每月调整
      AND ptf."top up fee_all" != 0
      AND ptf."top up fee_qi" != 0
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
        ) * 0.02*(SELECT param_e FROM params) +
        SUM(
            CASE 
                WHEN "businessType" = 'Consumption' AND country NOT IN ('HK','HKG') AND "status" IN ('Closed', 'Pending') THEN usd_amount
                WHEN "businessType" IN ('Reversal', 'Credit') AND country NOT IN ('HK','HKG') AND "status" IN ('Closed', 'Pending') THEN -usd_amount
                ELSE 0 
            END
        ) * 0.0118) as "新增收入"
    FROM transaction_base
    CROSS JOIN params p
    WHERE channel_provision = 'QBIT'
        AND "status" IN ('Closed', 'Pending')
        AND "businessType" IN ('Consumption')
    GROUP BY "母客户id"
),

MailingFeeIncome AS (
    SELECT 
        ah."母客户id",
        SUM(A."settleAmount")  AS "邮寄费收入"
    FROM "qbitCardWalletTransaction" A
    LEFT JOIN account_hierarchy ah ON ah."account_id" = A."accountId"
    LEFT JOIN "qbitCard" C ON A."cardId"=C."id"
    CROSS JOIN params p
    WHERE A."remarks" IN ('邮寄费','批量邮寄运费')
        AND A."transactionTime" >= p.start_time
        AND A."transactionTime" < p.end_time
        AND A."deleteTime" IS NULL
        AND A."status" = 'Closed'
        AND ah."母客户id" IS NOT NULL
        AND C."provider" like 'Qbit%'
    GROUP BY ah."母客户id"
),

-- 修改后的 combined_revenue：替换原 RechargeSummary 为 ProviderTopUpFee
combined_revenue AS (
    SELECT 
        COALESCE(ptf."母客户id", v."母客户id", p."母客户id", f."母客户id", 
                 s."母客户id", o."母客户id", f5."母客户id", m."母客户id") as "母客户id",
        COALESCE(ptf."充值费_总", 0) as "充值费_总",
        COALESCE(ptf."充值费_QI", 0) as "充值费_QI",
        COALESCE(v."虚拟开卡费", 0) as "虚拟开卡费收入",
        COALESCE(p."实体卡制卡费", 0) as "实体卡制卡费收入",
        COALESCE(f."FX_Cross费用", 0) as "FX_Cross费用收入",
        COALESCE(s."Settlement_Auth_Fee", 0) as "Settlement_Auth_Fee收入",
        COALESCE(o."其他费用", 0) as "其他费用收入",
        COALESCE(f5."新增收入", 0) as "新增收入",
        COALESCE(m."邮寄费收入", 0) as "邮寄费收入"
    FROM ProviderTopUpFee ptf
    FULL OUTER JOIN VirtualCardFee v USING("母客户id")
    FULL OUTER JOIN PhysicalCardFee p USING("母客户id")
    FULL OUTER JOIN FXFee f USING("母客户id")
    FULL OUTER JOIN SettlementAuthFee s USING("母客户id")
    FULL OUTER JOIN OtherFee o USING("母客户id")
    FULL OUTER JOIN fee5 f5 USING("母客户id")
    FULL OUTER JOIN MailingFeeIncome m USING("母客户id")
),

transaction_price_distribution AS (
    SELECT 
        ah."母客户id",
        COUNT(CASE WHEN ABS(A."settleAmount") < 5 THEN 1 END) AS cnt_less_5,
        COUNT(CASE WHEN ABS(A."settleAmount") >= 5 AND ABS(A."settleAmount") < 10 THEN 1 END) AS cnt_5_10,
        COUNT(CASE WHEN ABS(A."settleAmount") >= 10 AND ABS(A."settleAmount") < 50 THEN 1 END) AS cnt_10_50,
        COUNT(CASE WHEN ABS(A."settleAmount") >= 50 AND ABS(A."settleAmount") < 250 THEN 1 END) AS cnt_50_250,
        COUNT(CASE WHEN ABS(A."settleAmount") >= 250 THEN 1 END) AS cnt_greater_250,
        COUNT(*) AS total_count
    FROM "qbit_card_transaction" A
    LEFT JOIN account_hierarchy ah ON ah."account_id" = A."accountId"
    CROSS JOIN params p
    WHERE A."provider" LIKE 'Qb%'
        AND A."status" IN ('Closed', 'Pending')
        AND A."businessType" = 'Consumption'
        AND A."createTime" >= p.start_time
        AND A."createTime" < p.end_time
        AND ah."母客户id" IS NOT NULL
    GROUP BY ah."母客户id"
),

-- ================= 最终汇总（所有乘以占比的字段均用 GREATEST 保证非负） =================
final_summary AS (
    SELECT 
        amc."母客户id",
        amc."BD",
        amc."access_type",
        amc."business_mode",
        amc."systemType",
        COALESCE(c."成本一", 0) as "成本一",
        COALESCE(c."成本二", 0) as "成本二",
        COALESCE(c."成本三", 0) as "成本三",
        COALESCE(c."成本四", 0) as "成本四",
        COALESCE(c."成本五", 0) as "成本五",
        COALESCE(c."成本六", 0) as "成本六",
        COALESCE(c."成本七", 0) as "成本七",
        COALESCE(c."成本八", 0) as "成本八",
        COALESCE(c."成本九", 0) as "成本九",
        GREATEST((31103+10667+5808) * COALESCE(cons."客户QI渠道净消费占比", 0) / 100, 0) as "成本十",--每月调整固定成本+BPC成本+另一份账单的成本
        GREATEST(9000 * COALESCE(cons."客户QI渠道净消费占比", 0) / 100, 0) as "银行手续费成本",--每月调整
        (CASE WHEN amc."母客户id" = '732600' THEN -0 ELSE 0 END)* (COALESCE(cons."QI渠道净消费占比", 0) / 100) AS "直客手动退款",--每月调整
				
        (CASE 
            WHEN amc."母客户id" = '621311' THEN 0
            WHEN amc."母客户id" = '413969' THEN 0
        END )* (COALESCE(cons."QI渠道净消费占比", 0) / 100) AS "应收_财务线下手动调整",--每月调整
				
        CASE 
            WHEN amc."母客户id" = '440126' THEN 0
            ELSE 0
        END AS "线下实体卡收入",--每月调整
				
				CASE 
						WHEN amc."母客户id" = '018142' THEN 111.52
						WHEN amc."母客户id" = '079942' THEN 114.52
						WHEN amc."母客户id" = '148807' THEN 114.52
						WHEN amc."母客户id" = '227428' THEN 498.52
						WHEN amc."母客户id" = '238996' THEN 399.52
						WHEN amc."母客户id" = '369660' THEN 111.52
						WHEN amc."母客户id" = '426164' THEN 126.52
						WHEN amc."母客户id" = '440126' THEN 111.52
						WHEN amc."母客户id" = '562513' THEN 111.52
						WHEN amc."母客户id" = '665218' THEN 114.52
						WHEN amc."母客户id" = '744345' THEN 120.52
						WHEN amc."母客户id" = '797146' THEN 114.52
						WHEN amc."母客户id" = '835152' THEN 126.52
						WHEN amc."母客户id" = '852232' THEN 111.52
						WHEN amc."母客户id" = '907519' THEN 192.52
						WHEN amc."母客户id" = '941375' THEN 129.52
						WHEN amc."母客户id" = '990552' THEN 117.52
						ELSE 0
				END AS "新增实体卡成本",  --每月调整
				
        (CASE 
            WHEN amc."母客户id" = '637549' THEN 0
            ELSE 0
        END) * (COALESCE(cons."QI渠道净消费占比", 0) / 100) AS "财务手动调整返现成本",--每月调整
				
				CASE 
						WHEN amc."母客户id" = '018142' THEN 81.37
						WHEN amc."母客户id" = '128139' THEN 249.8
						WHEN amc."母客户id" = '289420' THEN 2.06
						WHEN amc."母客户id" = '322383' THEN 1436.8
						WHEN amc."母客户id" = '436731' THEN 45.28
						WHEN amc."母客户id" = '440126' THEN 9.44
						WHEN amc."母客户id" = '523135' THEN 146.6
						WHEN amc."母客户id" = '562513' THEN 28.72
						WHEN amc."母客户id" = '599703' THEN 93.85
						WHEN amc."母客户id" = '637549' THEN 175.62
						WHEN amc."母客户id" = '838108' THEN 41581.52
						WHEN amc."母客户id" = '990552' THEN 395
						ELSE 0
				END AS "客户返现代收成本",  --每月调整
        CASE 
            WHEN amc."母客户id" = '183821' THEN 1716.65
            WHEN amc."母客户id" = '990552' THEN 0
            ELSE 0
        END AS "手动计算应收",--每月调整
				
        -- 充值费字段直接取自 ProviderTopUpFee，不再乘占比
        COALESCE(r."充值费_总", 0) as "充值费收入",
        COALESCE(r."充值费_QI", 0) as "充值费收入_QI",
        COALESCE(r."虚拟开卡费收入", 0) as "虚拟开卡费收入",
        COALESCE(r."实体卡制卡费收入", 0) as "实体卡制卡费收入",
        COALESCE(r."FX_Cross费用收入", 0) as "FX_Cross费用收入",
        COALESCE(r."Settlement_Auth_Fee收入", 0) as "Settlement_Auth_Fee收入",
        COALESCE(r."其他费用收入", 0) as "其他费用收入",
        COALESCE(r."新增收入", 0) as "新增收入",
        COALESCE(r."邮寄费收入", 0) as "邮寄费收入",
        -- 实收字段直接从 new_receipts 获取，不再乘以占比
        COALESCE(nar."低消实收金额_QI", 0) AS "低消实收金额_QI",
        COALESCE(nar."月结手续费实收金额_QI", 0) AS "月结手续费实收金额_QI",
        COALESCE(nar."其他手续费实收金额_QI", 0) AS "其他手续费实收金额_QI",
        COALESCE(nar."总实收金额_QI", 0) AS "总实收金额_QI",
        COALESCE(nar."总实收金额_所有渠道", 0) AS "总实收金额_所有渠道",
        GREATEST(COALESCE(ara2."低消应收金额", 0) * COALESCE(cons."QI渠道净消费占比", 0) / 100, 0) as "低消应收金额_QI",
        GREATEST(COALESCE(ara2."月结手续费应收金额", 0) * COALESCE(cons."QI渠道净消费占比", 0) / 100, 0) as "月结手续费应收金额_QI",
        COALESCE(ara2."其他手续费应收金额", 0) as "其他手续费应收金额_QI",
        COALESCE(ara2."总应收金额", 0) as "总应收金额_QI",
        COALESCE(cons."QBIT渠道净消费", 0) as "QBIT渠道净消费",
        COALESCE(cbr."跨境USD_HKD交易金额", 0) AS "跨境USD_HKD交易金额",
        COALESCE(cbr."跨境交易金额", 0) AS "跨境交易金额",
        COALESCE(cbr."跨境USD_HKD交易占比", 0) AS "跨境USD_HKD交易占比",
        COALESCE(cons."所有渠道净消费", 0) as "所有渠道净消费",
        COALESCE(cons."QI渠道净消费占比", 0) as "QI渠道净消费占比",
        COALESCE(cons."客户QI渠道净消费占比", 0) as "客户QI渠道净消费占比",
        COALESCE(tpd.cnt_less_5, 0) as "cnt_less_5",
        COALESCE(tpd.cnt_5_10, 0) as "cnt_5_10",
        COALESCE(tpd.cnt_10_50, 0) as "cnt_10_50",
        COALESCE(tpd.cnt_50_250, 0) as "cnt_50_250",
        COALESCE(tpd.cnt_greater_250, 0) as "cnt_greater_250",
        COALESCE(tpd.total_count, 0) as "distribution_total_count",
        COALESCE(urm."不可拆分应收", 0) AS "不可拆分应收"
    FROM all_master_clients amc
    LEFT JOIN AdjustedConsumption cons ON amc."母客户id" = cons."母客户id"
    LEFT JOIN combined_costs c ON amc."母客户id" = c."母客户id"
    LEFT JOIN combined_revenue r ON amc."母客户id" = r."母客户id"
    LEFT JOIN new_receipts nar ON amc."母客户id" = nar."母客户id"   -- 替换原 ActualReceivedAmount
    LEFT JOIN AccountReceivableAmount ara2 ON amc."母客户id" = ara2."母客户id"
    LEFT JOIN transaction_price_distribution tpd ON amc."母客户id" = tpd."母客户id"
    LEFT JOIN UnallocatedReceivableByMaster urm ON amc."母客户id" = urm."母客户id"
    LEFT JOIN cross_border_ratio cbr ON amc."母客户id" = cbr."母客户id"
)

-- ================= 最终输出（注释掉低消和月结的应收/实收四项） =================
SELECT 
    AC."id"::text AS "accountid",
    f."母客户id",
    f."BD",
    f."systemType" AS "system_type",
    f."access_type",
    f."business_mode",
    CASE 
        WHEN AC."type" IN ('ApiClient', 'ApiClientCustomer') THEN 'API'
        WHEN AC."type" IN ('Merchant', 'MasterAccount', 'TestAccount','Channel','NewChannel','CNYSettle') THEN '直客'
        ELSE AC."type"
    END AS "客户类型",
    COALESCE(
        (SELECT "verifiedName" FROM account WHERE "displayId" LIKE 
            CASE WHEN f."母客户id" = '666245' OR f."母客户id" IN ('042433', '932059', '989223')
                 THEN '666245%' ELSE f."母客户id" || '%' END
            AND ("parentAccountId" = '00000000-0000-0000-0000-000000000000' OR "parentAccountId" IS NULL) 
            LIMIT 1),
        ''  -- 若无真实客户名称则留空
    ) as "verifiedName",
    f."QBIT渠道净消费" AS "QBIT渠道净消费",
    ROUND(f."跨境交易金额")::INTEGER AS "跨境交易金额",
    ROUND(f."跨境USD_HKD交易金额")::INTEGER AS "跨境USD(HKD)交易金额",
    f."跨境USD_HKD交易占比" || '%' AS "跨境USD(HKD)交易占比",
    f."distribution_total_count" AS "消费数量",
    CASE 
        WHEN f."distribution_total_count" > 0 THEN
            CONCAT(
                '"<5"：', ROUND(f."cnt_less_5" * 100.0 / f."distribution_total_count", 0), '%、',
                '"5-10"：', ROUND(f."cnt_5_10" * 100.0 / f."distribution_total_count", 0), '%、',
                '"10-50"：', ROUND(f."cnt_10_50" * 100.0 / f."distribution_total_count", 0), '%、',
                '"50-250"：', ROUND(f."cnt_50_250" * 100.0 / f."distribution_total_count", 0), '%、',
                '">250"：', ROUND(f."cnt_greater_250" * 100.0 / f."distribution_total_count", 0), '%'
            )
        ELSE '"<5"：0%、"5-10"：0%、"10-50"：0%、"50-250"：0%、">250"：0%'
    END AS "价格区间分布",
    f."QI渠道净消费占比" || '%' AS "QI渠道净消费占比",
    f."客户QI渠道净消费占比" || '%' AS "客户QI渠道净消费占比",
    f."成本一" AS "Issuer Card Service Fees",
    f."成本二" AS "Issuer Authorization, Clearing and Settlement Fees",
    f."成本三" AS "Issuer Authorization, Clearing and Settlement Fees_VIP", 
    f."成本四" AS "Visa Risk Manager (VRM)",
    f."成本五" AS "Crossborder/FX",
    f."成本六" AS "客户返现成本",
    f."客户返现代收成本" AS "客户返现_代收_QI",
    f."财务手动调整返现成本" AS "财务手动调整返现成本",
    f."成本七" AS "BaseII Dom",
    f."成本八" AS "VIP Dom",
    f."成本九" AS "DCSF成本",
    f."成本十" AS "固定成本+账户验证",
    f."新增实体卡成本" AS "实体卡成本",
    f."银行手续费成本" AS "银行手续费成本",
    -- KYC成本已去除，不再输出
    f."直客手动退款" AS "直客手动退款",
    f."应收_财务线下手动调整" AS "应收_财务线下手动调整",
    f."线下实体卡收入" AS "线下实体卡收入",
    f."充值费收入" AS "充值费收入",
    f."充值费收入_QI" AS "充值费收入_QI",
    f."虚拟开卡费收入" AS "虚拟开卡费收入",
    f."实体卡制卡费收入" AS "实体卡制卡费收入",
    f."FX_Cross费用收入" AS "FX_Cross费用收入",
    f."Settlement_Auth_Fee收入" AS "Settlement_Auth_Fee收入",
    f."其他费用收入" AS "其他费用收入",
    f."新增收入" AS "量子卡Cashback",
    f."邮寄费收入" AS "邮寄费收入",
		
		-- 以下四项已注释（低消和月结的应收/实收）
    -- f."低消应收金额_QI" AS "本月月账单_低消_QI",
    -- f."月结手续费应收金额_QI" AS "本月月账单_月费+api接入费_QI",
    f."其他手续费应收金额_QI" AS "本月月账单_其他手续费_QI",
		f."手动计算应收" AS "本月月账单_线下手动添加_QI",
    f."不可拆分应收" AS "本月月账单_技术bug未拆分_QI",
		
    -- f."低消实收金额_QI" AS "之前月账单_低消_QI",
    -- f."月结手续费实收金额_QI" AS "之前月账单_月费+api接入费_QI",
    f."其他手续费实收金额_QI" AS "之前月账单_其他手续费_QI",
    f."总实收金额_QI" AS "之前月账单_QI汇总",
    f."总实收金额_所有渠道" AS "之前月账单_所有渠道",  -- 新增字段
		
		(COALESCE(f."充值费收入_QI", 0) + COALESCE(f."虚拟开卡费收入", 0) + 
     COALESCE(f."实体卡制卡费收入", 0) + COALESCE(f."FX_Cross费用收入", 0) + 
     COALESCE(f."Settlement_Auth_Fee收入", 0) + COALESCE(f."其他费用收入", 0) + 
     COALESCE(f."新增收入", 0) + COALESCE(f."邮寄费收入", 0) +
     COALESCE(f."线下实体卡收入", 0)+
		 -- 已移除低消和月结应收
		 COALESCE(f."其他手续费应收金额_QI", 0) + COALESCE(f."直客手动退款", 0)+
     COALESCE(f."手动计算应收", 0) + COALESCE(f."不可拆分应收", 0) + COALESCE(f."应收_财务线下手动调整", 0)
		 ) AS "Pref_Rev",
		
    (COALESCE(f."充值费收入_QI", 0) + COALESCE(f."虚拟开卡费收入", 0) + 
     COALESCE(f."实体卡制卡费收入", 0) + COALESCE(f."FX_Cross费用收入", 0) + 
     COALESCE(f."Settlement_Auth_Fee收入", 0) + COALESCE(f."其他费用收入", 0) + 
     COALESCE(f."新增收入", 0) + COALESCE(f."邮寄费收入", 0) +
     COALESCE(f."线下实体卡收入", 0)) AS "Pref_Rev_realtime",
		 
		(COALESCE(f."其他手续费应收金额_QI", 0) + COALESCE(f."直客手动退款", 0)+
     COALESCE(f."手动计算应收", 0) + COALESCE(f."不可拆分应收", 0) + COALESCE(f."应收_财务线下手动调整", 0)) AS "Pref_Rev_本月月账单_not collected",
		 
    (COALESCE(f."成本一", 0) + COALESCE(f."成本二", 0) + COALESCE(f."成本三", 0) + 
     COALESCE(f."成本四", 0) + COALESCE(f."成本五", 0) + COALESCE(f."成本六", 0) + 
     COALESCE(f."成本七", 0) + COALESCE(f."成本八", 0) + COALESCE(f."成本九", 0) + 
     COALESCE(f."成本十", 0) + COALESCE(f."银行手续费成本", 0) + 
     COALESCE(f."客户返现代收成本", 0) + COALESCE(f."新增实体卡成本", 0) +
     COALESCE(f."财务手动调整返现成本", 0)) AS "Pref_Cost",
		 
		( COALESCE(f."充值费收入_QI", 0) + COALESCE(f."虚拟开卡费收入", 0) + 
     COALESCE(f."实体卡制卡费收入", 0) + COALESCE(f."FX_Cross费用收入", 0) + 
     COALESCE(f."Settlement_Auth_Fee收入", 0) + COALESCE(f."其他费用收入", 0) + 
     COALESCE(f."新增收入", 0) + COALESCE(f."邮寄费收入", 0) + COALESCE(f."直客手动退款", 0) +
     COALESCE(f."线下实体卡收入", 0)+
		 COALESCE(f."其他手续费应收金额_QI", 0) + 
     COALESCE(f."手动计算应收", 0) + COALESCE(f."不可拆分应收", 0) + COALESCE(f."应收_财务线下手动调整", 0)
	   -
		 (COALESCE(f."成本一", 0) + COALESCE(f."成本二", 0) + COALESCE(f."成本三", 0) + 
     COALESCE(f."成本四", 0) + COALESCE(f."成本五", 0) + COALESCE(f."成本六", 0) + 
     COALESCE(f."成本七", 0) + COALESCE(f."成本八", 0) + COALESCE(f."成本九", 0) + 
     COALESCE(f."成本十", 0) + COALESCE(f."银行手续费成本", 0) + 
     COALESCE(f."客户返现代收成本", 0) + COALESCE(f."新增实体卡成本", 0) +
     COALESCE(f."财务手动调整返现成本", 0))
		 ) AS "Pref_GP",
		 
		 
		 -- 毛利计算（月账单实收算毛利）
		( COALESCE(f."充值费收入_QI", 0) + COALESCE(f."虚拟开卡费收入", 0) + 
     COALESCE(f."实体卡制卡费收入", 0) + COALESCE(f."FX_Cross费用收入", 0) + 
     COALESCE(f."Settlement_Auth_Fee收入", 0) + COALESCE(f."其他费用收入", 0) + 
     COALESCE(f."新增收入", 0) + COALESCE(f."邮寄费收入", 0) +
     COALESCE(f."线下实体卡收入", 0) + 
		 -- 仅保留其他手续费实收，移除低消和月结实收
		 COALESCE(f."其他手续费实收金额_QI", 0)
		 ) AS "Cashflow_Rev",
		 
		(COALESCE(f."充值费收入_QI", 0) + COALESCE(f."虚拟开卡费收入", 0) + 
     COALESCE(f."实体卡制卡费收入", 0) + COALESCE(f."FX_Cross费用收入", 0) + 
     COALESCE(f."Settlement_Auth_Fee收入", 0) + COALESCE(f."其他费用收入", 0) + 
     COALESCE(f."新增收入", 0) + COALESCE(f."邮寄费收入", 0) +
     COALESCE(f."线下实体卡收入", 0)
		 ) AS "Cashflow_Rev_realtime",

    -- 之前月账单_collected 只保留其他手续费实收
    COALESCE(f."其他手续费实收金额_QI", 0) AS "Cashflow_Rev_之前月账单_collected",
		 
		( COALESCE(f."成本一", 0) + COALESCE(f."成本二", 0) + COALESCE(f."成本三", 0) + 
     COALESCE(f."成本四", 0) + COALESCE(f."成本五", 0) + COALESCE(f."成本六", 0) + 
     COALESCE(f."成本七", 0) + COALESCE(f."成本八", 0) + COALESCE(f."成本九", 0) + 
     COALESCE(f."成本十", 0) + COALESCE(f."银行手续费成本", 0) + 
     COALESCE(f."客户返现代收成本", 0) + COALESCE(f."新增实体卡成本", 0) +
     COALESCE(f."财务手动调整返现成本", 0)
		 ) AS "Cashflow_Cost",
		 
		(COALESCE(f."充值费收入_QI", 0) + COALESCE(f."虚拟开卡费收入", 0) + 
     COALESCE(f."实体卡制卡费收入", 0) + COALESCE(f."FX_Cross费用收入", 0) + 
     COALESCE(f."Settlement_Auth_Fee收入", 0) + COALESCE(f."其他费用收入", 0) + 
     COALESCE(f."新增收入", 0) + COALESCE(f."邮寄费收入", 0) + COALESCE(f."直客手动退款", 0) +
     COALESCE(f."线下实体卡收入", 0) + COALESCE(f."其他手续费实收金额_QI", 0) -
		 (COALESCE(f."成本一", 0) + COALESCE(f."成本二", 0) + COALESCE(f."成本三", 0) + 
     COALESCE(f."成本四", 0) + COALESCE(f."成本五", 0) + COALESCE(f."成本六", 0) + 
     COALESCE(f."成本七", 0) + COALESCE(f."成本八", 0) + COALESCE(f."成本九", 0) + 
     COALESCE(f."成本十", 0) + COALESCE(f."银行手续费成本", 0) + 
     COALESCE(f."客户返现代收成本", 0) + COALESCE(f."新增实体卡成本", 0) +
     COALESCE(f."财务手动调整返现成本", 0))
		 ) AS "Cashflow_GP",

     -- 毛利计算（销售调整：去除实体卡、邮寄费）
		(COALESCE(f."充值费收入_QI", 0) + COALESCE(f."虚拟开卡费收入", 0) + COALESCE(f."FX_Cross费用收入", 0) + 
     COALESCE(f."Settlement_Auth_Fee收入", 0) + COALESCE(f."其他费用收入", 0) + 
     COALESCE(f."新增收入", 0) + COALESCE(f."其他手续费实收金额_QI", 0)) AS "Cashflow_Rev_sale",

		(COALESCE(f."充值费收入_QI", 0) + COALESCE(f."虚拟开卡费收入", 0) + COALESCE(f."FX_Cross费用收入", 0) + 
     COALESCE(f."Settlement_Auth_Fee收入", 0) + COALESCE(f."其他费用收入", 0) + 
     COALESCE(f."新增收入", 0)) AS "Cashflow_Rev_realtime_sale",

		COALESCE(f."其他手续费实收金额_QI", 0) AS "Cashflow_Rev_之前月账单_collected_sale",
		 
		(COALESCE(f."成本一", 0) + COALESCE(f."成本二", 0) + COALESCE(f."成本三", 0) + 
     COALESCE(f."成本四", 0) + COALESCE(f."成本五", 0) + COALESCE(f."成本六", 0) + 
     COALESCE(f."成本七", 0) + COALESCE(f."成本八", 0) + COALESCE(f."成本九", 0) + 
     COALESCE(f."成本十", 0) + COALESCE(f."银行手续费成本", 0) + 
     COALESCE(f."客户返现代收成本", 0)) AS "Cashflow_Cost_sale",

		( (COALESCE(f."充值费收入_QI", 0) + COALESCE(f."虚拟开卡费收入", 0) + COALESCE(f."FX_Cross费用收入", 0) + 
     COALESCE(f."Settlement_Auth_Fee收入", 0) + COALESCE(f."其他费用收入", 0) + 
     COALESCE(f."新增收入", 0) + COALESCE(f."其他手续费实收金额_QI", 0)) -
		 (COALESCE(f."成本一", 0) + COALESCE(f."成本二", 0) + COALESCE(f."成本三", 0) + 
     COALESCE(f."成本四", 0) + COALESCE(f."成本五", 0) + COALESCE(f."成本六", 0) + 
     COALESCE(f."成本七", 0) + COALESCE(f."成本八", 0) + COALESCE(f."成本九", 0) + 
     COALESCE(f."成本十", 0) + COALESCE(f."银行手续费成本", 0) + 
     COALESCE(f."客户返现代收成本", 0))
	   ) AS "Cashflow_GP_sale"

FROM final_summary f
LEFT JOIN "account" AC ON f."母客户id" = AC."displayId"
WHERE f."母客户id" IS NOT NULL
    AND (
        f."充值费收入_QI" != 0 OR f."虚拟开卡费收入" != 0 OR f."实体卡制卡费收入" != 0 OR f."充值费收入" != 0
        OR f."FX_Cross费用收入" != 0 OR f."Settlement_Auth_Fee收入" != 0 OR f."其他费用收入" != 0 
        OR f."新增收入" != 0 OR f."总实收金额_QI" != 0 OR f."总实收金额_所有渠道" != 0 OR f."邮寄费收入" != 0 
        OR f."其他手续费应收金额_QI" != 0 OR f."不可拆分应收" != 0 OR f."手动计算应收" != 0
        OR f."成本一" != 0 OR f."成本二" != 0 OR f."成本三" != 0 OR f."成本四" != 0 
        OR f."成本五" != 0 OR f."成本六" != 0 OR f."成本七" != 0 OR f."成本八" != 0
        OR f."成本十" != 0 OR f."银行手续费成本" != 0 OR f."成本九" != 0 
        OR f."客户返现代收成本" != 0 OR f."新增实体卡成本" != 0 OR f."线下实体卡收入" != 0
        OR f."应收_财务线下手动调整" != 0 OR f."直客手动退款" != 0
    )
ORDER BY 
    CASE WHEN f."母客户id" = '666245' THEN 1 ELSE 2 END,
    f."QBIT渠道净消费" DESC,
    f."母客户id";
