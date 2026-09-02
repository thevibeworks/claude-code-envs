# Claude Code Environment Variables — v2.1.139

Source: `@anthropic-ai/claude-code-linux-x64@2.1.139`, documented from string
literals in the published release artifact.

`all_vars.txt` holds the `process.env.<NAME>` reads, `LC_ALL=C sort -u`.

This build predates the typed env registry introduced around v2.1.170, so
every read is a literal `process.env.<NAME>` and `all_vars.txt` ==
`direct_reads.txt`. `registry.txt` is absent here by design; the shared
pipeline emits the same file set for every version.

## Counts (vs v2.1.121)

| Metric | Value |
|--------|-------|
| Total vars (`all_vars.txt`) | 630 |
| Added | 36 |
| Removed | 2 |

See `new_vs_2.1.121.txt` and `removed_vs_2.1.121.txt` for the full diff.
