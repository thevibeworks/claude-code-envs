#!/usr/bin/env python3
"""extract-direct-reads.py - literal `process.env.<NAME>` reads in a binary.

This is the *second* of the two env sources. `extract-registry.py` covers the
typed registry a modern build declares; this covers what is still read
literally at a call site — mostly vendored dependencies (Azure SDK, gRPC, Bun
runtime, sharp, google-auth) plus a few first-party sites that never joined the
registry. Pre-registry builds (< ~v2.1.170) read everything this way.

## Concatenation artifacts

Bun packs some string literals with no separating NUL byte, so a naive capture
runs past the end of the real name into the next literal:

    process.env.BUN_ENV   + process...     -> "BUN_ENVprocess"
    process.env.NODE_ENV  + Content-Type   -> "NODE_ENVContent"

Two rules recover the real name, both derived from the data rather than a
hand-maintained fix-up table:

  prefix rule  another captured name is a proper prefix of this one, and this
               one occurs exactly once  ->  keep the prefix.
               (NODE_ENVContent -> NODE_ENV: NODE_ENV is captured 16x on its
               own, NODE_ENVContent once.)

  next-literal the name ends in "process" — the opening token of the very next
  rule         `process.env.` literal, which is what the capture pattern
               guarantees follows  ->  drop that suffix.
               (BUN_ENVprocess -> BUN_ENV.)

Anything still suspicious after both rules is *not* guessed at. It is written
to concat_artifacts.txt and left out of the name list, so a wrong name never
enters the published inventory silently.

Usage:
  extract-direct-reads.py <binary> [--names out.txt] [--artifacts out.txt]
"""
import argparse
import re
import sys
from collections import Counter

READ_RE = re.compile(rb"process\.env\.([A-Za-z_][A-Za-z0-9_]*)")
NEXT_LITERAL = "process"
# A name that looks like SCREAMING_SNAKE and then grows a lowercase tail is the
# concatenation shape. Names that go lowercase after a single capital
# (ComSpec, ProgramData, VisualStudioVersion) are ordinary Windows/npm vars.
SUSPECT_RE = re.compile(r"^[A-Z][A-Z0-9_]{2,}[A-Za-z]*[a-z]")


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("binary")
    ap.add_argument("--names")
    ap.add_argument("--artifacts")
    args = ap.parse_args()

    data = open(args.binary, "rb").read()
    counts = Counter(m.group(1).decode() for m in READ_RE.finditer(data))
    names = set(counts)

    resolved, artifacts = set(), []
    for name in sorted(counts):
        if not SUSPECT_RE.match(name):
            resolved.add(name)
            continue

        # prefix rule: longest captured proper prefix wins, but only for a
        # name seen once (a name read 16 times is not an artifact).
        prefix = None
        if counts[name] == 1:
            cands = [p for p in names if p != name and name.startswith(p)]
            if cands:
                prefix = max(cands, key=len)

        # next-literal rule
        if prefix is None and name.endswith(NEXT_LITERAL):
            cut = name[: -len(NEXT_LITERAL)]
            if cut and (cut[-1] == "_" or cut[-1].isupper()):
                prefix = cut

        if prefix:
            print(f"  concatenation artifact: {name} -> {prefix}", file=sys.stderr)
            resolved.add(prefix)
        else:
            print(f"  unresolved concatenation artifact (excluded): {name}", file=sys.stderr)
            artifacts.append(name)

    out = sorted(resolved)
    print(f"direct reads      : {len(out)} "
          f"({len(artifacts)} unresolved artifact(s) excluded)", file=sys.stderr)

    if args.names:
        with open(args.names, "w") as f:
            f.write("".join(n + "\n" for n in out))
    if args.artifacts:
        with open(args.artifacts, "w") as f:
            f.write("".join(n + "\n" for n in sorted(artifacts)))
    if not args.names:
        print("\n".join(out))
    return 0


if __name__ == "__main__":
    sys.exit(main())
