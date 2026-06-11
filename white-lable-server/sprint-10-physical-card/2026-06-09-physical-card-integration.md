# Infinity Launch 实体卡对接文档

## 1. 背景

本期支持 Infinity Launch 实体卡申请、邮寄地址提交、费用预览、物流查询、实体卡激活、PIN 设置/修改，以及 Admin 卡类型筛选。

卡片类型复用数据库 `card.type` 字段：

- `VIRTUAL_CARD`：虚拟卡
- `PHYSICAL_CARD`：实体卡

实体卡专属履约信息保存在 `card_physical_detail`。

## 2. 开卡能力

### 查询开卡能力摘要

`GET /member/api/v1/card/create-capability`

用途：前端判断新增虚拟卡、新增实体卡按钮是否展示。

响应字段：

| 字段 | 类型 | 说明 |
|---|---|---|
| totalAvailableCount | number | 当前账户剩余可开卡数量，实体卡 + 虚拟卡总上限为 3 |
| virtualCardAvailable | boolean | 是否可创建虚拟卡 |
| physicalCardAvailable | boolean | 是否可创建实体卡 |
| physicalCardReason | string | 实体卡不可创建原因 |
| physicalCardBin | string | 实体卡固定 BIN，当前为 `45492418` |
| physicalCardBinId | string | 实体卡 BIN ID |

`physicalCardReason`：

| 值 | 说明 |
|---|---|
| TOTAL_LIMIT_REACHED | 实体卡 + 虚拟卡总数已达 3 |
| PHYSICAL_LIMIT_REACHED | 已有 1 张实体卡 |
| BIN_NOT_ALLOWED | 当前账户无 `45492418` 卡段权限 |

## 3. 创建卡

### 创建虚拟卡/实体卡

`POST /member/api/v1/card`

请求示例：

```json
{
  "cardMode": "PHYSICAL_CARD",
  "binId": "bin-id-from-create-capability",
  "physicalCardDesignId": "BZ_SIGNATURE_BLACK_WHITE_PLASTIC",
  "label": "My Physical Card"
}
```

字段说明：

| 字段 | 必填 | 说明 |
|---|---|---|
| cardMode | 否 | `VIRTUAL_CARD` / `PHYSICAL_CARD`，为空默认 `VIRTUAL_CARD` |
| binId | 实体卡必填 | 实体卡只能使用 `45492418` 对应 BIN ID |
| physicalCardDesignId | 否 | 实体卡样式 ID，未传使用后端默认值，联调需替换为三方真实 ID |
| label | 否 | 卡片名称 |

创建实体卡规则：

- 实体卡 + 虚拟卡最多 3 张。
- 实体卡最多 1 张。
- 当前账户必须有 `45492418` BIN 权限。
- 创建成功后本地 `card.type = PHYSICAL_CARD`。
- 创建成功后生成 `card_physical_detail`，状态为 `PENDING_SHIPPING_ADDRESS`。

## 4. 卡列表与详情

### 会员端卡列表

`GET /member/api/v1/card/page`

Query 参数：

| 字段 | 说明 |
|---|---|
| status | 状态列表 |
| cardMode | `VIRTUAL_CARD` / `PHYSICAL_CARD` |
| page | 页码 |
| size | 每页数量 |

### Admin 卡列表

`GET /admin/api/v1/card/page`

新增 Query 参数：

| 字段 | 说明 |
|---|---|
| cardMode | `VIRTUAL_CARD` / `PHYSICAL_CARD` |

### 卡响应新增字段

| 字段 | 类型 | 说明 |
|---|---|---|
| cardMode | string | 卡片类型，`VIRTUAL_CARD` / `PHYSICAL_CARD` |
| physicalCardStatus | string | 实体卡履约状态，仅实体卡有值 |
| pinSet | boolean | 是否已设置 PIN，仅实体卡有值 |

实体卡履约状态：

| 状态 | 说明 |
|---|---|
| PENDING_SHIPPING_ADDRESS | 已创建实体卡，待提交邮寄地址 |
| PROCESSING | 已提交邮寄地址，制卡/运输处理中 |
| SHIPPING | 已查询到物流信息 |
| ACTIVATED | 已激活 |
| UNKNOWN | 三方状态无法识别 |

## 5. 实体卡费用

### 查询实体卡费用预览

`GET /member/api/v1/card/{id}/physical/fee-preview`

