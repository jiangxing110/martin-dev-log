# 销售毛利空销售过滤与最早日期限制设计

## 摘要

销售毛利看板不展示没有销售归属（`sale_id IS NULL`、空字符串或全空格）的数据；毛利查询仅允许从 2026-09-01 起查询。过滤在物化视图、快照生成和 API 查询侧共同生效，快照表定义也将 `sale_id` 设为非空且非空白。

## 范围

- 物化视图最终输出排除 `sale_id IS NULL`、空字符串和全空格。
- 快照批处理读取视图时排除空销售行；汇总和明细快照 DDL 对 `sale_id` 增加 `NOT NULL` 和非空白约束。
- 生产/本地 Mapper 的快照存在性判断、汇总查询及生产估算查询过滤空销售，避免历史快照残留行进入结果或触发错误的数据源切换。
- 回填销售名称前跳过空白 ID，避免把空字符串交给 UUID 用户表查询。
- 服务校验 `settlementMonth` 和 `reportDateRange` 起始日不得早于 2026-09-01；校验对分页和导出接口共享。使用项目全局异常处理器识别的 `CustomException`，让参数错误返回 400，而不是被兜底处理成 500。
- Open API 实收按 `api_client_bill_actual_received_amount` 减去 `api_client_bill_monthly_kyc_fee_received_amount`、`api_client_bill_physical_card_fee_received_amount`、`api_client_bill_minimum_commitment_received_amount` 计算，继续进入销售维度实收收入。

## 不在范围

- 不删除线上已有快照中的空销售行，也不在本次执行建表、刷新或快照重跑。
- 不改用户、部门或账户关联逻辑。

## 验收标准

- 新生成的视图行和快照行均有非空白 `sale_id`。
- 历史快照中的空销售行不会被汇总 API 返回。
- 早于 2026-09-01 的结算月或报告区间返回参数错误。
- 不运行编译或测试；只检查修改文件的静态差异。
