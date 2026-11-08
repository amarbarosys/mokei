# Security

Report vulnerabilities privately to dev@amarbaro.com. Do not open a public issue for a security problem.

You will get an acknowledgement within 7 days. Fixed issues are noted in `CHANGELOG.md` with credit if you want it.

Scope: mokei reads files and, for `--diff`, runs `git`. A crash, an abort, an out-of-bounds read, or memory or time out of proportion to the input on a crafted source file, `.gitignore`, `languages.toml` (`MOKEI_LANGS`) or `tokenizer.json` is in scope. A way to make `--diff A..B` run anything other than `git show`/`git diff` on the named revisions is in scope.
