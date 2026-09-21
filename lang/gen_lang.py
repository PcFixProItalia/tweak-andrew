"""Genera partL.ps1: descrizioni delle voci e traduzioni nelle altre lingue."""
import io, os

HERE = os.path.dirname(os.path.abspath(__file__))
SP = os.path.join(os.path.dirname(HERE), "src")
LANGS = ["es", "de", "fr", "pl", "pt", "ro", "ru"]


def ps(s):
    # Stringa PowerShell tra virgolette doppie: si proteggono ` $ " e si
    # trasforma \n nell'a capo di PowerShell.
    s = s.replace("`", "``").replace("$", "`$").replace('"', '`"')
    return '"' + s.replace("\\n", "`n") + '"'


def read_tsv(path):
    rows = []
    for n, line in enumerate(io.open(path, encoding="utf-8"), 1):
        line = line.rstrip("\n")
        if not line.strip():
            continue
        parts = line.split("\t")
        rows.append((n, parts))
    return rows


loc_keys = [l.split("\t")[0] for l in io.open(os.path.join(HERE, "Loc_src.tsv"), encoding="utf-8") if l.strip()]
msg_keys = [l.split("\t")[0] for l in io.open(os.path.join(HERE, "Msg_src.tsv"), encoding="utf-8") if l.strip()]
loc_keys = [k for k in loc_keys if k != "chkClockSeconds"]

out = []
out.append("")
out.append("# ------------------------------------------------------------------------------")
out.append("# 3b. DESCRIZIONI DELLE VOCI E ALTRE LINGUE")
out.append("# ------------------------------------------------------------------------------")
out.append("# Le descrizioni compaiono passando con il mouse su una voce: dicono cosa fa")
out.append("# e cosa si guadagna, senza entrare nel come. Le lingue oltre a italiano e")
out.append("# inglese stanno qui; una chiave mancante ripiega sull'inglese.")
out.append("$script:Tips = @{")
tip_keys = []
for n, p in read_tsv(os.path.join(HERE, "tips_it_en.tsv")):
    assert len(p) == 3, ("tips", n, p)
    tip_keys.append(p[0])
    out.append("    %s = @{ it = %s; en = %s }" % (p[0], ps(p[1]), ps(p[2])))
out.append("}")
out.append("")

report = []
out.append("$script:Tr = @{")
for lang in LANGS:
    path = os.path.join(HERE, "tr_%s.tsv" % lang)
    if not os.path.exists(path):
        report.append("%s: file assente" % lang)
        continue
    out.append("    %s = @{" % lang)
    seen = set()
    for n, p in read_tsv(path):
        assert len(p) == 2, (lang, n, p)
        key, text = p
        kind, name = key.split(":", 1)
        assert kind in ("L", "M", "H"), (lang, n, key)
        pool = {"L": loc_keys, "M": msg_keys, "H": tip_keys}[kind]
        assert name in pool, (lang, n, "chiave sconosciuta", key)
        assert key not in seen, (lang, n, "doppia", key)
        seen.add(key)
        out.append("        '%s' = %s" % (key, ps(text)))
    out.append("    }")
    miss_l = [k for k in loc_keys if "L:" + k not in seen]
    miss_m = [k for k in msg_keys if "M:" + k not in seen]
    miss_h = [k for k in tip_keys if "H:" + k not in seen]
    report.append("%s: %d voci, mancano L=%d M=%d H=%d  %s" % (
        lang, len(seen), len(miss_l), len(miss_m), len(miss_h),
        " ".join(miss_m + miss_h)))
out.append("}")
out.append("")
out.append("foreach ($lang in $script:Tr.Keys) {")
out.append("    foreach ($entry in $script:Tr[$lang].GetEnumerator()) {")
out.append("        $kind, $name = $entry.Key -split ':', 2")
out.append("        $table = switch ($kind) { 'L' { $script:Loc } 'M' { $script:Msg } 'H' { $script:Tips } }")
out.append("        if ($table.ContainsKey($name)) { $table[$name][$lang] = $entry.Value }")
out.append("    }")
out.append("}")
out.append("")

io.open(os.path.join(SP, "partL.ps1"), "w", encoding="utf-8").write("\n".join(out))
print("\n".join(report))
print("descrizioni:", len(tip_keys))
