# BB 月度全量重算与阶梯 Volume Fee 设计方案

## 摘要

当前 BB CDC 通过 `changed_keys` 找出最近变更的 `report_date + account_id`，删除 DWS 旧结果后重新读取对应客户/日期的交易明细。该流程在删除数据较多或客户当日交易量较大时，会触发大量 JDBC 结果回传，导致 TaskManager 长时间处于无响应状态并发生 heartbeat timeout。

本方案将 BB 的历史重算改为按月全量执行，范围从 2026-01-01 开始；截至 2026-08-23 时，先处理 2026-01-01 至 2026-08-01 的 7 个完整自然月，再处理 2026-08-01 至 2026-08-23 00:00:00 的当前月已完成日期。月度 BB 主链路完成后，再依次执行 active card 和固定成本脚本。返现 rate 统一从 `ods.ods_bi_month_tag` 读取。Volume Fee 按 BB 月度总净消费计算一次阶梯总费用，再按普通客户行的净消费占比分摊到每天；`ACTIVE_CARD` 和固定成本特殊行不参与分摊。

## 目标

1. 降低删除数据触发局部重算时的 JDBC 大结果集和 TaskManager heartbeat timeout 风险。
2. 支持从 2026-01-01 起按自然月逐月重建 BB DWS 数据，并将当前月截断到当天 00:00:00。
3. 将 BB/QI 返现 rate 的来源统一为 `ods.ods_bi_month_tag`。
4. 按月度总净消费计算 BB 阶梯 Volume Fee，并按普通客户净消费分摊到日粒度。
5. 为 QI DWS 财务表增加净消费字段，便于统一下游成本分析口径。

## 非目标

1. 本方案不改变 transaction/auth 原始明细的业务口径。
2. 本方案不删除或修改 `ACTIVE_CARD`、固定成本特殊行的独立脚本逻辑，只调整执行顺序和分摊排除范围。
3. 本方案不在日常在线 CDC 中直接执行整张 DWS 表的 `TRUNCATE`。
4. 本方案不把 volume fee 的月度总费用重复按天套用阶梯费率。

## 当前问题

当前 BB CDC 的依赖关系如下：

```text
最近更新/删除的 DWM 数据
        ↓
changed_keys(report_date, account_id)
        ↓
删除 dws_bb_card_finance_daily_v2_p 旧普通行
        ↓
按 account_id + 日期重新读取全部 transaction/auth 明细
        ↓
重新聚合并写入 DWS
```

删除记录本身不会直接删除 DWM 明细，但 `delete_time` 会进入 `changed_keys`，使对应客户/日期的全部剩余明细再次读取。transaction source 返回大量明细时，PostgreSQL 出现 `ClientWrite`，Flink TaskManager 可能无法及时响应 JobMaster heartbeat。

## 推荐方案

### 方案 A：按月全量重算（推荐）

将当前 CDC SQL 改造成带时间窗口参数的重算 SQL。窗口按半开区间执行：

```text
-- 完整月份示例
${start_time} = 2026-01-01 00:00:00
${end_time}   = 2026-02-01 00:00:00

-- 当前日期为 2026-08-23 时的最后一个窗口
${start_time} = 2026-08-01 00:00:00
${end_time}   = 2026-08-23 00:00:00
```

处理窗口如下：

```text
[2026-01-01 00:00:00, 2026-02-01 00:00:00)
[2026-02-01 00:00:00, 2026-03-01 00:00:00)
...
[2026-07-01 00:00:00, 2026-08-01 00:00:00)
[2026-08-01 00:00:00, 2026-08-23 00:00:00)
```

前 7 个窗口是完整自然月，最后一个窗口是当前月截至当天零点的已完成数据，不包含 2026-08-23 当天。

每次只处理半开区间：

```sql
report_date >= CAST('${start_time}' AS DATE)
AND report_date < CAST('${end_time}' AS DATE)
```

每个月的执行顺序：

```text
1. 清理当前月份 DWS 普通行
2. 全量读取当前月份 transaction/auth
3. 写入 BB 普通财务行
4. 执行 active card 脚本
5. 执行 fixed fee 脚本
6. 校验当前月份行数、净消费和成本汇总
```

清理范围只允许是当前月份，并且只清理普通行；`ACTIVE_CARD`、固定成本等特殊行由后续脚本负责生成。

### 方案 B：继续 CDC，降低 fetch-size

仅调整 `scan.fetch-size` 只能降低单次 JDBC 拉取批次，不能减少重算范围，也不能消除 `changed_keys` 的重复扫描。该方案作为短期缓解，不作为最终方案。

### 方案 C：全表清空后一次性全量重建

实现最简单，但失败时会导致正式 DWS 表为空或不完整，且会把历史所有月份一次性读入，当前 JDBC/TaskManager 问题下风险最高，不采用。

## BB 月度数据流

### 1. 月度 transaction/auth source

移除 CDC 专用的最近一天变更过滤和嵌套 `changed_keys` 查询，改为直接使用月度边界过滤：

```sql
WHERE delete_time IS NULL
  AND transaction_time >= CAST('${start_time}' AS TIMESTAMP)
  AND transaction_time < CAST('${end_time}' AS TIMESTAMP)
```

实际 transaction 需要覆盖 `transaction_time`、`original_completion_time`、`settlement_post_date` 三种报表日期；auth 使用 `auth_time`。三种日期分别取数后再按现有 `metric_basis` 逻辑聚合，避免漏掉跨字段变更的记录。

### 2. 月度清理

