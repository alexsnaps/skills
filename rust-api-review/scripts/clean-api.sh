#!/usr/bin/env bash
# Drop this skill's scratch build output for a PR (the archived base/head
# trees and raw tool output) while keeping the persisted api-review.md.
#
#   clean-api.sh <pr reference>
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

parse_pr_ref "${1:-}"
require_excluded
api_paths
rm -rf -- "$API_WD"
echo "cleaned=$API_WD"
