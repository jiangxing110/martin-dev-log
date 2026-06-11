# Physical Card Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 为 Infinity Launch 支持实体卡申请、邮寄地址提交、物流查询、实体卡激活、PIN 设置/修改，以及 Admin 卡类型展示与筛选。

**Architecture:** 在现有 VCC 卡模块上扩展实体卡能力。`card` 表保存通用卡主数据，复用现有 `type` 字段表示卡类型，新增实体卡详情表保存邮寄、物流、实体卡履约状态和 PIN 状态；三方调用统一走 `InterlaceApiClientHelper`，复用 Interlace SDK 3.0.9 的 `CardApi`、`PhysicalCardApi`、`SecurityApi`。

**Tech Stack:** Java 17, Spring Boot 3.3.3, MyBatis-Flex, Lombok, springdoc OpenAPI 3, Interlace Java SDK 3.0.9。

---

## 1. 需求范围

### 移动端

- 开卡入口拆为新增虚拟卡、新增实体卡。
- 实体卡 + 虚拟卡最多 3 张。
- 实体卡最多 1 张。
- 账户无 `45492418` 卡段权限时隐藏新增实体卡。
- 新增实体卡页面仅展示 `45492418` 卡段。
- 实体卡开卡成功后进入邮寄地址页。
- 未填写地址退出时，实体卡处于处理中，详情页展示填写邮寄地址按钮。
- 处理中实体卡隐藏冻结/解冻按钮。
- 可查询物流信息。
- 已提交邮寄信息且处理中时可激活实体卡。
- 激活后展示设置/修改 PIN 与冻结/解冻。

### Admin

- markup 暂时隐藏金属卡制卡费，仅保留 BZ 黑白塑料卡。
- 卡管理增加卡类型：实体卡 / 虚拟卡。
- 卡管理支持按卡类型筛选。

## 2. SDK 能力确认

当前项目依赖 `money.interlace.sdk:interlace-java-sdk:3.0.9`，本地已确认支持：

- 创建实体卡：`CreateBudgetCardReqDTO` 支持 `cardType` 和 `physicalCardDesignId`。
- 创建卡：`CardApi#createBudgetCard(...)`。
- 提交邮寄信息/发货：`PhysicalCardApi#physicalCardBulkShip(...)`，入参 `BulkShipReqDTO`。
- 查询物流：`PhysicalCardApi#getShippingInfo(...)`，返回 `ShippingInfoResource`。
- 激活实体卡：`PhysicalCardApi#physicalCardActivate(...)`，入参 `ActivatePhysicalCardReqDTO`。
- 设置/修改 PIN：`SecurityApi#updateCardPin(...)`，入参 `UpdatePINReqDTO`。
- 查询实体卡费用：`PhysicalCardApi#getPhysicalCardFees(...)`。

当前项目缺口：

- `ApiResource` 未初始化 `PhysicalCardApi`、`SecurityApi`。
- `InterlaceApiClientHelper` 未暴露 `createPhysicalCardApi(...)`、`createSecurityApi(...)`。
- `CardServiceImpl#createCard(...)` 当前固定传 `CreateBudgetCardReqDTO.CardModeEnum.VIRTUAL_CARD`，且 Java 实体尚未映射数据库已有的 `card.type`。
- `OpenApiWebHookServiceImpl` 当前只分发 KYC、区块链、预算/卡交易、扫码支付事件，尚未处理 `CARD.CREATED`、`CARD.UPDATED`、`CARD.DELETED`、`CARD.SETTING.UPDATED`、`PHYSICAL_CARD_ACTIVATED` 等卡生命周期事件。

## 3. 数据模型

推荐新增实体卡扩展表，避免把邮寄、物流、PIN 等实体卡专属字段塞入现有 `card` 表。

### 3.1 复用 `card.type` 字段

现有数据库表中已存在 `type` 字段，并且 `CardMapper#queryWhiteLabelVirtualCardTrends(...)` 已使用 `card.type = 'VIRTUAL_CARD'` 统计虚拟卡数量。

本期不新增 `card_mode` 字段，改为复用数据库已有 `type` 并补齐 Java 侧映射与查询：

