# Claude Code Environment Variables — v2.1.197

Source: `@anthropic-ai/claude-code-linux-x64@2.1.197`, documented from string
literals in the published release artifact.

- `all_vars.txt` — `process.env.<NAME>` reads, `LC_ALL=C sort -u`.
- `model_provider_env_strings.txt` — model/provider configuration keys that
  appear as static allowlist strings rather than direct `process.env` reads.

One extraction artifact corrected before diffing: the binary packs
`process.env.BUN_ENV` immediately adjacent to unrelated loader-extension
literals with no separating NUL byte, so a naive `strings` capture reads
`BUN_ENVprocess.browser.toml.yaml.wasm.text.json5`. Corrected to `BUN_ENV`
(same variable as v2.1.170 — not a real add/remove) before computing the
counts below.

## Counts (vs v2.1.170)

| Metric | Value |
|--------|-------|
| Total vars (`all_vars.txt`) | 655 |
| Added | 22 |
| Removed | 7 |

## Notable Additions

Multi-agent coordinator (new subsystem — matches the Claude API's
`multiagent: {type: "coordinator"}` Managed Agents feature):

- `CLAUDE_CODE_COORDINATOR_EXTRA_TOOLS`

Gateway / egress routing (new):

- `CLAUDE_CODE_USE_GATEWAY`
- `CLAUDE_GATEWAY_ALLOW_LOOPBACK`

(`CCR_EGRESS_GATEWAY_ENABLED` / `CCR_UPSTREAM_PROXY_ENABLED` were removed in
the same release — reads as a rename/supersede, not a net-new capability.)

Project / session identity:

- `CLAUDE_PROJECT_UUID`
- `CLAUDE_RUNNER_ACTIVITY_FD`

Cloud credential-chain vars surfaced directly:

- `AWS_CONFIG_FILE`
- `AWS_CONTAINER_CREDENTIALS_FULL_URI`
- `AWS_CONTAINER_CREDENTIALS_RELATIVE_URI`
- `AWS_ROLE_ARN`
- `AWS_SHARED_CREDENTIALS_FILE`
- `AWS_WEB_IDENTITY_TOKEN_FILE`
- `CLOUDSDK_AUTH_ACCESS_TOKEN`

Other: `BUF_BIGINT_DISABLE`, `JAVA_TOOL_OPTIONS`, `NODE_USE_ENV_PROXY`,
`CLAUDE_CODE_DD_ERROR_TRACKING_FLUSH_INTERVAL_MS`, `CLAUDE_CODE_FORCE_TIP_ID`,
`CLAUDE_CODE_SHOJI_ENGINE`, `CLAUDE_CODE_TERMINAL_MCP_TOOLS`,
`CLAUDE_INTERNAL_ASSISTANT_TEAM_NAME`, `INK_SCREEN_READER`,
`__MINIMATCH_TESTING_PLATFORM__`.

Removed: `CLAUDE_ASYNC_AGENT_STALL_TIMEOUT_MS`, `CLAUDE_BG_STARTUP_WEDGE_MS`,
`CLAUDE_CODE_FRAME_TIMING_LOG`, `CLAUDE_CODE_PLAN_MODE_REQUIRED`,
`CLAUDE_CODE_TEAM_ONBOARDING`, plus the two `CCR_*` gateway vars above.

Additional Sonnet 5 provider configuration (`model_provider_env_strings.txt`):

- `VERTEX_REGION_CLAUDE_5_SONNET`

The Sonnet line is released, so this ships in the public artifact normally —
it's the only genuinely new entry in `model_provider_env_strings.txt` this
release (the base `ANTHROPIC_DEFAULT_*_MODEL` / `DISABLE_PROMPT_CACHING_*`
forms already existed in v2.1.170; they're all captured this time by the same
script, same as always).

See `new_vs_2.1.170.txt` and `removed_vs_2.1.170.txt` for the full diff.

> Note: one configuration string referencing an unreleased model codename was
> held out of the public artifacts. See `_held/HELD-INVENTORY.md` (private,
> gitignored) and the top-level `FLAGGED.md`.
