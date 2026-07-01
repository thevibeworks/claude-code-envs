# claude-code-envs

> Release documentation of Claude Code environment variables, tracked across
> versions with a deterministic, auditable extraction method.

[![extract](https://github.com/thevibeworks/claude-code-envs/actions/workflows/deterministic-extract.yml/badge.svg)](../../actions/workflows/deterministic-extract.yml)
[![license](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

Claude Code reads a large and growing set of environment variables to configure
models, providers, transports, feature flags, and runtime behavior. This
repository documents which variables each published release reads, and how that
set changes from version to version.

The latest documented release, **v2.1.197**, reads **655** environment
variables.

## What this is

- A per-version record of the environment variables a Claude Code release reads.
- A per-version diff so you can see exactly what was added or removed.
- A small set of scripts that reproduce every artifact deterministically from a
  published release, so the data is verifiable rather than asserted.

This is documentation built from the publicly distributed release artifacts. It
does not include or reproduce Claude Code's source, and it is not affiliated
with Anthropic.

## Layout

```text
extractions/<version>/
  all_vars.txt                    every process.env.<NAME> the release reads
                                  (LC_ALL=C sort -u)
  model_provider_env_strings.txt  model/provider config keys that appear as
                                  static allowlist strings (v2.1.170+)
  new_vs_<prev>.txt               variables added since <prev>
  removed_vs_<prev>.txt           variables removed since <prev>
  SUMMARY.md                      counts, notable changes, source

scripts/
  fetch-release.sh                npm dist-tags + npm pack + sha512 manifest
  extract-binary.sh               emit all_vars + model/provider strings
  compare-release.sh              comm-based added/removed between two versions
  validate-extraction.sh          gates: locale, secrets, codenames, counts

FLAGGED.md                        items held out of public artifacts and why
```

Versions tracked: `v2.1.121`, `v2.1.139`, `v2.1.170`, `v2.1.197`.

> v2.1.121 is the first version captured here. Its `new_vars.txt` /
> `removed_vars.txt` are the delta against the prose documentation that preceded
> this repository. From v2.1.139 on, diffs are between consecutive extractions
> and named `new_vs_<prev>.txt` / `removed_vs_<prev>.txt`.

## Method

Recent Claude Code releases ship as a compiled, self-contained executable rather
than readable JavaScript. The configuration surface still survives as string
literals in the artifact's constant pool: each `process.env.<NAME>` read and
each model/provider configuration key is present as a literal string. Reading
those literals is a deterministic, repeatable operation.

The pipeline:

1. `fetch-release.sh` resolves the version via npm dist-tags, packs the exact
   version with `npm pack`, and records a `sha512` integrity manifest. The
   artifact itself is never committed.
2. `extract-binary.sh` reads the string literals and emits two sorted-unique
   lists: `process.env.<NAME>` reads, and the focused model/provider config
   allowlist strings.
3. `compare-release.sh` diffs against the previous version with `comm`.
4. `validate-extraction.sh` gates the result (see below).

Everything runs under `LC_ALL=C` so sorting and diffing are byte-deterministic
on any machine.

## Confidence model

The data is a literal record, not an inference. Each entry is exactly a string
that exists in the published release artifact. That bounds what we can and
cannot claim:

- **High confidence — the variable is referenced.** If a name appears in
  `all_vars.txt`, the release contains a literal `process.env.<NAME>` read for
  it. The diff counts are reproducible: re-running the pipeline yields the same
  numbers, and the validator enforces that the documented counts match the raw
  line counts.
- **Documented, not interpreted.** This repository does not claim to know each
  variable's default, type, or runtime effect. It records that the variable is
  read, not what reading it does. A literal string is evidence of a reference,
  not of behavior.
- **String literals can outlive their use.** A name may persist in the constant
  pool after the code path that used it is gone. Presence means "referenced in
  this artifact," which is a slightly weaker claim than "active in this
  release." Treat the lists as the reference surface, not a guarantee every
  variable is wired to live behavior.
- **Released models only.** Configuration strings that reference unreleased
  model codenames are held out of the public artifacts. See `FLAGGED.md`.

## Reproduce a version

```bash
# 1. fetch the exact release and record its sha512 (artifact is gitignored)
scripts/fetch-release.sh 2.1.170

# 2. unpack the tarball under build/2.1.170/ and point the extractor at the
#    release executable, then extract
scripts/extract-binary.sh build/2.1.170/package/<artifact> 2.1.170

# 3. diff against the previous tracked version
scripts/compare-release.sh 2.1.139 2.1.170

# 4. gate the result (must exit 0 before publishing)
scripts/validate-extraction.sh 2.1.170
```

## Validation gates

`validate-extraction.sh` blocks an extraction unless all of these hold:

- **Locale.** `LC_ALL=C` is pinned for both `sort` and `comm`, and every list is
  verified byte-sorted-unique under it. An ambient UTF-8 locale makes `comm`
  fabricate phantom added/removed lines — this is the single most common failure
  and the validator refuses to pass without it.
- **No secrets or local paths.** No API keys (`sk-...`), bearer tokens,
  `refreshToken`, private keys, or `/Users/` / `/home/` paths in any artifact.
- **Released codenames only.** Public allowlist is `opus`, `sonnet`, `haiku`,
  `fable` (Fable 5). Any other codename fails loudly and exits non-zero unless it
  is in the version's flagged hold file.
- **Counts agree.** Each `SUMMARY.md` total and diff counts must match the raw
  line counts.
- **Size cap.** No artifact may exceed 1 MiB (catches accidental noise capture).

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md). New releases are added by running the
pipeline and committing only the text artifacts.

## License

[MIT](LICENSE)
