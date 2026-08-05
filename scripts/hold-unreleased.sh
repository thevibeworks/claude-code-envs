#!/usr/bin/env bash
# hold-unreleased.sh — enforce the FLAGGED.md hold policy.
#
# Usage:
#   scripts/hold-unreleased.sh <version>
#
# Moves every config string carrying an unreleased model codename out of the
# published artifacts in extractions/<version>/ and into that version's
# gitignored _held/ directory.
#
# This is the step that makes the policy real. FLAGGED.md has always described
# holding unreleased codenames, and validate-extraction.sh gate (c) has always
# checked for them — but nothing performed the move, so gate (c) fired on every
# release that introduced a new codename and the weekly run failed instead of
# publishing. Gate (c) is the safety net; this script is the mechanism.
#
# Idempotent: running twice over the same directory is a no-op the second time.
# Run after extract-binary.sh and before compare-release.sh, so the diffs are
# computed from already-held artifacts and the counts stay consistent.
set -euo pipefail

export LC_ALL=C

ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
# shellcheck source=scripts/codenames.sh
source "$ROOT/scripts/codenames.sh"

version="${1:-}"
[[ -n "$version" ]] || { echo "usage: $0 <version>" >&2; exit 2; }

dir="$ROOT/extractions/$version"
[[ -d "$dir" ]] || { echo "ERROR: no extraction dir: $dir" >&2; exit 1; }

held_dir="$dir/_held"
inventory="$held_dir/HELD-INVENTORY.md"

# Collect the union of held tokens across every published artifact.
all_held="$(mktemp)"
trap 'rm -f "$all_held"' EXIT
: > "$all_held"
for f in "$dir"/*.txt; do
  [[ -e "$f" ]] || continue
  held_tokens "$f" >> "$all_held"
done
sort -u -o "$all_held" "$all_held"

if [[ ! -s "$all_held" ]]; then
  echo "hold: nothing to hold for $version (all codenames are public)" >&2
  exit 0
fi

mkdir -p "$held_dir"

{
  echo "# Held items — $version"
  echo
  echo "Config strings withheld from the published artifacts because they"
  echo "carry a model codename outside the public allowlist"
  echo "(\`${PUBLIC_CODENAMES//|/\`, \`}\`)."
  echo
  echo "This directory is gitignored and never published. See FLAGGED.md for"
  echo "the policy and the promote/keep-excluded decision."
  echo
  echo "## Tokens"
  echo
} > "$inventory"

# Remove each held token from every published artifact, recording where it was
# found. Artifacts are one token per line, so an exact line match is correct —
# a substring match would also strike released siblings that share a prefix.
count=0
while IFS= read -r token; do
  [[ -n "$token" ]] || continue
  found_in=()
  for f in "$dir"/*.txt; do
    [[ -e "$f" ]] || continue
    if grep -qxF "$token" "$f"; then
      found_in+=("$(basename "$f")")
      grep -vxF "$token" "$f" > "$f.tmp" && mv "$f.tmp" "$f"
    fi
  done
  joined="$(printf '%s, ' "${found_in[@]}" | sed 's/, $//')"
  printf -- '- `%s` — removed from: %s\n' "$token" "$joined" >> "$inventory"
  count=$((count + 1))
done < "$all_held"

echo "hold: withheld $count token(s) for $version -> $inventory" >&2
sed -n '/^## Tokens/,$p' "$inventory" | tail -n +3 >&2
