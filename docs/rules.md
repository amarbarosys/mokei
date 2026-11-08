# Rules (what broke -> the rule)

- 2026-11-07: a probe command did `cd dir && rm -f *` aimed at the repo root (denied by the user) -> never run `rm` in the repo root or with a glob there; tokei and fixture experiments live only in `.work/scratch/`, delete by exact path.
- 2026-11-07: `len(String)` is an error on Mojo 1.2 -> `.byte_length()`.
- 2026-11-07: a `List` negative index `xs[-1]` is a compile error -> `xs[len(xs) - 1]` (helper `last()`).
- 2026-11-07: `String` has no `s[a:b]` slice syntax -> work on `as_bytes()` indices (the `s[byte=a:b]` form needs a temporary to avoid an aliasing error).
- 2026-11-07: a fixture hand-count disagreed with tokei and cost a round -> expectations come from a tokei run, hand counts only as a cross-check (a blank line inside a block comment is a comment).
- 2026-11-07: `String(span_of_bytes)` builds a list repr, not text, and the walk silently matched nothing -> `String(unsafe_from_utf8=span)`; a test that counts only the pass case would not have caught it, the ignore fixture has a case per rule kind.
- 2026-11-07: `std.subprocess.run` drops trailing newlines of the output, so `git show` content lost its last blank lines and --diff under-counted blanks -> a line number past the end of the classified lines is a blank line; any byte-exact content comes from `open(...).read_bytes()` not `run`.
- 2026-11-08: the README claimed 42 languages and `languages.toml` has 40 rows -> a number in the README comes from a command run in the same sitting (`grep -c '^\[\[lang\]\]' languages.toml`), never from the older README.
- 2026-11-08: `gh-publish --help` took `--help` as the repo name (the tool has no help flag) -> read a tool's `tool.toml`/script head before probing it with flags.
- 2026-11-08: an example capture wrote `../../x.txt` from a `cd`-ed subshell and failed -> redirects in a captured block use an absolute path.
- 2026-11-08: a pasted output block can drift from the code -> docs/usage.md and skills/mokei/SKILL.md are regenerated from a run (examples copied from `tests/fx`), never edited by hand in the output lines.
