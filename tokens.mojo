# mokei --tokens [--tokenizer PATH]: tokens per language (and per file).
# Default: a byte-level estimate. With --tokenizer: the real count from a Hugging Face tokenizer.json (BPE, via mojo-tokenizers).
from tokenizers import Tokenizer
from core import Lang, is_word, jstr, lang_of, pad


def estimate(b: Span[UInt8, _]) -> Int:
    """Tokens of the text by pieces, weights fitted on the corpus against the Qwen2.5 tokenizer (tools/token-measure.sh).

    pieces: a newline run with its indentation, a blank run, a digit (each one), a word (letters and
    underscore) plus (len - 1) // 6 extra units, a symbol byte, a non-ASCII character. Weights in milli-tokens.
    """
    var n = len(b)
    var nl = 0
    var sp = 0
    var dg = 0
    var wd = 0
    var xw = 0
    var sy = 0
    var na = 0
    var i = 0
    while i < n:
        var c = b[i]
        if c == 10 or c == 13:
            while i < n and (b[i] == 10 or b[i] == 13 or b[i] == 32 or b[i] == 9):
                i += 1
            nl += 1
        elif c == 32 or c == 9:
            var j = i
            while j < n and (b[j] == 32 or b[j] == 9):
                j += 1
            if j - i > 1 and j < n and is_word(b[j]):
                j -= 1  # a single space glues to the next word
            if not (j - i == 1 and j < n and is_word(b[j])):
                sp += 1
            i = j + (1 if j < n and (b[j] == 32 or b[j] == 9) else 0)
        elif c >= 48 and c <= 57:
            var j = i
            while j < n and b[j] >= 48 and b[j] <= 57:
                j += 1
            dg += j - i
            i = j
        elif is_word(c):
            var j = i
            while j < n and is_word(b[j]) and not (b[j] >= 48 and b[j] <= 57):
                j += 1
            if j == i:
                j = i + 1
            wd += 1
            xw += (j - i - 1) // 6
            i = j
        elif c >= 128:
            var j = i + 1
            while j < n and b[j] >= 128 and b[j] < 192:
                j += 1
            na += 1
            i = j
        else:
            sy += 1
            i += 1
    return (nl * 966 + sp * 744 + dg * 1463 + wd * 1088 + xw * 688 + sy * 312 + na * 286) // 1000


def report(files: List[String], L: List[Lang], by_name: Dict[String, Int], by_ext: Dict[String, Int], by_sh: Dict[String, Int], tok_path: String, per_file: Bool, as_json: Bool) raises:
    var real = tok_path != ""
    var tks = List[Tokenizer]()  # empty without --tokenizer
    if real:
        tks.append(Tokenizer(tok_path))
    var rows = List[List[Int]]()  # per language: files, bytes, tokens
    for _ in range(len(L)):
        rows.append([0, 0, 0])
    var fnames = List[String]()
    var fk = List[Int]()
    var fv = List[List[Int]]()  # per file: bytes, tokens
    for f in files:
        var k = lang_of(f, by_name, by_ext, by_sh)
        if k < 0:
            continue
        var bytes = open(f, "r").read_bytes()
        if len(bytes) == 0:
            continue
        var t: Int
        if real:
            t = len(tks[0].encode(String(unsafe_from_utf8=Span(bytes))))
        else:
            t = estimate(bytes)
        rows[k][0] += 1
        rows[k][1] += len(bytes)
        rows[k][2] += t
        fnames.append(f)
        fk.append(k)
        fv.append([len(bytes), t])
    var order = List[Int]()
    for k in range(len(L)):
        if rows[k][0] > 0:
            var ins = len(order)
            order.append(k)
            while ins > 0 and rows[order[ins - 1]][2] < rows[k][2]:
                order[ins] = order[ins - 1]
                ins -= 1
            order[ins] = k
    var tot: List[Int] = [0, 0, 0]
    for k in order:
        for j in range(3):
            tot[j] += rows[k][j]
    var mode = "tokenizer" if real else "estimate"
    if as_json:
        var js = String('{"mode":"' + mode + '","languages":[')
        for oi in range(len(order)):
            var k = order[oi]
            js += (',' if oi > 0 else '') + '{"name":' + jstr(L[k].name) + ',"files":' + String(rows[k][0]) + ',"bytes":' + String(rows[k][1]) + ',"tokens":' + String(rows[k][2])
            if per_file:
                js += ',"reports":['
                var first = True
                for i in range(len(fnames)):
                    if fk[i] == k:
                        js += ('' if first else ',') + '{"name":' + jstr(fnames[i]) + ',"bytes":' + String(fv[i][0]) + ',"tokens":' + String(fv[i][1]) + "}"
                        first = False
                js += "]"
            js += "}"
        print(js + '],"total":{"files":' + String(tot[0]) + ',"bytes":' + String(tot[1]) + ',"tokens":' + String(tot[2]) + "}}")
        return
    var w = 12
    if per_file:
        for nm in fnames:
            w = max(w, nm.byte_length() + 2)
    print(pad("Language", w, True) + pad("Files", 10, False) + pad("Bytes", 12, False) + pad("Tokens", 12, False) + "  (" + mode + ")")
    for k in order:
        print(pad(L[k].name, w, True) + pad(String(rows[k][0]), 10, False) + pad(String(rows[k][1]), 12, False) + pad(String(rows[k][2]), 12, False))
        if per_file:
            for i in range(len(fnames)):
                if fk[i] == k:
                    print(pad(" " + fnames[i], w, True) + pad("1", 10, False) + pad(String(fv[i][0]), 12, False) + pad(String(fv[i][1]), 12, False))
    print(pad("Total", w, True) + pad(String(tot[0]), 10, False) + pad(String(tot[1]), 12, False) + pad(String(tot[2]), 12, False))