- `Card` 实体增加 `type` 字段，对应数据库 `card.type`。
- `CardQuery` / `QueryCardBO` 增加 `type` 条件。
- `CardResponseDTO` 对外命名建议使用 `cardType`，内部落库复用 `type`。
- 历史数据如果已有 `type = VIRTUAL_CARD`，不需要回填；如果部分历史数据为空，再单独追加一次 `UPDATE card SET type = 'VIRTUAL_CARD' WHERE type IS NULL AND delete_time IS NULL`。

### 3.2 新增 `card_physical_detail` 表

建议字段：

- `id`：雪花主键。
- `card_id`：本地 `card.id`，唯一索引。
- `tenant_id`：租户 ID。
- `account_id`：本地账户 ID。
- `outer_account_id`：三方账户 ID 快照。
- `outer_card_id`：三方卡 ID，即 `card.token` 快照。
- `physical_card_design_id`：实体卡样式 ID。
- `physical_card_status`：本地实体卡履约状态。
- `shipping_submitted`：是否已提交邮寄信息。
- `recipient_first_name` / `recipient_last_name`：收件人姓名。
- `recipient_phone_country_code` / `recipient_phone_number`：收件人手机号。
- `recipient_email`：收件人邮箱。
- `shipping_address_json`：邮寄地址快照。
- `production_fee`：制卡费快照。
- `shipping_fee`：运费快照。
- `total_cost`：总费用快照。
- `express_company`：快递公司。
- `tracking_number`：快递单号。
- `tracking_url`：物流 URL。
- `pin_set`：是否已设置 PIN。
- `create_time` / `update_time` / `delete_time` / `version`：审计与版本字段。

索引建议：

- `uk_card_physical_detail_card_id(card_id)`。
- `idx_card_physical_detail_account(tenant_id, account_id)`。
- `idx_card_physical_detail_status(tenant_id, physical_card_status)`。

## 4. 枚举与状态

### 4.1 `CardTypeEnum`

路径：`app-api/app-api-vcc/src/main/java/com/qbit/white/label/api/card/model/enums/CardTypeEnum.java`

取值：

- `VIRTUAL_CARD`：虚拟卡。
- `PHYSICAL_CARD`：实体卡。

### 4.2 `PhysicalCardStatusEnum`

路径：`app-api/app-api-vcc/src/main/java/com/qbit/white/label/api/card/model/enums/PhysicalCardStatusEnum.java`

取值：

- `PENDING_SHIPPING_ADDRESS`：已开实体卡，待提交邮寄地址。
- `PROCESSING`：已提交地址，制卡/运输处理中。
- `SHIPPING`：有物流信息，运输中。
- `ACTIVATED`：已激活。
- `UNKNOWN`：三方状态无法识别。

注意：不要用 `CardStatus.PENDING` 直接承载实体卡履约流。`card.status` 更接近三方卡状态，实体卡邮寄/激活应使用独立业务状态。

## 5. 接口设计

### 5.1 开卡能力摘要

新增：`GET /member/api/v1/card/create-capability`

返回字段：

- `totalAvailableCount`：剩余可开卡数量，按实体卡 + 虚拟卡总数计算。
- `virtualCardAvailable`：是否可开虚拟卡。
- `physicalCardAvailable`：是否可开实体卡。
- `physicalCardReason`：实体卡不可用原因。
- `physicalCardBin`：固定返回 `45492418`。
- `physicalCardBinId`：实体卡 BIN ID。

不可用原因：

- `TOTAL_LIMIT_REACHED`：总卡数已达 3。
- `PHYSICAL_LIMIT_REACHED`：实体卡已达 1。
- `BIN_NOT_ALLOWED`：账户无 `45492418` 卡段权限。

### 5.2 创建卡

调整：`POST /member/api/v1/card`

`CreateCardDTO` 新增：

- `cardType`：为空时默认 `VIRTUAL_CARD`，兼容旧前端；服务层最终写入 `card.type`。
- `physicalCardDesignId`：实体卡样式 ID。

实体卡创建规则：

- 总卡数不能超过 3。
- 实体卡不能超过 1。
- 必须拥有 `45492418` 卡段权限。
- 仅允许使用配置的实体卡 BIN/BIN ID。
- 调用 `CardApi#createBudgetCard(...)` 时传 `CardModeEnum.PHYSICAL_CARD` 和 `physicalCardDesignId`。
- 创建成功后写 `card.type = PHYSICAL_CARD`，并新增实体卡详情，状态为 `PENDING_SHIPPING_ADDRESS`。

