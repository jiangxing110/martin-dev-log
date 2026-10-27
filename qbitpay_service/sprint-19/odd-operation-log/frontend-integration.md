# ODD 操作日志前端对接文档

## 1. 对接目标

在 ODD Case 详情页展示该 Case 的操作日志，并将本次补充的 KYC/KYB 审批日志作为独立记录呈现。原有 ODD 状态流转日志继续展示，不与 CDD 审批日志合并。

日志归属关系如下：

- ODD Case 日志：`businessType = OddAccountReview`，`recordId = OddAccountReview.id`。
- 新增的 KYC/KYB 合规审批日志也归属到对应 ODD Case，使用相同的 `businessType` 和 ODD Case `recordId`。
- `data.kyCaseId` 是关联的 CDD Case ID；`data.cddRecordId` 是实际 KYC/KYB 记录 ID。它们用于展示或跳转关联信息，不作为 ODD Case 日志列表的主查询 `recordId`。
- 原有独立 CDD 日志使用 `businessType = CddReview`，不属于本次 ODD Case 操作日志列表的查询范围。

## 2. 查询接口

后台管理端使用 GraphQL 查询 `adminOperationLogs`。该查询要求管理员权限。

### GraphQL 查询

```graphql
query AdminOperationLogs($queryParams: QueryParams!) {
  adminOperationLogs(queryParams: $queryParams) {
    data {
      id
      accountId
      businessType
      recordId
      userId
      previousStatus
      currentStatus
      type
      occurrenceTime
      remarks
      data
      operatorUserInfo {
        id
        nickname
      }
    }
    total
    pageTotal
  }
}
```

### Variables 示例

```json
{
  "queryParams": {
    "filter": {
      "businessType": "OddAccountReview",
      "recordId": "<当前 OddAccountReview.id>"
    },
    "order": {
      "occurrenceTime": "DESC"
    },
    "pagination": {
      "page": 0,
      "limit": 50
    }
  }
}
```

`page` 从 `0` 开始。`total` 为总记录数，`pageTotal` 为当前返回的数据数量；分页加载时沿用相同的 `filter` 和 `order`，递增 `page`。

不要在 `filter` 中传 `operationType`。此字段在 `adminOperationLogs` 中只支持 PhoneChange、EmailChange 两种已有特殊筛选值；ODD 的操作类型应从返回值 `data.operationType` 判断。

## 3. 日志类型与展示映射

### ODD 状态流转日志

这些记录由 ODD Case 状态流转产生。字段包括 `previousStatus`、`currentStatus`、`data.operationType` 和 `data.params`。`operationType` 可能是 `CustomerSubmitInfo`、`CustomerNotSubmitInfo`、`Request`、`Other` 等。

建议：

- 继续按现有 ODD 状态日志 UI 展示状态变化和备注。
- 当 `data.operationType === "CustomerSubmitInfo"` 时，操作名称展示为“客户提交信息”。
- 不要将 ODD 状态变化日志当作 KYC/KYB 审批记录。

### KYC/KYB 合规审批日志（本次新增）

当 `data.operationType === "ComplianceReview"` 时，展示一条独立的“合规审核”记录。字段映射如下：

| 日志字段 | 前端展示 |
| --- | --- |
| `data.operationType` | 操作名称“合规审核” |
| `data.cddType` | 审核对象类型：`KYC` 或 `KYB` |
| `data.cddTypeDetail` | KYC/KYB 业务场景详情 |
| `data.cddRecordId` | 被审核的 KYC/KYB 记录 ID，可用于详情跳转 |
| `data.kyCaseId` | 关联的 CDD Case ID |
| `previousStatus` | 审核前状态 |
| `currentStatus` | 审核后状态 |
| `data.reviewResult` | 审核结果；通常与 `currentStatus` 对应 |
| `data.remarks` 或顶层 `remarks` | 审核备注 |
| `userId` / `operatorUserInfo.nickname` | 审核人 |
| `occurrenceTime` | 审核时间 |

`data` 是 JSON 字段，建议按可空对象处理，并对未知 `operationType`、缺少关联 ID、空备注等情况做兼容。审核结果状态的枚举文案请复用前端现有 KYC/KYB 状态字典，不要根据日志字段重新维护一套状态翻译。

## 4. 排序与时间

请求按 `occurrenceTime: DESC` 排序，最新日志显示在前。时间使用 `occurrenceTime`；如果个别旧记录没有该字段，再回退到实体的创建时间（若当前 GraphQL schema 已提供）。

## 5. 兼容说明

- 同一个 ODD Case 查询结果会同时包含状态流转日志和合规审批日志。前端按 `data.operationType` 分别渲染；不要过滤掉 `ComplianceReview`。
- 合规审核日志的 `recordId` 是 ODD Case ID。用 KYC/KYB 记录 ID 查询会查不到这条 ODD 日志。
- `data.cddType`、`data.cddRecordId`、`data.kyCaseId` 是新增合规审批日志的字段；旧日志可能没有这些字段。
- 现有 CDD 独立日志与 ODD Case 审批日志是两条不同业务记录。若页面需要展示 ODD 下的审批历史，应以本查询返回的 `ComplianceReview` 记录为准，避免将 CDD 日志列表重复拼接到 ODD 时间线。

## 6. 最小验收场景

1. ODD Case 状态流转到待审核后，列表中能看到原有“客户提交信息”记录。
2. 合规分别审核 ODD 下的 KYC 和 KYB 后，各出现一条独立的“合规审核”记录。
3. 两条审批日志能显示 KYC/KYB 类型、审核前后状态、审核人、审核时间和备注。
4. KYC/KYB 审批日志按 ODD Case `recordId` 可查到；用 `data.cddRecordId` 作为日志查询 `recordId` 不应作为前端实现方式。
5. 分页与最新优先排序正常，未知日志类型仍能以通用日志样式显示。

## 7. `data.operationType` 新增值说明

本次新增的 `data.operationType` 取值为字符串 `"ComplianceReview"`。它位于 `data` JSON 对象中，不是 OperationLog 顶层字段，也不是 GraphQL enum。前端收到该值时，应渲染一条独立的“合规审核”记录；审核对象由 `data.cddType` 区分为 `KYC` 或 `KYB`。

合规审批日志的 `data` 示例：

```json
{
  "operationType": "ComplianceReview",
  "cddType": "KYC",
  "cddRecordId": "<KYC 记录 ID>",
  "cddTypeDetail": "<KYC 业务场景>",
  "kyCaseId": "<CDD Case ID>",
  "reviewResult": "<审核结果状态>",
  "remarks": "<审核备注>"
}
```

`previousStatus`、`currentStatus`、`userId` 和 `occurrenceTime` 仍从 OperationLog 顶层读取。不要把 `ComplianceReview` 和 ODD 状态流转日志中的 `CustomerSubmitInfo`、`CustomerNotSubmitInfo`、`Request`、`Other` 混为同一类操作；分别按各自的 `data.operationType` 渲染。
