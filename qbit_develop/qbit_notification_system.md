# Qbit 通知体系 (Notification System)

> 基于 `qbit_notification_center` (NestJS) 代码库分析。
> 通知中心独立部署，与 qbit-assets 风控体系联动: 风控预警 → 通知中心 → 渠道发送。
> 最后更新: 2025-06-12

---

## 1. 架构概览

### 1.1 技术栈

| 组件 | 技术 |
|------|------|
| 框架 | NestJS (TypeScript) |
| 数据库 | PostgreSQL (TypeORM) |
| 消息队列 | Redis + Bull (WebPush) / RedisMQ |
| 实时推送 | Socket.IO (WebSocket) |
| 模板引擎 | EJS |
| 部署 | pm2, 端口 3022 |

### 1.2 通知流程

```
业务系统 (qbit-assets/pay-core) → 通知 API/SDK → QbitNotification (数据库记录)
                                                    ↓
                                             渠道分发服务
                                             ├── Email (AliYun/Amazon/Resend/WeChat)
                                             ├── SMS (AliYun/UCloud/SubMail/HeySpeed)
                                             ├── WebPush (Socket.IO + Bull Queue)
                                             ├── 飞书机器人 (FeiShuRobot)
                                             ├── 企业微信机器人 (WorkWeixinRobot)
                                             └── Qbit内部通知机器人 (QbitNoticeRobot)
```

### 1.3 关键设计

- **异步 + 记录**: 所有通知写入 `qbit_notification` 表，状态追踪 (Pending/Success/Fail)
- **可配置开关**: 通过 SystemConfig 控制 `send_email` / `send_sms` 全局开关
- **环境隔离**: 非生产环境仅允许白名单手机/邮箱接收通知
- **降级策略**: 短信多通道，邮件多通道，自动切换
- **模板化**: 邮件使用 EJS 模板，支持中英文多语言

---

## 2. 核心数据模型

### 2.1 QbitNotification — qbit_notification 表

| 字段 | 类型 | 说明 |
|------|------|------|
| `notificationType` | NotificationTypeEnum | 通知渠道类型 |
| `status` | StatusEnum | Pending / Success / Fail |
| `accountId` | String | 目标账户 |
| `userId` | String | 目标用户 |
| `data` | JSON | 通知内容 |
| `phone` | String | 短信收件人 |
| `email` | String | 邮件收件人 |
| `topicName` | String | 主题名称 |
| `notificationToAccountType` | NotificationToAccountTypeEnum | 接收方式 |
| `expireDate` | Timestamptz | 到期时间 |
| `endDate` | Timestamptz | 发送结束时间 |
| `responseRaw` | JSONB | 三方接口返回原始数据 |

### 2.2 NoticeTemplateSettings — 邮件模板签名配置

| 字段 | 说明 |
|------|------|
| `signName` | 模板签名 (唯一标识) |
| `type` | NotificationTypeEnum |
| `bottomContent` | 底部内容 |
| `emailFooter` / `emailImageLink` | 邮件底部/头部 |
| `sender` | 发送人邮箱 |
| `username/password/host/port` | SMTP 配置 |
| `channel` | EmailSender (AliYun/Amazon/Resend) |
| `status` | ActivationStatusEnum |

### 2.3 其他实体

- **EmailRecord** — 无效邮箱记录，下次拦截
- **FeiShuUser** — 飞书用户关联
- **SendSmsConfig** — 手机号维度的短信通道配置

---

## 3. 通知类型 (NotificationTypeEnum)

| 类型 | 说明 | 实现路径 |
|------|------|----------|
| `WebPush` | 网页推送 (WebSocket) | `websocket-push.service.ts` + `appGateway.ts` |
| `SMS` | 手机短信 | `send-sms/send-sms.service.ts` |
| `Email` | 邮件 | `send-email/send-email.service.ts` |
| `WorkWeixinRobot` | 企业微信机器人 | `work-weixin/work-weixin.service.ts` |
| `FeiShuRobot` | 飞书机器人 | `fei-shu/fei-shu.service.ts` |
| `AmazonCallback` | 亚马逊回调通知 | (预留) |
| `QbitNoticeRobot` | Qbit 内部机器人通知 | `fei-shu/qbit-notice-robot.service.ts` |

---

## 4. 收件范围 (NotificationToAccountTypeEnum)

| 类型 | 说明 |
|------|------|
| `User` | 发送给指定用户 |
| `Account` | 发送给账户下所有用户 |
| `Broadcast` | 广播给所有在线用户 |

---

## 5. 渠道细节

### 5.1 Email 邮件

**发送者 (EmailSender):**
- `AliYun` (默认) — 阿里云邮件推送
- `Amazon` — Amazon SES (已弃用)
- `Resend` — Resend API
- `WeChat` — 企业微信邮箱 (已弃用)

