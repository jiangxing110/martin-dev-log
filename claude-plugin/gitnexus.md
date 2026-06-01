# GitNexus 使用说明

## 简介

GitNexus 将代码仓库构建为知识图谱，让 AI 编程助手（Claude Code、Cursor 等）能深度理解项目结构和依赖关系。

## 安装

```bash
npm install -g gitnexus
```

> 如果缺少 C++ 工具链，安装前设置 `GITNEXUS_SKIP_OPTIONAL_GRAMMARS=1` 跳过 Dart/Proto/Swift 语法编译。

## MCP 配置

### 方式一：自动配置

```bash
gitnexus setup
```

会自动检测编辑器并写入 MCP 配置文件。

### 方式二：手动配置（推荐）

在 `~/.claude/settings.json` 的 `mcpServers` 中添加：

```json
{
  "mcpServers": {
    "gitnexus": {
      "command": "npx",
      "args": ["-y", "gitnexus@latest", "mcp"]
    }
  }
}
```

## 索引项目

在项目根目录执行：

```bash
cd /path/to/qbit-assets
gitnexus analyze
```

常用选项：

- `--skip-embeddings`：不生成向量索引，更快
- `--force`：完整重建
- `--skip-agents-md`：保留自定义 AGENTS.md

## 常用命令

| 命令                       | 作用                                        |
| -------------------------- | ------------------------------------------- |
| `gitnexus analyze [path]`  | 索引仓库或更新索引                          |
| `gitnexus analyze --force` | 完整重建索引（重新解析+建图+全文搜索）      |
| `gitnexus list`            | 查看已索引的仓库                            |
| `gitnexus status`          | 查看当前仓库索引状态                        |
| `gitnexus clean`           | 删除当前仓库索引                            |
| `gitnexus wiki`            | 从知识图谱生成文档（需设置 OPENAI_API_KEY） |
| `gitnexus serve`           | 启动本地 HTTP 服务，配合 Web UI 使用        |

## Claude Code 获得的能力

配置并索引后，Claude Code 通过 MCP 获得：

- **上下文查询**：快速获取函数、类、文件的完整上下文
- **影响分析**：修改某个符号时，检测会影响到哪些地方
- **语义搜索**：BM25 + 向量混合搜索
- **变更检测**：将 git diff 映射到受影响的流程
- **批量重命名**：带置信度评级的跨文件重命名

## 多仓库

可以在多个项目执行 `gitnexus analyze`，同一个 MCP 服务会自动注册所有已索引的仓库。
