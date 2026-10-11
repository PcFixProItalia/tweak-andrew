# Controllo incrociato: interruttori, azioni, ripristino, catalogo e testi.
# Prima: powershell -File tools/audit_dump.ps1 -Out tools/_audit.json
import io, json, os, re, sys, collections
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
d = json.load(io.open(os.path.join(ROOT, 'tools', '_audit.json'), encoding='utf-8-sig'))
xaml = io.open(os.path.join(ROOT, 'src', 'partB2.ps1'), encoding='utf-8').read()
BS = chr(92)
boxes = re.findall(r'<CheckBox[^>]*x:Name="(chk\w+)"', xaml)
print('Interruttori nella finestra:', len(boxes), ' doppi nel XAML:', [b for b, n in collections.Counter(boxes).items() if n > 1])

def norm(p):
    p = re.sub(r'^(HK\w+):', r'\1', p).replace('Registry::HKEY_USERS', 'HKU')
    return p.rstrip(BS).lower()

def regs(lst, names):
    out = {}
    for x in lst:
        if x['c'] in names and len(x['a']) >= 2:
            for p in str(x['a'][0]).split('||'):
                out[(norm(p), str(x['a'][1]).lower())] = x['a'][2] if len(x['a']) > 2 else None
    return out

apply, undo, noundo = d['apply'], d['undo'], set(d['noundo'])
print('\n== Interruttori senza azione di Applica')
print([b for b in boxes if b not in apply])
print('== Azioni per interruttori che non esistono nella finestra')
print([b for b in apply if b not in boxes], [b for b in undo if b not in boxes])
print('== Interruttori senza ripristino (ne\' annullamento ne\' motivo)')
print([b for b in boxes if b in apply and b not in undo and b not in noundo])

print('\n== Valori scritti da Applica e non rimessi dal ripristino')
for b in boxes:
    if b not in apply or b in noundo: continue
    a = regs(apply[b], ('Set-Reg', 'Remove-Reg')); u = regs(undo.get(b, []), ('Reset-Reg', 'Set-Reg', 'Remove-Reg'))
    miss = [k for k in a if k not in u and not k[0].startswith('?')]
    if miss: print(' ', b, miss)
    extra = [k for k in u if k not in a and not k[0].startswith('?')]
    if extra: print('  (solo nel ripristino)', b, extra)
    sa = {s for x in apply[b] if x['c'] == 'Set-Svc' for s in [x['a'][0]]}
    su = {s for x in undo.get(b, []) if x['c'] == 'Reset-Svc' for s in re.findall(r"'([^']+)'", x['t'])}
    su |= {x['a'][0] for x in undo.get(b, []) if x['c'] == 'Set-Svc'}
    if sa - su: print('  servizi non rimessi', b, sorted(sa - su))
    for c1, c2 in (('Set-GpuClassValue', 'Remove-GpuClassValue'), ('Set-PowerAc', 'Reset-PowerAc'), ('Set-NvProfile', 'Reset-NvProfile'), ('Set-AmdUmdValue', 'Remove-AmdUmdValue'), ('Set-Bcd', 'Reset-Bcd'), ('Disable-Tasks', 'Enable-Tasks')):
        n1 = sum(1 for x in apply[b] if x['c'] == c1); n2 = sum(1 for x in undo.get(b, []) if x['c'] in (c2, c1))
        if n1 and n1 != n2: print('  %s x%d contro %s x%d' % (c1, n1, c2, n2), b)

# ---- catalogo
cat = collections.defaultdict(list); svc = collections.defaultdict(list); tasks = collections.defaultdict(list); pw = collections.defaultdict(list)
titles = {}
for f in ('catalog.txt', 'privacy_pro.txt', 'power.txt'):
    cur = None
    for line in io.open(os.path.join(ROOT, 'catalog', f), encoding='utf-8'):
        p = line.rstrip('\r\n').split('|')
        if p[0] in ('T', 'S', 'J'): cur = p[1]; titles[cur] = p[5]
        elif p[0] == 'V':
            cur = p[1]; titles[cur] = p[6]
            for s in p[3].split(','): svc[s.lower()].append(cur)
        elif p[0] == 'N': cur = p[1]; titles[cur] = p[7]; pw[(p[3], p[4])].append(cur)
        elif p[0] == 'R': cat[(norm(p[1]), p[2].lower() + ('' if not p[3].startswith(('Bit', 'Byte', 'Kv')) else '#' + p[3]))].append(cur)
        elif p[0] == 'Q': tasks[p[1].lower()].append(cur)

print('\n== Doppioni dentro il catalogo (stesso valore, voci diverse)')
for k, v in cat.items():
    if len(set(v)) > 1: print(' ', k[0][-70:], k[1], sorted(set(v)))
