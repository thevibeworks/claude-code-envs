#!/usr/bin/env bash
# validate-extraction.sh — gate an extraction before it can be published.
#
# Usage:
#   scripts/validate-extraction.sh <version>
#
# Checks extractions/<version>/. Exits non-zero on any failure so CI can block.
#
# Gates:
#   (a) LC_ALL=C pinned for sort AND comm  — guards against locale-driven
#       phantom diffs (the #1 footgun: UTF-8 locale produced 57/47 instead of
#       the true 55/45). This script exports LC_ALL=C and verifies every
#       *.txt is already byte-sorted-unique under it.
#   (b) secrets / home-path gate           — no sk-..., Bearer ..., refreshToken,
#       /Users/, /home/, PRIVATE KEY anywhere in the tracked artifacts.
#   (c) unreleased-codename gate           — public codename allowlist is
#       opus|sonnet|haiku|fable-5. Any other (unreleased) codename fails loudly.
#       Held evidence lives only in the gitignored _held/ dir (never scanned).
#   (d) SUMMARY counts match raw line counts.
#   (e) sorted-unique (every *.txt).
#   (f) file-size cap (no artifact may balloon).
set -euo pipefail

# Gate (a): pin C locale for ALL sort/comm in this process.
export LC_ALL=C

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

version="${1:-}"
[[ -n "$version" ]] || { echo "usage: $0 <version>" >&2; exit 2; }

dir="$ROOT/extractions/$version"
[[ -d "$dir" ]] || { echo "ERROR: no extraction dir: $dir" >&2; exit 1; }

# Held unreleased-codename evidence lives in the gitignored _held/ dir; it is
# never published and is excluded from every gate below.
HELD_DIR="$dir/_held"

fail=0
note() { printf '  %s\n' "$*"; }
gate_fail() { printf 'FAIL [%s] %s\n' "$1" "$2" >&2; fail=1; }
gate_ok()   { printf 'ok   [%s] %s\n' "$1" "$2"; }

# Size cap: no single tracked artifact should exceed this. Extractions are a few
# hundred short lines; a megabyte means something captured noise or a binary.
MAX_BYTES=1048576  # 1 MiB

