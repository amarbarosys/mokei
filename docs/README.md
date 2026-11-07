# mokei

Line counter in Mojo, tokei-like, plus questions tokei cannot answer. 42 languages from `languages.toml`.

Build: `./build.sh` (needs a Mojo 1.2.0 venv with the `max` package, default `~/Projects/mojo/mojo-vattn/.venv/bin/mojo`, and the `mojo-tokenizers` source via `MOKEI_TOKENIZERS`; the mojo-uregex venv has no `max`). Test: `tests/test_mokei.sh`.
Files: `mokei.mojo` (arguments, output), `core.mojo` (table, scanner, embedded languages, walk), `semantic.mojo`, `diff.mojo`, `tokens.mojo`, `dupes.mojo`, `untested.mojo`.

```
mokei [FILE|DIR ...] [--json] [--files] [--sort code|lines|files]    count (no args: git ls-files, else walk . honouring .gitignore)
mokei --semantic FILES                 statements, functions, nesting, cyclomatic      docs/semantic.md
mokei --diff A..B [--budget XS|S|M|L]  code/comment/blank added and removed, loc line, exit 1 over budget
mokei --tokens [--tokenizer PATH]      tokens per language: estimate or real tokenizer.json   docs/tokens.md
mokei --dupes N                        blocks of >= N normalized code lines seen twice
mokei --untested                       defs named in no test file (a hint)
```
`MOKEI_JOBS=1` = serial scan. `MOKEI_LANGS=PATH` = another language table.

Status (2026-11-07): parity with tokei 15.0.0 on mokei, TOR-Telegram-Shop, iTools and modular (11.5k files) except the listed tokei bugs (`docs/known-diffs.md`); 67-71 ms against tokei 100 ms on modular. Last tokei parity run was at A5; tokei is removed, later scanner changes were checked against the A5 binary (identical outside HTML/Markdown) and `tests/embed-check.sh`.
Tools: `tools/parity.sh` (tokei vs mokei, needs tokei installed for the run), `tools/frozen.py` (embedded languages against a saved tokei JSON), `tools/bench.sh`, `tools/token-measure.sh`.
Plan: `docs/plan.md`; rules from the lane: `docs/rules.md`. Report: `.work/report-upgrade.md` (local).
iTools entry: `~/iTools/dev/mokei` symlinks here.
