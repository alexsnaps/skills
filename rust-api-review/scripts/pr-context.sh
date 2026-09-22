#!/usr/bin/env bash
# Justification evidence for the challenge step: PR body, linked issues, and
# the commit series -- one read-only gh call plus git log on the refs
# pr-review already fetched. Never fetches the PR itself.
#
#   pr-context.sh <pr reference>
#
# Prints the PR body and linked issues as markdown, then one line per commit.
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

parse_pr_ref "${1:-}"
load_pr_refs
require_excluded

gh pr view "$PR_NUM" -R "$PR_REPO" \
  --json body,closingIssuesReferences \
  --jq '"## PR body\n\n\(.body // "(empty)")\n\n## Linked issues\n" + ((.closingIssuesReferences // []) | map("- #\(.number) \(.title)") | join("\n"))' ||
  die "could not read the PR body from GitHub (gh not authenticated, offline, or no such PR)" 5

echo
echo "## Commits ($MB..$HEAD_SHA)"
git log --no-merges --format='- %h %s' "$MB..$HEAD_SHA"
