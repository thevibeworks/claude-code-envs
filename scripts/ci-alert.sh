#!/usr/bin/env bash
# ci-alert.sh — make a failing scheduled run impossible to miss.
#
# Usage:
#   scripts/ci-alert.sh open <run-id>   # called on failure
#   scripts/ci-alert.sh close           # called on success
#
# This workflow runs weekly and failed eight weeks in a row without anyone
# noticing: a red scheduled run produces no artifact and no notification, so
# silence looks exactly like success. The tripwire is a single tracking issue
# labelled `ci-failure` — opened on the first failure, commented on for each
# subsequent one, and closed automatically by the next green run.
#
# Deliberately bounded at one open issue. Dedup uses the REST issue list
# filtered by label, never the search API: search indexing lags writes by
# minutes, which is how a sibling repo once filed byte-identical duplicates
# 13 seconds apart.
#
# Adds no secrets — uses the built-in GITHUB_TOKEN via GH_TOKEN.
set -euo pipefail

REPO="${GITHUB_REPOSITORY:?GITHUB_REPOSITORY not set}"
LABEL="ci-failure"
TITLE="deterministic-extract is failing"

action="${1:-}"

existing() {
  gh api "repos/$REPO/issues?state=open&labels=$LABEL&per_page=1" -q '.[0].number // empty'
}

case "$action" in
  open)
    run_id="${2:?usage: $0 open <run-id>}"
    run_url="https://github.com/$REPO/actions/runs/$run_id"
    num="$(existing)"
    if [[ -n "$num" ]]; then
      gh api "repos/$REPO/issues/$num/comments" -f body="Still failing: $run_url" >/dev/null
      echo "ci-alert: commented on existing #$num" >&2
    else
      # Ensure the label exists; ignore "already exists".
      gh api "repos/$REPO/labels" -f name="$LABEL" -f color=b60205 \
        -f description="Scheduled extraction run is red" >/dev/null 2>&1 || true
      num="$(gh api "repos/$REPO/issues" -f title="$TITLE" -f "labels[]=$LABEL" \
        -f body="The weekly \`deterministic-extract\` run failed.

Failing run: $run_url

This issue closes automatically on the next green run. If it stays open, the
repository is not documenting new releases." -q .number)"
      echo "ci-alert: opened #$num" >&2
    fi
    ;;
  close)
    num="$(existing)"
    if [[ -n "$num" ]]; then
      gh api -X PATCH "repos/$REPO/issues/$num" -f state=closed -f state_reason=completed >/dev/null
      echo "ci-alert: closed #$num (run is green again)" >&2
    else
      echo "ci-alert: nothing to close" >&2
    fi
    ;;
  *)
    echo "usage: $0 open <run-id> | close" >&2
    exit 2
    ;;
esac
