# BB / QI / SL 渠道成本 v2 清洗方案

## 摘要

当前 BB、QI、SL 三个渠道的 DWS 成本表中都预留了 `cost_fixed_fee` 字段，但现有 Flink 脚本基本都写死为 `0`，没有真正完成月固定成本摊销。
同时，BB BI 侧已经给出新的 BB 成本规则，QI 的成本系数也需要从 `ods_bi_month_tag` 获取，SL 也需要补齐 batch / cdc 两套清洗链路。

本方案在不破坏现有生产表使用方的前提下，新增 `flink/quantum-v2` 版本脚本，统一按照 `account_id + report_date + sale_id + am_id` 粒度清洗 BB / QI / SL 渠道成本，并让成本系数、固定成本、渠道返现等月度参数从 `ods_bi_month_tag` 获取。

## 目标

1. 新增 BB / QI / SL 三个渠道的 v2 清洗脚本。
2. 每个渠道提供 batch 和 cdc 两套脚本。
3. 清洗粒度统一保持在 `account_id + report_date + sale_id + am_id`。
4. BB 不修改现有 `dws_bb_card_finance_daily_p` 表结构。
5. QI 可以新增成本基数、渠道返现基数字段。
6. SL 补齐 batch 和 cdc 两套链路。
7. `cost_fixed_fee` 不再固定写死为 `0`，改为从 `ods_bi_month_tag` 获取月固定成本后摊销。
8. 业务明细 batch 脚本按业务时间定向回刷，业务明细 cdc 脚本按业务源数据增量运行。
9. 固定成本回刷单独成链路，通过 `ods_bi_month_tag.update_time` 识别受影响月份，只负责 `cost_fixed_fee`。
10. 兼容软删除和硬删除场景，避免目标表残留历史成本。

## 非目标

1. 不直接改现有生产正在使用的 BB DWS 表结构。
2. 不在 DWS 层直接聚合到 master account。
3. 不把所有历史 SQL 一次性替换，先以 `v2` 脚本并行落地。
4. 不在脚本中继续保留 `job_action` 分支。
5. 不依赖阿里云 Flink 作业启动时必须输入变量来运行 cdc。

## 总体口径

### 1. 清洗粒度

BB / QI / SL 的 DWS 粒度统一为：

```text
account_id + report_date + sale_id + am_id
```

master account 维度不在清洗层提前聚合，后续报表或分析层可以基于 account 归属关系再汇总。

### 2. 月参数来源

成本系数、固定成本、渠道返现等月度参数统一从 `ods_bi_month_tag` 获取。

当存在多条同月同指标记录时，优先取当前有效且最新的一条：

```text
delete_time is null
order by update_time desc, statistics_time desc
```

### 3. 业务链路和固定成本链路拆分

v2 脚本拆成两类：

```text
业务明细链路：负责交易、结算、Auth、成本基数、返现基数等 DWM / DWS 清洗
固定成本链路：负责从 ods_bi_month_tag 读取月固定成本，并回刷 DWS.cost_fixed_fee
```

业务明细链路不默认扫描 `ods_bi_month_tag.update_time`。

业务明细 batch 使用业务时间窗口定向回刷，例如交易时间、结算时间或 report_date。

业务明细 cdc 按业务源表增量运行，不依赖作业启动时输入 `ods_bi_month_tag` 参数。

固定成本链路单独提供 batch / cdc：

```text
固定成本 batch：接收 start_time / end_time，只扫描 ods_bi_month_tag.update_time
固定成本 cdc：不要求传参，默认扫描昨天 ods_bi_month_tag.update_time
```

## `cost_fixed_fee` 方案

### 1. 字段定义

`cost_fixed_fee` 定义为：

```text
某渠道某月份的固定成本，在当月有效 DWS 明细粒度上的摊销金额
```

它不是 BB 的 `active_card_count`。

- `active_card_count` 是计费基数。
- `cost_fixed_fee` 是最终分摊到 DWS 行上的固定成本金额。

### 2. 数据来源

固定成本金额从 `ods_bi_month_tag` 按渠道、月份、固定成本类指标获取。

如果财务尚未录入正式数据，可以维护一条兜底记录。脚本只识别当前有效记录，不在 SQL 中写死兜底金额。

### 3. 单独回刷链路

固定成本不混在 BB / QI / SL 的主业务 CDC 脚本里处理，而是单独提供固定成本回刷脚本。

该脚本负责：

1. 根据 `ods_bi_month_tag.update_time` 找到固定成本变动月份。
2. 根据软删除记录找到需要清理的月份。
3. 根据源表和目标表对账找到硬删除影响月份。
4. 删除或覆盖目标 DWS 中对应月份、渠道的 `cost_fixed_fee`。
5. 重新按最新有效月固定成本计算并写回。

