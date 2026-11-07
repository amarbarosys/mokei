#!/usr/bin/env bash
# hyperfine: mokei (parallel and MOKEI_JOBS=1) vs tokei, run inside REPO (default: the large corpus repo).
# Usage: tools/bench.sh [REPO] [RUNS]   mokei reads git ls-files, tokei walks the tree with ignore rules.
set -euo pipefail
d="$(dirname "$(readlink -f "$0")")"
repo="${1:-$HOME/Projects/Modular/modular}"; runs="${2:-10}"
command -v hyperfine >/dev/null || { echo "FAIL hyperfine: not installed"; exit 1; }
cmds=(-n mokei "$d/../.bin/mokei" -n mokei-serial "env MOKEI_JOBS=1 $d/../.bin/mokei")
if command -v tokei >/dev/null; then cmds+=(-n tokei tokei); else echo "note: tokei not installed, mokei only"; fi
[ -x "$d/../.bin/mokei" ] || { echo "FAIL mokei: build .bin/mokei first"; exit 1; }
mkdir -p "$d/../.work"
cd "$repo"
export MOKEI_LANGS="$d/../languages.toml"
hyperfine -N --warmup 2 --runs "$runs" --export-json "$d/../.work/bench.json" \
  "${cmds[@]}" \
  | grep -E "Benchmark|Time|Range"
python3 -I - "$d/../.work/bench.json" <<'PY'
import json, sys
r = {x.get("name", x["command"]): (x["summary"]["time_wall_clock"]["mean"], x["summary"]["time_cpu"]["mean"]) for x in json.load(open(sys.argv[1]))["results"]}
w = {k: v[0] * 1000 for k, v in r.items()}
print("wall ms: " + " · ".join(f"{k} {v:.1f}" for k, v in w.items()) + (f" · tokei/mokei {w['tokei'] / w['mokei']:.2f}x" if "tokei" in w else ""))
print("cpu ms:  " + " · ".join(f"{k} {v[1] * 1000:.0f}" for k, v in r.items()))
PY
