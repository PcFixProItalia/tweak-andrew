# Prova la pulizia su profili di browser finti, in una cartella temporanea:
# deve togliere cronologia, download e cache, e lasciare password, cookie,
# preferiti e segnalibri. Poi controlla la sintassi degli script generati.
# Non tocca i dati veri: le cartelle base dei browser puntano a quella di prova
# e le scritture nel registro sono intercettate.
$root = Split-Path $PSScriptRoot -Parent
$text = [IO.File]::ReadAllText((Join-Path $root 'Tweak_Andrew.ps1'), [Text.Encoding]::UTF8)
$m = [regex]::Match($text, "(?s)\`$script:ToolHelpers = @'\r?\n(.*?)\r?\n'@")
if (-not $m.Success) { Write-Host 'FAIL aiuti non trovati' -ForegroundColor Red; exit 1 }
$helpers = $m.Groups[1].Value

$fail = 0
function Check($name, $cond) { if ($cond) { Write-Host "OK   $name" } else { Write-Host "FAIL $name" -ForegroundColor Red; $script:fail++ } }

$sb = Join-Path $env:TEMP ("ta_clean_" + [guid]::NewGuid().ToString('N').Substring(0, 8))
function Touch($p, [int]$kb = 4) { New-Item -ItemType Directory -Force (Split-Path $p) | Out-Null; [IO.File]::WriteAllBytes($p, (New-Object byte[] ($kb * 1024))) }

# Chrome con due profili, Opera con profilo unico.
foreach ($prof in 'Default', 'Profile 1') {
    $p = "$sb\Local\Google\Chrome\User Data\$prof"
    foreach ($f in 'History', 'History-journal', 'Visited Links', 'Top Sites', 'Shortcuts', 'Login Data', 'Web Data', 'Bookmarks', 'Preferences') { Touch "$p\$f" }
    Touch "$p\Network\Cookies"; Touch "$p\Cache\Cache_Data\f_000001" 64; Touch "$p\Code Cache\js\a" 32; Touch "$p\GPUCache\data_0" 16
}
Touch "$sb\Local\Google\Chrome\User Data\Local State"
Touch "$sb\Roaming\Opera Software\Opera Stable\History"; Touch "$sb\Roaming\Opera Software\Opera Stable\Login Data"

. ([ScriptBlock]::Create($helpers))
$LocalApp = "$sb\Local"; $RoamingApp = "$sb\Roaming"
# Il browser vero potrebbe essere aperto: per la prova risultano tutti chiusi.
function Test-BrowserOpen([string]$proc) { return $false }

