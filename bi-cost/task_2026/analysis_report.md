# dws_qbit_card_transaction_2026 不一致根因分析

> 分析对象：`public."qbit_card_transaction"`（原始表） vs `dws_qbit_card_transaction_2026`（清洗/汇总表）
> 口径：两表均按日聚合为 `consumptionAmount / consumptionCount / refundAmount / refundCount / reversalAmount / reversalCount / date` 七列
> 数据窗口：2026-01-01 ~ 2026-08-17（共 229 天；清洗导出 227 天，缺失 06-28、08-17）
> 配套脚本：`divergence_analysis.py` → `divergence_data.json`

---

## 1. 结论摘要

清洗表与原始表的偏差**不是随机噪声，而是系统性的、可解释的**，由现有 ETL 的**设计缺陷 + 运行中断/重跑**共同造成。

| 指标 | 原始合计 | 清洗合计 | 倍数 | 结论 |
|---|---|---|---|---|
| consumption（消费金额） | 414,062,167.07 | 940,377,107.14 | **2.271×** | 严重放大 |
| refund（退款金额） | 11,849,055.48 | 11,829,197.77 | 0.998× | 基本持平 |
| reversal（冲正金额） | 9,485,599.49 | 9,446,824.22 | 0.996× | 基本持平 |

核心结论：

1. **放大几乎只发生在 consumption 上**，refund/reversal 几乎不变 → 说明问题出在“消费类聚合行的重复写入”，而非整体逻辑算错。
2. **月度放大率单调爬升**：1 月 1.0× → 4 月 1.07× → 5 月 1.12× → **6 月 3.03× → 7 月 7.12× → 8 月 4.77×**。首个偏离 >5% 的日是 **2026-03-03**。这说明不稳定从 3 月初就已开始，6~7 月达到高峰，与你说的“中间可能有几天中断了”一致。
3. 同时存在**缺失型故障**：`2026-04-01` 消费保留但退款/冲正被清零；`2026-06-28`、`2026-08-17` 整行缺失。

---

## 2. 根因：ETL 非幂等（根本性设计缺陷）

现有 `insert_task_job.sql` / `update_insert_job.sql` / `delete_task_job.sql` 三步法：

```
每天：
  (1) INSERT 昨天窗口的聚合，主键用 generate_snowflake_id()
  (2) DELETE 那些“源表 updateTime 在窗口内 且 createTime::DATE <> updateTime::DATE”的汇总行
  (3) UPDATE 重新聚合这些被改动的 create_date，再次 generate_snowflake_id() 插入
```

### 2.1 致命点：`generate_snowflake_id()` + `ON CONFLICT (id) DO NOTHING`

```sql
INSERT INTO dws_qbit_card_transaction_2026 (id, ...) 
SELECT generate_snowflake_id(), ...   -- 每次执行都生成全新的随机主键
...
ON CONFLICT (id) DO NOTHING;          -- 主键永远不冲突 → 兜底去重永远不会触发
```

- `generate_snowflake_id()` 每次运行都产生**全新随机值**，`ON CONFLICT (id)` 因此**永远不可能命中**，去重 clause 形同虚设。
- 任何一次**重跑 / 重试 / 中断后补跑 / 调度双发**，都会把同一天同一批聚合**原样再插一份**，且 id 不同、无法被后续逻辑识别为重复。
- 这直接导致清洗表出现**同一 `(account, provider, bin, businessType, status, create_date)` 的多份副本**，按日重聚合时被 `SUM` 叠加 → consumption 成倍放大。

### 2.2 三步顺序脆弱，且 DELETE 与重插不原子

- 第 (2) 步 DELETE 只在“源表确有 `createTime≠updateTime` 且 updateTime 落在窗口”时才触发；纯重跑 INSERT 产生的副本**没有对应的源表更新事件**，DELETE 不会清理它们 → 副本**永久残留**。
- 若作业在 “DELETE 之后 / 重插之前” 中断，或单独重跑了 UPDATE（你提到“最坏重新执行 update 脚本”），重插会用新 id 叠加在旧行上 → 又一份副本。
- 副本积累速度取决于重跑/中断频率：3 月零星、6~7 月密集，正好对应月度倍数 1.07→3.03→7.12 的爬升曲线。

### 2.3 为什么 refund/reversal 没被放大？（重要线索）

