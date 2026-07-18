# Codex DeepSeek 备用配置设计

## 目标

为 Codex CLI 增加可选的 `deepseek-v4-pro` 配置，同时保持 OpenAI 为默认 Provider，并保留现有的登录状态和全部历史会话。

## 安全边界

- `~/.codex/config.toml` 继续使用内置的 `openai` Provider 和当前默认模型。
- 不修改 `~/.codex/auth.json`、`~/.codex/history.jsonl`、`~/.codex/sessions/` 或 `CODEX_HOME`。
- 不在 TOML、脚本、LaunchAgent 文件或本地桥配置中保存 API Key 明文。
- DeepSeek API Key 存入 macOS 钥匙串。本地桥启动时读取 Key，并且只在本地桥进程中导出为 `DEEPSEEK_API_KEY`。
- 本地桥只监听 `127.0.0.1`，不允许其他网络设备访问。

## 架构

使用 `codex --profile deepseek` 启动 Codex CLI。Codex 会先读取保持不变的 OpenAI 默认配置，再叠加 `~/.codex/deepseek.config.toml`。这个独立配置会选择 `deepseek-v4-pro`，并把自定义 Provider 的地址指向本地 LiteLLM 协议桥。本地桥接收 Codex 使用的 Responses API 请求，将其转换为 DeepSeek 支持的 API 请求，再把返回内容转换成 Codex 兼容的流式事件。

普通 Codex App 和直接运行的 `codex` 命令不会选择这个独立配置，因此仍然使用 OpenAI。

## 组成部分

- 位于 `~/.codex/deepseek-bridge/venv` 的独立 Python 虚拟环境，用于安装 LiteLLM。
- 位于 `~/.codex/deepseek-bridge/` 的 LiteLLM 配置，通过 `os.environ/DEEPSEEK_API_KEY` 读取 Key，并映射 `deepseek-v4-pro`。
- 本地启动脚本：从 macOS 钥匙串读取 Key，将其导出到本地桥进程，然后启动只监听本机的服务。
- `~/.codex/deepseek.config.toml`：只保存 DeepSeek 模型和本地自定义 Provider 设置。
- `codex-deepseek` 启动命令：先确认本地桥可以正常访问，再运行 `codex --profile deepseek`。

## 数据流

1. `codex-deepseek` 启动本地桥，或者检查已经运行的本地桥是否健康。
2. Codex 读取 OpenAI 默认配置，并且只为当前进程叠加 `deepseek.config.toml`。
3. Codex 把 Responses API 请求发送到本地桥。
4. 本地桥从自身进程环境读取 `DEEPSEEK_API_KEY`，然后调用 `deepseek-v4-pro`。
5. 本地桥把 DeepSeek 的输出和工具调用转换成 Codex 可识别的 Responses API 事件。

## 失败处理

- 如果 macOS 钥匙串中没有 DeepSeek API Key，启动命令会显示明确错误并退出，不启动 Codex。
- 如果本地桥健康检查失败，启动命令会退出，不修改默认 Codex 配置。
- 如果协议转换、流式输出或工具调用验证失败，DeepSeek 独立配置不会投入使用，OpenAI 默认配置保持不变。
- 可以单独删除本地桥及其安装文件，不影响 Codex 历史会话或 OpenAI 登录状态。

## 验证步骤

- 确认默认配置仍然使用 OpenAI Provider 和原来的默认模型。
- 确认安装前后 `auth.json`、历史记录数量和会话文件数量保持不变。
- 通过 DeepSeek 独立配置启动 Codex，并确认实际使用的模型和 Provider。
- 分别验证普通回复、流式输出和工具调用。
- 重启普通 Codex App，确认仍然使用 OpenAI，并且能够看到原来的历史会话。

