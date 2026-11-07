#!/usr/bin/env bash
# One runner: each row is a fixture, hand-counted and checked against tokei 15.0.0 (2026-11-07).
# row: file | Language | files lines code comments blanks
set -euo pipefail
d="$(dirname "$(readlink -f "$0")")"; b="${MOKEI_BIN:-$d/../.bin/mokei}"
cd "$d/fx"
fail() { echo "FAIL $1: $2"; exit 1; }
while read -r f lang row; do
  got="$("$b" "$f" | awk -v l="$lang" '$1==l{print $2,$3,$4,$5,$6}')"
  [ "$got" = "$row" ] || fail "$f" "want '$row' got '$got'"
done <<'ROWS'
a.py Python 1 6 4 1 1
b.js JavaScript 1 8 4 4 0
c.html HTML 1 3 1 1 1
t.ini INI 1 5 2 2 1
l.lua Lua 1 6 2 3 1
n.rs Rust 1 7 4 3 0
p.py Python 1 6 5 1 0
r.cpp C++ 1 5 4 1 0
s.swift Swift 1 4 1 3 0
ROWS
# a new language row needs no code
got="$(MOKEI_LANGS="$d/fx/extra.toml" "$b" d.foo | awk '$1=="Foo"{print $2,$3,$4,$5,$6}')"
[ "$got" = "1 5 1 3 1" ] || fail extra-row "got '$got'"
echo "ok mokei fixtures"
