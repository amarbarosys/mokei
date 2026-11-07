# mokei core: language table, scanner, embedded languages, gitignore walk.
from std.sys import argv, exit, stderr
from std.subprocess import run
from std.os import getenv, listdir
from std.runtime import parallelism_level
from max.algorithm import parallelize
from std.os.path import dirname, isdir, isfile, islink, realpath


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
    var cls: List[UInt8]  # byte classes built by prep()
    var embed: String  # "tags": <script>/<style> children, "fence": fenced code children
    var alias: List[String]  # extra names a fence info string may use


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
            l.append(Lang("", [], [], [], [], [], [], False, [], [], False, "", "", False, False, [], "", []))
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
            elif k == "embed":
                r.embed = xs[0]
            elif k == "alias":
                r.alias = xs^
            elif k == "prose":
                r.prose = v.startswith("true")
            else:
                raise Error("FAIL languages: unknown key " + k)
    for k in range(len(l)):
        prep(l[k])
    return l^


def at(b: Span[UInt8, _], i: Int, tok: String) -> Bool:
    var t = tok.as_bytes()
    var m = len(t)
    if m == 0 or i + m > len(b):
        return False
    for j in range(m):
        if b[i + j] != t[j]:
            return False
    return True


def which(b: Span[UInt8, _], i: Int, toks: List[String]) -> Int:
    """Index of the first token of toks found at byte i of b, else -1."""
    for k in range(len(toks)):
        if at(b, i, toks[k]):
            return k
    return -1


def skip_to(b: Span[UInt8, _], i: Int, x: UInt8, y: UInt8, z: UInt8, w: UInt8) -> Int:
    """First index >= i holding one of x, y, z, w, else len(b). 32 bytes per step."""
    var n = len(b)
    var p = b.unsafe_ptr()
    var j = i
    while j + 32 <= n:
        var v = p.unsafe_load[width=32](j)
        if ((v.eq(x)) | (v.eq(y)) | (v.eq(z)) | (v.eq(w))).reduce_or():
            break
        j += 32
    while j < n and b[j] != x and b[j] != y and b[j] != z and b[j] != w:
        j += 1
    return j


def prep(mut lg: Lang):
    """Byte classes for count(): 0 plain, 1 blank, 2 may start a token, 3 newline."""
    lg.cls = List[UInt8](length=256, fill=0)
    for c in [32, 9, 13]:
        lg.cls[c] = 1
    lg.cls[10] = 3
    lg.cls[ord("\\")] = 2
    for toks in [lg.lc.copy(), lg.bs.copy(), lg.rs.copy()]:
        for t in toks:
            lg.cls[Int(t.as_bytes()[0])] = 2
    for c in lg.quotes.as_bytes():
        lg.cls[Int(c)] = 2
    if lg.doc:
        lg.cls[ord('"')] = 2
        lg.cls[ord("'")] = 2
    if lg.rawdelim:
        lg.cls[ord("R")] = 2
    if lg.quotes.find("`") >= 0:
        lg.cls[ord("{")] = 2
        lg.cls[ord("}")] = 2


def count(b: Span[UInt8, _], lg: Lang, mut res: List[Int]):
    """Adds lines, code, comment, blank of the bytes b to res[0..3]."""
    var none = List[UInt8]()
    count_lines[False](b, lg, res, none)


