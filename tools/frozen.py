# Copyright 2026 amarbaro.org. Licensed under the Apache License, Version 2.0.
"""Embedded-language parity on a frozen corpus: mokei --json vs a saved `tokei --no-ignore -o json DIR`.

Usage: frozen.py TOKEI_JSON DIR   (default .work/frozen/tokei.json .work/frozen/files)
The reference is a one-time capture (tokei is not installed); DIR holds copies of the HTML/Markdown files.
"""
import json, os, subprocess, sys

sys.path.insert(0, os.path.dirname(os.path.abspath(__file__)))
from tokeirows import add_json, mokei_rows

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
def tokei_rows(path):
    rows = {}
    add_json(rows, json.load(open(path)))
    return rows

def run_mokei(d):
    exe = os.environ.get("MOKEI_BIN", os.path.join(ROOT, ".bin", "mokei"))
    files = [os.path.join(r, f) for r, _, fs in os.walk(d) for f in fs
             if not any(x.startswith(".") for x in os.path.relpath(os.path.join(r, f), d).split(os.sep))]  # tokei skips hidden paths
    p = subprocess.run([exe, "--json", *files], capture_output=True, text=True)
    if p.returncode != 0:
        print("FAIL mokei:", p.stderr[:200]); sys.exit(2)
    return mokei_rows(p.stdout)

def main():
    ref = sys.argv[1] if len(sys.argv) > 1 else os.path.join(ROOT, ".work/frozen/tokei.json")
    d = sys.argv[2] if len(sys.argv) > 2 else os.path.join(ROOT, ".work/frozen/files")
    t, m = tokei_rows(ref), run_mokei(d)
    bad = 0
    for k in sorted(set(t) | set(m)):
        a, b = t.get(k, [0] * 5), m.get(k, [0] * 5)
        if a != b:
            bad += 1
            print(f"  DIFF {k:<28} tokei {a}  mokei {b}")
    print(f"frozen: {len(t)} rows, {bad} differ")
    sys.exit(1 if bad else 0)

main()
