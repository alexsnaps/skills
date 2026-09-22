#!/usr/bin/env bash
# Put the pull request's diff into YOUR checkout so you can review it in your editor:
# detach at the PR's merge-base and apply the PR's net diff UNSTAGED (nothing is
# staged or committed, so the editor's git gutter shows the whole PR in context).
#
#   apply-pr.sh <pr reference>        (run fetch-pr.sh first)
#
# Refuses (and changes nothing) when:
#   6  another PR is still applied          -> reset-pr.sh first
#   7  the tree has tracked modifications, staged changes, or a merge/rebase/
#      cherry-pick in progress
#   8  an untracked file is in the way of a file the PR adds
#   9  the PR has no diff against its merge-base
#   10/11  the switch or the apply failed (you are put back where you were)
# It records where you were in .pr-reviews/<slug>/restore.env so reset-pr.sh can
# bring you back. It never stashes, stages, commits, or resets.
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

parse_pr_ref "${1:-}"
require_excluded
HEADREF="refs/pr-reviews/$SLUG/head"
BASEREF="refs/pr-reviews/$SLUG/base"
git rev-parse -q --verify "$HEADREF^{commit}" >/dev/null || die "run fetch-pr.sh first" 5
HEAD_SHA="$(git rev-parse "$HEADREF")"
MB="$(git merge-base "$HEADREF" "$BASEREF")"
WD="$PRDIR/$SLUG"
ACTIVE="$PRDIR/.active"

if [ -f "$ACTIVE" ]; then
  die "PR $(cat "$ACTIVE") is still applied to this checkout; run scripts/reset-pr.sh first" 6
fi

for f in MERGE_HEAD CHERRY_PICK_HEAD REVERT_HEAD REBASE_HEAD; do
  if git rev-parse -q --verify "$f" >/dev/null 2>&1; then die "a $f operation is in progress; finish or abort it first" 7; fi
done
for d in rebase-merge rebase-apply; do
  if [ -d "$(git rev-parse --path-format=absolute --git-path "$d")" ]; then die "a rebase is in progress; finish or abort it first" 7; fi
done

DIRTY="$(git status --porcelain --untracked-files=no)"
if [ -n "$DIRTY" ]; then
  echo "$DIRTY" >&2
  die "the working tree has modified or staged tracked files (listed above). Commit or set them aside yourself; I will not stash or touch them" 7
fi

COLLIDE=""
while IFS= read -r p; do
  [ -n "$p" ] || continue
  if { [ -e "$ROOT/$p" ] || [ -L "$ROOT/$p" ]; } && ! git ls-files --error-unmatch -- "$p" >/dev/null 2>&1; then
    COLLIDE="$COLLIDE$p"$'\n'
  fi
done < <(git diff --no-renames --name-only --diff-filter=A "$MB" "$HEAD_SHA")
if [ -n "$COLLIDE" ]; then
  printf '%s' "$COLLIDE" >&2
  die "these untracked files are in the way of files the PR adds (listed above)" 8
fi

mkdir -p "$WD"
git diff --binary --full-index --no-renames "$MB" "$HEAD_SHA" >"$WD/pr.patch"
[ -s "$WD/pr.patch" ] || die "the PR has no diff against its merge-base ($MB); already merged?" 9

RESTORE_REF="$(git symbolic-ref -q --short HEAD || true)"
RESTORE_SHA="$(git rev-parse HEAD)"
{
  echo "SLUG=$SLUG"
  echo "REPO=$PR_REPO"
  echo "PR=$PR_NUM"
  echo "RESTORE_REF=$RESTORE_REF"
  echo "RESTORE_SHA=$RESTORE_SHA"
  echo "MERGE_BASE=$MB"
  echo "PR_HEAD=$HEAD_SHA"
} >"$WD/restore.env"
echo "$SLUG" >"$ACTIVE"

back() {
  if [ -n "$RESTORE_REF" ]; then git switch --quiet "$RESTORE_REF"; else git switch --quiet --detach "$RESTORE_SHA"; fi
}
rollback_state() {
  rm -f "$ACTIVE" "$WD/restore.env"
}

if ! git switch --quiet --detach "$MB"; then
  rollback_state
  die "could not switch to the merge-base $MB; nothing was changed" 10
fi
if ! git apply --binary --whitespace=nowarn "$WD/pr.patch"; then
  back
  rollback_state
  die "the diff did not apply at the merge-base; you are back on ${RESTORE_REF:-$RESTORE_SHA}" 11
fi

echo "applied=$SLUG"
echo "detached_at=$MB"
echo "files_touched=$(git diff --no-renames --name-only "$MB" "$HEAD_SHA" | wc -l | tr -d ' ')"
echo "way_back=scripts/reset-pr.sh $SLUG   # returns to ${RESTORE_REF:-detached}@${RESTORE_SHA:0:12}"