# ---------------------------------------------------------------------------
# (e) sorted-unique + (f) size cap, over every *.txt
# ---------------------------------------------------------------------------
for f in "$dir"/*.txt; do
  [[ -e "$f" ]] || continue
  base="$(basename "$f")"

  # (f) size cap
  sz="$(wc -c < "$f" | tr -d ' ')"
  if (( sz > MAX_BYTES )); then
    gate_fail f "$base is ${sz} bytes (> ${MAX_BYTES})"
  fi

  # (e) sorted-unique under LC_ALL=C
  if ! diff -q "$f" <(sort -u "$f") >/dev/null; then
    gate_fail e "$base is not LC_ALL=C sort -u"
    note "first divergence:"
    diff "$f" <(sort -u "$f") | head -5 >&2 || true
  else
    gate_ok e "$base sorted-unique"
  fi
done

# ---------------------------------------------------------------------------
# (b) secrets / home-path gate
# ---------------------------------------------------------------------------
# Patterns that must never appear in any tracked artifact.
SECRET_RE='sk-[A-Za-z0-9_-]{8,}|Bearer[[:space:]]+[A-Za-z0-9._-]{8,}|refreshToken|-----BEGIN[[:space:]].*PRIVATE KEY-----|/Users/|/home/'
if grep -rEnI --exclude-dir=_held "$SECRET_RE" "$dir" >/dev/null 2>&1; then
  gate_fail b "secret or home-path pattern present:"
  grep -rEnI --exclude-dir=_held "$SECRET_RE" "$dir" >&2 || true
else
  gate_ok b "no secrets / home paths"
fi

# ---------------------------------------------------------------------------
# (c) unreleased-codename gate
# ---------------------------------------------------------------------------
# Released model codenames are public. Anything matching a *_MODEL / VERTEX /
# DISABLE_PROMPT_CACHING / CUSTOM_MODEL config string whose codename is NOT in
# the allowlist is treated as unreleased and must not ship publicly.
#
# Allowlist codenames: opus, sonnet, haiku, fable (fable-5). The CUSTOM_MODEL
# and numeric VERTEX_REGION strings carry no codename and are always allowed.
PUBLIC_CODENAMES='OPUS|SONNET|HAIKU|FABLE'

# Scan every tracked file EXCEPT the flagged hold file. Look at config-shaped
# tokens and reject any codename token not in the allowlist.
codename_hits=""
for f in "$dir"/*.txt "$dir"/*.md; do
  [[ -e "$f" ]] || continue
  # Pull config keys, drop the allowed ones, see what remains.
  hit="$(grep -oE '(ANTHROPIC_DEFAULT_[A-Z0-9_]*MODEL[A-Z0-9_]*|DISABLE_PROMPT_CACHING_[A-Z0-9_]+|VERTEX_REGION_CLAUDE_[A-Z0-9_]+)' "$f" 2>/dev/null \
      | grep -vE "(${PUBLIC_CODENAMES})" \
      | grep -vE 'CUSTOM_MODEL|VERTEX_REGION_CLAUDE_[0-9]' || true)"
  if [[ -n "$hit" ]]; then
    codename_hits+="$f:"$'\n'"$hit"$'\n'
  fi
done
if [[ -n "$codename_hits" ]]; then
  gate_fail c "unreleased codename in public artifact (allowlist: opus/sonnet/haiku/fable-5):"
  printf '%s' "$codename_hits" >&2
else
  gate_ok c "no unreleased codenames in public artifacts"
fi

# If held evidence exists (gitignored, not public), report it informationally.
if [[ -d "$HELD_DIR" ]]; then
  note "held (gitignored, not public): $(find "$HELD_DIR" -type f | wc -l | tr -d ' ') file(s) in _held/"
fi

# ---------------------------------------------------------------------------
# (d) SUMMARY counts match raw line counts
# ---------------------------------------------------------------------------
summary="$dir/SUMMARY.md"
if [[ -f "$summary" ]]; then
  total_raw="$(sort -u "$dir/all_vars.txt" | wc -l | tr -d ' ')"
  # Total vars (`all_vars.txt`) | N
  total_doc="$(grep -oE 'Total vars[^|]*\|[[:space:]]*[0-9]+' "$summary" | grep -oE '[0-9]+$' || true)"
  if [[ -n "$total_doc" ]]; then
    if [[ "$total_doc" == "$total_raw" ]]; then
      gate_ok d "SUMMARY total=$total_doc matches all_vars.txt"
    else
      gate_fail d "SUMMARY total=$total_doc != all_vars.txt=$total_raw"
    fi
  fi

  # Added / Removed, if the SUMMARY references a prior version diff.
  prev="$(grep -oE 'new_vs_[0-9.]+\.txt' "$summary" | head -1 | sed -E 's/new_vs_([0-9.]+)\.txt/\1/' || true)"
  if [[ -n "$prev" && -f "$dir/new_vs_${prev}.txt" ]]; then
    added_raw="$(wc -l < "$dir/new_vs_${prev}.txt" | tr -d ' ')"
    removed_raw="$(wc -l < "$dir/removed_vs_${prev}.txt" | tr -d ' ')"
    added_doc="$(grep -oE '\| Added \|[[:space:]]*[0-9]+' "$summary" | grep -oE '[0-9]+$' || true)"
    removed_doc="$(grep -oE '\| Removed \|[[:space:]]*[0-9]+' "$summary" | grep -oE '[0-9]+$' || true)"
    [[ -z "$added_doc"   || "$added_doc"   == "$added_raw"   ]] || gate_fail d "SUMMARY added=$added_doc != new_vs_${prev}.txt=$added_raw"
    [[ -z "$removed_doc" || "$removed_doc" == "$removed_raw" ]] || gate_fail d "SUMMARY removed=$removed_doc != removed_vs_${prev}.txt=$removed_raw"
    [[ "$fail" -eq 0 ]] && gate_ok d "SUMMARY diff counts match (+${added_raw}/-${removed_raw} vs $prev)"
  fi
else
  note "no SUMMARY.md (skipping gate d)"
fi

echo
if [[ "$fail" -ne 0 ]]; then
  echo "VALIDATION FAILED for $version" >&2
  exit 1
fi
echo "VALIDATION PASSED for $version"
