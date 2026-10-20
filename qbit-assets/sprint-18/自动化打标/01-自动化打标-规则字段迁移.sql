-- 自动化打标：规则字段迁移
-- 仅新增来源类型与系统规则编码字段，并将历史数据标记为自定义规则。
-- 可重复执行；执行前先核对目标数据库的表结构及发布流程。

BEGIN;

ALTER TABLE tag_auto_rule
    ADD COLUMN IF NOT EXISTS rule_type varchar(32);

ALTER TABLE tag_auto_rule
    ADD COLUMN IF NOT EXISTS rule_code varchar(100);

UPDATE tag_auto_rule
SET rule_type = 'CUSTOM'
WHERE rule_type IS NULL;

ALTER TABLE tag_auto_rule
    ALTER COLUMN rule_type SET DEFAULT 'CUSTOM',
    ALTER COLUMN rule_type SET NOT NULL;

COMMENT ON COLUMN tag_auto_rule.rule_type IS '规则来源类型：SYSTEM_PRESET 系统预置，CUSTOM 自定义';
COMMENT ON COLUMN tag_auto_rule.rule_code IS '系统预置规则稳定编码；自定义规则为空';

CREATE UNIQUE INDEX IF NOT EXISTS uq_tag_auto_rule_rule_code
    ON tag_auto_rule (rule_code)
    WHERE rule_code IS NOT NULL;

COMMIT;
