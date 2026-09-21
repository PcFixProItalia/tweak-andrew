# Legge catalog/*.txt e lang/cat_*.tsv e scrive src/partK_data.ps1.
# Controlla la forma di ogni riga: un errore qui evita un catalogo rotto a runtime.
import io, os, re, sys, glob

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
LANGS = ['it', 'en', 'es', 'de', 'fr', 'pl', 'pt', 'ro', 'ru']
TYPES = re.compile(r'^(D|S|E|Q|B|Key|Byte:\d+|Bit:\d+:0x[0-9A-Fa-f]+|Kv:[A-Za-z0-9]+)$')

def q(s):
    return "'" + s.replace("'", "''") + "'"

items, texts, tips, errors = [], {}, {}, []
page = group = None
cur = None

def err(f, n, m):
    errors.append('%s:%d %s' % (os.path.basename(f), n, m))

files = [os.path.join(ROOT, 'catalog', x) for x in ('catalog.txt', 'privacy_pro.txt', 'power.txt')]
for f in files:
    for n, line in enumerate(io.open(f, encoding='utf-8'), 1):
        line = line.rstrip('\r\n')
        if not line.strip() or line.startswith('#'):
            continue
        p = line.split('|')
        k = p[0]
        if k == 'P':
            page = p[1]; group = None
        elif k == 'G':
            group = p[1]
            texts['g.%s.%s' % (page, group)] = {'it': p[2], 'en': p[3]}
        elif k in ('T', 'S', 'J'):
            if len(p) != 7: err(f, n, 'campi attesi 7'); continue
            cur = {'Id': p[1], 'Page': page, 'Group': group, 'Kind': k, 'Flags': p[2], 'Def': p[3], 'Rec': p[4], 'Ops': [], 'Opts': [], 'Tasks': []}
            texts[p[1]] = {'it': p[5], 'en': p[6]}
            items.append(cur)
        elif k == 'V':
            if len(p) != 8: err(f, n, 'campi attesi 8'); continue
            cur = {'Id': p[1], 'Page': page, 'Group': group, 'Kind': 'V', 'Flags': p[2], 'Svcs': p[3].split(','), 'Def': p[4], 'Rec': p[5], 'Ops': [], 'Opts': [], 'Tasks': []}
            texts[p[1]] = {'it': p[6], 'en': p[7]}
            items.append(cur)
        elif k == 'N':
            if len(p) != 9: err(f, n, 'campi attesi 9'); continue
            cur = {'Id': p[1], 'Page': page, 'Group': group, 'Kind': 'N', 'Flags': p[2], 'Sub': p[3], 'Set': p[4], 'Def': p[5], 'Rec': p[6], 'Ops': [], 'Opts': [], 'Tasks': []}
            texts[p[1]] = {'it': p[7], 'en': p[8]}
            items.append(cur)
        elif k == 'R':
            if cur is None: err(f, n, 'R senza voce'); continue
            if not TYPES.match(p[3]): err(f, n, 'tipo sconosciuto ' + p[3])
            if not re.match(r'^(HKCU|HKLM|HKCR)\\', p[1]): err(f, n, 'radice sconosciuta')
            if cur['Kind'] == 'T':
                if len(p) != 6: err(f, n, 'R di T vuole 6 campi'); continue
                cur['Ops'].append(p[1:6])
            else:
                if len(p) != 4: err(f, n, 'R di S vuole 4 campi'); continue
                cur['Ops'].append(p[1:4])
        elif k == 'O':
            if cur is None: err(f, n, 'O senza voce'); continue
            key = p[1]
            texts['%s#%s' % (cur['Id'], key)] = {'it': p[2], 'en': p[3]}
            vals = p[4:]
            if cur['Kind'] == 'S' and len(vals) != len(cur['Ops']):
                err(f, n, 'valori %d, registri %d' % (len(vals), len(cur['Ops'])))
            cur['Opts'].append({'Key': key, 'Vals': vals})
        elif k == 'Q':
            cur['Tasks'].append(p[1])
        elif k == 'H':
            tips[p[1]] = {'it': p[2], 'en': p[3]}
        else:
            err(f, n, 'riga sconosciuta ' + k)

ids = [i['Id'] for i in items]
for d in set(x for x in ids if ids.count(x) > 1):
    errors.append('id doppio ' + d)
for i in items:
    if i['Id'] not in tips: errors.append('manca H per ' + i['Id'])
    if i['Kind'] in ('S', 'N'):
        keys = [o['Key'] for o in i['Opts']]
        if i['Def'] not in keys and i['Kind'] == 'S': errors.append('predefinito assente ' + i['Id'])
        if i['Rec'] != '-' and i['Rec'] not in keys: errors.append('consigliato assente ' + i['Id'])
    if i['Kind'] == 'T' and not i['Ops']: errors.append('T senza R ' + i['Id'])
    if i['Kind'] == 'J' and not i['Tasks']: errors.append('J senza Q ' + i['Id'])

