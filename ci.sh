#!/usr/bin/env bash
# Copyright 2026 amarbaro.org. Licensed under the Apache License, Version 2.0.
# CI gate, no GPU: build, then the full test runner, then the negative control.
# MOJO / MOKEI_TOKENIZERS / MOKEI_TEST_TOKENIZER override what is fetched or found on PATH.
set -euo pipefail
d="$(dirname "$(readlink -f "$0")")"; cd "$d"
TOK_TAG=v0.1.0                    # mojo-tokenizers release the build is checked against
QWEN_SHA=c0382117ea329cdf097041132f6d735924b697924d6f6fc3945713e96ce87539   # Qwen2.5-0.5B-Instruct tokenizer.json
export MOJO="${MOJO:-$(command -v mojo || true)}"
[ -x "$MOJO" ] || { echo "FAIL mojo: not on PATH (run through pixi, or set MOJO)"; exit 1; }
mkdir -p .work/deps .work/dl
if [ -z "${MOKEI_TOKENIZERS:-}" ]; then
    [ -d .work/deps/mojo-tokenizers/src ] || git clone -q --depth 1 --branch "$TOK_TAG" https://github.com/amarbaro/mojo-tokenizers .work/deps/mojo-tokenizers
    export MOKEI_TOKENIZERS="$d/.work/deps/mojo-tokenizers/src"
fi
if [ -z "${MOKEI_TEST_TOKENIZER:-}" ]; then
    t=.work/dl/tokenizer.json
    [ -f "$t" ] || curl -sSfL -o "$t" https://huggingface.co/Qwen/Qwen2.5-0.5B-Instruct/resolve/main/tokenizer.json
    echo "$QWEN_SHA  $t" | sha256sum -c --quiet - || { echo "FAIL tokenizer: sha256 of $t is not $QWEN_SHA"; exit 1; }
    export MOKEI_TEST_TOKENIZER="$d/$t"
fi
bash build.sh
bash tests/test_mokei.sh
bash tests/negative.sh
echo "PASS ci"
