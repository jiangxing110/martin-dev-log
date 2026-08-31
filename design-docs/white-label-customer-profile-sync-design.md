# 白标客户配置同步设计

## 1. 文档信息

| 项目 | 内容 |
|---|---|
| 文档名称 | 白标客户配置同步设计 |
| 版本 | v1.0 |
| 作者 | martinJiang |
| 日期 | 2026-08-31 |
| 涉及系统 | qbit-assets、white-label-server（Infinity Launch） |
| 状态 | 待评审 |

## 2. 背景

Infinity Launch 本质上是 qbit-assets 的 API 客户，同时 white-label-server 可能由客户独立部署。qbit-assets Admin 需要展示客户的统一详情，但 qbit-assets 与 white-label-server 的数据职责不同：账户身份数据属于 qbit-assets，白标展示配置属于 white-label-server。

当前 white-label-server 已经通过内部接口主动调用 qbit-assets，例如钱包余额查询接口。由于白标客户配置数量约十条，采用 white-label-server 通过 XXL-JOB 每小时全量推送到 qbit-assets 的方式，能够满足实时性要求，并降低独立部署场景下的网络依赖。

## 3. 目标与非目标

### 3.1 目标

1. qbit-assets Admin 展示以下八个字段，且全部只读：账户 ID、主体名称、Admin 域名、C 端域名、品牌名称、登录邮箱、品牌 Logo、Favicon。
2. qbit-assets 只维护账户 ID、主体名称的权威数据。
3. white-label-server 维护六个白标字段，并每小时同步到 qbit-assets。
4. qbit-assets 保存白标配置快照，Admin 不依赖实时访问 white-label-server。
5. 支持 white-label-server 客户独立部署，调用方向为客户系统出站访问 qbit-assets。
6. 同步接口具备鉴权、幂等、失败保留旧数据和可观测能力。

### 3.2 非目标

1. 不迁移白标配置主数据到 qbit-assets。
2. 不允许 qbit-assets Admin 修改白标字段。
3. 第一阶段不引入消息队列、复杂增量同步和配置变更事件。
4. 不通过数据库直连访问 white-label-server。
5. 不在同步接口中传输 clientSecret、accessToken 等 API 敏感凭证。

## 4. 数据归属

| 字段 | 主数据系统 | qbit-assets 存储方式 | 是否允许 qbit Admin 修改 |
|---|---|---|---|
| 账户 ID | qbit-assets | account 表 | 否 |
| 主体名称 | qbit-assets | account.verifiedName | 否 |
| Admin 域名 | white-label-server | 白标快照表 | 否 |
| C 端域名 | white-label-server | 白标快照表 | 否 |
| 品牌名称 | white-label-server | 白标快照表 | 否 |
| 登录邮箱 | white-label-server | 白标快照表 | 否 |
| 品牌 Logo | white-label-server | 白标快照表 | 否 |
| Favicon | white-label-server | 白标快照表 | 否 |

white-label-server 当前使用的 `tenantId`、`outAccountId`、qbit `accountId` 必须明确映射。同步请求中的 `accountId` 必须是 qbit-assets 能直接识别的真实账户 ID，不能默认将 tenantId 或 displayId 当作 accountId。

## 5. 总体架构

```text
white-label-server
        |
        | XXL-JOB 每小时全量同步
        | HTTPS + 内部签名
        v
qbit-assets 内部批量同步接口
        |
        | 校验账户、幂等 upsert、事务更新
        v
account_white_label_profile（只读投影）
        |
        v
qbit-assets Admin 客户详情接口
```

同步方向由 white-label-server 发起。这样客户独立部署时只需要允许访问 qbit-assets，不需要 qbit-assets 反向访问客户网络或开放客户服务的入站接口。

## 6. white-label-server 设计

### 6.1 XXL-JOB 任务

新增白标客户配置同步任务，例如：

```text
WhiteLabelCustomerProfileSyncJob
```

执行策略：

