# Claude Code Environment Variables — v2.1.222

Source: `@anthropic-ai/claude-code-linux-x64@2.1.222`, documented from
string literals in the published release artifact.

- `all_vars.txt` — `process.env.<NAME>` reads, `LC_ALL=C sort -u`.
- `model_provider_env_strings.txt` — model/provider configuration keys that
  appear as static allowlist strings rather than direct `process.env` reads.

## Counts (vs v2.1.218)

| Metric | Value |
|--------|-------|
| Total vars (`all_vars.txt`) | 539 |
| Added | 3 |
| Removed | 2 |

See `new_vs_2.1.218.txt` and `removed_vs_2.1.218.txt` for the full diff.

## Notable Additions

New API surface:

- `CLAUDE_CODE_ARTIFACTS_API_TOKEN` — a dedicated credential for an
  "artifacts" endpoint. This is the only new `CLAUDE_CODE_*` read in the
  release, and it is the first artifacts-specific token to appear in any
  tracked version.

Toolchain reads (both standard names owned by other tools, not by Claude Code):

- `GIT_CONFIG_COUNT` — the git convention for injecting configuration through
  the environment (`GIT_CONFIG_COUNT` plus numbered `GIT_CONFIG_KEY_<n>` /
  `GIT_CONFIG_VALUE_<n>` pairs) instead of writing a config file. Its
  appearance is consistent with git invocations being configured in-process;
  the key/value reads themselves are built dynamically and so do not show up
  as literals.
- `NODE_TEST_WORKER_ID` — set by Node's built-in test runner. Most likely
  carried in from a bundled dependency rather than used by the CLI at
  runtime. Inference, not established from the literal alone.

## Notable Removals

Both removals are `CLAUDE_CODE_*` knobs:

- `CLAUDE_CODE_RESUME_INTERRUPTED_TURN` — feature flag, gone. The usual
  pattern for this repo's history is that such flags either graduate to
  default-on behaviour or are dropped; the literal alone cannot say which.
- `CLAUDE_CODE_SUBAGENT_MODEL` — the subagent model override. v2.1.218
  recorded several `ANTHROPIC_DEFAULT_*_MODEL` reads moving behind the model
  configuration abstraction; this removal fits that same migration rather
  than implying subagents lost model selection.

## model_provider_env_strings.txt

One new entry: `VERTEX_REGION_CLAUDE_5_OPUS`. v2.1.218 already carried
`VERTEX_REGION_CLAUDE_5_SONNET`, so the Vertex region table now covers both
released Claude 5 lines.

> Note: 1 configuration string(s) referencing an unreleased model codename
> were held out of the public artifacts. See `_held/` (private, gitignored)
> and the top-level `FLAGGED.md`.