def count_lines[emit: Bool](b: Span[UInt8, _], lg: Lang, mut res: List[Int], mut kinds: List[UInt8]):
    """count(), and with emit one byte per line appended to kinds: 1 code, 2 comment, 3 blank."""
    var n = len(b)
    var cls = lg.cls.unsafe_ptr()
    var bp = b.unsafe_ptr()
    var NL = UInt8(ord("\n"))
    var BS = UInt8(ord("\\"))
    var DL = UInt8(ord("$"))
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
                comptime if emit:
                    kinds.append(2)
            elif code:
                res[1] += 1
                comptime if emit:
                    kinds.append(1)
            elif com:
                res[2] += 1
                comptime if emit:
                    kinds.append(2)
            else:
                res[3] += 1
                comptime if emit:
                    kinds.append(3)
            if q.byte_length() == 1 and not raw and lg.multiline.find(q) < 0:
                q = ""  # quote strings end at line end unless the language lets them span lines
            code = q.byte_length() > 0
            com = in_block
            i += 1
            continue
        var c = b[i]
        if in_block:
            com = True
            var e0 = block_end.as_bytes()[0]
            var s0 = block_start.as_bytes()[0] if lg.nested else e0
            i = skip_to(b, i, NL, e0, s0, e0)
            if i < n and b[i] != NL:
                if lg.nested and at(b, i, block_start):
                    depth += 1
                    i += block_start.byte_length()
                elif at(b, i, block_end):
                    depth -= 1
                    in_block = depth > 0
                    i += block_end.byte_length()
                else:
                    i += 1
        elif q.byte_length() > 0:
            code = True
            var q0 = q.as_bytes()[0]
            var tpl = q == "`" and not raw
            i = skip_to(b, i, NL, BS if not raw else NL, q0, DL if tpl else q0)
            if i < n and b[i] != NL:
                if b[i] == BS and not raw:
                    i += 1 if i + 1 < n and b[i + 1] == NL else 2
                elif tpl and at(b, i, "${"):
                    tdepth.append(1)
                    q = ""
                    i += 2
                elif at(b, i, q):
                    i += q.byte_length()
                    q = ""
                    raw = False
                else:
                    i += 1
        elif cls.unsafe_load(Int(c)) < 2:
            var any = False
            while i < n:
                var k = cls.unsafe_load(Int(bp.unsafe_load(i)))
                if k >= 2:
                    break
                any = any or k == 0
                i += 1
            code = code or any
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
            var bi = which(b, i, lg.bs)
            var li = which(b, i, lg.lc) if bi < 0 else -1
            var ri = which(b, i, lg.rs) if i == 0 or not is_word(b[i - 1]) else -1
            if bi >= 0:
                com = True
                in_block = True
                depth = 1
                block_start = lg.bs[bi]
                block_end = lg.be[bi]
                i += block_start.byte_length()
            elif li >= 0:
                com = True
                i = skip_to(b, i, NL, NL, NL, NL)
            elif lg.doc and not code and (at(b, i, '"""') or at(b, i, "'''")):
                com = True
                in_block = True
                depth = 1
                block_start = '"""' if at(b, i, '"""') else "'''"
                block_end = block_start
                i += 3
            elif lg.rawdelim and at(b, i, 'R"') and (i == 0 or not is_word(b[i - 1])):
                code = True
                var j = i + 2
                while j < n and j < i + 20 and b[j] != UInt8(ord("(")) and b[j] != UInt8(ord('"')):
                    j += 1
                if j < n and b[j] == UInt8(ord("(")):
                    raw = True
                    q = ")" + String(unsafe_from_utf8=b[i + 2 : j]) + '"'
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
                        if at(b, i, tq):
                            q = tq
                        else:
                            q = t
                        i += q.byte_length() - 1
                        break
                i += 1


def is_word(c: UInt8) -> Bool:
    return (c >= 48 and c <= 57) or (c >= 65 and c <= 90) or (c >= 97 and c <= 122) or c == 95


def find_tok(b: Span[UInt8, _], i: Int, tok: String) -> Int:
    """Index of the first tok at or after i, else -1."""
    var t0 = tok.as_bytes()[0]
    var j = skip_to(b, i, t0, t0, t0, t0)
    while j < len(b):
        if at(b, j, tok):
            return j
        j = skip_to(b, j + 1, t0, t0, t0, t0)
    return -1


def blank(b: Span[UInt8, _], a: Int, e: Int) -> Bool:
    for j in range(a, e):
        if b[j] != 32 and b[j] != 9 and b[j] != 13:
            return False
    return True


def lower(s: String) -> String:
    var o = String("")
    for c in s.as_bytes():
        o += chr(Int(c) + 32 if c >= 65 and c <= 90 else Int(c))
    return o


