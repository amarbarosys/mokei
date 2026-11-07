# mokei

Line counter in Mojo, tokei-like: code, comment and blank lines per language over `git ls-files`.

Build: `$MOJO build mokei.mojo -o .bin/mokei` with a Mojo 1.2.0 venv that has the `max` package (e.g. `~/Projects/mojo/mojo-vattn/.venv/bin/mojo`). Test: `tests/test_mokei.sh`. `MOKEI_JOBS=1` = serial.
Status (2026-11-07): matches tokei on Python, CSS, YAML, TOML, INI, Dockerfile, Shell; beats it on JS nested template strings. Limits: one line-comment token per language, no embedded languages, serial.
iTools entry: `~/iTools/dev/mokei` symlinks here.
