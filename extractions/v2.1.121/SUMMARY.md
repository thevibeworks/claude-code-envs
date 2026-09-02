# Claude Code Environment Variables — v2.1.121

Source: `@anthropic-ai/claude-code-linux-x64@2.1.121`, documented from string
literals in the published release artifact.

This is the first version captured in this repository. `all_vars.txt` holds the
`process.env.<NAME>` reads, `LC_ALL=C sort -u`.

This build predates the typed env registry introduced around v2.1.170, so
every read is a literal `process.env.<NAME>` and `all_vars.txt` ==
`direct_reads.txt`. `registry.txt` is absent here by design; the shared
pipeline emits the same file set for every version.

## Counts

| Metric | Value |
|--------|-------|
| Total vars (`all_vars.txt`) | 596 |

`new_vars.txt` (135) and `removed_vars.txt` (22) are the delta against the
earlier prose documentation baseline that preceded this repository, not against
a prior extraction in this layout. From v2.1.139 onward, diffs are computed
between consecutive extractions and named `new_vs_<prev>.txt` /
`removed_vs_<prev>.txt`.
