#!/usr/bin/env bash
# Shared helpers for the pr-review scripts. Sourced, never run directly.
#
# What these scripts may write: .pr-reviews/**, refs/pr-reviews/**, the
# .git/info/exclude file, and (apply-pr.sh / reset-pr.sh only) the working tree.
# They never commit, push, stash, stage, or write to GitHub. Run
# check-no-writes.sh to lint that.
set -euo pipefail

die() {
  echo "pr-review: $1" >&2
  exit "${2:-1}"
}
info() { echo "pr-review: $*" >&2; }

ROOT="$(git rev-parse --show-toplevel 2>/dev/null)" || die "not inside a git repository" 2
PRDIR="$ROOT/.pr-reviews"
SKILL_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"

lower() { printf '%s' "$1" | tr '[:upper:]' '[:lower:]'; }

# git URL -> lowercase "owner/repo" (GitHub only)
url_to_repo() {
  local u="$1"
  u="${u%/}"
  u="${u%.git}"
  case "$u" in
    git@github.com:*) u="${u#git@github.com:}" ;;
    ssh://git@github.com/*) u="${u#ssh://git@github.com/}" ;;
    https://*@github.com/*) u="${u#*@github.com/}" ;;
    http://github.com/* | https://github.com/*) u="${u#*://github.com/}" ;;
    *) return 1 ;;
  esac
  lower "$u"
}

# Name of the remote whose fetch URL points at owner/repo. Prefers origin, then
# upstream, then any other remote. Empty output if none matches.
remote_for_repo() {
  local want r u got found=""
  want="$(lower "$1")"
  for r in origin upstream $(git remote); do
    git remote get-url "$r" >/dev/null 2>&1 || continue
    u="$(git remote get-url "$r")"
    got="$(url_to_repo "$u" 2>/dev/null || true)"
    if [ "$got" = "$want" ]; then
      found="$r"
      break
    fi
  done
  printf '%s' "$found"
}

# The repository PRs are opened against: origin, else upstream. When that
# remote is a fork, its parent. Cached in .pr-reviews/.base-repo.
base_repo() {
  local cache="$PRDIR/.base-repo" cand="" r u parent
  if [ -s "$cache" ]; then
    cat "$cache"
    return
  fi
  for r in origin upstream; do
    if git remote get-url "$r" >/dev/null 2>&1; then
      u="$(git remote get-url "$r")"
      cand="$(url_to_repo "$u" 2>/dev/null || true)"
      [ -n "$cand" ] && break
    fi
  done
  [ -n "$cand" ] || die "no origin/upstream remote on GitHub; pass a full pull request URL" 4
  parent="$(gh repo view "$cand" --json isFork,parent --jq 'if .isFork then (.parent.owner.login + "/" + .parent.name) else empty end' 2>/dev/null || true)"
  [ -n "$parent" ] && cand="$(lower "$parent")"
  if [ -d "$PRDIR" ]; then printf '%s\n' "$cand" >"$cache"; fi
  printf '%s\n' "$cand"
}

# parse_pr_ref <number | #number | owner/repo#number | pull request URL>
# sets PR_REPO (lowercase owner/repo), PR_NUM, SLUG (<n> for the base repo,
# <owner>-<repo>-<n> for any other repo)
parse_pr_ref() {
  local ref="${1:-}"
  [ -n "$ref" ] || die "missing pull request reference (number, owner/repo#n, or URL)" 2
  case "$ref" in
    http*://github.com/*/pull/*)
      PR_REPO="$(lower "$(echo "$ref" | sed -E 's#^https?://github.com/([^/]+/[^/]+)/pull/.*#\1#')")"
      PR_NUM="$(echo "$ref" | sed -E 's#^https?://github.com/[^/]+/[^/]+/pull/([0-9]+).*#\1#')"
      ;;
    */*#*)
      PR_REPO="$(lower "${ref%%#*}")"
      PR_NUM="${ref##*#}"
      ;;
    *)
      PR_NUM="${ref#\#}"
      PR_REPO=""
      ;;
  esac
  case "$PR_NUM" in '' | *[!0-9]*) die "not a pull request reference: $ref" 2 ;; esac
  [ -n "$PR_REPO" ] || PR_REPO="$(base_repo)"
  if [ "$PR_REPO" = "$(base_repo)" ]; then
    SLUG="$PR_NUM"
  else
    SLUG="$(echo "$PR_REPO" | tr '/' '-')-$PR_NUM"
  fi
}

# Refuse to write drafts anywhere git would track them.
require_excluded() {
  git check-ignore -q -- "$PRDIR/.probe" ||
    die ".pr-reviews/ is not ignored by git; run scripts/ensure-excluded.sh first" 3
}

# fm_get <tracking-file> <key>: a value from the YAML front matter
fm_get() {
  [ -f "$1" ] || return 0
  awk -v k="$2" '
    /^---[ \t]*$/ { c++; next }
    c == 1 { i = index($0, ":"); if (i > 0 && substr($0, 1, i - 1) == k) { v = substr($0, i + 1); sub(/^[ \t]+/, "", v); gsub(/^"|"$/, "", v); print v; exit } }
    c >= 2 { exit }
  ' "$1"
}

# load_pr_refs: sets HEADREF, BASEREF, HEAD_SHA and MB for the parsed PR (SLUG)
load_pr_refs() {
  HEADREF="refs/pr-reviews/$SLUG/head"
  BASEREF="refs/pr-reviews/$SLUG/base"
  git rev-parse -q --verify "$HEADREF^{commit}" >/dev/null || die "run fetch-pr.sh first" 5
  HEAD_SHA="$(git rev-parse "$HEADREF")"
  MB="$(git merge-base "$HEADREF" "$BASEREF")"
}

# Files that run code at build time or configure how builds run. Building a PR that
# changes them executes the contributor's code, so it needs the maintainer's go-ahead.
GUARDED_ERE='(^|/)(build\.rs|Cargo\.toml|Cargo\.lock|rust-toolchain(\.toml)?|Makefile|justfile)$|^\.github/|(^|/)\.cargo/'

# exec_guard <approved: yes|no>
# Call before running anything that builds or tests the PR's code. Refuses (exit 22)
# when the PR touches a guarded file unless the maintainer approved (--approved).
# A profile can add patterns, one extended regex per line, in profiles/<repo>.guard.
exec_guard() {
  local approved="${1:-no}" hits extra
  hits="$(git diff --no-renames --name-only "$MB" "$HEAD_SHA" | grep -E "$GUARDED_ERE" || true)"
  extra="$SKILL_DIR/profiles/${PR_REPO#*/}.guard"
  if [ -f "$extra" ]; then
    hits="$hits"$'\n'"$(git diff --no-renames --name-only "$MB" "$HEAD_SHA" | grep -E -f "$extra" || true)"
  fi
  hits="$(printf '%s\n' "$hits" | sed '/^$/d' | sort -u)"
  if [ -n "$hits" ] && [ "$approved" != yes ]; then
    printf '%s\n' "$hits" >&2
    die "the PR touches files that run or configure builds (listed above). Executing its code needs the maintainer's go-ahead: ask, then re-run with --approved" 22
  fi
}