# Traduzioni: lang/cat_<lingua>.tsv con chiave<TAB>testo, e H:chiave per le descrizioni.
for lg in LANGS[2:]:
    path = os.path.join(ROOT, 'lang', 'cat_%s.tsv' % lg)
    if not os.path.exists(path): continue
    for line in io.open(path, encoding='utf-8'):
        line = line.rstrip('\r\n')
        if not line or '\t' not in line: continue
        key, val = line.split('\t', 1)
        if key.startswith('H:'):
            key = key[2:]
            if key in tips: tips[key][lg] = val
            else: errors.append('%s: descrizione sconosciuta %s' % (lg, key))
        elif key in texts: texts[key][lg] = val
        else: errors.append('%s: chiave sconosciuta %s' % (lg, key))

if errors:
    print('\n'.join(errors[:60])); print('ERRORI: %d' % len(errors)); sys.exit(1)

def entry(d):
    return '@{ ' + '; '.join('%s = %s' % (lg, q(d[lg])) for lg in LANGS if d.get(lg)) + ' }'

out = ['# ------------------------------------------------------------------------------',
       '# 27. CATALOGO DELLE IMPOSTAZIONI A INTERRUTTORE (generato da tools/gen_catalog.py)',
       '# ------------------------------------------------------------------------------',
       '$script:Catalog = @(']
rows = []
for i in items:
    f = ["Id = %s" % q(i['Id']), "Page = %s" % q(i['Page']), "Group = %s" % q(i['Group']),
         "Kind = %s" % q(i['Kind']), "Flags = %s" % q(i['Flags']), "Def = %s" % q(i['Def']), "Rec = %s" % q(i['Rec'])]
    if i['Ops']:
        # La virgola davanti impedisce a PowerShell di appiattire un elenco con un solo registro.
        f.append('Ops = @(' + ', '.join(',@(' + ', '.join(q(x) for x in op) + ')' for op in i['Ops']) + ')')
    if i['Opts']:
        f.append('Opts = @(' + ', '.join('@{ Key = %s; Vals = @(%s) }' % (q(o['Key']), ', '.join(q(v) for v in o['Vals'])) for o in i['Opts']) + ')')
    if i['Tasks']:
        f.append('Tasks = @(' + ', '.join(q(t) for t in i['Tasks']) + ')')
    if i['Kind'] == 'V':
        f.append('Svcs = @(' + ', '.join(q(s) for s in i['Svcs']) + ')')
    if i['Kind'] == 'N':
        f.append('Sub = %s' % q(i['Sub'])); f.append('Set = %s' % q(i['Set']))
    rows.append('    @{ ' + '; '.join(f) + ' }')
out.append(',\n'.join(rows))
out.append(')')
out.append('')
out.append('$script:CatText = @{')
for k, v in texts.items():
    out.append('    %s = %s' % (q(k), entry(v)))
out.append('}')
out.append('')
out.append('$script:CatTip = @{')
for k, v in tips.items():
    out.append('    %s = %s' % (q(k), entry(v)))
out.append('}')
io.open(os.path.join(ROOT, 'src', 'partK_data.ps1'), 'w', encoding='utf-8').write('\n'.join(out) + '\n')

cnt = {}
for i in items: cnt[i['Page']] = cnt.get(i['Page'], 0) + 1
print('OK: %d voci %s, %d testi, %d descrizioni' % (len(items), cnt, len(texts), len(tips)))
missing = {lg: sum(1 for v in texts.values() if lg not in v) for lg in LANGS[2:]}
print('testi senza traduzione:', missing)

# ---- catalogo delle app ----
apps, cats, aerr = [], [], []
for n, line in enumerate(io.open(os.path.join(ROOT, 'catalog', 'apps.txt'), encoding='utf-8'), 1):
    line = line.rstrip('\r\n')
    if not line.strip() or line.startswith('#'): continue
    p = line.split('|')
    if p[0] == 'C':
        cats.append((p[1], p[2], p[3]))
    elif p[0] == 'A':
        if len(p) != 6 or p[3] not in ('os', 'fw', 'fr', 'ms', 'pd'): aerr.append('apps.txt:%d' % n); continue
        apps.append((cats[-1][0],) + tuple(p[1:]))
ids = [a[1] for a in apps]
aerr += ['id doppio ' + x for x in set(ids) if ids.count(x) > 1]
if aerr:
    print('\n'.join(aerr)); sys.exit(1)
o = ['# Catalogo delle app installabili (generato da tools/gen_catalog.py)', '$script:AppCategories = @(']
o.append(',\n'.join('    @{ Key = %s; Text = @{ it = %s; en = %s } }' % (q(c[0]), q(c[1]), q(c[2])) for c in cats))
o.append(')')
o.append('$script:AppCatalog = @(')
o.append(',\n'.join('    @{ Cat = %s; Id = %s; Name = %s; Lic = %s; Desc = @{ it = %s; en = %s } }' % tuple(q(x) for x in a) for a in apps))
o.append(')')
io.open(os.path.join(ROOT, 'src', 'partApps_data.ps1'), 'w', encoding='utf-8').write('\n'.join(o) + '\n')
print('OK: %d app in %d categorie' % (len(apps), len(cats)))
