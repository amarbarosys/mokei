# mokei: count code, comment and blank lines per language (tokei-like).
# Usage: mokei [FILE ...]   (no args: files from `git ls-files` in cwd)
from std.sys import argv, exit, stderr
from std.subprocess import run


@fieldwise_init
struct Lang(Copyable, Movable):
    var name: String
    var exts: String  # space-padded: " py pyi "
    var lc: String  # line comment token, "" = none
    var bs: String  # block comment start, "" = none
    var be: String  # block comment end
    var quotes: String  # string delimiter bytes
    var doc: Bool  # triple quotes at line start count as comment


def langs() -> List[Lang]:
    var l = List[Lang]()
    l.append(Lang("Python", " py pyi ", "#", "", "", "\"'", False))
    l.append(Lang("Mojo", " mojo 🔥 ", "#", "", "", "\"'", False))
    l.append(Lang("JavaScript", " js mjs cjs jsx ", "//", "/*", "*/", "\"'`", False))
    l.append(Lang("TypeScript", " ts tsx ", "//", "/*", "*/", "\"'`", False))
    l.append(Lang("Rust", " rs ", "//", "/*", "*/", "\"", False))
    l.append(Lang("C", " c h ", "//", "/*", "*/", "\"'", False))
    l.append(Lang("C++", " cpp cc cxx hpp hh ", "//", "/*", "*/", "\"'", False))
    l.append(Lang("Go", " go ", "//", "/*", "*/", "\"'`", False))
    l.append(Lang("CSS", " css ", "", "/*", "*/", "\"'", False))
    l.append(Lang("HTML", " html htm ", "", "<!--", "-->", "", False))
    l.append(Lang("Markdown", " md ", "", "<!--", "-->", "", False))
    l.append(Lang("Shell", " sh bash fish zsh ", "#", "", "", "\"'", False))
    l.append(Lang("Dockerfile", " Dockerfile dockerfile ", "#", "", "", "\"'", False))
    l.append(Lang("INI", " ini cfg ", "#", "", "", "", False))
    l.append(Lang("TOML", " toml ", "#", "", "", "\"'", False))
    l.append(Lang("YAML", " yml yaml ", "#", "", "", "\"'", False))
    return l^


def at(s: String, i: Int, tok: String) -> Bool:
    var b = s.as_bytes()
    var t = tok.as_bytes()
    if len(t) == 0 or i + len(t) > len(b):
        return False
    for j in range(len(t)):
        if b[i + j] != t[j]:
            return False
    return True


def ext_of(path: String) -> String:
    var parts = path.split("/")
    var base = String(parts[len(parts) - 1])
    if base.find(".") < 0:
        return base
    var xs = base.split(".")
    return String(xs[len(xs) - 1])


def count(s: String, lg: Lang, mut res: List[Int]):
    """Adds lines, code, comment, blank of s to res[0..3]."""
    var b = s.as_bytes()
    var n = len(b)
    var NL = UInt8(ord("\n"))
    var BS = UInt8(ord("\\"))
    var in_block = False
    var block_end = String("")
    var q = String("")  # open string delimiter, "" = none
    var code = False
    var com = False
    var i = 0
    while i <= n:
        if i == n or b[i] == NL:
            if i == n and i > 0 and b[i - 1] == NL:
                break  # trailing newline: no extra line
            if i == n and n == 0:
                break
            res[0] += 1
            if code and lg.name == "Markdown":
                res[2] += 1  # prose counts as comment, like tokei
            elif code:
                res[1] += 1
            elif com:
                res[2] += 1
            else:
                res[3] += 1
            if q.byte_length() == 1 and q != "`":
                q = ""  # quote strings end at line end; template strings span lines
            code = q.byte_length() > 0
            com = in_block
            i += 1
            continue
        var c = b[i]
        if in_block:
            com = True
            if at(s, i, block_end):
                in_block = False
                i += block_end.byte_length()
            else:
                i += 1
        elif q.byte_length() > 0:
            code = True
            if c == BS:
                i += 2
            elif at(s, i, q):
                i += q.byte_length()
                q = ""
            else:
                i += 1
        elif c == UInt8(ord(" ")) or c == UInt8(ord("\t")) or c == UInt8(ord("\r")):
            i += 1
        elif at(s, i, lg.lc):
            com = True
            while i < n and b[i] != NL:
                i += 1
        elif at(s, i, lg.bs):
            com = True
            in_block = True
            block_end = lg.be
            i += lg.bs.byte_length()
        elif lg.doc and not code and (at(s, i, "\"\"\"") or at(s, i, "'''")):
            com = True
            in_block = True
            block_end = "\"\"\"" if at(s, i, "\"\"\"") else "'''"
            i += 3
        else:
            code = True
            var qs = lg.quotes.as_bytes()
            for j in range(len(qs)):
                if c == qs[j]:
                    var t = chr(Int(c))
                    var tq = t + t + t
                    if at(s, i, tq):
                        q = tq
                    else:
                        q = t
                    i += q.byte_length() - 1
                    break
            i += 1


def pad(s: String, w: Int, left: Bool) -> String:
    var p = String("")
    for _ in range(w - s.byte_length()):
        p += " "
    return s + p if left else p + s


def main() raises:
    var args = argv()
    var files = List[String]()
    if len(args) > 1:
        for k in range(1, len(args)):
            files.append(String(args[k]))
    else:
        for ln in run("git ls-files").split("\n"):
            if ln.byte_length() > 0:
                files.append(String(ln))
    var L = langs()
    var stats = List[List[Int]]()  # files, lines, code, comment, blank
    for _ in range(len(L)):
        stats.append([0, 0, 0, 0, 0])
    for f in files:
        var e = " " + ext_of(f) + " "
        if e == "  ":
            continue
        for k in range(len(L)):
            if L[k].exts.find(e) >= 0:
                var s: String
                try:
                    s = open(f, "r").read()
                except:
                    print("mokei: skip unreadable", f, file=stderr)
                    break
                if s.find("\0") >= 0:
                    break  # binary
                var r: List[Int] = [0, 0, 0, 0]
                count(s, L[k], r)
                stats[k][0] += 1
                for j in range(4):
                    stats[k][j + 1] += r[j]
                break
    # sort by code desc
    var order = List[Int]()
    for k in range(len(L)):
        if stats[k][0] > 0:
            order.append(k)
    for a in range(len(order)):
        for c in range(a + 1, len(order)):
            if stats[order[c]][2] > stats[order[a]][2]:
                var t = order[a]
                order[a] = order[c]
                order[c] = t
    var hdr = ["Language", "Files", "Lines", "Code", "Comments", "Blanks"]
    var line = pad(hdr[0], 12, True)
    for j in range(1, 6):
        line += pad(hdr[j], 10, False)
    print(line)
    var tot: List[Int] = [0, 0, 0, 0, 0]
    for k in order:
        var row = pad(L[k].name, 12, True)
        for j in range(5):
            row += pad(String(stats[k][j]), 10, False)
            tot[j] += stats[k][j]
        print(row)
    var trow = pad("Total", 12, True)
    for j in range(5):
        trow += pad(String(tot[j]), 10, False)
    print(trow)