### 5.3 提交邮寄地址

新增：`POST /member/api/v1/card/{id}/physical/shipping-address`

Request 字段：

- `firstName`
- `lastName`
- `phoneCountryCode`
- `phoneNumber`
- `email`
- `addressLine1`
- `addressLine2`
- `city`
- `state`
- `country`
- `postalCode`

规则：

- 只允许本人账户实体卡提交。
- 仅 `PENDING_SHIPPING_ADDRESS` 状态可提交。
- 姓名只允许英文字符、空格、连字符和撇号。
- 成功调用 `PhysicalCardApi#physicalCardBulkShip(...)` 后保存收件人与地址快照。
- 状态更新为 `PROCESSING`。

### 5.4 查询物流

新增：`GET /member/api/v1/card/{id}/physical/shipping-info`

规则：

- 只允许本人账户实体卡查询。
- 调用 `PhysicalCardApi#getShippingInfo(...)`。
- 无快递公司或单号时返回 `available = false`，不抛异常。
- 有物流信息时同步快递公司、单号、URL，状态可更新为 `SHIPPING`。

### 5.5 激活实体卡

新增：`POST /member/api/v1/card/{id}/physical/activate`

规则：

- 只允许本人账户实体卡操作。
- 必须已提交邮寄地址。
- `PROCESSING` 或 `SHIPPING` 状态允许激活。
- 调用 `PhysicalCardApi#physicalCardActivate(...)`。
- 成功后实体卡状态更新为 `ACTIVATED`，并同步 `card.status`。

### 5.6 设置/修改 PIN

新增：`POST /member/api/v1/card/{id}/pin`

Request 字段：

- `pin`

规则：

- 只允许本人账户实体卡操作。
- 仅已激活实体卡可设置/修改 PIN。
- PIN 不落库，不打印日志。
- 调用 `SecurityApi#updateCardPin(...)`。
- 成功后只保存 `pin_set = true`。

### 5.7 Admin 卡列表

调整：`GET /admin/api/v1/card/page`

新增 query 参数：

- `cardType`：`VIRTUAL_CARD` / `PHYSICAL_CARD`。

`CardResponseDTO` 新增返回：

- `cardType`
- `physicalCardStatus`
- `pinSet`

### 5.8 Card / Physical Card Webhook 同步

调整现有 webhook 分发：`POST /admin/api/v1/open-api/webhook`

当前 `WebHookEventTypeEnum` 已有但未处理的卡生命周期事件：

- `CARD.CREATED`
- `CARD.UPDATED`
- `CARD.DELETED`
- `CARD.SETTING.UPDATED`
- `PHYSICAL_CARD_ACTIVATED`

新增业务处理建议：

- 新增 `CardWebhookService`，由 `OpenApiWebHookServiceImpl` 分发上述事件。
- `CARD.CREATED` / `CARD.UPDATED`：按三方卡 ID、referenceId 或本地 uniqueKey 查找 `card`，同步 `status`、`currency`、`bin`、`cardLastFour`、`label`、`budgetId`、`cardholderId`、`billingAddress`、`type`。
- `CARD.DELETED`：同步本地卡状态为 `INACTIVE` 或三方返回的删除/取消状态，不物理删除本地记录。
- `CARD.SETTING.UPDATED`：用于同步 PIN/消费控制等卡设置变化；若 resource 能识别 PIN 更新，则同步实体卡详情 `pin_set = true`。
- `PHYSICAL_CARD_ACTIVATED`：按三方卡 ID 找到实体卡详情，设置 `physical_card_status = ACTIVATED`，同时同步 `card.status`。
- 如果 Interlace 后续提供物流/发货事件，例如 `PHYSICAL_CARD.SHIPPED`、`PHYSICAL_CARD.UPDATED`、`SHIPPING.UPDATED`，需要追加枚举并同步快递公司、单号、物流 URL；当前枚举未包含物流事件，所以物流仍以主动查询 `getShippingInfo(...)` 为主。

幂等规则：

- 继续复用 `webhook_event` 的 eventId + SUCCESS 幂等。
- 业务更新按三方卡 ID / referenceId 做幂等 upsert，不因重复 webhook 创建重复卡或重复实体卡详情。
- 找不到本地卡时记录 warn，不抛出导致 webhook 一直重试；后续可通过定时同步或人工排查补偿。

