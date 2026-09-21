# QI 渠道返现改按净消费计费

## 变更内容

- QI v2 batch 与 CDC 财务汇总的 Interchange 返现基数改为非港净消费金额乘 0.02。
- QI v2 batch 与 CDC 财务汇总的 Incentive 返现基数改为非港净消费金额乘 0.0118。
- `Consumption` 正向计入，`Reversal/Credit` 反向抵减，范围限定为 `Closed/Pending`。
- 更新目标表字段注释，明确返现基数为非港净消费口径。

## 验证

- 已完成 batch/CDC 净消费返现条件一致性静态检查。
- 已运行 `git diff --check`。
- 未执行真实 Flink 作业或数据库回刷。
