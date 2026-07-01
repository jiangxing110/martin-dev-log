# codebase-memory-mcp 使用指南

## 简介

codebase-memory-mcp 是 [DeusData](https://github.com/DeusData/codebase-memory-mcp) 开发的高性能代码智能引擎 MCP 服务器。基于 tree-sitter AST 分析和 Hybrid LSP 语义解析，为代码库构建持久知识图谱（函数、类、调用链、HTTP 路由等），让 AI 代理能用精确的图查询代替文件级 grep/读取，大幅减少上下文消耗。

- **语言：** 纯 C（单静态二进制，零依赖）
- **许可证：** MIT
- **核心机制：** 索引代码库 → 构建知识图谱（节点 + 边） → MCP 工具查询
- **性能：** Linux 内核（2800万行/7.5万文件）3分钟索引完成，查询 <1ms
- **内置 3D 图谱可视化：** `localhost:9749`

---

## 安装

### 一键安装（macOS / Linux）

```bash
curl -fsSL https://raw.githubusercontent.com/DeusData/codebase-memory-mcp/main/install.sh | bash
```

带图谱可视化 UI：

```bash
curl -fsSL https://raw.githubusercontent.com/DeusData/codebase-memory-mcp/main/install.sh | bash -s -- --ui
```

### Homebrew

```bash
brew install codebase-memory-mcp
```

### 手动配置（如果不用一键安装）

下载对应平台的二进制，解压后用 `install` 命令：

```bash
./install.sh
```

或者手动添加到 `.mcp.json`：

```json
{
  "mcpServers": {
    "codebase-memory-mcp": {
      "command": "/path/to/codebase-memory-mcp",
      "args": []
    }
  }
}
```

---

## 在 Claude Code 中使用

### 索引项目

安装后重启 Claude Code，对任意项目说：

> 索引这个项目

或直接调用 MCP 工具：

```
index_repository(repo_path="/绝对/路径/到/项目")
```

### 常用工具

| 工具 | 作用 | 示例场景 |
|------|------|----------|
| `get_architecture` | 获取项目架构概览（语言、包、路由、热点） | 首次接手项目 |
| `search_graph` | 结构化搜索函数/类/文件 | "找到所有名称含 Handler 的函数" |
| `trace_path` | 调用链追踪（BFS，深度1-5） | "谁调用了 ProcessOrder？" |
| `search_code` | 图增强的代码搜索 | "在已索引文件中搜关键字" |
| `query_graph` | Cypher 图查询 | `MATCH (f:Function)-[:CALLS]->(g) RETURN f.name` |
| `detect_changes` | Git 变更影响分析 | "这次改动的波及范围？" |
| `get_code_snippet` | 按限定名获取源代码 | "读取 main.Utils.calculate" |
| `manage_adr` | 架构决策记录 CRUD | "记录为什么选了这个方案" |
| `list_projects` | 查看已索引的项目 | "我有哪些项目索引了？" |

### 典型工作流

1. **项目接入：** `index_repository(repo_path="/path/to/project")`
2. **快速了解：** `get_architecture(repo_path="/path/to/project")`
3. **深入代码：** `trace_path(function_name="processPayment", direction="both")`
4. **变更分析：** `detect_changes(repo_path="/path/to/project")`
5. **交叉引用：** `search_graph(name_pattern=".*Auth.*", label="Function")`

### 图谱可视化

如果安装了 UI 变体：

```bash
codebase-memory-mcp --ui=true --port=9749
```

打开 `http://localhost:9749` 即可交互式浏览知识图谱。

---

## 配置

```bash
codebase-memory-mcp config list                              # 查看所有设置
codebase-memory-mcp config set auto_index true               # 会话启动时自动索引
codebase-memory-mcp config set auto_index_limit 50000        # 自动索引文件上限
```

### 环境变量

| 变量 | 默认值 | 说明 |
|------|--------|------|
| `CBM_CACHE_DIR` | `~/.cache/codebase-memory-mcp` | 数据库存储路径 |
| `CBM_LOG_LEVEL` | `info` | 日志级别（debug/info/warn/error/none）|
| `CBM_WORKERS` | 自动检测 | 并行索引线程数 |

---

## 团队共享

索引后的图可以压缩为 `.codebase-memory/graph.db.zst` 提交到仓库，其他成员克隆后可免重索引：

```bash
codebase-memory-mcp config set auto_index true  # 首次连接时自动导入
```

---

## 与 context-mode 的对比

| 维度 | codebase-memory-mcp | context-mode |
|------|-------------------|-------------|
| **核心解决** | 代理看不懂代码结构 | 代理被数据/日志填满上下文 |
| **方法** | 预处理代码成图谱 → 精确查询 | 沙箱执行 → 仅摘要进对话 |
| **安装** | ~10MB 静态二进制 | npm 包 + 运行时依赖 |
| **许可证** | MIT | Elastic-2.0 |
| **互补** | 可同时使用，互不冲突 | 可同时使用，互不冲突 |

---

## 卸载

```bash
codebase-memory-mcp uninstall
```

移除所有代理配置，保留二进制和数据库。手动删除二进制及 `~/.cache/codebase-memory-mcp/` 可实现完全清理。
