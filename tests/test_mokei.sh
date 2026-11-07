#!/usr/bin/env bash
# Hand-counted fixtures; numbers checked against tokei 2026-11-07 (Python, CSS-family match exactly).
set -euo pipefail
d="$(dirname "$(readlink -f "$0")")"; b="${MOKEI_BIN:-$d/../.bin/mokei}"
cd "$d/fx"
out="$("$b" a.py b.js c.html)"
exp='Python 1 6 4 1 1
JavaScript 1 8 4 4 0
HTML 1 3 1 1 1'
got="$(echo "$out" | awk 'NR>1 && $1!="Total"{print $1,$2,$3,$4,$5,$6}' | sort)"
if [ "$got" != "$(echo "$exp" | sort)" ]; then echo "FAIL fixtures: got"; echo "$got"; exit 1; fi
echo "ok mokei fixtures"
# a new language row needs no code: Foo = 5 lines, 1 code, 3 comment, 1 blank
got="$(MOKEI_LANGS="$d/fx/extra.toml" "$b" d.foo | awk '$1=="Foo"{print $1,$2,$3,$4,$5,$6}')"
if [ "$got" != "Foo 1 5 1 3 1" ]; then echo "FAIL extra-row: got '$got'"; exit 1; fi
echo "ok mokei extra row"
