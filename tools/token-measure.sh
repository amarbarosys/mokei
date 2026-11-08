#!/usr/bin/env bash
# Copyright 2026 amarbaro.org. Licensed under the Apache License, Version 2.0.
# --tokens estimate vs the real tokenizer on the corpus, per language and total.
# Usage: tools/token-measure.sh [TOKENIZER_JSON] [REPO...]   exit 1 when the total or a language of >= 50 kB is off by more than 10%.
set -euo pipefail
d="$(dirname "$(readlink -f "$0")")"
tok="${1:-$HOME/Models/qwen2.5-0.5b-instruct-hf/tokenizer.json}"; shift || true
repos=("$@"); [ ${#repos[@]} -gt 0 ] || repos=("$d/.." ~/Projects/science/TOR-Telegram-Shop ~/iTools)
[ -f "$tok" ] || { echo "FAIL tokenizer: $tok not found"; exit 1; }
mkdir -p "$d/../.work"
est="$d/../.work/tok-est.json"; real="$d/../.work/tok-real.json"
: > "$est"; : > "$real"
for r in "${repos[@]}"; do
  (cd "$r" && "$d/../.bin/mokei" --tokens --json >> "$est" && "$d/../.bin/mokei" --tokenizer "$tok" --json >> "$real")
done
python3 -I - "$est" "$real" <<'PY'
import json, sys
def load(p):
    rows = {}
    for ln in open(p):
        for l in json.loads(ln)["languages"]:
            r = rows.setdefault(l["name"], [0, 0])
            r[0] += l["bytes"]; r[1] += l["tokens"]
    return rows
e, r = load(sys.argv[1]), load(sys.argv[2])
bad = 0
te = sum(v[1] for v in e.values()); tr = sum(v[1] for v in r.values())
print(f"{'language':<12}{'bytes':>10}{'estimate':>10}{'real':>10}{'error':>8}")
for k in sorted(r, key=lambda k: -r[k][1]):
    err = (e[k][1] - r[k][1]) / r[k][1] * 100
    flag = ""
    if r[k][0] >= 50000 and abs(err) > 10:
        flag = "  <== over 10%"; bad += 1
    print(f"{k:<12}{r[k][0]:>10}{e[k][1]:>10}{r[k][1]:>10}{err:>+7.1f}%{flag}")
terr = (te - tr) / tr * 100
print(f"{'total':<12}{'':>10}{te:>10}{tr:>10}{terr:>+7.1f}%")
if abs(terr) > 10: bad += 1
sys.exit(1 if bad else 0)
PY
