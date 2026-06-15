# Qbit 风控体系 (Risk Control System)

> 基于 qbit-assets 代码库分析，涵盖规则引擎、账户风控、合规审查、预警管理四大板块。
> 最后更新: 2025-06-12

---

## 1. 架构概览

Qbit 风控体系分为四个层次：

```
合规审查层 (Compliance)        → KYC/KYB/KYB Detail, CDD, EDD, Blockchain KYA
账户风控层 (AccountRisk)       → AccountRiskControlDeploy (80+ 风控键值)
规则引擎层 (Drools Engine)     → DroolsRule + RuleGroup + Rule + RuleResult + DRL
预警处置层 (Risk Alert)        → RiskAlert + ControlWarningRule + 通知白名单
```

执行流程: `交易触发 → 数据准备 → Drools 规则匹配 → 风险判定 → 预警/阻断/人工审核`

---

## 2. Drools 规则引擎

### 2.1 核心实体

#### DroolsRule (drools_rule_collect) — 规则大合集
- `id` (UUID), `name`, `businessType` (DroolsBusinessTypeEnum)
- `ruleGroupIds` — 关联的规则组 ID 列表
- `resultIds` — 关联的结果 ID 列表
- `droolsRule` — 规则判断 Drools DRL 语句
- `droolsResult` — 规则结果判断 Drools DRL 语句
- `status` — 启用/停用

#### Rule (drools_rule) — 单条规则
- `id` (UUID), `name`, `businessType`, `dictionaryId`
- `fieldNameZh` / `fieldNameEn` — 中英文规则字段名
- `value` — 规则值

#### RuleGroup (drools_rule_group) — 规则组
- `id` (UUID), `name`, `ruleIds` — 包含的规则 ID 列表
- `concatType` — 规则间连接方式 (AND/OR)
- `index` — 序号

#### RuleResult (drools_rule_result) — 规则结果
- `id` (UUID), `name`, `businessType`
- `value` — 结果值 (是/否)
- `dictionaryId` — 规则结果字典 ID

#### DroolsRuleLogs (drools_rule_log) — 规则执行日志
- `customId` — 业务 ID, `customType` — 业务类型
- `businessType` — DroolsBusinessTypeEnum
- `droolsRuleId` — 规则集 ID, `droolsRuleName` — 规则集名称
- `condition` — 规则判断条件 (AND/OR)
- `result` — 规则集判断结果 (风险评级结果以 Map<得分,权重> 存储)
- `ruleGroupId` — 单条规则组 ID
- `ruleGroupResult` — 单条规则结果 (Boolean, 是否命中)
- `ruleGroupRealTimeValue` — 业务时点值 (如 `{"payerRisk": "中风险"}`)
- `resultIds` / `businessResultIds` — 配置匹配结果 ID / 业务最终结果 ID

### 2.2 DRL 规则文件

规则文件位于 `qbit-core/src/main/resources/rules/`，共 8 个：

| 文件 | 说明 |
|------|------|
| `CommonRiskAction.drl` | 通用风控规则 (申请处理通用部分) |
| `MerchantRiskAction.drl` | 商户量子卡上限规则 (VCCLT002~010) |
| `ApiClinetRiskAction.drl` | API 客户端风控规则 |
| `MultiAccountRiskAction.drl` | 多账户风控规则 |
| `CryptoOutbound.drl` | 链上提币风控规则 (OCW001~006) |
| `CurrencyOutbound.drl` | 法币出金风控规则 |
| `QbitRiskRatingAction.drl` | Qbit 风险评级规则 |
| `QbitInternationalRiskRatingAction.drl` | QbitInternational 风险评级规则 |

