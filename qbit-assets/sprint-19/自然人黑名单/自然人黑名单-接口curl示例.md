# 自然人黑名单接口 cURL 示例

> 测试环境地址按需替换。所有管理端 HTTP 示例均使用 POST；操作人从后台登录上下文获取，不需要在请求中传 userId。请将 `YOUR_ADMIN_TOKEN` 和 `YOUR_FINGERPRINT` 替换为当前有效值。JSON 请求体按可读格式展开。

## 1. 手工新增黑名单记录

`POST /api/admin/natural-person-blacklists`

```bash
curl --location "https://global.service.test.qbitnetwork.com/api/admin/natural-person-blacklists" \
  --header "Content-Type: application/json" \
  --header "Authorization: Bearer YOUR_ADMIN_TOKEN" \
  --header "fingerprint: YOUR_FINGERPRINT" \
  --data-raw '{
    "email": "alice@example.com",
    "countryCode": "SG",
    "idType": "PASSPORT",
    "documentNumber": "E1234567A",
    "remarks": "确认身份信息被多个账户复用"
  }'
```

成功响应的 `data` 是新建名单 ID。邮箱和证件信息至少提供一种；证件信息需要完整提供国籍、证件类型和证件号。

## 2. 分页查询黑名单

`POST /api/admin/natural-person-blacklists/page`

```bash
curl --location "https://global.service.test.qbitnetwork.com/api/admin/natural-person-blacklists/page" \
  --header "Content-Type: application/json" \
  --header "Authorization: Bearer YOUR_ADMIN_TOKEN" \
  --header "fingerprint: YOUR_FINGERPRINT" \
  --data-raw '{
    "current": 1,
    "size": 10,
    "status": "ACTIVE",
    "source": "IMPORT",
    "identityType": "EMAIL",
    "keyword": "alice@example.com",
    "importBatchNo": "IMP-20261028-123456789"
  }'
```

筛选字段可按需删减。列表中的身份值为脱敏值。

## 3. 查询黑名单详情

`POST /api/admin/natural-person-blacklists/detail`

```bash
curl --location "https://global.service.test.qbitnetwork.com/api/admin/natural-person-blacklists/detail" \
  --header "Content-Type: application/json" \
  --header "Authorization: Bearer YOUR_ADMIN_TOKEN" \
  --header "fingerprint: YOUR_FINGERPRINT" \
  --data-raw '{
    "blacklistId": 9988
  }'
```

## 4. 查询黑名单身份原文（小眼睛）

`POST /api/admin/natural-person-blacklists/identity/plaintext`

```bash
curl --location "https://global.service.test.qbitnetwork.com/api/admin/natural-person-blacklists/identity/plaintext" \
  --header "Content-Type: application/json" \
  --header "Authorization: Bearer YOUR_ADMIN_TOKEN" \
  --header "fingerprint: YOUR_FINGERPRINT" \
  --data-raw '{
    "blacklistId": 9988,
    "identityId": 12001
  }'
```

## 5. 解除单条黑名单

`POST /api/admin/natural-person-blacklists/release`

```bash
curl --location "https://global.service.test.qbitnetwork.com/api/admin/natural-person-blacklists/release" \
  --header "Content-Type: application/json" \
  --header "Authorization: Bearer YOUR_ADMIN_TOKEN" \
  --header "fingerprint: YOUR_FINGERPRINT" \
  --data-raw '{
    "blacklistId": 9988,
    "remarks": "风险已复核，申请解除"
  }'
```

## 6. 批量解除黑名单

`POST /api/admin/natural-person-blacklists/batch-release`

```bash
curl --location "https://global.service.test.qbitnetwork.com/api/admin/natural-person-blacklists/batch-release" \
  --header "Content-Type: application/json" \
  --header "Authorization: Bearer YOUR_ADMIN_TOKEN" \
  --header "fingerprint: YOUR_FINGERPRINT" \
  --data-raw '{
    "ids": [9988, 9991, 9974],
    "remarks": "批量复核后解除"
  }'
```

