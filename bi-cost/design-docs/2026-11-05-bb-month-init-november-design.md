# BB 2026 年 11 月初始化脚本方案

## 摘要

新增 2026 年 11 月 BB 月初始化 Flink SQL，覆盖 active card count、card finance 和 channel fixed fee 三类作业。以各自 10 月脚本为模板，将业务时间窗口顺延至 `[2026-11-01, 2026-12-01)`，保持计算及写入逻辑不变。

## 范围

- `flink/quantum-v2/bb/month-init/active-card-count/`
- `flink/quantum-v2/bb/month-init/card-finance/`
- `flink/quantum-v2/bb/month-init/channel-fixed-fee/`

## 处理方案

- 分别复制 10 月脚本生成 11 月脚本。
- 更新文件名、所有固化的月份日期及文件头 `Updated Time`。
- 保留字段定义、计算、删除和写入逻辑不变。

## 考虑过的方式

- 从 10 月脚本顺延：能延续当前最新版本，减少遗漏近期逻辑变更的风险。**采用此方式。**
- 从更早月份重建：可能漏掉 10 月已包含的更新，没有优势。

## 验证

- 三个 11 月脚本的业务日期边界一致，结束边界为 2026-12-01。
- 不残留 10 月的固化业务日期。
- `git diff --check` 通过。