def add_kid(mut kids: List[Int], ci: Int, chunk: Span[UInt8, _], lg: Lang, keep_empty: Bool):
    """Counts chunk as language ci and adds it to the file's child entries [ci, lines, code, comment, blank]."""
    var r: List[Int] = [0, 0, 0, 0]
    count(chunk, lg, r)
    if r[0] == 0 and not keep_empty:
        return
    for e in range(0, len(kids), 5):
        if kids[e] == ci:
            for j in range(4):
                kids[e + 1 + j] += r[j]
            return
    kids.append(ci)
    for j in range(4):
        kids.append(r[j])


def html_split(b: Span[UInt8, _], L: List[Lang], names: Dict[String, Int], mut parent: List[UInt8], mut kids: List[Int]) raises -> Bool:
    """Cuts <script>/<style> bodies out of an HTML file into child counts, like tokei.

    The open and close tag lines stay in the parent. Text on the tag lines moves to the child
    when it is not blank; a one-line <style>a{}</style> becomes two parent lines and one child line.
    """
    var css = names["css"] if "css" in names else -1
    var js = names["javascript"] if "javascript" in names else -1
    var jn = names["json"] if "json" in names else -1
    var n = len(b)
    var NL = UInt8(10)
    var i = 0
    var from_ = 0
    var any = False
    while i < n:
        i = skip_to(b, i, 60, 60, 60, 60)  # "<"
        if i >= n:
            break
        if at(b, i, "<!--"):
            var e = find_tok(b, i + 4, "-->")
            i = n if e < 0 else e + 3
            continue
        var script = at(b, i, "<script")
        if not (script or at(b, i, "<style")):
            i += 1
            continue
        var m = 7 if script else 6
        if i + m >= n:
            break
        var c = b[i + m]
        if not (c == 32 or c == 62 or c == 47 or c == 10 or c == 9 or c == 13):
            i += 1
            continue
        var gt = skip_to(b, i + m, 62, 62, 62, 62)  # ">"
        if gt >= n:
            break
        var close = "</script>" if script else "</style>"
        var k = find_tok(b, gt + 1, close)
        if k < 0:
            i = gt + 1
            continue
        var ci = css if not script else (jn if find_tok(b[i:gt], 0, "json") >= 0 else js)
        i = k + close.byte_length()
        if ci < 0:
            continue
        var cs = gt + 1
        var nl1 = skip_to(b, cs, NL, NL, NL, NL)
        var chunk = List[UInt8]()
        if nl1 >= k:  # body on one line
            if blank(b, cs, k):
                continue
            chunk.extend(b[cs:k])
            chunk.append(NL)
        else:
            if not blank(b, cs, nl1):
                chunk.extend(b[cs : nl1 + 1])
            var lastnl = nl1
            var p = skip_to(b, nl1 + 1, NL, NL, NL, NL)
            while p < k:
                lastnl = p
                p = skip_to(b, p + 1, NL, NL, NL, NL)
            chunk.extend(b[nl1 + 1 : lastnl + 1])
            if not blank(b, lastnl + 1, k):
                chunk.extend(b[lastnl + 1 : k])
                chunk.append(NL)
        parent.extend(b[from_:cs])
        parent.append(NL)
        from_ = k
        any = True
        add_kid(kids, ci, chunk, L[ci], False)
    if any:
        parent.extend(b[from_:n])
    return any


