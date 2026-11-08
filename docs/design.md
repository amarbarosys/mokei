# mokei design

mokei counts lines with one byte-level state machine driven by a data table, so a new language is a `languages.toml` row, not code.

## Layout

| File | Role |
|---|---|
| `languages.toml` | 40 `[[lang]]` rows: extensions, filenames, shebangs, line comments, block pairs (nested flag), quotes, raw strings, prose flag |
| `core.mojo` | table loader, line scanner (`count_lines`), embedded splits (HTML `script`/`style`, Markdown fences), `.gitignore` walk |
| `mokei.mojo` | flags, output (table, `--files`, `--json`), mode dispatch |
| `diff.mojo` | `--diff A..B` and `--budget`: counts both revisions from `git show`, never the working tree |
| `semantic.mojo` | `--semantic`: token rules per language, no parser |
| `tokens.mojo` | `--tokens` estimate and `--tokenizer` real count (mojo-tokenizers) |
| `dupes.mojo` | `--dupes N`: hashed windows of normalized code lines |
| `untested.mojo` | `--untested`: definition names matched against test files |

## Memory and speed

- One `read_bytes` per file; the scanner works on a `Span[UInt8]`, no per-line strings.
- `skip_to` compares 32 bytes per step to jump to the next newline, quote or comment byte.
- Files are split over all cores (`parallelize`); each worker owns its result rows, merged once. `MOKEI_JOBS=1` gives the same bytes serially.
- Files with a NUL byte are skipped as binary.

## Rejected

- A real parser per language: 40 grammars to keep for a count tokei gets from the same token rules.
- Python or a tokei wrapper: the point is a Mojo tool with no runtime dependency at count time.
- Per-function complexity: `--semantic` stays per file; a per-function number needs a parser.
- Coverage in `--untested`: it is a name match and says so.

## Checks

`tests/test_mokei.sh` (tokei-derived expectations, see `tests/SOURCES.md`), `tests/negative.sh` (each check must fail on a broken expectation), `tools/parity.sh` (corpus run against tokei 15.0.0, needs tokei installed).
