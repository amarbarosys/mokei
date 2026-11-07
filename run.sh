#!/usr/bin/env bash
# Launcher for ~/iTools/bin/mokei: rebuild when any source is newer than the binary, then run.
set -euo pipefail
d="$(dirname "$(readlink -f "$0")")"
b="$d/.bin/mokei"
if [ ! -x "$b" ] || [ -n "$(find "$d" -maxdepth 1 \( -name '*.mojo' -o -name languages.toml \) -newer "$b" -print -quit)" ]; then
    "$d/build.sh" >&2 || { echo "FAIL mokei build" >&2; exit 1; }
fi
exec "$b" "$@"
