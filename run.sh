#!/usr/bin/env bash
# Copyright 2026 amarbaro.org. Licensed under the Apache License, Version 2.0.
# Launcher: rebuild when any source is newer than the binary, then run.
set -euo pipefail
d="$(dirname "$(readlink -f "$0")")"
b="$d/.bin/mokei"
if [ ! -x "$b" ] || [ -n "$(find "$d" -maxdepth 1 \( -name '*.mojo' -o -name languages.toml \) -newer "$b" -print -quit)" ]; then
    "$d/build.sh" >&2 || { echo "FAIL mokei build" >&2; exit 1; }
fi
exec "$b" "$@"
