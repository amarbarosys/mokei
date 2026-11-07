# mokei

Line counter in Mojo, tokei-like: code, comment and blank lines per language, 42 languages from `languages.toml`.

Build: `$MOJO build mokei.mojo -o .bin/mokei` with a Mojo 1.2.0 venv that has the `max` package (e.g. `~/Projects/mojo/mojo-vattn/.venv/bin/mojo`; the mojo-uregex venv lacks it). Test: `tests/test_mokei.sh`.
Use: `mokei [FILE|DIR ...] [--json] [--files] [--sort code|lines|files]`. No args: `git ls-files`, else a walk of `.` honouring `.gitignore`. `MOKEI_JOBS=1` = serial. `MOKEI_LANGS=PATH` = another language table.
Status (2026-11-07): parity with tokei 15.0.0 on mokei, TOR-Telegram-Shop, iTools and modular (11.5k files) except the listed tokei bugs, `docs/known-diffs.md`. 67-71 ms against tokei 100 ms on modular (`tools/bench.sh`).
Tools: `tools/parity.sh` (tokei vs mokei, needs tokei installed for the run), `tools/frozen.py` (embedded languages against a saved tokei JSON), `tools/bench.sh`.
Plan: `docs/plan.md`; rules from the lane: `docs/rules.md`.
iTools entry: `~/iTools/dev/mokei` symlinks here.
