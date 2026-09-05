# 合伙人首页统计接口对接文档

## 1. 接口说明

合伙人首页拆分为两个接口：顶部佣金卡片和推荐客户 KYC 状态使用汇总接口，佣金趋势使用独立接口。

| 项目 | 内容 |
|---|---|
| 请求方式 | `POST` |
| 请求路径 | `/v1/home/summary` |
| Partner 本地地址 | `http://127.0.0.1:8080` |
| 完整地址 | `http://127.0.0.1:8080/v1/home/summary` |
| 请求体 | 无请求参数，可发送空 JSON `{}` |
| 登录态 | 必须携带当前合伙人登录态，接口从 `UserContext.accountId` 获取合伙人 ID |

接口不接收 `partnerAccountId`，防止前端传入其他合伙人账户 ID。

趋势接口：

```http
POST /v1/home/commission-trend
```

合伙人身份从登录态获取，请求体可为空。

请求体示例：

```json
{
  "startTime": "2026-02-01",
  "endTime": "2026-07-31",
  "commissionMode": "ALL"
}
```

## 2. 请求示例

```bash
curl --request POST 'http://127.0.0.1:8080/v1/home/summary' \
  --header 'Authorization: Bearer <partner-token>' \
  --header 'Content-Type: application/json' \
  --data '{}'
```

## 3. 响应示例

以下为业务数据示例，实际响应外层会按照项目统一 `Result` 格式返回：

```json
{
  "code": 200,
  "success": true,
  "data": {
    "estimatedCommissionTotal": 13460.56,
    "grossProfitCommission": 3240.10,
    "baseMarkupCommission": 8120.60,
    "elasticMarkupCommission": 980.20,
    "withdrawSettlementAmount": 1119.66,
    "customerKycStatistics": {
      "total": 38,
      "opened": 24,
      "applying": 8,
      "rejected": 6
    }
  }
}
```

趋势接口响应示例：

```json
{
  "code": 200,
  "success": true,
  "data": {
    "commissionTrend": [
      {"date":"2026-02","commissionMode":"GROSS_PROFIT","value":1200.00},
      {"date":"2026-02","commissionMode":"BASE_MARKUP","value":2300.00},
      {"date":"2026-02","commissionMode":"ELASTIC_MARKUP","value":180.00},
      {"date":"2026-03","commissionMode":"GROSS_PROFIT","value":1480.00}
    ]
  }
}
```

## 4. 字段说明

### 4.1 顶部佣金卡片

| 字段 | 类型 | 说明 |
|---|---|---|
| `estimatedCommissionTotal` | `number` | 本月预计佣金总额，毛利、底价加价、弹性加价之和 |
| `grossProfitCommission` | `number` | 本月毛利返佣预估；负毛利最终按 0 处理 |
| `baseMarkupCommission` | `number` | 本月底价加价预估，目前 Assets 暂返回 `0` |
| `elasticMarkupCommission` | `number` | 本月弹性加价预估，目前 Assets 暂返回 `0` |
| `withdrawSettlementAmount` | `number` | Partner 已落库且状态不是 `SETTLED`、`CANCELED` 的佣金合计 |

金额统一按 USD 处理，前端建议保留两位小数。空金额由服务端转换为 `0`。

### 4.2 推荐客户 KYC 统计

| 字段 | 类型 | 说明 |
|---|---|---|
| `total` | `integer` | 推荐客户总数 |
| `opened` | `integer` | 已开通客户数 |
| `applying` | `integer` | 申请中客户数 |
| `rejected` | `integer` | 已拒绝客户数 |

饼图总数使用 `total`，三种状态分别使用 `opened`、`applying`、`rejected`。

### 4.3 佣金趋势

该数据仅由 `/v1/home/commission-trend` 返回。

| 字段 | 类型 | 说明 |
|---|---|---|
| `date` | `string` | 结算月份，格式 `YYYY-MM` |
| `commissionMode` | `string` | `GROSS_PROFIT`、`BASE_MARKUP` 或 `ELASTIC_MARKUP` |
| `value` | `number` | 对应返佣模式的当月金额 |

默认返回最近 12 个月，每个月最多返回三条数据；前端按 `date` 和 `commissionMode` 绘制三条趋势线。

## 5. 数据来源与计算口径

### 5.1 本月预估

Partner 调用 Assets：

```http
POST /v1/feign/partner/commissions/monthly-commission/estimate
```

请求参数由 Partner 自动构造：

```json
{
  "partnerAccountId": "当前登录合伙人账户 ID",
  "startTime": "当前月第一天",
  "endTime": "当前月最后一天"
}
```

毛利返佣由 Assets 根据客户业务线毛利和合伙人阶梯配置计算；毛利小于或等于 0 时不产生负佣金。底价加价和弹性加价当前按约定返回 0。

### 5.2 推荐客户 KYC

Partner 调用 Assets：

```http
POST /v1/feign/partner/commissions/customer-kyc/statistics
```

该统计按当前登录合伙人的推荐客户去重后统计。若 Assets 端尚未接入 KYC 查询，响应会是 0 值结构，前端无需特殊处理。

### 5.3 待结算金额

Partner 查询自己的 `partner_monthly_commission`，排除以下状态：

```text
SETTLED
CANCELED
```

其余状态的 `total_commission_amount` 累加为 `withdrawSettlementAmount`。

### 5.4 佣金趋势

趋势接口直接查询 Partner 的 `partner_monthly_commission`，不重新调用 Assets。数据按月度佣金账单返回，并包含三种佣金模式金额。

## 6. 本地联调

Partner 本地配置使用：

```yaml
spring:
  cloud:
    openfeign:
      client:
        config:
          interlace-assets-api:
            url: http://127.0.0.1:8010
          partnerCommissionClient:
            url: http://127.0.0.1:8010
```

启动顺序：

1. 启动本地 Assets，确认端口为 `8010`。
2. 启动本地 Partner，确认端口为 `8080`。
3. 使用 Partner 登录 Token 调用 `/v1/home/summary`。

如果日志出现以下内容，说明没有走本地直连配置：

```text
URL not provided
No servers available for service: interlace-assets-api
```

如果使用测试类直连，需要确保测试类启用：

```java
@ActiveProfiles("local")
```

并重新编译 Partner，避免 IDEA 使用旧的 `target/classes`。

## 7. 异常处理

| 场景 | 结果 |
|---|---|
| 未登录或无法取得合伙人账户 ID | 返回统一无权限错误 |
| Assets 预估接口返回空 | 三种预估金额按 `0` 返回 |
| Assets KYC 接口返回空 | KYC 各项按 `0` 返回 |
| Partner 没有月度佣金记录 | `withdrawSettlementAmount` 为 `0`，趋势为空数组 |
| 本地 Assets 未启动 | Feign 连接失败，检查 Assets 是否监听 `8010` |

## 8. 当前限制

- 趋势接口支持 `startTime`、`endTime` 和 `commissionMode` 筛选；未传日期时默认最近 12 个月，未传模式时默认 `ALL`。
- 底价加价、弹性加价预估暂时为 0；已落库的历史数据仍按 Partner 月度账单展示。
- KYC 统计的最终状态映射依赖 Assets 端账户/KYC 数据实现。
