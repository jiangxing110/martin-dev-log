# Claude Code 使用指南

## 简介

Claude Code 是 Anthropic 的 CLI 编程助手，集成在终端中使用。本仓库通过 `deepseek-v4-flash` 模型驱动。

---

## 基本使用

### 启动

```bash
# 在项目目录下启动
claude

# 带初始 prompt 启动
claude "帮我看看这个项目的结构"
```

### 交互方式

直接输入自然语言描述任务即可，Claude Code 会自动：

1. 分析你的需求
2. 读取相关文件
3. 执行命令（git、maven 等）
4. 编辑代码
5. 展示结果

---

## 常用 Slash 命令

| 命令 | 用途 |
|------|------|
| `/help` | 查看帮助 |
| `/clear` | 清空对话 |
| `/cost` | 查看本次会话的 token 消耗 |
| `/config` | 修改配置（主题、模型等） |
| `/settings` | 打开 settings.json 编辑 |
| `/doctor` | 诊断环境问题 |
| `/loop <间隔> <指令>` | 定时重复执行某个 prompt |

### ! 前缀（Shell 命令）

在对话中直接执行终端命令：

```
!git status
!mvn compile -pl qbit-core -am
```

---

## 插件系统

### 已安装插件一览

| 插件 | 版本 | 来源 | 类型 |
|------|------|------|------|
| **superpowers** | v5.1.0 | claude-plugins-official | 技能系统（Skills） |
| **context7** | - | claude-plugins-official | MCP 工具 |
| **code-simplifier** | v1.0.0 | claude-plugins-official | Agent 代理 |
| **warp** | v2.0.0 | claude-code-warp | Hooks 集成 |
| **ecc** | v2.0.0-rc.1 | ecc（community） | 全能插件系统（60+ 代理 / 231 技能 / 75 命令） |

### 安装 / 管理插件

```bash
# 安装插件
claude plugins install <plugin-name>

# 查看所有插件的安装状态
claude plugins list

# 查看可用市场
claude plugins marketplace list

# 添加自定义市场
claude plugins marketplace add <repo-url>

# 卸载插件
claude plugins uninstall <plugin-name>
```

### 启用 / 禁用插件

通过 `~/.claude/settings.json` 中的 `enabledPlugins` 字段控制：

```json
{
  "enabledPlugins": {
    "superpowers@claude-plugins-official": true,
    "context7@claude-plugins-official": true,
    "code-simplifier@claude-plugins-official": true,
    "ecc@ecc": true
  }
}
```

---

## 各插件详细用法

### 1. superpowers（技能系统）

**类型**：Skills（技能）  
**特点**：自动触发，无需手动调用。当你提出需求时，Claude Code 会判断是否匹配某个技能并自动加载。

#### 技能速查表

| 技能 | 触发方式 | 作用 |
|------|----------|------|
| **brainstorming** | 说"帮我想想怎么实现 X" | 实现前的需求/设计探讨，澄清需求再动手 |
| **writing-plans** | 说"帮我写个计划实现 X" | 输出分步实施计划，会读相关代码再出计划 |
| **executing-plans** | 计划审批通过后自动进入 | 启动子 agent 依次执行计划中的每个任务 |
| **test-driven-development** | 说"用 TDD 方式实现 X" | 红-绿-重构循环：先写测试→写实现→重构 |
| **systematic-debugging** | 说"查个 bug" 或报错时 | 系统化排查：复现→隔离根因→修复→验证 |
| **requesting-code-review** | 说"帮我 review 代码" | 审查改动，给出结构化评审意见 |
| **receiving-code-review** | 收到 review 意见时 | 逐条理解评审意见并按建议修改 |
| **verification-before-completion** | 说"帮我验收一下" | 完成前检查：测试覆盖、边界情况、异常处理 |
| **finishing-a-development-branch** | 说"开发完了，帮我收尾" | 展示选项：合并、创建 PR、清理分支 |
| **subagent-driven-development** | 计划执行时自动使用 | 派生子 agent 并行执行独立任务 |
| **dispatching-parallel-agents** | 说"同时帮我查 A、B、C" | 并行派发多个 agent 做调研/搜索 |
| **using-git-worktrees** | 说"用 worktree 隔离开发" | 在独立 worktree 中开发，不干扰当前工作区 |
| **writing-skills** | 需要创建自定义技能时 | 指导如何编写可复用的 Skill |

