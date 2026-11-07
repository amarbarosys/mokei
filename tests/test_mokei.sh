#!/usr/bin/env bash
# One runner: each row is a fixture, numbers from a tokei 15.0.0 run (2026-11-07), hand counts only as a cross-check.
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
tpl.js JavaScript 1 5 4 0 1
raw2.cpp C++ 1 3 3 0 0
g.go Go 1 3 2 1 0
sb Shell 1 5 3 2 0
cont.py Python 1 3 2 1 0
ROWS
bash "$d/embed-check.sh" || fail embedded "see above"
# a new language row needs no code
got="$(MOKEI_LANGS="$d/fx/extra.toml" "$b" d.foo | awk '$1=="Foo"{print $2,$3,$4,$5,$6}')"
[ "$got" = "1 5 1 3 1" ] || fail extra-row "got '$got'"
echo "ok mokei fixtures"
# output formats: golden JSON (valid per python json), --files, --sort
(cd "$d/fx" && "$b" --json a.py b.js c.html | cmp - "$d/golden.json") || fail json "differs from tests/golden.json"
(cd "$d/fx" && "$b" --json --files --sort lines a.py b.js c.html | cmp - "$d/golden-files.json") || fail json-files "differs from tests/golden-files.json"
python3 -I -c "import json,sys;json.load(open(sys.argv[1]))" "$d/golden-files.json" || fail json "golden-files.json is not JSON"
got="$(cd "$d/fx" && "$b" --sort files a.py b.js c.html t.ini | awk 'NR>1&&$1!="Total"{printf "%s ",$1}')"
[ "$got" = "HTML INI JavaScript Python " ] || fail sort-files "got '$got'"
got="$(cd "$d/fx" && "$b" --sort lines a.py b.js c.html t.ini | awk 'NR>1&&$1!="Total"{printf "%s ",$1}')"
[ "$got" = "JavaScript Python INI HTML " ] || fail sort-lines "got '$got'"
got="$(cd "$d/fx" && "$b" --files a.py b.js | awk '$1=="a.py"||$1=="b.js"{printf "%s:%s ",$1,$3}')"
[ "$got" = "b.js:8 a.py:6 " ] || fail files "got '$got'"
echo "ok mokei formats"
# gitignore walk: a fixture tree built fresh under .work/scratch; 6 of the 15 .py files survive the ignore rules
t="$d/../.work/scratch/tree"
[ -n "$d" ] && [ -d "$t" ] && rm -rf -- "$t"
mkdir -p "$t/.git" "$t/build" "$t/deep/build" "$t/deep/sub" "$t/sub/inner" "$t/docs/x/y"
printf 'ign_*.py\nbuild/\n/top.py\n!ign_keep.py\nsub/*.py\ndocs/**/gen.py\n' > "$t/.gitignore"
printf 'local_*.py\n' > "$t/deep/.gitignore"
for f in a.py top.py deep/top.py ign_1.py ign_keep.py build/b.py deep/build/c.py sub/s.py sub/inner/s2.py docs/gen.py docs/x/y/gen.py docs/keep.py deep/local_1.py deep/sub/local_2.py local_3.py .git/hook.py; do echo 'x = 1' > "$t/$f"; done
got="$("$b" "$t" | awk '$1=="Python"{print $2,$3,$4}')"
[ "$got" = "6 6 6" ] || fail walk "want '6 6 6' got '$got'"
got="$(cd "$t" && GIT_CEILING_DIRECTORIES="$(dirname "$t")" "$b" | awk '$1=="Python"{print $2,$3,$4}')"
[ "$got" = "6 6 6" ] || fail walk-default "no git repo: want '6 6 6' got '$got'"
echo "ok mokei walk"
# parallel scan = serial scan, byte for byte (this repo plus the fixtures)
cd "$d/.."
cmp <(MOKEI_JOBS=1 "$b" tests/fx/* mokei.mojo) <("$b" tests/fx/* mokei.mojo) || fail parallel "output differs from MOKEI_JOBS=1"
cmp <(MOKEI_JOBS=1 "$b") <("$b") || fail parallel "git ls-files output differs from MOKEI_JOBS=1"
echo "ok mokei parallel"