for name, m in (('servizio', svc), ('attivita', tasks), ('piano', pw)):
    for k, v in m.items():
        if len(set(v)) > 1: print('  %s %s %s' % (name, k, sorted(set(v))))

print('\n== Doppioni tra interruttori (stesso valore di registro)')
allreg = collections.defaultdict(set); allsvc = collections.defaultdict(set); alltask = collections.defaultdict(set); allpw = collections.defaultdict(set); allbcd = collections.defaultdict(set); allgpu = collections.defaultdict(set)
for b, l in apply.items():
    for k in regs(l, ('Set-Reg', 'Remove-Reg')): allreg[k].add(b)
    for x in l:
        if x['c'] == 'Set-Svc': allsvc[str(x['a'][0]).lower()].add(b)
        if x['c'] == 'Disable-Tasks':
            for t in re.findall(r"'([^']+)'", x['t']):
                if BS in t: alltask[t.lower()].add(b)
        if x['c'] == 'Set-PowerAc': allpw[(x['a'][0], x['a'][1])].add(b)
        if x['c'] == 'Set-Bcd': allbcd[re.sub(r'\s+\S+$', '', str(x['a'][0]).lower())].add(b)
        if x['c'] == 'Set-GpuClassValue': allgpu[(str(x['a'][0]).lower(), str(x['a'][-1]).lower())].add(b)
for name, m in (('reg', allreg), ('servizio', allsvc), ('attivita', alltask), ('piano', allpw), ('bcd', allbcd), ('gpu', allgpu)):
    for k, v in m.items():
        if len(v) > 1: print('  %s %s %s' % (name, k, sorted(v)))

print('\n== Doppioni tra interruttori e catalogo')
for k, v in allreg.items():
    base = [c for kk, c in cat.items() if kk[0] == k[0] and kk[1].split('#')[0] == k[1]]
    if base: print('  reg', k[0][-70:], k[1], sorted(v), sorted({i for c in base for i in c}))
for k, v in allsvc.items():
    if k in svc: print('  servizio', k, sorted(v), svc[k])
for k, v in alltask.items():
    if k in tasks: print('  attivita', k, sorted(v), tasks[k])
for k, v in allpw.items():
    if k in pw: print('  piano', k, sorted(v), pw[k])

print('\n== Titoli uguali nel catalogo')
for t, n in collections.Counter(titles.values()).items():
    if n > 1: print('  ', t, [i for i, x in titles.items() if x == t])

print('\n== Stesso nome di valore in chiavi diverse (da guardare a mano)')
GENERIC = {'enabled', 'value', 'start', '', 'default', 'disabled', 'enable', 'state', 'type', 'data'}
byname = collections.defaultdict(set)
for k, v in allreg.items():
    for b in v: byname[k[1]].add((b, k[0]))
for k, v in cat.items():
    for i in set(v): byname[k[1].split('#')[0]].add((i, k[0]))
for n, s in sorted(byname.items()):
    owners = {o for o, _ in s}
    if n in GENERIC or len(owners) < 2: continue
    print('  %s: %s' % (n, '  |  '.join('%s @ %s' % (o, p[-55:]) for o, p in sorted(s))))

print('\n== Ripristino che riscrive lo stesso valore di Applica (resterebbe «Attivo»)')
for b in boxes:
    if b not in apply or b not in undo: continue
    a = regs(apply[b], ('Set-Reg',)); u = regs(undo[b], ('Reset-Reg', 'Set-Reg'))
    same = [k for k in a if k in u and u[k] is not None and str(u[k]).lower() == str(a[k]).lower()]
    if a and len(same) == len(a): print('  TUTTI uguali:', b, same)
    elif same: print('  alcuni uguali:', b, [k[1] for k in same])

print('\n== Percorsi o tipi sospetti in Applica')
for b, l in apply.items():
    for x in l:
        if x['c'] != 'Set-Reg': continue
        a = x['a']
        for p in str(a[0]).split('||'):
            if not p.startswith('?') and not re.match(r'^(HKLM:|HKCU:|HKCR:|Registry::)', p): print('  percorso', b, p)
        if len(a) > 3 and not str(a[3]).startswith('?'):
            if a[3] not in ('DWord', 'QWord', 'String', 'ExpandString', 'Binary', 'MultiString'): print('  tipo', b, a[1], a[3])
            if a[3] == 'DWord' and not str(a[2]).startswith('?') and not re.match(r'^-?\d+$', str(a[2])): print('  DWord non numerico', b, a[1], a[2])
            if a[3] == 'String' and re.match(r'^\d+$', str(a[2])) and "'" not in x['t'].split(a[1])[-1][:12] and '"' not in x['t'].split(a[1])[-1][:12]: pass