## 6. 文件改动地图

### API 契约层

- Modify: `app-api/app-api-vcc/src/main/java/com/qbit/white/label/api/card/service/CardService.java`
- Modify: `app-api/app-api-vcc/src/main/java/com/qbit/white/label/api/card/model/dto/request/CreateCardDTO.java`
- Modify: `app-api/app-api-vcc/src/main/java/com/qbit/white/label/api/card/model/dto/response/CardResponseDTO.java`
- Modify: `app-api/app-api-vcc/src/main/java/com/qbit/white/label/api/card/model/query/CardQuery.java`
- Modify: `app-api/app-api-vcc/src/main/java/com/qbit/white/label/api/card/model/bo/QueryCardBO.java`
- Create: `app-api/app-api-vcc/src/main/java/com/qbit/white/label/api/card/model/enums/CardTypeEnum.java`
- Create: `app-api/app-api-vcc/src/main/java/com/qbit/white/label/api/card/model/enums/PhysicalCardStatusEnum.java`
- Create: `app-api/app-api-vcc/src/main/java/com/qbit/white/label/api/card/model/dto/request/PhysicalCardShippingAddressRequest.java`
- Create: `app-api/app-api-vcc/src/main/java/com/qbit/white/label/api/card/model/dto/request/CardPinRequest.java`
- Create: `app-api/app-api-vcc/src/main/java/com/qbit/white/label/api/card/model/dto/response/CardCreateCapabilityResponseDTO.java`
- Create: `app-api/app-api-vcc/src/main/java/com/qbit/white/label/api/card/model/dto/response/PhysicalCardShippingInfoResponseDTO.java`

### Infra 层

- Modify: `app-infra/app-infra-business/src/main/java/com/qbit/white/label/infra/business/initializer/ApiResource.java`
- Modify: `app-infra/app-infra-business/src/main/java/com/qbit/white/label/infra/business/base/InterlaceApiClientHelper.java`

### Biz 层

- Modify: `app-biz/app-biz-vcc/src/main/java/com/qbit/white/label/biz/card/dal/entity/Card.java`
- Modify: `app-biz/app-biz-vcc/src/main/java/com/qbit/white/label/biz/card/dal/repository/CardRepository.java`
- Modify: `app-biz/app-biz-vcc/src/main/java/com/qbit/white/label/biz/card/convertor/CardConvertor.java`
- Modify: `app-biz/app-biz-vcc/src/main/java/com/qbit/white/label/biz/card/service/impl/CardServiceImpl.java`
- Create: `app-biz/app-biz-vcc/src/main/java/com/qbit/white/label/biz/card/dal/entity/CardPhysicalDetail.java`
- Create: `app-biz/app-biz-vcc/src/main/java/com/qbit/white/label/biz/card/dal/mapper/CardPhysicalDetailMapper.java`
- Create: `app-biz/app-biz-vcc/src/main/java/com/qbit/white/label/biz/card/dal/repository/CardPhysicalDetailRepository.java`
- Create: `app-biz/app-biz-vcc/src/main/java/com/qbit/white/label/biz/card/service/PhysicalCardService.java`
- Create: `app-biz/app-biz-vcc/src/main/java/com/qbit/white/label/biz/card/service/impl/PhysicalCardServiceImpl.java`
- Create: `app-biz/app-biz-vcc/src/main/java/com/qbit/white/label/biz/card/service/CardWebhookService.java`
- Create: `app-biz/app-biz-vcc/src/main/java/com/qbit/white/label/biz/card/service/impl/CardWebhookServiceImpl.java`
- Create: `app-biz/app-biz-vcc/src/main/java/com/qbit/white/label/biz/card/constant/PhysicalCardConstants.java`

### Web 层

- Modify: `app-web/app-web-member/src/main/java/com/qbit/white/label/member/api/card/CardController.java`
- Modify: `app-web/app-web-admin/src/main/java/com/qbit/white/label/admin/api/card/CardController.java`
- Modify: `app-biz/app-biz-system/src/main/java/com/qbit/white/label/biz/system/service/impl/OpenApiWebHookServiceImpl.java`
- Modify: `app-core/src/main/java/com/qbit/white/label/core/enums/WebHookEventTypeEnum.java`，仅在三方确认新增物流/发货事件时修改

### DB 迁移

