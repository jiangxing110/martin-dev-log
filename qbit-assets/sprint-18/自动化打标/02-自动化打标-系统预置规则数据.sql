-- 自动化打标：系统预置规则数据
-- CUSTOM 与 SYSTEM_PRESET 的 raw_data 均使用 TagRuleRawDTO JSON：{"logicTree":...}，由 rule_type 区分。
-- SYSTEM_PRESET 的 logicTree 使用 system_rule_code 条件节点作为规则目录路由；应用侧须按 rule_type 分流，并校验该编码与 rule_code 列一致。
-- 所有预置规则默认 Inactive；应用侧实现 system_rule_code 与枚举策略之前不得启用。
-- 本脚本只登记规则数据，不包含 ALTER TABLE 字段迁移；先执行 01-自动化打标-规则字段迁移.sql。
-- 目标路径已对照 qbit_test_core 活动末级标签导出结果，脚本仍会在路径不唯一时失败。

BEGIN;

CREATE TEMP TABLE _preset_rule_seed (
    rule_code text PRIMARY KEY,
    rule_name text NOT NULL,
    rule_description text NOT NULL,
    target_path text[] NOT NULL,
    condition_pending boolean NOT NULL DEFAULT false
) ON COMMIT DROP;

INSERT INTO _preset_rule_seed (rule_code, rule_name, rule_description, target_path, condition_pending) VALUES
('CUSTOMER_MODE_DIRECT', '合作模式-直客', '未标记为 API 客户时命中直客。', ARRAY['合作模式', '直客', '直客'], false),
('CUSTOMER_MODE_DISTRIBUTOR', '合作模式-API客户-Distributor', 'API 客户且合规选定对接模式为 Distributor。', ARRAY['合作模式', 'API客户', 'Distributor'], false),
('CUSTOMER_MODE_MOR', '合作模式-API客户-MOR', 'API 客户且合规选定对接模式为 MOR。', ARRAY['合作模式', 'API客户', 'MOR'], false),
('CUSTOMER_MODE_GATEWAY', '合作模式-API客户-Gateway', 'API 客户且合规选定对接模式为 Gateway。', ARRAY['合作模式', 'API客户', 'Gateway'], false),
('CUSTOMER_COMPLIANCE_CRYPTO', '合规分类-crypto', '加密资产 KYB 最新状态为通过。', ARRAY['合规分类', 'crypto'], false),
('CUSTOMER_COMPLIANCE_NON_CRYPTO', '合规分类-non-crypto', '加密资产 KYB 已有明确结果且状态不为通过；无记录或状态未知不命中。', ARRAY['合规分类', 'non-crypto'], false),
('CUSTOMER_VALUE_VIP', '客户价值分层-VIP', '卡净消费达到阈值或渠道毛利进入 QI/BB/BZ 汇总 Top10；窗口和指标口径待确认。', ARRAY['客户价值分层', 'VIP客户'], false),
('INDUSTRY_ECOM_PLATFORM_SELLER', '跨境电商-B2C零售-平台卖家', '全球账户 KYB 通过且主营业务为电商，平台字段命中平台卖家枚举，店铺审核通过。', ARRAY['跨境电商', 'B2C零售', '平台卖家'], false),
('INDUSTRY_ECOM_DTC', '跨境电商-B2C零售-DTC', '全球账户 KYB 通过且主营业务为电商，独立站平台或店铺域名命中特征，店铺审核通过。', ARRAY['跨境电商', 'B2C零售', 'DTC'], false),
('INDUSTRY_ECOM_HYBIRD', '跨境电商-B2C零售-Hybird', '同一客户同时存在审核通过的电商平台店铺和独立站店铺或域名。', ARRAY['跨境电商', 'B2C零售', 'Hybird'], false),
('INDUSTRY_ECOM_B2B_BUYER', '跨境电商-B2B-采购商', '全球账户 KYB 通过，主营业务为 B2B，主要用途包含向供货商或经销商付款。', ARRAY['跨境电商', 'B2B', '采购商'], false),
('INDUSTRY_ECOM_B2B_FACTORY', '跨境电商-B2B-外贸工厂', '全球账户 KYB 通过，主营业务为 B2B，行业属于货物贸易且主要用途包含收取海外客户款项。', ARRAY['跨境电商', 'B2B', '外贸工厂'], false),
('INDUSTRY_ECOM_LOGISTICS', '跨境电商-服务商-物流', '全球账户 KYB 通过，主营业务为出海服务，行业为物流运输或运输服务。', ARRAY['跨境电商', '服务商', '物流'], false),
('INDUSTRY_ECOM_SOFTWARE_SERVICE', '跨境电商-服务商-软件服务', '全球账户 KYB 通过，主营业务为出海服务，行业命中软件、数据管理或数字商品对应枚举。', ARRAY['跨境电商', '服务商', '软件服务'], false),
('INDUSTRY_DIGITAL_GAMING', '数娱与服务-数字内容-Gaming', '全球账户 KYB 通过且行业为网络游戏，或收单 KYB 通过且商品类型为游戏/虚拟物品。', ARRAY['数娱&服务', '数字内容', 'Gaming'], false),
('INDUSTRY_DIGITAL_LIVE_STREAMING', '数娱与服务-数字内容-直播', 'KYC 通过且业务信息命中直播关键词，或全球账户 KYB 通过且行业为媒体和互联网视频服务。', ARRAY['数娱&服务', '数字内容', '直播'], false),
('INDUSTRY_DIGITAL_CREATOR_ECONOMY', '数娱与服务-数字内容-创作者经济', 'KYC 通过且业务信息命中创作者经济关键词，或全球账户 KYB 通过且行业命中对应枚举。', ARRAY['数娱&服务', '数字内容', '创作者经济'], false),
('INDUSTRY_TECH_SOFTWARE_EXPORT', '数娱与服务-技术与软件-软件出海', 'KYC 通过，主营业务为出海服务，行业为软件和技术服务或软件销售。', ARRAY['数娱&服务', '技术&软件', '软件出海'], false),
('INDUSTRY_TECH_ADVERTISING', '数娱与服务-技术与软件-广告营销', 'KYC、全球账户 KYB 或量子卡 KYB 的广告行业/消费目的条件命中。', ARRAY['数娱&服务', '技术&软件', '广告营销'], false),
('INDUSTRY_WEB3_EXCHANGE', 'Fintech&Web3-Web3/Crypto-交易所', 'KYC 通过且主营业务为 Web3/数字货币相关，业务描述命中交易所关键词。', ARRAY['Fintech&Web3', 'Web3/Crypto', '交易所'], false),
('INDUSTRY_WEB3_WALLET_PROVIDER', 'Fintech&Web3-Web3/Crypto-Wallet Provider', 'KYC 通过且主营业务为 Web3/数字货币相关，业务描述命中钱包关键词。', ARRAY['Fintech&Web3', 'Web3/Crypto', 'Wallet Provider'], false),
('INDUSTRY_WEB3_DEFI', 'Fintech&Web3-Web3/Crypto-DeFi', 'KYC 通过且主营业务为 Web3/数字货币相关，业务描述命中 DeFi 等关键词。', ARRAY['Fintech&Web3', 'Web3/Crypto', 'Defi'], false),
('INDUSTRY_FINANCE_PSP', 'Fintech&Web3-传统金融-PSP', 'KYC 条件命中且业务描述包含 PSP、支付服务商等关键词。', ARRAY['Fintech&Web3', '传统金融', 'PSP'], false),
('INDUSTRY_FINANCE_INVESTOR', 'Fintech&Web3-传统金融-投资机构', 'KYB/新增业务场景主营业务或业务描述命中投资机构条件。', ARRAY['Fintech&Web3', '传统金融', '投资机构'], false),
('INDUSTRY_FINANCE_BANK', 'Fintech&Web3-传统金融-银行', 'KYC 通过且主营业务符合范围，业务描述命中银行或信托关键词。', ARRAY['Fintech&Web3', '传统金融', '银行'], false),
('INDUSTRY_PLATFORM_CROWDFUNDING', '平台型企业-平台-众筹平台', '全球账户 KYB 或新增店铺的平台字段命中 Kickstarter/Indiegogo。', ARRAY['平台型企业', '平台', '众筹平台'], false),
('INDUSTRY_PLATFORM_FREELANCE', '平台型企业-平台-自由职业者平台', 'KYC 通过且主营业务符合范围，业务描述命中自由职业者平台关键词。', ARRAY['平台型企业', '平台', '自由职业者平台'], false),
('INDUSTRY_PLATFORM_DISTRIBUTION', '平台型企业-平台-分销平台', 'KYB/业务描述关键词规则；动态 API/分账频次规则阈值与窗口待确认。', ARRAY['平台型企业', '平台', '分销平台'], false),
('PRODUCT_BANK_PORTAL', '产品类型-账户服务-银行账户-Bank Portal', '全球账户 KYB 通过且客户为非 API 客户。', ARRAY['账户服务', '银行账户', 'Bank Portal'], false),
('PRODUCT_BAAS', '产品类型-账户服务-银行账户-BaaS', 'Admin 开通产品标记为 BaaS 且客户为 API 客户。', ARRAY['账户服务', '银行账户', 'Baas'], false),
('PRODUCT_CARD_PORTAL', '产品类型-账户服务-发卡服务-Card Portal', '量子卡 KYB 通过且客户为非 API 客户。', ARRAY['发卡服务', '发卡解决方案', 'Card Portal'], false),
('PRODUCT_CAAS', '产品类型-账户服务-发卡服务-CaaS', 'Admin 开通产品标记为 CaaS 且客户为 API 客户。', ARRAY['发卡服务', '发卡解决方案', 'Caas'], false),
('PRODUCT_SCAN_TO_PAY', '产品类型-数字货币钱包-Scan to Pay', 'API onboarding/KYB 的 S2P 字段条件待确认。', ARRAY['账户服务', '钱包与支付', 'Scan to pay'], false),
('PRODUCT_FIAT_FX', '产品类型-财富管理-资金兑换-法币FX', '客户产生至少一笔成功法币与法币兑换；排除加密货币及稳定币。', ARRAY['资金兑换', '货币兑换', '法币FX'], false),
('PRODUCT_ON_OFF_RAMP', '产品类型-财富管理-资金兑换-On/Off Ramp', '客户产生至少一笔成功法币余额与稳定币兑换；币种账户分类映射待核实。', ARRAY['资金兑换', '货币兑换', 'On/ Off Ramp'], false),
('PRODUCT_CRYPTO_ACQUIRING', '产品类型-收单服务-商户收单-数币收单', '收单 KYB 通过且条件 2 待补齐；占位规则，禁止启用。', ARRAY['收单服务', '商户收单', '数币收单'], true),
('PRODUCT_INFINITY_LAUNCH', '产品类型-综合解决方案-行业集成-Infinity Launch', 'API onboarding 的 Infinity Launch 字段条件；字段路径和终态读取待核实。', ARRAY['综合解决方案', '行业集成', 'Infinity Launch'], false);

