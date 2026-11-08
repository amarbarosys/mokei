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

Count (`FILE|DIR ...`; a DIR honours `.gitignore`; no args = `git ls-files`, else walk `.`):

```
$ mokei a.py b.js c.html
Language             Files     Lines      Code  Comments    Blanks
JavaScript               1         8         4         4         0
Python                   1         6         4         1         1
HTML                     1         3         1         1         1
Total                    3        17         9         6         2
```

`--files` adds a row per file, `--sort code|lines|files`, `--json` for one JSON object:

```
$ mokei --files --sort lines a.py b.js
Language             Files     Lines      Code  Comments    Blanks
JavaScript               1         8         4         4         0
 b.js                    1         8         4         4         0
Python                   1         6         4         1         1
 a.py                    1         6         4         1         1
Total                    2        14         8         5         1
```

```
$ mokei --json a.py
{"languages":[{"name":"Python","files":1,"lines":6,"code":4,"comments":1,"blanks":1}],"total":{"files":1,"lines":6,"code":4,"comments":1,"blanks":1}}
```

Embedded languages (Markdown fences, HTML script/style) are child rows; Markdown prose counts as comments, like tokei:

```
$ mokei emb/e.md emb/h1.html
Language             Files     Lines      Code  Comments    Blanks
HTML                     1         2         2         0         0
 |- CSS                  1         2         1         0         1
 (Total)                           4         3         0         1
Markdown                 1        16         0        12         4
 |- Python               1         2         1         1         0
 (Total)                          18         1        13         4
Total                    2        22         4        13         5
```

`--semantic` (Python, Mojo, JavaScript, Rust, C; per file, token rules, no parser):

```
$ mokei --semantic sem/a.py sem/a.rs
File      Language       Stmts   Funcs    Nest   Cyclo
sem/a.py  Python            12       2       3       6
sem/a.rs  Rust               5       2       2       6
Total                       17       4       3      12
```

`--diff A..B` (needs git; `--budget XS|S|M|L` = 20/60/150/400 added code lines, exit 1 at or over):

```
$ mokei --diff HEAD~1..HEAD --budget XS
Language       Files      +Code  +Comments    +Blanks      -Code  -Comments    -Blanks
Python             1         25          0          0          0          0          0
Total              1         25          0          0          0          0          0
loc: before 0 · after 25
budget XS: 25 code lines added FAIL, must stay under 20
```

```
$ mokei --diff HEAD~1..HEAD --budget S
Language       Files      +Code  +Comments    +Blanks      -Code  -Comments    -Blanks
Python             1         25          0          0          0          0          0
Total              1         25          0          0          0          0          0
loc: before 0 · after 25
budget S: 25 code lines added < 60
```

`--tokens` (estimate fitted to Qwen2.5; `--tokenizer PATH` = real count from a Hugging Face `tokenizer.json`, single-threaded):

```
$ mokei --tokens a.py b.js
Language         Files       Bytes      Tokens  (estimate)
JavaScript           1          63          26
Python               1          60          25
Total                2         123          51
```

```
$ mokei --tokenizer tokenizer.json a.py
Language         Files       Bytes      Tokens  (tokenizer)
Python               1          60          24
Total                1          60          24
```

`--dupes N` (blocks of >= N normalized code lines seen twice):

```
$ mokei --dupes 5 dup/a.py dup/b.py
6 lines  dup/a.py:3-9  ==  dup/b.py:5-11
1 blocks, 6 duplicated code lines (blocks of >= 5 code lines)
```

`--untested` (names in no test file; a hint, not coverage):

```
$ mokei --untested lib.js lib.rs lib.test.js src.py test_src.py tests/it.rs
lib.js:2 jsUnused
lib.rs:2 rs_unused
src.py:4 unused
src.py:7 _private
src.py:11 method
5 untested of 8 defs (hint: a name match in a test file, nothing more)
```

`mokei --version` prints `mokei 0.1.0`. `MOKEI_JOBS=1` = serial scan (same output). `MOKEI_LANGS=PATH` = another language table:

```
$ MOKEI_LANGS=extra.toml mokei d.foo
Language             Files     Lines      Code  Comments    Blanks
Foo                      1         5         1         3         1
Total                    1         5         1         3         1
```

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
