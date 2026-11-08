#!/usr/bin/env bash
# Copyright 2026 amarbaro.org. Licensed under the Apache License, Version 2.0.
# tokei vs mokei on the corpus. Needs tokei 15.0.0 exactly (oracle, installed only for this run; the version is checked).
# Usage: tools/parity.sh [REPO...]   default corpus below. Exit 1 on an unlisted diff.
set -euo pipefail
d="$(dirname "$(readlink -f "$0")")"
command -v tokei >/dev/null || { echo "FAIL tokei: not installed"; exit 1; }
[ "$(tokei --version | awk '{print $2}')" = "15.0.0" ] || { echo "FAIL tokei: the oracle is pinned to 15.0.0, found $(tokei --version)"; exit 1; }
[ -x "$d/../.bin/mokei" ] || { echo "FAIL mokei: build .bin/mokei first"; exit 1; }
repos=("$@")
[ ${#repos[@]} -gt 0 ] || repos=("$d/..")
rc=0
for r in "${repos[@]}"; do python3 -I "$d/parity.py" "$r" || rc=1; done
exit $rc
