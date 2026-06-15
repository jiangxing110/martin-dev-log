# QbitCardTransaction SecondLabel 慢 SQL 分析

## 报警 SQL

```sql
SELECT ...
FROM "qbit_card_transaction" "QbitCardTransaction"
WHERE
  "businessType" IN ('Consumption', 'Credit', 'Refund')
  AND "updateTime" >= '2026-06-10 16:00:00.01+08'
  AND "secondLabel" IS NULL
  AND "deleteTime" IS NULL
LIMIT 1000
```

## SQL 来源

### 定时任务（主要来源）

**文件:** `src/modules/schedule/qbit-card/label.schedule.ts`
**执行频率:** 每 10 分钟 (`CronExpression.EVERY_10_MINUTES`)

```typescript
@Cron(CronExpression.EVERY_10_MINUTES, { timeZone: 'Asia/Shanghai' })
updateSecondLabel() {
  this.qbitCardTransactionSceneService.useSecondLabelRuleBySchedule();
}
```

### SQL 生成方法

**文件:** `src/modules/qbit-card/qbit-card/transaction-scene/qbit-card-transaction-scene.service.ts:1141`
**方法名:** `useSecondLabelRuleBySchedule(mins = 20)`
**默认窗口:** 过去 20 分钟

```typescript
public async useSecondLabelRuleBySchedule(mins = 20) {
  let qbitCardTxs: QbitCardTransaction[];
  let skip = 0;
  const take = 1000;
  while (
    (qbitCardTxs = await this.qbitCardTxRepo.find({
      where: {
        businessType: In([QbitCardTransactionTypeEnum.Consumption, QbitCardTransactionTypeEnum.Credit, QbitCardTransactionTypeEnum.Refund]),
        updateTime: MoreThanOrEqual(new Date(Date.now() - mins * 60 * 1000)),
        secondLabel: IsNull(),
      },
      skip,
      take,
    }))?.length > 0
  ) {
    skip += take;
    await this.useSecondLabelRuleByQbitCardTxList(qbitCardTxs);
  }
}
```

### 历史数据脚本（手动运行）

**文件:** `src/scripts/qbit-card/platform/secondLabel.ts:44`
**方法:** `run()` — 同样的 `skip/take` 分页模式，按 `createTime` 分段跑全量历史数据，仅在需要补标历史数据时手动执行。

## 相关实体

**文件:** `src/entity/qbit-card/qbit-card-transaction.entity.ts`
**表名:** `qbit_card_transaction`
**secondLabel 列定义:**

```typescript
@Field({ description: '二级标签', nullable: true })
@Column({ comment: '二级标签', nullable: true, default: '' })
secondLabel: string;
```

**现有索引（均不直接覆盖该查询）:**

| 索引 | 列 |
|------|----|
| 复合索引 1 | `accountId, provider, status, cardId, transactionTime, businessType` |
| 复合索引 2 | `accountId, cardId, status, transactionTime, provider, sourceId, transactionId` |
| 复合索引 3 | `displayStatus, businessType` |
| 复合索引 4 | `provider, status, businessType, released` |
| 单列索引 | `accountId`, `sourceId`, `transactionTime`, `transactionId`, `released`, `completeTime`, `updateTime`(继承自 Base) |

## 查询分析

### WHERE 条件

| 条件 | 索引覆盖情况 |
|------|-------------|
| `businessType IN ('Consumption','Credit','Refund')` | 部分复合索引包含 businessType，但无合适前导列 |
| `updateTime >= ...` | 有单列索引，但结合其他条件后优化器可能选择全表扫描 |
| `secondLabel IS NULL` | 无索引。PostgreSQL B-tree 对 NULL 的存储方式导致 IS NULL 条件效率低 |
| `deleteTime IS NULL` | 无索引（Base 类中 `deleteTime` 无 `@Index()`） |

### 慢的根因

1. **无匹配的复合索引:** 表中没有任何一个索引能同时覆盖 `businessType + updateTime + secondLabel` 三个条件，数据库只能全表扫描或走单列 `updateTime` 索引后回表大量过滤。

2. **`secondLabel IS NULL` 查询效率低:** `secondLabel` 默认值为 `''`（空字符串），即大部分行已有标签。NULL 的行应该是少数（待处理数据），但没有部分索引（partial index）来高效定位这些行。

3. **`skip` 分页效率递减:** TypeORM 的 `skip/take` 分页，随着 `skip` 值增大（1000, 2000, 3000...），数据库需要扫描并丢弃越来越多的行，越到后面越慢。当待处理数据量较大时影响明显。

4. **执行频率高:** 每 10 分钟执行一次，每次查 20 分钟窗口。如果这个窗口内有大量未打标的交易，会触发多次全表扫描或低效索引扫描。
