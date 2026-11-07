# Known diffs vs tokei 15.0.0

`tools/parity.py` marks a row KNOWN when `<repo basename> <Language>` appears below.
A row stays here only with a cause; delete it when the cause is fixed.

## tokei bugs (mokei is right)

- JavaScript: a regex literal holding a quote (`/[&<>"']/g`) opens a string in tokei that never closes, so every later blank line in the file counts as code. Fixture: `let r = /[&"]/g;` + blank line: tokei 3 code 0 blank, mokei 2 code 1 blank. Rows: `TOR-Telegram-Shop JavaScript`, `iTools JavaScript` (4 files).
- JavaScript, TypeScript: an apostrophe in JSX text (`don't`) also opens a never-closing string in tokei. Rows: `modular JavaScript` (docs/requirements.js), `modular TypeScript` (`/[^'`"\{\}\\]/` regexes in cmMode.ts; independent grep count: 44 comment and 53 blank lines, mokei 44 and 53, tokei 39 and 29).
- C, C++: the char literals `'"'` and `'\''` desync tokei, so blank lines after them count as code (fixture: 3-line `SetQuote('"')` snippet, tokei 6 code 0 blank, mokei 5 and 1). Row: `modular C++`.
- Mojo: a quote inside a backtick identifier (`` comptime `'` = 1 ``) desyncs tokei (tokei 4 code, mokei 2 code 1 comment 1 blank). A `"Hello` with no closing quote continues onto the next line in tokei (lexer test files, Mojo and Python semantics say a plain string ends at the line end). A `"""` string opened after code (`comptime X = """# ..."""`) has its `#` lines counted as comments by tokei. Row: `modular Mojo` (4 files).
- Rust: a first line `//! doc` is dropped, neither code nor comment nor blank (tokei 1 code 0 comment for `//! doc` + `fn a() {}`). Rows: `iTools Rust`, `mokei Rust`.

## mokei choices

- Files holding a NUL byte are skipped as binary; tokei counts them as source. Row: `iTools Python` (one 3-byte fixture `a\0b`).
- Interpreter detection: mokei reads the shebang of extensionless files and also accepts `python`, `node`, `lua`, `mojo` as `#!/usr/bin/python`; tokei only accepts some `env` forms.

## open until A8 (embedded languages)

- HTML and Markdown rows: tokei moves `<script>`, `<style>` and fenced code blocks to child languages; mokei counts them in the parent. Rows: `iTools HTML`, `iTools Markdown`, `TOR-Telegram-Shop HTML`, `TOR-Telegram-Shop Markdown`, `mokei Markdown`, `modular HTML`, `modular Markdown`.