# Firefox: database con le tabelle che servono.
$ffp = "$sb\Roaming\Mozilla\Firefox\Profiles\abc.default-release"
New-Item -ItemType Directory -Force $ffp | Out-Null
Touch "$sb\Local\Mozilla\Firefox\Profiles\abc.default-release\cache2\entries\X" 32
$db = Join-Path $ffp 'places.sqlite'
Add-Type -Namespace TaTest -Name Q -MemberDefinition @"
[System.Runtime.InteropServices.DllImport("winsqlite3.dll", EntryPoint = "sqlite3_open_v2")] public static extern int Open(byte[] f, out System.IntPtr db, int flags, System.IntPtr vfs);
[System.Runtime.InteropServices.DllImport("winsqlite3.dll", EntryPoint = "sqlite3_prepare_v2")] public static extern int Prepare(System.IntPtr db, byte[] sql, int n, out System.IntPtr st, System.IntPtr tail);
[System.Runtime.InteropServices.DllImport("winsqlite3.dll", EntryPoint = "sqlite3_step")] public static extern int Step(System.IntPtr st);
[System.Runtime.InteropServices.DllImport("winsqlite3.dll", EntryPoint = "sqlite3_column_int")] public static extern int Col(System.IntPtr st, int i);
[System.Runtime.InteropServices.DllImport("winsqlite3.dll", EntryPoint = "sqlite3_finalize")] public static extern int Fin(System.IntPtr st);
[System.Runtime.InteropServices.DllImport("winsqlite3.dll", EntryPoint = "sqlite3_close")] public static extern int Close(System.IntPtr db);
"@
function Count([string]$sql) {
    $h = [IntPtr]::Zero; $st = [IntPtr]::Zero
    [void][TaTest.Q]::Open([Text.Encoding]::UTF8.GetBytes($db + [char]0), [ref]$h, 1, [IntPtr]::Zero)
    [void][TaTest.Q]::Prepare($h, [Text.Encoding]::UTF8.GetBytes($sql + [char]0), -1, [ref]$st, [IntPtr]::Zero)
    [void][TaTest.Q]::Step($st); $v = [TaTest.Q]::Col($st, 0)
    [void][TaTest.Q]::Fin($st); [void][TaTest.Q]::Close($h); return $v
}
# 6 = SQLITE_OPEN_READWRITE | SQLITE_OPEN_CREATE: si crea il file e lo schema.
$h = [IntPtr]::Zero; $e = [IntPtr]::Zero
# Il tipo SQLite si carica alla prima chiamata: questa apre un file che non esiste ancora e fallisce, va bene.
[void](Invoke-Sqlite $db 'SELECT 1')
[void][TweakAndrewSql.Lite]::Open([Text.Encoding]::UTF8.GetBytes($db + [char]0), [ref]$h, 6, [IntPtr]::Zero)
$schema = "CREATE TABLE moz_places (id INTEGER PRIMARY KEY, url TEXT, visit_count INTEGER DEFAULT 0, last_visit_date INTEGER, frecency INTEGER DEFAULT -1);" +
          "CREATE TABLE moz_historyvisits (id INTEGER PRIMARY KEY, place_id INTEGER);" +
          "CREATE TABLE moz_inputhistory (place_id INTEGER, input TEXT);" +
          "CREATE TABLE moz_anno_attributes (id INTEGER PRIMARY KEY, name TEXT);" +
          "CREATE TABLE moz_annos (id INTEGER PRIMARY KEY, place_id INTEGER, anno_attribute_id INTEGER, content TEXT);" +
          "CREATE TABLE moz_bookmarks (id INTEGER PRIMARY KEY, fk INTEGER, title TEXT);" +
          "INSERT INTO moz_places VALUES (1,'https://a',5,1700000000,100),(2,'https://b',2,1700000001,50);" +
          "INSERT INTO moz_historyvisits (place_id) VALUES (1),(1),(2);" +
          "INSERT INTO moz_inputhistory VALUES (1,'a');" +
          "INSERT INTO moz_anno_attributes VALUES (1,'downloads/destinationFileURI'),(2,'bookmarkProperties/description');" +
          "INSERT INTO moz_annos (place_id, anno_attribute_id, content) VALUES (2,1,'file:///x'),(1,2,'nota');" +
          "INSERT INTO moz_bookmarks (fk, title) VALUES (1,'segnalibro');"
[void][TweakAndrewSql.Lite]::Exec($h, [Text.Encoding]::UTF8.GetBytes($schema + [char]0), [IntPtr]::Zero, [IntPtr]::Zero, [ref]$e)
[void][TweakAndrewSql.Lite]::Close($h)
Check 'database di prova creato' ((Count 'SELECT count(*) FROM moz_historyvisits') -eq 3)

$sizeBefore = Get-BrowserSize; $cacheBefore = Get-BrowserSize -Cache
Check 'spazio della cronologia misurato' ($sizeBefore -gt 0)
Check 'spazio della cache misurato' ($cacheBefore -ge 200KB)

