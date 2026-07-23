# Claude Code Environment Variables — v2.1.218

Source: `@anthropic-ai/claude-code-linux-x64@2.1.218`, documented from string
literals in the published release artifact.

- `all_vars.txt` — `process.env.<NAME>` reads, `LC_ALL=C sort -u`.
- `model_provider_env_strings.txt` — model/provider configuration keys that
  appear as static allowlist strings rather than direct `process.env` reads.

Same concatenation artifact as v2.1.197: the binary packs `process.env.BUN_ENV`
adjacent to unrelated loader-extension literals with no separating NUL byte
(`BUN_ENVprocess`), and `NODE_ENV` adjacent to `sec` (`NODE_ENVsec`). Corrected
to `BUN_ENV` and (since `NODE_ENV` already exists) removed the duplicate before
computing counts.

## Counts (vs v2.1.197)

| Metric | Value |
|--------|-------|
| Total vars (`all_vars.txt`) | 538 |
| Added | 9 |
| Removed | 126 |

Net reduction of 117 env-var reads vs v2.1.197 (655). The massive removal is
mostly feature flags that graduated to defaults, internal-only flags that were
inlined, and environment reads that moved behind abstractions.

## Notable Additions

Bridge / session reattach:

- `CLAUDE_BRIDGE_REATTACH_GROUPING`
- `CLAUDE_CODE_BRIDGE_SESSION_ID`

Cloud routing:

- `CLAUDE_CODE_USE_ANTHROPIC_GOOGLE_CLOUD` — new GCP routing path alongside
  existing Vertex/Bedrock options.

Safety / compliance:

- `CLAUDE_CODE_REFUSAL_FALLBACK_CATCH_ALL`
- `CCR_ON_BRANCH_DEFAULT_GUARD` — CCR branch safety guard.

Internal:

- `CLAUDE_INTERNAL_FC_OVERRIDES` — feature control overrides.
- `GIT_CONFIG_GLOBAL`, `NODE_CHANNEL_FD`, `TMPDIR` — standard env reads newly
  surfaced (likely refactored into direct reads from indirect access).

## Notable Removals (selected from 126)

Feature flags removed (graduated or dropped):

- `CLAUDE_CODE_ENABLE_TASKS`, `CLAUDE_CODE_ENABLE_AUTO_MODE`,
  `CLAUDE_CODE_ENABLE_XAA`, `CLAUDE_CODE_ENABLE_SDK_FILE_CHECKPOINTING`,
  `CLAUDE_CODE_ENABLE_GATEWAY_MODEL_DISCOVERY`,
  `CLAUDE_CODE_ENABLE_PROXY_AUTH_HELPER`,
  `CLAUDE_CODE_ENABLE_EXPERIMENTAL_ADVISOR_TOOL`,
  `CLAUDE_CODE_ENABLE_TOKEN_USAGE_ATTACHMENT`

Configuration knobs removed:

- `CLAUDE_CODE_MAX_CONTEXT_TOKENS`, `CLAUDE_CODE_GLOB_TIMEOUT_SECONDS`,
  `CLAUDE_CODE_STALL_TIMEOUT_MS_FOR_TESTING`,
  `CLAUDE_CODE_EXIT_AFTER_STOP_DELAY`, `CLAUDE_CODE_LOOP_PERSISTENT`,
  `CLAUDE_CODE_PLAN_V2_AGENT_COUNT`, `CLAUDE_CODE_PLAN_V2_EXPLORE_AGENT_COUNT`,
  `MAX_MCP_OUTPUT_TOKENS`

Telemetry:

- All 9 `OTEL_*` vars removed (`OTEL_EXPORTER_OTLP_*`, `OTEL_*_EXPORTER`,
  `OTEL_LOG_*`). Likely moved to a config object or removed entirely.

Model config:

- `ANTHROPIC_DEFAULT_OPUS_MODEL`, `ANTHROPIC_DEFAULT_SONNET_MODEL`,
  `ANTHROPIC_BETAS`, `ANTHROPIC_FOUNDRY_BASE_URL`,
  `ANTHROPIC_FOUNDRY_RESOURCE`, `ANTHROPIC_AWS_WORKSPACE_ID`
  — these reads appear to have moved behind the model-config abstraction layer.

Plugin system:

- `CLAUDE_CODE_PLUGIN_GIT_TIMEOUT_MS`, `CLAUDE_CODE_PLUGIN_PREFER_HTTPS`,
  `CLAUDE_CODE_PLUGIN_SEED_DIR`, `CLAUDE_CODE_PLUGIN_USE_ZIP_CACHE`,
  `CLAUDE_CODE_PLUGIN_KEEP_MARKETPLACE_ON_FAILURE`,
  `CLAUDE_CODE_DISABLE_OFFICIAL_MARKETPLACE_AUTOINSTALL`,
  `FORCE_AUTOUPDATE_PLUGINS`, `CLAUDE_CODE_USE_COWORK_PLUGINS`

CI / hosting env reads removed:

- `GITHUB_ACTOR`, `GITHUB_ACTOR_ID`, `GITHUB_REPOSITORY`,
  `GITHUB_REPOSITORY_ID`, `GITHUB_REPOSITORY_OWNER`,
  `GITHUB_REPOSITORY_OWNER_ID`, `ITERM_SESSION_ID`, `TMUX_PANE`,
  `COLORFGBG`, `ComSpec`, `SRT_WIN_PATH`, `SYSTEMROOT`

Session / identity:

- `CLAUDE_CODE_SESSION_NAME`, `CLAUDE_CODE_SESSION_LOG`,
  `CLAUDE_CODE_ACCOUNT_TAGGED_ID`, `CLAUDE_CODE_TASK_LIST_ID`

See `new_vs_2.1.197.txt` and `removed_vs_2.1.197.txt` for the full diff.

## model_provider_env_strings.txt

New entry: `VERTEX_REGION_CLAUDE_FABLE_5` (Fable 5 is released, ships publicly).

All `ANTHROPIC_DEFAULT_*_MODEL_SUPPORTED_CAPABILITIES` entries are new — these
were not present in v2.1.197. The model config abstraction now exposes
capabilities alongside name/description for each model tier.

> Note: one configuration string referencing an unreleased model codename was
> held out of the public artifacts. See `_held/` (private, gitignored) and the
> top-level `FLAGGED.md`.
