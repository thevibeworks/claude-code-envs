# Claude Code Environment Variables — v2.1.234

Source: `@anthropic-ai/claude-code-linux-x64@2.1.234`, documented from string
literals in the published release artifact.

- `registry.tsv` — the environment registry the build declares, one row per
  variable: name, parser type (`str` / `bool` / `triBool` / `int` / `enum`),
  and the parser argument (enum options or an int default) when present.
- `registry.txt` — just the names from `registry.tsv`.
- `direct_reads.txt` — literal `process.env.<NAME>` reads. Mostly vendored
  dependencies (Azure SDK, gRPC, Bun runtime, sharp, google-auth) plus a few
  first-party call sites that never joined the registry.
- `all_vars.txt` — the union of the two. This is the published inventory.
- `model_provider_env_strings.txt` — model/provider configuration keys that
  appear as static allowlist strings rather than registry entries.
- `concat_artifacts.txt` — captures that are provably `strings(1)` boundary
  accidents but could not be resolved to a real name, so they were excluded
  rather than guessed at.

## Counts (vs v2.1.218)

| Metric | Value |
|--------|-------|
| Total vars (`all_vars.txt`) | 994 |
| Added | 77 |
| Removed | 8 |

See `new_vs_2.1.218.txt` and `removed_vs_2.1.218.txt` for the full diff.

Split by source: 867 published registry entries (868 declared, one held — see
the note at the end), 486 literal `process.env` reads, 359 of which also appear
in the registry.

## Method note — this version and v2.1.170/v2.1.197/v2.1.218 were re-measured

Builds from ~v2.1.170 on no longer read `process.env.X` at each call site. They
declare a typed registry once and install it as a proxy object, so call sites
read `V.X` (the alias is minifier output and changes between builds). The
earlier `process.env.`-only extraction therefore undercounted by hundreds and
reported variables as *removed* when a build merely moved them behind the
proxy. Every version from v2.1.170 on has been re-extracted with
`scripts/extract-registry.py`, which detects the schema helper per build rather
than hardcoding a minified name.

Corrected diffs (old single-grep numbers in parentheses):

| Transition | Added | Removed |
|------------|-------|---------|
| v2.1.139 → v2.1.170 | 163 (55) | 1 (45) |
| v2.1.170 → v2.1.197 | 68 (22) | 9 (7) |
| v2.1.197 → v2.1.218 | 94 (9) | 20 (126) |
| v2.1.218 → v2.1.234 | 77 | 8 |

The v2.1.197 → v2.1.218 line is the clearest case: the previously published
126 "removals" were almost entirely measurement artifacts. Sampled entries
(`CLAUDE_CODE_ENABLE_TASKS`, `OTEL_METRICS_EXPORTER`, `ANTHROPIC_BETAS`) are all
present in v2.1.218's registry.

The v2.1.139 → v2.1.170 jump of +163 is a genuine build-structure boundary, not
a code change of that size: v2.1.170 is the first release with the registry, so
it is the first release whose full config surface is visible at all.

## Notable Additions

Self-hosted runner — the largest single block, 24 new variables for a runner
pool that spawns and recycles sessions:

- Lifecycle: `SELF_HOSTED_RUNNER_MAX_LIFETIME_MS`, `SELF_HOSTED_RUNNER_RETIRE_AT`,
  `SELF_HOSTED_RUNNER_IDLE_SHUTDOWN_MS`, `SELF_HOSTED_RUNNER_SESSION_IDLE_MS`,
  `SELF_HOSTED_RUNNER_DRAIN_GRACE_MS`, `SELF_HOSTED_RUNNER_DRAIN_WAIT_MS`,
  `SELF_HOSTED_RUNNER_SIGKILL_TIMEOUT_MS`,
  `SELF_HOSTED_RUNNER_STARTUP_TIMEOUT_MS`,
  `SELF_HOSTED_RUNNER_SESSION_STOP_GRACE_MS`