接口逐条返回处理结果；单条失败不代表整批都失败。

## 7. 全局分页查询命中记录

`POST /api/admin/natural-person-blacklists/hits`

```bash
curl --location "https://global.service.test.qbitnetwork.com/api/admin/natural-person-blacklists/hits" \
  --header "Content-Type: application/json" \
  --header "Authorization: Bearer YOUR_ADMIN_TOKEN" \
  --header "fingerprint: YOUR_FINGERPRINT" \
  --data-raw '{
    "current": 1,
    "size": 10,
    "hitTimeFrom": "2026-10-01T00:00:00+08:00",
    "hitTimeTo": "2026-10-28T23:59:59+08:00",
    "identityType": "NATIONALITY_ID",
    "identityValue": "1234567",
    "holderOrAccountId": "acc_7890"
  }'
```

## 8. 按命中 ID 查询命中详情原文

`POST /api/admin/natural-person-blacklists/hits/details`

```bash
curl --location "https://global.service.test.qbitnetwork.com/api/admin/natural-person-blacklists/hits/details" \\
  --header "Content-Type: application/json" \\
  --header "Authorization: Bearer YOUR_ADMIN_TOKEN" \\
  --header "fingerprint: YOUR_FINGERPRINT" \\
  --data-raw '{
    "hitId": 2115363300000000027
  }'
```

只需传命中事件 `hitId`。响应包含该事件的 `matchedDetails` 数组，每个维度中的 `identityValue` 为原文、`maskedValue` 为脱敏快照，并包含账户信息。

## 9. 通过 Excel 链接检查导入文件

