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
# --semantic: statements functions nesting cyclomatic, hand-counted (a.c: 6 ';' + if + for = 8, the ';' after the struct counts)
while read -r f row; do
  got="$(cd "$d/fx/sem" && "$b" --semantic "$f" | awk -v f="$f" '$1==f{print $3,$4,$5,$6}')"
  [ "$got" = "$row" ] || fail "semantic $f" "want '$row' got '$got'"
done <<'ROWS'
a.py 12 2 3 6
a.mojo 11 2 3 4
a.js 7 2 3 7
a.rs 5 2 2 6
a.c 8 2 2 5
ROWS
(cd "$d/fx/sem" && "$b" --semantic --json a.py | python3 -I -c 'import json,sys; j=json.load(sys.stdin); assert j["files"][0]["cyclomatic"]==6 and j["total"]["functions"]==2') || fail semantic-json "bad JSON"
echo "ok mokei semantic"
# --diff and --budget: a fixture repo with two commits (+ a third that adds 25 code lines)
r="$d/../.work/scratch/drepo"
[ -n "$d" ] && [ -d "$r" ] && rm -rf -- "$r"
mkdir -p "$r" && cd "$r"
g() { git -c user.name=t -c user.email=t@t -c commit.gpgsign=false "$@"; }
git init -q . && printf '# top\nx = 1\n\ndef f():\n    return 1\n' > a.py && printf 'var a = 1;\n// c\n' > b.js
g add -A && g commit -q -m one
printf '# top\nx = 2\n# new comment\n\ndef f():\n    return 1\n    # tail\n\ny = 3\n' > a.py && printf '# c\ndef g():\n    pass\n\n' > c.py && git rm -q b.js
g add -A && g commit -q -m two
got="$("$b" --diff HEAD~1..HEAD | awk '$1=="Python"||$1=="JavaScript"||$1=="Total"||$1=="loc:"{print}' | tr -s ' ' | tr '\n' '|')"
want="Python 2 4 3 2 1 0 0|JavaScript 1 0 0 0 1 1 0|Total 3 4 3 2 2 1 0|loc: before 4 · after 6|"
[ "$got" = "$want" ] || fail diff "want '$want' got '$got'"
"$b" --diff HEAD~1..HEAD --budget XS > /dev/null || fail budget "4 added code lines must pass XS"
for i in $(seq 1 25); do echo "v$i = $i"; done > big.py
g add -A && g commit -q -m three
if "$b" --diff HEAD~1..HEAD --budget XS > "$r/out.txt"; then fail budget "25 added code lines must fail XS"; fi
grep -q 'FAIL, must stay under 20' "$r/out.txt" || fail budget "no verdict line"
"$b" --diff HEAD~1..HEAD --budget S > /dev/null || fail budget "25 added code lines must pass S"
"$b" --diff HEAD~1..HEAD --json | python3 -I -c 'import json,sys; j=json.load(sys.stdin); assert j["total"]["added"]["code"]==25 and j["loc"]["after"]==25' || fail diff-json "bad JSON"
cd "$d/.."
echo "ok mokei diff"
# --tokens: estimate and the real Qwen2.5 tokenizer (counts from mojo-tokenizers, which matches the Python crate)
tk="${MOKEI_TEST_TOKENIZER:-$HOME/Models/qwen2.5-0.5b-instruct-hf/tokenizer.json}"
[ -f "$tk" ] || fail tokens "tokenizer.json not found at $tk (set MOKEI_TEST_TOKENIZER)"
tcount() { "$b" "$@" --json | python3 -I -c 'import json,sys; print(json.load(sys.stdin)["total"]["tokens"])'; }
cd "$d/fx"
[ "$(tcount --tokens a.py)" = 25 ] && [ "$(tcount --tokens b.js)" = 26 ] && [ "$(tcount --tokens sem/a.rs)" = 96 ] || fail tokens-estimate "estimates changed"
[ "$(tcount --tokenizer "$tk" a.py)" = 24 ] && [ "$(tcount --tokenizer "$tk" b.js)" = 24 ] && [ "$(tcount --tokenizer "$tk" sem/a.rs)" = 95 ] || fail tokens-real "real counts changed"
cd "$d/.."
echo "ok mokei tokens"
# --dupes: one planted 6-line block (comments, blanks and spacing differ), none at N=7, merged at N=3
cd "$d/fx/dup"
got="$("$b" --dupes 5 a.py b.py | head -1)"
[ "$got" = "6 lines  a.py:3-9  ==  b.py:5-11" ] || fail dupes "got '$got'"
got="$("$b" --dupes 7 a.py b.py | tail -1)"
[ "$got" = "0 blocks, 0 duplicated code lines (blocks of >= 7 code lines)" ] || fail dupes-none "got '$got'"
"$b" --dupes 3 --json a.py b.py | python3 -I -c 'import json,sys; j=json.load(sys.stdin); assert len(j["blocks"])==1 and j["blocks"][0]["lines"]==6 and j["duplicate_lines"]==6' || fail dupes-json "bad JSON"
cd "$d/.."
echo "ok mokei dupes"
# --untested: names in no test file (private names count, main/dunder/test* skipped, comments and strings ignored)
cd "$d/fx/unt"
got="$("$b" --untested lib.js lib.rs lib.test.js src.py test_src.py tests/it.rs | tr '\n' '|')"
want="lib.js:2 jsUnused|lib.rs:2 rs_unused|src.py:4 unused|src.py:7 _private|src.py:11 method|5 untested of 8 defs (hint: a name match in a test file, nothing more)|"
[ "$got" = "$want" ] || fail untested "got '$got'"
"$b" --untested --json lib.js lib.test.js | python3 -I -c 'import json,sys; j=json.load(sys.stdin); assert [u["name"] for u in j["untested"]]==["jsUnused"] and j["defs"]==2' || fail untested-json "bad JSON"
cd "$d/.."
echo "ok mokei untested"
# parallel scan = serial scan, byte for byte (this repo plus the fixtures)
cd "$d/.."
cmp <(MOKEI_JOBS=1 "$b" tests/fx/* mokei.mojo) <("$b" tests/fx/* mokei.mojo) || fail parallel "output differs from MOKEI_JOBS=1"
cmp <(MOKEI_JOBS=1 "$b") <("$b") || fail parallel "git ls-files output differs from MOKEI_JOBS=1"
echo "ok mokei parallel"
