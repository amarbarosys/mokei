# Copyright 2026 amarbaro.org. Licensed under the Apache License, Version 2.0.
# mokei --semantic: statements, functions, max nesting and a cyclomatic estimate per file, by token rules.
from core import Lang, at, is_word, jstr, lang_of, pad

# families: 0 = indentation (Python, Mojo), 1 = braces (JavaScript, Rust, C)
# Definitions (documented in docs/semantic.md):
#   statements  indentation: logical code lines; braces: ';' outside parentheses plus if/for/while/switch/match/loop/try keywords
#   functions   def/fn keywords; JavaScript also each '=>'; C: ') {' at brace depth 0
#   nesting     indentation levels / brace depth
#   cyclomatic  1 + decisions: if elif for while except case and or (indentation); if for while case catch && || ?? ?: (JS);
#               if for while && || and match arms '=>' (Rust); if for while case && || ?: (C)


def family(name: String) -> Int:
    """0 indentation, 1 braces, -1 not supported."""
    if name == "Python" or name == "Mojo":
        return 0
    if name == "JavaScript" or name == "Rust" or name == "C":
        return 1
    return -1


def clean(b: Span[UInt8, _], name: String) -> List[UInt8]:
    """Copy of b with comments and string/char literal bodies replaced by spaces (newlines kept)."""
    var n = len(b)
    var o = List[UInt8](length=n, fill=32)
    var py = family(name) == 0
    var i = 0
    while i < n:
        var c = b[i]
        if c == 10:
            o[i] = 10
            i += 1
        elif py and c == 35:  # '#'
            while i < n and b[i] != 10:
                i += 1
        elif not py and c == 47 and i + 1 < n and b[i + 1] == 47:  # //
            while i < n and b[i] != 10:
                i += 1
        elif not py and c == 47 and i + 1 < n and b[i + 1] == 42:  # /* */
            i += 2
            while i < n and not (b[i] == 42 and i + 1 < n and b[i + 1] == 47):
                if b[i] == 10:
                    o[i] = 10
                i += 1
            i += 2
        elif name == "C" and c == 35 and blank_before(b, i):  # preprocessor line
            while i < n and b[i] != 10:
                i += 1
        elif c == 34 or c == 39 or (c == 96 and name == "JavaScript"):
            var q = c
            var triple = py and i + 2 < n and b[i + 1] == q and b[i + 2] == q
            if name == "Rust" and q == 39:  # lifetime or char literal
                var ch = i + 3 < n and b[i + 2] == 39 or (i + 3 < n and b[i + 1] == 92)
                if not ch:
                    o[i] = c
                    i += 1
                    continue
            o[i] = q
            i += 3 if triple else 1
            while i < n:
                if b[i] == 92:
                    i += 2
                    continue
                if triple:
                    if b[i] == q and i + 2 < n and b[i + 1] == q and b[i + 2] == q:
                        i += 3
                        break
                elif b[i] == q or (b[i] == 10 and q != 96 and not (name == "Rust")):
                    if b[i] == q:
                        o[i] = q
                        i += 1
                    break
                if b[i] == 10:
                    o[i] = 10
                i += 1
        else:
            o[i] = c
            i += 1
    return o^


def blank_before(b: Span[UInt8, _], i: Int) -> Bool:
    var j = i
    while j > 0 and (b[j - 1] == 32 or b[j - 1] == 9):
        j -= 1
    return j == 0 or b[j - 1] == 10


def word_at(t: Span[UInt8, _], i: Int, w: String) -> Bool:
    """Whole word w at byte i."""
    if not at(t, i, w):
        return False
    var e = i + w.byte_length()
    return (i == 0 or not is_word(t[i - 1])) and (e >= len(t) or not is_word(t[e]))


