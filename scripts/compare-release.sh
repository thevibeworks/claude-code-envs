#!/usr/bin/env bash
# compare-release.sh — diff two extractions and write the added/removed lists.
#
# Usage:
#   scripts/compare-release.sh <prev-version> <version>
#
# Reads:
#   extractions/<prev>/all_vars.txt
#   extractions/<version>/all_vars.txt
#
# Writes (into extractions/<version>/):
#   new_vs_<prev>.txt       vars present in <version> but not <prev>
#   removed_vs_<prev>.txt   vars present in <prev> but not <version>
#
# Both inputs are re-sorted with `LC_ALL=C sort -u` before comm, and comm runs
# under LC_ALL=C. This is mandatory: an ambient UTF-8 locale makes comm and sort
# disagree on byte order and fabricate phantom added/removed lines.
set -euo pipefail

export LC_ALL=C

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

prev="${1:-}"
version="${2:-}"
if [[ -z "$prev" || -z "$version" ]]; then
  echo "usage: $0 <prev-version> <version>" >&2
  exit 2
fi

prev_file="$ROOT/extractions/$prev/all_vars.txt"
cur_file="$ROOT/extractions/$version/all_vars.txt"
for f in "$prev_file" "$cur_file"; do
  [[ -f "$f" ]] || { echo "ERROR: missing $f" >&2; exit 1; }
done

out="$ROOT/extractions/$version"
new_file="$out/new_vs_${prev}.txt"
removed_file="$out/removed_vs_${prev}.txt"

prev_sorted="$(mktemp)"; cur_sorted="$(mktemp)"
trap 'rm -f "$prev_sorted" "$cur_sorted"' EXIT
sort -u "$prev_file" > "$prev_sorted"
sort -u "$cur_file"  > "$cur_sorted"

# comm -13: lines only in cur (added). comm -23: lines only in prev (removed).
comm -13 "$prev_sorted" "$cur_sorted" > "$new_file"
comm -23 "$prev_sorted" "$cur_sorted" > "$removed_file"

echo "Compared $prev -> $version" >&2
echo "  added:   $(wc -l < "$new_file")  ($new_file)" >&2
echo "  removed: $(wc -l < "$removed_file")  ($removed_file)" >&2