用途：进入 Shipping Address 页面时展示费用。

响应示例：

```json
{
  "currency": "USD",
  "productionFee": 10,
  "shippingFee": 15,
  "totalCost": 25
}
```

费用口径：

| 费用 | AccountFeeType | 说明 |
|---|---|---|
| 制卡费 | `QuantumCardMakeCardFee` | 对应 `AccountFeeType.QUANTUM_CARD_MAKE_CARD_FEE` |
| 邮寄费 | `ShoppingFee` | 对应 `AccountFeeType.SHOPPING_FEE` |
| 总支出 | - | `productionFee + shippingFee` |

注意：

- 不使用 `_Caas` 版本费率。
- 提交邮寄地址时后端会重新计算一次费用，并将 `production_fee`、`shipping_fee`、`total_cost` 快照保存到 `card_physical_detail`。
- 如果缺少 `QuantumCardMakeCardFee` 或 `ShoppingFee` 配置，提交邮寄地址会失败。

## 6. 邮寄地址

### 提交邮寄地址

`POST /member/api/v1/card/{id}/physical/shipping-address`

请求示例：

```json
{
  "firstName": "San",
  "lastName": "Zhang",
  "phoneCountryCode": "+86",
  "phoneNumber": "13800138000",
  "email": "san.zhang@example.com",
  "addressLine1": "Room 101, Road 1",
  "addressLine2": "Building A",
  "city": "Shanghai",
  "state": "Shanghai",
  "country": "CN",
  "postalCode": "200000"
}
```

规则：

- 只能本人账户提交。
- 只能实体卡提交。
- 仅 `PENDING_SHIPPING_ADDRESS` 状态可提交。
- `firstName` / `lastName` 仅支持英文、空格、连字符、撇号。
- 成功后状态变为 `PROCESSING`。
- 成功后保存收件人与地址快照、费用快照。

## 7. 物流查询

### 查询物流信息

`GET /member/api/v1/card/{id}/physical/shipping-info`

响应字段：

| 字段 | 类型 | 说明 |
|---|---|---|
| available | boolean | 是否已有物流信息 |
| expressCompany | string | 快递公司 |
| trackingNumber | string | 快递单号 |
| trackingUrl | string | 物流查询地址 |
| physicalCardStatus | string | 实体卡履约状态 |

规则：

- 无物流信息时返回 `available = false`，不作为异常。
- 有物流单号时同步快递公司、单号、URL，状态更新为 `SHIPPING`。

## 8. 激活实体卡

### 激活

`POST /member/api/v1/card/{id}/physical/activate`

规则：

- 只能本人账户操作。
- 必须已提交邮寄地址。
- `PROCESSING` 或 `SHIPPING` 状态可激活。
- 成功后 `physicalCardStatus = ACTIVATED`。
- 成功后同步 `card.status = ACTIVE`。

## 9. 设置/修改 PIN

### 设置或修改 PIN

`POST /member/api/v1/card/{id}/pin`

请求示例：

```json
{
  "pin": "123456"
}
```

规则：

- 只能本人账户操作。
- 仅 `ACTIVATED` 实体卡可设置/修改 PIN。
- PIN 当前按 6 位数字校验。
- PIN 不落库、不打印日志。
- 成功后仅保存 `pin_set = true`。

## 10. 冻结/解冻限制

现有接口：

- `POST /member/api/v1/card/freeze/{id}`
- `POST /member/api/v1/card/unfreeze/{id}`
- `POST /admin/api/v1/card/freeze/{id}`
- `POST /admin/api/v1/card/unfreeze/{id}`

实体卡规则：

- `PENDING_SHIPPING_ADDRESS`、`PROCESSING`、`SHIPPING` 状态禁止冻结/解冻。
- 仅 `ACTIVATED` 状态沿用现有冻结/解冻逻辑。

## 11. Webhook 同步

现有 webhook 入口：

`POST /admin/api/v1/open-api/webhook`

已接入卡生命周期事件：

| 事件 | 处理 |
|---|---|
| CARD.CREATED | 同步本地卡基础信息，必要时补实体卡详情 |
| CARD.UPDATED | 同步本地卡基础信息 |
| CARD.DELETED | 同步本地卡状态，默认置为 `INACTIVE` |
| CARD.SETTING.UPDATED | 同步卡设置；能识别 PIN 更新时设置 `pin_set = true` |
| PHYSICAL_CARD_ACTIVATED | 兜底同步实体卡状态为 `ACTIVATED` |