### 4. 摊销方式

第一版采用有效 DWS 行均摊：

```text
cost_fixed_fee = month_fixed_fee / month_valid_row_count
```

`month_valid_row_count` 为当月该渠道参与摊销的 DWS 明细行数量。

有效行建议满足：

1. `report_date` 属于该月份。
2. `account_id` 不为空。
3. 行上存在交易、结算、成本基数、返现基数、活跃卡等任一业务数据。

该口径适合月固定费、系统费、通道固定服务费等不应随交易金额波动的成本。

### 5. 后续可扩展摊销方式

如果后续业务确认某类固定成本应和金额或卡量强相关，可以扩展为：

1. 按交易金额占比摊销。
2. 按 active card / active account 占比摊销。
3. 按指定成本基数占比摊销。

第一版不引入多套摊销配置，避免口径过早复杂化。

## BB v2 方案

### 1. DWM 层

BB DWM 继续承接交易、结算清洗逻辑，同时新增 Auth 明细清洗链路。

BB 新规则中的交易基础表以 `quantum_card_transaction_extend` 为主源，而不是旧的 `qbitCardTransaction`。

由于旧 `dwm_bb_card_transaction_detail_p` 缺少 `source_id`、`card_transaction_id`、`business_code_list`、`detail`、`original_completion_time` 等新规则中间字段，v2 不直接复用旧 DWM 表，而是新增：

```text
dwm.dwm_bb_card_transaction_detail_v2_p
```

该表和旧表并行存在，避免影响生产旧链路。

交易 DWM 需要从 `quantum_card_transaction_extend` 读取：

1. `id`
2. `source_id`
3. `card_transaction_id`
4. `account_id`
5. `country`
6. `type`
7. `transaction_time`
8. `original_completion_time`
9. `business_code_list`
10. `remarks`
11. `card_id`
12. `detail`
13. `channel_provision`
14. `delete_time`

并关联 `qbitCard` 获取卡组织：

```text
qbitCard.id = quantum_card_transaction_extend.card_id
```

BB 交易过滤口径：

```text
channel_provision = 'BLUEBANC'
delete_time is null
type in ('Consumption', 'Credit')
qbitCard.type in ('Master', 'VISA')
detail not like 'AUTO CLASS CAR RENTAL%'
```

结算仍从 `qbitCardSettlement` 获取，并按 BlueBanc 规则关联：

```text
source_id = transactionId
card_transaction_id = qbitCardTransactionId
provider = 'BlueBancCard'
```

Auth 明细来源为月表：

```text
bb_card_auth_detail_yyyy-mm
```

由于 Auth 明细是月表，v2 新增稳定 DWM：

```text
dwm.dwm_bb_card_auth_detail_v2_p
```

Auth 月表存在时，单独运行 Auth batch 将该月数据导入稳定 DWM；如果某个月份对应 Auth 表不存在，则不运行 Auth 导入，对应月份 DWS 从 Auth DWM 取不到数据，相关字段自然按 0 处理，不阻塞交易 / 结算主链路。

### 2. DWS 层

BB DWS 表结构保持不变。

DWS 仍按：

```text
account_id + report_date + sale_id + am_id
```

聚合交易、结算、Auth、Decline、AC Decline、Active Card 等指标。

BB DWS 中的交易笔数、AC 验证、金额成本、Reversal、Refund 等指标优先基于 `quantum_card_transaction_extend + qbitCardSettlement` 的新规则计算。

现有 BB DWS 表没有单独的 AC Decline 字段，因此第一版不把 AC Decline 强行塞入其它字段。AC Decline 明细保留在 `dwm_bb_card_auth_detail_v2_p` 中，后续如果要在 DWS 承接，需要单独评估是否新增字段或由报表层直接读取 Auth DWM。

主业务 CDC 第一阶段先同步 BB v2 DWM。DWS 可以通过按受影响日期调度 batch 回刷落地，避免在 DWM 目标表暂未确认可稳定 CDC 订阅前强行引入 DWS CDC。

### 3. 新 BB 成本规则

BB BI 新规则中的 master customer 汇总不直接落入 DWS。

DWS 负责保留明细粒度指标，后续可在报表层按 master customer 聚合后复用 BI 规则。

## QI v2 方案

### 1. 成本系数

QI 的成本系数和阶梯规则从 `ods_account_fee` 获取，不再写死在 SQL 中。

建议在 `ods_account_fee` 中保留一条全局兜底记录，使用 `2022-01-01 00:00:00 ~ 2099-01-01 00:00:00` 覆盖所有月份。
当月存在正式配置时，优先取当月配置；当月没有正式配置时，回落到兜底记录。

