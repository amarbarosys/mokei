"""Shared by parity.py and frozen.py: tokei JSON and mokei --json to {row name: [files, lines, code, comments, blanks]}.

A child row is named "<Parent> |- <Child>". tokei names that mokei merges are mapped (BASH, Zsh, Fish -> Shell, ...).
"""
import json

MERGE = {"C Header": "C", "C++ Header": "C++", "TSX": "TypeScript", "JSX": "JavaScript",
         "BASH": "Shell", "Zsh": "Shell", "Fish": "Shell"}


def add_json(rows, d):
    """Adds one tokei JSON document (a dict) into rows."""
    for lang, v in d.items():
        if lang == "Total":
            continue
        lang = MERGE.get(lang, lang)
        parts = [(lang, v["reports"])] + [(f"{lang} |- {MERGE.get(c, c)}", r) for c, r in v["children"].items()]
        for name, rs in parts:
            st = [sum(r["stats"][k] for r in rs) for k in ("code", "comments", "blanks")]
            cur = rows.setdefault(name, [0, 0, 0, 0, 0])
            for i, x in enumerate([len(rs), sum(st), *st]):
                cur[i] += x


def mokei_rows(text):
    """Rows of a `mokei --json` document, children included."""
    rows = {}
    keys = ("files", "lines", "code", "comments", "blanks")
    for l in json.loads(text)["languages"]:
        rows[l["name"]] = [l[k] for k in keys]
        for c in l.get("children", []):
            rows[f'{l["name"]} |- {c["name"]}'] = [c[k] for k in keys]
    return rows