例如 CryptoOutbound.drl 中的典型规则：
```drl
rule "OCW001"
when
    $t:DroolsRuleExecuteDto()
    // 客户单日成功交易 >= 3 且累计金额 >= 30 USDC/USDT
    DroolsRuleExecuteDto(map["transferCountMap"] >= 3 && map["singleDaySumMap"] >= 30)
then
end

rule "OCW004"
when
    $t:DroolsRuleExecuteDto()
    // 客户单笔交易/上一笔交易 >= 9倍，且上笔交易 > 300 USDC/USDT
    DroolsRuleExecuteDto(map["multiple"] >= 9 && map["singleTradeBeforeOneMap"] > 300)
then
end
```

### 2.3 核心服务

#### DroolsRuleService
- `execute(DroolsRuleExecuteDto)` — 执行规则 (V1, 有 SocketException)
- `executeV2(DroolsRuleExecuteDto)` — 执行规则 (V2)
- `executeRiskRating(DroolsRuleExecuteDto)` — 执行风险评级规则
- `qbitCardRisk(QbitCardRiskDTO)` — 执行量子卡上限规则
- `updateRecode(DroolsRulesDto)` — 新增/编辑规则
- `remove(id, userId)` — 删除规则
- `isAble(id, userId)` — 启用/停用规则
- `rulesPage(DroolsRuleSearchDto)` — 规则分页
- `getInfo(id)` — 规则详情
- `writeDroolsRule/writeDroolsResult/writeRiskRatingResult` — 写 DRL 文件

#### ReloadDroolsRulesService (CommandLineRunnerImpl)
- 项目启动时自动加载所有 DRL 规则
- 支持运行时动态重载规则 (通过 Redis 通知或接口触发)

#### DroolsRuleRiskService
- `relation(Collection<IDroolsRiskRating>)` — 关联风险评级数据，为业务数据注入风险评级结果

#### RiskRatingService
- `saveRiskRatingRule(RiskRatingRuleDto)` — 保存风险评级规则
- `riskRatingInfo()` — 查询风险评级规则详情
- `riskRatingPage(OrderRiskRatingDto)` — 订单评级分页查询

#### KieSessionUtils
- `getAllRules()` — 创建包含所有规则的有状态 KieSession
- `newKieSession(classPath)` — 快速新建有状态 KieSession
- `newStatelessKieSession(classPath)` — 快速新建无状态 KieSession
- `getKieSessionFromXLS(realPath)` — 从 XLS 文件生成 KieSession
- `createKieSessionFromDRL(drl)` — 从 DRL 字符串创建 KieSession

### 2.4 动作接口与实现

**RiskAction\<T\>** — 风控处理组件接口
- `execute(DroolsRuleExecuteDto)` -> T

**实现类:**
- **CryptoOutboundRiskAction** — 链上提币风控，异步并行查询单日笔数、单日累计金额、单笔交易金额、上一笔交易、近7日最大单笔/单日，计算 6 个维度数据供 DRL 匹配
- **CurrencyOutboundRiskAction** — 法币出金风控
- **QbitCardRiskAction** — 量子卡风控

**RiskRatingAction\<T\>** — 风险评级处理逻辑接口
- `execute(DroolsRuleExecuteDto)` -> T

**实现类:**
- **QbitRiskRatingAction** — Qbit 风险评级
- **QbitInternationalRiskRatingAction** — QbitInternational 风险评级

### 2.5 规则执行流程

```
1. Controller 调用 execute / qbitCardRisk
2. DroolsRuleService 加载对应 DroolsRule 实体 (含 droolsRule + droolsResult DRL 语句)
3. 使用 KieSessionUtils 创建 KieSession
4. 将 DroolsRuleExecuteDto (含 accountId, customId, 业务数据 map) insert 到 Session
5. 执行 fireAllRules() — DRL 规则匹配
6. 根据 droolsResult 判断最终结果
7. 记录 DroolsRuleLogs (含命中情况、业务时点值、评级结果)
8. 返回执行结果
```

### 2.6 风控结果枚举 (DroolsRiskResultEnum)

| 值 | 含义 |
|----|------|
| `person_check` | 人工审核 — 需风控人员介入 |
| `warning_alter` | 风控预警 — 通知风控部门 |
| `auto_passed` | 自动通过 — 无风险 |

