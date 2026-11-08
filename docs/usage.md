# Using mokei

Every command below was run from a scratch copy of `tests/fx` (and, for `--diff`, a three-commit repo); the output is pasted from that run. Build first: `./build.sh` (see the README). `mokei` here is `.bin/mokei`.

## Count

`mokei [FILE|DIR ...]`. A DIR is walked honouring `.gitignore`; no arguments means `git ls-files` in the current repo, else a walk of `.`. Languages come from `languages.toml` (40 rows). Rows are sorted by code lines.

```
$ mokei a.py b.js c.html
Language             Files     Lines      Code  Comments    Blanks
JavaScript               1         8         4         4         0
Python                   1         6         4         1         1
HTML                     1         3         1         1         1
Total                    3        17         9         6         2
```

Inside a repo with three tracked Python files:

```
$ mokei
Language             Files     Lines      Code  Comments    Blanks
Python                   3        38        31         4         3
Total                    3        38        31         4         3
```

### `--files`, `--sort`, `--json`

`--files` adds one row per file. `--sort code|lines|files` orders the language rows. `--json` prints one JSON object.

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

### Embedded languages

Code inside Markdown fences and in HTML `<script>`/`<style>` is counted under its own language as a child row. Markdown prose counts as comment lines, as in tokei.

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

In `--json` the children sit under `"children"`.

## `--semantic FILES`

Statements, functions, maximum nesting and cyclomatic complexity per file, from token rules (no parser). Python, Mojo, JavaScript, Rust, C. Rules: [semantic.md](semantic.md).

```
$ mokei --semantic sem/a.py sem/a.rs
File      Language       Stmts   Funcs    Nest   Cyclo
sem/a.py  Python            12       2       3       6
sem/a.rs  Rust               5       2       2       6
Total                       17       4       3      12
```

## `--diff A..B [--budget XS|S|M|L]`

Code, comment and blank lines added and removed between two revisions, per language, plus total lines of code before and after. With `--budget`, the exit status is 1 when the added code lines reach the limit (XS 20, S 60, M 150, L 400). Needs `git`. `--json` prints the same numbers as JSON.

```
$ mokei --diff HEAD~2..HEAD~1
Language       Files      +Code  +Comments    +Blanks      -Code  -Comments    -Blanks
Python             2          4          3          2          1          0          0
JavaScript         1          0          0          0          1          1          0
Total              3          4          3          2          2          1          0
loc: before 4 · after 6
```

Over budget (exit status 1, so a CI step fails):

```
$ mokei --diff HEAD~1..HEAD --budget XS
Language       Files      +Code  +Comments    +Blanks      -Code  -Comments    -Blanks
Python             1         25          0          0          0          0          0
Total              1         25          0          0          0          0          0
loc: before 0 · after 25
budget XS: 25 code lines added FAIL, must stay under 20
```

Under budget (exit status 0):

```
$ mokei --diff HEAD~1..HEAD --budget S
Language       Files      +Code  +Comments    +Blanks      -Code  -Comments    -Blanks
Python             1         25          0          0          0          0          0
Total              1         25          0          0          0          0          0
loc: before 0 · after 25
budget S: 25 code lines added < 60
```

## `--tokens [--tokenizer PATH]`

Bytes and tokens per language. Without `--tokenizer`, a fast estimate fitted to the Qwen2.5 tokenizer; with it, the real count from a Hugging Face `tokenizer.json` (single-threaded). Details and measured error: [tokens.md](tokens.md).

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

## `--dupes N`

Blocks of at least N consecutive normalized code lines (comments, blanks and spacing ignored) that occur twice.

```
$ mokei --dupes 5 dup/a.py dup/b.py
6 lines  dup/a.py:3-9  ==  dup/b.py:5-11
1 blocks, 6 duplicated code lines (blocks of >= 5 code lines)
```

## `--untested`

Definitions whose name appears in no test file. A test file sits in a `test`, `tests` or `__tests__` directory or is named `test_*`, `*_test.*`, `*.test.*` or `*.spec.*`. A hint, not coverage: a name match in a test file counts as tested. `main`, dunder names and `test*` are skipped; comments and strings are ignored.

```
$ mokei --untested lib.js lib.rs lib.test.js src.py test_src.py tests/it.rs
lib.js:2 jsUnused
lib.rs:2 rs_unused
src.py:4 unused
src.py:7 _private
src.py:11 method
5 untested of 8 defs (hint: a name match in a test file, nothing more)
```

## Environment

| variable | effect |
|---|---|
| `MOKEI_LANGS=PATH` | use another language table instead of `languages.toml` |
| `MOKEI_JOBS=1` | serial scan (the default is parallel; the output is identical) |

A new language is one `[[lang]]` row, no code (`tests/fx/extra.toml` is an example):

```
$ MOKEI_LANGS=extra.toml mokei d.foo
Language             Files     Lines      Code  Comments    Blanks
Foo                      1         5         1         3         1
Total                    1         5         1         3         1
```

## Errors

An unknown flag stops with a `FAIL args: ...` message and a non-zero exit:

```
$ mokei --bogus
Unhandled exception caught during execution: FAIL args: unknown flag --bogus
```

## Differences from tokei

[known-diffs.md](known-diffs.md): where tokei 15.0.0 is wrong and mokei is right, and where mokei chooses differently (binary files, shebangs). mokei reads `/proc/self/exe` to find `languages.toml` and `VERSION`, so it runs on Linux only.
