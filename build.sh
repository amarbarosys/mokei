#!/usr/bin/env bash
# Copyright 2026 amarbaro.org. Licensed under the Apache License, Version 2.0.
# Builds .bin/mokei. MOJO: a Mojo 1.2.0 with the max package; MOKEI_TOKENIZERS: src dir of mojo-tokenizers.
set -euo pipefail
d="$(dirname "$(readlink -f "$0")")"
mojo="${MOJO:-$HOME/Projects/mojo/mojo-vattn/.venv/bin/mojo}"
tok="${MOKEI_TOKENIZERS:-$HOME/Projects/mojo/mojo-tokenizers/src}"
[ -x "$mojo" ] || { echo "FAIL mojo: $mojo not found (set MOJO)"; exit 1; }
[ -d "$tok/tokenizers" ] || { echo "FAIL tokenizers: $tok/tokenizers not found (set MOKEI_TOKENIZERS)"; exit 1; }
mkdir -p "$d/.bin"
cd "$d" && "$mojo" build -I "$tok" mokei.mojo -o .bin/mokei
