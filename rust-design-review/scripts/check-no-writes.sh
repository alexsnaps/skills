#!/usr/bin/env bash
# Guardrail: fail if any script here contains a command that could write to git
# history/index/config, to GitHub, or to the network, or recursively delete
# outside .design-review/. This skill is a read-only audit.
#
#   check-no-writes.sh              lint scripts/*.sh
#   check-no-writes.sh --self-test  prove the rules catch what they should (and only that)
#
# Allowed on purpose: read-only git (rev-parse, check-ignore, locate via cargo),
# appending to .git/info/exclude via a shell redirect (not a git command), cargo
# reads/builds, tokei/jq/grep/find, and rm -f / rm -rf of paths under "$DRDIR/".
# `gh` is forbidden entirely -- this skill never talks to GitHub.
set -uo pipefail
HERE="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
SELF="$(basename "${BASH_SOURCE[0]}")"
B='(^|[^[:alnum:]_-])'
GIT="${B}git[[:space:]]+(-[^[:space:]]+[[:space:]]+([^-[:space:]][^[:space:]]*[[:space:]]+)?){0,4}"

RULES=(
  "git history/index/config write|${GIT}(commit|push|stash|add|reset|rebase|merge|cherry-pick|revert|am|tag|clean|checkout|restore|rm|mv|pull|fetch|worktree|config|gc|prune|update-ref)([[:space:]]|$)"
  "git remote/branch write|${GIT}(remote[[:space:]]+(add|set-url|remove|rm|rename)|branch[[:space:]]+(-[dDmMcC]|--delete|--move|--copy))"
  "git apply that stages|${GIT}apply[^|;&]*(--index|--cached|--3way|[[:space:]]-3)"
  "github access|${B}gh[[:space:]]"
  "network tool|${B}(curl|wget|scp|rsync|ssh|nc|ncat|telnet|ftp|sftp)[[:space:]]"
  "sudo/eval|${B}(sudo|eval)[[:space:]]"
)
RM_RECURSIVE="${B}rm[[:space:]]+-[a-zA-Z]*[rR]"

scan() {
  local file="$1" label="${2:-$1}" n=0 bad=0 line raw rule name re
  while IFS= read -r raw || [ -n "$raw" ]; do
    n=$((n + 1))
    line="${raw#"${raw%%[![:space:]]*}"}"
    [ -n "$line" ] || continue
    case "$line" in \#*) continue ;; esac
    if [[ "$line" =~ ^(echo|die|info|printf)[[:space:]] ]] && ! [[ "$line" =~ [\;\&\|\`] ]] && [[ "$line" != *'$('* ]]; then
      continue
    fi
    for rule in "${RULES[@]}"; do
      name="${rule%%|*}"; re="${rule#*|}"
      if [[ "$line" =~ $re ]]; then echo "$label:$n: [$name] $line"; bad=1; fi
    done
    if [[ "$line" =~ $RM_RECURSIVE ]] && [[ "$line" != *'"$DRDIR/'* ]]; then
      echo "$label:$n: [recursive rm outside .design-review] $line"; bad=1
    fi
  done <"$file"
  return $bad
}

if [ "${1:-}" = "--self-test" ]; then
  tmp="$(mktemp)"; trap 'rm -f "$tmp"' EXIT; fail=0
  expect_flagged() { printf '%s\n' "$1" >"$tmp"; if scan "$tmp" >/dev/null; then echo "self-test FAILED: not flagged: $1"; fail=1; fi; }
  expect_clean()   { printf '%s\n' "$1" >"$tmp"; if ! scan "$tmp" >/dev/null; then echo "self-test FAILED: wrongly flagged: $1"; fail=1; fi; }
  for bad in \
    'git commit -m x' 'git push origin main' 'git add -A' 'git reset --hard' 'git fetch origin' \
    'git checkout -- .' 'git config user.name x' 'git update-ref refs/heads/main abc' \
    'git remote add fork url' 'git branch -D x' 'git apply --index p' \
    'gh pr view 1' 'gh api repos/x' 'gh pr comment 1 -b x' 'curl https://x' 'ssh host' \
    'sudo rm x' 'eval "$x"' 'rm -rf /tmp/x' 'rm -rf "$HOME"' \
    'true && git commit -m x' 'echo hi; git push' 'git -C /tmp/r commit -m y'; do
    expect_flagged "$bad"
  done
  for good in \
    'git -C "$ROOT" rev-parse --git-dir' 'git -C "$ROOT" check-ignore -q -- "$DRDIR/.probe"' \
    'cargo metadata --no-deps --format-version 1' 'cargo public-api -p "$name"' 'tokei --output json "$d"' \
    'find "$src" -type f -name "*.rs"' 'printf ".design-review/\n" >>"$EXC"' \
    'rm -f "$DRDIR/.pkgs.tsv"' 'rm -rf -- "$DRDIR/measure"' \
    '# git commit is forbidden' 'die "run ensure-excluded.sh first" 3' 'echo "never gh or git push here"'; do
    expect_clean "$good"
  done
  [ "$fail" -eq 0 ] && echo "self-test ok: every forbidden pattern is caught and every allowed one passes"
  exit "$fail"
fi

status=0
while IFS= read -r f; do
  [ "$(basename "$f")" = "$SELF" ] && continue
  scan "$f" "${f#"$HERE"/../}" || status=1
done < <(find "$HERE" -name '*.sh' -type f 2>/dev/null | sort)
[ "$status" -eq 0 ] && echo "ok: no script can write to git, GitHub, or the network"
exit "$status"