- Create: `qbit-core/src/main/resources/db/migration/V20260609_01__add_physical_card_detail.sql`

如果实际迁移目录不同，实施前以仓库现有 Flyway 目录为准。

## 7. 实施任务

### Task 1: 接入 SDK API 客户端

- [ ] 修改 `ApiResource`，增加 `PhysicalCardApi`、`SecurityApi` 字段。
- [ ] 在构造方法中用同一个 `ApiClient` 初始化两个 API。
- [ ] 修改 `InterlaceApiClientHelper`，增加 `createPhysicalCardApi(Long tenantId)` 和 `createSecurityApi(Long tenantId)`。
- [ ] 编译验证：`mvn compile -q -pl app-infra/app-infra-business -am`。

### Task 2: 增加卡类型与实体卡状态契约

- [ ] 新增 `CardTypeEnum`。
- [ ] 新增 `PhysicalCardStatusEnum`。
- [ ] `CreateCardDTO` 增加 `cardType`、`physicalCardDesignId`。
- [ ] `CardResponseDTO` 增加 `cardType`、`physicalCardStatus`、`pinSet`。
- [ ] `CardQuery`、`QueryCardBO` 增加 `type` 查询条件。
- [ ] 编译验证：`mvn compile -q -pl app-api/app-api-vcc -am`。

### Task 3: 增加数据库结构与实体

- [ ] 确认数据库 `card.type` 字段已存在。
- [ ] 如线上历史数据存在 `type IS NULL`，迁移脚本只补充回填：`UPDATE card SET type = 'VIRTUAL_CARD' WHERE type IS NULL AND delete_time IS NULL`。
- [ ] 新增 `card_physical_detail` 表。
- [ ] 新增 `Card.type` 字段，映射数据库已有 `card.type`。
- [ ] 新增 `CardPhysicalDetail` 实体。
- [ ] 新增 `CardPhysicalDetailMapper`。
- [ ] 新增 `CardPhysicalDetailRepository`。
- [ ] 编译验证：`mvn compile -q -pl app-biz/app-biz-vcc -am`。

### Task 4: 改造创建卡流程

- [ ] 新增 `PhysicalCardConstants`，集中定义实体卡 BIN、BIN ID、默认样式 ID、默认制卡费用配置键。
- [ ] `CardRepository` 支持 `type` 查询和计数。
- [ ] `CardServiceImpl#createCard` 读取 `CreateCardDTO.cardType/cardType`，为空默认虚拟卡。
- [ ] 虚拟卡创建保持现有行为。
- [ ] 实体卡创建前校验总卡数小于 3。
- [ ] 实体卡创建前校验实体卡数小于 1。
- [ ] 实体卡创建前校验账户具备 `45492418` 卡段权限。
- [ ] 实体卡创建时传 `CardModeEnum.PHYSICAL_CARD` 和 `physicalCardDesignId`。
- [ ] 本地 `card.type` 写 `PHYSICAL_CARD`。
- [ ] 三方创建成功后新增实体卡详情，状态 `PENDING_SHIPPING_ADDRESS`。
- [ ] 三方创建失败时清理本地 `card` 和实体卡详情。
- [ ] 编译验证：`mvn compile -q -pl app-biz/app-biz-vcc -am`。

### Task 5: 开卡能力摘要接口

- [ ] 新增 `CardCreateCapabilityResponseDTO`。
- [ ] `CardService` 增加 `getCreateCapability()`。
- [ ] 服务中统计当前账户总卡数与实体卡数。
- [ ] 服务中调用 `CardBinService#queryCardBins()` 判断是否具备 `45492418` 权限。
- [ ] Member `CardController` 增加 `GET /create-capability`。
- [ ] 编译验证：`mvn compile -q -pl app-web/app-web-member -am`。

### Task 6: 提交邮寄地址

- [ ] 新增 `PhysicalCardShippingAddressRequest`，加参数校验。
- [ ] 新增 `PhysicalCardService#submitShippingAddress(...)`。
- [ ] 实现中校验卡归属、卡类型、实体卡状态。
- [ ] 校验收件人姓名仅支持英文/拼音字符。
- [ ] 构造 `BulkShipReqDTO`，调用 `PhysicalCardApi#physicalCardBulkShip(...)`。
- [ ] 成功后保存收件人、地址、费用快照，状态改为 `PROCESSING`。
- [ ] Member `CardController` 增加 `POST /{id}/physical/shipping-address`。
- [ ] 编译验证：`mvn compile -q -pl app-web/app-web-member -am`。

