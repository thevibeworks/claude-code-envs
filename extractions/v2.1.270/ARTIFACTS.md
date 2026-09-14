# Extraction artifacts — v2.1.270

String literals the release binary packs against adjacent data with no
separating NUL byte, so the extractor over-reads the variable name.
Repaired only where the truncated prefix is already a known variable.

- `BUN_ENVprocess` -> `BUN_ENV` (prefix is a known variable)
- `NODE_ENVContent` -> dropped (prefix `NODE_ENVC` is not a known variable; not guessed)
- `NODEwith` -> dropped (prefix `NODE` is not a known variable; not guessed)
