#!/usr/bin/env bash
# Copyright 2026 amarbaro.org. Licensed under the Apache License, Version 2.0.
# tokei vs mokei on the corpus. Needs tokei (oracle, installed only for this run).
# Usage: tools/parity.sh [REPO...]   default corpus below. Exit 1 on an unlisted diff.
set -euo pipefail
d="$(dirname "$(readlink -f "$0")")"
command -v tokei >/dev/null || { echo "FAIL tokei: not installed"; exit 1; }
[ -x "$d/../.bin/mokei" ] || { echo "FAIL mokei: build .bin/mokei first"; exit 1; }
repos=("$@")
[ ${#repos[@]} -gt 0 ] || repos=("$d/.." ~/Projects/science/TOR-Telegram-Shop ~/iTools ~/Projects/Modular/modular)
rc=0
for r in "${repos[@]}"; do python3 -I "$d/parity.py" "$r" || rc=1; done
exit $rc
