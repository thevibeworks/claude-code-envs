#!/usr/bin/env bash
# extract-binary.sh — document the environment variables referenced by a
# Claude Code release artifact, by reading the string literals the build
# leaves in its constant pool.
#
# Two outputs, both `LC_ALL=C sort -u`:
#   all_vars.txt                    every `process.env.<NAME>` read
#   model_provider_env_strings.txt  model/provider config keys that appear as
#                                   static allowlist strings, not direct reads
#
# Usage:
#   scripts/extract-binary.sh <artifact-path> <version>
#
#   artifact-path   path to the unpacked CLI file or release binary
#   version         version label (e.g. 2.1.170); output goes to
#                   extractions/<version>/
#
# Requires: strings (binutils), grep. Run validate-extraction.sh afterward.
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

# strings() over the artifact, then grep the two patterns. Using `strings -n 6`
# keeps short noise out without dropping real env names (shortest tracked names
# are well above 6 chars; the pattern itself guards length).
dump() { strings -n 6 "$artifact"; }

# 1) process.env.<NAME> reads. NAME = [A-Za-z_][A-Za-z0-9_]*
dump \
  | grep -oE 'process\.env\.[A-Za-z_][A-Za-z0-9_]*' \
  | sed 's/^process\.env\.//' \
  | sort -u > "$out/all_vars.txt"

# 2) Focused model/provider config allowlist strings. These are static keys the
#    build compares against, not `process.env` reads. Allowlist by prefix so we
#    capture config surface without sweeping in unrelated literals.
#    - ANTHROPIC_DEFAULT_<CODENAME>_MODEL[...]
#    - ANTHROPIC_CUSTOM_MODEL_OPTION_*
#    - DISABLE_PROMPT_CACHING_<CODENAME>
#    - VERTEX_REGION_CLAUDE_*
dump \
  | grep -oE '\b(ANTHROPIC_DEFAULT_[A-Z0-9_]*MODEL[A-Z0-9_]*|ANTHROPIC_CUSTOM_MODEL_OPTION_[A-Z0-9_]+|DISABLE_PROMPT_CACHING_[A-Z0-9_]+|VERTEX_REGION_CLAUDE_[A-Z0-9_]+)\b' \
  | sort -u > "$out/model_provider_env_strings.txt"

echo "Wrote:" >&2
echo "  $out/all_vars.txt                   ($(wc -l < "$out/all_vars.txt") vars)" >&2
echo "  $out/model_provider_env_strings.txt ($(wc -l < "$out/model_provider_env_strings.txt") keys)" >&2
echo >&2
echo "Next: scripts/validate-extraction.sh $version" >&2
echo "      scripts/compare-release.sh <prev> $version" >&2
