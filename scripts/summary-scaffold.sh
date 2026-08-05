#!/usr/bin/env bash
# summary-scaffold.sh — write the mechanical half of extractions/<version>/SUMMARY.md.
#
# Usage:
#   scripts/summary-scaffold.sh <prev-version> <version>
#
# SUMMARY.md is an editorial document: the "Notable Additions"/"Notable
# Removals" sections carry judgment about what a diff means, and nothing can
# generate those. But its counts table is pure arithmetic, and gate (d) of
# validate-extraction.sh checks the table against the raw files — so when CI
# never wrote a SUMMARY.md at all, gate (d) silently skipped on every run and
# the PR pointed reviewers at a file that did not exist.
#
# This writes the mechanical scaffold (header, counts, held note, pointers) and
# marks where the editorial passes go. Never overwrites an existing SUMMARY.md.
set -euo pipefail

export LC_ALL=C

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

prev="${1:-}"
version="${2:-}"
if [[ -z "$prev" || -z "$version" ]]; then
  echo "usage: $0 <prev-version> <version>" >&2
  exit 2
fi

dir="$ROOT/extractions/$version"
[[ -d "$dir" ]] || { echo "ERROR: no extraction dir: $dir" >&2; exit 1; }

summary="$dir/SUMMARY.md"
if [[ -f "$summary" ]]; then
  echo "summary: $summary already exists; leaving it alone" >&2
  exit 0
fi

prev_bare="${prev#v}"
ver_bare="${version#v}"
new_file="$dir/new_vs_${prev_bare}.txt"
removed_file="$dir/removed_vs_${prev_bare}.txt"
for f in "$new_file" "$removed_file"; do
  [[ -f "$f" ]] || { echo "ERROR: missing $f (run compare-release.sh first)" >&2; exit 1; }
done

total="$(sort -u "$dir/all_vars.txt" | wc -l | tr -d ' ')"
added="$(wc -l < "$new_file" | tr -d ' ')"
removed="$(wc -l < "$removed_file" | tr -d ' ')"

{
  echo "# Claude Code Environment Variables — $version"
  echo
  echo "Source: \`@anthropic-ai/claude-code-linux-x64@${ver_bare}\`, documented from"
  echo "string literals in the published release artifact."
  echo
  echo "- \`all_vars.txt\` — \`process.env.<NAME>\` reads, \`LC_ALL=C sort -u\`."
  echo "- \`model_provider_env_strings.txt\` — model/provider configuration keys that"
  echo "  appear as static allowlist strings rather than direct \`process.env\` reads."
  echo
  echo "## Counts (vs $prev)"
  echo
  echo "| Metric | Value |"
  echo "|--------|-------|"
  echo "| Total vars (\`all_vars.txt\`) | $total |"
  echo "| Added | $added |"
  echo "| Removed | $removed |"
  echo
  echo "See \`new_vs_${prev_bare}.txt\` and \`removed_vs_${prev_bare}.txt\` for the full diff."
  echo
  echo "## Notable Additions"
  echo
  echo "<!-- TODO(review): group the $added added vars by theme and say what changed. -->"
  echo
  echo "## Notable Removals"
  echo
  echo "<!-- TODO(review): group the $removed removed vars by theme and say what changed. -->"

  if [[ -d "$dir/_held" ]]; then
    n="$(grep -c '^- `' "$dir/_held/HELD-INVENTORY.md" 2>/dev/null || echo 0)"
    echo
    echo "> Note: $n configuration string(s) referencing an unreleased model codename"
    echo "> were held out of the public artifacts. See \`_held/\` (private, gitignored)"
    echo "> and the top-level \`FLAGGED.md\`."
  fi
} > "$summary"

echo "summary: wrote scaffold $summary (total=$total added=$added removed=$removed)" >&2
