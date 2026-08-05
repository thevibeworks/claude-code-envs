#!/usr/bin/env bash
# normalize-artifacts.sh — repair string-concatenation artifacts in an extraction.
#
# Usage:
#   scripts/normalize-artifacts.sh <version> [prev-version]
#
# The release binary packs some `process.env.<NAME>` literals directly against
# unrelated strings with no separating NUL byte, so the extractor's regex runs
# past the end of the real name:
#
#   process.env.BUN_ENV + "process..."  ->  BUN_ENVprocess
#   process.env.NODE_ENV + "sec..."     ->  NODE_ENVsec
#
# v2.1.218 was repaired by hand ("Corrected to BUN_ENV and ... removed the
# duplicate before computing counts" — see its SUMMARY.md). That repair was
# never part of the pipeline, so the first fully automated extraction published
# BUN_ENVprocess, NODE_ENVsec and NODEreams as if they were real variables, and
# lost the real BUN_ENV entirely.
#
# Detection must not touch the legitimately mixed-case Windows variables
# (ProgramData, SystemRoot, ConEmuANSI, VisualStudioVersion, ...). Those start
# with a SINGLE capital before lowercase. A concatenation artifact always has an
# UPPER_SNAKE run of at least two characters butted straight against lowercase:
#
#   ^[A-Z][A-Z0-9_]*[A-Z0-9][a-z]
#
# Repair is conservative. The truncated prefix is accepted only when it is
# already a known variable — present elsewhere in this extraction or in the
# previous one. Anything else is reported as unresolved and dropped rather than
# guessed at, because publishing a fabricated variable name is worse than
# omitting a broken literal. Every decision is recorded in ARTIFACTS.md.
set -euo pipefail

export LC_ALL=C

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

version="${1:-}"
prev="${2:-}"
[[ -n "$version" ]] || { echo "usage: $0 <version> [prev-version]" >&2; exit 2; }

dir="$ROOT/extractions/$version"
[[ -d "$dir" ]] || { echo "ERROR: no extraction dir: $dir" >&2; exit 1; }

vars="$dir/all_vars.txt"
[[ -f "$vars" ]] || { echo "ERROR: no all_vars.txt in $dir" >&2; exit 1; }

ARTIFACT_RE='^[A-Z][A-Z0-9_]*[A-Z0-9][a-z]'

suspects="$(grep -E "$ARTIFACT_RE" "$vars" || true)"
if [[ -z "$suspects" ]]; then
  echo "normalize: no concatenation artifacts in $version" >&2
  exit 0
fi

# Known-good names: everything non-suspect here, plus the previous extraction.
known="$(mktemp)"; repaired="$(mktemp)"
trap 'rm -f "$known" "$repaired"' EXIT
grep -vE "$ARTIFACT_RE" "$vars" > "$known"
if [[ -n "$prev" && -f "$ROOT/extractions/$prev/all_vars.txt" ]]; then
  cat "$ROOT/extractions/$prev/all_vars.txt" >> "$known"
fi
sort -u -o "$known" "$known"

report="$dir/ARTIFACTS.md"
{
  echo "# Extraction artifacts — $version"
  echo
  echo "String literals the release binary packs against adjacent data with no"
  echo "separating NUL byte, so the extractor over-reads the variable name."
  echo "Repaired only where the truncated prefix is already a known variable."
  echo
} > "$report"

n_fix=0; n_drop=0
while IFS= read -r token; do
  [[ -n "$token" ]] || continue
  prefix="$(sed -E 's/^([A-Z][A-Z0-9_]*[A-Z0-9])[a-z].*$/\1/' <<< "$token")"
  if grep -qx "$prefix" "$known"; then
    printf -- '- `%s` -> `%s` (prefix is a known variable)\n' "$token" "$prefix" >> "$report"
    echo "$prefix" >> "$repaired"
    n_fix=$((n_fix + 1))
  else
    printf -- '- `%s` -> dropped (prefix `%s` is not a known variable; not guessed)\n' "$token" "$prefix" >> "$report"
    n_drop=$((n_drop + 1))
  fi
done <<< "$suspects"

# Rebuild: non-suspect names plus accepted repairs, sorted-unique.
{ grep -vE "$ARTIFACT_RE" "$vars"; cat "$repaired" 2>/dev/null || true; } | sort -u > "$vars.tmp"
mv "$vars.tmp" "$vars"

echo "normalize: repaired $n_fix, dropped $n_drop -> $report" >&2
sed -n '/^- /p' "$report" >&2