幂等：

- 继续复用 `webhook_event` 的 `eventId + SUCCESS` 幂等。
- 找不到本地卡时记录 warn 并返回成功，避免三方持续重试。

## 12. 前端建议流程

1. 进入卡片页，调用 `GET /card/create-capability`。
2. 根据返回值展示 Add Virtual Card / Add Physical Card。
3. 创建实体卡时传 `cardMode = PHYSICAL_CARD` 和实体卡 BIN ID。
4. 创建成功后进入 Shipping Address 页面。
5. Shipping Address 页面调用 `GET /card/{id}/physical/fee-preview` 展示费用。
6. 用户确认后调用 `POST /card/{id}/physical/shipping-address`。
7. 详情页按 `physicalCardStatus` 控制按钮展示：
   - `PENDING_SHIPPING_ADDRESS`：展示填写邮寄地址。
   - `PROCESSING` / `SHIPPING`：展示物流信息、激活按钮；隐藏冻结/解冻。
   - `ACTIVATED`：展示设置/修改 PIN、冻结/解冻。
8. 激活后调用 PIN 接口设置或修改 PIN。

## 13. 待联调确认

- BZ 黑白塑料实体卡真实 `physicalCardDesignId`。
- PIN 是否确认为 6 位数字。
- 三方 `CARD.SETTING.UPDATED` resource 是否能明确识别 PIN 更新。
- 费用配置中 `QuantumCardMakeCardFee`、`ShoppingFee` 是否已为 Infinity Launch 配好最终客户价。

## 14. curl 示例

说明：

- 以下示例使用测试环境域名。
- `authorization`、`nonce`、`sign`、`timestamp`、`fingerprint` 请按实际登录态和签名规则替换。
- Member 端示例使用 `platform: member`；Admin 端示例使用 `platform: admin`。
- 示例里的 `X-Tenant-Id` 使用 `489789`，联调时按实际租户替换。

### 14.1 Member 通用 Header 模板

```bash
-H 'Accept: application/json, text/plain, */*' \
-H 'Accept-Language: zh,en-US;q=0.9,en;q=0.8,zh-CN;q=0.7' \
-H 'Connection: keep-alive' \
-H 'Content-Type: application/json' \
-H 'Origin: https://test-u-app-member.qbitnetwork.com:26813' \
-H 'Referer: https://test-u-app-member.qbitnetwork.com:26813/' \
-H 'X-Tenant-Id: 489789' \
-H 'authorization: Bearer <MEMBER_TOKEN>' \
-H 'fingerprint: <FINGERPRINT>' \
-H 'lang: zh_CN' \
-H 'nonce: <NONCE>' \
-H 'platform: member' \
-H 'sign: <SIGN>' \
-H 'timestamp: <TIMESTAMP>'
```

### 14.2 Admin 通用 Header 模板

```bash
-H 'Accept: application/json, text/plain, */*' \
-H 'Accept-Language: zh,en-US;q=0.9,en;q=0.8,zh-CN;q=0.7' \
-H 'Connection: keep-alive' \
-H 'Content-Type: application/json' \
-H 'Origin: https://test-u-app-admin.qbitnetwork.com:26813' \
-H 'Referer: https://test-u-app-admin.qbitnetwork.com:26813/' \
-H 'X-Tenant-Id: 489789' \
-H 'authorization: Bearer <ADMIN_TOKEN>' \
-H 'fingerprint: <FINGERPRINT>' \
-H 'lang: zh_CN' \
-H 'nonce: <NONCE>' \
-H 'platform: admin' \
-H 'sign: <SIGN>' \
-H 'timestamp: <TIMESTAMP>'
```

### 14.3 查询开卡能力摘要

```bash
curl 'https://test-white-label-member.qbitnetwork.com:26811/member/api/v1/card/create-capability' \
  -H 'Accept: application/json, text/plain, */*' \
  -H 'Accept-Language: zh,en-US;q=0.9,en;q=0.8,zh-CN;q=0.7' \
  -H 'Connection: keep-alive' \
  -H 'Content-Type: application/json' \
  -H 'Origin: https://test-u-app-member.qbitnetwork.com:26813' \
  -H 'Referer: https://test-u-app-member.qbitnetwork.com:26813/' \
  -H 'X-Tenant-Id: 489789' \
  -H 'authorization: Bearer <MEMBER_TOKEN>' \
  -H 'fingerprint: <FINGERPRINT>' \
  -H 'lang: zh_CN' \
  -H 'nonce: <NONCE>' \
  -H 'platform: member' \
  -H 'sign: <SIGN>' \
  -H 'timestamp: <TIMESTAMP>'
```

