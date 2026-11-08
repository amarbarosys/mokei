# Changelog

Newest first.

## 0.1.0 (2026-11-08)

First public release. Line counter in Mojo, 42 languages from `languages.toml`, checked against tokei 15.0.0 (listed differences in `docs/known-diffs.md`).

- Counting: code, comments, blanks per language, embedded languages (HTML, Markdown), `.gitignore` walk, parallel scan, `--json`, `--files`, `--sort`.
- `--semantic`: statements, functions, nesting, cyclomatic per file.
- `--diff A..B [--budget XS|S|M|L]`: lines added and removed per language, exit 1 over budget.
- `--tokens [--tokenizer PATH]`: tokens per language, estimate or a real `tokenizer.json`.
- `--dupes N`: duplicated blocks of normalized code lines.
- `--untested`: definitions named in no test file.
- `--version`.
