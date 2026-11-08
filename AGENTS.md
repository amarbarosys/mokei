# Agents

Using mokei (sizing a repo or a change, diff budgets, tokens, duplicates, untested names): read `skills/mokei/SKILL.md`. Claude Code: `/plugin marketplace add amarbaro/mokei`, then install the `mokei` plugin.

Changing mokei: `pixi install`, then `pixi run gate` must stay green (build, `tests/test_mokei.sh`, the negative control). Rules in CONTRIBUTING.md. Sources are the `*.mojo` files at the repo root; `languages.toml` is the language table (a new language is a row, no code); `VERSION` is the only home of the version.
