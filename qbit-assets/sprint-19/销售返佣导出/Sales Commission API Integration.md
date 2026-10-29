# 销售佣金导出前后端对接文档

## 1. 接口说明

| 项目 | 内容 |
| --- | --- |
| 接口 | `POST /api/admin/sale/commission/export` |
| 用途 | 异步导出指定销售、指定结算月份的销售佣金明细 Excel |
| 鉴权 | 使用现有 Admin 登录态和请求鉴权 |
| 请求类型 | `application/json` |
| 响应 | 空响应体；接口不直接返回 Excel 文件或下载地址 |
| 完成通知 | 后端任务完成后向发起人发送现有 `admin_message_notice` WebSocket 通知 |

该接口只接受一个销售 ID。没有部门级、批量销售或销售 ID 列表导出参数。

## 2. 请求参数

请求体沿用 `SaleCommissionQueryDTO`：

| 字段 | 类型 | 必填 | 说明 |
| --- | --- | --- | --- |
| `saleId` | `string` | 是 | 要导出的单个销售用户 ID；数据按快照/视图中的 `sale_id` 精确匹配，不包含该销售的 AM 或其他销售数据 |
| `settlementMonth` | `string` | 是 | 结算月份，格式 `yyyy-MM`，例如 `2026-10` |

示例：

```http
POST /api/admin/sale/commission/export
Content-Type: application/json
```

```json
{
  "saleId": "269ce892-8728-4954-bb05-613163dbd142",
  "settlementMonth": "2026-10"
}
```

月份格式不正确时请求会被拒绝。非超级管理员可导出的数据从 `2026-08` 起；同时必须通过现有数据权限校验，包括本人、可管理用户或有权限的部门。请以前端现有销售选择器提供的单个销售用户 ID 为准，不要传部门 ID、AM ID 或拼接多个 ID。

## 3. 响应与异步通知

HTTP 请求仅负责校验并启动后台任务，成功时响应体为空。前端不应等待文件内容，也没有任务 ID 可用于轮询。

后台导出成功后，发起人会收到已有 WebSocket 通知：

- topic：`admin_message_notice`
- 通知类型：`WebPush`
- 成功标题：`销售佣金明细`
- 成功内容：包含“点击下载”的 HTML 链接，链接指向导出文件
- 失败标题：`销售佣金明细失败`

前端应复用现有 Admin 导出通知处理逻辑，通过通知标题判断成功/失败；成功时展示下载链接。失败通知没有可用文件地址。该接口不另外提供同步下载 URL。

## 4. Excel 结构

### 海外销售二部

当目标销售属于海外销售二部（部门 ID：`1851130772357509121`）时，导出一个 sheet：`海外销售二部`。

| 列顺序 | 表头 | 数据说明 |
| --- | --- | --- |
| 1 | 客户名称 | 客户认证名称；优先 `verifiedName`，缺失时回退 `verifiedNameEn` |
| 2 | 销售 | 销售昵称 |
| 3 | 毛利 | 毛利金额 |
| 4 | 费率 | 佣金费率 |
| 5 | 提成 | 佣金金额 |

### 其他部门

其他部门导出以下四个 sheet，顺序固定。即使某产品无数据，也保留空 sheet 和表头。

| Sheet | 产品范围 |
| --- | --- |
| `量子卡` | `qbit_card` |
| `全球账户` | `group_account` |
| `加密资产` | `crypto` |
| `API` | `open_api` 的无渠道实收数据 |

每个 sheet 的列顺序相同：

| 列顺序 | 表头 | 数据说明 |
| --- | --- | --- |
| 1 | 客户名称 | 客户认证名称；优先 `verifiedName`，缺失时回退 `verifiedNameEn` |
| 2 | 销售 | 销售昵称 |
| 3 | 渠道 | 产品渠道；无渠道时为空 |
| 4 | 有效收入 | 有效收入金额 |
| 5 | 成本 | 成本金额 |
| 6 | 毛利 | 毛利金额 |
| 7 | 激活时间 | 产品激活日期，格式 `yyyy-MM-dd`；无值时为空 |
| 8 | 激活天数 | 产品活跃天数；无值时为空 |
| 9 | 费率 | 佣金费率 |
| 10 | 提成 | 佣金金额 |

## 5. 数据口径

1. 后端优先读取指定销售、指定结算月份的佣金快照；该销售没有快照时读取现有 `mv_sales_commission_recent_estimate` 视图。
2. 导出明细只包含 `current_payout`，不会把 `future_payout` 的应收金额作为当期实收导出。
3. 普通部门的 API sheet 仅纳入同时满足以下条件的明细：产品为 `open_api`、渠道为空或空白、来源类型是 `billing_decline_fee`、`past_due_invoice`、`offline_api_income` 之一，并且属于 `current_payout`。`api_monthly_billing` 是应收来源，不会进入 API sheet。
4. 海外销售二部使用单 sheet 展示该销售的佣金明细；其 API 渠道行不会因普通部门 API sheet 的无渠道规则而从单表数据中移除。
5. 生产查询和本地预估视图查询按产品从 `dim.dim_account_analysis` 读取激活日期：量子卡 `card_active_time`、全球账户 `global_active_time`、加密资产 `crypto_active_time`、API `api_active_time`。本地快照导出查询使用 `account."createTime"`（账户创建时间）作为激活时间。

## 6. 前端对接建议

- 仅当选中一个销售且结算月份有效时启用导出按钮。
- 点击后调用接口，展示“导出处理中”之类的提示；HTTP 成功仅表示任务已启动，不表示文件已生成。
- 复用 Admin 全局通知监听，接收 `admin_message_notice` 后按通知结果展示下载链接或失败提示。
- 不要通过本接口响应体解析文件地址，也不要把部门 ID 或多个销售 ID 填入 `saleId`。