### Task 7: 查询物流信息

- [ ] 新增 `PhysicalCardShippingInfoResponseDTO`。
- [ ] 新增 `PhysicalCardService#getShippingInfo(Long cardId)`。
- [ ] 调用 `PhysicalCardApi#getShippingInfo(...)`。
- [ ] 无物流单号时返回 `available = false`。
- [ ] 有物流单号时同步快递公司、单号、URL，状态可改为 `SHIPPING`。
- [ ] Member `CardController` 增加 `GET /{id}/physical/shipping-info`。
- [ ] 编译验证：`mvn compile -q -pl app-web/app-web-member -am`。

### Task 8: 激活实体卡

- [ ] 新增 `PhysicalCardService#activate(Long cardId)`。
- [ ] 校验实体卡已提交邮寄地址。
- [ ] 构造 `ActivatePhysicalCardReqDTO`，设置三方账户 ID 和 `cardholderId`。
- [ ] 调用 `PhysicalCardApi#physicalCardActivate(...)`。
- [ ] 成功后实体卡状态改为 `ACTIVATED`，同步 `card.status`。
- [ ] Member `CardController` 增加 `POST /{id}/physical/activate`。
- [ ] 编译验证：`mvn compile -q -pl app-web/app-web-member -am`。

### Task 9: 设置/修改 PIN

- [ ] 新增 `CardPinRequest`。
- [ ] PIN 校验先按 6 位数字处理，联调时按三方规则修正。
- [ ] 新增 `PhysicalCardService#updatePin(Long cardId, CardPinRequest request)`。
- [ ] 校验实体卡已激活。
- [ ] 构造 `UpdatePINReqDTO`，设置 PIN 和三方账户 ID。
- [ ] 调用 `SecurityApi#updateCardPin(...)`。
- [ ] 不保存 PIN 明文，不输出 PIN 日志。
- [ ] 成功后设置 `pin_set = true`。
- [ ] Member `CardController` 增加 `POST /{id}/pin`。
- [ ] 编译验证：`mvn compile -q -pl app-web/app-web-member -am`。

### Task 10: Admin 卡类型筛选

- [ ] Admin `/card/page` 增加 `cardType` 请求参数，服务层映射到 `card.type`。
- [ ] `QueryCardBO`、`CardQuery` 透传 `type`。
- [ ] `CardRepository` 按 `card.type` 过滤。
- [ ] `CardConvertor` 返回 `cardType`。
- [ ] 对实体卡补充 `physicalCardStatus`、`pinSet`。
- [ ] 编译验证：`mvn compile -q -pl app-web/app-web-admin -am`。

### Task 11: 限制处理中实体卡冻结/解冻

- [ ] 在 `CardServiceImpl#suspendCard(...)` 前增加实体卡状态校验。
- [ ] 在 `CardServiceImpl#enableCard(...)` 前增加实体卡状态校验。
- [ ] `PENDING_SHIPPING_ADDRESS`、`PROCESSING`、`SHIPPING` 状态禁止冻结/解冻。
- [ ] `ACTIVATED` 状态沿用现有冻结/解冻逻辑。
- [ ] 编译验证：`mvn compile -q -pl app-biz/app-biz-vcc -am`。

### Task 12: Card / Physical Card Webhook 同步

- [ ] 新增 `CardWebhookService`，定义 `handleCardCreatedOrUpdated(...)`、`handleCardDeleted(...)`、`handleCardSettingUpdated(...)`、`handlePhysicalCardActivated(...)`。
- [ ] 新增 `CardWebhookServiceImpl`，解析 webhook resource 中的三方卡 ID、referenceId、accountId、status、bin、cardLastFour、cardholderId、cardMode 等字段。
- [ ] `CARD.CREATED` / `CARD.UPDATED` 事件按三方卡 ID 或 referenceId 查找本地 `card` 并同步基础字段。
- [ ] `CARD.DELETED` 事件同步本地 `card.status`，不物理删除。
- [ ] `CARD.SETTING.UPDATED` 事件同步可识别的卡设置；如果 resource 表明 PIN 已更新，则设置实体卡详情 `pin_set = true`。
- [ ] `PHYSICAL_CARD_ACTIVATED` 事件同步 `card_physical_detail.physical_card_status = ACTIVATED`，并同步 `card.status`。
- [ ] 修改 `OpenApiWebHookServiceImpl`，在 switch 中分发 `CARD_CREATED`、`CARD_UPDATED`、`CARD_DELETED`、`CARD_SETTING_UPDATED`、`PHYSICAL_CARD_ACTIVATED`。
- [ ] 找不到本地卡时记录包含 eventType、outerCardId、referenceId 的 warn 日志并返回成功，避免三方重复重试造成噪声。
- [ ] 如果三方提供物流/发货事件，补充 `WebHookEventTypeEnum` 枚举并在 `CardWebhookService` 同步物流字段。
- [ ] 静态检查 webhook 幂等：重复 eventId 不重复更新；重复业务 resource 不重复创建实体卡详情。

