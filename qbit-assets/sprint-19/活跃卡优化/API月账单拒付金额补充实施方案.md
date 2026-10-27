# API 月账单历史配置补充金额拒付数据 Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** 将拒付金额、无验证消费金额和金额拒付率写入 API 月账单 `bill_history_config`。

**Architecture:** 复用 ODS 风控查询结果已有的拒付金额和无验证消费金额，在风险参数 VO 与账单生成 Map 间透传，再由 `ApiBillHistoryConfig` 序列化进 JSON。覆盖 `ApiClientBillServiceImpl` 和 `QuantumCardApiCustomerServiceImpl` 两条生成路径；不改 PDF 展示或罚款规则。

**Tech Stack:** Java 17、Spring Boot 3、FastJSON、MyBatis。

**Spec:** `docs/superpowers/specs/2026-10-25-active-card-bill-and-reject-rate-design.md`

## Global Constraints

- 新增字段类型使用 `BigDecimal`。
- 新增字段、类和方法注释使用中文。
- 兼容历史 `bill_history_config` JSON 中缺少新增字段的情况。
- 不自动创建分支、commit、push、合并或 PR。
- 不改 PDF 参数或模板，不调整拒付罚款规则。

## Review Focus

- 风控统计结果金额为空时，按现有数据库查询的默认值及风险对象构造方式处理，避免新增空值导致账单生成失败。
- 历史 JSON 缺少新增字段时，反序列化保持兼容。
- 两条账单生成链路都设置三个字段，字段语义与单位一致。
- 金额拒付率沿用现有计算结果，不从四舍五入后的比率反算金额。
- 新字段不进入 PDF 参数映射。

---

### Task 1: 风控金额字段透传到账单历史配置

**Files:**
- Modify: `qbit-core/src/main/java/com/qbit/common_all/quantum/card/domain/vo/QuantumCardRiskRuleParamsVO.java`
- Modify: `qbit-core/src/main/java/com/qbit/common_all/quantum/card/service/QuantumCardService.java`
- Modify: `qbit-core/src/main/java/com/qbit/openapi/domain/entity/ApiBillHistoryConfig.java`
- Modify: `qbit-core/src/main/java/com/qbit/common_all/api/client/bill/service/impl/ApiClientBillServiceImpl.java`
- Modify: `qbit-core/src/main/java/com/qbit/common_all/api/client/bill/service/impl/QuantumCardApiCustomerServiceImpl.java`

**Interfaces:**
- Consumes: `QuantumCardRefusalRateResultBO.refusalAmount`, `noAuthConsumptionAmount`; existing `QuantumCardRiskRuleParamsVO.rejectPayRateAmount`.
- Produces: risk parameter fields `rejectPayAmount` and `conAmount`; config fields `rejectPayAmount`, `conAmount`, `rejectPayRateAmount`.

- [ ] Add documented `BigDecimal rejectPayAmount` and `BigDecimal conAmount` properties to `QuantumCardRiskRuleParamsVO`.
- [ ] Populate those properties from the existing risk result in `QuantumCardService.getAccountQuantumCardRiskRateFilterDeletedCard`.
- [ ] Add documented `BigDecimal rejectPayAmount`, `conAmount`, and `rejectPayRateAmount` properties to `ApiBillHistoryConfig`.
- [ ] In both bill generation services, put the three risk values in the monthly reject data and copy them into `ApiBillHistoryConfig` in `dealHistoryConfig`.
- [ ] Inspect the resulting diff, then run `git diff --check` and verify the new fields are only used in config serialization, not PDF rendering.