### 14.4 创建实体卡

```bash
curl 'https://test-white-label-member.qbitnetwork.com:26811/member/api/v1/card' \
  -H 'Accept: application/json, text/plain, */*' \
  -H 'Accept-Language: zh,en-US;q=0.9,en;q=0.8,zh-CN;q=0.7' \
  -H 'Connection: keep-alive' \
  -H 'Content-Type: application/json' \
  -H 'Origin: https://test-u-app-member.qbitnetwork.com:26813' \
  -H 'Referer: https://test-u-app-member.qbitnetwork.com:26813/' \
  -H 'X-Tenant-Id: 489789' \
  -H 'authorization: Bearer <MEMBER_TOKEN>' \
  -H 'fingerprint: <FINGERPRINT>' \
  -H 'lang: zh_CN' \
  -H 'nonce: <NONCE>' \
  -H 'platform: member' \
  -H 'sign: <SIGN>' \
  -H 'timestamp: <TIMESTAMP>' \
  --data-raw '{"cardMode":"PHYSICAL_CARD","binId":"<PHYSICAL_CARD_BIN_ID>","physicalCardDesignId":"BZ_SIGNATURE_BLACK_WHITE_PLASTIC","label":"My Physical Card"}'
```

### 14.5 创建虚拟卡

```bash
curl 'https://test-white-label-member.qbitnetwork.com:26811/member/api/v1/card' \
  -H 'Accept: application/json, text/plain, */*' \
  -H 'Accept-Language: zh,en-US;q=0.9,en;q=0.8,zh-CN;q=0.7' \
  -H 'Connection: keep-alive' \
  -H 'Content-Type: application/json' \
  -H 'Origin: https://test-u-app-member.qbitnetwork.com:26813' \
  -H 'Referer: https://test-u-app-member.qbitnetwork.com:26813/' \
  -H 'X-Tenant-Id: 489789' \
  -H 'authorization: Bearer <MEMBER_TOKEN>' \
  -H 'fingerprint: <FINGERPRINT>' \
  -H 'lang: zh_CN' \
  -H 'nonce: <NONCE>' \
  -H 'platform: member' \
  -H 'sign: <SIGN>' \
  -H 'timestamp: <TIMESTAMP>' \
  --data-raw '{"cardMode":"VIRTUAL_CARD","binId":"<VIRTUAL_CARD_BIN_ID>","label":"My Virtual Card"}'
```

### 14.6 查询会员端卡列表

```bash
curl 'https://test-white-label-member.qbitnetwork.com:26811/member/api/v1/card/page?page=1&size=10&cardMode=PHYSICAL_CARD' \
  -H 'Accept: application/json, text/plain, */*' \
  -H 'Accept-Language: zh,en-US;q=0.9,en;q=0.8,zh-CN;q=0.7' \
  -H 'Connection: keep-alive' \
  -H 'Content-Type: application/json' \
  -H 'Origin: https://test-u-app-member.qbitnetwork.com:26813' \
  -H 'Referer: https://test-u-app-member.qbitnetwork.com:26813/' \
  -H 'X-Tenant-Id: 489789' \
  -H 'authorization: Bearer <MEMBER_TOKEN>' \
  -H 'fingerprint: <FINGERPRINT>' \
  -H 'lang: zh_CN' \
  -H 'nonce: <NONCE>' \
  -H 'platform: member' \
  -H 'sign: <SIGN>' \
  -H 'timestamp: <TIMESTAMP>'
```

### 14.7 查询卡详情

```bash
curl 'https://test-white-label-member.qbitnetwork.com:26811/member/api/v1/card/<CARD_ID>' \
  -H 'Accept: application/json, text/plain, */*' \
  -H 'Accept-Language: zh,en-US;q=0.9,en;q=0.8,zh-CN;q=0.7' \
  -H 'Connection: keep-alive' \
  -H 'Content-Type: application/json' \
  -H 'Origin: https://test-u-app-member.qbitnetwork.com:26813' \
  -H 'Referer: https://test-u-app-member.qbitnetwork.com:26813/' \
  -H 'X-Tenant-Id: 489789' \
  -H 'authorization: Bearer <MEMBER_TOKEN>' \
  -H 'fingerprint: <FINGERPRINT>' \
  -H 'lang: zh_CN' \
  -H 'nonce: <NONCE>' \
  -H 'platform: member' \
  -H 'sign: <SIGN>' \
  -H 'timestamp: <TIMESTAMP>'
```

