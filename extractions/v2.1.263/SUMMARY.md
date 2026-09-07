# Claude Code Environment Variables — v2.1.263

Source: `@anthropic-ai/claude-code-linux-x64@2.1.263`, documented from
string literals in the published release artifact.

- `all_vars.txt` — `process.env.<NAME>` reads, `LC_ALL=C sort -u`.
- `model_provider_env_strings.txt` — model/provider configuration keys that
  appear as static allowlist strings rather than direct `process.env` reads.

## Counts (vs v2.1.222)

| Metric | Value |
|--------|-------|
| Total vars (`all_vars.txt`) | 438 |
| Added | 48 |
| Removed | 149 |

See `new_vs_2.1.222.txt` and `removed_vs_2.1.222.txt` for the full diff.

## Notable Additions

<!-- TODO(review): group the 48 added vars by theme and say what changed. -->

## Notable Removals

<!-- TODO(review): group the 149 removed vars by theme and say what changed. -->

> Note: 2 configuration string(s) referencing an unreleased model codename
> were held out of the public artifacts. See `_held/` (private, gitignored)
> and the top-level `FLAGGED.md`.
