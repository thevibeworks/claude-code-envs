#!/usr/bin/env bash
# extract-binary.sh — document the environment variables referenced by a
# Claude Code release artifact.
#
# Four outputs, all `LC_ALL=C sort -u`:
#   registry.tsv                    declared config surface: name, type, arg
#   registry.txt                    just the names from registry.tsv
#   direct_reads.txt                literal `process.env.<NAME>` reads
#   all_vars.txt                    union of the two above
#   model_provider_env_strings.txt  model/provider config keys that appear as
#                                   static allowlist strings, not direct reads
#
# Why two sources instead of one grep:
#
#   Modern builds read almost nothing through a literal `process.env.X`. They
#   declare a typed registry once (`NAME:()=>getter`, `getter=Ve.bool()`) and
#   install it as a proxy object, so call sites read `V.NAME`. A
#   `process.env.`-only grep therefore *undercounts by hundreds* and — worse —
#   reports a variable as REMOVED when a build merely moved it behind the
#   proxy. The v2.1.197→v2.1.218 diff produced by the old single-grep method
#   claimed 126 removals; re-measured against the registry it is 7.
#
#   registry.txt      = what Claude Code itself declares (first-party surface)
#   direct_reads.txt  = literal reads, mostly vendored deps (Azure SDK, gRPC,
#                       Bun runtime, sharp, google-auth) plus a few first-party
#                       call sites that never joined the registry
#   all_vars.txt      = the union; this is the number quoted in SUMMARY.md
#
# Usage:
#   scripts/extract-binary.sh <artifact-path> <version>
#
#   artifact-path   path to the unpacked CLI file or release binary
#   version         version label (e.g. 2.1.234); output goes to
#                   extractions/<version>/
#
# Requires: strings (binutils), grep, python3. Run validate-extraction.sh after.
set -euo pipefail

# Pin C locale: byte-wise sorting and stable grep behavior across machines.
export LC_ALL=C

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

artifact="${1:-}"
version="${2:-}"
if [[ -z "$artifact" || -z "$version" ]]; then
  echo "usage: $0 <artifact-path> <version>" >&2
  exit 2
fi
if [[ ! -f "$artifact" ]]; then
  echo "ERROR: artifact not found: $artifact" >&2
  exit 1
fi

out="$ROOT/extractions/$version"
mkdir -p "$out"

# strings() over the artifact, then grep the patterns. Using `strings -n 6`
# keeps short noise out without dropping real env names (shortest tracked names
# are well above 6 chars; the pattern itself guards length).
dump() { strings -n 6 "$artifact"; }

# 1) Declared registry — name + parser type. Build-independent: the script
#    detects the minified schema-helper identifier rather than hardcoding it.
"$ROOT/scripts/extract-registry.py" "$artifact" \
  --tsv "$out/registry.tsv" --names "$out/registry.txt"
sort -u "$out/registry.tsv" -o "$out/registry.tsv"
sort -u "$out/registry.txt" -o "$out/registry.txt"
# Pre-registry builds (< ~v2.1.170) legitimately have none; don't publish two
# empty files that imply the extractor failed.
[[ -s "$out/registry.txt" ]] || rm -f "$out/registry.txt" "$out/registry.tsv"

# 2) Literal `process.env.<NAME>` reads, with Bun's string-concatenation
#    artifacts resolved from the data (see extract-direct-reads.py).
"$ROOT/scripts/extract-direct-reads.py" "$artifact" \
  --names "$out/direct_reads.txt" --artifacts "$out/concat_artifacts.txt"
sort -u "$out/direct_reads.txt" -o "$out/direct_reads.txt"
sort -u "$out/concat_artifacts.txt" -o "$out/concat_artifacts.txt"
[[ -s "$out/concat_artifacts.txt" ]] || rm -f "$out/concat_artifacts.txt"

# 3) Union. This is the published inventory.
sort -u "$out/registry.txt" "$out/direct_reads.txt" > "$out/all_vars.txt"

# 4) Focused model/provider config allowlist strings. These are static keys the
#    build compares against, not registry entries. Allowlist by prefix so we
#    capture config surface without sweeping in unrelated literals.
#    - ANTHROPIC_DEFAULT_<CODENAME>_MODEL[...]
#    - ANTHROPIC_CUSTOM_MODEL_OPTION_*
#    - DISABLE_PROMPT_CACHING_<CODENAME>
#    - VERTEX_REGION_CLAUDE_*
dump \
  | grep -oE '\b(ANTHROPIC_DEFAULT_[A-Z0-9_]*MODEL[A-Z0-9_]*|ANTHROPIC_CUSTOM_MODEL_OPTION_[A-Z0-9_]+|DISABLE_PROMPT_CACHING_[A-Z0-9_]+|VERTEX_REGION_CLAUDE_[A-Z0-9_]+)\b' \
  | sort -u > "$out/model_provider_env_strings.txt"

# 5) Hold unreleased model codenames out of the public artifacts (FLAGGED.md).
#    Config strings keyed on a codename outside the released allowlist are moved
#    to the gitignored _held/ dir and stripped from everything published, so
#    validate-extraction.sh gate (c) passes by construction instead of by hand.
PUBLIC_CODENAMES='OPUS|SONNET|HAIKU|FABLE'
held="$out/_held"
held_list="$(mktemp)"
trap 'rm -f "$held_list"' EXIT

cat "$out/all_vars.txt" "$out/model_provider_env_strings.txt" \
  | grep -E '^(ANTHROPIC_DEFAULT_[A-Z0-9_]*MODEL[A-Z0-9_]*|DISABLE_PROMPT_CACHING_[A-Z0-9_]+|VERTEX_REGION_CLAUDE_[A-Z0-9_]+)$' \
  | grep -vE "(${PUBLIC_CODENAMES})" \
  | grep -vE 'CUSTOM_MODEL|VERTEX_REGION_CLAUDE_[0-9]' \
  | sort -u > "$held_list" || true

if [[ -s "$held_list" ]]; then
  mkdir -p "$held"
  cp "$held_list" "$held/unreleased_codenames.txt"
  for f in "$out/all_vars.txt" "$out/registry.txt" "$out/model_provider_env_strings.txt"; do
    grep -vxF -f "$held_list" "$f" > "$f.pub" && mv "$f.pub" "$f"
  done
  grep -vE "^($(paste -sd'|' "$held_list"))	" "$out/registry.tsv" > "$out/registry.tsv.pub" \
    && mv "$out/registry.tsv.pub" "$out/registry.tsv"
  echo "Held $(wc -l < "$held_list" | tr -d ' ') unreleased-codename string(s) in $held/ (gitignored)" >&2
fi

echo "Wrote:" >&2
echo "  $out/registry.tsv                   ($(wc -l < "$out/registry.tsv") declared)" >&2
echo "  $out/direct_reads.txt               ($(wc -l < "$out/direct_reads.txt") literal reads)" >&2
echo "  $out/all_vars.txt                   ($(wc -l < "$out/all_vars.txt") vars)" >&2
echo "  $out/model_provider_env_strings.txt ($(wc -l < "$out/model_provider_env_strings.txt") keys)" >&2
echo >&2
echo "Next: scripts/validate-extraction.sh $version" >&2
echo "      scripts/compare-release.sh <prev> $version" >&2