### 14.8 查询实体卡费用预览

```bash
curl 'https://test-white-label-member.qbitnetwork.com:26811/member/api/v1/card/<CARD_ID>/physical/fee-preview' \
  -H 'Accept: application/json, text/plain, */*' \
  -H 'Accept-Language: zh,en-US;q=0.9,en;q=0.8,zh-CN;q=0.7' \
  -H 'Connection: keep-alive' \
  -H 'Content-Type: application/json' \
  -H 'Origin: https://test-u-app-member.qbitnetwork.com:26813' \
  -H 'Referer: https://test-u-app-member.qbitnetwork.com:26813/' \
  -H 'X-Tenant-Id: 489789' \
  -H 'authorization: Bearer <MEMBER_TOKEN>' \
  -H 'fingerprint: <FINGERPRINT>' \
  -H 'lang: zh_CN' \
  -H 'nonce: <NONCE>' \
  -H 'platform: member' \
  -H 'sign: <SIGN>' \
  -H 'timestamp: <TIMESTAMP>'
```

### 14.9 提交实体卡邮寄地址

```bash
curl 'https://test-white-label-member.qbitnetwork.com:26811/member/api/v1/card/<CARD_ID>/physical/shipping-address' \
  -H 'Accept: application/json, text/plain, */*' \
  -H 'Accept-Language: zh,en-US;q=0.9,en;q=0.8,zh-CN;q=0.7' \
  -H 'Connection: keep-alive' \
  -H 'Content-Type: application/json' \
  -H 'Origin: https://test-u-app-member.qbitnetwork.com:26813' \
  -H 'Referer: https://test-u-app-member.qbitnetwork.com:26813/' \
  -H 'X-Tenant-Id: 489789' \
  -H 'authorization: Bearer <MEMBER_TOKEN>' \
  -H 'fingerprint: <FINGERPRINT>' \
  -H 'lang: zh_CN' \
  -H 'nonce: <NONCE>' \
  -H 'platform: member' \
  -H 'sign: <SIGN>' \
  -H 'timestamp: <TIMESTAMP>' \
  --data-raw '{"firstName":"San","lastName":"Zhang","phoneCountryCode":"+86","phoneNumber":"13800138000","email":"san.zhang@example.com","addressLine1":"Room 101, Road 1","addressLine2":"Building A","city":"Shanghai","state":"Shanghai","country":"CN","postalCode":"200000"}'
```

### 14.10 查询实体卡物流信息

```bash
curl 'https://test-white-label-member.qbitnetwork.com:26811/member/api/v1/card/<CARD_ID>/physical/shipping-info' \
  -H 'Accept: application/json, text/plain, */*' \
  -H 'Accept-Language: zh,en-US;q=0.9,en;q=0.8,zh-CN;q=0.7' \
  -H 'Connection: keep-alive' \
  -H 'Content-Type: application/json' \
  -H 'Origin: https://test-u-app-member.qbitnetwork.com:26813' \
  -H 'Referer: https://test-u-app-member.qbitnetwork.com:26813/' \
  -H 'X-Tenant-Id: 489789' \
  -H 'authorization: Bearer <MEMBER_TOKEN>' \
  -H 'fingerprint: <FINGERPRINT>' \
  -H 'lang: zh_CN' \
  -H 'nonce: <NONCE>' \
  -H 'platform: member' \
  -H 'sign: <SIGN>' \
  -H 'timestamp: <TIMESTAMP>'
```

### 14.11 激活实体卡

