# QI 2026-07 月度 Rate Seed 方案

- Created Time: 2026-08-10 15:23:54
- Updated Time: 2026-08-10 15:30:45
- Status: 已评审并实现

## 摘要

新增独立 SQL，仅维护 `ods.ods_bi_month_tag` 中 QI 的 `2026-07` 月度 rate，不修改 `2026-01~06` 和 `DEFAULT_FALLBACK`。九项 rate 使用业务提供的真实数值，月份相关字段统一切换为 2026 年 7 月。

## 输入 Rate

| Tag | 2026-07 Rate |
|---|---:|
| `QI_COST_SERVICE_RATE` | 0.9720 |
| `QI_COST_ACS_REGULAR_RATE` | 0.9087 |
| `QI_COST_ACS_VIP_RATE` | 1.0880 |
| `QI_COST_VRM_RATE` | 1.3734 |
| `QI_COST_HK_REGULAR_RATE` | 1 |
| `QI_COST_HK_VIP_RATE` | 1 |
| `QI_COST_DCSF_RATE` | 1.1115 |
| `QI_REBATE_INTERCHANGE_RATE` | 0.9975 |
| `QI_REBATE_INCENTIVE_RATE` | 0.9975 |

## SQL 设计

1. 新文件：`month-tag/qi_bi_month_tag_seed_2026_07.sql`。
2. 事务内仅软删除 `provider='IQ'`、`product_line='QI'`、`account_type='fullCustomer'`、`detail='2026-07'` 且属于上述九个 tag 的有效旧行。
3. 插入行统一使用：
   - `statistics_time='2026-07-01 00:00:00+08'`
   - `detail='2026-07'`
   - `remarks='QI 2026-07 monthly rate seed'`
4. 使用新的固定 ID 段，避免与历史 seed 主键冲突。
5. 使用 Greenplum 兼容的独立 `UPDATE` / `INSERT`：固定 ID 已存在时更新并重新激活，不存在时插入；不使用 writable CTE 或 `ON CONFLICT`。
6. 脚本末尾提供只读校验 SQL，检查有效行数量为 9、tag 唯一、月份和 rate 正确。

## 风险与边界

- 不更新 `DEFAULT_FALLBACK`，避免七月配置影响其他未配置月份。
- 不改原 `qi_bi_month_tag_seed_2026_01_06.sql`，保留历史初始化脚本。
- 若目标库已存在与新 ID 相同的软删除记录，`NOT EXISTS` 会阻止插入，因此 ID 段必须先做静态唯一性检查。

## 验收标准

- 七月有效 QI rate 恰好 9 条。
- 九项值与业务输入完全一致。
- 一月至六月及 fallback 有效记录不发生变化。
- SQL 事务、软删除范围和幂等逻辑完整。