#### 典型场景示例

```
你: 帮我想想怎么做量子卡的月结功能
→ 自动触发 brainstorming，先和你讨论需求和方案

你: 方案定了，写个计划
→ 自动触发 writing-plans，出实施计划

你: 开始执行
→ 自动进入 executing-plans，派发子 agent 逐个实现
```

---

### 2. context7（文档查询）

**类型**：MCP 工具  
**特点**：实时查询任意框架/库/工具的最新官方文档和代码示例，直接注入到对话上下文中。

#### 什么场景用

当你不确定某个库的 API 用法、配置项、或版本迁移时，直接问 Claude，它会自动调用 context7 查询最新文档。

#### 示例

```
你: React 18 的 useTransition 怎么用？
→ Claude 自动调 context7 查询最新官方文档

你: Spring Boot 3.0 的 @ConfigurationProperties 怎么配？
→ Claude 自动调 context7 查 Spring 官方文档

你: MyBatis-Plus 3.5 的分页怎么用？
→ Claude 自动调 context7 查 MP 文档
```

#### 特点

- 比训练数据更新，能查到最新版本的 API
- 自动解析官方文档，附带代码示例
- 内置 15 分钟缓存，重复查询更快

---

### 3. code-simplifier（代码简化）

**类型**：Agent 代理  
**特点**：审查已修改的代码，检查复用性、质量、效率问题，然后自动修复。

#### 什么场景用

当你改完一段代码，想确保它干净、简洁、没有冗余时使用。

#### 使用方法

```bash
# 方式1：直接说
简化一下我改的代码

# 方式2：用 /simplify 命令（如果已注册）
/simplify
```

#### 检查内容

- 是否有可复用的公共逻辑
- 代码是否过于复杂
- 是否有不必要的抽象
- 命名是否清晰
- 是否有重复代码

#### 示例

```
你: 简化一下我刚刚改的代码
→ Claude 触发 code-simplifier，审查 diff，提出优化建议并自动修改
```

---

### 4. warp（Warp 终端集成）

**类型**：Hooks 集成  
**特点**：提供 Warp 终端的原生集成，主要功能是桌面通知。

#### 功能

- **桌面通知**：当 Claude Code 在后台完成任务时，通过 Warp 发送原生桌面通知
- **权限请求**：Warp 中显示权限请求弹窗
- **会话管理**：自动处理 session start/stop 事件

#### 无需额外操作

这个插件是自动工作的，安装后就有通知能力。你不需要手动调用它。

#### 验证是否生效

当你在 Warp 中运行 Claude Code 并切到其他窗口时，如果 Claude 完成了任务或需要你确认，你会看到 Warp 发来的系统通知。

---

### 5. ECC（Everything Claude Code）全能插件系统

**类型**：复合型插件（Skills + Commands + Agents + Hooks + Rules）  
**版本**：v2.0.0-rc.1  
**来源**：community（140K+ stars）  
**特点**：社区最大的 Claude Code 增强套件，60+ 子代理、231 个技能、75 个命令。

#### 使用方式

ECC 的命令以命名空间形式使用，前缀为 `/ecc:`（插件安装模式）或直接使用短命令（手动安装模式）：

```bash
# 插件安装模式（当前模式）
/ecc:plan "添加用户认证"
/ecc:code-review
/ecc:security-scan

# 查看 ECC 所有可用命令
/plugin list ecc@ecc
```

#### 75 个命令分类速查