def fence_split(b: Span[UInt8, _], L: List[Lang], names: Dict[String, Int], mut parent: List[UInt8], mut kids: List[Int]) -> Bool:
    """Cuts ```lang fenced blocks of a known language out of a Markdown file into child counts.

    The fence lines stay in the parent; blank lines at both ends of the block are dropped; a
    fence without a closing line runs to the end of the file.
    """
    if find_tok(b, 0, "```") < 0:
        return False
    var n = len(b)
    var NL = UInt8(10)
    var i = 0
    var any = False
    while i < n:
        var e = skip_to(b, i, NL, NL, NL, NL)
        var nxt = e + 1 if e < n else n
        var t = i
        while t < e and (b[t] == 32 or b[t] == 9):
            t += 1
        if not at(b, t, "```"):
            parent.extend(b[i:nxt])
            i = nxt
            continue
        var w0 = t + 3
        while w0 < e and b[w0] == 32:
            w0 += 1
        var w1 = w0
        while w1 < e and b[w1] != 32 and b[w1] != 9 and b[w1] != 13:
            w1 += 1
        var word = lower(String(unsafe_from_utf8=b[w0:w1]))
        var ci = names.get(word, -1)
        var cstart = -1  # start of the closing fence line
        var cend = n  # end of the closing fence line, newline included
        var c = nxt
        while c < n:
            var ce = skip_to(b, c, NL, NL, NL, NL)
            var ct = c
            while ct < ce and (b[ct] == 32 or b[ct] == 9):
                ct += 1
            if at(b, ct, "```"):
                cstart = c
                cend = ce + 1 if ce < n else n
                break
            c = ce + 1 if ce < n else n
        if ci < 0:  # unknown language or none: the whole block stays prose
            parent.extend(b[i:cend])
            i = cend
            continue
        var z = cstart if cstart >= 0 else n
        var a = nxt
        while a < z:  # drop leading blank lines
            var le = skip_to(b, a, NL, NL, NL, NL)
            if not blank(b, a, le):
                break
            a = le + 1
        while z > a:  # drop trailing blank lines
            var q = z - 1 if b[z - 1] == NL else z
            var ls = q
            while ls > a and b[ls - 1] != NL:
                ls -= 1
            if not blank(b, ls, q):
                break
            z = ls
        add_kid(kids, ci, b[a:z], L[ci], True)
        parent.extend(b[i:nxt])
        if cstart >= 0:
            parent.extend(b[cstart:cend])
        any = True
        i = cend
    return any


def scan_file(b: Span[UInt8, _], lg: Lang, L: List[Lang], names: Dict[String, Int], mut res: List[Int], mut kids: List[Int]) raises:
    """Counts b as language lg into res; embedded languages go to kids."""
    if lg.embed == "":
        count(b, lg, res)
        return
    var parent = List[UInt8]()
    var split = html_split(b, L, names, parent, kids) if lg.embed == "tags" else fence_split(b, L, names, parent, kids)
    if split:
        count(parent, lg, res)
    else:
        count(b, lg, res)


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


@fieldwise_init
struct Rule(Copyable, Movable):
    var base: String  # directory of the .gitignore, "" or ends with "/"
    var pat: String
    var neg: Bool
    var dironly: Bool
    var anchored: Bool  # pattern holds a slash: match the path below base, else the basename


def glob(p: Span[UInt8, _], pi0: Int, s: Span[UInt8, _], si0: Int) -> Bool:
    """Gitignore glob: * and ? stop at /, [set], a/**/b, trailing /**."""
    var pi = pi0
    var si = si0
    var SL = UInt8(ord("/"))
    var ST = UInt8(ord("*"))
    while pi < len(p):
        var c = p[pi]
        if c == ST:
            var j = pi + 1
            while j < len(p) and p[j] == ST:
                j += 1
            if j - pi >= 2 and (pi == 0 or p[pi - 1] == SL) and (j == len(p) or p[j] == SL):
                if j == len(p):
                    return si < len(s)  # trailing /**: everything inside
                var k = si
                while True:  # **/: zero or more directories
                    if glob(p, j + 1, s, k):
                        return True
                    while k < len(s) and s[k] != SL:
                        k += 1
                    if k >= len(s):
                        return False
                    k += 1
            var k = si
            while True:  # a star run: any bytes but /
                if glob(p, j, s, k):
                    return True
                if k >= len(s) or s[k] == SL:
                    return False
                k += 1
        elif c == UInt8(ord("?")):
            if si >= len(s) or s[si] == SL:
                return False
            pi += 1
            si += 1
        elif c == UInt8(ord("[")):
            var j = pi + 1
            var neg = j < len(p) and (p[j] == UInt8(ord("!")) or p[j] == UInt8(ord("^")))
            if neg:
                j += 1
            var hit = False
            var first = True
            while j < len(p) and (p[j] != UInt8(ord("]")) or first):
                first = False
                if j + 2 < len(p) and p[j + 1] == UInt8(ord("-")) and p[j + 2] != UInt8(ord("]")):
                    hit = hit or (si < len(s) and s[si] >= p[j] and s[si] <= p[j + 2])
                    j += 3
                else:
                    hit = hit or (si < len(s) and s[si] == p[j])
                    j += 1
            if j >= len(p) or si >= len(s) or s[si] == SL or hit == neg:
                return False
            pi = j + 1
            si += 1
        else:
            if c == UInt8(ord("\\")) and pi + 1 < len(p):
                pi += 1
            if si >= len(s) or s[si] != p[pi]:
                return False
            pi += 1
            si += 1
    return si == len(s)