$script:BrowserOpen = @()
$freed = Clear-BrowserHistory
$p = "$sb\Local\Google\Chrome\User Data\Default"
Check 'Chrome: cronologia tolta' (-not (Test-Path "$p\History") -and -not (Test-Path "$p\History-journal") -and -not (Test-Path "$p\Visited Links"))
Check 'Chrome: secondo profilo pulito' (-not (Test-Path "$sb\Local\Google\Chrome\User Data\Profile 1\History"))
Check 'Chrome: password, cookie, preferiti restano' ((Test-Path "$p\Login Data") -and (Test-Path "$p\Network\Cookies") -and (Test-Path "$p\Bookmarks") -and (Test-Path "$p\Web Data"))
Check 'Opera: cronologia tolta, password resta' (-not (Test-Path "$sb\Roaming\Opera Software\Opera Stable\History") -and (Test-Path "$sb\Roaming\Opera Software\Opera Stable\Login Data"))
Check 'Firefox: visite tolte' ((Count 'SELECT count(*) FROM moz_historyvisits') -eq 0)
Check 'Firefox: indirizzi digitati tolti' ((Count 'SELECT count(*) FROM moz_inputhistory') -eq 0)
Check 'Firefox: elenco download tolto' ((Count 'SELECT count(*) FROM moz_annos WHERE anno_attribute_id = 1') -eq 0)
Check 'Firefox: note dei segnalibri restano' ((Count 'SELECT count(*) FROM moz_annos WHERE anno_attribute_id = 2') -eq 1)
Check 'Firefox: segnalibri restano' ((Count 'SELECT count(*) FROM moz_bookmarks') -eq 1)
Check 'Firefox: pagine azzerate senza cancellarle' ((Count 'SELECT count(*) FROM moz_places') -eq 2 -and (Count 'SELECT sum(visit_count) FROM moz_places') -eq 0)
Check 'spazio liberato riportato' ($freed -gt 0)

$freed = Clear-BrowserCache
Check 'cache Chromium svuotata' (-not (Test-Path "$p\Cache\Cache_Data\f_000001") -and -not (Test-Path "$p\GPUCache\data_0"))
Check 'cartella cache tenuta' (Test-Path "$p\Cache")
Check 'cache Firefox svuotata' (-not (Test-Path "$sb\Local\Mozilla\Firefox\Profiles\abc.default-release\cache2\entries\X"))
Check 'cache: liberato almeno 200 KB' ($freed -ge 200KB)

# Browser aperto: si salta e lo si dice.
Touch "$p\History"
function Test-BrowserOpen([string]$proc) { return ($proc -eq 'chrome') }
$script:BrowserOpen = @()
[void](Clear-BrowserHistory)
Check 'browser aperto: saltato' ((Test-Path "$p\History") -and ($script:BrowserOpen -contains 'Chrome'))

# Elementi recenti: le cartelle fissate restano, il registro non si tocca davvero.
$script:RegCalls = @()
function Remove-ItemProperty { $script:RegCalls += ,@($args) }
$r = "$sb\Roaming\Microsoft\Windows\Recent"
Touch "$r\file.lnk" 1; Touch "$r\AutomaticDestinations\$QuickAccessPins" 2; Touch "$r\AutomaticDestinations\aaaa.automaticDestinations-ms" 2; Touch "$r\CustomDestinations\b.customDestinations-ms" 2
[void](Clear-Recent)
Check 'recenti: collegamenti tolti' (-not (Test-Path "$r\file.lnk") -and -not (Test-Path "$r\AutomaticDestinations\aaaa.automaticDestinations-ms"))
Check 'recenti: cartelle fissate in Accesso rapido restano' (Test-Path "$r\AutomaticDestinations\$QuickAccessPins")
Check 'recenti: chiamate al registro per Esegui e percorsi' ($script:RegCalls.Count -eq 2)

Remove-Item -LiteralPath $sb -Recurse -Force -ErrorAction SilentlyContinue
Check 'cartella di prova rimossa' (-not (Test-Path $sb))
"FALLITI: $fail"
