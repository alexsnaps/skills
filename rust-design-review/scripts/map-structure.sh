#!/usr/bin/env bash
# Discover how the codebase is "split": workspace members, each crate's kind, the
# module files inside it, and the internal (member-to-member) dependency edges.
# No source is modified; `cargo metadata` reads the manifests (it does NOT compile).
#
#   map-structure.sh
#
# Writes, under .design-review/:
#   metadata.json   raw `cargo metadata --no-deps` (reused by measure.sh)
#   structure.tsv   name<TAB>reldir<TAB>class<TAB>publishable<TAB>n_modules
#   edges.tsv       from<TAB>to<TAB>dep_kind        (only edges between members)
# and prints a human-readable outline to stdout.
#
# class: library | workspace-internal | binary | cdylib | proc-macro | other.
# It's a heuristic from the manifest's target kinds + `publish`; confirm anything
# borderline yourself. Exit 20: jq missing (required here).
source "$(dirname "${BASH_SOURCE[0]}")/lib.sh"

have jq || die "jq is required to map structure (brew install jq)" 20
require_excluded
mkdir -p "$DRDIR"

META="$DRDIR/metadata.json"
cargo metadata --no-deps --format-version 1 >"$META" 2>"$DRDIR/metadata.err" ||
  die "cargo metadata failed (see $DRDIR/metadata.err)" 5

n_members="$(jq '.workspace_members | length' "$META")"
IS_WS=no; [ "$n_members" -gt 1 ] && IS_WS=yes

# name<TAB>manifest_dir<TAB>rawkind<TAB>publishable<TAB>kinds_csv
jq -r '
  .packages[]
  | . as $p
  | ([$p.targets[].kind[]] | unique) as $kinds
  | [ $p.name,
      ($p.manifest_path | sub("/Cargo\\.toml$"; "")),
      (if   ($kinds | index("cdylib"))     then "cdylib"
       elif ($kinds | index("proc-macro")) then "proc-macro"
       elif ($kinds | index("lib")) or ($kinds | index("rlib")) then "lib"
       elif ($kinds | index("bin"))        then "bin"
       else "other" end),
      (if ($p.publish == null) or (($p.publish | length) > 0) then "true" else "false" end),
      ($kinds | join(",")) ]
  | @tsv
' "$META" >"$DRDIR/.pkgs.tsv"

: >"$DRDIR/structure.tsv"
while IFS=$'\t' read -r name dir rawkind publishable kinds; do
  [ -n "$name" ] || continue
  reldir="${dir#"$ROOT"/}"; [ "$reldir" = "$dir" ] && reldir="."
  case "$rawkind" in
    cdylib | proc-macro | bin | other) class="$rawkind" ;;
    lib) if [ "$IS_WS" = yes ] && [ "$publishable" = false ]; then class="workspace-internal"; else class="library"; fi ;;
    *) class="other" ;;
  esac
  [ "$class" = bin ] && class="binary"
  srcdir="$dir/src"
  n_mods=0
  [ -d "$srcdir" ] && n_mods="$(find "$srcdir" -type f -name '*.rs' 2>/dev/null | grep -c . || true)"
  printf '%s\t%s\t%s\t%s\t%s\n' "$name" "$reldir" "$class" "$publishable" "$n_mods" >>"$DRDIR/structure.tsv"
done <"$DRDIR/.pkgs.tsv"

# Internal dependency edges: a package dependency whose name is another member.
jq -r '[.packages[].name] | .[]' "$META" | sort -u >"$DRDIR/.members.txt"
: >"$DRDIR/edges.tsv"
jq -r '
  .packages[] as $p
  | $p.dependencies[]?
  | [ $p.name, .name, (.kind // "normal") ] | @tsv
' "$META" | while IFS=$'\t' read -r from to kind; do
  grep -qxF "$to" "$DRDIR/.members.txt" || continue
  printf '%s\t%s\t%s\n' "$from" "$to" "$kind" >>"$DRDIR/edges.tsv"
done

# ---- human-readable outline ----
echo "root=$ROOT"
echo "workspace=$IS_WS  members=$n_members"
have cargo-modules || info "cargo-modules not installed: module tree is approximated by source files; install it for the true mod hierarchy and intra-crate edges"
echo
echo "Crates (class, modules):"
while IFS=$'\t' read -r name reldir class publishable n_mods; do
  printf '  %-28s %-18s %s modules   [%s]\n' "$name" "$class" "$n_mods" "$reldir"
done <"$DRDIR/structure.tsv"

echo
if [ -s "$DRDIR/edges.tsv" ]; then
  echo "Internal dependency edges (from -> to [kind]):"
  while IFS=$'\t' read -r from to kind; do echo "  $from -> $to [$kind]"; done <"$DRDIR/edges.tsv"
  # Cheap circular-dependency hint: a normal edge A->B where B->A also exists.
  # (Deeper cycles need a real graph tool; this catches the common 2-crate case.)
  cyc="$(awk -F'\t' '$3=="normal"{seen[$1"\t"$2]=1}
       END{for(e in seen){split(e,a,"\t"); if((a[2]"\t"a[1]) in seen && a[1]<a[2]) print "  "a[1]" <-> "a[2]}}' "$DRDIR/edges.tsv")"
  [ -n "$cyc" ] && { echo; echo "Circular crate dependencies (red flag -- see design-principles Ch2/Ch7):"; echo "$cyc"; }
else
  echo "Internal dependency edges: none (single crate, or members don't depend on each other)"
fi

echo
echo "wrote: $DRDIR/structure.tsv  $DRDIR/edges.tsv  $DRDIR/metadata.json"
rm -f "$DRDIR/.pkgs.tsv" "$DRDIR/.members.txt"