```bash
curl 'https://test-white-label-member.qbitnetwork.com:26811/member/api/v1/card/<CARD_ID>/physical/activate' \
  -X POST \
  -H 'Accept: application/json, text/plain, */*' \
  -H 'Accept-Language: zh,en-US;q=0.9,en;q=0.8,zh-CN;q=0.7' \
  -H 'Connection: keep-alive' \
  -H 'Content-Type: application/json' \
  -H 'Origin: https://test-u-app-member.qbitnetwork.com:26813' \
  -H 'Referer: https://test-u-app-member.qbitnetwork.com:26813/' \
  -H 'X-Tenant-Id: 489789' \
  -H 'authorization: Bearer <MEMBER_TOKEN>' \
  -H 'fingerprint: <FINGERPRINT>' \
  -H 'lang: zh_CN' \
  -H 'nonce: <NONCE>' \
  -H 'platform: member' \
  -H 'sign: <SIGN>' \
  -H 'timestamp: <TIMESTAMP>'
```

### 14.12 设置或修改实体卡 PIN

```bash
curl 'https://test-white-label-member.qbitnetwork.com:26811/member/api/v1/card/<CARD_ID>/pin' \
  -H 'Accept: application/json, text/plain, */*' \
  -H 'Accept-Language: zh,en-US;q=0.9,en;q=0.8,zh-CN;q=0.7' \
  -H 'Connection: keep-alive' \
  -H 'Content-Type: application/json' \
  -H 'Origin: https://test-u-app-member.qbitnetwork.com:26813' \
  -H 'Referer: https://test-u-app-member.qbitnetwork.com:26813/' \
  -H 'X-Tenant-Id: 489789' \
  -H 'authorization: Bearer <MEMBER_TOKEN>' \
  -H 'fingerprint: <FINGERPRINT>' \
  -H 'lang: zh_CN' \
  -H 'nonce: <NONCE>' \
  -H 'platform: member' \
  -H 'sign: <SIGN>' \
  -H 'timestamp: <TIMESTAMP>' \
  --data-raw '{"pin":"123456"}'
```

### 14.13 会员端冻结实体卡

```bash
curl 'https://test-white-label-member.qbitnetwork.com:26811/member/api/v1/card/freeze/<CARD_ID>' \
  -X POST \
  -H 'Accept: application/json, text/plain, */*' \
  -H 'Accept-Language: zh,en-US;q=0.9,en;q=0.8,zh-CN;q=0.7' \
  -H 'Connection: keep-alive' \
  -H 'Content-Type: application/json' \
  -H 'Origin: https://test-u-app-member.qbitnetwork.com:26813' \
  -H 'Referer: https://test-u-app-member.qbitnetwork.com:26813/' \
  -H 'X-Tenant-Id: 489789' \
  -H 'authorization: Bearer <MEMBER_TOKEN>' \
  -H 'fingerprint: <FINGERPRINT>' \
  -H 'lang: zh_CN' \
  -H 'nonce: <NONCE>' \
  -H 'platform: member' \
  -H 'sign: <SIGN>' \
  -H 'timestamp: <TIMESTAMP>'
```

### 14.14 会员端解冻实体卡

```bash
curl 'https://test-white-label-member.qbitnetwork.com:26811/member/api/v1/card/unfreeze/<CARD_ID>' \
  -X POST \
  -H 'Accept: application/json, text/plain, */*' \
  -H 'Accept-Language: zh,en-US;q=0.9,en;q=0.8,zh-CN;q=0.7' \
  -H 'Connection: keep-alive' \
  -H 'Content-Type: application/json' \
  -H 'Origin: https://test-u-app-member.qbitnetwork.com:26813' \
  -H 'Referer: https://test-u-app-member.qbitnetwork.com:26813/' \
  -H 'X-Tenant-Id: 489789' \
  -H 'authorization: Bearer <MEMBER_TOKEN>' \
  -H 'fingerprint: <FINGERPRINT>' \
  -H 'lang: zh_CN' \
  -H 'nonce: <NONCE>' \
  -H 'platform: member' \
  -H 'sign: <SIGN>' \
  -H 'timestamp: <TIMESTAMP>'
```

### 14.15 Admin 查询卡列表

```bash
curl 'https://test-white-label-admin.qbitnetwork.com:26811/admin/api/v1/card/page?status=ACTIVE&cardMode=PHYSICAL_CARD&page=1&size=10' \
  -H 'Accept: application/json, text/plain, */*' \
  -H 'Accept-Language: zh,en-US;q=0.9,en;q=0.8,zh-CN;q=0.7' \
  -H 'Connection: keep-alive' \
  -H 'Content-Type: application/json' \
  -H 'Origin: https://test-u-app-admin.qbitnetwork.com:26813' \
  -H 'Referer: https://test-u-app-admin.qbitnetwork.com:26813/' \
  -H 'X-Tenant-Id: 489789' \
  -H 'authorization: Bearer <ADMIN_TOKEN>' \
  -H 'fingerprint: <FINGERPRINT>' \
  -H 'lang: zh_CN' \
  -H 'nonce: <NONCE>' \
  -H 'platform: admin' \
  -H 'sign: <SIGN>' \
  -H 'timestamp: <TIMESTAMP>'
```

