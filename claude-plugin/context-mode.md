# context-mode 使用指南

## 简介

context-mode 是 [Mert Koseoğlu](https://github.com/mksglu/context-mode) 开发的开源 MCP 服务器，专用于优化 AI 编码助手的上下文窗口使用效率。核心思路是将数据操作隔离到沙箱中执行，只让摘要和结果进入对话，从源头减少上下文消耗（实测从 315KB 降至 5.4KB，减少 98%）。同时提供会话连续性支持，在上下文压缩后恢复工作状态。

- **语言：** TypeScript（Node.js >=22.5，也支持 Bun）
- **许可证：** Elastic-2.0
- **核心机制：** 沙箱执行 + 钩子拦截 + SQLite 会话日志
- **平台：** 支持 17+ 客户端（Claude Code、Gemini CLI、Cursor、VS Code Copilot、Codex CLI 等）

---

## 安装

### 通过 npm 全局安装

```bash
npm install -g context-mode
```

或通过 pnpm：

```bash
pnpm add -g context-mode
```

### 自动设置

```bash
context-mode setup
```

该命令会自动检测已安装的编码代理并配置 MCP 条目、钩子和插件。

### 手动配置（Claude Code）

添加到 `~/.claude/.mcp.json` 或项目 `.mcp.json`：

```json
{
  "mcpServers": {
    "context-mode": {
      "command": "npx",
      "args": ["-y", "context-mode"]
    }
  }
}
```

### 验证安装

```bash
context-mode doctor
```

---

## 在 Claude Code 中使用

### 核心工具

| 工具 | 作用 | 示例场景 |
|------|------|----------|
| `ctx_execute` | 沙箱中执行代码，仅返回 stdout | "分析这个 CSV 文件的结构" |
| `ctx_batch_execute` | 批量沙箱执行 | "同时跑多个数据检查" |
| `ctx_execute_file` | 从文件执行脚本 | "运行本地已经写好的分析脚本" |
| `ctx_index` | 索引 URL/内容到本地知识库 | "把这篇文档索引起来" |
| `ctx_search` | FTS5 搜索已索引的内容 | "我之前索引过的内容里搜 X" |
| `ctx_fetch_and_index` | 获取并索引网络内容 | "抓取这个页面并索引" |
| `ctx_stats` | 查看上下文用量统计 | "检查上下文消耗分布" |
| `ctx_doctor` | 诊断安装状态 | "检查配置是否正确" |
| `ctx_insight` | 查看知识库热度分析 | "哪些内容最常被查询" |

### 典型工作流

#### 1. 数据处理（替代在聊天中粘贴大段内容）

```
> 分析 /var/log/app/access.log 的请求分布
→ ctx_execute(code="...写一个解析脚本...")
→ 脚本输出：10000 请求，GET 占 60%，POST 占 30%...
→ 仅摘要进入对话，原始日志不进入上下文
```

#### 2. 网络内容索引

```
> 把这篇文章索引起来
→ ctx_fetch_and_index(url="https://example.com/docs/api")
→ 之后可以随时 ctx_search(query="身份验证") 搜索
```

#### 3. 会话恢复

当 Claude Code 压缩对话后，重启时 context-mode 通过 SessionStart 钩子自动注入会话指南，包含：

- 上一次的请求
- 进行中的任务
- 已做的决策
- 未处理的错误
- 阻塞项

#### 4. 批量数据检查

```
> 同时跑这三个数据验证
→ ctx_batch_execute(scripts=[...])
→ 并行执行，汇总结果返回
```

---

## 钩子系统（Hook）

context-mode 的一大特点是钩子系统，能在特定时机截获工具调用：

| 钩子 | 作用 |
|------|------|
| `PreToolUse` | 拦截危险命令（如 curl/wget），重定向到沙箱 |
| `PostToolUse` | 记录文件编辑、错误、决策到 SQLite |
| `SessionStart` | 恢复上次压缩前的状态 |
| `PreCompact` | 压缩前生成工作快照 |
| `Stop` | 会话结束时执行清理 |

在 Claude Code 中，这些钩子通过 `.claude/hooks/` 目录注册。

---

## 知识库管理

context-mode 用 SQLite FTS5 作为本地知识库，支持：

- **BM25 全文搜索**（Porter 词干提取 + 三元组子串匹配）
- **模糊纠正**（Levenshtein 编辑距离）
- **RRF（Reciprocal Rank Fusion）**多路搜索合并
- **TTL 缓存**：避免重复抓取 URL，缓存窗口内跳过重复请求

数据保存在 `~/.cache/context-mode/` 或项目本地目录。

---

## 与 codebase-memory-mcp 的对比

| 维度 | context-mode | codebase-memory-mcp |
|------|-------------|-------------------|
| **核心解决** | 代理被数据/日志/网页填满上下文，以及会话压缩后丢失状态 | 代理看不懂代码结构，大量令牌浪费在 grep/读取文件 |
| **方法** | 沙箱执行 → 仅摘要进对话 + 会话状态持久化 | 预处理代码成图谱 → 精确查询 |
| **安装** | npm 包，需要 Node.js >=22.5 | ~10MB 单静态二进制 |
| **许可证** | Elastic-2.0 | MIT |
| **互补** | 可同时使用，互不冲突 | 可同时使用，互不冲突 |

**核心建议：** 如果主要痛点是代码理解（看不懂结构、找调用链），用 codebase-memory-mcp。如果主要痛点是上下文窗口被外部数据填满或会话压缩后断片，用 context-mode。两者可以一起用，一个解决代码理解问题，一个解决上下文管理问题。

---

## 卸载

```bash
npm uninstall -g context-mode
context-mode setup  # 清理代理配置
```

手动删除 `~/.claude/.mcp.json` 中的 context-mode 条目，以及 `~/.cache/context-mode/` 目录。
