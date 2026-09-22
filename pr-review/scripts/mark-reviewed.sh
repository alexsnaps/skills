#!/usr/bin/env bash
# Record that the PR's current fetched head has been reviewed, so the next round
# is incremental (range-diff since this SHA). Only moves a private ref.
#
#   mark-reviewed.sh <pr reference>
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

parse_pr_ref "${1:-}"
HEAD_SHA="$(git rev-parse -q --verify "refs/pr-reviews/$SLUG/head^{commit}")" ||
  die "nothing fetched for $SLUG; run fetch-pr.sh first" 5
git update-ref "refs/pr-reviews/$SLUG/reviewed" "$HEAD_SHA"
echo "reviewed=$HEAD_SHA"