| 分类 | 命令 | 用途 |
|------|------|------|
| **规划** | `/ecc:plan`、`/ecc:plan-prd`、`/ecc:feature-dev` | 功能规划、PRD 编写、特性开发 |
| **代码审查** | `/ecc:code-review`、`/ecc:review-pr`、`/ecc:quality-gate` | 代码审查、PR 审查、质量门禁 |
| **构建修复** | `/ecc:build-fix`、`/ecc:go-build`、`/ecc:rust-build`、`/ecc:kotlin-build`、`/ecc:cpp-build`、`/ecc:gradle-build`、`/ecc:flutter-build`、`/ecc:gan-build` | 各语言/框架构建错误修复 |
| **TDD** | `/ecc:go-test`、`/ecc:rust-test`、`/ecc:kotlin-test`、`/ecc:cpp-test`、`/ecc:flutter-test` | 各语言 TDD 测试 |
| **安全** | `/ecc:security-scan` | 安全审计（集成 AgentShield） |
| **持续学习** | `/ecc:learn`、`/ecc:learn-eval`、`/ecc:instinct-status`、`/ecc:instinct-import`、`/ecc:instinct-export`、`/ecc:evolve`、`/ecc:prune`、`/ecc:promote`、`/ecc:projects` | 从会话中学习模式，形成"直觉" |
| **技能管理** | `/ecc:skill-create`、`/ecc:skill-health`、`/ecc:hookify-list`、`/ecc:hookify`、`/ecc:hookify-configure`、`/ecc:hookify-help` | 从 git 历史创建技能、技能健康检查 |
| **多 agent 编排** | `/ecc:multi-plan`、`/ecc:multi-execute`、`/ecc:multi-backend`、`/ecc:multi-frontend`、`/ecc:multi-workflow` | 多 agent 并行协作 |
| **文档** | `/ecc:update-docs`、`/ecc:update-codemaps`、`/ecc:project-init` | 文档同步、代码映射更新 |
| **代码重构** | `/ecc:refactor-clean` | 清理无效/冗余代码 |
| **会话管理** | `/ecc:sessions`、`/ecc:save-session`、`/ecc:resume-session`、`/ecc:loop-start`、`/ecc:loop-status` | 会话历史管理、恢复、循环 |
| **测试覆盖** | `/ecc:test-coverage` | 测试覆盖率分析 |
| **PR 流程** | `/ecc:pr`、`/ecc:prp-*`（prd/plan/implement/commit/pr） | PR 创建与 PRP 全流程 |
| **其他** | `/ecc:cost-report`、`/ecc:model-route`、`/ecc:pm2`、`/ecc:jira`、`/ecc:santa-loop`、`/ecc:aside`、`/ecc:auto-update`、`/ecc:setup-pm`、`/ecc:harness-audit`、`/ecc:ecc-guide` | 成本报告、模型路由、PM2 管理、Jira 集成等 |

#### 60+ 子代理（按需使用）

子代理位于 `agents/` 目录，以 Markdown 文件定义，专精于特定领域：

| 代理 | 专业领域 |
|------|----------|
| `planner.md` | 功能实现规划 |
| `architect.md` | 系统架构设计决策 |
| `tdd-guide.md` | 测试驱动开发 |
| `code-reviewer.md` | 代码质量与安全审查 |
| `security-reviewer.md` | 漏洞分析 |
| `build-error-resolver.md` | 构建错误修复 |
| `e2e-runner.md` | Playwright 端到端测试 |
| `refactor-cleaner.md` | 无效代码清理 |
| `doc-updater.md` | 文档同步更新 |
| `chief-of-staff.md` | 沟通梳理与文稿起草 |
| `loop-operator.md` | 自主循环执行 |
| `harness-optimizer.md` | 执行框架配置调优 |
| 各语言审查/构建修复 | `java-reviewer.md`、`java-build-resolver.md`、`go-reviewer.md`、`python-reviewer.md`、`cpp-reviewer.md`、`rust-reviewer.md`、`kotlin-reviewer.md`、`database-reviewer.md`、`typescript-reviewer.md` 等 |

#### 231 个技能概览

