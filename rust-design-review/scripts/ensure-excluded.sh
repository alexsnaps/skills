#!/usr/bin/env bash
# Keep .design-review/ out of git without touching the shared .gitignore: add it to
# .git/info/exclude (local to this clone, never committed) and verify. Idempotent.
# A no-op when the root is not a git repository. Exit 3 if git would still track it.
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

mkdir -p "$DRDIR"

if ! is_git; then
  echo "ok: $ROOT is not a git repository; nothing to exclude ($DRDIR)"
  exit 0
fi

EXC="$(git -C "$ROOT" rev-parse --path-format=absolute --git-path info/exclude)"
if ! git -C "$ROOT" check-ignore -q -- "$DRDIR/.probe"; then
  mkdir -p "$(dirname "$EXC")"
  printf '\n# rust-design-review skill: local design-audit output, never committed\n.design-review/\n' >>"$EXC"
fi

git -C "$ROOT" check-ignore -q -- "$DRDIR/.probe" ||
  die ".design-review/ is still not ignored (a negation rule in .gitignore?); refusing to write into a tree git would track" 3

echo "ok: .design-review/ is ignored ($EXC)"