- 周期：每小时一次；
- 初期：查询全部约十条配置并一次批量提交；
- 单次任务使用固定批次号或执行时间作为 trace 标识；
- 记录总数、成功数、失败数、耗时和响应摘要；
- qbit-assets 请求失败时抛出任务异常，由 XXL-JOB 重试；
- 不因为一次同步失败而清理本地白标配置。

### 6.2 数据组装

配置来源：

- `tenant_customer_config`：Admin 域名、C 端域名；
- `tenant_profile`：品牌名称、品牌 Logo、Favicon；
- 租户管理员用户或租户配置：登录邮箱；
- qbit 账户映射：qbit-assets 账户 ID。

建议由 Service 统一组装同步 DTO，不让 XXL-JOB 直接访问 Mapper 或拼接业务字段。

### 6.3 请求示例

```json
{
  "requestId": "wl-sync-20260831120000",
  "profiles": [
    {
      "accountId": "844768",
      "adminDomain": "admin.example.com",
      "appDomain": "app.example.com",
      "brandName": "Infinity Launch",
      "loginEmail": "admin@example.com",
      "brandLogo": "https://cdn.example.com/logo.png",
      "favicon": "https://cdn.example.com/favicon.ico"
    }
  ]
}
```

`requestId` 用于日志关联和请求幂等；同一批数据重复提交不得产生重复记录。

## 7. qbit-assets 接口设计

### 7.1 接口

```text
POST /qbit-assets/account/white-label-customer-profile/sync
```

该接口属于系统间内部接口，鉴权方式沿用现有 white-label-server 调用 qbit-assets 的内部请求方式，例如 `HeaderUtils.buildNodeHeaders(accountId, secret)` 对应的签名协议。由于请求中包含多个账户，签名主体不应依赖当前用户上下文，而应使用配置的系统级 clientId/secret 或 mTLS。

建议新接口使用 `white-label` 正确拼写；现有 `white-lable-wallet-balances` 接口保持兼容，不在本需求中改名。

### 7.2 请求对象

```java
public class WhiteLabelCustomerProfileSyncRequest {
    private String requestId;
    private List<WhiteLabelCustomerProfileItem> profiles;
}

public class WhiteLabelCustomerProfileItem {
    private String accountId;
    private String adminDomain;
    private String appDomain;
    private String brandName;
    private String loginEmail;
    private String brandLogo;
    private String favicon;
}
```

校验要求：

- `requestId` 非空且长度受限；
- `profiles` 非空，单批数量限制为 100；
- `accountId` 非空，并校验 qbit-assets 账户是否存在；
- 域名、邮箱和 URL 按格式校验；
- 同一请求内不允许出现重复 accountId；
- 不接受 clientSecret、accessToken 等敏感字段。

### 7.3 返回对象

```json
{
  "requestId": "wl-sync-20260831120000",
  "successCount": 10,
  "failedCount": 0,
  "errors": []
}
```

部分账户失败时返回各账户错误信息，但已通过校验的账户可以正常更新。若采用整体事务，则校验阶段应先完成，业务更新阶段不应出现预期内的单条失败；推荐第一版使用“先校验、后整体更新”。

## 8. qbit-assets 数据模型

### 8.1 表名

```text
account_white_label_profile
```

该表是 qbit-assets 的白标配置只读投影，不是白标主数据表。

### 8.2 字段建议

| 字段 | 类型 | 说明 |
|---|---|---|
| id | varchar/uuid | 主键，遵循项目现有基类规范 |
| account_id | varchar | qbit-assets 账户 ID |
| admin_domain | varchar(255) | Admin 域名 |
| app_domain | varchar(255) | C 端域名 |
| brand_name | varchar(255) | 品牌名称 |
| login_email | varchar(320) | 登录邮箱 |
| brand_logo | text | Logo 地址 |
| favicon | text | Favicon 地址 |
| source | varchar(64) | 来源，如 WHITE_LABEL |
| source_version | bigint/int | 来源版本，可选 |
| last_sync_time | timestamp | 最近一次成功同步时间 |
| sync_status | varchar(32) | SUCCESS/FAILED |
| last_sync_error | text | 最近一次同步错误 |
| create_time | timestamp | 创建时间 |
| update_time | timestamp | 更新时间 |
| delete_time | timestamp | 软删除时间 |
| version | bigint/int | 乐观锁版本 |