---

## 3. 账户风控配置 (AccountRiskControlDeploy)

### 3.1 数据模型 — accountRiskControlDeploy 表

| 字段 | 类型 | 说明 |
|------|------|------|
| `accountId` | String | 账户 ID (分片键) |
| `key` | RiskControlKeyEnum | 风控键 |
| `actionType` | RiskControlActionTypeEnum | 动作类型 |
| `value` | String | 配置值 |
| `deployValueType` | ParamsTypeEnum | 值类型 |
| `condition` | ConditionEnum | 条件 |
| `businessType` | ProductEnum | 适用业务线 |
| `status` | String | 状态 (Active/Inactive) |
| `currency` | String | 币种 |
| `reexamine` | JSONB | 复核配置 |

### 3.2 风控键枚举 (RiskControlKeyEnum) ~80 个

**量子卡相关:**
- `QUANTUM_CARD_MAX_AMOUNT` — 单卡额度上限
- `QUANTUM_CARD_MIN_AMOUNT` — 单卡额度下限
- `QUANTUM_CARD_MAX_APPLY_LIMIT_WEEK` — 每周最大申卡数
- `QUANTUM_CARD_MAX_APPLY_LIMIT_MONTH` — 每月最大申卡数
- `QUANTUM_CARD_AMOUNT_WEEK_LIMIT` — 每周额度烧录上限
- `QUANTUM_CARD_AMOUNT_MONTH_LIMIT` — 每月额度烧录上限
- `QUANTUM_CARD_PHYSICAL_CARD_COUNT` — 实体卡数量限制
- `QUANTUM_CARD_RISK_WARNING` — 量子卡风险预警

**全球账户相关:**
- `GLOBAL_ACCOUNT_BALANCE_WARNING` — 余额预警
- `GLOBAL_ACCOUNT_MAX_OUT_AMOUNT` — 最大出金金额
- `GLOBAL_ACCOUNT_DAILY_DEBIT_LIMIT` — 每日扣款限额
- `GLOBAL_ACCOUNT_WEEKLY_DEBIT_LIMIT` — 每周扣款限额
- `GLOBAL_ACCOUNT_MONTHLY_DEBIT_LIMIT` — 每月扣款限额
- `GLOBAL_ACCOUNT_TEMPORARY_LIMIT` — 临时额度限制
- `GLOBAL_ACCOUNT_SWEEP_LIMIT` — 资金归集限额

**加密资产相关:**
- `CRYPTO_ASSETS_WITHDRAWAL_AMOUNT_LIMIT` — 提币金额限制
- `CRYPTO_ASSETS_WITHDRAWAL_COUNT_LIMIT` — 提币次数限制
- `CRYPTO_ASSETS_COLD_WALLET_WITHDRAWAL` — 冷钱包提币限制
- `CRYPTO_ASSETS_HOT_WALLET_UPPER_LIMIT` — 热钱包上限

**黑白灰名单 (~15 个):**
- `BLOCK_CHAIN_BLACK_LIST` / `BLOCK_CHAIN_WHITE_LIST`
- `SCENARIO_BLACK_LIST`
- `MCC_BLACK_LIST` / `MCC_WHITE_LIST`
- `CURRENCY_BLACK_LIST` / `CURRENCY_WHITE_LIST`
- `ATM_COUNTRY_WHITE_LIST`
- `IP_COUNTRY_BLACK_LIST`

**其他风控键:**
- `WITHDRAW_LIMIT` / `WITHDRAW_LIMIT_DAY` — 提现/日限
- `TOP_AMOUNT_CHARGE_BACK` — 最大拒付金额
- `TOP_AMOUNT_RDR` — 最大 RDR 金额
- `MAX_STOP_PAYMENT_TIME` — 最大止付时间
- `CARD_STATUS_TOP_LIMIT` — 卡状态上限
- `IS_OPEN_ATM` / `IS_OPEN_APPLE_PAY` / `IS_OPEN_GOOGLE_PAY` — 功能开关
- `DISTINGUISH_CUSTOMERS_KEYS` 分组 — 区分客户类型
- `REEXAMINE` — 复核相关配置

