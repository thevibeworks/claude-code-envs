# Extraction artifacts — v2.1.226

String literals the release binary packs against adjacent data with no
separating NUL byte, so the extractor over-reads the variable name.
Repaired only where the truncated prefix is already a known variable.

- `BUN_ENVprocess` -> `BUN_ENV` (prefix is a known variable)
- `NODE_ENVsec` -> `NODE_ENV` (prefix is a known variable)
- `NODEreams` -> dropped (prefix `NODE` is not a known variable; not guessed)