技能分为以下几大类（完整列表见 ECC 插件目录 `skills/`）：

| 大类 | 包含 |
|------|------|
| **编码规范** | coding-standards、java-coding-standards、cpp-coding-standards |
| **后端模式** | backend-patterns、springboot-*、django-*、laravel-*、quarkus-*、fastapi-patterns、nestjs-patterns、dotnet-patterns |
| **前端模式** | frontend-patterns、swiftui-patterns、compose-multiplatform、flutter-patterns |
| **数据库** | postgres-patterns、mysql-patterns、redis-patterns、prisma-patterns、jpa-patterns、database-migrations |
| **测试** | tdd-workflow、e2e-testing、verification-loop、python-testing、golang-testing、rust-testing |
| **安全** | security-review、security-scan、hipaa-compliance、defi-amm-security |
| **AI/ML** | mle-workflow、recsys-pipeline-architect、pytorch-patterns、deep-research |
| **DevOps** | deployment-patterns、docker-patterns、flox-environments、canary-watch |
| **业务运营** | customer-billing-ops、finance-billing-ops、inventory-demand-planning、logistics-exception-management |
| **内容创作** | article-writing、content-engine、market-research、investor-materials、seo、video-editing、videodb |
| **其他** | accessibility、benchmark、design-system、docs-lookup、error-handling、git-workflow、terminal-ops 等 |

#### 持续学习 v2（ECC 特色功能）

ECC 最具特色的功能之一——自动从对话中学习模式并跨会话积累：

```
/ecc:instinct-status        # 查看已学习的"直觉"及其置信度
/ecc:instinct-import <文件>  # 导入他人的直觉
/ecc:instinct-export        # 导出你的直觉以供分享
/ecc:evolve                 # 将相关直觉聚类为技能
/ecc:promote                # 将项目级直觉提升为全局
/ecc:prune                  # 删除过期的待处理直觉
/learn                      # 从当前会话提取模式
```

#### AgentShield 安全审计

ECC 自带的 AgentShield 工具可以扫描你的 Claude Code 配置安全风险：

```bash
# 快速扫描
npx ecc-agentshield scan

# 自动修复安全问题
npx ecc-agentshield scan --fix

# 深度分析（3 个 Opus agent）
npx ecc-agentshield scan --opus --stream

# 从头生成安全配置
npx ecc-agentshield init
```

扫描范围：CLAUDE.md、settings.json、MCP 配置、钩子、agent 定义、技能模块，覆盖密钥检测（14 种模式）、权限审计、钩子注入分析等。

#### 安装 Rules（已安装）

ECC 插件带不了 rules（Claude Code 插件系统限制），需要手动复制。

**当前已安装：** `common`（通用规则）+ `java` + `golang` + `python` + `typescript` + `web`

已安装的文件：

| 规则目录 | 文件名 | 内容 |
|----------|--------|------|
| `common/` | coding-style.md | 不可变性、文件组织规范 |
| | git-workflow.md | 提交格式、PR 流程 |
| | testing.md | TDD、覆盖率要求 |
| | performance.md | 模型选型、上下文管理 |
| | patterns.md | 设计模式、项目骨架 |
| | hooks.md | 钩子架构 |
| | agents.md | 子智能体委派时机 |
| | security.md | 强制安全检查 |
| | code-review.md | 代码审查流程 |
| | development-workflow.md | 开发工作流 |
| `java/` | coding-style.md | Java 编码风格 |
| | patterns.md | Java 设计模式 |
| | security.md | Java 安全规范 |
| | testing.md | Java 测试规范 |
| | hooks.md | Java 相关钩子 |
| `golang/` | coding-style.md | Go 编码风格 |
| | patterns.md | Go 设计模式 |
| | security.md | Go 安全规范 |
| | testing.md | Go 测试规范 |
| | hooks.md | Go 相关钩子 |
| `python/` | coding-style.md | Python 编码风格 |
| | patterns.md | Python 设计模式 |
| | security.md | Python 安全规范 |
| | testing.md | Python 测试规范 |
| | hooks.md | Python 相关钩子 |
| `typescript/` | coding-style.md | TS/JS 编码风格 |
| | patterns.md | TS/JS 设计模式 |
| | security.md | TS/JS 安全规范 |
| | testing.md | TS/JS 测试规范 |
| | hooks.md | TS/JS 相关钩子 |
| `web/` | coding-style.md | 前端编码风格 |
| | patterns.md | 前端设计模式 |
| | security.md | 前端安全规范 |
| | testing.md | 前端测试规范 |
| | hooks.md | 前端相关钩子 |