### 3.3 辅助枚举

**RiskControlActionTypeEnum:** `Notice` / `Authorize` / `Merchant` / `Api` / `Others`

**ConditionEnum:** `<` / `<=` / `>` / `>=` / `=`

**ParamsTypeEnum:** `String` / `Number` / `Object` / `Array` / `Date` / `Boolean`

**WHITE_LIST_KEYS 分组:** BLOCK_CHAIN_WHITE_LIST, MCC_WHITE_LIST, CURRENCY_WHITE_LIST, ATM_COUNTRY_WHITE_LIST

### 3.4 AccountRiskControlDeployService

| 方法 | 说明 |
|------|------|
| `safetyInfo(accountId)` | 查询账户风控安全信息 |
| `insertRecode(dto)` | 新增风控配置记录 |
| `search(dto)` | 分页查询风控配置 |
| `verify(id, status)` | 审核风控配置 |
| `reexamine(id)` | 复核风控配置 |
| `getByKeyWithAllStatus(key)` | 根据 key 查询所有状态记录 |
| `getAccountRiskControlDeployInfo(accountId)` | 查询账户风控配置信息 |
| `getAccountRiskControlDeployInfoByMaster(masterAccountId)` | 根据主账户查询风控配置 |
| `initAccountRisk(accountId)` | 初始化账户风控 |
| `quantumCardControlWhitelit(accountId)` | 量子卡管控白名单 |

---

## 4. 风控预警系统

### 4.1 RiskAlert (drools_risk_alert)

| 字段 | 说明 |
|------|------|
| `recordId` | 业务 ID |
| `recordType` | 业务类型 |
| `accountId` | 账户 ID |
| `status` | 预警状态 |
| `handleType` | 处理类型 |
| `droolsRuleIds` | 触发规则 ID 列表 |
| `businessResultIds` | 业务结果 ID |
| `comment` | 备注 |

### 4.2 ControlWarningRule (control_warning_rule)

| 字段 | 说明 |
|------|------|
| `ruleType` | 管控/预警 (`control_rule` / `warning_rule`) |
| `ruleName` | 规则名称 |
| `ruleAccountTypes` | 适用对象 (企业/个人/父级账户/子账户) |
| `listTypes` | 名单类型 (BlackList/WhiteList/GrayList/NormalList) |
| `runTimeType` | 运行周期 (day/month/custom) |
| `rawData` | 规则数据 (JSON) |
| `dataRange` | 统计天数 |
| `ruleKind` | 规则种类 (RuleKindEnum) |
| `resultTypes` | 结果操作: 预警/清退/冻结 |

RuleKindEnum: `Normal`(普通) / `Account`(账户级, 清退=单业务暂停) / `Card`(卡级, 清退=删卡)

### 4.3 管理端预警接口

`AdminRiskNoticeController` — `/api/admin/risk/notice/`
- `POST /balance/page` — 余额负数预警记录分页
- `POST /force-post/page` — 强扣交易预警记录分页
- `POST /account/page` — 账户预警记录分页
- `POST /white-list/add` / `remove` / `page` — 预警白名单管理

---

## 5. 管理端事中风控

`AdminRiskRuleController` — `/api/admin/risk/`
- `POST /rule/collection/page` — 规则集列表分页 (含判断次数 + 规则条数统计)

辅助枚举: `ControlTypeEnum`, `NoticeTypeEnum`, `RiskRuleEnum`, `DecisionFormatEnum`, `ControlMetricEnum`, `RiskRatingEntityTypeEnum`

---

## 6. 合规审查 (Compliance)

### 6.1 模块结构

