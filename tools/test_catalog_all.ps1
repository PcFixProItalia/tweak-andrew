# Prova ogni voce del catalogo con i suoi dati veri, ma su una copia delle
# chiavi sotto HKCU\Software\TweakAndrewTest: il sistema non viene toccato.
# Interruttori: acceso -> letto acceso, spento -> letto spento.
# Menu: ogni opzione scritta si rilegge uguale.
# Servizi, attivita' e piano energetico: solo lettura dello stato reale.
$root = Split-Path $PSScriptRoot -Parent
function E($n) { $null }
function Get-Text($e) { if ($e) { $e['it'] } }
function T($k) { $k }
$script:Log = @()
function Write-Log($m) { $script:Log += $m }
$script:Catalog = @(); $script:CatText = @{}; $script:CatTip = @{}
. ([ScriptBlock]::Create([IO.File]::ReadAllText("$root\src\partK.ps1")))
. ([ScriptBlock]::Create([IO.File]::ReadAllText("$root\src\partK_data.ps1")))

$base = 'HKCU\Software\TweakAndrewTest'
$fail = 0; $done = 0
function Bad($m) { Write-Host "FAIL $m" -ForegroundColor Red; $script:fail++ }
function Map([string]$p) { "$base\" + ($p -replace '^(HK\w+)\\', '$1_\') }

function Seed($ops) {
    foreach ($o in $ops) {
        if ($o[2] -match '^(Bit|Byte)') {
            $k = 'Registry::' + ($o[0] -replace '^HKCU', 'HKEY_CURRENT_USER')
            if (-not (Test-Path -LiteralPath $k)) { New-Item -Path $k -Force | Out-Null }
            if ($null -eq (Get-ItemProperty -LiteralPath $k -Name $o[1] -ErrorAction SilentlyContinue)) {
                New-ItemProperty -LiteralPath $k -Name $o[1] -PropertyType Binary -Value ([byte[]](,0 * 16)) -Force | Out-Null
            }
        }
    }
}

foreach ($it in $script:Catalog) {
    $kind = [string]$it.Kind
    if ($kind -in 'T', 'S') {
        $copy = @{}; foreach ($k in $it.Keys) { $copy[$k] = $it[$k] }
        $copy.Flags = ''
        $copy.Ops = @($it.Ops | ForEach-Object { $o = @($_); $o[0] = Map $o[0]; , $o })
        Seed $copy.Ops
        $script:Log = @()
        try {
            if ($kind -eq 'T') {
                [void](Set-CatState $copy $true);  if ((Get-CatState $copy) -ne $true) { Bad "$($it.Id) acceso non si rilegge acceso" }
                [void](Set-CatState $copy $false); if ((Get-CatState $copy) -ne $false) { Bad "$($it.Id) spento non si rilegge spento" }
                [void](Set-CatState $copy $true);  if ((Get-CatState $copy) -ne $true) { Bad "$($it.Id) riacceso non si rilegge acceso" }
            } else {
                foreach ($opt in $it.Opts) {
                    [void](Set-CatState $copy $opt.Key)
                    $got = Get-CatState $copy
                    if ([string]$got -ne [string]$opt.Key) { Bad "$($it.Id) opzione $($opt.Key) si rilegge '$got'" }
                }
                if (@($it.Opts | Where-Object { [string]$_.Key -eq [string]$it.Def }).Count -eq 0) { Bad "$($it.Id) predefinito '$($it.Def)' non e' tra le opzioni" }
                if ($it.Rec -ne '-' -and @($it.Opts | Where-Object { [string]$_.Key -eq [string]$it.Rec }).Count -eq 0) { Bad "$($it.Id) consigliato '$($it.Rec)' non e' tra le opzioni" }
            }
        } catch { Bad "$($it.Id) eccezione: $($_.Exception.Message)" }
        $errs = @($script:Log | Where-Object { $_ -like '*ERRORE*' })
        if ($errs) { Bad "$($it.Id) registro: $($errs[0])" }
        $done++
    } else {
        try {
            $s = Get-CatState $it
            if ($kind -eq 'N') {
                if ($null -eq $s) { Write-Host "INFO $($it.Id): impostazione assente o valore fuori elenco su questo PC" }
                if (@($it.Opts | Where-Object { [string]$_.Key -eq [string]$it.Def }).Count -eq 0 -and $it.Opts.Count) { Bad "$($it.Id) predefinito '$($it.Def)' non e' tra le opzioni" }
                foreach ($rp in ([string]$it.Rec -split '/')) { if ($rp -ne '-' -and $it.Opts.Count -and @($it.Opts | Where-Object { [string]$_.Key -eq $rp }).Count -eq 0) { Bad "$($it.Id) consigliato '$rp' non e' tra le opzioni" } }
            }
            if ($kind -eq 'V') {
                $miss = @($it.Svcs | Where-Object { -not (Get-Service -Name $_ -ErrorAction SilentlyContinue) })
                if ($miss.Count -eq $it.Svcs.Count) { Write-Host "INFO $($it.Id): servizi assenti su questo PC ($($miss -join ', '))" }
            }
            if ($kind -eq 'J') {
                $found = 0
                foreach ($t in $it.Tasks) {
                    $p = Split-Path $t -Parent; if (-not $p.EndsWith('\')) { $p += '\' }
                    if (Get-ScheduledTask -TaskPath $p -TaskName (Split-Path $t -Leaf) -ErrorAction SilentlyContinue) { $found++ }
                }
                if ($found -eq 0) { Write-Host "INFO $($it.Id): attivita' assenti su questo PC" }
            }
        } catch { Bad "$($it.Id) lettura: $($_.Exception.Message)" }
        $done++
    }
    foreach ($f in 'Def', 'Rec') {
        if ($kind -eq 'T' -and $it.Page -ne 'priv' -and [string]$it[$f] -notin '0', '1', '-') { Bad "$($it.Id) $f non valido: $($it[$f])" }
    }
    if (-not $script:CatText[$it.Id]) { Bad "$($it.Id) senza titolo" }
    if (-not $script:CatTip[$it.Id]) { Bad "$($it.Id) senza descrizione" }
}
Remove-Item -Path 'HKCU:\Software\TweakAndrewTest' -Recurse -Force -ErrorAction SilentlyContinue
"Voci provate: $done   FALLITI: $fail"
