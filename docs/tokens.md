# mokei --tokens

`mokei --tokens [FILES|DIR]` prints files, bytes and tokens per language (`--files` per file, `--json`).

- Default: a byte-level estimate, one pass, no model. Pieces: newline run with its indentation, blank run, each digit, word (letters and underscore) plus one extra unit per 6 further letters, symbol byte, non-ASCII character; weights fitted by least squares on per-file counts of the Qwen2.5 tokenizer (`estimate()` in tokens.mojo).
- `--tokenizer PATH`: the real count from a Hugging Face `tokenizer.json` (byte-level BPE, WordPiece, Unigram) through [mojo-tokenizers](https://github.com/amarbaro/mojo-tokenizers) (ids equal the Python crate's). Single-threaded; ~0.1 s for a small repo, minutes for a 140 MB tree. Build with `./build.sh` (`MOKEI_TOKENIZERS` = that library's `src`).

Measured (`tools/token-measure.sh`, Qwen2.5-0.5B tokenizer, estimate against real):

| set | total | languages of >= 50 kB |
|---|---|---|
| fit corpus: mokei, TOR-Telegram-Shop, iTools (2.3 MB of source) | -2.9% | Python -3.1, Shell -3.3, Mojo -4.9, Markdown -1.7, TOML +1.4, HTML, JSON, JavaScript all within 6% |
| hold-out, not in the fit: mojo-vattn, corewait | within 6% | Markdown -1.4, Shell -1.9, Mojo -5.4 |

The weights suit a Qwen-like tokenizer (single digits). Another tokenizer (Llama 3 groups digits by 3) shifts number-heavy files; use `--tokenizer` for a real count.
