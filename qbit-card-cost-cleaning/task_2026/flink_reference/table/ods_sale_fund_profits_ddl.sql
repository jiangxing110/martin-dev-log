-- [TODO] ods_sale_fund_profits 检测到嵌套/非标准 FROM（fund_profits AS tr
CROSS JOIN LATERAL js...），
--        删除函数的变更窗口与聚合子查询的源别名引用可能需要人工校准，上线前务必核对。
-- ods_sale_fund_profits DDL（IF NOT EXISTS，不重建现有表）
CREATE TABLE IF NOT EXISTS public.ods_sale_fund_profits_2024 (
    "id" BIGINT,,
    "fund_id" STRING,,
    "create_time" TIMESTAMP(6),,
    "update_time" TIMESTAMP(6),,
    "delete_time" TIMESTAMP(6),,
    "version" BIGINT,,
    "remarks" STRING,,
    "account_id" STRING,,
    "sale_or_am_id" STRING,,
    "product_id" STRING,,
    "date" DATE,,
    "currency" STRING,,
    "profit" DECIMAL(20,4),,
    "service_fee" DECIMAL(20,4),,
    "status" STRING,,
    "apr" DECIMAL(20,4),,
    "share" DECIMAL(20,4),,
    "net_value" DECIMAL(20,4)
);

CREATE TABLE IF NOT EXISTS public.ods_sale_fund_profits_2025 (
    "id" BIGINT,,
    "fund_id" STRING,,
    "create_time" TIMESTAMP(6),,
    "update_time" TIMESTAMP(6),,
    "delete_time" TIMESTAMP(6),,
    "version" BIGINT,,
    "remarks" STRING,,
    "account_id" STRING,,
    "sale_or_am_id" STRING,,
    "product_id" STRING,,
    "date" DATE,,
    "currency" STRING,,
    "profit" DECIMAL(20,4),,
    "service_fee" DECIMAL(20,4),,
    "status" STRING,,
    "apr" DECIMAL(20,4),,
    "share" DECIMAL(20,4),,
    "net_value" DECIMAL(20,4)
);

CREATE TABLE IF NOT EXISTS public.ods_sale_fund_profits_2026 (
    "id" BIGINT,,
    "fund_id" STRING,,
    "create_time" TIMESTAMP(6),,
    "update_time" TIMESTAMP(6),,
    "delete_time" TIMESTAMP(6),,
    "version" BIGINT,,
    "remarks" STRING,,
    "account_id" STRING,,
    "sale_or_am_id" STRING,,
    "product_id" STRING,,
    "date" DATE,,
    "currency" STRING,,
    "profit" DECIMAL(20,4),,
    "service_fee" DECIMAL(20,4),,
    "status" STRING,,
    "apr" DECIMAL(20,4),,
    "share" DECIMAL(20,4),,
    "net_value" DECIMAL(20,4)
);

CREATE TABLE IF NOT EXISTS public.ods_sale_fund_profits_2027 (
    "id" BIGINT,,
    "fund_id" STRING,,
    "create_time" TIMESTAMP(6),,
    "update_time" TIMESTAMP(6),,
    "delete_time" TIMESTAMP(6),,
    "version" BIGINT,,
    "remarks" STRING,,
    "account_id" STRING,,
    "sale_or_am_id" STRING,,
    "product_id" STRING,,
    "date" DATE,,
    "currency" STRING,,
    "profit" DECIMAL(20,4),,
    "service_fee" DECIMAL(20,4),,
    "status" STRING,,
    "apr" DECIMAL(20,4),,
    "share" DECIMAL(20,4),,
    "net_value" DECIMAL(20,4)
);