```
common_all/compliance/
├── cdd/        — CDD 客户尽职调查
├── edd/        — EDD 强化尽职调查
├── risk/       — CddRiskRating 风险评级
└── engine/     — ComplianceEngine 合规引擎

merchant/blockchain/compliance/
└── BlockchainComplianceEngineFactory — KYA 区块链合规
```

### 6.2 CDD 实体

- `CddKyc` — KYC 主表
- `CddKycIndividualDetail` / `CddKycBusinessDetail` — 个人/企业 KYC 详情
- `CddKyb` / `CddKybDetail` — KYB 详情
- `CddBusinessPerson` — 企业相关人员
- `CddIdentityAuthentication` — 身份认证
- `CddKyCase` — KYC 案件
- `CddKyRecord` — 审核记录
- `CddBlack` — 黑名单
- `FaceAuth` — 人脸认证

### 6.3 EDD

- `EddCase` — 被调查人/案件状态/风险类型
- 支持创建、审核(含拒绝)、分页查询

### 6.4 区块链合规

- `BlockchainComplianceEngineFactory` — 适配器模式工厂
- 当前渠道: `BLOCKSEC` (区块安全)
- KYA (Know Your Address): 对区块链地址做合规检查
- 输入: `ChainType` + `address` + `token` + 可选 `options`

---

## 7. 转账白名单

`common_all/risk/whitelist/`:
- `TransferWhiteList` — 账户维度的转账白名单
- `TransferWhiteListRecord` — 白名单操作日志
- `TransferWhiteListService` — 校验 + CRUD

---

## 8. 风控流程总结

### 交易风控流程

```
发起交易 → 风控前置检查 → Drools 规则匹配 → 风险评级 → 处置决策
   ├── AccountRiskControlDeploy 配置检查 (额度/次数/黑白名单)
   ├── RiskAction 异步数据准备 (CryptoOutbound 6 维度并行查询)
   ├── DroolsRuleService.execute() → KieSession.fireAllRules()
   ├── 结果匹配: person_check / warning_alert / auto_passed
   └── DroolsRuleLogs 记录 + RiskAlert 创建
```

### 账户风控初始化

```
创建账户 → initAccountRisk(accountId)
   ├── 量子卡限额配置
   ├── 全球账户限额配置
   ├── 加密资产限额配置
   └── 黑白名单初始化
```

### 规则管理流程

```
Admin 创建/编辑 → updateRecode()
   ├── 保存 DroolsRule
   ├── writeDroolsRule() / writeDroolsResult() 写 .drl 文件
   └── ReloadDroolsRulesService 重载 KieSession
```

---

## 9. 路径速查

| 模块 | 路径 |
|------|------|
| Drools 实体 | `qbit-core/.../drools/domain/entity/` |
| Drools Service | `qbit-core/.../drools/service/` |
| Drools Action | `qbit-core/.../drools/action/` |
| Drools Controller | `qbit-core/.../drools/controller/` |
| DRL 规则文件 | `qbit-core/src/main/resources/rules/` |
| 账户风控配置 | `qbit-core/.../entity/account/AccountRiskControlDeploy.java` |
| 账户风控服务 | `qbit-core/.../service/account/AccountRiskControlDeployService.java` |
| 风控枚举 | `qbit-core/.../enums/AccountRiskControlDeployEnums.java` |
| Admin 事中风控 | `qbit-core/.../admin/risk/controller/AdminRiskRuleController.java` |
| Admin 风控预警 | `qbit-core/.../admin/risk/controller/AdminRiskNoticeController.java` |
| CDD 实体 | `qbit-core/.../common_all/compliance/cdd/entity/` |
| EDD 实体 | `qbit-core/.../common_all/compliance/edd/entity/` |
| 风险评级 | `qbit-core/.../common_all/compliance/risk/` |
| 转账白名单 | `qbit-core/.../common_all/risk/whitelist/` |
| 区块链合规 | `qbit-core/.../merchant/blockchain/compliance/` |
