#!/usr/bin/env bash
# Per-crate and per-module signals for the design lenses in ASSESS.md. Heuristic,
# source-level counts (not a real Rust parser) plus tool-backed numbers where the
# tool is installed; every number is a starting point to confirm by reading, not a
# verdict. Nothing is modified.
#
#   measure.sh [<crate-name>]     all crates, or just one
#
# Reads .design-review/structure.tsv (run map-structure.sh first). Writes per-crate
# detail to .design-review/measure/<crate>.modules.tsv and prints a summary table.
#
# Columns (per crate): loc  pub  pub(crate)  pub_use  pub/kLoC  modules  public_api
#   loc         Rust code lines (tokei) or raw line count if tokei is missing
#   pub         public items (fn/struct/enum/trait/mod/const/static/type/union)
#   pub(crate)  crate/super/self-restricted items (real hiding, not leakage)
#   pub_use     public re-exports (a re-export changes an item's public path)
#   pub/kLoC    public items per 1000 code lines -- a high value hints "shallow"
#   public_api  `cargo public-api` item count, or "-" when the tool/nightly is absent
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

ONLY="${1:-}"
require_excluded
[ -f "$DRDIR/structure.tsv" ] || die "no structure.tsv; run map-structure.sh first" 6
mkdir -p "$DRDIR/measure"

HAVE_TOKEI=no; have tokei && HAVE_TOKEI=yes
HAVE_PUBLIC_API=no; have cargo-public-api && HAVE_PUBLIC_API=yes
HAVE_NIGHTLY=no; rustup toolchain list 2>/dev/null | grep -q '^nightly' && HAVE_NIGHTLY=yes
if [ "$HAVE_PUBLIC_API" = yes ] && [ "$HAVE_NIGHTLY" = no ]; then
  info "cargo-public-api needs a nightly toolchain (rustup toolchain install nightly): public_api column will be '-'"
  HAVE_PUBLIC_API=no
fi
[ "$HAVE_TOKEI" = yes ] || info "tokei not installed: loc is a raw line count (blanks+comments included)"
[ "$HAVE_PUBLIC_API" = yes ] || info "cargo-public-api unavailable: public_api column is '-' (reason above); judge surface from pub/pub_use"

PUB_RE='(^|[^[:alnum:]_])pub[[:space:]]+(async[[:space:]]+)?(unsafe[[:space:]]+)?(extern[[:space:]]+("[^"]*"[[:space:]]+)?)?(fn|struct|enum|trait|mod|const|static|type|union)[[:space:]]'
PUBUSE_RE='(^|[^[:alnum:]_])pub[[:space:]]+use[[:space:]]'
PUBCRATE_RE='(^|[^[:alnum:]_])pub[[:space:]]*\([[:space:]]*(crate|super|self|in[[:space:]])'

loc_of() { # loc_of <dir>
  local d="$1"
  if [ "$HAVE_TOKEI" = yes ]; then
    tokei --output json "$d" 2>/dev/null | jq -r '(.Rust.code // 0)' 2>/dev/null || echo 0
  else
    find "$d" -type f -name '*.rs' -print0 2>/dev/null | xargs -0 cat 2>/dev/null | grep -c '' || echo 0
  fi
}

printf '%-26s %7s %5s %6s %6s %8s %7s %10s\n' crate loc pub 'pub(cr)' pub_use pub/kLoC modules public_api
while IFS=$'\t' read -r name reldir class publishable n_mods; do
  [ -n "$name" ] || continue
  [ -n "$ONLY" ] && [ "$ONLY" != "$name" ] && continue
  crate_dir="$ROOT/$reldir"; [ "$reldir" = "." ] && crate_dir="$ROOT"
  src="$crate_dir/src"
  if [ ! -d "$src" ]; then
    printf '%-26s %7s %5s %6s %6s %8s %7s %10s   [%s, no src/]\n' "$name" - - - - - "$n_mods" - "$class"
    continue
  fi

  loc="$(loc_of "$src")"; [ -n "$loc" ] || loc=0
  pub="$(count_matches "$PUB_RE" "$src")"
  pubcrate="$(count_matches "$PUBCRATE_RE" "$src")"
  pubuse="$(count_matches "$PUBUSE_RE" "$src")"
  if [ "$loc" -gt 0 ]; then ratio="$(awk -v p="$pub" -v l="$loc" 'BEGIN{printf "%.1f", (p*1000.0)/l}')"; else ratio="-"; fi

  papi="-"
  if [ "$HAVE_PUBLIC_API" = yes ]; then
    case "$class" in
      library | workspace-internal | proc-macro)
        if out="$(cd "$ROOT" && cargo public-api -p "$name" 2>"$DRDIR/measure/$name.public-api.err")"; then
          echo "$out" >"$DRDIR/measure/$name.public-api.txt"
          papi="$(printf '%s\n' "$out" | grep -c . || true)"
        else papi="err"; fi ;;
    esac
  fi

  # per-module (per-file) detail, largest first
  {
    printf 'module_file\tloc\tpub\n'
    find "$src" -type f -name '*.rs' 2>/dev/null | sort | while read -r f; do
      fl="$(grep -c '' "$f" || echo 0)"
      fp="$(count_matches "$PUB_RE" "$f")"
      printf '%s\t%s\t%s\n' "${f#"$crate_dir"/}" "$fl" "$fp"
    done | sort -t$'\t' -k2,2nr
  } >"$DRDIR/measure/$name.modules.tsv"

  printf '%-26s %7s %5s %6s %6s %8s %7s %10s\n' "$name" "$loc" "$pub" "$pubcrate" "$pubuse" "$ratio" "$n_mods" "$papi"
done <"$DRDIR/structure.tsv"

echo
echo "per-module detail: $DRDIR/measure/<crate>.modules.tsv (largest files first)"
echo "high pub/kLoC or a module with many pub items and few callers = shallow-module / overexposure candidates (ASSESS.md)"
