# 验证码发送接口轰炸攻击整改技术方案

## 1. 方案结论

推荐采用“服务层强制滑块校验 + 参数完整性前置校验 + 回归测试”的最小安全修复方案。

核心原则：

- 不改接口路径。
- 不改正常成功响应。
- 不影响已登录和内部发送接口。
- 在短信/邮件资源消耗前拒绝非法请求。
- 保留现有 IP、指纹、手机号、token 频控作为第二道防线。

## 2. 可选方案对比

### 2.1 方案 A：仅 WAF/网关封禁

做法：

- 在阿里 WAF、长亭 WAF、SLB 封禁恶意 IP。
- 针对攻击特征配置规则。

优点：

- 响应快。
- 对应用代码无侵入。

缺点：

- 只能处理已知 IP 或明显攻击特征。
- 攻击者轮转 IP、调整指纹后仍可能绕过。
- 应用层漏洞仍存在。

结论：

- 可作为临时止血措施，不能作为最终修复。

### 2.2 方案 B：Controller 层强制校验 captcha 字段

做法：

- 在 `QbitNotificationController#sendVerifCode` 中校验 `captcha` 是否存在。

优点：

- 入口直观。
- 改动少。

缺点：

- Controller 不适合承载复杂业务场景判断。
- 不利于复用服务层逻辑。
- 容易遗漏其他入口调用 `sendSmsEmailNotification` 的场景。

结论：

- 不推荐作为主方案。

### 2.3 方案 C：Service 层按公开发送场景强制滑块校验

做法：

- 在 `QbitNotificationServiceImpl#sendSmsEmailNotification` 中判断公开验证码发送场景。
- 对公开发送场景先校验 `captcha` 完整性。
- 完整性通过后再执行滑块服务二次验证。
- 滑块通过后再执行频控和发送。

优点：

- 贴合现有业务分层。
- 可覆盖 Controller、内部服务调用等统一发送链路。
- 不依赖攻击样例里的未验证字段值。
- 能保证非法请求不会进入发送资源消耗流程。

缺点：

- 需要确认公开发送场景是否都已接入滑块，避免误伤前端。

结论：

- 推荐采用。

## 3. 目标改动点

### 3.1 不再依赖攻击样例的 `codeType` 数值

说明：

- 当前不能确认攻击请求里的 `codeType` 是否为生产真实枚举值。
- `SmsCodeEnum` 的序列化值为字符串，不应把 `3` 当作既成事实写入结论。
- 先以生产日志确认真实 `codeType`，再决定是否对某个场景单独豁免或单独收紧。

### 3.2 增加滑块参数完整性校验

文件：

- `qbit-core/src/main/java/com/qbit/common_all/notification/notification/service/impl/QbitNotificationServiceImpl.java`

建议新增私有方法：

```java
private boolean shouldVerifyCaptcha(Boolean isAuth) {
    return !Boolean.TRUE.equals(isAuth);
}
```

```java
private void validateCaptcha(CaptchaVO captcha) {
    if (captcha == null
            || StringUtils.isBlank(captcha.getToken())
            || StringUtils.isBlank(captcha.getPointJson())
            || StringUtils.isBlank(captcha.getSecretKey())) {
        throw CustomerFactory.businessCode(ExceptionConstant.COMMON_EXCEPTION_400, HttpStatus.BAD_REQUEST, "captcha");
    }
}
```

### 3.3 封装滑块后端二次验证

建议将现有滑块验证代码封装为独立方法：

```java
private void verifyCaptcha(VerCodeDTO param) {
    CaptchaVO captcha = param.getCaptcha();
    validateCaptcha(captcha);
    ResponseModel model;
    try {
        String pointJson = AbstractCaptchaService.decrypt(captcha.getPointJson(), captcha.getSecretKey());
        String value = AESUtil.aesEncrypt(captcha.getToken().concat("---").concat(pointJson), captcha.getSecretKey());
        captcha.setCaptchaVerification(value);
        model = captchaService.verification(captcha);
    } catch (Exception e) {
        log.error("滑块验证码校验异常，fingerprint：{}，ip：{}", param.getFingerprint(), param.getIpAddress(), e);
        throw CustomerFactory.businessCode(ExceptionConstant.COMMON_EXCEPTION_400, HttpStatus.BAD_REQUEST, "captcha");
    }
    if (!model.isSuccess()) {
        throw new CustomException(model.getRepMsg(), HttpStatus.BAD_REQUEST);
    }
}
```

