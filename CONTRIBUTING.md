# Contributing to mokei

## The gate

Every change must keep the gate green, and the gate must be able to fail:

```
bash ci.sh      # build, then tests/test_mokei.sh; no GPU
```

A change to counting behavior adds a fixture row to `tests/test_mokei.sh` (or `tests/embedded.expected`) whose numbers come from a tokei run, not from a hand count; a hand count is only a cross-check. A test that cannot go red is not a test: the negative control in `tests/negative.sh` shows that a wrong count makes the check fail.

A change that claims a speedup shows `tools/bench.sh` output before and after.

## Sign-off (DCO)

Commits are signed off under the [Developer Certificate of Origin](https://developercertificate.org/) 1.1:

```
git commit -s
```

The `Signed-off-by:` line certifies that you wrote the change or have the right to submit it under the Apache-2.0 license. No CLA.

## Style

- Mojo is the implementation language. Python is allowed only as an oracle, kept in `tools/`.
- A new language is a row in `languages.toml`, no code.
- One fact, one home: numbers live in the file that produced them and are linked, not restated.
- No attribution trailers other than `Signed-off-by`.

## Copyright

Contributions are licensed under Apache-2.0. New source files carry the header line used throughout the repository. The copyright holder for the project is amarbaro.org.
