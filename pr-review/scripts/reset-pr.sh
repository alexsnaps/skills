#!/usr/bin/env bash
# Undo apply-pr.sh: remove the applied PR diff and switch back to where you were.
#
#   reset-pr.sh [<pr reference>]      (no argument: the PR that is currently applied)
#
# Only discards the PR's diff, and only when the working tree still equals the PR
# on every file it touches. If you edited any of those files, or changed anything
# else that is tracked, it refuses and lists them (exit 12/13) and changes nothing.
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

ACTIVE="$PRDIR/.active"
if [ -n "${1:-}" ]; then
  parse_pr_ref "$1"
else
  [ -f "$ACTIVE" ] || die "no PR is applied to this checkout" 12
  SLUG="$(cat "$ACTIVE")"
fi
WD="$PRDIR/$SLUG"
[ -f "$WD/restore.env" ] || die "no restore point for $SLUG (was it applied here?)" 12

RESTORE_REF="" RESTORE_SHA="" MERGE_BASE="" PR_HEAD=""
while IFS='=' read -r k v; do
  case "$k" in
    RESTORE_REF) RESTORE_REF="$v" ;;
    RESTORE_SHA) RESTORE_SHA="$v" ;;
    MERGE_BASE) MERGE_BASE="$v" ;;
    PR_HEAD) PR_HEAD="$v" ;;
  esac
done <"$WD/restore.env"

[ "$(git rev-parse HEAD)" = "$MERGE_BASE" ] ||
  die "HEAD is not at the PR's merge-base any more (you moved it); not resetting. Restore point was ${RESTORE_REF:-detached}@${RESTORE_SHA:0:12}" 12

# 1. anything tracked that is not part of the applied PR, or staged? refuse.
TOUCHED="$(git diff --no-renames --name-only "$MERGE_BASE" "$PR_HEAD")"
is_touched() {
  printf '%s\n' "$TOUCHED" | grep -Fxq -- "$1"
}
EXTRA=""
while IFS= read -r line; do
  [ -n "$line" ] || continue
  idx="${line:0:1}"
  path="${line:3}"
  if [ "$idx" != " " ] || ! is_touched "$path"; then EXTRA="$EXTRA$line"$'\n'; fi
done < <(git status --porcelain --untracked-files=no)

# 2. every touched file must still be exactly what the PR has
EDITED=""
while IFS=$'\t' read -r st path; do
  [ -n "$path" ] || continue
  case "$st" in
    D) [ ! -e "$ROOT/$path" ] || EDITED="$EDITED$path (should be deleted)"$'\n' ;;
    *)
      if [ ! -f "$ROOT/$path" ] || [ "$(git hash-object -- "$ROOT/$path")" != "$(git rev-parse "$PR_HEAD:$path")" ]; then
        EDITED="$EDITED$path"$'\n'
      fi
      ;;
  esac
done < <(git diff --no-renames --name-status "$MERGE_BASE" "$PR_HEAD")

if [ -n "$EXTRA$EDITED" ]; then
  [ -z "$EXTRA" ] || {
    echo "tracked changes outside the applied PR:" >&2
    printf '%s' "$EXTRA" >&2
  }
  [ -z "$EDITED" ] || {
    echo "files that no longer match the applied PR:" >&2
    printf '%s' "$EDITED" >&2
  }
  die "refusing to discard your changes; deal with the files above, then run this again" 13
fi

git apply -R --binary --whitespace=nowarn "$WD/pr.patch" ||
  die "could not reverse the applied diff; nothing was switched" 13
[ -z "$(git status --porcelain --untracked-files=no)" ] || info "warning: the tree is not clean after reversing the diff"

if [ -n "$RESTORE_REF" ]; then
  git rev-parse -q --verify "refs/heads/$RESTORE_REF" >/dev/null ||
    die "the branch '$RESTORE_REF' no longer exists. The diff is removed; you are detached at the merge-base. Your old HEAD was $RESTORE_SHA" 14
  git switch --quiet "$RESTORE_REF"
  TIP="$(git rev-parse HEAD)"
  [ "$TIP" = "$RESTORE_SHA" ] || info "note: '$RESTORE_REF' moved since ($RESTORE_SHA -> $TIP)"
else
  git switch --quiet --detach "$RESTORE_SHA"
fi

rm -f "$ACTIVE" "$WD/restore.env"
echo "reset=$SLUG"
echo "back_on=${RESTORE_REF:-detached}@$(git rev-parse --short=12 HEAD)"
