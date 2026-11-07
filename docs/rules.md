# Rules (what broke -> the rule)

- 2026-11-07: a probe command did `cd dir && rm -f *` aimed at the repo root (denied by the user) -> never run `rm` in the repo root or with a glob there; tokei and fixture experiments live only in `.work/scratch/`, delete by exact path.