新增或复用按月清理函数，函数必须满足：

```text
- 只删除当前 start_time/end_time 范围内的数据；
- 只删除 special_fee_type 为空的普通行；
- 保留 ACTIVE_CARD 和固定成本特殊行，或在 active/fixed 脚本前明确清理并重建；
- 返回 affected_rows 仅用于日志/校验，不再作为大范围 CDC 重算触发器。
```

不再使用最近一天 `update_time/delete_time` 推导重算范围。

## 返现 rate

BB 和 QI 的月度 rate 均从 `ods.ods_bi_month_tag` 读取，按产品线、标签和统计月份匹配。实现时沿用 QI 已有的字段映射模式，并明确：

```text
- product_line = 对应产品线；
- tag = 对应 rate 标签；
- statistics_time 落在当前重算月份；
- delete_time IS NULL；
- 缺失 rate 时使用 0，并在校验结果中告警。
```

具体 tag 名称必须以当前 `ods_bi_month_tag` 实际数据为准，不能在 SQL 中硬编码未经确认的名称。

## Volume Fee 口径

### 月度阶梯总费用

对 BB 当前月份所有普通客户行的净消费求和：

```sql
month_total_net_amount = SUM(total_net_amount)
```

阶梯总费用：

```sql
CASE
    WHEN month_total_net_amount = 0 THEN 0
    WHEN month_total_net_amount <= 5000000
        THEN month_total_net_amount * 0.0055
    WHEN month_total_net_amount <= 10000000
        THEN 5000000 * 0.0055
           + (month_total_net_amount - 5000000) * 0.0045
    ELSE 5000000 * 0.0055
       + 5000000 * 0.0045
       + (month_total_net_amount - 10000000) * 0.004
END AS month_volume_fee_cost
```

例如月度净消费 16,000,000：

```text
5,000,000 × 0.0055
+ 5,000,000 × 0.0045
+ 6,000,000 × 0.004
= 74,000
```

### 按客户/日期分摊

普通客户每日分摊金额：

```sql
total_net_amount / month_total_net_amount
    * month_volume_fee_cost
```

分摊时：

```text
- 分子：当前普通客户当天 total_net_amount；
- 分母：BB 当前月份普通客户 total_net_amount 总和；
- 特殊行不参与分母；
- 月度分摊结果四舍五入后，需要增加月度尾差校验；
- 所有普通客户行 volume_fee_cost 之和必须等于 month_volume_fee_cost（允许最后一行吸收小数尾差）。
```

建议保留 `month_total_net_amount` 和 `month_volume_fee_cost` 中间字段或月度校验结果，方便排查分摊差异。

## QI 净消费字段

修改：

```text
flink/quantum-v2/qi/table-scripts/dws_qi_card_finance_daily_v2_p.sql
```

增加净消费字段，字段名暂定为：

```sql
net_consumption numeric(20,4) DEFAULT 0
```

最终字段名需要与 BB 当前 `total_net_amount` 的下游命名规范统一；如果下游要求统一比较，优先使用 `total_net_amount`，避免同时存在两个含义接近的字段。

## 执行与失败恢复

1. 每个时间窗口独立提交任务，任务失败只影响当前窗口。
2. 不直接清空整张正式 DWS 表。
3. 当前窗口的清理和写入必须使用同一组 `start_time/end_time` 参数；完整月使用自然月边界，当前月使用当天 00:00:00 作为 `end_time`。
4. 当前月份写入完成后，先执行校验，再执行 active card 和 fixed fee。
5. active/fixed 脚本失败时，BB 普通行保留，但该月份标记为未完成，不进入下一个月。
6. 重跑同一个窗口必须幂等：先清理该窗口普通行，再重新插入。

## 校验标准

每个月至少校验：

```sql
-- 月度净消费
SELECT
    DATE_TRUNC('month', report_date)::date AS month_start,
    SUM(total_net_amount) AS total_net_amount,
    SUM(volume_fee_cost) AS volume_fee_cost
FROM dws.dws_bb_card_finance_daily_v2_p
WHERE report_date >= CAST('${start_time}' AS DATE)
  AND report_date < CAST('${end_time}' AS DATE)
  AND COALESCE(special_fee_type, '') = ''
GROUP BY 1;
```

并确认：

1. `SUM(volume_fee_cost)` 与阶梯公式计算的月度费用一致。
2. 特殊行不进入 volume fee 分母。
3. 普通行、active card、fixed fee 行数量符合预期。
4. 返现 rate 能从 `ods_bi_month_tag` 找到且月份匹配。
5. QI 新增净消费字段的月度汇总与现有净消费口径一致。

## 影响文件

计划修改：

1. `flink/quantum-v2/bb/cdc/dws_online_bb_card_finance_daily_v2-cdc-v2-sql.sql`
2. BB active card 月度/重算脚本（具体文件待确认）
3. BB fixed fee 月度/重算脚本（具体文件待确认）
4. `flink/quantum-v2/qi/table-scripts/dws_qi_card_finance_daily_v2_p.sql`
5. `ods_bi_month_tag` rate 配置或维护 SQL（具体文件待确认）

## 待确认项

1. QI 净消费字段最终命名：`net_consumption` 还是统一使用 `total_net_amount`。
2. BB 和 QI 在 `ods_bi_month_tag` 中实际使用的 product_line/tag 值。
3. active card 与 fixed fee 的现有脚本文件路径和参数形式。
4. 月度 volume fee 尾差由哪一条普通客户行吸收；建议使用排序后的最后一条有效普通客户行。
