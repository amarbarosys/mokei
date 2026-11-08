# Copyright 2026 amarbaro.org. Licensed under the Apache License, Version 2.0.
# mokei --untested: defs whose name appears in no test file. A hint (name match only), never a verdict.
# Test files: a path with a test/tests/__tests__ directory, or a name test_*, *_test.*, *.test.*, *.spec.*.
# Defs (comments and strings blanked first): Python/Mojo def and fn, JavaScript/TypeScript function NAME, Rust fn NAME.
# Skipped: main, dunder names, names starting with test.
from semantic import clean, word_at
from core import Lang, is_word, jstr, lang_of


def is_test_path(p: String) -> Bool:
    var parts = p.split("/")
    for i in range(len(parts) - 1):
        if parts[i] == "test" or parts[i] == "tests" or parts[i] == "__tests__":
            return True
    var base = String(parts[len(parts) - 1])
    if base.startswith("test_") or base.startswith("test."):
        return True
    for m in ["_test.", ".test.", ".spec."]:
        if base.find(m) >= 0:
            return True
    return False


def ident_end(t: Span[UInt8, _], i: Int) -> Int:
    var j = i
    while j < len(t) and is_word(t[j]):
        j += 1
    return j


def untested_report(files: List[String], L: List[Lang], by_name: Dict[String, Int], by_ext: Dict[String, Int], by_sh: Dict[String, Int], as_json: Bool) raises:
    var used = Dict[String, Int]()  # every identifier seen in a test file
    for f in files:
        if not is_test_path(f):
            continue
        var b = open(f, "r").read_bytes()
        var i = 0
        while i < len(b):
            if is_word(b[i]):
                var j = ident_end(b, i)
                used[String(unsafe_from_utf8=b[i:j])] = 1
                i = j
            else:
                i += 1
    var ofile = List[String]()
    var oline = List[Int]()
    var oname = List[String]()
    var defs = 0
    for f in files:
        if is_test_path(f):
            continue
        var k = lang_of(f, by_name, by_ext, by_sh)
        if k < 0:
            continue
        var lname = L[k].name
        var py = lname == "Python" or lname == "Mojo"
        var js = lname == "JavaScript" or lname == "TypeScript"
        if not (py or js or lname == "Rust"):
            continue
        var t = clean(open(f, "r").read_bytes(), "JavaScript" if lname == "TypeScript" else lname)
        var line = 1
        var i = 0
        while i < len(t):
            if t[i] == 10:
                line += 1
            if is_word(t[i]) and (i == 0 or not is_word(t[i - 1])):
                var kw = 0
                if py and (word_at(t, i, "def") or word_at(t, i, "fn")):
                    kw = 3 if word_at(t, i, "def") else 2
                elif js and word_at(t, i, "function"):
                    kw = 8
                elif lname == "Rust" and word_at(t, i, "fn"):
                    kw = 2
                var j = ident_end(t, i)
                if kw > 0:
                    var a = i + kw
                    while a < len(t) and (t[a] == 32 or t[a] == 9):
                        a += 1
                    var e = ident_end(t, a)
                    if e > a and a > i + kw:
                        var nm = String(unsafe_from_utf8=t[a:e])
                        if nm != "main" and not (nm.startswith("__") and nm.endswith("__")) and not nm.startswith("test"):
                            defs += 1
                            if nm not in used:
                                ofile.append(f)
                                oline.append(line)
                                oname.append(nm)
                i = j
            else:
                i += 1
    if as_json:
        var js2 = String('{"defs":' + String(defs) + ',"untested":[')
        for q in range(len(ofile)):
            js2 += (',' if q > 0 else '') + '{"file":' + jstr(ofile[q]) + ',"line":' + String(oline[q]) + ',"name":' + jstr(oname[q]) + "}"
        print(js2 + "]}")
        return
    for q in range(len(ofile)):
        print(ofile[q] + ":" + String(oline[q]) + " " + oname[q])
    print(String(len(ofile)) + " untested of " + String(defs) + " defs (hint: a name match in a test file, nothing more)")
