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

## embedded languages (A8)

The 26 probe files in `tests/fx/emb` match tokei exactly (`tests/embed-check.sh`). On the frozen HTML/Markdown corpus
(`.work/frozen`, 521 files copied from the four corpus repos, reference = one saved `tokei --no-ignore -o json`;
`tools/frozen.py`) 17 of 24 HTML files and 484 of 492 Markdown files match per file; the rest:

- HTML, 7 files: text on the `<script>`/`<style>` tag lines of multi-line blocks (`<script>(function(){` ... `})();</script>`),
  saved pages with `<script ...><!-- // --><![CDATA[` open lines (btt-0.html: tokei 76 child lines, mokei 118), a JS desync in
  tokei (server-dashboard: tokei 220 code 0 comment 0 blank, same line total), and `UN_charter_AR.html` where tokei counts a ~1700 line
  `<style>` block as JavaScript (JS 2231 vs 12, CSS 20 vs 1554). Cause per file is a guess; no tokei to probe now. Rows: `HTML`, `HTML |- CSS`, `HTML |- JavaScript`.
- Markdown, 8 files: fences nested inside longer fences or lists (`docstring-style-guide.md`: tokei 181 Mojo code lines, mokei 43), a fence tagged `wolfram` (no such language in mokei).
  Rows: `Markdown |- Mojo`, `Markdown |- Python`, `Markdown |- Shell`, `Markdown |- Wolfram`, and the Markdown parent lines.
- tokei skips hidden directories (`.github`, `.cache-pool`) even with `--no-ignore`; mokei counts them. `frozen.py` filters them out.
