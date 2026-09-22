#!/usr/bin/env bash
# Fetch a pull request's head and its base branch into private refs and print what
# the review needs, as key=value lines.
#
#   fetch-pr.sh <number | owner/repo#number | pull request URL>
#
# Finds the remote by matching the PR's repository URL against your remotes (never
# by name), so it works for the base repo and for any fork you have a remote for.
# Fetches refs/pull/<n>/head from that repo (no need to add a contributor's fork,
# and it survives the fork being deleted) into refs/pr-reviews/<slug>/head.
# GitHub is only read (gh pr view). Exit 4: no remote for that repo.
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

parse_pr_ref "${1:-}"
require_excluded

REMOTE="$(remote_for_repo "$PR_REPO")"
[ -n "$REMOTE" ] ||
  die "no remote points at $PR_REPO. Add one yourself, e.g.: git remote add <name> git@github.com:$PR_REPO.git" 4

meta="$(gh pr view "$PR_NUM" -R "$PR_REPO" \
  --json number,title,author,state,isDraft,baseRefName,headRefOid,url,changedFiles,additions,deletions \
  --jq '"pr_title=\(.title | gsub("[\n\r\t]"; " "))\npr_author=\(.author.login)\npr_author_is_bot=\(.author.is_bot)\npr_state=\(.state)\npr_draft=\(.isDraft)\nbase_ref=\(.baseRefName)\ngh_head_sha=\(.headRefOid)\npr_url=\(.url)\nchanged_files=\(.changedFiles)\nadditions=\(.additions)\ndeletions=\(.deletions)"')" ||
  die "could not read $PR_REPO#$PR_NUM from GitHub (gh not authenticated, offline, or no such PR)" 5

pr_title="" pr_author="" pr_author_is_bot="" pr_state="" pr_draft="" base_ref="" gh_head_sha="" pr_url=""
changed_files="" additions="" deletions=""
while IFS='=' read -r k v; do
  case "$k" in
    pr_title) pr_title="$v" ;;
    pr_author) pr_author="$v" ;;
    pr_author_is_bot) pr_author_is_bot="$v" ;;
    pr_state) pr_state="$v" ;;
    pr_draft) pr_draft="$v" ;;
    base_ref) base_ref="$v" ;;
    gh_head_sha) gh_head_sha="$v" ;;
    pr_url) pr_url="$v" ;;
    changed_files) changed_files="$v" ;;
    additions) additions="$v" ;;
    deletions) deletions="$v" ;;
  esac
done <<<"$meta"

HEADREF="refs/pr-reviews/$SLUG/head"
BASEREF="refs/pr-reviews/$SLUG/base"
git fetch --quiet --no-tags "$REMOTE" "+refs/pull/$PR_NUM/head:$HEADREF" ||
  die "could not fetch refs/pull/$PR_NUM/head from remote '$REMOTE'" 5
git fetch --quiet --no-tags "$REMOTE" "+refs/heads/$base_ref:$BASEREF" ||
  die "could not fetch base branch '$base_ref' from remote '$REMOTE'" 5

head_sha="$(git rev-parse "$HEADREF")"
merge_base="$(git merge-base "$HEADREF" "$BASEREF")" || die "no merge base between the PR head and $base_ref" 5
[ "$head_sha" = "$gh_head_sha" ] || info "warning: fetched head $head_sha differs from GitHub's $gh_head_sha (a push landed meanwhile?)"

reviewed="$(git rev-parse -q --verify "refs/pr-reviews/$SLUG/reviewed^{commit}" 2>/dev/null || true)"
tracking="$PRDIR/$SLUG.md"
repo_name="${PR_REPO#*/}"
profile="$SKILL_DIR/profiles/$repo_name.md"
[ -f "$profile" ] || profile="none"

echo "repo=$PR_REPO"
echo "remote=$REMOTE"
echo "slug=$SLUG"
echo "pr_number=$PR_NUM"
echo "pr_url=$pr_url"
echo "pr_title=$pr_title"
echo "pr_author=$pr_author"
echo "pr_author_is_bot=$pr_author_is_bot"
echo "pr_state=$pr_state"
echo "pr_draft=$pr_draft"
echo "base_ref=$base_ref"
echo "head_sha=$head_sha"
echo "merge_base=$merge_base"
echo "commit_count=$(git rev-list --count "$merge_base..$head_sha")"
echo "changed_files=$changed_files"
echo "additions=$additions"
echo "deletions=$deletions"
echo "last_reviewed_sha=$reviewed"
echo "head_moved=$([ -n "$reviewed" ] && [ "$reviewed" != "$head_sha" ] && echo yes || echo no)"
echo "tracking_file=$tracking"
echo "tracking_exists=$([ -f "$tracking" ] && echo yes || echo no)"
echo "profile=$profile"