### Task 13: 测试

建议覆盖：

- [ ] 不传 `cardType` 创建卡时仍为虚拟卡。
- [ ] 创建实体卡成功时写入 `card.type = PHYSICAL_CARD`。
- [ ] 创建实体卡成功时新增实体卡详情。
- [ ] 总卡数达到 3 时不能创建任何新卡。
- [ ] 已有 1 张实体卡时不能再创建实体卡。
- [ ] 无 `45492418` 权限时实体卡能力不可用。
- [ ] 待地址状态可提交邮寄地址。
- [ ] 已激活实体卡不可重复提交地址。
- [ ] 无物流信息时返回 `available = false`。
- [ ] 有物流信息时同步快递公司和单号。
- [ ] 未提交地址不能激活。
- [ ] 已提交地址可以激活。
- [ ] 已激活实体卡可设置 PIN。
- [ ] PIN 明文不落库。
- [ ] 处理中实体卡不可冻结/解冻。
- [ ] Admin 按 `cardType` 筛选只返回对应卡类型。
- [ ] `CARD.UPDATED` webhook 可同步本地卡状态、卡后四位和卡类型。
- [ ] `CARD.DELETED` webhook 可同步本地卡删除/取消状态。
- [ ] `PHYSICAL_CARD_ACTIVATED` webhook 可兜底同步实体卡已激活状态。
- [ ] 重复 webhook eventId 不重复处理。

建议命令：

- `mvn test -DskipTests=false -pl app-biz/app-biz-vcc -am`
- `mvn test -DskipTests=false -pl app-web/app-web-member -am`
- `mvn test -DskipTests=false -pl app-web/app-web-admin -am`

## 8. 联调验收清单

- [ ] 无实体卡 BIN 权限时只展示新增虚拟卡。
- [ ] 总卡数 3 张时隐藏新增虚拟卡和新增实体卡。
- [ ] 已有实体卡时隐藏新增实体卡。
- [ ] 实体卡申请页只展示 `45492418`。
- [ ] 实体卡创建后跳转邮寄地址页。
- [ ] 未提交地址退出后详情页展示填写邮寄地址按钮。
- [ ] 处理中实体卡不展示冻结/解冻。
- [ ] 提交地址后展示制卡费、运费、总支出。
- [ ] 有物流信息时展示快递公司和单号。
- [ ] 无物流信息时展示暂未查询到物流订单信息。
- [ ] 激活确认后实体卡变为已激活。
- [ ] 激活后展示设置卡 PIN。
- [ ] 设置 PIN 后展示修改卡 PIN。
- [ ] Admin 卡管理展示卡类型。
- [ ] Admin 卡管理可按实体卡/虚拟卡筛选。
- [ ] 三方推送 `CARD.UPDATED` 后，本地卡状态与后四位能同步。
- [ ] 三方推送 `PHYSICAL_CARD_ACTIVATED` 后，即使主动激活接口未完成本地更新，详情页也能展示已激活。
- [ ] 三方重复推送同一 webhook 事件时，本地不会重复写入或重复创建实体卡详情。

## 9. 风险与待确认项

