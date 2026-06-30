# 验证码发送接口轰炸攻击整改需求文档

## 1. 背景

2026-06-30 经安全检测发现，生产环境验证码发送接口存在被短信/邮箱验证码轰炸攻击的风险。

攻击接口：

- `POST https://assets-prod.qbitnetwork.com/api/notification/send/verify/code`

攻击现象：

- 15 分钟内异常调用 82 次。
- 其中成功发送 17 次。
- 1 分钟内成功发送 17 次，不符合现有验证码频次限制预期。

攻击特征：

- 恶意 IP：`165.154.199.66`
- 攻击者测试指纹：
  - `rapidtest58901234567890`
  - `test12345678901234567890`
- 攻击者尝试通过更换指纹、轮转 IP、复用请求体绕过频控与滑块校验。

## 2. 现状分析

当前接口链路：

- Controller：`com.qbit.merchant.QbitNotificationController#sendVerifCode`
- Service：`com.qbit.common_all.notification.notification.service.impl.QbitNotificationServiceImpl#sendSmsEmailNotification`
- 入参 DTO：`com.qbit.common_all.notification.notification.domain.dto.VerCodeDTO`
- 验证码类型枚举：`com.qbit.common.enums.notification.SmsCodeEnum`

当前主要防护策略：

1. 滑块验证码后端二次校验。
2. 指纹 `Fingerprint` 高频/低频限制。
3. IP 高频/低频限制。
4. 手机号/邮箱 高频/低频限制。
5. 命中阈值后封禁 IP、指纹、手机号、用户 token。

当前风险点：

1. 公开发送接口允许部分 `codeType` 在未登录状态下调用。
2. 滑块校验只覆盖 `SmsCodeEnum.NO_AUTHS_STRENGTHEN` 中的场景。
3. `codeType` 的生产实际绑定值尚未确认，不能仅凭攻击样例推断具体枚举。
4. 对 `captcha` 对象及其关键字段缺少前置完整性校验，异常请求可能进入后续逻辑或返回不准确的 500 错误。
5. 风控依赖指纹和 IP 时，攻击者可通过轮转 IP、修改指纹降低频控效果。

## 3. 整改目标

### 3.1 安全目标

1. 所有公开未登录验证码发送场景，只要存在资源消耗风险，必须先通过滑块后端二次校验。
2. 不符合滑块验证码入参格式的请求必须直接拒绝，不允许进入频次计数、验证码生成、短信/邮箱发送流程。
3. 缺失 `captcha` 或缺失滑块关键字段时，返回明确的 400 参数错误。
4. 滑块解密失败、token 失效、坐标不匹配、重复校验等场景，统一视为滑块校验失败。
5. 保留现有手机号/邮箱、IP、指纹、token 频控与封禁逻辑，作为滑块校验之后的第二道防线。

### 3.2 兼容目标

1. 不修改接口路径。
2. 不修改成功响应结构。
3. 不影响已登录验证码发送接口 `/api/notification/send/verify/codes`。
4. 不影响内部接口 `/api/notification/internal/send/verify/code`。
5. 正常前端已带滑块参数的公开发送流程应保持可用。

## 4. 需求范围

### 4.1 本次范围

1. 加固 `POST /api/notification/send/verify/code` 的公开验证码发送逻辑。
2. 补齐公开发送验证码场景的滑块强校验范围。
3. 增加滑块参数完整性校验。
4. 将缺失或非法滑块参数的错误语义调整为 400。
5. 增加安全回归用例，覆盖攻击 body 缺失 `captcha` 的场景。

### 4.2 非本次范围

1. 不调整 WAF、SLB、长亭等网关封禁规则。
2. 不重构验证码发送接口整体架构。
3. 不新增第三方滑块服务。
4. 不调整短信供应商或邮件供应商。
5. 不修改验证码校验接口 `/api/notification/check/verify/code`。

## 5. 业务规则

### 5.1 公开发送验证码场景

未登录接口 `/api/notification/send/verify/code` 仅允许 `SmsCodeEnum.NO_AUTHS` 中定义的验证码类型。

### 5.2 强制滑块校验场景

对所有公开发送验证码场景必须执行滑块校验，直到生产日志确认哪些 `codeType` 需要豁免或单独处理。

### 5.3 滑块参数完整性

需要滑块校验的场景，请求体必须包含 `captcha`，且至少包含以下字段：

- `captcha.token`
- `captcha.pointJson`
- `captcha.secretKey`

任一字段缺失、为空、空白字符串时，接口必须拒绝。

### 5.4 执行顺序

公开发送验证码的推荐执行顺序：

1. 规范化手机号/邮箱。
2. 从请求头提取 IP、Fingerprint、Authorization。
3. 判断是否免发送。
4. 判断公开接口是否允许当前 `codeType`。
5. 若命中公开发送场景，先校验滑块参数完整性，再执行滑块后端二次验证。
6. 执行手机号/邮箱、指纹、IP、token 频控。
7. 生成验证码。
8. 发送短信或邮件。
9. 写入 Redis 验证码缓存并设置 TTL。

## 6. 异常与响应

### 6.1 缺失滑块参数

触发条件：

- `captcha == null`
- `captcha.token` 为空
- `captcha.pointJson` 为空
- `captcha.secretKey` 为空

期望结果：

- HTTP 状态：`400 Bad Request`
- 业务异常码：复用 `ExceptionConstant.COMMON_EXCEPTION_400`
- 参数：`captcha`
- 不发送短信或邮件。
- 不生成验证码。
- 不写入验证码缓存。

### 6.2 滑块验证失败

触发条件：

- 滑块 token 无效。
- 坐标解密失败。
- 坐标校验不通过。
- 重放已使用滑块凭据。
- 滑块服务返回失败。

期望结果：

- HTTP 状态：`400 Bad Request`
- 错误信息使用滑块服务返回文案或统一参数错误文案。
- 不发送短信或邮件。

### 6.3 频控命中

保持现有行为：

- 命中手机号/邮箱、指纹、IP、token 高频或低频阈值时，返回验证码限流错误。
- 按现有策略封禁相关维度。

## 7. 验收标准

1. 使用攻击 body，不携带 `captcha` 调用 `/api/notification/send/verify/code`，接口返回 400。
2. 使用攻击 body，不携带 `captcha` 调用时，不触发短信发送。
3. 使用攻击 body，不携带 `captcha` 调用时，不写入验证码 Redis 缓存。
4. 公开发送流程必须要求滑块，直到生产日志确认例外场景。
5. 已登录接口 `/api/notification/send/verify/codes` 不受本次滑块强制逻辑影响。
6. 内部接口 `/api/notification/internal/send/verify/code` 不受本次滑块强制逻辑影响。
7. 正常携带合法滑块参数的前端流程可继续发送验证码。

## 8. 风险与注意事项

1. 前端如果某些公开场景未传 `captcha`，上线后会收到 400，需要提前确认前端调用链。
2. 生产日志中必须确认真实 `codeType`，不能沿用攻击报文里的未验证字段值做结论。
3. 频控仍不能完全抵御分布式 IP 池攻击，滑块一次性验证是本次核心防线。
4. WAF 封禁已完成，但应用层仍必须修复，不能依赖单一 IP 封禁。

