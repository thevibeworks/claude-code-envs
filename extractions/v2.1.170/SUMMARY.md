# Claude Code Environment Variables — v2.1.170

Source: `@anthropic-ai/claude-code-linux-x64@2.1.170`, documented from string
literals in the published release artifact.

- `all_vars.txt` — every environment variable the release reads:
  `registry.txt` ∪ `direct_reads.txt`, `LC_ALL=C sort -u`.
- `registry.tsv` / `registry.txt` — the typed registry the build declares
  (first release that has one: 626 published entries).
- `direct_reads.txt` — literal `process.env.<NAME>` reads (640).
- `model_provider_env_strings.txt` — model/provider configuration keys that
  appear as static allowlist strings rather than direct `process.env` reads.

## Counts (vs v2.1.139)

| Metric | Value |
|--------|-------|
| Total vars (`all_vars.txt`) | 792 |
| Added | 163 |
| Removed | 1 |

> **Re-measured (method correction).** This release declares its environment
> variables in a typed registry read through a proxy object, so the original
> `process.env.`-only extraction undercounted it and produced phantom
> "removed" entries. The counts below come from
> `scripts/extract-registry.py` ∪ `scripts/extract-direct-reads.py`.
> `../v2.1.234/SUMMARY.md` carries the old and new numbers side by side and
> explains the method.


## Notable Additions

Fable 5 model configuration (`all_vars.txt`):

- `ANTHROPIC_DEFAULT_FABLE_MODEL`
- `ANTHROPIC_DEFAULT_FABLE_MODEL_NAME`
- `ANTHROPIC_DEFAULT_FABLE_MODEL_DESCRIPTION`
- `DISABLE_PROMPT_CACHING_FABLE`

Additional Fable / provider configuration (`model_provider_env_strings.txt`):

- `ANTHROPIC_DEFAULT_FABLE_MODEL_SUPPORTED_CAPABILITIES`
- `VERTEX_REGION_CLAUDE_FABLE_5`

Environment / workspace identity:

- `ANTHROPIC_ENVIRONMENT_ID`
- `ANTHROPIC_ENVIRONMENT_KEY`
- `ANTHROPIC_WORKSPACE_ID`

Workflow / background / runtime controls:

- `CLAUDE_CODE_WORKFLOWS`
- `CLAUDE_CODE_DISABLE_WORKFLOWS`
- `CLAUDE_CODE_SYNC_SKILLS`
- `CLAUDE_CODE_SYNC_PLUGINS`
- `CLAUDE_BG_AUTH_SNAPSHOT_PATH`
- `CLAUDE_MEMORY_STORES`

See `new_vs_2.1.139.txt` and `removed_vs_2.1.139.txt` for the full diff.

> Note: one configuration string referencing an unreleased model codename was
> held out of the public artifacts. See `flagged_unreleased_codenames.txt` and
> the top-level `FLAGGED.md`.