-- 从 system_tag 的 parent_id 还原全路径，并只接受活动末级标签。
-- 若目标标签路径不存在或重名，下面校验会抛错并回滚，不会部分写入。
CREATE TEMP TABLE _preset_rule_targets ON COMMIT DROP AS
WITH RECURSIVE tag_paths AS (
    SELECT id AS target_id,
           name AS target_name,
           parent_id,
           status AS target_status,
           delete_time AS target_delete_time,
           ARRAY[name::text] AS full_path
    FROM system_tag
    WHERE delete_time IS NULL
    UNION ALL
    SELECT child.target_id,
           child.target_name,
           parent.parent_id,
           child.target_status,
           child.target_delete_time,
           ARRAY[parent.name::text] || child.full_path
    FROM tag_paths child
    JOIN system_tag parent
      ON parent.id = child.parent_id
     AND parent.delete_time IS NULL
)
SELECT seed.rule_code,
       seed.rule_name,
       seed.rule_description,
       seed.target_path,
       seed.condition_pending,
       matches.target_id AS system_tag_id,
       COUNT(matches.target_id) OVER (PARTITION BY seed.rule_code) AS matched_count
FROM _preset_rule_seed seed
LEFT JOIN (
    SELECT path.target_id, path.full_path
    FROM tag_paths path
    WHERE (path.parent_id IS NULL OR path.parent_id = 0)
      AND path.target_status = 'Active'
      AND path.target_delete_time IS NULL
      AND NOT EXISTS (
          SELECT 1
          FROM system_tag child
          WHERE child.parent_id = path.target_id
            AND child.delete_time IS NULL
      )
) matches ON matches.full_path = seed.target_path;

