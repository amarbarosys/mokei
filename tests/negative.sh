#!/usr/bin/env bash
# Copyright 2026 amarbaro.org. Licensed under the Apache License, Version 2.0.
# Negative control: a wrong expected count must make the check FAIL. Each case copies tests/ to .work/neg,
# breaks one expectation there, runs the copy against the real binary, and requires a non-zero exit with
# the named FAIL line. A case that passes means the check cannot go red.
set -euo pipefail
d="$(dirname "$(readlink -f "$0")")"; root="$d/.."; b="${MOKEI_BIN:-$root/.bin/mokei}"
fail() { echo "FAIL $1: $2"; exit 1; }
n=0
case_() {   # name, file to break (relative to tests/), sed expression, expected FAIL fragment
    local w="$root/.work/neg"; n=$((n + 1))
    [ -d "$w" ] && rm -rf -- "$w"
    mkdir -p "$w" && cp -r "$d" "$w/tests" && cp "$root/VERSION" "$root/CHANGELOG.md" "$w/"
    sed -i "$3" "$w/tests/$2"
    cmp -s "$d/$2" "$w/tests/$2" && fail "$1" "the break changed nothing in $2"
    if out="$(MOKEI_BIN="$b" bash "$w/tests/test_mokei.sh" 2>&1)"; then fail "$1" "broken $2 still passed"; fi
    grep -q "$4" <<<"$out" || fail "$1" "no '$4' in: $(echo "$out" | tail -1)"
    echo "ok negative $1 (failed as it must: $(echo "$out" | tail -1))"
}
case_ row-count     test_mokei.sh        's/^a.py Python 1 6 4 1 1$/a.py Python 1 6 5 1 1/' 'FAIL a.py'
case_ golden-json   golden.json          's/"code":4/"code":5/'                                  'FAIL json'
case_ embedded      embedded.expected    '1s/[0-9][0-9]*$/99/'                                  'FAIL embed'
case_ diff-count    test_mokei.sh        's/^want="Python 2 4 3/want="Python 2 5 3/'             'FAIL diff'
echo "ok mokei negative ($n cases)"