### 14.16 Admin 查询卡详情

```bash
curl 'https://test-white-label-admin.qbitnetwork.com:26811/admin/api/v1/card/<CARD_ID>' \
  -H 'Accept: application/json, text/plain, */*' \
  -H 'Accept-Language: zh,en-US;q=0.9,en;q=0.8,zh-CN;q=0.7' \
  -H 'Connection: keep-alive' \
  -H 'Content-Type: application/json' \
  -H 'Origin: https://test-u-app-admin.qbitnetwork.com:26813' \
  -H 'Referer: https://test-u-app-admin.qbitnetwork.com:26813/' \
  -H 'X-Tenant-Id: 489789' \
  -H 'authorization: Bearer <ADMIN_TOKEN>' \
  -H 'fingerprint: <FINGERPRINT>' \
  -H 'lang: zh_CN' \
  -H 'nonce: <NONCE>' \
  -H 'platform: admin' \
  -H 'sign: <SIGN>' \
  -H 'timestamp: <TIMESTAMP>'
```

### 14.17 Admin 冻结卡

```bash
curl 'https://test-white-label-admin.qbitnetwork.com:26811/admin/api/v1/card/freeze/<CARD_ID>' \
  -X POST \
  -H 'Accept: application/json, text/plain, */*' \
  -H 'Accept-Language: zh,en-US;q=0.9,en;q=0.8,zh-CN;q=0.7' \
  -H 'Connection: keep-alive' \
  -H 'Content-Type: application/json' \
  -H 'Origin: https://test-u-app-admin.qbitnetwork.com:26813' \
  -H 'Referer: https://test-u-app-admin.qbitnetwork.com:26813/' \
  -H 'X-Tenant-Id: 489789' \
  -H 'authorization: Bearer <ADMIN_TOKEN>' \
  -H 'fingerprint: <FINGERPRINT>' \
  -H 'lang: zh_CN' \
  -H 'nonce: <NONCE>' \
  -H 'platform: admin' \
  -H 'sign: <SIGN>' \
  -H 'timestamp: <TIMESTAMP>'
```

### 14.18 Admin 解冻卡

```bash
curl 'https://test-white-label-admin.qbitnetwork.com:26811/admin/api/v1/card/unfreeze/<CARD_ID>' \
  -X POST \
  -H 'Accept: application/json, text/plain, */*' \
  -H 'Accept-Language: zh,en-US;q=0.9,en;q=0.8,zh-CN;q=0.7' \
  -H 'Connection: keep-alive' \
  -H 'Content-Type: application/json' \
  -H 'Origin: https://test-u-app-admin.qbitnetwork.com:26813' \
  -H 'Referer: https://test-u-app-admin.qbitnetwork.com:26813/' \
  -H 'X-Tenant-Id: 489789' \
  -H 'authorization: Bearer <ADMIN_TOKEN>' \
  -H 'fingerprint: <FINGERPRINT>' \
  -H 'lang: zh_CN' \
  -H 'nonce: <NONCE>' \
  -H 'platform: admin' \
  -H 'sign: <SIGN>' \
  -H 'timestamp: <TIMESTAMP>'
```

### 14.19 Webhook 回放示例

```bash
curl 'https://test-white-label-admin.qbitnetwork.com:26811/admin/api/v1/open-api/webhook' \
  -H 'Accept: application/json, text/plain, */*' \
  -H 'Content-Type: application/json' \
  -H 'X-Tenant-Id: 489789' \
  --data-raw '{"id":"<WEBHOOK_EVENT_ID>","eventType":"PHYSICAL_CARD_ACTIVATED","apiVersion":"v1","createTime":"2026-06-09T00:00:00Z","code":"000000","message":"success","resource":"{\"id\":\"<OUTER_CARD_ID>\",\"referenceId\":\"<LOCAL_CARD_UNIQUE_KEY>\",\"status\":\"ACTIVE\",\"cardMode\":\"PHYSICAL_CARD\"}"}'
```