def cut(s: String, a: Int, b: Int) -> String:
    """Bytes a..b of s."""
    return String(unsafe_from_utf8=s.as_bytes()[a:b])


def add_rules(base: String, text: String, mut rules: List[Rule]):
    """Rules of one .gitignore (blank and # lines skipped, ! negates, trailing / = dirs only)."""
    for raw in text.split("\n"):
        var ln = String(raw.rstrip())
        if ln.byte_length() == 0 or ln.startswith("#"):
            continue
        var neg = ln.startswith("!")
        if neg or ln.startswith("\\#") or ln.startswith("\\!"):
            ln = cut(ln, 1, ln.byte_length())  # drops the ! or the escape
        var dironly = ln.endswith("/")
        if dironly:
            ln = cut(ln, 0, ln.byte_length() - 1)
        var anchored = ln.find("/") >= 0
        if ln.startswith("/"):
            ln = cut(ln, 1, ln.byte_length())
        if ln.byte_length() > 0:
            rules.append(Rule(base, ln, neg, dironly, anchored))


def is_ignored(rel: String, name: String, isd: Bool, rules: List[Rule]) -> Bool:
    var res = False
    for k in range(len(rules)):
        ref r = rules[k]
        if (r.dironly and not isd) or r.neg != res:
            continue  # only a rule that flips the current answer can matter
        var subject = cut(rel, r.base.byte_length(), rel.byte_length()) if r.anchored else name
        if glob(r.pat.as_bytes(), 0, subject.as_bytes(), 0):
            res = not r.neg
    return res


def walk(root: String, rel: String, mut rules: List[Rule], mut out: List[String]) raises:
    """Files below root/rel in sorted order, honouring .gitignore files; .git and dir symlinks skipped."""
    var dir = root if rel == "" else root + "/" + rel
    var mark = len(rules)
    var gi = dir + "/.gitignore"
    if isfile(gi):
        add_rules(rel + "/" if rel != "" else "", open(gi, "r").read(), rules)
    var names = listdir(dir)
    sort(names)
    for name in names:
        var r = rel + "/" + name if rel != "" else name
        var p = root + "/" + r
        var isd = isdir(p)
        if name == ".git" or (isd and islink(p)) or is_ignored(r, name, isd, rules):
            continue
        if isd:
            walk(root, r, rules, out)
        else:
            out.append(p)
    while len(rules) > mark:
        _ = rules.pop()


def lang_path() raises -> String:
    """$MOKEI_LANGS, else languages.toml one directory above the binary."""
    var e = getenv("MOKEI_LANGS")
    if e != "":
        return e
    return dirname(dirname(realpath("/proc/self/exe"))) + "/languages.toml"


def jstr(s: String) -> String:
    """JSON string literal."""
    var o = String('"')
    for c in s.as_bytes():
        if c == UInt8(ord('"')) or c == UInt8(ord("\\")):
            o += "\\" + chr(Int(c))
        elif c < 32:
            o += "\\u00" + ("0" if c < 16 else "1") + chr(Int(c & 15) + (48 if c & 15 < 10 else 87))
        else:
            o += chr(Int(c))
    return o + '"'


def pad(s: String, w: Int, left: Bool) -> String:
    var p = String("")
    for _ in range(w - s.byte_length()):
        p += " "
    return s + p if left else p + s
