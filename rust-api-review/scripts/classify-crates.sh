#!/usr/bin/env bash
# Which crates a PR touches, and a best-effort guess at each one's kind --
# no build, no exec_guard: just Cargo.toml read via `git show`, never a
# checkout. This is a heuristic starting point (line-based Cargo.toml
# reading, not a real TOML parser) -- confirm anything borderline yourself.
#
#   classify-crates.sh <pr reference>
#
# One tab-separated line per touched crate's manifest, to stdout:
#   <dir>\t<manifest-path>\t<safe-name>\t<kind>\t<publish>
# dir is "" for a manifest at the repo root. kind: library | workspace-internal
# | binary | cdylib. safe-name has anything but [A-Za-z0-9_-] replaced with
# "_", so it's always safe to use in a filename.
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

parse_pr_ref "${1:-}"
load_pr_refs
require_excluded

mapfile -t MANIFESTS < <(git ls-tree -r --name-only "$HEAD_SHA" | grep -E '(^|/)Cargo\.toml$')
IS_WORKSPACE=no
for m in "${MANIFESTS[@]}"; do [ "$m" = "Cargo.toml" ] && IS_WORKSPACE=yes; done

is_known_manifest() {
  local want="$1" cand
  for cand in "${MANIFESTS[@]}"; do [ "$cand" = "$want" ] && return 0; done
  return 1
}

# nearest_manifest <changed-file>: the closest Cargo.toml at or above it, at head
nearest_manifest() {
  local d f="$1" m
  d="$(dirname "$f")"
  while :; do
    m="Cargo.toml"; [ "$d" != "." ] && m="$d/Cargo.toml"
    is_known_manifest "$m" && { echo "$m"; return 0; }
    [ "$d" = "." ] && return 1
    d="$(dirname "$d")"
  done
}

mapfile -t CHANGED < <(git diff --no-renames --name-only "$MB" "$HEAD_SHA")
declare -A SEEN
for f in "${CHANGED[@]}"; do
  m="$(nearest_manifest "$f")" || continue
  [ -n "${SEEN[$m]:-}" ] && continue
  SEEN["$m"]=1

  toml="$(git show "$HEAD_SHA:$m" 2>/dev/null || true)"
  dir="$(dirname "$m")"; [ "$dir" = "." ] && dir=""
  name="$(printf '%s\n' "$toml" | awk -F'"' '/^[[:space:]]*name[[:space:]]*=/{print $2; exit}')"
  # A manifest with no `name` has no [package] section -- a pure workspace
  # root, not a crate itself. Nothing to classify; a changed top-level file
  # (README, CI config) legitimately walks up to it, so skip quietly.
  [ -n "$name" ] || continue
  safe_name="$(printf '%s' "$name" | tr -c 'A-Za-z0-9_-' '_')"
  publish=true
  printf '%s\n' "$toml" | grep -qE '^[[:space:]]*publish[[:space:]]*=[[:space:]]*false' && publish=false
  is_cdylib=false
  printf '%s\n' "$toml" | grep -qE 'crate-type[[:space:]]*=.*cdylib' && is_cdylib=true
  has_bin=false
  printf '%s\n' "$toml" | grep -qE '^\[\[bin\]\]' && has_bin=true
  has_lib=false
  git cat-file -e "$HEAD_SHA:${dir:+$dir/}src/lib.rs" 2>/dev/null && has_lib=true

  if [ "$is_cdylib" = true ]; then
    kind=cdylib
  elif [ "$has_lib" = false ] && [ "$has_bin" = true ]; then
    kind=binary
  elif [ "$IS_WORKSPACE" = yes ] && [ "$publish" = false ]; then
    kind=workspace-internal
  else
    kind=library
  fi
  printf '%s\t%s\t%s\t%s\t%s\n' "$dir" "$m" "$safe_name" "$kind" "$publish"
done
