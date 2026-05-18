# ECC (Everything Claude Code) 使用指南

> ECC v2.0.0-rc.1 社区插件 | 140K+ stars | Anthropic 黑客松获胜项目

---

## 目录

1. [概述](#1-概述)
2. [命令大全](#2-命令大全)
3. [子代理](#3-子代理)
4. [技能体系](#4-技能体系)
5. [规则体系](#5-规则体系)
6. [持续学习 v2](#6-持续学习-v2)
7. [AgentShield 安全审计](#7-agentshield-安全审计)
8. [常用工作流](#8-常用工作流)
9. [注意事项](#9-注意事项)

---

## 1. 概述

ECC 是一个 Claude Code 增强插件，提供：

| 组件         | 数量       | 说明                                                     |
| ------------ | ---------- | -------------------------------------------------------- |
| **Commands** | 75 个      | 斜杠命令，直接调用                                       |
| **Agents**   | 60 个      | 子代理，可委派执行特定任务                               |
| **Skills**   | 231 个     | 工作流和领域知识定义                                     |
| **Rules**    | 6 套       | 编码规范约束（common/java/golang/python/typescript/web） |
| **Hooks**    | 354 行配置 | 自动化钩子                                               |

### 命名空间

插件安装模式下，命令使用 `/ecc:` 命名空间：

```bash
/ecc:plan "xxx"
/ecc:code-review
```

---

## 2. 命令大全

所有 75 个命令按功能分类：

### 2.1 规划类

| 命令                | 用途             | 用法示例                      |
| ------------------- | ---------------- | ----------------------------- |
| `/ecc:plan`         | 功能实现规划     | `/ecc:plan "添加用户认证"`    |
| `/ecc:plan-prd`     | 编写 PRD 文档    | `/ecc:plan-prd "量子卡月结"`  |
| `/ecc:feature-dev`  | 完整特性开发流程 | `/ecc:feature-dev "导出功能"` |
| `/ecc:project-init` | 项目初始化脚手架 | `/ecc:project-init`           |

### 2.2 代码审查类

| 命令                 | 用途           | 用法示例             |
| -------------------- | -------------- | -------------------- |
| `/ecc:code-review`   | 审查当前改动   | `/ecc:code-review`   |
| `/ecc:review-pr`     | 审查 PR 的改动 | `/ecc:review-pr`     |
| `/ecc:quality-gate`  | 质量门禁检查   | `/ecc:quality-gate`  |
| `/ecc:test-coverage` | 测试覆盖率分析 | `/ecc:test-coverage` |

**各语言审查命令：**

| 命令                  | 用途             |
| --------------------- | ---------------- |
| `/ecc:go-review`      | Go 代码审查      |
| `/ecc:python-review`  | Python 代码审查  |
| `/ecc:java-review`    | Java 代码审查    |
| `/ecc:cpp-review`     | C++ 代码审查     |
| `/ecc:rust-review`    | Rust 代码审查    |
| `/ecc:kotlin-review`  | Kotlin 代码审查  |
| `/ecc:flutter-review` | Flutter 代码审查 |
| `/ecc:django-review`  | Django 代码审查  |
| `/ecc:fastapi-review` | FastAPI 代码审查 |

### 2.3 构建修复类

| 命令                 | 用途                   |
| -------------------- | ---------------------- |
| `/ecc:build-fix`     | 通用构建错误修复       |
| `/ecc:go-build`      | Go 构建修复            |
| `/ecc:rust-build`    | Rust 构建修复          |
| `/ecc:kotlin-build`  | Kotlin/Gradle 构建修复 |
| `/ecc:cpp-build`     | C++ 构建修复           |
| `/ecc:gradle-build`  | Gradle 构建修复        |
| `/ecc:flutter-build` | Flutter 构建修复       |
| `/ecc:django-build`  | Django 构建修复        |
| `/ecc:dart-build`    | Dart 构建修复          |
| `/ecc:gan-build`     | GAN 模型构建修复       |

### 2.4 TDD / 测试类

| 命令                | 用途               |
| ------------------- | ------------------ |
| `/ecc:go-test`      | Go TDD 工作流      |
| `/ecc:rust-test`    | Rust TDD 工作流    |
| `/ecc:kotlin-test`  | Kotlin TDD 工作流  |
| `/ecc:cpp-test`     | C++ TDD 工作流     |
| `/ecc:flutter-test` | Flutter TDD 工作流 |

### 2.5 安全类

| 命令                 | 用途                             |
| -------------------- | -------------------------------- |
| `/ecc:security-scan` | 安全审计扫描（集成 AgentShield） |

### 2.6 持续学习类

| 命令                          | 用途                         |
| ----------------------------- | ---------------------------- |
| `/ecc:learn`                  | 从当前会话提取模式           |
| `/ecc:learn-eval`             | 提取并评估模式，保存为知识   |
| `/ecc:instinct-status`        | 查看已学习的"直觉"及其置信度 |
| `/ecc:instinct-import <文件>` | 导入他人的直觉               |
| `/ecc:instinct-export`        | 导出直觉以供分享             |
| `/ecc:evolve`                 | 将相关直觉聚类为技能         |
| `/ecc:promote`                | 将项目级直觉提升为全局       |
| `/ecc:prune`                  | 删除过期待处理直觉           |
| `/ecc:projects`               | 查看已识别项目与直觉统计     |

### 2.7 技能管理类

| 命令                     | 用途                |
| ------------------------ | ------------------- |
| `/ecc:skill-create`      | 从 git 历史生成技能 |
| `/ecc:skill-health`      | 技能健康度检查      |
| `/ecc:hookify-list`      | 列出可转换的 hook   |
| `/ecc:hookify`           | 将规则转换为 hook   |
| `/ecc:hookify-configure` | 配置 hookify        |
| `/ecc:hookify-help`      | hookify 帮助        |

### 2.8 多 Agent 编排

| 命令                  | 用途                    |
| --------------------- | ----------------------- |
| `/ecc:multi-plan`     | 多 agent 任务拆解规划   |
| `/ecc:multi-execute`  | 多 agent 工作流编排执行 |
| `/ecc:multi-backend`  | 后端多服务并行开发      |
| `/ecc:multi-frontend` | 前端多服务并行开发      |
| `/ecc:multi-workflow` | 通用多服务工作流        |

> **注意：** `multi-*` 命令需要额外安装 `ccg-workflow` 运行时：
>
> ```bash
> npx ccg-workflow
> ```

### 2.9 文档类

| 命令                   | 用途             |
| ---------------------- | ---------------- |
| `/ecc:update-docs`     | 同步更新文档     |
| `/ecc:update-codemaps` | 更新代码映射文件 |
| `/ecc:ecc-guide`       | ECC 自带指南     |

### 2.10 PR 流程类

| 命令                 | 用途               |
| -------------------- | ------------------ |
| `/ecc:pr`            | 创建 Pull Request  |
| `/ecc:prp-prd`       | PRP 流程：编写 PRD |
| `/ecc:prp-plan`      | PRP 流程：编写计划 |
| `/ecc:prp-implement` | PRP 流程：实现     |
| `/ecc:prp-commit`    | PRP 流程：提交     |
| `/ecc:prp-pr`        | PRP 流程：创建 PR  |

### 2.11 代码重构类

| 命令                  | 用途                  |
| --------------------- | --------------------- |
| `/ecc:refactor-clean` | 清理无效/冗余代码     |
| `/ecc:checkpoint`     | 保存验证状态          |
| `/ecc:aside`          | 临时记笔记/保存上下文 |

### 2.12 会话管理类

| 命令                  | 用途         |
| --------------------- | ------------ |
| `/ecc:sessions`       | 会话历史管理 |
| `/ecc:save-session`   | 保存当前会话 |
| `/ecc:resume-session` | 恢复历史会话 |
| `/ecc:loop-start`     | 启动自主循环 |
| `/ecc:loop-status`    | 查看循环状态 |

### 2.13 工具类

| 命令                 | 用途                   |
| -------------------- | ---------------------- |
| `/ecc:cost-report`   | Token 消耗报告         |
| `/ecc:model-route`   | 模型路由选择           |
| `/ecc:pm2`           | PM2 服务生命周期管理   |
| `/ecc:jira`          | Jira 集成              |
| `/ecc:setup-pm`      | 配置包管理器           |
| `/ecc:harness-audit` | 执行框架审计           |
| `/ecc:auto-update`   | 自动更新 ECC           |
| `/ecc:santa-loop`    | 圣诞模式循环（节日用） |

---

## 3. 子代理

60 个子代理以 Markdown 文件定义，可在对话中委派任务。每个 agent 有专精领域和推荐模型。

### 3.1 通用代理

| Agent 文件                 | 专精领域            | 推荐模型 |
| -------------------------- | ------------------- | -------- |
| `planner.md`               | 功能实现规划        | opus     |
| `architect.md`             | 系统架构设计决策    | opus     |
| `code-architect.md`        | 代码架构设计        | opus     |
| `code-explorer.md`         | 代码库探索分析      | opus     |
| `tdd-guide.md`             | 测试驱动开发        | opus     |
| `code-reviewer.md`         | 代码质量与安全审查  | opus     |
| `code-simplifier.md`       | 代码简化            | sonnet   |
| `security-reviewer.md`     | 漏洞分析            | opus     |
| `build-error-resolver.md`  | 构建错误修复        | opus     |
| `e2e-runner.md`            | Playwright E2E 测试 | sonnet   |
| `refactor-cleaner.md`      | 无效代码清理        | sonnet   |
| `doc-updater.md`           | 文档同步更新        | sonnet   |
| `docs-lookup.md`           | 文档/API 查阅       | sonnet   |
| `chief-of-staff.md`        | 沟通梳理与文稿起草  | opus     |
| `loop-operator.md`         | 自主循环执行        | opus     |
| `harness-optimizer.md`     | 执行框架配置调优    | opus     |
| `conversation-analyzer.md` | 对话分析            | opus     |
| `comment-analyzer.md`      | 评论分析            | opus     |
| `a11y-architect.md`        | 可访问性架构        | opus     |

### 3.2 各语言审查代理

| Agent 文件                  | 用途                       |
| --------------------------- | -------------------------- |
| `java-reviewer.md`          | Java/Spring Boot 代码审查  |
| `java-build-resolver.md`    | Java/Maven/Gradle 构建修复 |
| `go-reviewer.md`            | Go 代码审查                |
| `go-build-resolver.md`      | Go 构建修复                |
| `python-reviewer.md`        | Python 代码审查            |
| `django-reviewer.md`        | Django 代码审查            |
| `django-build-resolver.md`  | Django 构建修复            |
| `fastapi-reviewer.md`       | FastAPI 代码审查           |
| `cpp-reviewer.md`           | C++ 代码审查               |
| `cpp-build-resolver.md`     | C++ 构建修复               |
| `rust-reviewer.md`          | Rust 代码审查              |
| `rust-build-resolver.md`    | Rust 构建修复              |
| `kotlin-reviewer.md`        | Kotlin/Android/KMP 审查    |
| `kotlin-build-resolver.md`  | Kotlin/Gradle 构建修复     |
| `typescript-reviewer.md`    | TypeScript/JS 审查         |
| `csharp-reviewer.md`        | C# 代码审查                |
| `flutter-reviewer.md`       | Flutter/Dart 审查          |
| `dart-build-resolver.md`    | Dart 构建修复              |
| `fsharp-reviewer.md`        | F# 代码审查                |
| `database-reviewer.md`      | 数据库/Supabase 审查       |
| `harmonyos-app-resolver.md` | HarmonyOS 应用             |

### 3.3 GAN/ML 代理

| Agent 文件         | 用途           |
| ------------------ | -------------- |
| `gan-planner.md`   | GAN 实验规划   |
| `gan-generator.md` | GAN 生成器实现 |
| `gan-evaluator.md` | GAN 评估       |

---

## 4. 技能体系

231 个技能覆盖以下领域：

### 4.1 语言/框架专项

| 技能组           | 包含技能                                                                                                |
| ---------------- | ------------------------------------------------------------------------------------------------------- |
| **SprinBoot**    | springboot-patterns、springboot-security、springboot-tdd、springboot-verification                       |
| **Django**       | django-patterns、django-security、django-tdd、django-verification、django-celery                        |
| **Laravel**      | laravel-patterns、laravel-security、laravel-tdd、laravel-verification、laravel-plugin-discovery         |
| **Quarkus**      | quarkus-patterns、quarkus-security、quarkus-tdd、quarkus-verification                                   |
| **FastAPI**      | fastapi-patterns                                                                                        |
| **NestJS**       | nestjs-patterns                                                                                         |
| **Go**           | golang-patterns、golang-testing                                                                         |
| **Python**       | python-patterns、python-testing、pytorch-patterns                                                       |
| **Rust**         | rust-patterns、rust-testing                                                                             |
| **Kotlin**       | kotlin-patterns、kotlin-testing、kotlin-coroutines-flows、kotlin-exposed-patterns、kotlin-ktor-patterns |
| **Swift**        | swiftui-patterns、swift-actor-persistence、swift-concurrency-6-2、swift-protocol-di-testing             |
| **Flutter/Dart** | dart-flutter-patterns、compose-multiplatform-patterns                                                   |
| **Perl**         | perl-patterns、perl-security、perl-testing                                                              |

### 4.2 通用技术

| 技能组       | 包含技能                                                                                              |
| ------------ | ----------------------------------------------------------------------------------------------------- |
| **编码规范** | coding-standards、java-coding-standards、cpp-coding-standards                                         |
| **后端模式** | backend-patterns、hexagonal-architecture、api-design、error-handling                                  |
| **前端/UI**  | frontend-patterns、frontend-design-direction、design-system、motion-\*、liquid-glass-design           |
| **数据库**   | postgres-patterns、mysql-patterns、redis-patterns、prisma-patterns、jpa-patterns、database-migrations |
| **测试**     | tdd-workflow、e2e-testing、verification-loop、eval-harness                                            |
| **DevOps**   | deployment-patterns、docker-patterns、flox-environments、canary-watch、production-audit               |
| **安全**     | security-review、safety-guard、gateguard、hipaa-compliance、security-bounty-hunter                    |
| **AI/ML**    | mle-workflow、recsys-pipeline-architect、deep-research、scientific-\*                                 |
| **区块链**   | defi-amm-security、evm-token-decimals                                                                 |

### 4.3 业务/运营

| 技能组     | 包含技能                                                                               |
| ---------- | -------------------------------------------------------------------------------------- |
| **财务**   | finance-billing-ops、customer-billing-ops、cost-tracking、cost-aware-llm-pipeline      |
| **供应链** | inventory-demand-planning、logistics-exception-management、returns-reverse-logistics   |
| **内容**   | article-writing、content-engine、seo、brand-voice、investor-materials、market-research |
| **媒体**   | video-editing、videodb、manim-video、remotion-video-creation、fal-ai-media             |
| **医疗**   | healthcare-\*、hipaa-compliance                                                        |
| **网络**   | cisco-ios-patterns、homelab-_、network-_                                               |

---

## 5. 规则体系

已安装的 6 套规则位于 `~/.claude/rules/`：

### 5.1 通用规则（common/）

| 文件                      | 核心内容                                            |
| ------------------------- | --------------------------------------------------- |
| `coding-style.md`         | 不可变性优先、文件组织规范、命名约定                |
| `git-workflow.md`         | 提交格式（conventional commits）、分支策略、PR 流程 |
| `testing.md`              | TDD 优先、80%+ 覆盖率、测试金字塔                   |
| `performance.md`          | 模型选型策略、上下文窗口管理                        |
| `patterns.md`             | 设计模式使用规范、项目骨架                          |
| `hooks.md`                | 钩子架构与使用时机                                  |
| `agents.md`               | 何时委派子代理、如何编写 agent 定义                 |
| `security.md`             | 强制安全检查清单                                    |
| `code-review.md`          | 代码审查流程与标准                                  |
| `development-workflow.md` | 端到端开发流程                                      |

### 5.2 各语言规则

每个语言目录（`java/`、`golang/`、`python/`、`typescript/`、`web/`）包含：

| 文件              | 内容             |
| ----------------- | ---------------- |
| `coding-style.md` | 语言特定编码风格 |
| `testing.md`      | 语言特定测试规范 |
| `security.md`     | 语言特定安全规范 |
| `patterns.md`     | 语言特定设计模式 |
| `hooks.md`        | 语言相关钩子配置 |

---

## 6. 持续学习 v2

ECC 最具特色的功能，自动从对话中学习模式并跨会话积累"直觉"（instincts）。

### 6.1 工作流程

```
日常使用 Claude Code
       ↓
自动记录行为模式（代码风格、决策偏好等）
       ↓
用 instinct-status 查看已积累的直觉
       ↓
用 evolve 将相关直觉聚类为可复用技能
       ↓
用 promote 将项目级直觉提升为全局生效
```

### 6.2 命令详解

```bash
# 查看已学习的直觉及其置信度
/ecc:instinct-status

# 查看已识别项目及其直觉统计
/ecc:projects

# 从当前会话中提取新的模式
/ecc:learn

# 提取并评估模式质量
/ecc:learn-eval

# 将高置信度的直觉聚类为正式技能
/ecc:evolve

# 将项目级直觉提升为全局级别
/ecc:promote

# 导入/导出直觉（团队共享）
/ecc:instinct-import <文件>
/ecc:instinct-export

# 删除过期的待处理直觉
/ecc:prune
```

### 6.3 适用场景

- **长期项目**：Claude Code 越用越贴合你的编码风格
- **团队协作**：导出直觉给团队成员，保持风格统一
- **新项目初始化**：从类似项目中导入直觉，快速建立规范

---

## 7. AgentShield 安全审计

AgentShield 是 ECC 自带的安全审计工具（黑客松获奖项目），扫描 Claude Code 配置中的安全风险。

### 7.1 使用方式

```bash
# 快速扫描（无需安装）
npx ecc-agentshield scan

# 自动修复安全问��
npx ecc-agentshield scan --fix

# 3 个 Opus 4.6 agent 深度分析
npx ecc-agentshield scan --opus --stream

# 从头生成安全配置
npx ecc-agentshield init

# 在 Claude Code 中
/ecc:security-scan
```

### 7.2 扫描范围

| 类别               | 检查项                                      |
| ------------------ | ------------------------------------------- |
| **密钥检测**       | 14 种模式（API Key、Token、Private Key 等） |
| **权限审计**       | settings.json 权限配置风险                  |
| **钩子注入**       | hooks 中的命令注入风险                      |
| **MCP 风险评估**   | MCP 服务配置安全                            |
| **Agent 配置审查** | agent 定义中的安全漏洞                      |

### 7.3 输出格式

- 终端：彩色等级 A-F
- CI：JSON（退出码 2 表示严重问题，可用于门禁）
- 报告：Markdown、HTML

---

## 8. 常用工作流

### 8.1 特性开发

```bash
# 1. 需求规划
/ecc:plan "xx功能"

# 2. 编写 PRD
/ecc:plan-prd "xx功能"

# 3. 开发实现
/ecc:feature-dev "xx功能"

# 4. 代码审查
/ecc:code-review

# 5. 安全扫描
/ecc:security-scan

# 6. 质量门禁
/ecc:quality-gate

# 7. 创建 PR
/ecc:pr
```

### 8.2 修复构建错误

```bash
# 通用
/ecc:build-fix

# Java 专用
/ecc:gradle-build
```

### 8.3 多 Agent 协作

```bash
# 后端 + 前端并行开发
/ecc:multi-plan "用户中心"
/ecc:multi-backend "用户API"
/ecc:multi-frontend "用户页面"
/ecc:multi-execute
```

### 8.4 学习与优化

```bash
# 让 Claude 从当前会话学习
/ecc:learn

# 查看学到了什么
/ecc:instinct-status

# 聚类成技能
/ecc:evolve
```

### 8.5 安全审计

```bash
# 命令行扫描
npx ecc-agentshield scan

# Claude Code 内扫描
/ecc:security-scan
```

---

## 9. 注意事项

### 9.1 命名空间

插件安装模式下所有命令使用 `/ecc:` 前缀。手动安装模式可以用短命令（如 `/plan` 而非 `/ecc:plan`）。

### 9.2 multi-\* 命令

`/ecc:multi-plan`、`/ecc:multi-execute` 等需要额外安装 `ccg-workflow`：

```bash
npx ccg-workflow
```

### 9.3 与 superpowers 的关系

ECC 和 superpowers 功能部分重叠（planning、TDD、code review）。两者可共存：

- 同一需求可能两个系统都响应
- 如果觉得冗余，可在 `~/.claude/settings.json` 中禁用其中一个

### 9.4 MCP 工具数量

不要一次启用太多 MCP 工具，200k 上下文窗口会显著缩小：

- 建议启用不超过 10 个 MCP
- 活动工具保持在 80 个以下

### 9.5 区块链相关

ECC 中区块链相关技能有限：

- `defi-amm-security` — DeFi AMM 安全
- `evm-token-decimals` — EVM 代币精度

**没有** Solana、Bitcoin 等链的专项规则或技能，如有需要后续自行补充。
