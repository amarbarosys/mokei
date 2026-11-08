# mokei

A line counter in Mojo, like [tokei](https://github.com/XAMPPRocky/tokei), for 40 languages from a TOML table, plus questions tokei cannot answer: a size budget for a diff, tokens per language, duplicated blocks, definitions no test names.

**Verified against** tokei 15.0.0: the language rows of `tests/test_mokei.sh` and `tests/embedded.expected` are tokei runs (`tests/SOURCES.md` lists the expectations that are not), and mokei matched tokei on four corpora (this repo, a web app, a tool collection, and a Modular monorepo of 11.5k files) except the cases in [docs/known-diffs.md](docs/known-diffs.md), where tokei is wrong or mokei chose differently. The last full corpus run was 2026-11-07; later scanner changes were checked against the fixtures only. `tools/parity.sh` repeats the run when tokei 15.0.0 is installed. The test runner never needs tokei.

**Does not do:** parse code (the `--semantic` numbers come from token rules, per file, not per function), count more than the 40 languages in `languages.toml` unless you add a row, run off Linux (it finds its files through `/proc/self/exe`), or take tokei's flags (`--sort`, `--files` and `--json` exist; its other options do not). `--untested` is a name match, not coverage. `--tokens` without a tokenizer is an estimate (total within 3% of the Qwen2.5 count on the corpora measured, each language of 50 kB or more within 6%, [docs/tokens.md](docs/tokens.md)).

```
$ mokei a.py b.js c.html
Language             Files     Lines      Code  Comments    Blanks
JavaScript               1         8         4         4         0
Python                   1         6         4         1         1
HTML                     1         3         1         1         1
Total                    3        17         9         6         2
```

## Build and test

Needs [pixi](https://pixi.sh), `git` and `curl`. pixi installs Mojo 1.2.0 and the `max` package; the gate fetches `mojo-tokenizers` v0.1.0 and a checksummed Qwen2.5 `tokenizer.json`.

```
git clone https://github.com/amarbarosys/mokei && cd mokei   # after publication
pixi install
pixi run gate        # build, tests/test_mokei.sh, negative control; no GPU
.bin/mokei --version
```

Without pixi: `MOJO=/path/to/mojo MOKEI_TOKENIZERS=/path/to/mojo-tokenizers/src ./build.sh`, then `tests/test_mokei.sh` (set `MOKEI_TEST_TOKENIZER` to a Qwen2.5 `tokenizer.json`).

## Modes

```
mokei [FILE|DIR ...] [--json] [--files] [--sort code|lines|files]    count (no args: git ls-files, else walk .)
mokei --semantic FILES                 statements, functions, nesting, cyclomatic
mokei --diff A..B [--budget XS|S|M|L]  code/comment/blank added and removed, exit 1 over budget
mokei --tokens [--tokenizer PATH]      tokens per language: estimate or a real tokenizer.json
mokei --dupes N                        blocks of >= N normalized code lines seen twice
mokei --untested                       defs named in no test file (a hint)
mokei --version
```

`MOKEI_JOBS=1` scans serially, `MOKEI_LANGS=PATH` loads another language table. Every mode with a real command and its output: [docs/usage.md](docs/usage.md). Docs index: [docs/README.md](docs/README.md).

## For agents

`skills/mokei/SKILL.md` (also a Claude Code plugin, `.claude-plugin/marketplace.json`) teaches an agent when and how to run mokei. See [AGENTS.md](AGENTS.md).

## License

Apache-2.0, see [LICENSE](LICENSE) and [NOTICE](NOTICE). Contributing: [CONTRIBUTING.md](CONTRIBUTING.md). Changes: [CHANGELOG.md](CHANGELOG.md).
