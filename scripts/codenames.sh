#!/usr/bin/env bash
# codenames.sh — the single source of truth for the public-codename policy.
#
# Sourced by:
#   hold-unreleased.sh      moves non-allowlisted strings out of the public
#                           artifacts and into the gitignored _held/ dir
#   validate-extraction.sh  gate (c): fails if any slipped through
#
# Keeping one definition here is the point. When the two drifted apart the
# hold step and the gate disagreed about what "released" meant, and the
# pipeline failed every week instead of publishing.
#
# To promote a codename once it ships publicly: add it to PUBLIC_CODENAMES,
# re-run the extraction, and the held strings flow into the public artifacts.

# Released model lines. Anything else is treated as unreleased and held.
PUBLIC_CODENAMES='OPUS|SONNET|HAIKU|FABLE'

# Config-shaped tokens that can carry a codename.
CODENAME_TOKEN_RE='(ANTHROPIC_DEFAULT_[A-Z0-9_]*MODEL[A-Z0-9_]*|DISABLE_PROMPT_CACHING_[A-Z0-9_]+|VERTEX_REGION_CLAUDE_[A-Z0-9_]+)'

# Tokens that match the shape above but carry no codename, so they always ship:
#   ANTHROPIC_CUSTOM_MODEL_OPTION_*     user-supplied model slot
#   VERTEX_REGION_CLAUDE_<digit>...     numbered lines (e.g. 3_5_SONNET, 4_0_OPUS)
CODENAME_EXEMPT_RE='CUSTOM_MODEL|VERTEX_REGION_CLAUDE_[0-9]'

# held_tokens <file> — print every token in <file> that must not ship publicly.
# Empty output (exit 0) means the file is clean.
held_tokens() {
  grep -oE "$CODENAME_TOKEN_RE" "$1" 2>/dev/null \
    | grep -vE "($PUBLIC_CODENAMES)" \
    | grep -vE "$CODENAME_EXEMPT_RE" \
    | sort -u || true
}