[下载自然人黑名单导入模板](https://qbit-develop.oss-accelerate.aliyuncs.com/open-api/4c5ee705-1db8-4729-8954-2bcb866b6fdd/1793183512590/自然人黑名单-导入模版.xlsx)

`POST /api/admin/natural-person-blacklists/imports/check`

```bash
curl --location "https://global.service.test.qbitnetwork.com/api/admin/natural-person-blacklists/imports/check" \
  --header "Content-Type: application/json" \
  --header "Authorization: Bearer YOUR_ADMIN_TOKEN" \
  --header "fingerprint: YOUR_FINGERPRINT" \
  --data-raw '{
    "fileUrl": "https://qbit-develop.oss-accelerate.aliyuncs.com/open-api/4c5ee705-1db8-4729-8954-2bcb866b6fdd/1793183512590/自然人黑名单-导入模版.xlsx"
  }'
```

`fileUrl` 需要是可访问的 `.xls` 或 `.xlsx` 文件 HTTPS 链接。后端目前仅允许 `qbit-develop.oss-accelerate.aliyuncs.com` 域名，文件大小上限 20 MB，数据行上限 5000。原 multipart 文件上传方式仍可用。

## 10. 确认批量导入

`POST /api/admin/natural-person-blacklists/imports/confirm`

```bash
curl --location "https://global.service.test.qbitnetwork.com/api/admin/natural-person-blacklists/imports/confirm" \
  --header "Content-Type: application/json" \
  --header "Authorization: Bearer YOUR_ADMIN_TOKEN" \
  --header "fingerprint: YOUR_FINGERPRINT" \
  --data-raw '{
    "importBatchNo": "IMP-20261028-123456789",
    "rows": [
      {
        "email": "alice@example.com",
        "countryCode": "SG",
        "idType": "PASSPORT",
        "documentNumber": "E1234567A",
        "remarks": "身份信息重复使用"
      },
      {
        "email": "bob@example.com",
        "countryCode": null,
        "idType": null,
        "documentNumber": null,
        "remarks": "已完成复核"
      }
    ]
  }'
```

将检查接口返回的 `importBatchNo` 和需要提交的行数据原样带入。确认接口允许逐行部分成功。

## 11. 根据 Excel 链接直接导入黑名单

`POST /api/admin/natural-person-blacklists/imports/confirm`

```bash
curl --location "https://global.service.test.qbitnetwork.com/api/admin/natural-person-blacklists/imports/confirm" \
  --header "Content-Type: application/json" \
  --header "Authorization: Bearer YOUR_ADMIN_TOKEN" \
  --header "fingerprint: YOUR_FINGERPRINT" \
  --data-raw '{
    "importBatchNo": "IMP-20261028-123456789",
    "fileUrl": "https://qbit-develop.oss-accelerate.aliyuncs.com/open-api/4c5ee705-1db8-4729-8954-2bcb866b6fdd/1793183512590/自然人黑名单-导入模版.xlsx"
  }'
```

链接模式直接检查并导入 Excel；使用请求中的批次号并在回执中返回，省略时服务端生成，逐行处理且支持部分成功。文件链接限制、大小和行数与链接检查接口相同。

## 12. 异步导出命中记录

`POST /api/admin/natural-person-blacklists/hits/export`

```bash
curl --location "https://global.service.test.qbitnetwork.com/api/admin/natural-person-blacklists/hits/export" \\
  --header "Content-Type: application/json" \\
  --header "Authorization: Bearer YOUR_ADMIN_TOKEN" \\
  --header "fingerprint: YOUR_FINGERPRINT" \\
  --data-raw '{
    "current": 1,
    "size": 10,
    "hitTimeFrom": "2026-10-01T00:00:00+08:00",
    "hitTimeTo": "2026-10-28T23:59:59+08:00",
    "identityType": "NATIONALITY_ID",
    "identityValue": "1234567",
    "holderOrAccountId": "acc_7890"
  }'
```

请求筛选条件与命中分页一致；导出全部匹配结果，不受 `current`、`size` 限制。导出身份值为脱敏值，任务完成后通过现有异步导出通知流程获取文件。

## 13. 查询统一操作日志

黑名单操作日志复用 `admin-graphql` 的 `adminOperationLogs`，按名单 ID 过滤。下面的请求体使用 `recordId` 字符串；token 和 fingerprint 沿用后台登录态。

```bash
curl --location "https://global.service.test.qbitnetwork.com/admin-graphql" \
  --header "Content-Type: application/json" \
  --header "Accept-Language: zh,en-US;q=0.9,en;q=0.8,zh-CN;q=0.7" \
  --header "Origin: https://test-admin-v3.qbitnetwork.com" \
  --header "Referer: https://test-admin-v3.qbitnetwork.com/" \
  --header "Authorization: Bearer YOUR_ADMIN_TOKEN" \
  --header "fingerprint: YOUR_FINGERPRINT" \
  --data-raw '{
    "operationName": "operationLogs",
    "variables": {
      "queryParams": {
        "filter": {
          "recordId": "9988"
        },
        "pagination": {
          "limit": 0,
          "page": 0
        }
      }
    },
    "query": "query operationLogs($queryParams: QueryParams!) { data: adminOperationLogs(queryParams: $queryParams) { pageTotal total data { remarks userId accountId recordId previousStatus currentStatus businessType data message comment { comment attachment } userComment { comment attachment } operatorUserInfo { nickname } operatorAccountInfo { id } createTime } } }"
  }'
```

## 13. 不提供 cURL 的内部方法

以下能力不是 HTTP API，不能通过 cURL 或 Postman 请求：

- 删除处置联动加黑：由处置业务在 Java 中调用 `NaturalPersonBlacklistService.addFromDisposition(...)`，用户及处置业务参数按 Service 契约传入。
- KYC/SumSub 黑名单校验：由 Node 项目在本地调用校验方法，直接查询黑名单并记录命中；不新增 HTTP/Feign 接口。

如果处置代码或 KYC 代码所在应用与上述实现不在同一进程，需要另行确认跨应用调用方式；当前方案没有对应 HTTP 路由。

