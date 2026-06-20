# Codex DeepSeek Backup Profile Design

## Goal

Add `deepseek-v4-pro` as an optional Codex CLI profile while keeping OpenAI as the default provider and preserving all existing authentication and conversation history.

## Safety Boundaries

- Keep `~/.codex/config.toml` set to the built-in `openai` provider and its current default model.
- Do not modify `~/.codex/auth.json`, `~/.codex/history.jsonl`, `~/.codex/sessions/`, or `CODEX_HOME`.
- Store no API key in TOML, scripts, launch-agent files, or the bridge configuration.
- Store the DeepSeek API key in macOS Keychain. The bridge startup process reads it and exports `DEEPSEEK_API_KEY` only to the bridge process.
- Bind the bridge only to `127.0.0.1` so it is not reachable from the network.

## Architecture

Codex CLI starts with `--profile deepseek` and overlays `~/.codex/deepseek.config.toml` on the unchanged OpenAI defaults. The profile selects `deepseek-v4-pro` and a custom provider whose base URL points to a local LiteLLM bridge. The bridge accepts the Responses API used by Codex, translates requests to DeepSeek's supported API, and returns compatible streaming events.

The normal Codex app and ordinary `codex` commands do not select this profile, so they continue using OpenAI.

## Components

- An isolated Python virtual environment under `~/.codex/deepseek-bridge/venv` containing LiteLLM.
- A LiteLLM configuration under `~/.codex/deepseek-bridge/` that references `os.environ/DEEPSEEK_API_KEY` and maps `deepseek-v4-pro`.
- A local startup script that retrieves the key from macOS Keychain, exports it to the bridge process, and starts the loopback-only server.
- `~/.codex/deepseek.config.toml`, containing only the DeepSeek model and local custom-provider settings.
- A `codex-deepseek` launcher command that ensures the bridge is healthy before running `codex --profile deepseek`.

## Data Flow

1. `codex-deepseek` starts or health-checks the local bridge.
2. Codex loads the base OpenAI configuration and overlays `deepseek.config.toml` for that process only.
3. Codex sends a Responses API request to the loopback bridge.
4. The bridge reads `DEEPSEEK_API_KEY` from its process environment and calls `deepseek-v4-pro`.
5. The bridge translates DeepSeek output and tool calls back into Responses API events for Codex.

## Failure Handling

- If Keychain has no DeepSeek key, the launcher exits with an actionable error before starting Codex.
- If the bridge health check fails, the launcher exits without changing the default Codex configuration.
- If Responses translation, streaming, or tool calls fail during verification, the DeepSeek profile remains disabled and OpenAI remains untouched.
- Installation artifacts can be removed independently without affecting Codex history or OpenAI login state.

## Verification

- Confirm the base configuration still reports the OpenAI provider and existing model.
- Confirm `auth.json`, history file counts, and session file counts are unchanged after installation.
- Start Codex through the DeepSeek profile and verify the effective model/provider.
- Run a minimal response test, a streaming response test, and a tool-call test.
- Restart the normal Codex app and confirm it still uses OpenAI and displays existing conversations.

