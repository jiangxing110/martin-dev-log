# 分区表查询优化指南

## 背景

`qbit_card_transaction` 是按季度分区的大表，直接查询主表会扫描所有分区，性能较差。

## 优化方案

### 1. 辅助函数（partition_helper_functions.sql）

提供三个辅助函数，帮助快速生成分区表 UNION ALL 查询：

#### 函数列表

| 函数名 | 用途 |
|--------|------|
| `get_partition_table_name(date)` | 根据日期获取分区表名 |
| `generate_partition_union(start_date, end_date)` | 生成完整的 UNION ALL 查询 |
| `get_partition_tables(start_date, end_date)` | 列出涉及的分区表 |
| `generate_flink_partition_union(start_date, end_date)` | 生成 Flink SQL 格式的 UNION ALL 片段 |

#### 使用示例

```sql
-- 1. 查看某个日期属于哪个分区
SELECT get_partition_table_name('2026-05-15');
-- 输出: qbit_card_transaction_2026q2

-- 2. 查看日期范围内涉及的所有分区表
SELECT * FROM get_partition_tables('2026-01-15', '2026-12-31');
-- 输出:
-- partition_table
-- -------------------------------
-- qbit_card_transaction_2026q1
-- qbit_card_transaction_2026q2
-- qbit_card_transaction_2026q3
-- qbit_card_transaction_2026q4

-- 3. 生成 Flink SQL 格式的 UNION ALL 片段
SELECT generate_flink_partition_union('2026-01-15', '2026-06-20');
-- 输出:
--             -- 2026q1
--             SELECT * FROM "qbit_card_transaction_2026q1"
--             UNION ALL
--             -- 2026q2
--             SELECT * FROM "qbit_card_transaction_2026q2"
```

### 2. 优化版 Flink SQL（03_dws_qbit_card_transaction_v2-batch-sql-optimized.sql）

直接查询分区表，避免主表扫描：

```sql
CREATE TEMPORARY TABLE source_dws_qbit_card_transaction (...) WITH (
    'connector' = 'jdbc',
    'url' = '...',
    'table-name' = '(WITH affected AS (
        SELECT DISTINCT tr."accountId" AS k0, ...
        FROM (
            -- 直接 UNION ALL 分区表，只查询涉及的分区
            SELECT * FROM "qbit_card_transaction_2026q1"
            UNION ALL
            SELECT * FROM "qbit_card_transaction_2026q2"
            UNION ALL
            SELECT * FROM "qbit_card_transaction_2026q3"
            UNION ALL
            SELECT * FROM "qbit_card_transaction_2026q4"
        ) AS tr
        ...
    ) ...'
    ...
);
```

## 使用步骤

### Step 1: 部署辅助函数

```bash
psql -h <host> -U <user> -d <database> -f partition_helper_functions.sql
```

### Step 2: 生成分区 UNION 查询

```sql
-- 假设要处理 2026-01-01 到 2026-06-30 的数据
SELECT generate_flink_partition_union('2026-01-01', '2026-06-30');
```

复制输出结果，粘贴到 `03_dws_qbit_card_transaction_v2-batch-sql-optimized.sql` 的两处位置：
- `WITH affected AS (...)` 子查询中的 `FROM (...) AS tr`
- 主查询中的 `FROM (...) AS tr`

### Step 3: 提交 Flink 作业

```bash
flink run -c org.apache.flink.streaming.api.environment.StreamExecutionEnvironment \
  -d \
  --start_date 2026-01-01 \
  --end_date 2026-06-30 \
  03_dws_qbit_card_transaction_v2-batch-sql-optimized.sql
```

## 性能对比

| 方案 | 扫描数据量 | 查询时间 | 说明 |
|------|-----------|---------|------|
| 查询主表 | 全部分区 | 慢 | 扫描 2020~2028 所有分区 |
| 查询指定分区 | 仅涉及分区 | 快 | 只扫描 2026q1~q2 |

## 注意事项

1. **分批执行**：建议按季度分批执行，避免单次跨过多分区
2. **日期对齐**：start_date/end_date 尽量对齐季度边界（如 2026-01-01, 2026-04-01）
3. **分区存在性**：执行前确认目标分区表已存在
4. **双重修改**：记得同时修改两处 UNION ALL（affected 子查询和主查询）

## 季度分区对应关系

| 日期范围 | 分区表 |
|---------|--------|
| 2026-01-01 ~ 2026-03-31 | qbit_card_transaction_2026q1 |
| 2026-04-01 ~ 2026-06-30 | qbit_card_transaction_2026q2 |
| 2026-07-01 ~ 2026-09-30 | qbit_card_transaction_2026q3 |
| 2026-10-01 ~ 2026-12-31 | qbit_card_transaction_2026q4 |

## 故障排查

### 问题：分区表不存在

**原因**：目标日期超出已创建分区范围

**解决**：检查分区表是否已创建，或联系 DBA 扩展分区

```sql
-- 查看所有分区表
SELECT tablename FROM pg_tables WHERE tablename LIKE 'qbit_card_transaction_%';
```

### 问题：数据量仍然很大

**原因**：单个分区数据量本身很大

**解决**：
1. 缩小日期范围（如按月分批）
2. 检查是否可以添加额外的过滤条件（如 `status`, `provider` 等）
3. 考虑添加物化视图或汇总表

## 相关文件

- [03_dws_qbit_card_transaction_v2-batch-sql-optimized.sql](./03_dws_qbit_card_transaction_v2-batch-sql-optimized.sql) - 优化版 Flink SQL
- [partition_helper_functions.sql](./partition_helper_functions.sql) - 辅助函数
- [README-partition-optimization.md](./README-partition-optimization.md) - 本文档