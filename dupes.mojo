# Copyright 2026 amarbaro.org. Licensed under the Apache License, Version 2.0.
# mokei --dupes N: blocks of at least N consecutive normalized code lines that occur twice.
# Comments and blank lines are skipped (the scanner classifies them), whitespace runs collapse to one space,
# a rolling hash over windows of N code-line hashes finds candidates, equal line hashes confirm them, and
# consecutive matching windows merge into one maximal block.
from core import Lang, count_lines, jstr, lang_of, pad


def line_hash(b: Span[UInt8, _], a: Int, e: Int) -> UInt64:
    """FNV-1a of the line a..e with leading and trailing blanks cut and inner runs of blanks folded to one space."""
    var h: UInt64 = 14695981039346656037
    var pending = False
    var started = False
    for i in range(a, e):
        var c = b[i]
        if c == 32 or c == 9 or c == 13:
            pending = started
            continue
        if pending:
            h = (h ^ 32) * 1099511628211
            pending = False
        h = (h ^ UInt64(c)) * 1099511628211
        started = True
    return h


def file_of(starts: List[Int], g: Int) -> Int:
    """Index of the file holding global code line g (binary search over starts)."""
    var lo = 0
    var hi = len(starts) - 1
    while lo < hi:
        var mid = (lo + hi + 1) // 2
        if starts[mid] <= g:
            lo = mid
        else:
            hi = mid - 1
    return lo


def dupes_report(files: List[String], n: Int, L: List[Lang], by_name: Dict[String, Int], by_ext: Dict[String, Int], by_sh: Dict[String, Int], as_json: Bool) raises:
    if n < 2:
        raise Error("FAIL args: --dupes takes N >= 2")
    var names = List[String]()
    var starts = List[Int]()  # per file: global index of its first code line
    var hs = List[UInt64]()  # per code line: hash
    var lns = List[Int32]()  # per code line: line number in its file
    for f in files:
        var k = lang_of(f, by_name, by_ext, by_sh)
        if k < 0:
            continue
        var b = open(f, "r").read_bytes()
        var res: List[Int] = [0, 0, 0, 0]
        var kinds = List[UInt8]()
        count_lines[True](b, L[k], res, kinds)
        names.append(f)
        starts.append(len(hs))
        var ln = 0
        var a = 0
        for i in range(len(b) + 1):
            if i == len(b) or b[i] == 10:
                if ln < len(kinds) and kinds[ln] == 1:
                    hs.append(line_hash(b, a, i))
                    lns.append(Int32(ln + 1))
                ln += 1
                a = i + 1
    starts.append(len(hs))  # sentinel
    var base: UInt64 = 1000003
    var top: UInt64 = 1  # base^(n-1)
    for _ in range(n - 1):
        top *= base
    var seen = Dict[UInt64, Int]()
    var blocks = List[List[Int]]()  # first global index, second global index, length in code lines
    for f in range(len(names)):
        var s0 = starts[f]
        var cnt = starts[f + 1] - s0
        if cnt < n:
            continue
        var h: UInt64 = 0
        for t in range(n):
            h = h * base + hs[s0 + t]
        var last_j = -1  # earlier window the previous window matched
        for pos in range(cnt - n + 1):
            var g = s0 + pos
            if pos > 0:
                h = (h - hs[g - 1] * top) * base + hs[g + n - 1]
            var matched = -1
            if h in seen:
                var j = seen[h]
                var ok = j + n <= g or file_of(starts, j) != f
                if ok:
                    for t in range(n):
                        if hs[j + t] != hs[g + t]:
                            ok = False
                            break
                if ok:
                    matched = j
            if matched >= 0:
                if last_j >= 0 and matched == last_j + 1:
                    blocks[len(blocks) - 1][2] += 1
                else:
                    blocks.append([matched, g, n])
            else:
                if h not in seen:
                    seen[h] = g
            last_j = matched
    var order = List[Int]()
    for i in range(len(blocks)):
        var ins = len(order)
        order.append(i)
        while ins > 0 and blocks[order[ins - 1]][2] < blocks[i][2]:
            order[ins] = order[ins - 1]
            ins -= 1
        order[ins] = i
    var total = 0
    for i in order:
        total += blocks[i][2]
    if as_json:
        var js = String('{"min_lines":' + String(n) + ',"blocks":[')
        for oi in range(len(order)):
            ref bl = blocks[order[oi]]
            var fa = file_of(starts, bl[0])
            var fb = file_of(starts, bl[1])
            js += (',' if oi > 0 else '') + '{"lines":' + String(bl[2])
            js += ',"a":{"file":' + jstr(names[fa]) + ',"from":' + String(Int(lns[bl[0]])) + ',"to":' + String(Int(lns[bl[0] + bl[2] - 1])) + "}"
            js += ',"b":{"file":' + jstr(names[fb]) + ',"from":' + String(Int(lns[bl[1]])) + ',"to":' + String(Int(lns[bl[1] + bl[2] - 1])) + "}}"
        print(js + '],"duplicate_lines":' + String(total) + "}")
        return
    for i in order:
        ref bl = blocks[i]
        var fa = file_of(starts, bl[0])
        var fb = file_of(starts, bl[1])
        print(String(bl[2]) + " lines  " + names[fa] + ":" + String(Int(lns[bl[0]])) + "-" + String(Int(lns[bl[0] + bl[2] - 1])) + "  ==  " + names[fb] + ":" + String(Int(lns[bl[1]])) + "-" + String(Int(lns[bl[1] + bl[2] - 1])))
    print(String(len(blocks)) + " blocks, " + String(total) + " duplicated code lines (blocks of >= " + String(n) + " code lines)")