说明：

- 缺失参数和解密异常统一按 400 处理。
- 日志需包含 `fingerprint`、`ip`，便于安全审计。
- 不记录手机号完整值、不记录验证码、不记录滑块明文坐标。

### 3.4 调整发送流程顺序

建议在 `checkSendCountLimit(param)` 前执行滑块校验：

```java
if (shouldVerifyCaptcha(isAuth)) {
    verifyCaptcha(param);
}
this.checkSendCountLimit(param);
```

原因：

- 滑块失败请求不应进入频控计数。
- 滑块失败请求不应产生验证码。
- 滑块失败请求不应消耗短信/邮件资源。

## 4. 兼容性设计

### 4.1 未登录公开接口

接口：

- `/api/notification/send/verify/code`

影响：

- 公开发送流程必须携带合法滑块，直到生产日志确认哪些场景可以豁免。

### 4.2 已登录接口

接口：

- `/api/notification/send/verify/codes`

影响：

- 调用 `sendSmsEmailNotification(..., Boolean.TRUE)`。
- `shouldVerifyCaptcha` 返回 `false`。
- 不强制新增滑块。

### 4.3 内部接口

接口：

- `/api/notification/internal/send/verify/code`

影响：

- 调用 `sendSmsEmailNotification(..., Boolean.TRUE)`。
- 不强制新增滑块。

## 5. 测试方案

### 5.1 单元测试

新增测试类：

- `qbit-core/src/test/java/com/qbit/core/service/impl/notification/QbitNotificationServiceImplCaptchaTest.java`

建议覆盖用例：

1. 公开发送且 `captcha == null`，返回 `COMMON_EXCEPTION_400`，参数为 `captcha`。
2. 公开发送且 `captcha.token` 为空，返回 400。
3. 公开发送且 `captcha.pointJson` 为空，返回 400。
4. 公开发送且 `captcha.secretKey` 为空，返回 400。
5. 缺失滑块参数时，不调用 Redis 频控自增。
6. 缺失滑块参数时，不调用短信/邮件发送服务。
7. 已登录发送同一 `codeType` 不强制滑块。

### 5.2 集成验证

使用类似攻击 body 验证：

```json
{
  "emailPhone": "+8617639370503",
  "codeType": "3",
  "nationCode": "+86",
  "phoneCode": "+86"
}
```

预期：

- 返回 400。
- 不发送短信。
- 不写入验证码缓存。

注意：

- 需先确认生产真实 `codeType` 的实际绑定逻辑。
- 不能仅根据攻击报文里的 `codeType` 推导业务场景。

## 6. 发布前检查清单

1. 确认前端在公开发送验证码场景均传递 `captcha`。
2. 确认公开发送场景是否存在必须豁免的历史入口。
3. 确认异常码 `COMMON_EXCEPTION_400` 的中英文文案满足前端展示。
4. 确认安全日志不输出验证码、手机号完整值、滑块坐标明文。
5. 保持 WAF/SLB 对 `165.154.199.66` 的封禁作为临时防线。

## 7. 发布后观测

建议监控以下指标：

1. `/api/notification/send/verify/code` 每分钟请求量。
2. 400 参数错误中 `captcha` 错误占比。
3. 滑块验证失败量。
4. 验证码发送成功量。
5. 同一手机号/邮箱发送次数。
6. 同一 IP、同一 Fingerprint 命中频控次数。
7. 短信供应商消耗量。

## 8. 后续增强建议

1. 将公开验证码发送接口的所有资源消耗类场景统一纳入滑块校验策略配置。
2. 增加手机号/邮箱维度的“滑块通过后短时间内只允许发送一次”幂等保护。
3. 对 `captcha.token` 增加应用侧一次性消费记录，防止滑块服务异常时重复使用。
4. 增加安全审计表或结构化日志，记录被拒绝的攻击维度摘要。
5. 对验证码发送接口增加灰度开关，支持紧急开启更严格策略。