### 2. DWS 字段

QI DWS 在保留原有 `*_vol` 兼容字段的同时，新增显式基数字段：

1. `cost_reimbursement_base_amt`
2. `cost_service_base_amt`
3. `cost_acs_regular_base_cnt`
4. `cost_acs_vip_base_cnt`
5. `cost_vrm_base_cnt`
6. `rebate_interchange_base_amt`
7. `rebate_incentive_base_amt`

这些字段用于保留：

1. 成本计算基数。
2. 渠道返现计算基数。
3. 固定成本摊销基数。

说明：

1. 这些 `base` 字段来自交易/结算明细和 `ods_account_fee` 规则计算，不再从 `ods_bi_month_tag` 直接读取。
2. `ods_account_fee` 同时承担月度固定成本、费用系数、阶梯规则配置。
3. 如果后续要新增规则，只需要在 `ods_account_fee` 补充对应 `fee_type` 及其时间窗即可。

### 3. 固定成本

QI 的 `cost_fixed_fee` 使用统一固定成本方案，从 `ods_bi_month_tag` 获取月固定成本后按有效 DWS 行均摊。

## SL v2 方案

### 1. 脚本补齐

SL 补齐 batch 和 cdc 两套脚本。

### 2. 成本和返现

SL 继续保留现有 DWS 粒度，并把成本系数、返现系数、固定成本来源统一切换到 `ods_bi_month_tag`。

### 3. 固定成本

SL 的 `cost_fixed_fee` 使用统一固定成本方案，从 `ods_bi_month_tag` 获取月固定成本后按有效 DWS 行均摊。

## 删除兼容

### 1. 软删除

当 `ods_bi_month_tag.delete_time is not null` 时：

1. 该条指标不再参与新数据计算。
2. 仍需要识别其对应月份为受影响月份。
3. 重洗对应月份后，目标表中该指标相关成本应变为 0 或不再产出。

### 2. 硬删除

硬删除无法依赖 `update_time` 感知。

处理方式为：

1. 按目标表中已有成本月份和指标生成目标侧集合。
2. 按当前有效 `ods_bi_month_tag` 生成源侧集合。
3. 通过源表和目标表按月份、渠道、指标对比，找出源侧已经不存在但目标侧仍存在的月份。
4. 将这些月份加入重洗范围。

## 目录规划

新增目录：

```text
flink/quantum-v2/
```

建议结构：

```text
flink/quantum-v2/bb/batch/
flink/quantum-v2/bb/cdc/
flink/quantum-v2/qi/batch/
flink/quantum-v2/qi/cdc/
flink/quantum-v2/sl/batch/
flink/quantum-v2/sl/cdc/
flink/quantum-v2/fixed_fee/batch/
flink/quantum-v2/fixed_fee/cdc/
```

每个渠道至少包含：

```text
dwm_*_v2-batch-sql.sql
dwm_*_v2-cdc-sql.sql
dws_*_v2-batch-sql.sql
dws_*_v2-cdc-sql.sql
```

固定成本链路包含：

```text
dws_online_quantum_channel_fixed_fee_v2-batch-sql.sql
dws_online_quantum_channel_fixed_fee_v2-cdc-sql.sql
```

## 风险与约束

1. `ods_bi_month_tag` 的指标命名需要稳定，否则脚本无法可靠识别固定成本、成本系数和返现系数。
2. 业务明细 cdc 脚本在阿里云 Flink 任务编排中不能依赖必填参数。
3. 阿里云 VVR 不支持在任务执行时设置 `execution.runtime-mode`，v2 脚本不能使用该 SET。
4. Auth 月表不存在时需要允许字段按 0 处理，不能让主链路失败。
5. 硬删除需要依赖源表与目标表对账，单靠 `ods_bi_month_tag.update_time` 不够。
6. 固定成本均摊口径上线前需要和财务确认，避免和金额占比摊销预期不一致。

## 验收标准

1. BB / QI / SL 均存在 v2 batch 和 cdc 脚本。
2. 业务明细 cdc 脚本可以不传参数运行，且不依赖 `ods_bi_month_tag.update_time`。
3. 固定成本 cdc 脚本可以不传参数运行，默认扫描昨天 `ods_bi_month_tag.update_time`。
4. 固定成本 batch 脚本可以通过 `start_time` / `end_time` 定向回刷 `ods_bi_month_tag` 变动窗口。
5. BB DWS 表结构不变。
6. QI DWS 可以保留成本基数和渠道返现基数字段。
7. `cost_fixed_fee` 不再固定写死为 0。
8. 软删除和硬删除后，目标表不会残留历史固定成本。
9. DWS 清洗粒度保持 `account_id + report_date + sale_id + am_id`。
