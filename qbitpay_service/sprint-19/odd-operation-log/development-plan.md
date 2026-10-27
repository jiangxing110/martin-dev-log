# ODD 年审 KYC/KYB 合规审核日志开发方案

## 目标

每次合规人员提交 ODD 年审 Case 下 KYC 或 KYB 的审核结果时，除现有 CDD 审核日志外，额外生成一条独立的「合规审核」操作日志，供 ODD 年审 Case 日志使用。

ODD Case 状态流转到「待审核」时的「客户提交信息」日志属于另一类事件，继续由现有状态流转逻辑负责。本方案不改动该行为，也不影响普通 CDD 审核日志。

## 当前实现

- 年审 Case 状态根据其 KYC/KYB 状态计算；从 Processing/Request 转到 Pending 时，调用年审审核逻辑并保存操作日志。满足客户提交条件时，operationType 为 CustomerSubmitInfo。
- KYC 审核在 CDD 审核事务中写入 CddReview / ReviewKyc 日志；KYB 审核写入 CddReview / ReviewKyb 日志。
- ODD 年审 Case 由 OddAccountReview 表示，持有 kyCaseId。年审 Case 自身日志使用 OperationLogBusinessTypeEnum.OddAccountReview，recordId 为 OddAccountReview.id。
- 因此，现有 CDD 审核日志和年审 Case 日志的业务类型及 recordId 不同；要让 ODD Case 获得独立的合规审核记录，需要在 CDD 审核提交路径额外保存一条 OddAccountReview 日志。

## 方案

在现有 KYC/KYB 审核事务中追加保存一条 OperationLog：

- businessType：OperationLogBusinessTypeEnum.OddAccountReview
- recordId：对应的 OddAccountReview.id
- accountId / userId：年审 Case 账户与实际审核人
- previousStatus / currentStatus：本次 CDD 审核对象的审核前后状态
- data.operationType：统一使用 ComplianceReview
- data.cddType：KYC 或 KYB
- data.cddRecordId：实际被审核的 KYC/KYB 记录 ID
- data.kyCaseId：用于关联 CDD case
- data.kycType 或 data.businessType：说明被审 CDD 产品/类型
- data.reviewResult / remarks：审核结果与审核意见；仅保留审核操作所需信息，不复制整份 CDD 个人资料或附件

KYC 与 KYB 可共用一个新增日志辅助方法，避免两边的字段结构和 operationType 漂移。现有 CddReview 日志照常保存，不合并、不替换。

## 触发范围

仅当待审核的 CDD 记录确实属于 ODD 年审时追加日志：

- KYC：年审 KYC 类型（例如 BusinessOdd）。
- KYB：ODD 年审产品类型（例如 VirtualCardOdd、MultiCurrencyAccountOdd）。

普通 Business / Personal KYC、普通 KYB 仍只走现有 CDD 日志逻辑。

通过 kyCaseId 查找对应的 OddAccountReview。查询及新增日志使用当前审核事务的 EntityManager/QueryRunner，确保 CDD 审核结果、现有 CDD 日志和新增年审日志在同一事务提交或回滚。若标记为 ODD 年审的记录找不到对应 Case，应作为关联异常处理并留下可检索错误，不能静默地漏掉要求的年审日志。

## 主要代码位置

- ODD 年审状态与日志：`src/modules/cdd/odd/odd-account-review.service.ts`
- 年审 Case 实体：`src/entity/cdd/odd-account-review.entity.ts`
- KYC 审核及审核日志：`src/modules/cdd/v2/service/kyc-v2.service.ts`、必要时检查 `src/modules/cdd/v2/service/kyc-individual-v2.service.ts` 的实际路由
- KYB 审核及审核日志：`src/modules/cdd/v2/service/kyb-v2.service.ts`
- 操作日志业务类型：`src/entity/user-logs/operation.log.entity.ts`

## 实施步骤

1. 顺着 GraphQL/API 调用链确认 ODD 年审 KYC 与 KYB 实际进入哪些审核方法，覆盖所有能提交审核结果的路径（包括再次审核路径）。
2. 在相应审核事务内拿到被审核记录、审核前后状态及当前操作人；用 kyCaseId 找到 OddAccountReview。
3. 添加共用的 ODD 审核日志写入方法，明确并固定 data 字段结构和 operationType。
4. 在 KYC、KYB 审核成功保存结果后、事务提交前，分别追加日志；保留原有 CddReview 日志。
5. 按业务类型限定触发范围，保证普通 CDD 审核不会产生 ODD 年审日志。
6. 由 ODD 年审 Case 日志的查询接口按 OddAccountReview businessType 和年审 Case recordId 读取这类新日志；确认数据展示可区分 KYC 与 KYB。

## 验收场景

- ODD 年审 KYC 审批提交一次：新增一条 OddAccountReview / ComplianceReview 日志，包含审核人、状态变化、CDD 记录 ID 和 KYC 类型；原有 CddReview / ReviewKyc 仍存在。
- ODD 年审 KYB 审批提交一次：新增一条对应 KYB 的年审日志；原有 CddReview / ReviewKyb 仍存在。
- 再次审核或重新提交审批：每次成功提交各新增一条日志。
- 普通 CDD KYC/KYB 审核：不新增 OddAccountReview 日志。
- 审核事务失败：审核状态及两类日志均不应留下部分提交。
- ODD 年审 Case 流转到 Pending：仍由现有路径生成 CustomerSubmitInfo；不因 KYC/KYB 审核日志改动而重复生成。

## 未包含

- 回填历史审核日志。
- 修改「客户提交信息」日志的触发条件。
- 新建操作日志表或替换现有 CddReview 日志。
- UI 文案/布局的独立改版；若当前 Case 日志接口或前端过滤器不展示 OddAccountReview 记录，则需要在实施时补上读取/展示支持。