建议 `account_id + source` 建立唯一索引。新实体遵循 qbit-assets 的 `BaseV3`、软删除和 PostgreSQL 字段命名规范。

### 8.3 删除策略

第一版不根据“本次请求中没有某个客户”自动删除数据，避免某个客户独立部署异常或查询失败导致 assets 清空配置。

如果白标配置需要清空字段，应由 white-label-server 明确发送空值；如果客户彻底下线，后续增加明确的 `status` 或删除接口，不使用列表缺失推断删除。

## 9. qbit-assets 分层实现

建议新增独立模块，职责如下：

```text
InternalWhiteLabelCustomerProfileController
        -> WhiteLabelCustomerProfileService
        -> WhiteLabelCustomerProfileMapper
        -> account_white_label_profile
```

Controller 只负责参数校验和返回结果；Service 负责账户存在性校验、数据映射、幂等更新和事务；Mapper 负责批量查询与持久化。

不建议把同步逻辑继续放入现有 `InternalAccountController`，避免账户基础接口、钱包接口和白标配置接口职责混杂。

Admin 查询接口应通过 Service 查询 `account` 与白标快照，返回专用 VO。账户 ID、主体名称从 `account` 查询，六个白标字段从快照表查询。不存在快照时六个白标字段返回 null，并返回同步状态或最近同步时间供页面展示。

## 10. 幂等与一致性

### 10.1 幂等键

业务唯一键使用：

```text
account_id + source
```

重复请求执行 update，不新增重复记录。

### 10.2 版本控制

第一版可以使用 white-label-server 的 `updateTime` 或配置版本作为 `source_version`。当请求版本早于数据库已有版本时拒绝覆盖，防止网络重试造成旧配置覆盖新配置。

如果当前白标配置没有版本号，至少使用同步任务时间和 assets 接收时间，并保证同一任务内数据稳定；后续补充配置版本号。

### 10.3 事务边界

单批约十条数据，推荐在 qbit-assets Service 使用：

```java
@Transactional(rollbackFor = Exception.class)
```

先批量校验账户，再批量新增或更新快照。数据库写入失败时整批回滚，white-label XXL-JOB 下次重试。

## 11. 安全设计

1. 接口仅允许系统间调用，不暴露给普通 Admin 用户。
2. 沿用现有内部请求头协议，推荐系统级签名或 mTLS。
3. 签名内容包含 HTTP 方法、路径、时间戳、nonce、requestId 和请求体摘要。
4. 校验时间窗口，防止重放攻击。
5. 日志禁止打印 Logo 全量内容以外的敏感凭证；严禁打印 clientSecret、accessToken。
6. `accountId` 必须校验存在，不能允许调用方创建不存在的账户配置。
7. 图片地址仅作为展示 URL 保存，不由 qbit-assets 服务端主动下载，避免引入 SSRF 风险。
8. 记录调用方、requestId、traceId、账户数量、结果数量和耗时。

## 12. 失败处理与监控

### 12.1 white-label-server

- HTTP 非 2xx 或业务失败时让 XXL-JOB 任务失败；
- 记录 qbit-assets 返回的错误摘要；
- 下次任务重新全量发送；
- 发送成功后记录成功数和最后成功时间。

### 12.2 qbit-assets

- 请求格式错误：直接返回 400，不写库；
- 签名失败：返回 401/403，不写库；
- 账户不存在：返回账户级错误，不写入该账户；
- 数据库异常：事务回滚，返回失败；
- 重复请求：正常返回成功，保证幂等。

### 12.3 Admin 展示

建议在详情页展示：

```text
白标配置同步状态：成功
最近同步时间：2026-08-31 12:00:00
```

同步失败时仍展示上一次成功配置，同时提示最近同步失败，不能因为临时失败把页面字段清空。

## 13. 独立部署兼容性

