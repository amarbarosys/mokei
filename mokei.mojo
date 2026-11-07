# mokei: count code, comment and blank lines per language (tokei-like).
# Usage: mokei [FILE|DIR ...]   (DIR: walk honouring .gitignore; no args: `git ls-files` in cwd, else walk .)
from std.sys import argv, exit, stderr
from std.subprocess import run
from std.os import getenv, listdir
from std.runtime import parallelism_level
from max.algorithm import parallelize
from std.os.path import dirname, isdir, isfile, islink, realpath


from core import Lang, Rule, langs, lang_path, lang_of, scan_file, skip_to, walk, lower, cut, jstr, pad


def main() raises:
    var args = argv()
    var files = List[String]()
    var rules = List[Rule]()
    var as_json = False
    var per_file = False
    var sort_key = String("code")
    var paths = List[String]()
    var ai = 1
    while ai < len(args):
        var a = String(args[ai])
        if a == "--json":
            as_json = True
        elif a == "--files":
            per_file = True
        elif a == "--sort" and ai + 1 < len(args):
            ai += 1
            sort_key = String(args[ai])
        elif a.startswith("--sort="):
            sort_key = cut(a, 7, a.byte_length())
        elif a.startswith("--"):
            raise Error("FAIL args: unknown flag " + a)
        else:
            paths.append(a)
        ai += 1
    if sort_key != "code" and sort_key != "lines" and sort_key != "files":
        raise Error("FAIL args: --sort takes code, lines or files")
    var jkeys = ["files", "lines", "code", "comments", "blanks"]
    if len(paths) > 0:
        for a in paths:
            if isdir(a):
                walk(String(a.rstrip("/")) if a != "/" else a, "", rules, files)
            else:
                files.append(a)
    else:
        var listed = False
        try:
            for ln in run("git ls-files 2>/dev/null").split("\n"):
                if ln.byte_length() > 0:
                    files.append(String(ln))
                    listed = True
        except:
            pass
        if not listed:
            walk(".", "", rules, files)
    var L = langs(lang_path())
    var by_name = Dict[String, Int]()
    var by_ext = Dict[String, Int]()
    var by_sh = Dict[String, Int]()
    for k in range(len(L)):
        for x in L[k].filenames:
            by_name[x] = k
        for x in L[k].shebangs:
            by_sh[x] = k
        for x in L[k].exts:
            by_ext[x] = k
    var stats = List[List[Int]]()  # files, lines, code, comment, blank
    for _ in range(len(L)):
        stats.append([0, 0, 0, 0, 0])
    var n = len(files)
    var out = List[Int](length=n * 5, fill=0)  # per file: language index + 1, lines, code, comment, blank
    var op = out.unsafe_ptr()
    var emb = List[List[Int]]()  # per file: embedded-language entries [language, lines, code, comment, blank]
    for _ in range(n):
        emb.append(List[Int]())
    var ep = emb.unsafe_ptr()
    var names = Dict[String, Int]()  # lower-case language name or alias -> index, for fences and tags
    for k in range(len(L)):
        names[lower(L[k].name)] = k
        for x in L[k].alias:
            names[lower(x)] = k

    def scan(i: Int) {imm files, imm L, imm by_name, imm by_ext, imm by_sh, imm op, imm ep, imm names}:
        try:
            var k = lang_of(files[i], by_name, by_ext, by_sh)
            if k < 0:
                return
            var s = open(files[i], "r").read_bytes()
            if skip_to(s, 0, 0, 0, 0, 0) < len(s):
                return  # binary
            var r: List[Int] = [0, 0, 0, 0]
            var kids = List[Int]()
            scan_file(s, L[k], L, names, r, kids)
            ep[i] = kids^
            op.unsafe_store(i * 5, k + 1)
            for j in range(4):
                op.unsafe_store(i * 5 + 1 + j, r[j])
        except:
            print("mokei: skip unreadable", files[i], file=stderr)

    var jobs = atol(getenv("MOKEI_JOBS", "0"))
    parallelize(scan, n, jobs if jobs > 0 else parallelism_level())
    for i in range(n):
        if out[i * 5] > 0:
            var k = out[i * 5] - 1
            stats[k][0] += 1
            for j in range(4):
                stats[k][j + 1] += out[i * 5 + 1 + j]
    var nl = len(L)
    var cs = List[Int](length=nl * nl * 5, fill=0)  # embedded stats: [parent][child] -> files, lines, code, comment, blank
    for i in range(n):
        if out[i * 5] > 0:
            ref kd = emb[i]
            for e in range(0, len(kd), 5):
                var base = ((out[i * 5] - 1) * nl + kd[e]) * 5
                cs[base] += 1
                for j in range(4):
                    cs[base + 1 + j] += kd[e + 1 + j]
    # rows: language indexes with files, sorted by the --sort key (largest first), ties by name
    var order = List[Int]()
    for k in range(len(L)):
        if stats[k][0] > 0:
            order.append(k)
    var col = 0 if sort_key == "files" else (1 if sort_key == "lines" else 2)  # index into stats[k]

    def lang_before(a: Int, c: Int) {imm stats, imm L, imm col} -> Bool:
        return stats[a][col] > stats[c][col] or (stats[a][col] == stats[c][col] and L[a].name < L[c].name)

    for a in range(1, len(order)):  # insertion sort: stable and tiny
        var t = order[a]
        var c = a - 1
        while c >= 0 and lang_before(t, order[c]):
            order[c + 1] = order[c]
            c -= 1
        order[c + 1] = t
    # per-file rows (--files and --json --files): file indexes per language, same key, ties by path
    var per = List[List[Int]]()
    for _ in range(len(L)):
        per.append(List[Int]())
    for i in range(n):
        if per_file and out[i * 5] > 0:
            per[out[i * 5] - 1].append(i)
    var fcol = 1 if sort_key == "lines" else 2  # out[i*5 + fcol]: lines, code

    def file_before(a: Int, c: Int) {imm out, imm files, imm fcol, imm sort_key} -> Bool:
        if sort_key == "files":
            return files[a] < files[c]
        return out[a * 5 + fcol] > out[c * 5 + fcol] or (out[a * 5 + fcol] == out[c * 5 + fcol] and files[a] < files[c])

    for k in order:
        ref lst = per[k]
        for a in range(1, len(lst)):
            var t = lst[a]
            var c = a - 1
            while c >= 0 and file_before(t, lst[c]):
                lst[c + 1] = lst[c]
                c -= 1
            lst[c + 1] = t
    var kidlist = List[List[Int]]()  # per language: embedded child languages, by name like tokei
    for k in range(len(L)):
        var ks = List[Int]()
        for c in range(nl):
            if cs[(k * nl + c) * 5] > 0:
                var ins = len(ks)
                ks.append(c)
                while ins > 0 and L[ks[ins - 1]].name > L[c].name:
                    ks[ins] = ks[ins - 1]
                    ins -= 1
                ks[ins] = c
        kidlist.append(ks^)
    var tot: List[Int] = [0, 0, 0, 0, 0]  # children count in the lines, code, comment, blank totals
    for k in order:
        for j in range(5):
            tot[j] += stats[k][j]
        for c in kidlist[k]:
            for j in range(1, 5):
                tot[j] += cs[(k * nl + c) * 5 + j]
    if as_json:
        var js = String('{"languages":[')
        for oi in range(len(order)):
            var k = order[oi]
            js += (',' if oi > 0 else '') + '{"name":' + jstr(L[k].name)
            for j in range(5):
                js += ',"' + jkeys[j] + '":' + String(stats[k][j])
            if len(kidlist[k]) > 0:
                js += ',"children":['
                for ci in range(len(kidlist[k])):
                    var c = kidlist[k][ci]
                    js += (',' if ci > 0 else '') + '{"name":' + jstr(L[c].name)
                    for j in range(5):
                        js += ',"' + jkeys[j] + '":' + String(cs[(k * nl + c) * 5 + j])
                    js += "}"
                js += "]"
            if per_file:
                js += ',"reports":['
                for fi in range(len(per[k])):
                    var i = per[k][fi]
                    js += (',' if fi > 0 else '') + '{"name":' + jstr(files[i])
                    for j in range(4):
                        js += ',"' + jkeys[j + 1] + '":' + String(out[i * 5 + 1 + j])
                    js += "}"
                js += "]"
            js += "}"
        js += '],"total":{'
        for j in range(5):
            js += (',' if j > 0 else '') + '"' + jkeys[j] + '":' + String(tot[j])
        print(js + "}}")
        return
    var w = 16
    if per_file:
        for i in range(n):
            if out[i * 5] > 0 and files[i].byte_length() + 2 > w:
                w = files[i].byte_length() + 2
    var hdr = ["Language", "Files", "Lines", "Code", "Comments", "Blanks"]
    var line = pad(hdr[0], w, True)
    for j in range(1, 6):
        line += pad(hdr[j], 10, False)
    print(line)
    for k in order:
        var row = pad(L[k].name, w, True)
        for j in range(5):
            row += pad(String(stats[k][j]), 10, False)
        print(row)
        if per_file:
            for i in per[k]:
                var frow = pad(" " + files[i], w, True) + pad("1", 10, False)
                for j in range(4):
                    frow += pad(String(out[i * 5 + 1 + j]), 10, False)
                print(frow)
        if len(kidlist[k]) > 0:
            var sums: List[Int] = [0, stats[k][1], stats[k][2], stats[k][3], stats[k][4]]
            for c in kidlist[k]:
                var crow = pad(" |- " + L[c].name, w, True)
                for j in range(5):
                    crow += pad(String(cs[(k * nl + c) * 5 + j]), 10, False)
                    sums[j] += cs[(k * nl + c) * 5 + j] if j > 0 else 0
                print(crow)
            var trow = pad(" (Total)", w, True) + pad("", 10, False)
            for j in range(1, 5):
                trow += pad(String(sums[j]), 10, False)
            print(trow)
    var trow = pad("Total", w, True)
    for j in range(5):
        trow += pad(String(tot[j]), 10, False)
    print(trow)
