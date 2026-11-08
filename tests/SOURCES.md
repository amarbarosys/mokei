# Provenance of the test fixtures

All files under `tests/fx/` are small snippets written for mokei (a few lines each; no third-party text is copied). They are released under the repository's Apache-2.0 license.

| path | what | where the expected numbers come from |
|---|---|---|
| `fx/*.py`, `*.js`, `*.go`, `*.rs`, `*.cpp`, `*.swift`, `*.lua`, `*.html`, `*.ini`, `sb`, `cont.py`, `raw2.cpp`, `tpl.js` | one construct per file (raw strings, continuations, template strings, shebang, nested blocks) | the rows in `tests/test_mokei.sh`, from a tokei 15.0.0 run on 2026-11-07 |
| `fx/emb/` | 26 HTML and Markdown probes with embedded languages | `tests/embedded.expected`, from tokei 15.0.0 JSON |
| `fx/sem/`, `fx/dup/`, `fx/unt/` | inputs for `--semantic`, `--dupes`, `--untested` | counted by hand (tokei has no such modes); rules in `docs/semantic.md` |
| `fx/extra.toml`, `fx/d.foo` | a language row added through `MOKEI_LANGS` | counted by hand (tokei cannot load the extra row) |
| `golden.json`, `golden-files.json` | mokei's own `--json` output, frozen | mokei; counts agree with the tokei rows above |

The tokenizer used by the `--tokens` test is not stored here. `ci.sh` downloads Qwen2.5-0.5B-Instruct's `tokenizer.json` (Apache-2.0, Alibaba Cloud) and checks its sha256 before use.

Oracle versions: tokei 15.0.0 (checked by `tools/parity.sh`), CPython 3.13 (pinned in `pixi.toml`, used only for JSON checks).

Removal contact: dev@amarbaro.com.
