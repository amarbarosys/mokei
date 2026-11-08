# mokei upgrade plan (2026-11-07)

Thesis: mokei already matches tokei on 8 languages and is right where tokei is wrong; it becomes worth keeping when it is faster than tokei on a large repo and answers questions tokei cannot (diff budgets, tokens, duplicates).

Order: tokei parity + speed first (Phase A), then agent-facing features (Phase B).
Toolchain: Mojo 1.2.0 (`$MOJO`).
Oracle: tokei, installed only for a comparison run and removed after.
Corpus for parity/speed: this repo and three other repos (a Python/JS web app, a shell and Python tool collection, and the Modular monorepo, 11.5k files).

## Phase A: parity + speed

| id | item | given → must | check | size |
|---|---|---|---|---|
| A1 | `languages.toml` data file | table moves out of code; rows: name, exts, filenames, line comments (list), block pairs (list, nested flag), quotes, raw strings, prose flag | existing fixtures unchanged; adding a row needs no code | M |
| A2 | multi-token comments | INI `;`+`#`, Lua `--[[ ]]`, nested Rust/Swift block comments, Python `r"..."`, C++ raw strings | one fixture per token kind, hand-counted and matched against tokei | S |
| A3 | top-40 languages | rows for tokei's 40 most common languages | `tools/parity.sh`: tokei vs mokei on the corpus, diff per language; known tokei bugs (JS `${}` in template strings) listed in `docs/known-diffs.md` | M |
| A4 | parallel scan | files split over all cores (`std.algorithm.parallelize`), results merged | same output as serial, byte for byte | S |
| A5 | fast line scan | one read per file, SIMD search for newline and special bytes, fast path for lines with no special bytes | `tools/bench.sh` with hyperfine, mokei vs tokei on the large repo, numbers in the commit | M |
| A6 | gitignore walk without git | `mokei DIR` walks the tree honouring `.gitignore`; `git ls-files` stays the default inside a repo | fixture tree with ignores | M |
| A7 | output formats | `--json`, `--files` (per file), `--sort code|lines|files` | golden JSON fixture | S |
| A8 | embedded languages | `<script>`/`<style>` in HTML, fenced code in Markdown, counted as child languages like tokei's `(Total)` | parity on HTML/MD rows of the corpus | M |

## Phase B: leading features

| id | item | given → must | check | size |
|---|---|---|---|---|
| B1 | semantic LOC | `--semantic`: per file statements, functions, max nesting, cyclomatic estimate for Py/Mojo/JS/Rust/C by token rules (no full parser) | hand-counted fixtures | L |
| B2 | diff LOC | `mokei --diff A..B`: code/comment/blank added and removed per language, from `git diff` plus reclassification of changed lines | fixture repo with two commits | M |
| B3 | budget gate | `mokei --budget XS|S|M|L --diff A..B` exits non-zero above the size (XS<20 S<60 M<150 L<400 code lines); prints the `loc: before N · after M` line for commit bodies | exit codes on fixture diffs | S |
| B4 | token count | `--tokens`: tokens per language/file; default byte-level estimate, `--tokenizer PATH` loads a real `tokenizer.json` (BPE merges) | estimate within 10% of the real tokenizer on the corpus, measured | L |
| B5 | duplicates | `--dupes N`: blocks of ≥N normalized code lines seen twice (rolling hash), with file:line pairs | fixture with a planted duplicate | M |
| B6 | dead-code hint | `--untested`: defs never referenced from test files (name match), reported as a hint, not a verdict | fixture | M |

## Rules for the lane
- Commit per item: conventional subject, why-body, numbers (bench, LOC) in the body. No attribution trailers.
- Every item adds its fixture to `tests/` and keeps `tests/test_mokei.sh` green (grow it into one runner).
- Python only as oracle in `tools/`. Scripts `set -euo pipefail`, `FAIL <step>: <reason>`.
- A mistake that costs a turn goes in `docs/rules.md`, same commit.
- A design call the plan cannot settle: smallest choice, flagged at the top of the report.
- Blocked means two approaches tried, evidence in the report.