客户独立部署时只需要配置 qbit-assets 的访问地址和系统鉴权信息：

```yaml
qbit:
  assets:
    sync-url: https://assets.example.com
    client-id: ${QBIT_ASSETS_CLIENT_ID}
    client-secret: ${QBIT_ASSETS_CLIENT_SECRET}
```

客户服务向 qbit-assets 发起出站 HTTPS 请求，不要求 qbit-assets 访问客户内网。若客户暂时无法访问 qbit-assets，XXL-JOB 任务失败并在网络恢复后自动补偿；客户本地配置不受影响。

## 14. 测试与验收标准

### 14.1 单元测试

1. 空 profiles 被拒绝。
2. 重复 accountId 被拒绝。
3. 不存在的 accountId 被拒绝。
4. 首次同步能够新增记录。
5. 重复同步不会新增重复记录。
6. 重复同步会更新白标字段。
7. 账户 ID 和主体名称不被同步请求覆盖。
8. 旧版本请求不会覆盖新版本配置。
9. 数据库异常时整批回滚。
10. 同步失败时旧快照仍可查询。

### 14.2 集成测试

1. white-label-server XXL-JOB 能够查询十条左右配置并调用 assets。
2. assets 能正确解析现有内部请求头。
3. qbit Admin 详情接口能返回八个字段。
4. qbit Admin 返回字段均无修改接口或修改权限。
5. Logo/Favicon URL 原样保存和返回。
6. assets 不返回 clientSecret、accessToken。

### 14.3 验收标准

- 每小时同步任务成功后，assets Admin 最迟在下一次查询时展示最新配置；
- 同步失败不会清空旧配置；
- 重复执行任务不会产生重复数据；
- white-label-server 不需要开放入站访问；
- qbit-assets Admin 的八个字段全部只读；
- qbit 账户主体信息始终来自 qbit-assets 自己的 `account` 表。

## 15. 实施顺序

1. 确认 `tenantId/outAccountId/accountId/displayId` 的真实映射关系。
2. 在 qbit-assets 增加白标快照表和实体。
3. 增加批量同步 DTO、Controller、Service、Mapper 和事务处理。
4. 增加 qbit-assets Admin 只读详情查询接口和页面展示。
5. 在 white-label-server 增加同步 DTO、客户端和 XXL-JOB 任务。
6. 联调签名、批量 upsert、异常重试和旧数据保留。
7. 增加监控日志和任务执行说明。

## 16. 结论

在当前只有约十条白标客户配置的前提下，“white-label-server 使用 XXL-JOB 每小时全量推送，qbit-assets 保存只读快照”的方案成本最低、边界清晰，也最适合客户独立部署。

白标配置的主数据始终保留在 white-label-server，qbit-assets 只保存展示投影；qbit-assets 的账户 ID 和主体名称始终以自身账户数据为准。后续如果需要更高实时性，可以在不改变数据归属的前提下增加“白标配置修改后立即推送”，并继续保留每小时 XXL-JOB 作为补偿机制。

## 17. Admin 配置更新规则补充

white-label-server Admin 可以继续编辑六个白标字段：Admin 域名、C 端域名、品牌名称、登录邮箱、品牌 Logo、Favicon。编辑成功后更新 white-label-server 自己的 `tenant_customer_config` 和 `tenant_profile`，不直接写 qbit-assets 数据库；下一次 XXL-JOB 全量同步负责将变更同步到 qbit-assets。

qbit-assets Admin 的客户详情页仍然全部只读。qbit-assets Admin 不提供白标字段修改接口，避免 qbit-assets 和 white-label-server 形成双主数据。

如果产品要求白标 Admin 保存后立即在 qbit-assets Admin 生效，可以在 white-label-server 保存成功后复用同一套同步 Service 立即调用 qbit-assets 同步接口，XXL-JOB 仍作为每小时补偿任务。立即推送失败不应阻断白标本地保存，也不应清空 qbit-assets 的旧快照。

建表 SQL 见同目录的 `account-white-label-profile.sql`。
