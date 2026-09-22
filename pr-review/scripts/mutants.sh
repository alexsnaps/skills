#!/usr/bin/env bash
# Mutation testing scoped to the lines a PR changes (cargo-mutants --in-diff).
#
#   mutants.sh count  <pr reference>                       how many mutants the diff has
#   mutants.sh run    <pr reference> [--over-limit] [--approved] [-j N]   run them, detached, in the background
#   mutants.sh status <pr reference>                       progress / results / missed mutants
#
# The PR must be applied to this checkout (apply-pr.sh), because --in-diff selects
# mutants by line number in the current tree. cargo-mutants mutates a COPY of the tree
# in a temp directory; this script never passes --in-place, so your checkout is never
# mutated. Results land in .pr-reviews/<slug>/mutants/ and a status file, so a later
# invocation (even in a new session) can read them.
#
# The count is compared with a limit (300 by default: about 15 CPU-minutes at ~3s per
# mutant on cel-rust). Above it, `run` stops with exit 21 unless --over-limit is given:
# the maintainer decides whether to run, narrow, or skip.
# Exit 20: cargo-mutants is not installed (report "mutation skipped: tool missing").
# Exit 22: the PR touches build/config files; pass --approved only after the maintainer agrees.
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

MODE="${1:-}"
shift || true
[ -n "$MODE" ] || die "usage: mutants.sh count|run|status <pr reference> [--over-limit] [--approved] [-j N]" 2
parse_pr_ref "${1:-}"
shift || true
LIMIT="${PR_REVIEW_MUTANT_LIMIT:-300}"
JOBS="${PR_REVIEW_MUTANT_JOBS:-4}"
OVER=no
APPROVED=no
while [ $# -gt 0 ]; do
  case "$1" in
    --over-limit) OVER=yes ;;
    --approved) APPROVED=yes ;;
    -j) JOBS="${2:?-j needs a number}"; shift ;;
    *) die "unknown option: $1" 2 ;;
  esac
  shift
done

require_excluded
WD="$PRDIR/$SLUG"
# a profile may add cargo-mutants arguments, one per line (profiles/<repo>.mutants-args)
EXTRA=()
args_file="$SKILL_DIR/profiles/${PR_REPO#*/}.mutants-args"
if [ -f "$args_file" ]; then
  while IFS= read -r a; do
    case "$a" in '' | \#*) continue ;; esac
    EXTRA+=("$a")
  done <"$args_file"
fi
STATUS="$WD/mutants.status"
OUT="$WD/mutants"

if [ "$MODE" = status ]; then
  [ -f "$STATUS" ] || die "no mutation run recorded for $SLUG" 1
  cat "$STATUS"
  res="$OUT/mutants.out"
  if [ -d "$res" ]; then
    for k in caught missed unviable timeout; do
      [ -f "$res/$k.txt" ] && echo "$k=$(wc -l <"$res/$k.txt" | tr -d ' ')"
    done
    if [ -s "$res/missed.txt" ]; then
      echo "--- missed mutants (each is behaviour no test pins down):"
      cat "$res/missed.txt"
    fi
  fi
  exit 0
fi

command -v cargo-mutants >/dev/null 2>&1 || die "cargo-mutants is not installed: mutation testing skipped" 20
[ -f "$PRDIR/.active" ] && [ "$(cat "$PRDIR/.active")" = "$SLUG" ] ||
  die "$SLUG is not the applied PR; run apply-pr.sh first (--in-diff needs the PR's tree)" 6
[ -s "$WD/pr.patch" ] || die "no $WD/pr.patch; run apply-pr.sh first" 6
load_pr_refs

COUNT="$(cd "$ROOT" && cargo mutants --in-diff "$WD/pr.patch" --list --no-shuffle "${EXTRA[@]}" 2>/dev/null | grep -c . || true)"
echo "count=$COUNT"
echo "limit=$LIMIT"
[ "$MODE" = count ] && exit 0
[ "$MODE" = run ] || die "unknown mode: $MODE" 2

[ "$MODE" = run ] && exec_guard "$APPROVED"
if [ "$COUNT" -eq 0 ]; then
  printf 'state=none\ncount=0\nnote=no mutants on the changed lines (docs, tests, or generated code only)\n' >"$STATUS"
  echo "state=none"
  exit 0
fi
if [ "$COUNT" -gt "$LIMIT" ] && [ "$OVER" != yes ]; then
  die "$COUNT mutants is above the limit of $LIMIT: ask the maintainer to run all (--over-limit), narrow the scope, or skip" 21
fi

mkdir -p "$OUT"
printf 'state=running\ncount=%s\njobs=%s\nstarted=%s\n' "$COUNT" "$JOBS" "$(date -u +%FT%TZ)" >"$STATUS"
(
  cd "$ROOT"
  # cargo-mutants exits non-zero when mutants are missed or time out: that is a result, not a failure
  rc=0
  cargo mutants --in-diff "$WD/pr.patch" --output "$OUT" -j "$JOBS" \
    --timeout-multiplier 2 --minimum-test-timeout 30 --no-shuffle "${EXTRA[@]}" >"$WD/mutants.log" 2>&1 || rc=$?
  printf 'state=done\ncount=%s\njobs=%s\nexit_code=%s\nfinished=%s\n' "$COUNT" "$JOBS" "$rc" "$(date -u +%FT%TZ)" >"$STATUS"
) </dev/null >/dev/null 2>&1 &
disown
echo "state=running"
echo "results=$OUT/mutants.out   log=$WD/mutants.log   status: scripts/mutants.sh status $SLUG"
