---
name: mokei
description: "Count lines, tokens, diffs, duplicates and untested names with mokei (Mojo, tokei-like). Use when sizing a repo or a change, budgeting a diff (XS/S/M/L), estimating the LLM tokens of source, finding duplicated blocks or definitions no test names, or checking mokei against tokei."
metadata:
  short-description: "mokei: line counts per language, diff budgets, tokens, dupes, untested names"
  owner: amarbaro.org
  license: Apache-2.0
  origin: own
---

# mokei

## When to use

- How big is this repo or change: `mokei`, `mokei --diff A..B --budget S` (a size gate, exit 1 when over).
- How many LLM tokens is this source: `mokei --tokens` (estimate) or `--tokenizer tokenizer.json` (real).
- Is code copied: `--dupes N`. Which defs does no test name: `--untested`. How complex: `--semantic`.

Not for: other languages than the 40 in `languages.toml` (add a `[[lang]]` row, no code), real coverage, per-function complexity, non-Linux.

## Setup

Build once: `pixi install && pixi run gate` in the mokei checkout, binary `.bin/mokei` (or `MOJO=... MOKEI_TOKENIZERS=... ./build.sh`). Below, `mokei` is that binary. Outputs were pasted from real runs on the repo's `tests/fx` fixtures.

## Modes

All outputs with real runs: `docs/usage.md`. Count example (tokei-style table):

```
$ mokei a.py b.js c.html
Language             Files     Lines      Code  Comments    Blanks
JavaScript               1         8         4         4         0
Python                   1         6         4         1         1
HTML                     1         3         1         1         1
Total                    3        17         9         6         2
```

| Call | Answers |
|---|---|
| `mokei [FILE\|DIR ...]` | lines per language; DIR honours `.gitignore`; no args = `git ls-files` |
| `--files`, `--sort code\|lines\|files`, `--json` | per-file rows, order, one JSON object |
| `--semantic` | statements, funcs, nesting, cyclomatic per file (Python, Mojo, JS, Rust, C) |
| `--diff A..B --budget XS\|S\|M\|L` | added/removed lines; exit 1 at or over 20/60/150/400 added code lines |
| `--tokens` / `--tokenizer tokenizer.json` | token estimate (Qwen2.5 fit) / real count |
| `--dupes N` | blocks of >= N normalized code lines seen twice |
| `--untested` | defs no test file names (a hint, not coverage) |
| `--version`, `MOKEI_JOBS=1`, `MOKEI_LANGS=PATH` | version, serial scan, other language table |

Embedded languages (Markdown fences, HTML script/style) are child rows; Markdown prose counts as comments, like tokei.

## Known differences from tokei 15.0.0

Full list: `docs/known-diffs.md`. mokei is right where tokei misparses a quote inside a regex literal, a JSX apostrophe, `'"'` char literals in C/C++, a quote in a Mojo backtick name, or drops a first-line Rust `//! doc`. mokei chooses differently for files with a NUL byte (skipped as binary) and for shebang detection (`python`, `node`, `lua`, `mojo` accepted without `env`). On HTML and Markdown corpora most files match per file; a few differ on nested fences and tag-line text.

## Gotchas

- Unknown flag: `FAIL args: unknown flag --bogus`, exit 1. A flag that takes a value (`--dupes`, `--tokenizer`, `--diff`, `--budget`, `--sort`) at the end of the line is treated as an unknown flag.
- `--budget` fires at `>=` the limit: 20 added code lines fail XS.
- `--diff` counts code lines of the two revisions as they are committed; the working tree is not read.
- `--semantic` cyclomatic is per file (1 + all decisions), not per function.
- `--untested` ignores comments and strings, skips `main`, dunder names and `test*`; a name in any test file counts as tested.
- The estimate of `--tokens` suits a Qwen-like tokenizer; Llama 3 groups digits by 3, so number-heavy files drift. Use `--tokenizer` for a real count.
- Linux only: mokei finds `languages.toml` and `VERSION` one directory above its binary through `/proc/self/exe`; keep `.bin/mokei` inside the checkout (or set `MOKEI_LANGS`).