**邮件模板 (EJS):**
- `balance` / `notice` / `verificationCode` — 余额/通知/验证码
- `uniteNotice` / `internalUniteNotice` — 统一/内部通知
- `niumCode` — Nium 验证码
- `customUniteNotice` — 自定义签名通知
- `newsletter` — 邮件订阅 (含退订逻辑)

**安全限制:** 非生产环境仅白名单邮箱，SystemConfig 全局开关，无效邮箱自动记录

### 5.2 SMS 短信

**第三方通道:** Ali / UCloud / SubMail / HeySpeed / YunPian

**路由逻辑:**
- `google-libphonenumber` 识别手机号
- +86 → 国内通道 (`send_sms_local_channel`)
- 国际 → 国际通道 (`send_sms_channel`)
- 多通道按 `order` 优先级自动降级

**安全限制:** 非生产环境仅白名单手机号，SystemConfig 全局开关

### 5.3 WebSocket (WebPush)

**架构:** Socket.IO + Bull 队列 (`QbitWebPush`)

**房间模型:**
- `accountId` 房间 → 推送所有关联用户
- `accountId + userId` 房间 → 推送指定用户
- `QbitGroup` → 广播所有在线用户

**API:** `joinAccountRoom` / `leaveAccountRoom` (JWT 鉴权), `notificationAccountAllUser` / `notificationAccountOneUser` / `notificationAllAccount`

### 5.4 飞书机器人

**消息类型:** text / post / interactive(卡片) / image / share_chat / file

**卡片交互:** 支持按钮回调 + 表单提交, HMAC-SHA512 签名验证

**通知模板 (QbitNoticeTemplateEnum):** `Notice`(普通) / `WorkOrder`(工单) / `ThreeTemplate`(三方)

### 5.5 企业微信机器人

**消息类型:** text / markdown / image / news(图文) / file
**支持:** `@mentioned_list` / `mentioned_mobile_list`

---

## 6. 模块结构

```
AppModule
├── ScheduleModule            — 定时任务
├── DatabaseModule            — PostgreSQL (TypeORM)
├── RedisModule               — Redis
├── SendEmailModule           — 邮件发送
├── SendSmsModule             — 短信发送
├── WebsocketPushModule       — WebSocket 推送
├── WorkWeixinModule          — 企业微信
├── FeiShuModule              — 飞书机器人
├── FeiShuApprovalModule      — 飞书审批
└── EventSubscriberModule     — TypeORM 事件订阅
```

**启动入口:** `main.ts` (端口 3022), `schedule.ts` (独立定时任务进程)

---

## 7. 与风控体系联动

### 7.1 风控预警 → 通知流程

```
Drools 规则命中 → RiskAlert 创建 → ControlWarningRule 执行
                                          ↓
                                   结果类型判断
                                   ├── 预警 → 飞书通知风控部门
                                   ├── 清退 → 账户/卡操作 + 通知
                                   └── 冻结 → 卡/账户冻结 + 通知
```

### 7.2 具体联动场景

1. **ControlWarningRule `resultTypes`**: 预警触发飞书通知 (FeiShuService), 清退/冻结操作后通过 WebSocket/Email 通知商户
2. **Admin 风控预警记录**: 余额负数/强扣交易/账户预警在前端展示，同时联动飞书通知到风控群
3. **通知中心风控键值 (RiskControlKeyEnum)**: `QuantumCardBalanceRemind`(余额不足提醒) / `GroupBalanceRemind`(预算不足提醒) / `AllowSendCardSms`(卡片短信开关)

### 7.3 系统配置开关

`SystemConfig`: `send_email` / `send_sms` 全局开关；账户级在 AccountRiskControlDeploy 中细粒度控制

---

## 8. 路径速查

| 模块 | 路径 |
|------|------|
| 通知实体 | `src/entity/notification.entity.ts` |
| 通知接口 | `src/common/interface/INotification.ts` |
| 通知 DTO | `src/modules/dto/notifications.dto.ts` |
| 邮件服务 | `src/modules/send-email/send-email.service.ts` |
| 邮件模板 | `src/modules/send-email/templates/*.ejs` |
| 短信服务 | `src/modules/send-sms/send-sms.service.ts` |
| WebSocket 网关 | `src/appGateway.ts` |
| WebSocket 推送 | `src/modules/websocket-push/websocket-push.service.ts` |
| 飞书服务 | `src/modules/fei-shu/fei-shu.service.ts` |
| 飞书 SDK | `src/modules/fei-shu/fei-shu.sdk.service.ts` |
| Qbit 通知模板 | `src/modules/fei-shu/qbit-notice-robot-template.ts` |
| 企业微信 | `src/modules/work-weixin/work-weixin.service.ts` |
| 公共枚举 | `src/common/enum/common.enum.ts` |
| MQ Topic | `src/common/enum/mq.topic.enum.ts` |