- Isolation / trust: `SELF_HOSTED_RUNNER_LOCK_TO_ACCOUNT`,
  `SELF_HOSTED_RUNNER_TRUST_WORKSPACE`,
  `SELF_HOSTED_RUNNER_CONFINE_REPO_SETTINGS`,
  `SELF_HOSTED_RUNNER_CONFIGURE_GIT`
- Secrets: `SELF_HOSTED_RUNNER_POOL_SECRET`,
  `SELF_HOSTED_RUNNER_ENVIRONMENT_SECRET`
- Paths / hooks / observability: `SELF_HOSTED_RUNNER_BASE_DIR`,
  `SELF_HOSTED_RUNNER_EXEC_PATH`, `SELF_HOSTED_RUNNER_HOST_CONFIG_DIR`,
  `SELF_HOSTED_RUNNER_HOOKS_DIR`,
  `SELF_HOSTED_RUNNER_POST_SESSION_HOOK_TIMEOUT_MS`,
  `SELF_HOSTED_RUNNER_HEALTH_PORT`, `SELF_HOSTED_RUNNER_LOG_FILE`,
  `SELF_HOSTED_RUNNER_DEBUG_DIR`, `SELF_HOSTED_RUNNER_DEBUG_TOKEN_DIR`,
  `SELF_HOSTED_RUNNER_PUSH_OUTCOME_ON_RELEASE`

Matching runner git controls: `CLAUDE_RUNNER_SKIP_GIT_VERIFY`,
`CLAUDE_RUNNER_USE_GIT_PROXY`.

Cross-session messaging — the `harbor_kite` feature (`SendMessage` /
`ListAgents` between sessions):

- `CLAUDE_CODE_HARBOR_KITE` (bool) — force-enables the feature regardless of
  the server flag.
- `CLAUDE_CODE_HARBOR_KITE_CLOUD` (bool) — extends reachability to cloud
  sessions.
- `CLAUDE_CODE_MESSAGING_SOCKET`, `CLAUDE_CODE_MESSAGING_TOKEN` — set by the
  process itself when it opens its inbox; not user-facing configuration.

Artifacts — 10 new variables, the second-largest block, covering asset hosting,
a local DB, and a comment-responder loop:

- `CLAUDE_CODE_ARTIFACT_ASSETS`, `CLAUDE_CODE_ARTIFACT_ASSET_BASE_URL`,
  `CLAUDE_CODE_ARTIFACT_LIVE_BASE_URL`,
  `CLAUDE_CODE_ARTIFACT_VIEWER_BASE_URL`, `CLAUDE_CODE_ARTIFACTS_API_TOKEN`,
  `CLAUDE_CODE_ARTIFACT_DB`, `CLAUDE_CODE_ARTIFACT_COMMENTS`,
  `CLAUDE_CODE_ARTIFACT_COMMENTS_AUTOREACT`,
  `CLAUDE_CODE_ARTIFACT_COMMENT_FAST_ACK`,
  `CLAUDE_CODE_ARTIFACT_COMMENT_RESPONDER`
- Related: `CLAUDE_CODE_PLAN_ARTIFACTS`, `CLAUDE_CODE_COWORK_FRAME_ARTIFACTS`

New disable switches (each one is a supported way to turn a behaviour off):

- `CLAUDE_CODE_DISABLE_DIR_SYNC`
- `CLAUDE_CODE_DISABLE_PERMISSION_PROMPT_NOTIFY_HOOKS`
- `CLAUDE_CODE_DISABLE_UNKNOWN_MODEL_WINDOW_ENFORCEMENT`
- `CLAUDE_CODE_DISABLE_MTLS_RELOAD_ON_STALE_CONNECTION`
- `CLAUDE_CODE_DISABLE_ADMIN_ENV_UNION`

Telemetry: the three per-signal OTLP header overrides are back —
`OTEL_EXPORTER_OTLP_{LOGS,METRICS,TRACES}_HEADERS`.