def semantic(b: Span[UInt8, _], name: String) -> List[Int]:
    """[statements, functions, max nesting, cyclomatic] of the file."""
    var t = clean(b, name)
    var n = len(t)
    var stmts = 0
    var funcs = 0
    var nest = 0
    var cc = 1
    var py = family(name) == 0
    var rust = name == "Rust"
    var js = name == "JavaScript"
    var depth = 0  # brace depth
    var paren = 0  # parenthesis and bracket depth
    var indents = List[Int]()
    indents.append(0)
    var i = 0
    var bol = True  # at the start of a logical line (indentation family)
    var cont = False  # previous logical line continues with a backslash
    while i < n:
        var c = t[i]
        if py:
            if c == 10:
                bol = paren == 0 and not cont
                cont = False
                i += 1
                continue
            if c == 92 and i + 1 < n and t[i + 1] == 10:
                cont = True
                i += 1
                continue
            if bol:
                var col = 0
                var j = i
                while j < n and (t[j] == 32 or t[j] == 9):
                    col += 1 if t[j] == 32 else 8
                    j += 1
                if j < n and t[j] != 10:
                    while col < indents[len(indents) - 1]:
                        _ = indents.pop()
                    if col > indents[len(indents) - 1]:
                        indents.append(col)
                    nest = max(nest, len(indents) - 1)
                    stmts += 1
                    if word_at(t, j, "def") or word_at(t, j, "fn") or (word_at(t, j, "async") and word_at(t, j + 6, "def")):
                        funcs += 1
                    bol = False
                i = j
                continue
        if c == 40 or c == 91:
            paren += 1
        elif c == 41 or c == 93:
            paren = max(0, paren - 1)
        elif c == 123 and not py:
            depth += 1
            nest = max(nest, depth)
        elif c == 125 and not py:
            depth = max(0, depth - 1)
        elif c == 59 and not py and paren == 0:
            stmts += 1
        if is_word(c) and (i == 0 or not is_word(t[i - 1])):
            if py:
                if word_at(t, i, "if") or word_at(t, i, "elif") or word_at(t, i, "for") or word_at(t, i, "while") or word_at(t, i, "except") or word_at(t, i, "case") or word_at(t, i, "and") or word_at(t, i, "or"):
                    cc += 1
            else:
                var ctl = word_at(t, i, "if") or word_at(t, i, "for") or word_at(t, i, "while")
                if ctl or word_at(t, i, "switch") or word_at(t, i, "match") or word_at(t, i, "loop") or word_at(t, i, "try"):
                    stmts += 1
                if ctl or (word_at(t, i, "case") and not rust) or (word_at(t, i, "catch") and js):
                    cc += 1
                if (word_at(t, i, "function") and js) or (word_at(t, i, "fn") and rust):
                    funcs += 1
        elif not py and c == 38 and i + 1 < n and t[i + 1] == 38:  # &&
            cc += 1
            i += 1
        elif not py and c == 124 and i + 1 < n and t[i + 1] == 124:  # ||
            cc += 1
            i += 1
        elif js and c == 63 and i + 1 < n and t[i + 1] == 63:  # ??
            cc += 1
            i += 1
        elif (js or name == "C") and c == 63 and not (i + 1 < n and t[i + 1] == 46 and js):  # ?: but not ?.
            cc += 1
        elif c == 61 and i + 1 < n and t[i + 1] == 62 and not py:  # =>
            if js:
                funcs += 1
            elif rust:
                cc += 1
            i += 1
        elif name == "C" and c == 123 and depth == 1 and prev_is_paren(t, i):
            funcs += 1
        i += 1
    return [stmts, funcs, nest, cc]


def prev_is_paren(t: Span[UInt8, _], i: Int) -> Bool:
    """The last non-blank byte before i is ')'."""
    var j = i
    while j > 0 and (t[j - 1] == 32 or t[j - 1] == 9 or t[j - 1] == 10 or t[j - 1] == 13):
        j -= 1
    return j > 0 and t[j - 1] == 41


def report(files: List[String], L: List[Lang], by_name: Dict[String, Int], by_ext: Dict[String, Int], by_sh: Dict[String, Int], as_json: Bool) raises:
    """Prints the semantic metrics of every supported file, a table or one JSON line."""
    var names = List[String]()
    var langs = List[String]()
    var vals = List[List[Int]]()
    var w = 6
    for f in files:
        var k = lang_of(f, by_name, by_ext, by_sh)
        if k < 0 or family(L[k].name) < 0:
            continue
        var s = open(f, "r").read_bytes()
        names.append(f)
        langs.append(L[k].name)
        vals.append(semantic(s, L[k].name))
        w = max(w, f.byte_length() + 2)
    var tot: List[Int] = [0, 0, 0, 0]
    for v in vals:
        tot[0] += v[0]
        tot[1] += v[1]
        tot[2] = max(tot[2], v[2])
        tot[3] += v[3]
    var keys = ["statements", "functions", "max_nesting", "cyclomatic"]
    if as_json:
        var js = String('{"files":[')
        for i in range(len(names)):
            js += (',' if i > 0 else '') + '{"name":' + jstr(names[i]) + ',"language":' + jstr(langs[i])
            for j in range(4):
                js += ',"' + keys[j] + '":' + String(vals[i][j])
            js += "}"
        js += '],"total":{'
        for j in range(4):
            js += (',' if j > 0 else '') + '"' + keys[j] + '":' + String(tot[j])
        print(js + "}}")
        return
    var hdr = pad("File", w, True) + pad("Language", 12, True)
    for h in ["Stmts", "Funcs", "Nest", "Cyclo"]:
        hdr += pad(String(h), 8, False)
    print(hdr)
    for i in range(len(names)):
        var row = pad(names[i], w, True) + pad(langs[i], 12, True)
        for j in range(4):
            row += pad(String(vals[i][j]), 8, False)
        print(row)
    var trow = pad("Total", w, True) + pad("", 12, True)
    for j in range(4):
        trow += pad(String(tot[j]), 8, False)
    print(trow)