DO $$
DECLARE
    invalid_count integer;
    invalid_codes text;
BEGIN
    SELECT COUNT(DISTINCT rule_code), STRING_AGG(DISTINCT rule_code, ', ')
      INTO invalid_count, invalid_codes
    FROM _preset_rule_targets
    WHERE matched_count <> 1 OR system_tag_id IS NULL;

    IF invalid_count > 0 THEN
        RAISE EXCEPTION '预置规则目标标签必须唯一且为活动末级标签，需核对 rule_code: %', invalid_codes;
    END IF;
END $$;

-- BaseV3 使用应用侧 ASSIGN_ID。此处显式取当前最大 ID 后顺序分配，并锁表避免并发插入冲突。
LOCK TABLE tag_auto_rule IN EXCLUSIVE MODE;

WITH next_id AS (
    SELECT COALESCE(MAX(id), 0) AS max_id
    FROM tag_auto_rule
), numbered AS (
    SELECT target.*,
           ROW_NUMBER() OVER (ORDER BY target.rule_code) AS row_number
    FROM _preset_rule_targets target
)
INSERT INTO tag_auto_rule (
    id,
    remarks,
    create_time,
    update_time,
    delete_time,
    version,
    rule_name,
    rule_description,
    system_tag_id,
    raw_data,
    status,
    data_range,
    operation_user_id,
    rule_type,
    rule_code
)
SELECT next_id.max_id + numbered.row_number,
       '系统预置规则；上线前需完成规则实现和业务验收',
       NOW(),
       NOW(),
       NULL,
       0,
       numbered.rule_name,
       numbered.rule_description,
       numbered.system_tag_id,
       jsonb_build_object(
           'logicTree', jsonb_build_object(
               'concatRelation', 'And',
               'children', jsonb_build_array(
                   jsonb_build_object(
                       'fieldName', 'system_rule_code',
                       'ruleMatch', '=',
                       'fieldValue', numbered.rule_code
                   )
               )
           )
       )::text,
       'Inactive',
       NULL,
       'SYSTEM_PRESET_SQL',
       'SYSTEM_PRESET',
       numbered.rule_code
FROM numbered
CROSS JOIN next_id
ON CONFLICT (rule_code) WHERE rule_code IS NOT NULL
DO UPDATE SET
    rule_name = EXCLUDED.rule_name,
    rule_description = EXCLUDED.rule_description,
    system_tag_id = EXCLUDED.system_tag_id,
    raw_data = EXCLUDED.raw_data,
    rule_type = EXCLUDED.rule_type,
    update_time = NOW();

-- 不覆盖已存在规则的 Active/Inactive 状态；重复执行仅同步规则定义及标签绑定。
COMMIT;

-- 执行后核对：
-- SELECT id, rule_code, rule_name, system_tag_id, status
-- FROM tag_auto_rule WHERE rule_type = 'SYSTEM_PRESET' AND delete_time IS NULL
-- ORDER BY rule_code;
