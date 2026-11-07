#!/usr/bin/env bash
# mokei vs tests/embedded.expected (rows from tokei 15.0.0 JSON): one row per file/language and per child (|-).
set -euo pipefail
d="$(dirname "$(readlink -f "$0")")"; b="${MOKEI_BIN:-$d/../.bin/mokei}"
cd "$d/fx/emb"
bad=0
for f in *; do
  got="$("$b" --json "$f" | python3 -I -c '
import json, sys
f = sys.argv[1]
j = json.load(sys.stdin)
for l in j["languages"]:
    print(f, l["name"], l["files"], l["lines"], l["code"], l["comments"], l["blanks"])
    for c in l.get("children", []):
        print(f, "|-", c["name"], c["files"], c["lines"], c["code"], c["comments"], c["blanks"])
' "$f")"
  want="$(grep "^$f " "$d/embedded.expected" || true)"
  if [ "$got" != "$want" ]; then echo "FAIL embed $f:"; diff <(echo "$want") <(echo "$got") || true; bad=1; fi
done
[ $bad -eq 0 ] || exit 1
echo "ok mokei embedded"
