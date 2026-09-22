#!/usr/bin/env bash
# Guardrail: fail if any pr-review script contains a command that could write to
# GitHub, git history, your index/stash/config, or the network.
#
#   check-no-writes.sh              lint scripts/*.sh and profiles/**/*.sh
#   check-no-writes.sh --self-test  prove the rules catch what they should (and only that)
#
# Allowed on purpose: git fetch (refs/pr-reviews only), git switch, git apply (without
# --index), git update-ref on refs/pr-reviews/*, git archive, gh read commands
# (pr view|list|checks|diff, run view, repo view, api GET), rm -f of known files, and
# rm -rf of paths under "$WD/" or "$PRDIR/".
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SELF="$(basename "${BASH_SOURCE[0]}")"
B='(^|[^[:alnum:]_-])' # what may precede a command word
# `git` followed by up to four options, each with an optional value (git -C dir -c k=v ...)
GIT="${B}git[[:space:]]+(-[^[:space:]]+[[:space:]]+([^-[:space:]][^[:space:]]*[[:space:]]+)?){0,4}"

# name|extended regex
RULES=(
  "git history/index/stash/config write|${GIT}(commit|push|stash|add|reset|rebase|merge|cherry-pick|revert|am|tag|clean|checkout|restore|rm|mv|pull|worktree|config|gc|prune)([[:space:]]|$)"
  "git remote/branch write|${GIT}(remote[[:space:]]+(add|set-url|remove|rm|rename)|branch[[:space:]]+(-[dDmMcC]|--delete|--move|--copy))"
  "git apply that stages|${GIT}apply[^|;&]*(--index|--cached|--3way|[[:space:]]-3)"
  "gh write verb|${B}gh[[:space:]]+(pr[[:space:]]+(comment|review|merge|edit|close|reopen|ready|create|checkout|lock|unlock|update-branch)|issue|label|release|workflow|run[[:space:]]+(rerun|cancel|delete)|repo[[:space:]]+(edit|delete|fork|create|sync|rename|archive)|secret|variable|ruleset|auth|extension|alias|config)([[:space:]]|$)"
  "gh api with a method or fields|${B}gh[[:space:]]+api[^|;&]*([[:space:]]-X|--method|[[:space:]]-f[[:space:]]|[[:space:]]-F[[:space:]]|--field|--raw-field|--input)"
  "network tool|${B}(curl|wget|scp|rsync|ssh|nc|ncat|telnet|ftp|sftp)[[:space:]]"
  "mutation in place|--in-place"
  "sudo/eval|${B}(sudo|eval)[[:space:]]"
)
RM_RECURSIVE="${B}rm[[:space:]]+-[a-zA-Z]*[rR]"

# scan <file> [label]: prints violations, returns 1 if any
scan() {
  local file="$1" label="${2:-$1}" n=0 bad=0 line raw rule name re
  while IFS= read -r raw || [ -n "$raw" ]; do
    n=$((n + 1))
    line="${raw#"${raw%%[![:space:]]*}"}"
    [ -n "$line" ] || continue
    case "$line" in \#*) continue ;; esac
    # a plain message (echo/die/info/printf with no command chaining) may mention a command
    if [[ "$line" =~ ^(echo|die|info|printf)[[:space:]] ]] && ! [[ "$line" =~ [\;\&\|\`] ]] && [[ "$line" != *'$('* ]]; then
      continue
    fi
    for rule in "${RULES[@]}"; do
      name="${rule%%|*}"
      re="${rule#*|}"
      if [[ "$line" =~ $re ]]; then
        echo "$label:$n: [$name] $line"
        bad=1
      fi
    done
    if [[ "$line" =~ $RM_RECURSIVE ]] && [[ "$line" != *'"$WD/'* ]] && [[ "$line" != *'"$PRDIR/'* ]]; then
      echo "$label:$n: [recursive rm outside .pr-reviews] $line"
      bad=1
    fi
    if [[ "$line" == *update-ref* ]] && [[ "$line" != *refs/pr-reviews/* ]]; then
      echo "$label:$n: [update-ref outside refs/pr-reviews] $line"
      bad=1
    fi
  done <"$file"
  return $bad
}

if [ "${1:-}" = "--self-test" ]; then
  tmp="$(mktemp)"
  trap 'rm -f "$tmp"' EXIT
  fail=0
  expect_flagged() {
    printf '%s\n' "$1" >"$tmp"
    if scan "$tmp" >/dev/null; then echo "self-test FAILED: not flagged: $1"; fail=1; fi
  }
  expect_clean() {
    printf '%s\n' "$1" >"$tmp"
    if ! scan "$tmp" >/dev/null; then echo "self-test FAILED: wrongly flagged: $1"; fail=1; fi
  }
  for bad in \
    'git commit -m x' 'git push origin main' 'git stash' 'git add -A' 'git reset --hard' 'git rebase main' \
    'git checkout -- .' 'git restore .' 'git -C x commit' 'git config user.name x' 'git worktree add x' \
    'git remote add fork url' 'git branch -D x' 'git apply --index p' 'git apply -3 p' \
    'gh pr comment 1 -b x' 'gh pr review 1 --approve' 'gh pr merge 1' 'gh pr edit 1' 'gh pr close 1' \
    'gh issue create' 'gh label create x' 'gh workflow run x' 'gh run rerun 1' 'gh api -X POST /x' \
    'gh api repos/x --method PATCH' 'gh api repos/x -f a=b' 'curl https://x' 'ssh host' \
    'cargo mutants --in-place' 'rm -rf /tmp/x' 'rm -rf "$HOME"' 'git update-ref refs/heads/main abc' \
    'true && git commit -m x' 'echo hi; git push' \
    'git --no-pager commit -m x' 'git -c user.name=x commit -m y' 'git -C /tmp/r -c a=b push' \
    'git -C x remote add a b' 'git -C x apply --index p' 'git -C x -c y=z stash'; do
    expect_flagged "$bad"
  done
  for good in \
    'git fetch --quiet origin +refs/pull/1/head:refs/pr-reviews/1/head' 'git switch --detach abc' \
    'git apply --binary p' 'git apply -R --binary p' 'git update-ref refs/pr-reviews/1/reviewed abc' \
    'git archive abc | tar -x -C d' 'git diff --name-only a b' 'git status --porcelain' 'git remote get-url origin' \
    'gh pr view 1 -R o/r --json title' 'gh pr list -R o/r' 'gh pr checks 1' 'gh run view 1 --log-failed' \
    'gh repo view o/r' 'gh api repos/o/r/pulls/1' 'rm -f "$ACTIVE"' 'rm -rf -- "$WD/commits"' \
    '# git commit is forbidden' 'die "add one yourself: git remote add x y" 4' 'echo "never git push"'; do
    expect_clean "$good"
  done
  [ "$fail" -eq 0 ] && echo "self-test ok: every forbidden pattern is caught and every allowed one passes"
  exit "$fail"
fi

status=0
while IFS= read -r f; do
  [ "$(basename "$f")" = "$SELF" ] && continue
  scan "$f" "${f#"$HERE"/../}" || status=1
done < <(find "$HERE" "$HERE/../profiles" -name '*.sh' -type f 2>/dev/null | sort)
[ "$status" -eq 0 ] && echo "ok: no script can write to GitHub, git history, the index, or the network"
exit "$status"
