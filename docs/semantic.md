# mokei --semantic

Per file (Python, Mojo, JavaScript, Rust, C), from token rules after comments and string bodies are blanked. No parser.

| metric | indentation family (Python, Mojo) | brace family (JavaScript, Rust, C) |
|---|---|---|
| statements | logical code lines (continuations joined) | `;` outside parentheses + each `if for while switch match loop try` |
| functions | `def`, `fn`, `async def` at line start | JS `function` and each `=>`; Rust `fn`; C `) {` at brace depth 0 |
| max nesting | indentation levels | brace depth |
| cyclomatic | 1 + `if elif for while except case and or` | 1 + `if for while && ||`; JS also `case catch ?? ?:`; Rust also match arms `=>`; C also `case ?:` |

Cyclomatic is per file (1 + all decisions), not per function. Known limits: JS regex literals holding quotes confuse the blanking; C macros are blanked (preprocessor lines).
Fixtures: `tests/fx/sem/a.*`, hand-counted, run by `tests/test_mokei.sh`.