#### 区块链 / Web3 相关

ECC 中与区块链相关的技能非常有限，仅有：

| 技能 | 说明 |
|------|------|
| `defi-amm-security` | DeFi AMM 安全模式 |
| `evm-token-decimals` | EVM 代币精度处理 |

**没有**区块链/Rules 规则目录，也没有 Solana 相关的任何内容。如果需要这类规范，后续需要自行补充。

---

#### 与 superpowers 的关系

ECC 和 superpowers 功能有部分重叠（都有 planning、TDD、code review 等技能），不会冲突但可能同时响应同一需求。建议：
- 先用一段时间感受两者各自的工作方式
- 如果觉得某个功能重复了，可以在 `~/.claude/settings.json` 中禁用其中一个插件
- 目前 superpowers 和 ECC 同时启用，没有已知冲突

---

## 常用工作流

### 日常开发

```
1. 描述需求 → Claude Code 可能会触发 brainstorming 和你讨论
2. 确认方案 → 可能会触发 writing-plans 出计划
3. 审批计划 → 开始实现
4. 修改代码 → Claude Code 自动编辑文件
5. 测试验证 → 可要求运行测试或审查结果
6. 提交代码 → 要求执行 git commit
7. 创建 PR → 要求创建 Pull Request
```

### 调试 Bug

```
1. 描述 bug 现象
2. Claude Code 自动触发 systematic-debugging
3. 按步骤排查根因
4. 修复并验证
```

### 代码评审

```
1. 要求"帮我 review 代码"
2. Claude Code 触发 requesting-code-review
3. 生成评审意见
4. 可按意见逐条修改
```

### 查文档

```
直接在对话中提问即可，context7 自动工作
例: "Spring Boot 3.0 的虚拟线程怎么配置？"
```

---

## 注意事项

1. Claude Code **不会自动执行 git commit**，需要你明确要求
2. 涉及破坏性操作（force push、reset、删除分支）会先征求同意
3. 可以通过 `~/.claude/settings.json` 配置模型、权限等
4. 当前使用模型：`deepseek-v4-flash`（快速模式）
5. 项目级配置在项目根目录的 `.claude/settings.local.json`（如果有）
6. Superpowers 技能是自动触发的，你不需要手动写命令调用它们

---

## 配置文件速查

| 文件 | 作用 |
|------|------|
| `~/.claude/settings.json` | 全局设置（模型、插件、环境变量） |
| `~/.claude/projects/<project-hash>/settings.json` | 项目级设置 |
| `~/.claude/keybindings.json` | 快捷键绑定 |
| `项目根目录/CLAUDE.md` | 项目级指令（AI 协作规范） |

---

## 技巧

- **复杂任务先用 brainstorm**：如果不确定怎么做，说"帮我想想怎么实现 X"，会自动触发 brainstorming 流程
- **大任务拆解**：说"帮我写个计划实现 X"，会触发 writing-plans
- **并行调研**：需要查多个事情时，说"帮我同时查 A、B、C"，会触发 dispatching-parallel-agents
- **查文档直接问**：context7 不需要手动启用，问库的用法时会自动调用
- **中断恢复**：直接继续描述任务即可，上下文会自动延续
- **使用 `!` 执行命令**：可以无缝执行 shell 命令而无需退出对话
- **代码改完后可以要求简化**：说"简化一下"触发 code-simplifier 审查优化
