#!/usr/bin/env bash
# Shared helpers for rust-api-review. Sourced, never run directly.
#
# Hard dependency: pr-review must be installed. parse_pr_ref, load_pr_refs,
# exec_guard, require_excluded and the .pr-reviews/ layout all come from ITS
# scripts/lib.sh -- never re-implemented here. Every script here still runs
# from inside the target repo, same assumption as pr-review's own scripts.
set -euo pipefail

_find_pr_review_dir() {
  local here candidates=() c
  [ -n "${PR_REVIEW_DIR:-}" ] && candidates+=("$PR_REVIEW_DIR")
  here="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/.." && pwd)"
  candidates+=("$here/../pr-review" "$HOME/src/Claude/pr-review")
  for c in "${candidates[@]}"; do
    [ -f "$c/scripts/lib.sh" ] && { printf '%s' "$c"; return 0; }
  done
  return 1
}

PR_REVIEW_DIR="$(_find_pr_review_dir)" || {
  echo "rust-api-review: pr-review not found (checked \$PR_REVIEW_DIR, ../pr-review, ~/src/Claude/pr-review)." >&2
  echo "rust-api-review: this skill hard-depends on pr-review's scripts/lib.sh; there is no fallback." >&2
  exit 2
}
# shellcheck source=/dev/null
source "$PR_REVIEW_DIR/scripts/lib.sh"

# Redefine under this skill's own name for anything printed from here on.
die() { echo "rust-api-review: $1" >&2; exit "${2:-1}"; }
info() { echo "rust-api-review: $*" >&2; }

SKILL_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/.." && pwd)"

# Call after parse_pr_ref. Sets API_WD (this skill's scratch dir for the PR)
# and OUTFILE (the markdown file this skill owns), nested under pr-review's
# own per-PR directory so its cleanup/reset boundary still makes sense.
api_paths() {
  API_WD="$PRDIR/$SLUG/api-review"
  OUTFILE="$PRDIR/$SLUG/api-review.md"
}
