# Rules (what broke -> the rule)

- 2026-11-07: a probe command did `cd dir && rm -f *` aimed at the repo root (denied by the user) -> never run `rm` in the repo root or with a glob there; tokei and fixture experiments live only in `.work/scratch/`, delete by exact path.
- 2026-11-07: `len(String)` is an error on Mojo 1.2 -> `.byte_length()`.
- 2026-11-07: a `List` negative index `xs[-1]` is a compile error -> `xs[len(xs) - 1]` (helper `last()`).
- 2026-11-07: `String` has no `s[a:b]` slice syntax -> work on `as_bytes()` indices (the `s[byte=a:b]` form needs a temporary to avoid an aliasing error).
- 2026-11-07: a fixture hand-count disagreed with tokei and cost a round -> expectations come from a tokei run, hand counts only as a cross-check (a blank line inside a block comment is a comment).
- 2026-11-07: `String(span_of_bytes)` builds a list repr, not text, and the walk silently matched nothing -> `String(unsafe_from_utf8=span)`; a test that counts only the pass case would not have caught it, the ignore fixture has a case per rule kind.