Provider: `ANTHROPIC_BEDROCK_REGION_PREFIX` (enum) joins the Bedrock routing
knobs.

Other first-party additions: `CLAUDE_CODE_ENABLE_TODO_TOOLS`,
`CLAUDE_CODE_ENABLE_NARRATION`, `CLAUDE_CODE_TURN_UPDATES`,
`CLAUDE_CODE_GOAL_CHECKIN_MINUTES`, `CLAUDE_CODE_TOOL_MEMORY_LIMIT`,
`CLAUDE_CODE_WEBFETCH_CACHE_TTL_MS`, `CLAUDE_CODE_WEB_FETCH_AGENT`,
`CLAUDE_CODE_WORKFLOW_PREFIX_STAGGER_MS`, `CLAUDE_CODE_SKILL_PROPOSALS`,
`CLAUDE_CODE_PROJECT_DIR_NAME`, `CLAUDE_CODE_SLACK_TAG_TOKEN`,
`CLAUDE_CODE_RETIRE_UNANSWERED_PARKED_PERMISSION`, `MCP_PROTOCOL_NEGOTIATION`,
`CLAUDE_AX_PREPARK_MS`, and three bridge-reattach keys
(`CLAUDE_BRIDGE_REATTACH_NO_BACKFILL`, `_OWNER_ACCT`, `_OWNER_ORG`).

Two new codename-style flags appear without any other identifying strings:
`CLAUDE_CODE_PARCHMENT_FERN`, `CLAUDE_CODE_THRIFTY_SONIC`.

## Removals (8)

- `CLAUDE_CODE_HERON_TALLOW`, `CLAUDE_CODE_MARL_CORMORANT` — codename flags
  retired (graduated or dropped).
- `CLAUDE_CODE_POST_FOR_SESSION_INGRESS_V2` — the v2 ingress path is no longer
  behind a flag.
- `CLAUDE_CODE_MAX_SUBAGENTS_PER_SESSION`, `CLAUDE_CODE_INVESTIGATE_FIRST`,
  `CLAUDE_CODE_COMMIT_LOG` — knobs removed.
- `BUN_JS_DEBUG`, `DATABASE_URL` — dependency reads that disappeared with a
  vendored-dependency change.

These are re-measured against the registry, so unlike the previously published
v2.1.218 removal list they are not proxy-alias artifacts.

## registry.tsv — type breakdown

| Type | Count |
|------|-------|
| `str` | 446 |
| `bool` | 279 |
| `int` | 98 |
| `triBool` | 40 |
| `enum` | 4 |
| **total** | **867** |

`triBool` is the three-state form: unset is distinguishable from an explicit
false. The four enums:

| Variable | Options |
|----------|---------|
| `CCR_ON_BRANCH_DEFAULT_GUARD` | `enforce`, `observe`, `off` |
| `CLAUDE_CODE_MEMORY_PUSH_DELETE_MODE` | `corroborate`, `immediate`, `never` |
| `CLAUDE_CODE_TODO_REMINDER_MODE` | `baseline`, `off` |
| `ANTHROPIC_BEDROCK_REGION_PREFIX` | options passed by reference, not inline |

## model_provider_env_strings.txt

No change in shape from v2.1.218: the four released model lines (opus, sonnet,
haiku, fable) each carry `_MODEL`, `_MODEL_NAME`, `_MODEL_DESCRIPTION`, and
`_MODEL_SUPPORTED_CAPABILITIES`, plus per-line `DISABLE_PROMPT_CACHING_*` and
the `VERTEX_REGION_CLAUDE_*` region table.

> Note: one configuration string referencing an unreleased model codename was
> held out of the public artifacts. See `_held/` (private, gitignored) and the
> top-level `FLAGGED.md`. The hold is now applied by `extract-binary.sh` rather
> than by hand, so the codename gate passes by construction.
