#!/usr/bin/env bash
# Does every commit of the PR build? CI only builds the PR head, so a commit that
# breaks the build in the middle of the series (and breaks bisecting) goes unnoticed.
#
#   check-commits.sh <pr reference> [--max N] [--cmd "<command>"] [--approved]
#
# Each commit is exported with `git archive` into .pr-reviews/<slug>/commits/<sha>/
# (read-only on your repo: no checkout, so the applied PR diff is untouched) and the
# command runs there. All exports share one CARGO_TARGET_DIR (.pr-reviews/target) so
# dependencies compile once. Merge commits are skipped.
#
# This builds the contributor's code: it goes through exec_guard (exit 22 for build/
# config files unless --approved). Above --max commits (default 20) it stops with
# exit 21 so the maintainer can decide. Prints "<sha> ok|FAIL <subject>" per commit.
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

parse_pr_ref "${1:-}"
shift || true
MAX=20
CMD="cargo check --workspace --all-targets --all-features"
APPROVED=no
while [ $# -gt 0 ]; do
  case "$1" in
    --max) MAX="${2:?--max needs a number}"; shift ;;
    --cmd) CMD="${2:?--cmd needs a command}"; shift ;;
    --approved) APPROVED=yes ;;
    *) die "unknown option: $1" 2 ;;
  esac
  shift
done

require_excluded
load_pr_refs
exec_guard "$APPROVED"

mapfile -t COMMITS < <(git rev-list --reverse --no-merges "$MB..$HEAD_SHA")
[ "${#COMMITS[@]}" -gt 0 ] || die "no commits between the merge-base and the PR head" 9
if [ "${#COMMITS[@]}" -gt "$MAX" ]; then
  die "${#COMMITS[@]} commits is above the limit of $MAX: ask the maintainer (re-run with --max ${#COMMITS[@]}) or check only some" 21
fi

WD="$PRDIR/$SLUG"
rm -rf -- "$WD/commits"
mkdir -p "$WD/commits"
export CARGO_TARGET_DIR="$PRDIR/target"

failed=0
for sha in "${COMMITS[@]}"; do
  short="${sha:0:8}"
  dir="$WD/commits/$short"
  mkdir -p "$dir"
  git archive "$sha" | tar -x -C "$dir"
  subject="$(git log -1 --format=%s "$sha")"
  if (cd "$dir" && bash -c "$CMD") >"$dir.log" 2>&1; then
    echo "$short ok    $subject"
  else
    failed=$((failed + 1))
    echo "$short FAIL  $subject"
    grep -m6 -E '^(error|warning: unused)' -A2 "$dir.log" | sed 's/^/        /' || true
  fi
done
echo "checked=${#COMMITS[@]} failed=$failed command=$CMD"
