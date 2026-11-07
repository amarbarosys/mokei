"""Oracle: tokei vs mokei on one repo, same file list (git ls-files), per-language diff.

Usage: parity.py REPO [--all]   exit 1 on a diff not listed in docs/known-diffs.md.
A diff row is KNOWN when "<repo basename> <Language>" appears in docs/known-diffs.md.
"""
import json, os, re, subprocess, sys

HERE = os.path.dirname(os.path.abspath(__file__))
ROOT = os.path.dirname(HERE)
# tokei splits some languages mokei keeps together
MERGE = {"C Header": "C", "C++ Header": "C++", "TSX": "TypeScript", "JSX": "JavaScript",
         "BASH": "Shell", "Zsh": "Shell", "Fish": "Shell"}

def die(step, why):
    print(f"FAIL {step}: {why}")
    sys.exit(2)

def tokei(repo, files):
    tot = {}
    batch, size = [], 0
    def flush():
        nonlocal batch, size
        if not batch:
            return
        p = subprocess.run(["tokei", "-o", "json", *batch], cwd=repo, capture_output=True, text=True)
        if p.returncode != 0:
            die("tokei", p.stderr[:200])
        d, _ = json.JSONDecoder().raw_decode(p.stdout)
        for k, v in d.items():
            if k == "Total":
                continue
            r = tot.setdefault(MERGE.get(k, k), [0, 0, 0, 0, 0])
            r[0] += len(v["reports"])
            r[1] += v["code"] + v["comments"] + v["blanks"]
            r[2] += v["code"]; r[3] += v["comments"]; r[4] += v["blanks"]
        batch, size = [], 0
    for f in files:
        batch.append(f); size += len(f) + 1
        if size > 100000:
            flush()
    flush()
    return tot

def mokei(repo):
    exe = os.environ.get("MOKEI_BIN", os.path.join(ROOT, ".bin", "mokei"))
    p = subprocess.run([exe], cwd=repo, capture_output=True, text=True)
    if p.returncode != 0:
        die("mokei", p.stderr[:200])
    out = {}
    for ln in p.stdout.splitlines()[1:]:
        w = ln.split()
        if w[0] != "Total":
            out[" ".join(w[:-5])] = [int(x) for x in w[-5:]]
    return out

def main():
    if len(sys.argv) < 2:
        die("args", "parity.py REPO")
    repo = os.path.abspath(sys.argv[1])
    base = os.path.basename(repo)
    files = [f for f in subprocess.run(["git", "ls-files", "-z"], cwd=repo, capture_output=True, text=True).stdout.split("\0") if f and not os.path.isdir(os.path.join(repo, f))]  # tokei follows dir symlinks, mokei skips them
    known = open(os.path.join(ROOT, "docs", "known-diffs.md")).read()
    t, m = tokei(repo, files), mokei(repo)
    supported = set(re.findall(r'^name = "(.*)"', open(os.path.join(ROOT, "languages.toml")).read(), re.M))
    bad = 0
    print(f"{base}: {'language':<12} {'files lines code comm blank':>30}   tokei | mokei")
    for lang in sorted(set(m) | {k for k in t if k in supported}):
        a, b = t.get(lang, [0] * 5), m.get(lang, [0] * 5)
        if a == b:
            if "--all" in sys.argv:
                print(f"  ok    {lang:<12} {a}")
            continue
        tag = "KNOWN" if f"{base} {lang}" in known else "DIFF "
        bad += tag == "DIFF "
        print(f"  {tag} {lang:<12} tokei {a}  mokei {b}")
    skipped = sorted(k for k in t if k not in supported)
    print(f"  tokei-only languages (not in mokei): {len(skipped)}")
    sys.exit(1 if bad else 0)

main()
