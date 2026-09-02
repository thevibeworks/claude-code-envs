# claude-code-envs

> Release documentation of Claude Code environment variables, tracked across
> versions with a deterministic, auditable extraction method.

[![extract](https://github.com/thevibeworks/claude-code-envs/actions/workflows/deterministic-extract.yml/badge.svg)](../../actions/workflows/deterministic-extract.yml)
[![license](https://img.shields.io/badge/license-MIT-blue.svg)](LICENSE)

Claude Code reads a large and growing set of environment variables to configure
models, providers, transports, feature flags, and runtime behavior. This
repository documents which variables each published release reads, and how that
set changes from version to version.

The latest documented release, **v2.1.234**, reads **994** environment
variables — **867** of them declared in the build's own typed registry, the rest
read literally at a call site.

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
  all_vars.txt                    every env var the release reads:
                                  registry.txt U direct_reads.txt
                                  (LC_ALL=C sort -u)
  registry.tsv                    the build's declared env registry, typed:
                                  name, parser type, parser arg. Absent for
                                  pre-v2.1.170 builds, which have no registry
  registry.txt                    just the names from registry.tsv
  direct_reads.txt                literal process.env.<NAME> reads
  concat_artifacts.txt            captures that are provably strings(1)
                                  boundary accidents and could not be
                                  resolved; excluded rather than guessed at
  model_provider_env_strings.txt  the model/provider config surface in full;
                                  some of these are also in all_vars.txt
  new_vs_<prev>.txt               variables added since <prev>
  removed_vs_<prev>.txt           variables removed since <prev>
  SUMMARY.md                      counts, notable changes, source

scripts/
  fetch-release.sh                npm dist-tags + npm pack + sha512 manifest
  extract-registry.py             the declared typed env registry
  extract-direct-reads.py         literal process.env.<NAME> reads
  extract-binary.sh               runs both, unions them, emits model/provider
                                  strings, holds unreleased codenames
  compare-release.sh              comm-based added/removed between two versions
  validate-extraction.sh          gates: locale, secrets, codenames, counts

FLAGGED.md                        items held out of public artifacts and why
```

Versions tracked: `v2.1.121`, `v2.1.139`, `v2.1.170`, `v2.1.197`, `v2.1.218`,
`v2.1.234`.

> v2.1.121 is the first version captured here. Its `new_vars.txt` /
> `removed_vars.txt` are the delta against the prose documentation that preceded
> this repository. From v2.1.139 on, diffs are between consecutive extractions
> and named `new_vs_<prev>.txt` / `removed_vs_<prev>.txt`.

## Method

Recent Claude Code releases ship as a compiled, self-contained executable rather
than readable JavaScript. The configuration surface still survives as string
literals in the artifact's constant pool, so reading it is a deterministic,
repeatable operation.

There are two places to read it from, and using only one of them is wrong.

**The declared registry (v2.1.170+).** Modern builds do not read
`process.env.X` at each call site. They declare the whole set once, typed, and
install it as a proxy object:

```js
var NS={}; yt(NS,{CLAUDE_CODE_FOO:()=>gFoo, ...});   // the declaration
gFoo = Ve.bool()                                     // the type
V = LTs({...NS, ...}, proto)                         // call sites read V.FOO
```

`extract-registry.py` detects the schema helper (`Ve` above — a different
minified name in every build) by frequency rather than hardcoding it, then
reports every declared name with its parser type. That set is name-complete and
does not shift when the minifier renames things.

**Literal reads.** `extract-direct-reads.py` collects what is still read as
`process.env.X` — mostly vendored dependencies (Azure SDK, gRPC, Bun runtime,
sharp, google-auth) plus a few first-party call sites that never joined the
registry. Pre-registry builds read everything this way.

Using the literal grep alone undercounts a modern build by hundreds of names,
and — worse — reports a variable as *removed* when a build merely moved it
behind the proxy. The originally published v2.1.197 → v2.1.218 diff claimed 126
removals on exactly that basis; re-measured against the registry it is 20. Every
version from v2.1.170 on has been re-extracted with the current method.

The pipeline:

1. `fetch-release.sh` resolves the version via npm dist-tags, packs the exact
   version with `npm pack`, and records a `sha512` integrity manifest. The
   artifact itself is never committed.
2. `extract-binary.sh` runs both extractors, unions them into `all_vars.txt`,
   emits the model/provider config strings, and moves any unreleased-codename
   string into the gitignored hold directory.
3. `compare-release.sh` diffs against the previous version with `comm`.
4. `validate-extraction.sh` gates the result (see below).

Everything runs under `LC_ALL=C` so sorting and diffing are byte-deterministic
on any machine.

## Confidence model

The data is a literal record, not an inference. Each entry is exactly a string
that exists in the published release artifact. That bounds what we can and
cannot claim:

- **High confidence — the variable is referenced.** If a name appears in
  `all_vars.txt`, the release either declares it in its typed env registry or
  contains a literal `process.env.<NAME>` read for it. The diff counts are reproducible: re-running the pipeline yields the same
  numbers, and the validator enforces that the documented counts match the raw
  line counts.
- **Type, yes. Behavior, no.** For registry entries, `registry.tsv` records the
  parser the build applies (`str` / `bool` / `triBool` / `int` / `enum`, plus
  enum options and int defaults where they are inline). That is read straight
  from the declaration. What the value then *does* is not recorded here — a
  declaration is evidence of a knob, not of its effect.
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
scripts/fetch-release.sh 2.1.234

# 2. the compiled executable ships in a platform-specific optionalDependency,
#    not in the wrapper package -- fetch and unpack that one
(cd build/2.1.234 && npm pack @anthropic-ai/claude-code-linux-x64@2.1.234)
mkdir -p build/2.1.234/package
tar -xzf build/2.1.234/anthropic-ai-claude-code-linux-x64-*.tgz \
    -C build/2.1.234/package --strip-components=1

# 3. extract (registry + direct reads + model/provider strings)
scripts/extract-binary.sh build/2.1.234/package/claude v2.1.234

# 4. diff against the previous tracked version
scripts/compare-release.sh v2.1.218 v2.1.234

# 5. gate the result (must exit 0 before publishing)
scripts/validate-extraction.sh v2.1.234
```

Requires `binutils` (for `strings`), `grep`, and `python3`.

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
