-- 合伙人加点佣金交易 Mock 数据
--
-- 用途：测试 PartnerCommissionClient 非毛利佣金查询接口。
-- 固定合伙人：82650a77-6238-49f0-92f3-c8a6a90eb0cd
-- 固定客户：  61dd8fcc-50af-4360-b31c-e64633cdaf94
--
-- 说明：
-- 1. 每个 FeeTemplateNameEnum 业务费率生成 BasePriceMarkup、FlexibleMarkup 各一条。
-- 2. 产品线由 Assets 代码中的 FeeTemplateNameEnum.businessType 映射，不在交易表中重复存储。
-- 3. markup_fee 作为本次查询接口返回的 commissionAmount。
-- 4. ID 使用稳定 hash，重复执行时冲突行跳过，不会重复插入同一批 Mock 数据。

-- 删除本脚本生成的 Mock 数据，便于修正后重新执行。
DELETE FROM public.partner_commission_fee_transaction
WHERE partner_id = '82650a77-6238-49f0-92f3-c8a6a90eb0cd'::uuid
  AND account_id = '61dd8fcc-50af-4360-b31c-e64633cdaf94'::uuid
  AND source_id LIKE 'mock-%';

INSERT INTO public.partner_commission_fee_transaction (
    id,
    remarks,
    create_time,
    update_time,
    version,
    account_id,
    transaction_id,
    source_id,
    fee_name,
    deduction_node,
    rate_type,
    transaction_country,
    direction,
    amount,
    rate,
    fee,
    is_settled,
    markup_fee,
    markup_rate,
    partner_id,
    status,
    total_fee,
    total_rate,
    commission_mode
)
WITH fee_names(fee_name) AS (
    VALUES
        -- Crypto assets
        ('CryptoAddressScanner'),
        ('CryptoCreationWallet'),
        ('CryptoCrossChainWithdraw'),
        ('CryptoDeposit'),
        ('CryptoFiatDeposit'),
        ('CryptoSwap'),
        ('CryptoWithdraw'),
        ('CryptoStablecoinTopUpSwap'),
        -- Quantum card
        ('QuantumCardVerificationFee'),
        ('SchemeFeeSignature'),
        ('QuantumCardActiveFee'),
        ('QuantumCardApplePayFee'),
        ('QuantumCardSettlementFee'),
        ('SchemeServiceFee'),
        ('QuantumCardATMFee'),
        ('SchemeSettlementFee'),
        ('QuantumCardCrossBorderBaseFee'),
        ('AccountDeposit'),
        ('QuantumCardOpenFee'),
        ('SchemeRefundFee'),
        ('QuantumCardFxFee'),
        ('QuantumCardMetalMakeCardFee'),
        ('QuantumCardCeramicMakeCardFee'),
        ('SchemeVRMFee'),
        ('SchemeAuthFee'),
        ('QuantumCardRefundFee'),
        ('QuantumCardCrossBorderFee'),
        ('DeclineFee'),
        ('QuantumCardRefundCustomerRefundFee'),
        ('SchemeReversalFee'),
        ('SchemeVerificationFee'),
        ('QuantumCardMakeCardFee'),
        ('QuantumCardShoppingFee'),
        ('QuantumCardNotActiveFee'),
        ('QuantumCardReversalFee'),
        ('QuantumCardAuthorizationFee'),
        ('QuantumCardFxPassThroughFee'),
        -- Global account
        ('InternationalCharging'),
        ('GlobalInbound2'),
        ('GlobalInboundCurrencyOther'),
        ('GlobalTransferIn'),
        ('GlobalAccountCreateFee'),
        ('GlobalInboundCurrencyMain'),
        ('GlobalAchInbound'),
        ('GlobalVrnMonthFee'),
        ('GlobalAccountToQbitWallet'),
        ('GlobalAccountTransferFee'),
        ('GlobalAccountMaxOpenCount')
), modes(commission_mode, mode_index) AS (
    VALUES
        ('BasePriceMarkup', 1),
        ('FlexibleMarkup', 2)
), mock_rows AS (
    SELECT
        f.fee_name,
        m.commission_mode,
        row_number() OVER (ORDER BY f.fee_name, m.mode_index) AS row_no
    FROM fee_names f
    CROSS JOIN modes m
)
SELECT
    abs(hashtextextended(concat(
        'mock-partner-commission:',
        '82650a77-6238-49f0-92f3-c8a6a90eb0cd:',
        '61dd8fcc-50af-4360-b31c-e64633cdaf94:',
        fee_name, ':', commission_mode
    ), 0))::bigint AS id,
    'mock partner commission fee transaction' AS remarks,
    DATE '2026-08-01'
        + ((row_no % 20) * interval '1 day')
        + ((row_no % 60) * interval '1 minute') AS create_time,
    DATE '2026-08-01'
        + ((row_no % 20) * interval '1 day')
        + ((row_no % 60) * interval '1 minute') AS update_time,
    1 AS version,
    '61dd8fcc-50af-4360-b31c-e64633cdaf94'::uuid AS account_id,
    NULL::uuid AS transaction_id,
    concat('mock-', fee_name, '-', lower(commission_mode)) AS source_id,
    fee_name,
    'monthly' AS deduction_node,
    'percentage' AS rate_type,
    'ALL' AS transaction_country,
    'debit' AS direction,
    (1000 + row_no * 10)::numeric(20, 12) AS amount,
    0.010000000000::numeric(20, 12) AS rate,
    (10 + row_no)::numeric(20, 12) AS fee,
    false AS is_settled,
    CASE commission_mode
        WHEN 'BasePriceMarkup' THEN (20 + row_no)::numeric(20, 12)
        ELSE (30 + row_no)::numeric(20, 12)
    END AS markup_fee,
    CASE commission_mode
        WHEN 'BasePriceMarkup' THEN 0.002000000000::numeric(20, 12)
        ELSE 0.003000000000::numeric(20, 12)
    END AS markup_rate,
    '82650a77-6238-49f0-92f3-c8a6a90eb0cd'::uuid AS partner_id,
    'Success' AS status,
    CASE commission_mode
        WHEN 'BasePriceMarkup' THEN (30 + row_no)::numeric(20, 12)
        ELSE (40 + row_no)::numeric(20, 12)
    END AS total_fee,
    CASE commission_mode
        WHEN 'BasePriceMarkup' THEN 0.012000000000::numeric(20, 12)
        ELSE 0.013000000000::numeric(20, 12)
    END AS total_rate,
    commission_mode
FROM mock_rows
ON CONFLICT (id) DO NOTHING;

-- 校验 Mock 数据：应返回每种模式各 48 条（按当前 FeeTemplateNameEnum 中三条业务线）。
SELECT commission_mode, count(*) AS row_count, sum(markup_fee) AS commission_amount
FROM public.partner_commission_fee_transaction
WHERE source_id LIKE 'mock-%'
  AND account_id = '61dd8fcc-50af-4360-b31c-e64633cdaf94'::uuid
GROUP BY commission_mode
ORDER BY commission_mode;
