# ODD 年审审批日志开发记录

## 本次改动

当前分支提交：`c5765e8a44 odd 账户年审日志`

本次为 ODD 年审 Case 下的 KYC/KYB 审批新增独立的合规审核日志。原有 CDD 审核日志保留；新增日志通过 `OddAccountReview` 业务类型关联年审 Case，并与审核结果在同一事务中保存。

## 文件变更明细

### `src/modules/operation-log/operation.log.service.ts`

新增 `createOddAccountReviewCddAuditLog` 方法：

- 使用调用方传入的 EntityManager，在当前审核事务中执行查询和写入。
- 根据 `kyCaseId` 查找未删除的 ODD 年审 Case。
- 将新日志写入 `operationLog`，业务类型为 `OddAccountReview`，操作类型为 `ComplianceReview`。
- 记录被审类型（KYC/KYB）、CDD 记录 ID、KYC 类型或 KYB 产品类型、审核前后状态、审核结果和审核意见。
- 如果 ODD 年审类型的审核找不到对应 Case，抛出关联错误，避免审核成功但遗漏年审日志。

### `src/modules/cdd/v2/cdd-v2.dto.ts`

在 `IReviewKycLog` 中增加 `kycType` 字段，使共用 KYC 日志方法能够识别当前记录是否为年审 KYC。

### `src/modules/cdd/v2/service/kyc-v2.service.ts`

- 调用共用 KYC 审核日志方法时传入当前 KYC 类型。
- 对 `BusinessOdd` 在已有 `CddReview / ReviewKyc` 日志之外，额外写入一条 ODD 年审 `ComplianceReview` 日志。
- 其他 KYC 类型不新增 ODD 年审日志。

### `src/modules/cdd/v2/service/kyb-v2.service.ts`

- 对 `VirtualCardOdd`、`MultiCurrencyAccountOdd`、`DigitalCurrenciesOdd` 等年审 KYB 类型，在已有 `CddReview / ReviewKyb` 日志之外，额外写入一条 ODD 年审 `ComplianceReview` 日志。
- 普通 KYB 类型保持原有日志行为。

## 检查记录

- Prettier 格式检查：通过。
- `git diff --check`：通过。
- 未运行测试。
- `tsc --noEmit -p tsconfig.build.json` 未完成：当前 TypeScript 3.9.7 在解析 `node_modules/apollo-server-express/node_modules/@types/express-serve-static-core` 时出现语法错误，因此无法据此验证全量类型。
- 后续反馈的 TS2339：当前分支中方法已定义在 `OperationLogService` 类内，KYC/KYB 调用也引用同一服务文件；本次检查未能在当前 checkout 复现。若仍出现，请核对报错文件路径是否指向当前分支源码。

