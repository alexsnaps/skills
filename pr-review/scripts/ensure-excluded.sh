#!/usr/bin/env bash
# Keep .pr-reviews/ out of git without touching the shared .gitignore: add it to
# .git/info/exclude (local to this clone, never committed) and verify.
# Idempotent. Exit 3 if git would still track the directory.
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

EXC="$(git rev-parse --path-format=absolute --git-path info/exclude)"
mkdir -p "$PRDIR"

if ! git check-ignore -q -- "$PRDIR/.probe"; then
  mkdir -p "$(dirname "$EXC")"
  printf '\n# pr-review skill: private review drafts, never committed\n.pr-reviews/\n' >>"$EXC"
fi

git check-ignore -q -- "$PRDIR/.probe" ||
  die ".pr-reviews/ is still not ignored (a negation rule in .gitignore?); refusing to write drafts into a tree git would track" 3

echo "ok: .pr-reviews/ is ignored ($EXC)"
