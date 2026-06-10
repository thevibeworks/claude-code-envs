# Flagged Items

Some configuration strings appear in a release artifact but reference model
codenames that are not part of any public Claude Code release. By default this
repository **excludes** those strings from the published artifacts and holds
them privately for a per-codename review decision.

The published artifacts (`all_vars.txt`, `model_provider_env_strings.txt`, the
diff files, and each `SUMMARY.md`) only contain configuration for **released**
model lines: `opus`, `sonnet`, `haiku`, and `fable` (Fable 5).

## Held items

The specific held strings for a release are recorded **privately** under that
version's gitignored `_held/` directory (e.g. `_held/HELD-INVENTORY.md`) and are
intentionally **not** named in this published file. Naming an unreleased
codename here would pre-announce it — exactly what this policy prevents. If you
are the maintainer, see `_held/` on your local checkout.

## Released equivalents (NOT held — published normally)

The Fable 5 line is released, so its configuration ships in the public
artifacts:

- `DISABLE_PROMPT_CACHING_FABLE`
- `ANTHROPIC_DEFAULT_FABLE_MODEL`
- `ANTHROPIC_DEFAULT_FABLE_MODEL_NAME`
- `ANTHROPIC_DEFAULT_FABLE_MODEL_DESCRIPTION`
- `ANTHROPIC_DEFAULT_FABLE_MODEL_SUPPORTED_CAPABILITIES`
- `VERTEX_REGION_CLAUDE_FABLE_5`

## How this is enforced

`scripts/validate-extraction.sh` gate (c) fails loudly and exits non-zero if any
codename outside the public allowlist (`opus`, `sonnet`, `haiku`, `fable`)
appears in a published artifact. Held evidence lives only in the gitignored
`_held/` directory, which is never published or scanned.

## Decision needed

Per codename, decide one of:

1. **Keep excluded** (current default) — leave the held string in `_held/`, out
   of public artifacts, until the codename ships.
2. **Promote** — once a codename is publicly released, add it to the allowlist
   in `scripts/validate-extraction.sh` (gate c) and re-run the extraction so the
   string flows into the public artifacts.
