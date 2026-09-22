#!/usr/bin/env bash
# Archive base and head (never a checkout) and run cargo-public-api /
# cargo-semver-checks per touched crate where installed. Building the PR's
# code goes through exec_guard -- same trigger conditions as pr-review's own
# scripts (exit 22 for build/config files unless --approved).
#
#   scan-api.sh <pr reference> [--approved]
#
# Output lands under .pr-reviews/<slug>/api-review/{base,head}/ (the archived
# trees) and .../<safe-crate-name>.{base-api,head-api}.txt plus a
# .public-api.diff and a .semver-checks.txt per crate (each a one-line
# "skipped: ..." when its tool can't run -- never implies a pass). Only
# library/workspace-internal crates get either tool run (binary/cdylib have
# no rustdoc-visible library API to check -- cargo-semver-checks itself
# refuses on a binary-only crate: "no crates with library targets selected").
# Prints a manifest line per crate: crate=<name> dir=<dir> kind=<kind>
# public_api=ok|skipped semver_checks=ok|failed|skipped
#
# cargo-public-api needs a NIGHTLY toolchain to build rustdoc JSON, separate
# from the binary being installed (`rustup toolchain install nightly`); 0.52
# has no flag to point it at a different one. Verified against real installs
# of cargo-public-api 0.52.0 / cargo-semver-checks 0.50.0.
#
# Known gap, confirmed against cargo-semver-checks 0.50.0's own --list: it
# has no lint for "a function's return type changed to a different concrete
# type" (e.g. () -> Result<(), E>) -- only unit<->value transitions
# (function_now_returns_unit / exported_function_return_value_added). A
# clean semver-checks run does NOT mean no breaking signature change; the
# signature lens in REVIEW.md still has to look at every changed function
# itself, not just trust a pass here.
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

parse_pr_ref "${1:-}"
PR_ARG="${1:-}"
shift || true
APPROVED=no
while [ $# -gt 0 ]; do
  case "$1" in
    --approved) APPROVED=yes ;;
    *) die "unknown option: $1" 2 ;;
  esac
  shift
done

require_excluded
load_pr_refs
api_paths
exec_guard "$APPROVED"

rm -rf -- "$API_WD"
mkdir -p "$API_WD/base" "$API_WD/head"
export CARGO_TARGET_DIR="$PRDIR/target"

git archive "$MB" | tar -x -C "$API_WD/base"
git archive "$HEAD_SHA" | tar -x -C "$API_WD/head"

HAVE_PUBLIC_API=no; command -v cargo-public-api >/dev/null 2>&1 && HAVE_PUBLIC_API=yes
HAVE_NIGHTLY=no; rustup toolchain list 2>/dev/null | grep -q '^nightly' && HAVE_NIGHTLY=yes
HAVE_SEMVER_CHECKS=no; command -v cargo-semver-checks >/dev/null 2>&1 && HAVE_SEMVER_CHECKS=yes

if [ "$HAVE_PUBLIC_API" = no ]; then
  info "cargo-public-api not installed: falling back to diff-reading for the API surface (weak spots: re-exports, trait impls, macro-generated items)"
elif [ "$HAVE_NIGHTLY" = no ]; then
  info "cargo-public-api needs a nightly toolchain to build rustdoc JSON (not installed: rustup toolchain install nightly): falling back to diff-reading"
  HAVE_PUBLIC_API=no
fi
[ "$HAVE_SEMVER_CHECKS" = yes ] || info "cargo-semver-checks not installed: no tool-backed semver verdict, judgment only"

"$SKILL_DIR/scripts/classify-crates.sh" "$PR_ARG" >"$API_WD/crates.tsv"

while IFS=$'\t' read -r dir manifest name kind publish; do
  [ -n "$name" ] || continue
  base_manifest="$API_WD/base/$manifest"
  head_manifest="$API_WD/head/$manifest"
  checkable=no
  case "$kind" in library | workspace-internal) checkable=yes ;; esac

  public_status=skipped
  if [ "$checkable" = yes ] && [ "$HAVE_PUBLIC_API" = yes ] && [ -f "$base_manifest" ] && [ -f "$head_manifest" ]; then
    cargo public-api --manifest-path "$base_manifest" >"$API_WD/$name.base-api.txt" 2>"$API_WD/$name.base-api.err" || true
    cargo public-api --manifest-path "$head_manifest" >"$API_WD/$name.head-api.txt" 2>"$API_WD/$name.head-api.err" || true
    if [ -s "$API_WD/$name.head-api.txt" ]; then
      diff -u "$API_WD/$name.base-api.txt" "$API_WD/$name.head-api.txt" >"$API_WD/$name.public-api.diff" || true
      public_status=ok
    fi
  fi
  if [ "$public_status" = skipped ]; then
    if [ "$checkable" = no ]; then
      echo "skipped: kind=$kind has no library API surface to check" >"$API_WD/$name.public-api.diff"
    else
      echo "skipped: cargo-public-api unavailable (see above), or crate missing on one side" >"$API_WD/$name.public-api.diff"
    fi
  fi

  semver_status=skipped
  if [ "$checkable" = yes ] && [ "$HAVE_SEMVER_CHECKS" = yes ] && [ -f "$base_manifest" ] && [ -f "$head_manifest" ]; then
    if cargo semver-checks check-release --manifest-path "$head_manifest" \
         --baseline-root "$(dirname "$base_manifest")" >"$API_WD/$name.semver-checks.txt" 2>&1; then
      semver_status=ok
    else
      semver_status=failed
    fi
  fi
  if [ "$semver_status" = skipped ]; then
    if [ "$checkable" = no ]; then
      echo "skipped: kind=$kind has no library API surface to check" >"$API_WD/$name.semver-checks.txt"
    else
      echo "skipped: cargo-semver-checks not installed, or crate missing on one side" >"$API_WD/$name.semver-checks.txt"
    fi
  fi

  echo "crate=$name dir=${dir:-.} kind=$kind public_api=$public_status semver_checks=$semver_status"
done <"$API_WD/crates.tsv"

echo "base_dir=$API_WD/base head_dir=$API_WD/head crates_file=$API_WD/crates.tsv"
