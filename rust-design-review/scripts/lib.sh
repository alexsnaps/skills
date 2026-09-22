#!/usr/bin/env bash
# Shared helpers for the rust-design-review scripts. Sourced, never run directly.
#
# This is a READ-ONLY audit. These scripts never write to git, never touch GitHub,
# never use the network, and never modify the codebase. They may run `cargo`
# (which compiles crates, i.e. executes their build scripts) and write only under
# .design-review/. Run check-no-writes.sh to lint that.
set -euo pipefail

die() { echo "rust-design-review: $1" >&2; exit "${2:-1}"; }
info() { echo "rust-design-review: $*" >&2; }
have() { command -v "$1" >/dev/null 2>&1; }

have cargo || die "cargo not found; this skill audits a Rust codebase" 2

# The workspace (or package) root is the directory of the manifest cargo resolves
# from the current directory. Works for both a virtual workspace and a lone crate.
_manifest="$(cargo locate-project --workspace --message-format plain 2>/dev/null || true)"
[ -n "$_manifest" ] || die "not inside a Cargo workspace or package (no Cargo.toml found upward)" 2
ROOT="$(cd "$(dirname "$_manifest")" && pwd)"
DRDIR="$ROOT/.design-review"
SKILL_DIR="$(cd "$(dirname "$(readlink -f "${BASH_SOURCE[0]}")")/.." && pwd)"

is_git() { git -C "$ROOT" rev-parse --git-dir >/dev/null 2>&1; }

# Refuse to write the report where git would track it -- but only when the root is
# actually a git repo (a plain source tree has nothing to exclude).
require_excluded() {
  is_git || return 0
  git -C "$ROOT" check-ignore -q -- "$DRDIR/.probe" ||
    die ".design-review/ is not ignored by git; run scripts/ensure-excluded.sh first" 3
}

# count_matches <extended-regex> <file...>: matching lines, 0 instead of a grep
# non-zero exit on no match (so `set -e` is safe). Reads names from stdin if none.
count_matches() {
  local re="$1"; shift
  if [ "$#" -gt 0 ]; then grep -rhoE "$re" "$@" 2>/dev/null | grep -c . || true
  else grep -hoE "$re" 2>/dev/null | grep -c . || true; fi
}
