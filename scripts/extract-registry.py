#!/usr/bin/env python3
"""extract-registry.py - read Claude Code's declared environment-variable
registry out of a release binary.

Since v2.1.2xx the bundle no longer reads `process.env.X` at each call site.
It builds a typed proxy object once:

    Ve = {str:..., bool:..., triBool:..., int:..., enum:...}
    var NS={}; yt(NS,{CLAUDE_CODE_FOO:()=>gFoo, ...});
    var gFoo; ...  gFoo = Ve.bool()
    V = LTs({...NS1, ...NS2, ...}, proto)   // V.CLAUDE_CODE_FOO reads process.env

So the authoritative inventory is the set of keys in those `yt(NS,{...})`
namespace blocks whose getter is assigned a `Ve.<parser>()` schema. That set is
name-complete AND typed, and it does not depend on how any individual call site
happens to be minified.

Method (no hardcoded minified identifiers):
  1. Find every `<ident> = <helper>.<parser>(<arg>)` assignment and pick the
     `<helper>` that accounts for the most of them. That is `Ve`.
  2. Collect every `NAME:()=><ident>` export pair in the binary.
  3. Keep the pairs whose `<ident>` has a `Ve.<parser>` schema.

Output is `LC_ALL=C`-sortable TSV: name, type, arg, getter.

Usage: extract-registry.py <binary> [--tsv out.tsv] [--names out.txt] [--json]
"""
import argparse
import json
import re
import sys
from collections import Counter

PARSERS = ("str", "bool", "triBool", "int", "enum", "num")
SCHEMA_RE = re.compile(
    r"([A-Za-z0-9_$]+)=([A-Za-z0-9_$]{1,4})\.(" + "|".join(PARSERS) + r")\(([^()]*(?:\([^()]*\))?[^()]*)\)"
)
EXPORT_RE = re.compile(r"([A-Za-z_][A-Za-z0-9_]*):\(\)=>([A-Za-z0-9_$]+)")

# A real registry declares hundreds of schemas. Anything below this is noise
# from a pre-registry build (see the guard in main()).
MIN_SCHEMA_ASSIGNMENTS = 50


def main() -> int:
    ap = argparse.ArgumentParser()
    ap.add_argument("binary")
    ap.add_argument("--tsv")
    ap.add_argument("--names")
    ap.add_argument("--json", action="store_true")
    args = ap.parse_args()

    data = open(args.binary, "rb").read().decode("latin-1")

    schemas = list(SCHEMA_RE.finditer(data))
    helper, helper_n = (
        Counter(m.group(2) for m in schemas).most_common(1)[0] if schemas else ("", 0)
    )

    # Builds before ~v2.1.170 have no typed env registry — every read is a
    # literal `process.env.X`. There the winning "helper" is a handful of
    # coincidental matches, not the env schema. Refuse to report those as a
    # registry; emit an empty one so the caller falls back to direct reads.
    if helper_n < MIN_SCHEMA_ASSIGNMENTS:
        print(
            f"no env registry in this build "
            f"(best helper candidate {helper or '-'} has only {helper_n} "
            f"assignments, need >= {MIN_SCHEMA_ASSIGNMENTS})",
            file=sys.stderr,
        )
        for path in (args.tsv, args.names):
            if path:
                open(path, "w").close()
        if args.json:
            print("[]")
        return 0

    typed = {}
    for m in schemas:
        if m.group(2) != helper:
            continue
        typed[m.group(1)] = (m.group(3), m.group(4))

    rows = {}
    for m in EXPORT_RE.finditer(data):
        name, getter = m.group(1), m.group(2)
        if getter in typed and name not in rows:
            rows[name] = (typed[getter][0], typed[getter][1], getter)

    out = [
        {"name": n, "type": rows[n][0], "arg": rows[n][1], "getter": rows[n][2]}
        for n in sorted(rows)
    ]

    print(f"env schema helper : {helper} ({helper_n} schema assignments)", file=sys.stderr)
    print(f"typed getters     : {len(typed)}", file=sys.stderr)
    print(f"registry names    : {len(out)}", file=sys.stderr)
    print("  by type         : " + ", ".join(
        f"{k}={v}" for k, v in sorted(Counter(r['type'] for r in out).items())), file=sys.stderr)

    if args.tsv:
        with open(args.tsv, "w") as f:
            for r in out:
                f.write(f"{r['name']}\t{r['type']}\t{r['arg']}\n")
    if args.names:
        with open(args.names, "w") as f:
            for r in out:
                f.write(r["name"] + "\n")
    if args.json:
        json.dump(out, sys.stdout, indent=1)
        print()
    return 0


if __name__ == "__main__":
    sys.exit(main())
