# Copyright 2026 amarbaro.org. Licensed under the Apache License, Version 2.0.
# mokei --diff A..B [--budget XS|S|M|L]: code, comment and blank lines added and removed per language.
# git supplies the changed line numbers (diff --unified=0); every changed line is classified in the file as it
# stands on its own side (old content for removed lines, new content for added lines), so a line that turns from
# code into comment is counted as code removed and comment added.
from std.subprocess import run
from core import Lang, count_lines, jstr, lang_of, pad


def shq(s: String) -> String:
    """Single-quoted shell word."""
    var o = String("'")
    for c in s.as_bytes():
        o += "'\\''" if c == 39 else chr(Int(c))
    return o + "'"


def limit(size: String) raises -> Int:
    """Code lines a change of this size stays under: XS 20, S 60, M 150, L 400."""
    if size == "XS":
        return 20
    if size == "S":
        return 60
    if size == "M":
        return 150
    if size == "L":
        return 400
    raise Error("FAIL args: --budget takes XS, S, M or L")


def num(s: String) raises -> Int:
    return atol(s)


def tally(mut row: List[Int], kinds: List[UInt8], start: Int, cnt: Int, off: Int):
    """Adds the classes of lines start..start+cnt-1 (1-based) of kinds to row[off..off+2] (code, comment, blank)."""
    for ln in range(start, start + cnt):
        if ln >= 1:  # run() drops trailing newlines: a line past the end of kinds is a blank one
            row[off + (Int(kinds[ln - 1]) if ln <= len(kinds) else 3) - 1] += 1


def show(rev: String, path: String) -> String:
    try:
        return run("git show " + shq(rev + ":" + path) + " 2>/dev/null")
    except:
        return ""


def diff_report(spec: String, budget: String, L: List[Lang], by_name: Dict[String, Int], by_ext: Dict[String, Int], by_sh: Dict[String, Int], as_json: Bool) raises -> Int:
    """Prints the diff table; returns the process exit code (1 when over budget)."""
    var ends = spec.split("..")
    if len(ends) != 2 or ends[0].byte_length() == 0 or ends[1].byte_length() == 0:
        raise Error("FAIL args: --diff takes A..B")
    var a = String(ends[0])
    var b = String(ends[1])
    var lim = limit(budget) if budget != "" else 0
    var text = run("git diff --unified=0 --no-color --no-ext-diff --no-renames " + shq(a + ".." + b))
    # per language: files, +code, +comment, +blank, -code, -comment, -blank
    var rows = List[List[Int]]()
    for _ in range(len(L)):
        rows.append([0, 0, 0, 0, 0, 0, 0])
    var before = 0
    var after = 0
    var path = String("")
    var k = -1
    var oldk = List[UInt8]()
    var newk = List[UInt8]()
    var hunks = List[List[Int]]()  # per file: old start, old count, new start, new count
    var nosh = Dict[String, Int]()  # no shebang detection: file names only

    var lines = text.split("\n")
    var li = 0
    while li <= len(lines):
        var ln = String(lines[li]) if li < len(lines) else String("diff --git end")
        li += 1
        if ln.startswith("diff --git"):
            if k >= 0 and len(hunks) > 0:
                rows[k][0] += 1
                for h in hunks:
                    tally(rows[k], oldk, h[0], h[1], 4)
                    tally(rows[k], newk, h[2], h[3], 1)
            k = -1
            hunks = List[List[Int]]()
            path = ""
            continue
        if ln.startswith("+++ "):
            var p = cut_from(ln, 4)
            if p == "/dev/null":
                p = path
            elif p.startswith("b/"):
                p = cut_from(p, 2)
            path = p
        elif ln.startswith("--- "):
            var p = cut_from(ln, 4)
            path = cut_from(p, 2) if p.startswith("a/") else String("")
        elif ln.startswith("@@ "):
            if k < 0:
                k = lang_of(path, by_name, by_ext, nosh) if path.byte_length() > 0 else -1
                if k >= 0:
                    var res: List[Int] = [0, 0, 0, 0]
                    oldk = List[UInt8]()
                    newk = List[UInt8]()
                    var ob = show(a, path)
                    var nb = show(b, path)
                    count_lines[True](ob.as_bytes(), L[k], res, oldk)
                    before += res[1]
                    res = [0, 0, 0, 0]
                    count_lines[True](nb.as_bytes(), L[k], res, newk)
                    after += res[1]
            if k >= 0:
                var w = ln.split(" ")
                var o = String(w[1]).split(",")
                var n2 = String(w[2]).split(",")
                var os = num(cut_from(String(o[0]), 1))
                var oc = num(String(o[1])) if len(o) > 1 else 1
                var ns = num(cut_from(String(n2[0]), 1))
                var nc = num(String(n2[1])) if len(n2) > 1 else 1
                hunks.append([os, oc, ns, nc])
    var tot: List[Int] = [0, 0, 0, 0, 0, 0, 0]
    var order = List[Int]()
    for i in range(len(L)):
        if rows[i][0] > 0:
            order.append(i)
            for j in range(7):
                tot[j] += rows[i][j]
    var added = tot[1]
    var over = lim > 0 and added >= lim
    var verdict = String("")
    if lim > 0:
        verdict = "budget " + budget + ": " + String(added) + " code lines added " + ("FAIL, must stay under " if over else "< ") + String(lim)
    var locline = "loc: before " + String(before) + " · after " + String(after)
    var keys = ["files", "code", "comments", "blanks"]
    if as_json:
        var js = String('{"diff":' + jstr(spec) + ',"languages":[')
        for oi in range(len(order)):
            var i = order[oi]
            js += (',' if oi > 0 else '') + '{"name":' + jstr(L[i].name) + ',"files":' + String(rows[i][0])
            js += ',"added":{"code":' + String(rows[i][1]) + ',"comments":' + String(rows[i][2]) + ',"blanks":' + String(rows[i][3]) + "}"
            js += ',"removed":{"code":' + String(rows[i][4]) + ',"comments":' + String(rows[i][5]) + ',"blanks":' + String(rows[i][6]) + "}}"
        js += '],"total":{"files":' + String(tot[0])
        js += ',"added":{"code":' + String(tot[1]) + ',"comments":' + String(tot[2]) + ',"blanks":' + String(tot[3]) + "}"
        js += ',"removed":{"code":' + String(tot[4]) + ',"comments":' + String(tot[5]) + ',"blanks":' + String(tot[6]) + "}}"
        js += ',"loc":{"before":' + String(before) + ',"after":' + String(after) + "}"
        if lim > 0:
            js += ',"budget":{"size":"' + budget + '","limit":' + String(lim) + ',"added_code":' + String(added) + ',"ok":' + ("false" if over else "true") + "}"
        print(js + "}")
        return 1 if over else 0
    var hdr = pad("Language", 12, True) + pad("Files", 8, False)
    for h in ["+Code", "+Comments", "+Blanks", "-Code", "-Comments", "-Blanks"]:
        hdr += pad(String(h), 11, False)
    print(hdr)
    for i in order:
        var row = pad(L[i].name, 12, True)
        for j in range(7):
            row += pad(String(rows[i][j]), 8 if j == 0 else 11, False)
        print(row)
    var trow = pad("Total", 12, True)
    for j in range(7):
        trow += pad(String(tot[j]), 8 if j == 0 else 11, False)
    print(trow)
    print(locline)
    if verdict != "":
        print(verdict)
    return 1 if over else 0


def cut_from(s: String, a: Int) -> String:
    return String(unsafe_from_utf8=s.as_bytes()[a:])
