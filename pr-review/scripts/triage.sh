#!/usr/bin/env bash
# Read-only triage of the open PRs of the base repo against what has already been
# reviewed (.pr-reviews/<n>.md). Prints a prioritized list; reviews nothing.
#
#   triage.sh [owner/repo]
#
# Priority: 1 never reviewed, 2 head moved since the last review, 3 new comments
# or reviews since, 4 a pending CI check has since finished. Drafts and bot PRs
# are listed apart. Only gh reads (pr list / pr view / pr checks) are made.
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

REPO="${1:-$(base_repo)}"
mkdir -p "$PRDIR" 2>/dev/null || true

rows="$(gh pr list -R "$REPO" --state open --limit 100 \
  --json number,title,author,isDraft,headRefOid,updatedAt \
  --jq '.[] | [.number, .isDraft, (.author.login // "?"), (.author.is_bot // false), .headRefOid, .updatedAt, (.title | gsub("[\t\n\r]"; " "))] | @tsv')" ||
  die "could not list pull requests of $REPO (gh not authenticated, or offline). The last known state is in $PRDIR/*.md" 5

new="" moved="" comments="" cidone="" aside="" unchanged=0 open_slugs=" "
while IFS=$'\t' read -r num draft author bot head updated title; do
  [ -n "$num" ] || continue
  open_slugs="$open_slugs$num "
  line="#$num $title  ($author)"
  file="$PRDIR/$num.md"
  if [ "$draft" = "true" ]; then
    aside="$aside  draft: $line"$'\n'
    continue
  fi
  if [ "$bot" = "true" ] || [[ "$author" == app/* ]]; then
    aside="$aside  bot:   $line"$'\n'
    continue
  fi
  if [ ! -f "$file" ]; then
    new="$new  $line"$'\n'
    continue
  fi
  reviewed_head="$(fm_get "$file" head_reviewed)"
  reviewed_at="$(fm_get "$file" reviewed_at)"
  if [ "$reviewed_head" != "$head" ]; then
    moved="$moved  $line   [reviewed ${reviewed_head:0:8}, now ${head:0:8}]"$'\n'
    continue
  fi
  latest="$(gh pr view "$num" -R "$REPO" --json comments,reviews \
    --jq '[.comments[].createdAt, .reviews[].submittedAt] | map(select(. != null)) | max // ""' 2>/dev/null || true)"
  if [ -n "$latest" ] && [ -n "$reviewed_at" ] && [[ "$latest" > "$reviewed_at" ]]; then
    comments="$comments  $line   [activity $latest]"$'\n'
    continue
  fi
  if [ "$(fm_get "$file" ci)" = "pending" ]; then
    pending="$(gh pr checks "$num" -R "$REPO" --json state --jq '[.[] | select(.state == "PENDING" or .state == "QUEUED" or .state == "IN_PROGRESS")] | length' 2>/dev/null || echo 1)"
    if [ "$pending" = "0" ]; then
      cidone="$cidone  $line   [CI finished]"$'\n'
      continue
    fi
  fi
  unchanged=$((unchanged + 1))
done <<<"$rows"

closed=""
for f in "$PRDIR"/*.md; do
  [ -f "$f" ] || continue
  slug="$(basename "$f" .md)"
  case "$slug" in *[!0-9]*) continue ;; esac
  case "$open_slugs" in *" $slug "*) continue ;; esac
  st="$(fm_get "$f" state)"
  case "$st" in merged | closed) continue ;; esac
  closed="$closed  #$slug (tracked as '$st', no longer open)"$'\n'
done

show() { [ -z "$2" ] || { printf '%s\n%s\n' "$1" "$2"; }; }
echo "Triage for $REPO (read-only)"
echo
show "1. Never reviewed:" "$new"
show "2. Head moved since the last review:" "$moved"
show "3. New comments or reviews since the last review:" "$comments"
show "4. CI has finished since the last review:" "$cidone"
show "Tracked but no longer open (update the state, no review needed):" "$closed"
show "Drafts and bots (only reviewed if you name them):" "$aside"
[ "$unchanged" -eq 0 ] || echo "$unchanged tracked PR(s) unchanged since their last review."
[ -n "$new$moved$comments$cidone" ] || echo "Nothing needs a review."
