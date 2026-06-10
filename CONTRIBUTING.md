# Contributing

Thanks for helping keep the Claude Code environment-variable record accurate.

## Adding a new release

Run the pipeline end to end, then commit only the text artifacts.

```bash
# resolve + fetch the exact version (records sha512; tarball stays gitignored)
scripts/fetch-release.sh <version>

# unpack build/<version>/*.tgz, then extract from the release executable
scripts/extract-binary.sh build/<version>/package/<artifact> <version>

# diff against the previous tracked version
scripts/compare-release.sh <prev-version> <version>

# must pass before you open a PR
scripts/validate-extraction.sh <version>
```

Then write `extractions/<version>/SUMMARY.md` with the totals and notable
changes, and run the validator again so it checks the documented counts.

## Rules

- **Never commit the release artifact or any extracted executable.** Only the
  text files under `extractions/` are tracked. `build/` is gitignored.
- **Everything runs under `LC_ALL=C`.** The scripts pin it; do not re-sort lists
  in another locale. Byte order must be deterministic.
- **Released model codenames only** in public artifacts: `opus`, `sonnet`,
  `haiku`, `fable`. Anything else goes in the version's
  `flagged_unreleased_codenames.txt` and gets an entry in `FLAGGED.md`. The
  validator enforces this.
- **No secrets, tokens, or local paths** in any committed file.
- **Keep the diff surgical.** A release PR should touch one new version
  directory (plus `FLAGGED.md` / `README` counts when they change).

## Scripts depend only on

`bash`, `npm`, `strings` (binutils), `grep`, `comm`, `sort`, and `shasum` /
`sha512sum`. Keep it that way.

## Reporting an inaccuracy

Open an issue with the version, the variable name, and what you observe versus
what is documented. The data is meant to be reproducible, so include the
command output if you re-ran the pipeline.
