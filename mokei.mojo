# mokei: count code, comment and blank lines per language (tokei-like).
# Usage: mokei [FILE ...]   (no args: files from `git ls-files` in cwd)
from std.sys import argv, exit, stderr
from std.subprocess import run
from std.os import getenv
from std.runtime import parallelism_level
from max.algorithm import parallelize
from std.os.path import dirname, realpath


@fieldwise_init
struct Lang(Copyable, Movable):
    var name: String
    var exts: List[String]
    var filenames: List[String]
    var shebangs: List[String]  # interpreter names for extensionless scripts
    var lc: List[String]  # line comment tokens
    var bs: List[String]  # block comment starts
    var be: List[String]  # block comment ends, same index as bs
    var nested: Bool  # block comments nest
    var rs: List[String]  # raw string starts (no escapes inside), re[k] ends rs[k]
    var re: List[String]
    var rawdelim: Bool  # C++ R"delim( ... )delim" raw strings
    var quotes: String  # string delimiter bytes
    var multiline: String  # quote bytes whose strings may span lines
    var doc: Bool  # triple quotes at line start count as comment
    var prose: Bool  # every non-blank line counts as comment


def strs(v: String) -> List[String]:
    """The double-quoted strings of v, in order (`\\"` and `\\\\` escapes)."""
    var out = List[String]()
    var b = v.as_bytes()
    var i = 0
    while i < len(b):
        if b[i] == UInt8(ord("\"")):
            var cur = String("")
            i += 1
            var st = i
            while i < len(b) and b[i] != UInt8(ord("\"")):
                if b[i] == UInt8(ord("\\")):
                    cur += String(v[byte=st:i])
                    i += 1
                    st = i
                i += 1
            out.append(cur + String(v[byte=st:i]))
        i += 1
    return out^


def langs(path: String) raises -> List[Lang]:
    """Rows of the [[lang]] tables in the TOML file at path."""
    var l = List[Lang]()
    for raw in open(path, "r").read().split("\n"):
        var ln = String(raw.strip())
        if ln.startswith("[[lang]]"):
            l.append(Lang("", [], [], [], [], [], [], False, [], [], False, "", "", False, False))
        elif len(l) > 0 and ln.find("=") > 0 and not ln.startswith("#"):
            var kv = ln.split("=", 1)
            var k = String(kv[0].strip())
            var v = String(kv[1].strip())
            ref r = l[len(l) - 1]
            var xs = strs(v)
            if k == "name":
                r.name = xs[0]
            elif k == "exts":
                r.exts = xs^
            elif k == "filenames":
                r.filenames = xs^
            elif k == "shebang":
                r.shebangs = xs^
            elif k == "line":
                r.lc = xs^
            elif k == "block":
                for j in range(0, len(xs) - 1, 2):
                    r.bs.append(xs[j])
                    r.be.append(xs[j + 1])
            elif k == "nested":
                r.nested = v.startswith("true")
            elif k == "raw":
                for j in range(0, len(xs) - 1, 2):
                    r.rs.append(xs[j])
                    r.re.append(xs[j + 1])
            elif k == "rawdelim":
                r.rawdelim = v.startswith("true")
            elif k == "quotes":
                r.quotes = xs[0]
            elif k == "multiline":
                r.multiline = xs[0]
            elif k == "doc":
                r.doc = v.startswith("true")
            elif k == "prose":
                r.prose = v.startswith("true")
            else:
                raise Error("FAIL languages: unknown key " + k)
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


def which(s: String, i: Int, toks: List[String]) -> Int:
    """Index of the first token of toks found at byte i of s, else -1."""
    for k in range(len(toks)):
        if at(s, i, toks[k]):
            return k
    return -1


def last(s: String, sep: String) -> String:
    """Text after the last sep in s."""
    var xs = s.split(sep)
    return String(xs[len(xs) - 1])


def shebang(path: String) -> String:
    """Interpreter name of a `#!` first line (env skipped, version digits cut), else ""."""
    var head: String
    try:
        head = open(path, "r").read(128)
    except:
        return ""
    if not head.startswith("#!"):
        return ""
    var ws = String(head.split("\n")[0][byte=2:]).split()
    var w = last(String(ws[0]), "/") if len(ws) > 0 else String("")
    if w == "env":
        w = ""
        for k in range(1, len(ws)):
            if not ws[k].startswith("-"):
                w = last(String(ws[k]), "/")
                break
    var wb = w.as_bytes()
    var e = len(wb)
    while e > 0 and wb[e - 1] <= 57 and (wb[e - 1] >= 48 or wb[e - 1] == 46):
        e -= 1
    return String(w[byte=:e])