1. `physicalCardDesignId` 未在需求文档中给出，需要确认 BZ Signature 黑白塑料卡对应 ID。
2. 文档给的是 BIN `45492418`，但创建卡接口需要 `binId`，需要确认三方返回的实际 BIN ID。
3. 制卡费文档存在 “报价 10，系统默认 12” 的冲突，需要产品/运营确认最终口径。
4. 运费“成本 + 5” 需要确认成本来源：SDK `getPhysicalCardFees(...)`，还是 qbit-assets 费用系统。
5. PIN 位数需要确认三方约束；计划暂按 6 位数字。
6. 激活接口 SDK 入参只有 `accountId` 和 `cardholderId`，“自动传 KYC 信息”可能由三方按 cardholder 自动完成，联调要重点验证。
7. `physicalCardBulkShip(...)` 是批量接口，单卡发货传单元素 `cardIds`。
8. 新增异常码应追加到现有异常码文件末尾，不直接抛通用 `RuntimeException`。
9. 卡生命周期 webhook 的 resource 字段结构需要用三方真实样例确认，尤其是 `CARD.SETTING.UPDATED` 是否能明确区分 PIN 更新。
10. 当前枚举未包含物流/发货 webhook；如果三方支持物流事件，需要追加枚举和同步逻辑，否则物流状态只能由主动查询接口补偿。

## 10. 推荐实施顺序

1. SDK API 接入。
2. API 契约与枚举。
3. 数据库迁移与实体卡详情 Repository。
4. 开卡主流程改造，并回归虚拟卡。
5. 开卡能力摘要接口。
6. 邮寄地址、物流、激活、PIN 四个实体卡服务接口。
7. Admin 卡类型筛选。
8. 冻结/解冻限制。
9. Card / Physical Card webhook 同步。
10. 单元测试与联调验收。

## 11. 提交建议

未得到用户明确要求前，不自动执行 `git commit`。

如果用户明确要求提交，建议拆分：

- `feat(vcc): add physical card sdk clients and models`
- `feat(vcc): support physical card creation flow`
- `feat(vcc): add physical card shipping and activation`
- `feat(vcc): support physical card pin update`
- `feat(vcc): add admin card mode filter`
- `test(vcc): cover physical card workflows`

## 12. 2026-06-09 开发进度

已完成代码改动：

- SDK 客户端补齐 `PhysicalCardApi`、`SecurityApi`。
- 复用 `card.type` 作为卡片模式字段，未新增 `card_mode`。
- 新增实体卡状态、邮寄地址、PIN、物流、开卡能力等 API 契约。
- 新增 `card_physical_detail` 实体、Mapper、Repository 与迁移 SQL。
- 创建卡流程支持 `VIRTUAL_CARD` / `PHYSICAL_CARD`，实体卡校验总卡数、实体卡数量和 `45492418` BIN 权限。
- 会员端补齐开卡能力、提交邮寄地址、查询物流、激活实体卡、设置/修改 PIN 接口。
- Admin 卡列表支持按 `cardMode` 筛选。
- 冻结/解冻增加实体卡履约状态校验，未激活实体卡禁止冻结/解冻。
- 新增卡生命周期 webhook 同步，并接入现有 webhook 分发：`CARD.CREATED`、`CARD.UPDATED`、`CARD.DELETED`、`CARD.SETTING.UPDATED`、`PHYSICAL_CARD_ACTIVATED`。

未执行：

- 按要求未执行 Maven 编译或测试。

仍需联调确认：

- BZ 黑白塑料实体卡真实 `physicalCardDesignId`。
- PIN 位数与三方规则是否为 6 位数字。
- `CARD.SETTING.UPDATED` resource 是否能明确表达 PIN 更新。
- 制卡费、运费成本来源与最终收费口径。

## 13. 2026-06-09 费率修正

本轮补齐实体卡费率闭环：

- 客户收费口径使用 `QuantumCardMakeCardFee` + `ShoppingFee`，不使用 `_Caas` 版本。
- 新增实体卡费用预览接口：`GET /member/api/v1/card/{id}/physical/fee-preview`。
- 费用预览返回 `currency`、`productionFee`、`shippingFee`、`totalCost`。
- 提交邮寄地址时会重新计算费用，并把 `production_fee`、`shipping_fee`、`total_cost` 快照写入 `card_physical_detail`。
- 若缺少 `QuantumCardMakeCardFee` 或 `ShoppingFee` 配置，提交邮寄地址会失败，避免发货成功但费用为空。
- `AccountFeeType.CARD_FEES` 已补充 `ShoppingFee`，保持卡类费率集合完整。

仍未执行：

- 按要求未执行 Maven 编译或测试。
