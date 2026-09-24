# Porta i testi di lang/v7_strings.txt dentro partC (italiano e inglese), nei
# file sorgente delle lingue e nelle descrizioni. Si puo' rilanciare: le chiavi
# gia' presenti vengono aggiornate, non duplicate.
import io, os, re
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LANG = os.path.join(ROOT, 'lang')
OTHER = ['es', 'de', 'fr', 'pl', 'pt', 'ro', 'ru']

def ps(s):
    return '"' + s.replace('`', '``').replace('$', '`$').replace('"', '`"') + '"'

rows = []
for line in io.open(os.path.join(LANG, 'v7_strings.txt'), encoding='utf-8'):
    line = line.rstrip('\r\n')
    if not line or line.startswith('#'): continue
    p = line.split('|')
    if p[0] in ('L', 'M'): assert len(p) == 11, p[:2]
    else: assert len(p) in (4, 11), p[:2]
    rows.append(p)

partc = os.path.join(ROOT, 'src', 'partC.ps1')
t = io.open(partc, encoding='utf-8').read()

def upsert_block(t, block, key, it, en):
    start = t.index('$script:%s = @{' % block)
    end = t.index('\n}', start)
    body = t[start:end]
    line = '    %s = @{ it = %s; en = %s }' % (key.ljust(18), ps(it), ps(en))
    m = re.search(r'(?m)^    %s\s*=.*$' % re.escape(key), body)
    if m:
        body = body[:m.start()] + line + body[m.end():]
    else:
        body = body + '\n' + line
    return t[:start] + body + t[end:]

def upsert_tsv(path, key, value):
    lines = io.open(path, encoding='utf-8').read().splitlines() if os.path.exists(path) else []
    new = key + '\t' + value
    for i, l in enumerate(lines):
        if l.split('\t', 1)[0] == key:
            lines[i] = new; break
    else:
        lines.append(new)
    io.open(path, 'w', encoding='utf-8').write('\n'.join(lines) + '\n')

for p in rows:
    kind, key = p[0], p[1]
    if kind in ('L', 'M'):
        t = upsert_block(t, 'Loc' if kind == 'L' else 'Msg', key, p[2], p[3])
        upsert_tsv(os.path.join(LANG, 'Loc_src.tsv' if kind == 'L' else 'Msg_src.tsv'), key, p[3])
        for lg, text in zip(OTHER, p[4:]):
            upsert_tsv(os.path.join(LANG, 'tr_%s.tsv' % lg), '%s:%s' % (kind, key), text)
    else:
        upsert_tsv(os.path.join(LANG, 'tips_it_en.tsv'), key, p[2] + '\t' + p[3])
        # Le descrizioni scritte in tutte le lingue portano anche le altre sette.
        for lg, text in zip(OTHER, p[4:]):
            upsert_tsv(os.path.join(LANG, 'tr_%s.tsv' % lg), 'H:%s' % key, text)

io.open(partc, 'w', encoding='utf-8').write(t)
print('testi uniti:', len(rows))