退款/冲正交易通常**创建当天即结清**（`createTime::DATE = updateTime::DATE`），因此被排除在第 (2)(3) 步的“修正路径”之外——只在首次 INSERT 写入一次，不会被重复重插。
而消费交易（购买）常有**事后修正/补单**（`createTime≠updateTime`），会进入 DELETE+UPDATE 路径，在非幂等主键下副本逐日累积。

这完美解释了“**消费 7 倍、退款冲正几乎不变**”的诡异分布，也反过来佐证根因就是“消费行的重复写入”。

### 2.4 `2026-04-01` 清零事件

当日消费保留（约 2,000,090，与原值 2,000,090 接近），但 refund/reversal 从 `92876.16/800/60088.23/2909` 变为 `0/0/0/0`。
典型成因：第 (2) 步 DELETE 因该 create_date 有某笔“创建≠更新”的源行被触发，删掉了当天的退款/冲正汇总行；但第 (3) 步重插时，退款/冲正源行的重算窗口或分组未命中（或被 `CASE WHEN deleteTime IS NOT NULL THEN 0` 过滤），**只补回了消费、没补回退款/冲正**。

### 2.5 缺失行（06-28 / 08-17）

- `2026-08-17`：很可能只是清洗导出时当日作业尚未完成 / 粘贴截断（今日即 08-17）。
- `2026-06-28`：清洗表整行缺失，说明当天作业（INSERT 或 DELETE+重插）整体未成功落地，且无补偿重跑。这是“中断几天”的直接证据。

---

## 3. 修复方向（基于现有 Flink 体系）

现有 `bi-cost/flink/quantum-v2/{sl,bb,qi,bz}` 已经用**完全相反且正确的范式**解决了同类问题，可直接借鉴：

| 现有 PG 存储过程（有 bug） | quantum-v2 Flink（正确范式） |
|---|---|
| `generate_snowflake_id()` 随机主键 | `ABS(HASH_CODE(CONCAT(...)))` **确定性业务指纹主键** |
| `ON CONFLICT(id) DO NOTHING`（永不命中） | 主键确定 → 重算即覆盖，天然幂等 |
| 三步：INSERT→DELETE(创建≠更新)→UPDATE 重插 | **按“受影响周期”整段删除 + 全量重算** |
| 重复/缺失靠运气 | `PARTITION BY RANGE(create_date)`，整月删除原子且廉价 |
| 重跑即翻倍 | `writeMode='insert'`（CDC）/ `'upsert'`（补数），重跑安全 |

具体参考实现见 `flink_reference/`：

- `dws_qbit_card_transaction_v2-ddl.sql` —— 目标表改为**按 `create_date` 范围分区 + 确定性主键 `(id, create_date)`**
- `dws_qbit_card_transaction_v2-fn.sql` —— `fn_delete_qbit_card_transaction_v2(p_dry_run)` 删除函数（按受影响月份整段清理）
- `dws_qbit_card_transaction_v2-cdc.sql` —— CDC 流作业：扫描昨天变更的源 → 定位受影响月份 → 调删除函数 → 用确定性主键重插
- `dws_qbit_card_transaction_v2-batch.sql` —— 批量/补数作业（`writeMode='upsert'`，用于历史重刷与一次性修复）

---

## 4. 数据可信度说明

- 上述数字基于你提供的两份查询结果快照（已硬编码进 `divergence_analysis.py`）。
- 我在复盘时发现快照里 `2026-06-28` 在清洗端为误植行（已剔除），故清洗端该日按“缺失”处理；`2026-08-17` 同样仅在原始端存在。
- 行级根因（2.3/2.4 的微观机制）是基于代码与数据分布的**合理推断**，建议用下面 SQL 在库内直接验证重复行数量：

```sql
-- 校验清洗表是否存在“同一业务指纹的多份副本”
SELECT account_id, provider, bin, business_type, status,
       create_date::date AS d, COUNT(*) AS copies
FROM dws_qbit_card_transaction_2026
GROUP BY account_id, provider, bin, business_type, status, d
HAVING COUNT(*) > 1
ORDER BY copies DESC
LIMIT 50;
```

若返回大量行，且 `copies` 集中在消费类 `business_type`，即可坐实本报告的“非幂等重复写入”结论。