def lang_of(path: String, by_name: Dict[String, Int], by_ext: Dict[String, Int], by_sh: Dict[String, Int]) raises -> Int:
    """Language index: exact filename, extension, else the shebang of an extensionless file."""
    var base = last(path, "/")
    if base in by_name:
        return by_name[base]
    var xs = base.split(".")
    var e = String(xs[len(xs) - 1])
    if len(xs) > 1:
        return by_ext[e] if e in by_ext else -1
    var w = shebang(path)
    return by_sh[w] if w in by_sh else -1


def count(s: String, lg: Lang, mut res: List[Int]):
    """Adds lines, code, comment, blank of s to res[0..3]."""
    var b = s.as_bytes()
    var n = len(b)
    var NL = UInt8(ord("\n"))
    var BS = UInt8(ord("\\"))
    var in_block = False
    var depth = 0  # block comment nesting
    var block_start = String("")
    var block_end = String("")
    var q = String("")  # open string delimiter, "" = none
    var raw = False  # open string is raw: no escapes, spans lines
    var tdepth = List[Int]()  # brace depth of each open `${` inside a template string
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
            if code and lg.prose:
                res[2] += 1  # prose counts as comment, like tokei
            elif code:
                res[1] += 1
            elif com:
                res[2] += 1
            else:
                res[3] += 1
            if q.byte_length() == 1 and not raw and lg.multiline.find(q) < 0:
                q = ""  # quote strings end at line end unless the language lets them span lines
            code = q.byte_length() > 0
            com = in_block
            i += 1
            continue
        var c = b[i]
        if in_block:
            com = True
            if lg.nested and at(s, i, block_start):
                depth += 1
                i += block_start.byte_length()
            elif at(s, i, block_end):
                depth -= 1
                in_block = depth > 0
                i += block_end.byte_length()
            else:
                i += 1
        elif q.byte_length() > 0:
            code = True
            if c == BS and not raw:
                i += 1 if i + 1 < n and b[i + 1] == NL else 2  # keep the newline: it ends a line
            elif q == "`" and not raw and at(s, i, "${"):
                tdepth.append(1)
                q = ""
                i += 2
            elif at(s, i, q):
                i += q.byte_length()
                q = ""
                raw = False
            else:
                i += 1
        elif c == UInt8(ord(" ")) or c == UInt8(ord("\t")) or c == UInt8(ord("\r")):
            i += 1
        elif c == BS:  # an escaped byte outside a string: never a quote or comment start
            code = True
            i += 1 if i + 1 < n and b[i + 1] == NL else 2
        elif len(tdepth) > 0 and (c == UInt8(ord("{")) or c == UInt8(ord("}"))):
            code = True
            tdepth[len(tdepth) - 1] += 1 if c == UInt8(ord("{")) else -1
            if tdepth[len(tdepth) - 1] == 0:
                _ = tdepth.pop()
                q = "`"
            i += 1
        else:
            var bi = which(s, i, lg.bs)
            var li = which(s, i, lg.lc) if bi < 0 else -1
            var ri = which(s, i, lg.rs) if i == 0 or not is_word(b[i - 1]) else -1
            if bi >= 0:
                com = True
                in_block = True
                depth = 1
                block_start = lg.bs[bi]
                block_end = lg.be[bi]
                i += block_start.byte_length()
            elif li >= 0:
                com = True
                while i < n and b[i] != NL:
                    i += 1
            elif lg.doc and not code and (at(s, i, '"""') or at(s, i, "'''")):
                com = True
                in_block = True
                depth = 1
                block_start = '"""' if at(s, i, '"""') else "'''"
                block_end = block_start
                i += 3
            elif lg.rawdelim and at(s, i, 'R"') and (i == 0 or not is_word(b[i - 1])):
                code = True
                var j = i + 2
                while j < n and j < i + 20 and b[j] != UInt8(ord("(")) and b[j] != UInt8(ord('"')):
                    j += 1
                if j < n and b[j] == UInt8(ord("(")):
                    raw = True
                    q = ")" + String(s[byte=i + 2 : j]) + '"'
                    i = j + 1
                else:
                    q = '"'
                    i += 2
            elif ri >= 0:
                code = True
                raw = True
                q = lg.re[ri]
                i += lg.rs[ri].byte_length()
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


def is_word(c: UInt8) -> Bool:
    return (c >= 48 and c <= 57) or (c >= 65 and c <= 90) or (c >= 97 and c <= 122) or c == 95


def lang_path() raises -> String:
    """$MOKEI_LANGS, else languages.toml one directory above the binary."""
    var e = getenv("MOKEI_LANGS")
    if e != "":
        return e
    return dirname(dirname(realpath("/proc/self/exe"))) + "/languages.toml"


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

    def scan(i: Int) {imm files, imm L, imm by_name, imm by_ext, imm by_sh, imm op}:
        try:
            var k = lang_of(files[i], by_name, by_ext, by_sh)
            if k < 0:
                return
            var s = open(files[i], "r").read()
            if s.find("\0") >= 0:
                return  # binary
            var r: List[Int] = [0, 0, 0, 0]
            count(s, L[k], r)
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
