#!/usr/bin/env bash
# fetch-release.sh — download a published Claude Code release artifact and
# record a sha512 integrity manifest. NEVER commits the artifact itself.
#
# Usage:
#   scripts/fetch-release.sh [version]
#
#   version   exact npm version (e.g. 2.1.170). If omitted, resolves the
#             current `latest` dist-tag.
#
# Output (under build/<version>/, which is gitignored):
#   *.tgz                 the packed artifact (do not commit)
#   integrity.txt         sha512 + size + resolved version
#
# Requires: npm, shasum (or sha512sum).
set -euo pipefail

PKG="@anthropic-ai/claude-code"
ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

version="${1:-}"
if [[ -z "$version" ]]; then
  echo "Resolving '$PKG' dist-tags..." >&2
  npm view "$PKG" dist-tags --json
  version="$(npm view "${PKG}@latest" version)"
  echo "latest = $version" >&2
fi

out="$ROOT/build/$version"
mkdir -p "$out"

echo "Packing ${PKG}@${version}..." >&2
# npm pack writes the tarball into $out and prints its filename.
tarball="$(cd "$out" && npm pack "${PKG}@${version}" --silent)"
tarball_path="$out/$tarball"

if [[ ! -f "$tarball_path" ]]; then
  echo "ERROR: expected tarball not found at $tarball_path" >&2
  exit 1
fi

# Compute sha512 portably.
if command -v sha512sum >/dev/null 2>&1; then
  digest="$(sha512sum "$tarball_path" | awk '{print $1}')"
else
  digest="$(shasum -a 512 "$tarball_path" | awk '{print $1}')"
fi
size="$(wc -c < "$tarball_path" | tr -d ' ')"

manifest="$out/integrity.txt"
{
  echo "package    $PKG"
  echo "version    $version"
  echo "tarball    $tarball"
  echo "size       $size"
  echo "sha512     $digest"
} > "$manifest"

echo "Wrote integrity manifest: $manifest" >&2
cat "$manifest"
echo >&2
echo "Reminder: build/ is gitignored. Do not commit the tarball or any" >&2
echo "extracted binary. Only text extractions under extractions/ are tracked." >&2
