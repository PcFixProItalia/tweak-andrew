# ------------------------------------------------------------------------------
# 31. OPERAZIONI IN CORSO, BLOCCO DELLE PAGINE, STRUMENTI E STATO ATTUALE
# ------------------------------------------------------------------------------

# --- indicatore delle operazioni, visibile da qualsiasi pagina ---
$pillActivity = E 'pillActivity'; $txtActivity = E 'txtActivity'; $txtActivityPct = E 'txtActivityPct'
$prgActivity = E 'prgActivity'; $dotActivity = E 'dotActivity'
$script:Activities = [ordered]@{}

function Update-ActivityPill {
    if ($script:Activities.Count -eq 0) { $pillActivity.Visibility = 'Collapsed'; return }
    $all = @($script:Activities.Values)
    $a = $all[$all.Count - 1]
    $pillActivity.Visibility = 'Visible'
    $txtActivity.Text = if ($all.Count -gt 1) { "$($a.Text)   (+$($all.Count - 1))" } else { $a.Text }
    if ($a.Pct -ge 0) {
        $prgActivity.Visibility = 'Visible'; $prgActivity.Value = [Math]::Min(100, $a.Pct)
        $txtActivityPct.Text = "$([int]$a.Pct)%"
    } else {
        $prgActivity.Visibility = 'Collapsed'; $txtActivityPct.Text = ''
    }
}

# Chiave, testo, percentuale (-1 se non c'e' una stima) e voce del menu da aprire con un clic.
function Set-Activity([string]$Key, [string]$Text, [double]$Pct = -1, [string]$Nav = '') {
    if ($script:Activities.Contains($Key)) {
        if (-not $Nav) { $Nav = $script:Activities[$Key].Nav }
        $script:Activities.Remove($Key)
    }
    if (-not $Nav) {
        foreach ($e in $script:NavPages) { if ($e.Nav.IsChecked -eq $true) { $Nav = [string]$e.Nav.Name } }
    }
    $script:Activities[$Key] = @{ Text = $Text; Pct = $Pct; Nav = $Nav }
    Update-ActivityPill
}

function Clear-Activity([string]$Key) {
    if ($script:Activities.Contains($Key)) { $script:Activities.Remove($Key) }
    Update-ActivityPill
}

$pillActivity.Add_MouseLeftButtonUp({
    $all = @($script:Activities.Values)
    if ($all.Count -eq 0) { return }
    $nav = $all[$all.Count - 1].Nav
    if ($nav) { $el = E $nav; if ($el) { $el.IsChecked = $true } }
})

# Il pallino respira mentre qualcosa lavora.
$an = New-Object System.Windows.Media.Animation.DoubleAnimation(1, 0.25, [TimeSpan]::FromSeconds(0.8))
$an.AutoReverse = $true; $an.RepeatBehavior = [System.Windows.Media.Animation.RepeatBehavior]::Forever
$dotActivity.BeginAnimation([System.Windows.UIElement]::OpacityProperty, $an)

# --- blocco delle pagine durante le operazioni ---
# Mentre si applicano le modifiche o gira uno strumento di sistema le pagine delle
# impostazioni si ingrigiscono e non accettano clic: niente interruttori cambiati
# a meta'. Restano libere la Home e le App, che non toccano le stesse cose.
$svTools = E 'svTools'
$script:UiLocks = New-Object 'System.Collections.Generic.HashSet[string]'

function Set-UiLock([string]$Key, [bool]$On) {
    if ($On) { [void]$script:UiLocks.Add($Key) } else { [void]$script:UiLocks.Remove($Key) }
    $lock = $script:UiLocks.Count -gt 0
    $targets = @($script:NavPages | Where-Object { -not ($_.Home -or $_.Apps -or $_.Tools) } | ForEach-Object { $_.Page }) + @($svTools)
    foreach ($el in $targets) {
        if ($null -eq $el) { continue }
        $el.IsEnabled = -not $lock
        $el.Opacity = if ($lock) { 0.5 } else { 1 }
    }
    foreach ($n in @('barQueue', 'btnDetectActive', 'btnEmergency', 'chkRestorePoint')) {
        $el = $window.FindName($n)
        if ($el) { $el.IsEnabled = -not $lock }
    }
}

# ------------------------------------------------------------------------------
# Esecuzione degli strumenti: uno alla volta, in una console virtuale per poter
# leggere la percentuale che scrivono DISM, SFC e gli script del programma.
# Gli script comunicano con righe «@@PCT n» e «@@STEP testo».
# ------------------------------------------------------------------------------
$bdToolJobs = E 'bdToolJobs'; $panToolJobs = E 'panToolJobs'; $prgToolJobs = E 'prgToolJobs'
$txtToolJobsCount = E 'txtToolJobsCount'; $btnToolJobsClose = E 'btnToolJobsClose'; $panTools = E 'panTools'
$script:ToolJobs = New-Object System.Collections.Queue
$script:ToolJobList = New-Object System.Collections.ArrayList
$script:ToolJob = $null

function Test-ToolBusy { return ($null -ne $script:ToolJob) -or ($script:ToolJobs.Count -gt 0) }

function Add-ToolJob([string]$Name, [string]$Script, [switch]$Reboot) {
    if (-not (Test-ToolBusy)) { $script:ToolJobList.Clear(); $panToolJobs.Children.Clear() }
    $job = @{ Name = $Name; Label = $Name; Script = $Script; Reboot = [bool]$Reboot; Proc = $null; Done = $false; Ok = $false; Frac = 0.0 }
    New-AppJobRow $job $panToolJobs
    Set-AppJobView $job (T 'jobWait') 0 '#FF6C727A'
    [void]$script:ToolJobList.Add($job)
    $script:ToolJobs.Enqueue($job)
    $bdToolJobs.Visibility = 'Visible'; $btnToolJobsClose.Visibility = 'Collapsed'
    Set-UiLock 'tools' $true
    $script:ToolTimer.Start()
}

function Start-ToolJob($job) {
    $script:ToolJob = $job
    $body = "`$ProgressPreference = 'SilentlyContinue'`r`n" + $job.Script
    $enc = [Convert]::ToBase64String([Text.Encoding]::Unicode.GetBytes($body))
    $cmd = "powershell.exe -NoProfile -ExecutionPolicy Bypass -EncodedCommand $enc"
    try { $job.Proc = [TweakAndrew.PtyProcess]::Start($cmd) }
    catch {
        try { $job.Proc = Start-AppHidden 'powershell.exe' "-NoProfile -ExecutionPolicy Bypass -EncodedCommand $enc" }
        catch { Write-Log "[ERRORE] $($job.Name) - $($_.Exception.Message)"; Complete-ToolJob $job -1; return }
    }
    Write-Log "[INFO] Avvio: $($job.Name)"
    Set-AppJobView $job (T 'jobPrep') -1 '#FFC5C9CF'
}

function Update-ToolJobProgress($job) {
    if ($job.Proc.GetType().Name -ne 'PtyProcess') { return }
    $raw = $job.Proc.Text
    if ($raw.Length -gt 8000) { $raw = $raw.Substring($raw.Length - 8000) }
    $clean = $raw -replace "\x1b\][^\x07\x1b]*(\x07|\x1b\\)?", '' -replace "\x1b\[[0-9;?]*[ -/]*[@-~]", ''
    $step = [regex]::Matches($clean, '@@STEP ([^\r\n]+)')
    $text = if ($step.Count -gt 0) { $step[$step.Count - 1].Groups[1].Value.Trim() } else { T 'jobWorking' }
    $job.Step = $text
    $after = if ($step.Count -gt 0) { $clean.Substring($step[$step.Count - 1].Index) } else { $clean }
    $own = [regex]::Matches($after, '@@PCT (\d+)')
    $any = [regex]::Matches($after, '(\d{1,3})(?:[.,]\d+)?\s?%')
    $pct = -1
    if ($own.Count -gt 0) { $pct = [int]$own[$own.Count - 1].Groups[1].Value }
    elseif ($any.Count -gt 0) { $pct = [Math]::Min(100, [int]$any[$any.Count - 1].Groups[1].Value) }
    if ($pct -ge 0) { Set-AppJobView $job "$text  ·  $pct%" $pct '#FFE6E8EB'; $job.Frac = $pct / 100 }
    else { Set-AppJobView $job $text -1 '#FFE6E8EB'; $job.Frac = 0.05 }
}

function Complete-ToolJob($job, [int]$code) {
    $job.Done = $true; $job.Frac = 1.0
    $msg = ''
    if ($job.Proc -and $job.Proc.GetType().Name -eq 'PtyProcess') {
        $m = [regex]::Matches(($job.Proc.Text -replace "\x1b\[[0-9;?]*[ -/]*[@-~]", ''), '@@DONE ([^\r\n]+)')
        if ($m.Count -gt 0) { $msg = $m[$m.Count - 1].Groups[1].Value.Trim() }
    }
    if ($code -eq 0 -or $code -eq 3010) {
        $job.Ok = $true
        $txt = if ($msg) { $msg } elseif ($job.Reboot -or $code -eq 3010) { T 'jobOkReboot' } else { T 'jobOk' }
        Write-Log "[OK] $($job.Name) $msg"
        Set-AppJobView $job $txt 100 $(if ($job.Reboot -or $code -eq 3010) { '#FFFDBA74' } else { '#FF3DBE8B' })
    } else {
        Write-Log "[ERRORE] $($job.Name) - codice $code $msg"
        Set-AppJobView $job ($(if ($msg) { $msg } else { (T 'jobErr') -f $code })) 0 '#FFF87171'
    }
    if ($script:ToolJob -eq $job) { $script:ToolJob = $null }
}

$script:ToolTimer = New-Object System.Windows.Threading.DispatcherTimer
$script:ToolTimer.Interval = [TimeSpan]::FromMilliseconds(300)
$script:ToolTimer.Add_Tick({
    $job = $script:ToolJob
    if ($null -ne $job) {
        if ($job.Proc.HasExited) { Complete-ToolJob $job $job.Proc.ExitCode } else { Update-ToolJobProgress $job }
    }
    if ($null -eq $script:ToolJob -and $script:ToolJobs.Count -gt 0) { Start-ToolJob ($script:ToolJobs.Dequeue()) }
    $total = $script:ToolJobList.Count
    if ($total -gt 0) {
        $done = @($script:ToolJobList | Where-Object { $_.Done }).Count
        $sum = 0.0; foreach ($j in $script:ToolJobList) { $sum += $j.Frac }
        $prgToolJobs.Value = $sum / $total
        $txtToolJobsCount.Text = (T 'jobsProgress') -f $done, $total
        if ($script:ToolJob) {
            $st = if ($script:ToolJob.Step) { $script:ToolJob.Step } else { T 'jobPrep' }
            Set-Activity 'tools' ("$($script:ToolJob.Name) · $st") ([Math]::Round(100 * $sum / $total)) 'tabTools'
        }
    }
    if (Test-ToolBusy) { return }
    $script:ToolTimer.Stop()
    Clear-Activity 'tools'
    Set-UiLock 'tools' $false
    $btnToolJobsClose.Visibility = 'Visible'
    if ($script:ToolsNeedRefresh) { $script:ToolsNeedRefresh = $false; Start-ToolScan }
    if ($script:GhostRescan) { $script:GhostRescan = $false; Start-GhostScan }
    if ($script:DebloatRescan) { $script:DebloatRescan = $false; Start-DebloatScan }
})

$btnToolJobsClose.Add_Click({
    if (Test-ToolBusy) { return }
    $script:ToolJobList.Clear(); $panToolJobs.Children.Clear(); $bdToolJobs.Visibility = 'Collapsed'
})

# ------------------------------------------------------------------------------
# Script degli strumenti
# ------------------------------------------------------------------------------
# Pulizia totale: ogni voce ha le cartelle da svuotare e, se serve, un'azione a parte.
# Dal vecchio file .bat restano fuori: Prefetch (Windows lo ricrea subito e
# intanto programmi e avvio partono piu' lenti), i file .bak di tutto il disco C
# (sono copie di sicurezza di programmi e utenti) e la ricreazione delle
# cartelle Temp, che perdeva i loro permessi.
$script:CleanItems = @(
    @{ Key = 'winTemp';      On = $true;  Paths = @('%SystemRoot%\Temp') }
    @{ Key = 'userTemp';     On = $true;  Paths = @('%TEMP%') }
    @{ Key = 'wuCache';      On = $true;  Paths = @('%SystemRoot%\SoftwareDistribution\Download') }
    @{ Key = 'doCache';      On = $true;  Paths = @('%SystemRoot%\ServiceProfiles\NetworkService\AppData\Local\Microsoft\Windows\DeliveryOptimization\Cache') }
    @{ Key = 'recycle';      On = $true;  Paths = @() }
    @{ Key = 'errors';       On = $true;  Paths = @('%ProgramData%\Microsoft\Windows\WER\ReportArchive', '%ProgramData%\Microsoft\Windows\WER\ReportQueue', '%LOCALAPPDATA%\CrashDumps', '%SystemRoot%\Minidump') }
    @{ Key = 'browserHist';  On = $true;  Paths = @() }
    @{ Key = 'browserCache'; On = $true;  Paths = @() }
    @{ Key = 'recent';       On = $false; Paths = @() }
    @{ Key = 'thumbs';       On = $false; Paths = @() }
)

# Funzioni comuni agli script: girano in un processo a parte, quindi niente T.
$script:ToolHelpers = @'
function Clear-Dir([string]$p) {
    $p = [Environment]::ExpandEnvironmentVariables($p)
    if (-not (Test-Path -LiteralPath $p)) { return 0 }
    $size = 0
    foreach ($f in @(Get-ChildItem -LiteralPath $p -Force -Recurse -File -ErrorAction SilentlyContinue)) {
        try { $len = $f.Length; Remove-Item -LiteralPath $f.FullName -Force -ErrorAction Stop; $size += $len } catch {}
    }
    Get-ChildItem -LiteralPath $p -Force -Directory -ErrorAction SilentlyContinue | ForEach-Object {
        Remove-Item -LiteralPath $_.FullName -Recurse -Force -ErrorAction SilentlyContinue
    }
    return $size
}
function Size-Text([double]$b) { if ($b -ge 1GB) { '{0:0.0} GB' -f ($b / 1GB) } else { '{0:0} MB' -f ($b / 1MB) } }
function Get-PathSize([string]$p) {
    $p = [Environment]::ExpandEnvironmentVariables($p)
    if (-not (Test-Path -LiteralPath $p)) { return 0 }
    $item = Get-Item -LiteralPath $p -Force -ErrorAction SilentlyContinue
    if ($item -and -not $item.PSIsContainer) { return [double]$item.Length }
    return [double](Get-ChildItem -LiteralPath $p -Force -Recurse -File -ErrorAction SilentlyContinue | Measure-Object Length -Sum).Sum
}

# Browser basati su Chromium: la cronologia e l'elenco dei download stanno nel
# file History del profilo. Cookie (Network\Cookies), password (Login Data) e
# accessi stanno in altri file e non si toccano.
# Cartelle base dei profili: variabili, cosi' la prova le punta su una cartella finta.
$LocalApp = $env:LOCALAPPDATA
$RoamingApp = $env:APPDATA
$Browsers = @(
    @{ Name = 'Chrome';   Proc = 'chrome';  Base = 'L'; Root = 'Google\Chrome\User Data';            Multi = $true }
    @{ Name = 'Edge';     Proc = 'msedge';  Base = 'L'; Root = 'Microsoft\Edge\User Data';           Multi = $true }
    @{ Name = 'Brave';    Proc = 'brave';   Base = 'L'; Root = 'BraveSoftware\Brave-Browser\User Data'; Multi = $true }
    @{ Name = 'Vivaldi';  Proc = 'vivaldi'; Base = 'L'; Root = 'Vivaldi\User Data';                  Multi = $true }
    @{ Name = 'Opera';    Proc = 'opera';   Base = 'R'; Root = 'Opera Software\Opera Stable';         Multi = $false }
    @{ Name = 'Opera GX'; Proc = 'opera';   Base = 'R'; Root = 'Opera Software\Opera GX Stable';      Multi = $false }
)
$HistoryFiles = @('History', 'History-journal', 'Visited Links', 'Top Sites', 'Top Sites-journal', 'Shortcuts', 'Shortcuts-journal')
$CacheDirs = @('Cache', 'Code Cache', 'GPUCache')

function Get-BrowserProfiles($b) {
    $root = Join-Path $(if ($b.Base -eq 'L') { $LocalApp } else { $RoamingApp }) $b.Root
    if (-not (Test-Path -LiteralPath $root)) { return @() }
    if (-not $b.Multi) { return @($root) }
    return @(Get-ChildItem -LiteralPath $root -Directory -ErrorAction SilentlyContinue |
             Where-Object { $_.Name -eq 'Default' -or $_.Name -like 'Profile *' } | ForEach-Object { $_.FullName })
}
function Get-FirefoxProfiles([switch]$Local) {
    $base = if ($Local) { "$LocalApp\Mozilla\Firefox\Profiles" } else { "$RoamingApp\Mozilla\Firefox\Profiles" }
    if (-not (Test-Path -LiteralPath $base)) { return @() }
    return @(Get-ChildItem -LiteralPath $base -Directory -ErrorAction SilentlyContinue | ForEach-Object { $_.FullName })
}
function Test-BrowserOpen([string]$proc) { return [bool](Get-Process -Name $proc -ErrorAction SilentlyContinue) }

# SQLite di Windows (winsqlite3.dll, presente da Windows 10): serve per Firefox,
# che tiene cronologia e segnalibri nello stesso file.
function Invoke-Sqlite([string]$db, [string]$sql) {
    if (-not ('TweakAndrewSql.Lite' -as [type])) {
        Add-Type -Namespace TweakAndrewSql -Name Lite -MemberDefinition @"
[System.Runtime.InteropServices.DllImport("winsqlite3.dll", EntryPoint = "sqlite3_open_v2")] public static extern int Open(byte[] file, out System.IntPtr db, int flags, System.IntPtr vfs);
[System.Runtime.InteropServices.DllImport("winsqlite3.dll", EntryPoint = "sqlite3_exec")] public static extern int Exec(System.IntPtr db, byte[] sql, System.IntPtr cb, System.IntPtr arg, out System.IntPtr err);
[System.Runtime.InteropServices.DllImport("winsqlite3.dll", EntryPoint = "sqlite3_busy_timeout")] public static extern int Busy(System.IntPtr db, int ms);
[System.Runtime.InteropServices.DllImport("winsqlite3.dll", EntryPoint = "sqlite3_close")] public static extern int Close(System.IntPtr db);
"@
    }
    $h = [IntPtr]::Zero; $e = [IntPtr]::Zero
    $r = [TweakAndrewSql.Lite]::Open([Text.Encoding]::UTF8.GetBytes($db + [char]0), [ref]$h, 2, [IntPtr]::Zero)
    if ($r -ne 0) { if ($h -ne [IntPtr]::Zero) { [void][TweakAndrewSql.Lite]::Close($h) }; return $r }
    [void][TweakAndrewSql.Lite]::Busy($h, 2000)
    $r = [TweakAndrewSql.Lite]::Exec($h, [Text.Encoding]::UTF8.GetBytes($sql + [char]0), [IntPtr]::Zero, [IntPtr]::Zero, [ref]$e)
    [void][TweakAndrewSql.Lite]::Close($h)
    return $r
}
# Firefox: si cancellano le visite, gli indirizzi digitati e l'elenco dei
# download; le pagine restano solo come voci senza visite, cosi' i segnalibri
# (che puntano a quelle righe) non si toccano. Tutto in una transazione: se
# qualcosa va storto non cambia nulla.
$FirefoxSql = "BEGIN; DELETE FROM moz_historyvisits; DELETE FROM moz_inputhistory; " +
              "DELETE FROM moz_annos WHERE anno_attribute_id IN (SELECT id FROM moz_anno_attributes WHERE name LIKE 'downloads/%'); " +
              "UPDATE moz_places SET visit_count = 0, last_visit_date = NULL, frecency = 0; COMMIT;"

# Cronologia dei browser. Restituisce lo spazio liberato; i browser aperti si
# saltano e finiscono nell'elenco $script:BrowserOpen.
function Clear-BrowserHistory {
    $freed = 0
    foreach ($b in $Browsers) {
        $profiles = @(Get-BrowserProfiles $b)
        if ($profiles.Count -eq 0) { continue }
        if (Test-BrowserOpen $b.Proc) { $script:BrowserOpen += $b.Name; continue }
        foreach ($p in $profiles) {
            foreach ($f in $HistoryFiles) {
                $x = Join-Path $p $f
                if (Test-Path -LiteralPath $x) { try { $len = (Get-Item -LiteralPath $x -Force).Length; Remove-Item -LiteralPath $x -Force -ErrorAction Stop; $freed += $len } catch {} }
            }
        }
    }
    $ff = @(Get-FirefoxProfiles | Where-Object { Test-Path -LiteralPath (Join-Path $_ 'places.sqlite') })
    if ($ff.Count -gt 0) {
        if (Test-BrowserOpen 'firefox') { $script:BrowserOpen += 'Firefox' }
        elseif (-not (Test-Path "$env:SystemRoot\System32\winsqlite3.dll")) { Write-Host 'ATTENZIONE: SQLite di Windows assente, cronologia di Firefox non pulita.' }
        else {
            foreach ($p in $ff) {
                $r = Invoke-Sqlite (Join-Path $p 'places.sqlite') $FirefoxSql
                if ($r -ne 0) { Write-Host "ATTENZIONE: cronologia di Firefox non pulita (codice SQLite $r)." }
            }
        }
    }
    return $freed
}
function Clear-BrowserCache {
    $freed = 0
    foreach ($b in $Browsers) {
        $profiles = @(Get-BrowserProfiles $b)
        if ($profiles.Count -eq 0) { continue }
        if (Test-BrowserOpen $b.Proc) { if ($script:BrowserOpen -notcontains $b.Name) { $script:BrowserOpen += $b.Name }; continue }
        foreach ($p in $profiles) { foreach ($d in $CacheDirs) { $freed += Clear-Dir (Join-Path $p $d) } }
    }
    $ff = @(Get-FirefoxProfiles -Local)
    if ($ff.Count -gt 0) {
        if (Test-BrowserOpen 'firefox') { if ($script:BrowserOpen -notcontains 'Firefox') { $script:BrowserOpen += 'Firefox' } }
        else { foreach ($p in $ff) { $freed += Clear-Dir (Join-Path $p 'cache2') } }
    }
    return $freed
}
function Get-BrowserSize([switch]$Cache) {
    $sum = 0
    foreach ($b in $Browsers) {
        foreach ($p in @(Get-BrowserProfiles $b)) {
            if ($Cache) { foreach ($d in $CacheDirs) { $sum += Get-PathSize (Join-Path $p $d) } }
            else { foreach ($f in $HistoryFiles) { $sum += Get-PathSize (Join-Path $p $f) } }
        }
    }
    if ($Cache) { foreach ($p in @(Get-FirefoxProfiles -Local)) { $sum += Get-PathSize (Join-Path $p 'cache2') } }
    return $sum
}

# Elementi recenti ed elenchi di salto. Resta il file delle cartelle fissate in
# Accesso rapido: cancellarlo toglieva anche quelle.
$QuickAccessPins = 'f01b4d95cf55d32a.automaticDestinations-ms'
function Clear-Recent {
    $freed = 0
    $r = "$RoamingApp\Microsoft\Windows\Recent"
    foreach ($f in @(Get-ChildItem -LiteralPath $r -Force -Recurse -File -ErrorAction SilentlyContinue | Where-Object { $_.Name -ne $QuickAccessPins })) {
        try { $len = $f.Length; Remove-Item -LiteralPath $f.FullName -Force -ErrorAction Stop; $freed += $len } catch {}
    }
    Remove-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\RunMRU' -Name * -ErrorAction SilentlyContinue
    Remove-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\TypedPaths' -Name * -ErrorAction SilentlyContinue
    return $freed
}
'@

function Get-CleanScript([string[]]$Keys) {
    $sb = New-Object System.Text.StringBuilder
    [void]$sb.AppendLine($script:ToolHelpers)
    [void]$sb.AppendLine('$freed = 0; $script:BrowserOpen = @()')
    $i = 0
    foreach ($k in $Keys) {
        $item = $script:CleanItems | Where-Object { $_.Key -eq $k }
        $i++
        [void]$sb.AppendLine("Write-Host '@@STEP $((T "clean_$k") -replace "'", "''")'")
        [void]$sb.AppendLine("Write-Host '@@PCT $([int](100 * ($i - 1) / $Keys.Count))'")
        switch ($k) {
            'wuCache' {
                [void]$sb.AppendLine("Stop-Service wuauserv, bits -Force -ErrorAction SilentlyContinue")
                [void]$sb.AppendLine("`$freed += Clear-Dir '%SystemRoot%\SoftwareDistribution\Download'")
                [void]$sb.AppendLine("Start-Service bits, wuauserv -ErrorAction SilentlyContinue")
            }
            'doCache' {
                [void]$sb.AppendLine("try { Delete-DeliveryOptimizationCache -Force -ErrorAction Stop } catch { `$freed += Clear-Dir '$($item.Paths[0])' }")
            }
            'recycle' {
                [void]$sb.AppendLine("foreach (`$d in [IO.DriveInfo]::GetDrives() | Where-Object { `$_.DriveType -eq 'Fixed' -and `$_.IsReady }) { `$freed += Get-PathSize (Join-Path `$d.RootDirectory '`$Recycle.Bin') }")
                [void]$sb.AppendLine("Clear-RecycleBin -Force -ErrorAction SilentlyContinue")
            }
            'thumbs' {
                [void]$sb.AppendLine("Get-ChildItem `"`$env:LOCALAPPDATA\Microsoft\Windows\Explorer`" -Filter 'thumbcache_*.db' -Force -ErrorAction SilentlyContinue | ForEach-Object { try { `$l = `$_.Length; Remove-Item -LiteralPath `$_.FullName -Force -ErrorAction Stop; `$freed += `$l } catch {} }")
            }
            'browserHist'  { [void]$sb.AppendLine('$freed += Clear-BrowserHistory') }
            'browserCache' { [void]$sb.AppendLine('$freed += Clear-BrowserCache') }
            'recent'       { [void]$sb.AppendLine('$freed += Clear-Recent') }
            default {
                foreach ($p in $item.Paths) { [void]$sb.AppendLine("`$freed += Clear-Dir '$p'") }
            }
        }
    }
    [void]$sb.AppendLine("Write-Host '@@PCT 100'")
    [void]$sb.AppendLine("`$msg = '$((T 'cleanFreed') -replace "'", "''")' -f (Size-Text `$freed)")
    [void]$sb.AppendLine("if (`$script:BrowserOpen.Count -gt 0) { `$msg += ' ' + ('$((T 'cleanBrowserOpen') -replace "'", "''")' -f ((`$script:BrowserOpen | Select-Object -Unique) -join ', ')) }")
    [void]$sb.AppendLine("Write-Host ('@@DONE ' + `$msg)")
    return $sb.ToString()
}

$script:ToolScripts = @{
    netQuick = @'
Write-Host '@@STEP DNS'; ipconfig /flushdns | Out-Null
Write-Host '@@STEP DHCP'; ipconfig /release | Out-Null; ipconfig /renew | Out-Null
Write-Host '@@PCT 100'
'@
    # Il vecchio script disattivava l'autotuning TCP: rallenta le connessioni
    # veloci. Qui torna al valore di Windows («normal»), insieme a RSS attivo.
    netFull = @'
Write-Host '@@STEP TCP'
netsh int tcp set heuristics disabled | Out-Null
netsh int tcp set global autotuninglevel=normal | Out-Null
netsh int tcp set global rss=enabled | Out-Null
Write-Host '@@PCT 25'; Write-Host '@@STEP Winsock'
netsh winsock reset | Out-Null
netsh int ip reset | Out-Null
netsh winhttp reset proxy | Out-Null
Write-Host '@@PCT 60'; Write-Host '@@STEP DNS / DHCP'
ipconfig /flushdns | Out-Null
ipconfig /release | Out-Null
ipconfig /renew | Out-Null
Write-Host '@@PCT 100'
'@
    firewall = @'
Write-Host '@@STEP Firewall'
netsh advfirewall reset | Out-Null
exit $LASTEXITCODE
'@
    # Procedura di ripristino di Windows Update descritta da Microsoft. A
    # differenza di altri strumenti non cancella i criteri di gruppo, che
    # contengono anche le altre impostazioni del programma.
    wuReset = @'
Write-Host '@@STEP Servizi'
foreach ($s in 'bits','wuauserv','appidsvc','cryptsvc','usosvc') { Stop-Service $s -Force -ErrorAction SilentlyContinue }
Write-Host '@@PCT 15'; Write-Host '@@STEP Code BITS'
Remove-Item "$env:ALLUSERSPROFILE\Microsoft\Network\Downloader\qmgr*.dat" -Force -ErrorAction SilentlyContinue
Write-Host '@@PCT 25'; Write-Host '@@STEP SoftwareDistribution'
foreach ($p in "$env:SystemRoot\SoftwareDistribution", "$env:SystemRoot\System32\catroot2") {
    Remove-Item "$p.old" -Recurse -Force -ErrorAction SilentlyContinue
    if (Test-Path $p) { Rename-Item $p "$(Split-Path $p -Leaf).old" -ErrorAction SilentlyContinue }
}
Write-Host '@@PCT 45'; Write-Host '@@STEP Permessi dei servizi'
$sd = 'D:(A;;CCLCSWRPWPDTLOCRRC;;;SY)(A;;CCDCLCSWRPWPDTLOCRSDRCWDWO;;;BA)(A;;CCLCSWLOCRRC;;;AU)(A;;CCLCSWRPWPDTLOCRRC;;;PU)'
sc.exe sdset bits $sd | Out-Null
sc.exe sdset wuauserv $sd | Out-Null
Write-Host '@@PCT 55'; Write-Host '@@STEP Componenti'
$dlls = 'atl.dll','urlmon.dll','mshtml.dll','jscript.dll','vbscript.dll','scrrun.dll','msxml3.dll','msxml6.dll','actxprxy.dll','softpub.dll',
        'wintrust.dll','dssenh.dll','rsaenh.dll','cryptdlg.dll','oleaut32.dll','ole32.dll','shell32.dll','wuapi.dll','wuaueng.dll','wups.dll','wups2.dll','qmgr.dll','qmgrprxy.dll'
foreach ($d in $dlls) { if (Test-Path "$env:SystemRoot\System32\$d") { Start-Process regsvr32.exe -ArgumentList '/s', $d -Wait -WindowStyle Hidden } }
Write-Host '@@PCT 75'; Write-Host '@@STEP Rete'
netsh winsock reset | Out-Null
netsh winhttp reset proxy | Out-Null
Get-BitsTransfer -AllUsers -ErrorAction SilentlyContinue | Remove-BitsTransfer -ErrorAction SilentlyContinue
Write-Host '@@PCT 85'; Write-Host '@@STEP Avvio dei servizi'
Set-Service bits -StartupType Manual -ErrorAction SilentlyContinue
Set-Service wuauserv -StartupType Manual -ErrorAction SilentlyContinue
Set-Service cryptsvc -StartupType Automatic -ErrorAction SilentlyContinue
Set-ItemProperty 'HKLM:\SYSTEM\CurrentControlSet\Services\AppIDSvc' -Name Start -Value 3 -ErrorAction SilentlyContinue
foreach ($s in 'cryptsvc','bits','wuauserv','usosvc') { Start-Service $s -ErrorAction SilentlyContinue }
Start-Process "$env:SystemRoot\System32\UsoClient.exe" -ArgumentList 'StartScan' -WindowStyle Hidden -ErrorAction SilentlyContinue
Write-Host '@@PCT 100'
'@
    # Prima DISM ripara l'archivio dei componenti, poi SFC ripara i file usando
    # quell'archivio: e' l'ordine consigliato da Microsoft.
    repair = @'
Write-Host '@@STEP DISM /RestoreHealth'
& dism.exe /Online /Cleanup-Image /RestoreHealth
$d = $LASTEXITCODE
Write-Host '@@STEP SFC /scannow'
& sfc.exe /scannow
if ($d -ne 0 -and $d -ne 3010) { exit $d }
exit 0
'@
    ntp = @'
Write-Host '@@STEP Servizio Ora di Windows'
Set-Service w32time -StartupType Manual -ErrorAction SilentlyContinue
Start-Service w32time -ErrorAction SilentlyContinue
w32tm /config /manualpeerlist:"pool.ntp.org,0x8 time.windows.com,0x8" /syncfromflags:manual /update | Out-Null
Restart-Service w32time -Force -ErrorAction SilentlyContinue
Write-Host '@@PCT 60'; Write-Host '@@STEP Sincronizzazione'
w32tm /resync /force | Out-Null
exit $LASTEXITCODE
'@
    rootCerts = @'
Write-Host '@@STEP Scarico l''elenco da Windows Update'
$f = Join-Path $env:TEMP 'TweakAndrew_roots.sst'
& certutil.exe -generateSSTFromWU $f | Out-Null
if ($LASTEXITCODE -ne 0 -or -not (Test-Path -LiteralPath $f)) { Write-Host 'ERRORE: elenco dei certificati non scaricato.'; exit 1 }
Write-Host '@@PCT 60'; Write-Host '@@STEP Importo i certificati'
try { $n = @(Import-Certificate -FilePath $f -CertStoreLocation Cert:\LocalMachine\Root -ErrorAction Stop).Count; Write-Host "OK: $n certificati radice aggiornati." }
catch { Write-Host "ERRORE: $($_.Exception.Message)"; Remove-Item -LiteralPath $f -Force -ErrorAction SilentlyContinue; exit 1 }
Remove-Item -LiteralPath $f -Force -ErrorAction SilentlyContinue
exit 0
'@
    winget = @'
Write-Host '@@STEP App Installer'
try { Add-AppxPackage -RegisterByFamilyName -MainPackage Microsoft.DesktopAppInstaller_8wekyb3d8bbwe -ErrorAction Stop } catch { Write-Host $_.Exception.Message }
Write-Host '@@PCT 60'; Write-Host '@@STEP Origini'
$w = Get-Command winget.exe -ErrorAction SilentlyContinue
if (-not $w) { exit 1 }
& $w.Source source reset --force --disable-interactivity | Out-Null
& $w.Source source update --disable-interactivity | Out-Null
exit 0
'@
    regBackup = @'
Write-Host '@@STEP Backup del registro'
$k = 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Configuration Manager'
New-ItemProperty -Path $k -Name EnablePeriodicBackup -PropertyType DWord -Value 1 -Force | Out-Null
schtasks.exe /Change /TN '\Microsoft\Windows\Registry\RegIdleBackup' /ENABLE | Out-Null
schtasks.exe /Run /TN '\Microsoft\Windows\Registry\RegIdleBackup' | Out-Null
exit 0
'@
}

# Funzionalita' di Windows che si possono attivare.
$script:Features = @(
    @{ Key = 'netfx';   Names = @('NetFx3', 'NetFx4-AdvSrvs') }
    @{ Key = 'hyperv';  Names = @('Microsoft-Hyper-V-All') }
    @{ Key = 'sandbox'; Names = @('Containers-DisposableClientVM') }
    @{ Key = 'wsl';     Names = @('VirtualMachinePlatform', 'Microsoft-Windows-Subsystem-Linux') }
    @{ Key = 'media';   Names = @('WindowsMediaPlayer', 'MediaPlayback', 'DirectPlay', 'LegacyComponents') }
    @{ Key = 'nfs';     Names = @('ServicesForNFS-ClientOnly', 'ClientForNFS-Infrastructure', 'NFS-Administration') }
)

function Get-FeatureScript([string[]]$Keys) {
    $names = @()
    foreach ($k in $Keys) { $names += ($script:Features | Where-Object { $_.Key -eq $k }).Names }
    $sb = New-Object System.Text.StringBuilder
    [void]$sb.AppendLine('$rc = 0')
    foreach ($n in $names) {
        [void]$sb.AppendLine("Write-Host '@@STEP $n'")
        [void]$sb.AppendLine("& dism.exe /Online /Enable-Feature /FeatureName:$n /All /NoRestart")
        [void]$sb.AppendLine("if (`$LASTEXITCODE -ne 0 -and `$LASTEXITCODE -ne 3010) { `$rc = `$LASTEXITCODE } elseif (`$LASTEXITCODE -eq 3010 -and `$rc -eq 0) { `$rc = 3010 }")
    }
    [void]$sb.AppendLine('exit $rc')
    return $sb.ToString()
}

# Pannelli classici di Windows.
$script:Panels = @(
    @{ Key = 'control';  Cmd = 'control.exe' }
    @{ Key = 'compmgmt'; Cmd = 'compmgmt.msc' }
    @{ Key = 'devmgmt';  Cmd = 'devmgmt.msc' }
    @{ Key = 'diskmgmt'; Cmd = 'diskmgmt.msc' }
    @{ Key = 'services'; Cmd = 'services.msc' }
    @{ Key = 'eventvwr'; Cmd = 'eventvwr.msc' }
    @{ Key = 'appwiz';   Cmd = 'appwiz.cpl' }
    @{ Key = 'ncpa';     Cmd = 'ncpa.cpl' }
    @{ Key = 'powercfg'; Cmd = 'powercfg.cpl' }
    @{ Key = 'printers'; Cmd = 'shell:::{A8A91A66-3A7D-4424-8D24-04E180695C7A}' }
    @{ Key = 'mouse';    Cmd = 'main.cpl' }
    @{ Key = 'sound';    Cmd = 'mmsys.cpl' }
    @{ Key = 'sysdm';    Cmd = 'sysdm.cpl' }
    @{ Key = 'region';   Cmd = 'intl.cpl' }
    @{ Key = 'time';     Cmd = 'timedate.cpl' }
    @{ Key = 'security'; Cmd = 'wscui.cpl' }
    @{ Key = 'firewall'; Cmd = 'firewall.cpl' }
    @{ Key = 'restore';  Cmd = 'rstrui.exe' }
)

# ------------------------------------------------------------------------------
# Pagina Strumenti
# ------------------------------------------------------------------------------
# Ogni strumento ha un'icona, un nome semplice e una frase che dice cosa fa.
# Icone: Segoe Fluent Icons su Windows 11, Segoe MDL2 Assets su Windows 10;
# i codici usati qui esistono in entrambi.
$script:IconFont = New-Object System.Windows.Media.FontFamily('Segoe Fluent Icons, Segoe MDL2 Assets')

function New-ToolIcon([string]$Glyph, [string]$Color, [double]$Size = 36) {
    $b = New-Object System.Windows.Controls.Border
    $b.Width = $Size; $b.Height = $Size; $b.CornerRadius = [Math]::Round($Size / 4)
    $c = [System.Windows.Media.ColorConverter]::ConvertFromString($Color)
    $b.Background = New-Object System.Windows.Media.SolidColorBrush ([System.Windows.Media.Color]::FromArgb(38, $c.R, $c.G, $c.B))
    $t = New-Object System.Windows.Controls.TextBlock
    $t.Text = [string][char][Convert]::ToInt32($Glyph, 16); $t.FontFamily = $script:IconFont; $t.FontSize = [Math]::Round($Size * 0.46)
    $t.Foreground = New-AppBrush $Color; $t.HorizontalAlignment = 'Center'; $t.VerticalAlignment = 'Center'
    $b.Child = $t
    return $b
}

# Intestazione di una scheda: icona, titolo e una frase semplice.
function New-ToolHead([string]$Glyph, [string]$Color, [string]$Title, [string]$Desc) {
    $g = New-Object System.Windows.Controls.Grid; $g.Margin = '0,0,0,14'
    $c0 = New-Object System.Windows.Controls.ColumnDefinition; $c0.Width = [System.Windows.GridLength]::Auto
    $c1 = New-Object System.Windows.Controls.ColumnDefinition
    $g.ColumnDefinitions.Add($c0); $g.ColumnDefinitions.Add($c1)
    $ic = New-ToolIcon $Glyph $Color 42; $ic.VerticalAlignment = 'Top'
    [void]$g.Children.Add($ic)
    $sp = New-Object System.Windows.Controls.StackPanel; $sp.Margin = '14,0,0,0'; $sp.VerticalAlignment = 'Center'
    $t = New-Object System.Windows.Controls.TextBlock
    $t.Text = $Title; $t.FontSize = 17; $t.FontWeight = 'SemiBold'; $t.Foreground = New-AppBrush '#FFF2F4F7'
    $t.FontFamily = 'Segoe UI Variable Display, Segoe UI'; $t.TextWrapping = 'Wrap'
    [void]$sp.Children.Add($t)
    if ($Desc) {
        $d = New-Object System.Windows.Controls.TextBlock
        $d.Text = $Desc; $d.Style = $window.FindResource('SubTitle'); $d.Margin = '0,3,0,0'; $d.FontSize = 12.5
        [void]$sp.Children.Add($d)
    }
    [System.Windows.Controls.Grid]::SetColumn($sp, 1); [void]$g.Children.Add($sp)
    return $g
}

function New-ToolCard([string]$Title, [string]$Hint, [string]$Glyph = '', [string]$Color = '#FF4C8DFF') {
    $card = New-Object System.Windows.Controls.Border
    $card.Style = $window.FindResource('Glass')
    $sp = New-Object System.Windows.Controls.StackPanel
    if ($Glyph) { [void]$sp.Children.Add((New-ToolHead $Glyph $Color $Title $Hint)) }
    else {
        $h = New-Object System.Windows.Controls.TextBlock
        $h.Text = $Title.ToUpper(); $h.Style = $window.FindResource('CardTitle')
        [void]$sp.Children.Add($h)
        if ($Hint) {
            $s = New-Object System.Windows.Controls.TextBlock
            $s.Text = $Hint; $s.Style = $window.FindResource('SubTitle'); $s.Margin = '0,-4,0,10'
            [void]$sp.Children.Add($s)
        }
    }
    $card.Child = $sp
    return @{ Card = $card; Panel = $sp }
}

function New-ToolButton([string]$Text, [scriptblock]$Click, [string]$Style = 'GhostBtn') {
    $b = New-Object System.Windows.Controls.Button
    $b.Content = $Text; $b.Style = $window.FindResource($Style); $b.Margin = '0,0,8,0'
    $b.Add_Click($Click)
    return $b
}

# Riquadro di una riparazione: icona e nome, cosa fa, e il pulsante. $Tag dice
# se serve un riavvio ('reboot') o se va usata con cautela ('caution').
function New-ToolTile([string]$Key, [string]$Glyph, [string]$Color, [scriptblock]$Click, [string]$Tag = '') {
    $b = New-Object System.Windows.Controls.Border
    $b.Background = New-AppBrush '#FF111316'; $b.BorderBrush = New-AppBrush '#FF25282D'; $b.BorderThickness = 1
    $b.CornerRadius = 9; $b.Padding = '14,12,14,12'; $b.Margin = '0,0,10,10'
    $g = New-Object System.Windows.Controls.Grid
    foreach ($h in 'Auto', '*', 'Auto') {
        $rd = New-Object System.Windows.Controls.RowDefinition
        $rd.Height = if ($h -eq '*') { New-Object System.Windows.GridLength(1, [System.Windows.GridUnitType]::Star) } else { [System.Windows.GridLength]::Auto }
        $g.RowDefinitions.Add($rd)
    }
    $top = New-Object System.Windows.Controls.Grid
    $tc0 = New-Object System.Windows.Controls.ColumnDefinition; $tc0.Width = [System.Windows.GridLength]::Auto
    $tc1 = New-Object System.Windows.Controls.ColumnDefinition
    $top.ColumnDefinitions.Add($tc0); $top.ColumnDefinitions.Add($tc1)
    [void]$top.Children.Add((New-ToolIcon $Glyph $Color 32))
    $t = New-Object System.Windows.Controls.TextBlock
    $t.Text = T "tool_$Key"; $t.FontSize = 13; $t.FontWeight = 'SemiBold'; $t.Foreground = New-AppBrush '#FFE6E8EB'
    $t.TextWrapping = 'Wrap'; $t.VerticalAlignment = 'Center'; $t.Margin = '10,0,0,0'
    [System.Windows.Controls.Grid]::SetColumn($t, 1); [void]$top.Children.Add($t)
    [void]$g.Children.Add($top)
    $d = New-Object System.Windows.Controls.TextBlock
    $d.Text = T "toolDesc_$Key"; $d.Style = $window.FindResource('SubTitle'); $d.Margin = '0,9,0,10'
    [System.Windows.Controls.Grid]::SetRow($d, 1); [void]$g.Children.Add($d)
    $bottom = New-Object System.Windows.Controls.Grid
    $bc0 = New-Object System.Windows.Controls.ColumnDefinition
    $bc1 = New-Object System.Windows.Controls.ColumnDefinition; $bc1.Width = [System.Windows.GridLength]::Auto
    $bottom.ColumnDefinitions.Add($bc0); $bottom.ColumnDefinitions.Add($bc1)
    if ($Tag) {
        $pill = if ($Tag -eq 'reboot') { New-AppPill (T 'tagReboot') '#FFFDBA74' '#26FB923C' } else { New-AppPill (T 'tagCaution') '#FFFCA5A5' '#26F87171' }
        $pill.Margin = '0'; $pill.HorizontalAlignment = 'Left'
        [void]$bottom.Children.Add($pill)
    }
    $btn = New-Object System.Windows.Controls.Button
    $btn.Content = T 'toolRun'; $btn.Style = $window.FindResource('GhostBtn'); $btn.Padding = '18,6,18,6'
    $btn.Add_Click($Click)
    [System.Windows.Controls.Grid]::SetColumn($btn, 1); [void]$bottom.Children.Add($btn)
    [System.Windows.Controls.Grid]::SetRow($bottom, 2); [void]$g.Children.Add($bottom)
    $b.Child = $g
    return $b
}

function Confirm-Tool([string]$Key, [string]$Kind = 'ask') {
    return (Show-Dialog (T "tool_$Key") (T "toolAsk_$Key") $Kind)
}

$script:CleanBoxes = @{}
$script:CleanSizes = @{}
$script:CleanSizeText = @{}
$script:FeatureBoxes = @{}

# Riga con testo a sinistra e interruttore a destra. Il modello delle caselle
# mostra solo testo semplice: titolo e spiegazione stanno accanto, e un clic
# sul testo sposta l'interruttore.
function New-SwitchRow($Text, [string]$Desc, $Box) {
    $g = New-Object System.Windows.Controls.Grid; $g.Margin = '0,0,0,6'
    $c0 = New-Object System.Windows.Controls.ColumnDefinition
    $c1 = New-Object System.Windows.Controls.ColumnDefinition; $c1.Width = [System.Windows.GridLength]::Auto
    $g.ColumnDefinitions.Add($c0); $g.ColumnDefinitions.Add($c1)
    $sp = New-Object System.Windows.Controls.StackPanel; $sp.VerticalAlignment = 'Center'; $sp.Margin = '0,0,12,0'
    $sp.Background = [System.Windows.Media.Brushes]::Transparent; $sp.Cursor = 'Hand'; $sp.Tag = $Box
    [void]$sp.Children.Add($Text)
    if ($Desc) {
        $d = New-Object System.Windows.Controls.TextBlock
        $d.Text = $Desc; $d.Style = $window.FindResource('SubTitle'); $d.Margin = '0,1,0,0'
        [void]$sp.Children.Add($d)
    }
    $sp.Add_MouseLeftButtonUp({ $b = $this.Tag; if ($b.IsEnabled) { $b.IsChecked = -not ($b.IsChecked -eq $true) } })
    [void]$g.Children.Add($sp)
    $Box.Content = ''; $Box.VerticalAlignment = 'Center'
    [System.Windows.Controls.Grid]::SetColumn($Box, 1); [void]$g.Children.Add($Box)
    return $g
}

# Riga della pulizia: nome, spazio occupato e spiegazione.
function New-CleanRow($it) {
    $cb = New-Object System.Windows.Controls.CheckBox
    $cb.Tag = 'tool'; $cb.IsChecked = $it.On
    $t = New-Object System.Windows.Controls.TextBlock; $t.TextWrapping = 'Wrap'
    $r1 = New-Object System.Windows.Documents.Run (T "clean_$($it.Key)")
    $r1.Foreground = New-AppBrush '#FFE6E8EB'; $r1.FontSize = 13
    $r2 = New-Object System.Windows.Documents.Run ''
    $r2.Foreground = New-AppBrush '#FF7EB1FF'; $r2.FontSize = 12.5; $r2.FontWeight = 'SemiBold'
    [void]$t.Inlines.Add($r1); [void]$t.Inlines.Add($r2)
    $cb.Add_Checked({ Update-CleanTotal }); $cb.Add_Unchecked({ Update-CleanTotal })
    $script:CleanBoxes[$it.Key] = $cb
    $script:CleanSizeText[$it.Key] = $r2
    return (New-SwitchRow $t (T "cleanTip_$($it.Key)") $cb)
}

function Update-CleanTotal {
    if ($null -eq $script:CleanTotalText) { return }
    $sum = 0.0; $n = 0
    foreach ($k in $script:CleanBoxes.Keys) {
        if ($script:CleanBoxes[$k].IsChecked -ne $true) { continue }
        $n++
        if ($script:CleanSizes.ContainsKey($k)) { $sum += [double]$script:CleanSizes[$k] }
    }
    $sz = if ($sum -ge 1GB) { '{0:0.0} GB' -f ($sum / 1GB) } else { '{0:0} MB' -f ($sum / 1MB) }
    $script:CleanTotalText.Text = if ($script:ToolScanJob) { T 'cleanMeasuring' } else { (T 'cleanTotal') -f $sz }
    if ($script:CleanRunBtn) { $script:CleanRunBtn.IsEnabled = ($n -gt 0) }
}

function Show-ToolsPage {
    $panTools.Children.Clear()
    $root = New-Object System.Windows.Controls.StackPanel

    # --- riga 1: pulizia totale e dispositivi scollegati, le due cose piu' usate
    $row1 = New-Object System.Windows.Controls.Grid
    foreach ($i in 0..1) { $cd = New-Object System.Windows.Controls.ColumnDefinition; $cd.Width = New-Object System.Windows.GridLength(1, [System.Windows.GridUnitType]::Star); $row1.ColumnDefinitions.Add($cd) }

    $c = New-ToolCard (T 'ttlCleanAll') (T 'cleanAllHint') 'E74D' '#FF4C8DFF'
    $script:CleanBoxes = @{}; $script:CleanSizeText = @{}
    foreach ($it in $script:CleanItems) { [void]$c.Panel.Children.Add((New-CleanRow $it)) }
    $bar = New-Object System.Windows.Controls.Grid; $bar.Margin = '0,12,0,0'
    $bc0 = New-Object System.Windows.Controls.ColumnDefinition
    $bc1 = New-Object System.Windows.Controls.ColumnDefinition; $bc1.Width = [System.Windows.GridLength]::Auto
    $bar.ColumnDefinitions.Add($bc0); $bar.ColumnDefinitions.Add($bc1)
    $script:CleanTotalText = New-Object System.Windows.Controls.TextBlock
    $script:CleanTotalText.FontSize = 13; $script:CleanTotalText.FontWeight = 'SemiBold'; $script:CleanTotalText.Foreground = New-AppBrush '#FFC5C9CF'
    $script:CleanTotalText.VerticalAlignment = 'Center'
    [void]$bar.Children.Add($script:CleanTotalText)
    $btns = New-Object System.Windows.Controls.StackPanel; $btns.Orientation = 'Horizontal'
    [void]$btns.Children.Add((New-ToolButton (T 'cleanRescan') { Start-ToolScan }))
    $script:CleanRunBtn = New-ToolButton (T 'cleanNow') {
        $keys = @($script:CleanItems | Where-Object { $script:CleanBoxes[$_.Key].IsChecked -eq $true } | ForEach-Object { $_.Key })
        if ($keys.Count -eq 0) { return }
        if (-not (Show-Dialog (T 'ttlCleanAll') ((T 'cleanAsk') -f $keys.Count) 'warn')) { return }
        $script:ToolsNeedRefresh = $true
        Add-ToolJob (T 'ttlCleanAll') (Get-CleanScript $keys)
    } 'PrimaryBtn'
    $script:CleanRunBtn.Margin = '0'
    [void]$btns.Children.Add($script:CleanRunBtn)
    [System.Windows.Controls.Grid]::SetColumn($btns, 1); [void]$bar.Children.Add($btns)
    [void]$c.Panel.Children.Add($bar)
    $leftCol = New-Object System.Windows.Controls.StackPanel
    [void]$leftCol.Children.Add($c.Card)

    # Programmi all'avvio, sotto la pulizia.
    $c = New-ToolCard (T 'ttlStartup') (T 'startupHint') 'E7E8' '#FFFBBF24'
    $script:StartupStatus = New-Object System.Windows.Controls.TextBlock
    $script:StartupStatus.FontSize = 13; $script:StartupStatus.Foreground = New-AppBrush '#FFC5C9CF'; $script:StartupStatus.Margin = '0,0,0,8'
    [void]$c.Panel.Children.Add($script:StartupStatus)
    $sv2 = New-Object System.Windows.Controls.ScrollViewer; $sv2.MaxHeight = 420; $sv2.VerticalScrollBarVisibility = 'Auto'
    $script:StartupList = New-Object System.Windows.Controls.StackPanel
    $sv2.Content = $script:StartupList
    [void]$c.Panel.Children.Add($sv2)
    [void]$leftCol.Children.Add($c.Card)
    [void]$row1.Children.Add($leftCol)

    $c = New-ToolCard (T 'ttlGhost') (T 'ghostHint') 'E772' '#FF2DD4BF'
    $script:GhostStatus = New-Object System.Windows.Controls.TextBlock
    $script:GhostStatus.FontSize = 13; $script:GhostStatus.Foreground = New-AppBrush '#FFC5C9CF'; $script:GhostStatus.TextWrapping = 'Wrap'
    $script:GhostStatus.Margin = '0,0,0,8'
    [void]$c.Panel.Children.Add($script:GhostStatus)
    $script:GhostAll = New-Object System.Windows.Controls.CheckBox
    $script:GhostAll.Tag = 'tool'; $script:GhostAll.IsChecked = $true
    $script:GhostAll.Add_Checked({ foreach ($g in $script:GhostBoxes) { $g.IsChecked = $true }; Update-GhostButton })
    $script:GhostAll.Add_Unchecked({ foreach ($g in $script:GhostBoxes) { $g.IsChecked = $false }; Update-GhostButton })
    $at = New-Object System.Windows.Controls.TextBlock; $at.Text = T 'ghostAll'; $at.FontWeight = 'SemiBold'; $at.Foreground = New-AppBrush '#FFC5C9CF'
    $script:GhostAllRow = New-SwitchRow $at '' $script:GhostAll
    $script:GhostAllRow.Visibility = 'Collapsed'; $script:GhostAllRow.Margin = '0,0,0,8'
    [void]$c.Panel.Children.Add($script:GhostAllRow)
    $sv = New-Object System.Windows.Controls.ScrollViewer; $sv.MaxHeight = 330; $sv.VerticalScrollBarVisibility = 'Auto'
    $script:GhostList = New-Object System.Windows.Controls.StackPanel
    $sv.Content = $script:GhostList
    [void]$c.Panel.Children.Add($sv)
    $gb = New-Object System.Windows.Controls.StackPanel; $gb.Orientation = 'Horizontal'; $gb.Margin = '0,12,0,0'; $gb.HorizontalAlignment = 'Right'
    [void]$gb.Children.Add((New-ToolButton (T 'ghostRescan') { Start-GhostScan }))
    $script:GhostRemoveBtn = New-ToolButton (T 'ghostRemove') { Invoke-GhostRemove } 'PrimaryBtn'
    $script:GhostRemoveBtn.Margin = '0'; $script:GhostRemoveBtn.IsEnabled = $false
    [void]$gb.Children.Add($script:GhostRemoveBtn)
    [void]$c.Panel.Children.Add($gb)
    $ghostCard = $c.Card
    $rightCol = New-Object System.Windows.Controls.StackPanel
    [System.Windows.Controls.Grid]::SetColumn($rightCol, 1)

    # App di Windows da togliere (debloat), in cima alla colonna destra.
    $c = New-ToolCard (T 'ttlDebloat') (T 'debloatHint') 'E74C' '#FFF472B6'
    $script:DebloatStatus = New-Object System.Windows.Controls.TextBlock
    $script:DebloatStatus.FontSize = 13; $script:DebloatStatus.Foreground = New-AppBrush '#FFC5C9CF'; $script:DebloatStatus.Margin = '0,0,0,8'
    [void]$c.Panel.Children.Add($script:DebloatStatus)
    $script:DebloatList = New-Object System.Windows.Controls.StackPanel
    [void]$c.Panel.Children.Add($script:DebloatList)
    $db = New-Object System.Windows.Controls.StackPanel; $db.Orientation = 'Horizontal'; $db.Margin = '0,12,0,0'; $db.HorizontalAlignment = 'Right'
    [void]$db.Children.Add((New-ToolButton (T 'ghostRescan') { Start-DebloatScan }))
    $script:DebloatRunBtn = New-ToolButton (T 'debloatRun') { Invoke-Debloat } 'PrimaryBtn'
    $script:DebloatRunBtn.Margin = '0'; $script:DebloatRunBtn.IsEnabled = $false
    [void]$db.Children.Add($script:DebloatRunBtn)
    [void]$c.Panel.Children.Add($db)
    [void]$rightCol.Children.Add($c.Card)
    [void]$rightCol.Children.Add($ghostCard)
    [void]$row1.Children.Add($rightCol)
    [void]$root.Children.Add($row1)

    # Funzionalita' di Windows, sotto i dispositivi.
    $c = New-ToolCard (T 'ttlFeatures') (T 'featHint') 'E71D' '#FFA78BFA'
    $script:FeatureBoxes = @{}
    foreach ($f in $script:Features) {
        $cb = New-Object System.Windows.Controls.CheckBox
        $cb.Tag = 'tool'; $cb.Content = T "feat_$($f.Key)"; $cb.ToolTip = T "featTip_$($f.Key)"
        $script:FeatureBoxes[$f.Key] = $cb
        [void]$c.Panel.Children.Add($cb)
    }
    $fb = New-ToolButton (T 'featRun') {
        $keys = @($script:Features | Where-Object { $script:FeatureBoxes[$_.Key].IsChecked -eq $true -and $script:FeatureBoxes[$_.Key].IsEnabled } | ForEach-Object { $_.Key })
        if ($keys.Count -eq 0) { return }
        if (-not (Show-Dialog (T 'ttlFeatures') ((T 'featAsk') -f $keys.Count) 'ask')) { return }
        foreach ($k in $keys) { $script:FeatureBoxes[$k].IsChecked = $false }
        $script:ToolsNeedRefresh = $true
        Add-ToolJob (T 'ttlFeatures') (Get-FeatureScript $keys) -Reboot
    } 'PrimaryBtn'
    $fb.Margin = '0,12,0,0'; $fb.HorizontalAlignment = 'Right'
    [void]$c.Panel.Children.Add($fb)
    [void]$rightCol.Children.Add($c.Card)

    # --- riga 2: riparazioni, un riquadro per ciascuna
    $c = New-ToolCard (T 'ttlFix') (T 'fixHint') 'E90F' '#FF34D399'
    $ug = New-Object System.Windows.Controls.Primitives.UniformGrid; $ug.Columns = 3; $ug.Margin = '0,0,-10,-10'
    [void]$ug.Children.Add((New-ToolTile 'netQuick' 'E701' '#FF38BDF8' { if (Confirm-Tool 'netQuick') { Add-ToolJob (T 'tool_netQuick') $script:ToolScripts.netQuick } }))
    [void]$ug.Children.Add((New-ToolTile 'netFull' 'E839' '#FF38BDF8' { if (Confirm-Tool 'netFull' 'warn') { Add-ToolJob (T 'tool_netFull') $script:ToolScripts.netFull -Reboot } } 'reboot'))
    [void]$ug.Children.Add((New-ToolTile 'firewall' 'EA18' '#FFF87171' { if (Confirm-Tool 'firewall' 'danger') { Add-ToolJob (T 'tool_firewall') $script:ToolScripts.firewall } } 'caution'))
    [void]$ug.Children.Add((New-ToolTile 'wuReset' 'E895' '#FFFBBF24' { if (Confirm-Tool 'wuReset' 'warn') { Add-ToolJob (T 'tool_wuReset') $script:ToolScripts.wuReset -Reboot } } 'reboot'))
    [void]$ug.Children.Add((New-ToolTile 'repair' 'E90F' '#FF34D399' { if (Confirm-Tool 'repair') { Add-ToolJob (T 'tool_repair') $script:ToolScripts.repair } }))
    [void]$ug.Children.Add((New-ToolTile 'ntp' 'E823' '#FFA78BFA' { Add-ToolJob (T 'tool_ntp') $script:ToolScripts.ntp }))
    [void]$ug.Children.Add((New-ToolTile 'rootCerts' 'E8D7' '#FF34D399' { Add-ToolJob (T 'tool_rootCerts') $script:ToolScripts.rootCerts }))
    [void]$ug.Children.Add((New-ToolTile 'winget' 'E7B8' '#FF60A5FA' { Add-ToolJob (T 'tool_winget') $script:ToolScripts.winget }))
    [void]$ug.Children.Add((New-ToolTile 'regBackup' 'E78C' '#FF60A5FA' { Add-ToolJob (T 'tool_regBackup') $script:ToolScripts.regBackup }))
    [void]$ug.Children.Add((New-ToolTile 'store' 'E719' '#FF60A5FA' {
        Start-Process "$env:SystemRoot\System32\wsreset.exe" -ErrorAction SilentlyContinue
        Write-Log "[OK] Cache del Microsoft Store: wsreset avviato."
    }))
    [void]$ug.Children.Add((New-ToolTile 'explorer' 'EC50' '#FFFBBF24' {
        Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
        Write-Log "[OK] Esplora risorse riavviato."
    }))
    [void]$ug.Children.Add((New-ToolTile 'icons' 'E8B9' '#FFFBBF24' {
        if (-not (Confirm-Tool 'icons')) { return }
        Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
        Start-Sleep -Milliseconds 800
        $d = "$env:LOCALAPPDATA\Microsoft\Windows\Explorer"
        Remove-Item "$env:LOCALAPPDATA\IconCache.db" -Force -ErrorAction SilentlyContinue
        Get-ChildItem $d -Filter 'iconcache_*.db' -Force -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue
        Get-ChildItem $d -Filter 'thumbcache_*.db' -Force -ErrorAction SilentlyContinue | Remove-Item -Force -ErrorAction SilentlyContinue
        if (-not (Get-Process explorer -ErrorAction SilentlyContinue)) { Start-Process explorer.exe }
        Write-Log "[OK] Cache di icone e miniature ricostruita."
    }))
    [void]$c.Panel.Children.Add($ug)
    [void]$root.Children.Add($c.Card)


    $c = New-ToolCard (T 'ttlPanels') (T 'panelsHint') 'E713' '#FF94A3B8'
    $ug = New-Object System.Windows.Controls.Primitives.UniformGrid; $ug.Columns = 4
    foreach ($p in $script:Panels) {
        $b = New-Object System.Windows.Controls.Button
        $b.Content = T "panel_$($p.Key)"; $b.Style = $window.FindResource('GhostBtn'); $b.Margin = '0,0,8,8'; $b.Tag = $p.Cmd
        $b.Add_Click({ try { Start-Process ([string]$this.Tag) } catch { Write-Log "[ERRORE] $($this.Content): $($_.Exception.Message)" } })
        [void]$ug.Children.Add($b)
    }
    [void]$c.Panel.Children.Add($ug)
    [void]$root.Children.Add($c.Card)

    [void]$panTools.Children.Add($root)
    Update-CleanTotal
}

# Spazio occupato dalle voci di pulizia e stato delle funzionalita': letture
# lente, in un runspace. Il risultato torna sulle righe.
$script:ToolScanScript = @'
param($items, $features, $helpers)
. ([ScriptBlock]::Create($helpers))
$out = @{ Sizes = @{}; Features = @{} }
foreach ($it in $items) {
    $sum = 0
    foreach ($p in $it.Paths) { $sum += Get-PathSize $p }
    switch ($it.Key) {
        'recycle' {
            foreach ($d in [IO.DriveInfo]::GetDrives() | Where-Object { $_.DriveType -eq 'Fixed' -and $_.IsReady }) { $sum += Get-PathSize (Join-Path $d.RootDirectory '$Recycle.Bin') }
        }
        'thumbs' { $sum += (Get-ChildItem "$env:LOCALAPPDATA\Microsoft\Windows\Explorer" -Filter 'thumbcache_*.db' -Force -ErrorAction SilentlyContinue | Measure-Object Length -Sum).Sum }
        'browserHist' { $sum += Get-BrowserSize }
        'browserCache' { $sum += Get-BrowserSize -Cache }
        'recent' { $sum += (Get-ChildItem "$env:APPDATA\Microsoft\Windows\Recent" -Force -Recurse -File -ErrorAction SilentlyContinue | Where-Object { $_.Name -ne $QuickAccessPins } | Measure-Object Length -Sum).Sum }
    }
    $out.Sizes[$it.Key] = [double]$sum
}
try {
    $all = @{}
    foreach ($f in Get-WindowsOptionalFeature -Online -ErrorAction Stop) { $all[$f.FeatureName] = [string]$f.State }
    foreach ($f in $features) {
        $st = @($f.Names | ForEach-Object { if ($all.ContainsKey($_)) { $all[$_] } else { 'Missing' } })
        $out.Features[$f.Key] = if (@($st | Where-Object { $_ -ne 'Enabled' -and $_ -ne 'Missing' }).Count -eq 0 -and @($st | Where-Object { $_ -eq 'Enabled' }).Count -gt 0) { 'on' }
                                elseif (@($st | Where-Object { $_ -eq 'Missing' }).Count -eq $st.Count) { 'missing' } else { 'off' }
    }
} catch {}
$out
'@

function Start-ToolScan {
    if ($script:ToolScanJob) { return }
    $ps = [powershell]::Create()
    [void]$ps.AddScript($script:ToolScanScript).AddArgument($script:CleanItems).AddArgument($script:Features).AddArgument($script:ToolHelpers)
    $script:ToolScanJob = @{ Ps = $ps; H = $ps.BeginInvoke() }
    foreach ($k in $script:CleanSizeText.Keys) { $script:CleanSizeText[$k].Text = "   ·  $(T 'cleanMeasuring')" }
    Update-CleanTotal
    $t = New-Object System.Windows.Threading.DispatcherTimer
    $t.Interval = [TimeSpan]::FromMilliseconds(250)
    $t.Add_Tick({
        if (-not $script:ToolScanJob.H.IsCompleted) { return }
        $this.Stop()
        try { $r = @($script:ToolScanJob.Ps.EndInvoke($script:ToolScanJob.H)) | Where-Object { $_ -is [hashtable] } | Select-Object -First 1 } catch { $r = $null }
        $script:ToolScanJob.Ps.Dispose(); $script:ToolScanJob = $null
        if ($null -eq $r) { Update-CleanTotal; return }
        foreach ($k in $script:CleanSizeText.Keys) {
            $b = [double]$r.Sizes[$k]
            $script:CleanSizes[$k] = $b
            $script:CleanSizeText[$k].Text = if ($b -ge 1GB) { '   ·  {0:0.0} GB' -f ($b / 1GB) } elseif ($b -ge 1MB) { '   ·  {0:0} MB' -f ($b / 1MB) } else { "   ·  $(T 'cleanEmpty')" }
        }
        foreach ($k in $script:FeatureBoxes.Keys) {
            $cb = $script:FeatureBoxes[$k]; $st = [string]$r.Features[$k]
            [System.Windows.Automation.AutomationProperties]::SetHelpText($cb, $(if ($st -eq 'on') { 'active' } else { '' }))
            $cb.IsEnabled = ($st -eq 'off')
            [System.Windows.Controls.ToolTipService]::SetShowOnDisabled($cb, $true)
            if ($st -eq 'missing') { $cb.ToolTip = T 'featMissing' }
        }
        Update-CleanTotal
    })
    $t.Start()
}

# ------------------------------------------------------------------------------
# Dispositivi scollegati
# ------------------------------------------------------------------------------
# Ogni chiavetta, cuffia o periferica collegata almeno una volta lascia una voce
# con il suo driver. Toglierle e' sicuro: ricollegando il dispositivo Windows lo
# reinstalla. Restano fuori le classi di sistema (processori, volumi, firmware,
# componenti software) e le voci ROOT, che Windows crea da solo.
$script:GhostScanScript = @'
$skip = @('System', 'Computer', 'Processor', 'Volume', 'VolumeSnapshot', 'Firmware', 'SoftwareComponent', 'LegacyDriver')
try {
    @(Get-PnpDevice -ErrorAction Stop | Where-Object {
        -not $_.Present -and $skip -notcontains [string]$_.Class -and [string]$_.InstanceId -notmatch '^(ROOT|HTREE)\\'
    } | Sort-Object Class, FriendlyName | ForEach-Object {
        $n = if ($_.FriendlyName) { [string]$_.FriendlyName } elseif ($_.Description) { [string]$_.Description } else { [string]$_.InstanceId }
        @{ Id = [string]$_.InstanceId; Name = $n; Class = [string]$_.Class }
    })
} catch { @{ Error = $_.Exception.Message } }
'@

$script:GhostBoxes = @()
function Update-GhostButton {
    if ($null -eq $script:GhostRemoveBtn) { return }
    $n = @($script:GhostBoxes | Where-Object { $_.IsChecked -eq $true }).Count
    $script:GhostRemoveBtn.IsEnabled = ($n -gt 0)
    $script:GhostRemoveBtn.Content = if ($n -gt 0) { "$(T 'ghostRemove') ($n)" } else { T 'ghostRemove' }
}

function Start-GhostScan {
    if ($script:GhostJob -or $null -eq $script:GhostList) { return }
    $script:GhostList.Children.Clear(); $script:GhostBoxes = @()
    $script:GhostAllRow.Visibility = 'Collapsed'
    $script:GhostStatus.Text = T 'ghostSearching'
    Update-GhostButton
    $ps = [powershell]::Create()
    [void]$ps.AddScript($script:GhostScanScript)
    $script:GhostJob = @{ Ps = $ps; H = $ps.BeginInvoke() }
    $t = New-Object System.Windows.Threading.DispatcherTimer
    $t.Interval = [TimeSpan]::FromMilliseconds(250)
    $t.Add_Tick({
        if (-not $script:GhostJob.H.IsCompleted) { return }
        $this.Stop()
        try { $r = @($script:GhostJob.Ps.EndInvoke($script:GhostJob.H) | Where-Object { $_ -is [hashtable] }) } catch { $r = @() }
        $script:GhostJob.Ps.Dispose(); $script:GhostJob = $null
        $err = @($r | Where-Object { $_.ContainsKey('Error') })
        $list = @($r | Where-Object { $_.ContainsKey('Id') })
        if ($err.Count -gt 0) { $script:GhostStatus.Text = "$(T 'ghostError') $($err[0].Error)"; return }
        if ($list.Count -eq 0) { $script:GhostStatus.Text = T 'ghostNone'; return }
        $script:GhostStatus.Text = (T 'ghostFound') -f $list.Count
        $script:GhostAll.IsChecked = $true; $script:GhostAllRow.Visibility = 'Visible'
        foreach ($d in $list) {
            $cb = New-Object System.Windows.Controls.CheckBox
            $cb.Tag = $d.Id; $cb.IsChecked = $true
            $tb = New-Object System.Windows.Controls.TextBlock; $tb.TextWrapping = 'Wrap'
            $r1 = New-Object System.Windows.Documents.Run $d.Name; $r1.Foreground = New-AppBrush '#FFE6E8EB'; $r1.FontSize = 12.5
            $r2 = New-Object System.Windows.Documents.Run "   $($d.Class)"; $r2.Foreground = New-AppBrush '#FF7F858D'; $r2.FontSize = 11.5
            [void]$tb.Inlines.Add($r1); [void]$tb.Inlines.Add($r2)
            $cb.Add_Checked({ Update-GhostButton }); $cb.Add_Unchecked({ Update-GhostButton })
            $script:GhostBoxes += $cb
            $row = New-SwitchRow $tb '' $cb; $row.Margin = '0,0,0,2'
            [void]$script:GhostList.Children.Add($row)
        }
        Update-GhostButton
    })
    $t.Start()
}

# ------------------------------------------------------------------------------
# Debloat: app di Windows da togliere
# ------------------------------------------------------------------------------
# Elenco preso da quello di ReviOS (playbook open source di Revision), piu' le
# app che il programma toglieva gia' dalla pagina Avanzate. Si vedono solo le
# app presenti. Accese di serie quelle che non servono quasi a nessuno; spente
# quelle che qualcuno usa (Foto, Fotocamera, Xbox, Outlook, OneDrive...).
# Restano fuori i pacchetti di sistema che ReviOS toglie con un suo strumento
# (Edge, componenti WinSxS): toglierli rompe aggiornamenti e funzioni di
# Windows, e Edge in Europa si disinstalla gia' da Impostazioni.
$script:DebloatApps = @(
    @{ K = 'news';      L = 'Microsoft News, MSN Meteo, Money e Sport'; On = $true;  P = @('Microsoft.BingNews', 'Microsoft.BingWeather', 'Microsoft.BingFinance', 'Microsoft.BingSports') }
    @{ K = 'bing';      L = 'Bing Search';                         On = $true;  P = @('Microsoft.BingSearch') }
    @{ K = 'copilot';   L = 'Copilot';                             On = $true;  P = @('Microsoft.Copilot', 'Microsoft.Windows.Ai.Copilot.Provider') }
    @{ K = 'widgets';   L = 'Widget (notizie sulla barra)';        On = $true;  P = @('MicrosoftWindows.Client.WebExperience', 'Microsoft.WidgetsPlatformRuntime', 'Microsoft.StartExperiencesApp') }
    @{ K = 'teams';     L = 'Microsoft Teams (personale)';         On = $true;  P = @('MicrosoftTeams', 'MSTeams') }
    @{ K = 'office';    L = 'Microsoft 365 (Office) e collegamenti'; On = $true;  P = @('Microsoft.MicrosoftOfficeHub', 'Microsoft.Office.OneNote') }
    @{ K = 'solitaire'; L = 'Microsoft Solitaire Collection';      On = $true;  P = @('Microsoft.MicrosoftSolitaireCollection') }
    @{ K = 'tips';      L = 'Suggerimenti, Assistenza e Hub di Feedback'; On = $true; P = @('Microsoft.Getstarted', 'Microsoft.GetHelp', 'Microsoft.WindowsFeedbackHub') }
    @{ K = 'clipchamp'; L = 'Clipchamp';                           On = $true;  P = @('Clipchamp.Clipchamp') }
    @{ K = 'todo';      L = 'Microsoft To Do e Power Automate';    On = $true;  P = @('Microsoft.Todos', 'Microsoft.PowerAutomateDesktop') }
    @{ K = 'people';    L = 'Persone, Mappe e Skype';              On = $true;  P = @('Microsoft.People', 'Microsoft.WindowsMaps', 'Microsoft.SkypeApp', 'Microsoft.Messaging') }
    @{ K = 'threeD';    L = 'App 3D e realtà mista';               On = $true;  P = @('Microsoft.Microsoft3DViewer', 'Microsoft.3DBuilder', 'Microsoft.Print3D', 'Microsoft.MSPaint', 'Microsoft.MixedReality.Portal') }
    @{ K = 'family';    L = 'Microsoft Family e Cortana';          On = $true;  P = @('MicrosoftCorporationII.MicrosoftFamily', 'Microsoft.549981C3F5F10') }
    @{ K = 'devhome';   L = 'Dev Home';                            On = $true;  P = @('Microsoft.Windows.DevHome') }
    @{ K = 'spotify';   L = 'Spotify (preinstallato)';             On = $true;  P = @('SpotifyAB.SpotifyMusic') }
    @{ K = 'recorder';  L = 'Registratore di suoni';               On = $false; P = @('Microsoft.WindowsSoundRecorder') }
    @{ K = 'media';     L = 'Lettore multimediale e Film e TV';    On = $false; P = @('Microsoft.ZuneMusic', 'Microsoft.ZuneVideo') }
    @{ K = 'outlook';   L = 'Outlook (nuovo) e Posta e Calendario'; On = $false; P = @('Microsoft.OutlookForWindows', 'microsoft.windowscommunicationsapps') }
    @{ K = 'phone';     L = 'Collegamento al telefono';            On = $false; P = @('Microsoft.YourPhone', 'MicrosoftWindows.CrossDevice') }
    @{ K = 'quick';     L = 'Assistenza rapida';                   On = $false; P = @('MicrosoftCorporationII.QuickAssist') }
    @{ K = 'alarms';    L = 'Sveglie e orologio';                  On = $false; P = @('Microsoft.WindowsAlarms') }
    @{ K = 'sticky';    L = 'Sticky Notes';                        On = $false; P = @('Microsoft.MicrosoftStickyNotes') }
    @{ K = 'camera';    L = 'Fotocamera';                          On = $false; P = @('Microsoft.WindowsCamera') }
    @{ K = 'photos';    L = 'Foto';                                On = $false; P = @('Microsoft.Windows.Photos') }
    @{ K = 'xbox';      L = 'App Xbox e Game Bar';                 On = $false; P = @('Microsoft.XboxApp', 'Microsoft.GamingApp', 'Microsoft.XboxGameOverlay', 'Microsoft.XboxGamingOverlay', 'Microsoft.XboxSpeechToTextOverlay', 'Microsoft.XboxIdentityProvider') }
    @{ K = 'onedrive';  L = 'OneDrive';                            On = $false; P = @() }
)
$script:DebloatBoxes = @{}

# Quali app ci sono: l'elenco di tutti gli utenti richiede i permessi di
# amministratore; senza, si guarda quello dell'utente.
$script:DebloatScanScript = @'
param($apps)
$names = @{}
try { foreach ($p in @(Get-AppxPackage -AllUsers -ErrorAction Stop)) { $names[$p.Name] = $true } }
catch { foreach ($p in @(Get-AppxPackage -ErrorAction SilentlyContinue)) { $names[$p.Name] = $true } }
$found = @()
foreach ($a in $apps) {
    if ($a.K -eq 'onedrive') {
        if ((Test-Path "$env:LOCALAPPDATA\Microsoft\OneDrive\OneDrive.exe") -or (Test-Path "$env:ProgramFiles\Microsoft OneDrive\OneDrive.exe") -or
            (Test-Path 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\OneDriveSetup.exe')) { $found += $a.K }
        continue
    }
    if (@($a.P | Where-Object { $names.ContainsKey($_) }).Count -gt 0) { $found += $a.K }
}
,$found
'@

function Get-DebloatScript([string[]]$Keys) {
    $sb = New-Object System.Text.StringBuilder
    $pk = @()
    foreach ($k in $Keys) { $pk += ($script:DebloatApps | Where-Object { $_.K -eq $k }).P }
    [void]$sb.AppendLine('$ok = 0; $names = @(' + (($pk | ForEach-Object { "'$_'" }) -join ', ') + ')')
    [void]$sb.AppendLine("Write-Host '@@STEP $((T 'debloatStepApps') -replace "'", "''")'")
    [void]$sb.AppendLine('$prov = @(); try { $prov = @(Get-AppxProvisionedPackage -Online -ErrorAction Stop) } catch {}')
    [void]$sb.AppendLine('for ($i = 0; $i -lt $names.Count; $i++) {')
    [void]$sb.AppendLine('    $n = $names[$i]')
    [void]$sb.AppendLine('    foreach ($p in @(Get-AppxPackage -AllUsers -Name $n -ErrorAction SilentlyContinue)) {')
    [void]$sb.AppendLine('        try { Remove-AppxPackage -Package $p.PackageFullName -AllUsers -ErrorAction Stop; $ok++ }')
    [void]$sb.AppendLine('        catch { try { Remove-AppxPackage -Package $p.PackageFullName -ErrorAction Stop; $ok++ } catch { Write-Host "ATTENZIONE: $n - $($_.Exception.Message)" } }')
    [void]$sb.AppendLine('    }')
    # Tolte anche dall'immagine: non tornano per i nuovi utenti.
    [void]$sb.AppendLine('    foreach ($pp in @($prov | Where-Object { $_.DisplayName -eq $n })) { try { Remove-AppxProvisionedPackage -Online -PackageName $pp.PackageName -ErrorAction Stop | Out-Null } catch {} }')
    [void]$sb.AppendLine('    Write-Host ("@@PCT " + [int](90 * ($i + 1) / [Math]::Max(1, $names.Count)))')
    [void]$sb.AppendLine('}')
    if ($Keys -contains 'onedrive') {
        # Disinstallazione ufficiale di OneDrive; la cartella con i file resta.
        [void]$sb.AppendLine("Write-Host '@@STEP OneDrive'")
        [void]$sb.AppendLine('Get-Process OneDrive -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue')
        [void]$sb.AppendLine('$u = (Get-ItemProperty "HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall\OneDriveSetup.exe" -ErrorAction SilentlyContinue).UninstallString')
        [void]$sb.AppendLine('if ($u) { Start-Process cmd.exe "/c `"$u`"" -Wait -WindowStyle Hidden; $ok++ }')
        [void]$sb.AppendLine('else { foreach ($s in "$env:SystemRoot\System32\OneDriveSetup.exe", "$env:SystemRoot\SysWOW64\OneDriveSetup.exe") { if (Test-Path $s) { Start-Process $s "/uninstall" -Wait; $ok++; break } } }')
    }
    [void]$sb.AppendLine("Write-Host '@@PCT 100'")
    [void]$sb.AppendLine("Write-Host ('@@DONE ' + ('$((T 'debloatDone') -replace "'", "''")' -f `$ok))")
    [void]$sb.AppendLine('exit 0')
    return $sb.ToString()
}

function Start-DebloatScan {
    if ($script:DebloatJob -or $null -eq $script:DebloatList) { return }
    $script:DebloatList.Children.Clear(); $script:DebloatBoxes = @{}
    $script:DebloatStatus.Text = T 'debloatSearching'
    Update-DebloatButton
    $ps = [powershell]::Create()
    [void]$ps.AddScript($script:DebloatScanScript).AddArgument($script:DebloatApps)
    $script:DebloatJob = @{ Ps = $ps; H = $ps.BeginInvoke() }
    $t = New-Object System.Windows.Threading.DispatcherTimer
    $t.Interval = [TimeSpan]::FromMilliseconds(250)
    $t.Add_Tick({
        if (-not $script:DebloatJob.H.IsCompleted) { return }
        $this.Stop()
        try { $found = @($script:DebloatJob.Ps.EndInvoke($script:DebloatJob.H) | ForEach-Object { $_ }) } catch { $found = @() }
        $script:DebloatJob.Ps.Dispose(); $script:DebloatJob = $null
        $script:DebloatStatus.Text = if ($found.Count -eq 0) { T 'debloatNone' } else { (T 'debloatFound') -f $found.Count }
        foreach ($a in $script:DebloatApps) {
            if ($found -notcontains $a.K) { continue }
            $cb = New-Object System.Windows.Controls.CheckBox
            $cb.Tag = 'tool'; $cb.IsChecked = $a.On
            $cb.Add_Checked({ Update-DebloatButton }); $cb.Add_Unchecked({ Update-DebloatButton })
            $tb = New-Object System.Windows.Controls.TextBlock; $tb.Text = (T "debloat_$($a.K)"); $tb.Foreground = New-AppBrush '#FFE6E8EB'; $tb.FontSize = 12.5; $tb.TextWrapping = 'Wrap'
            $script:DebloatBoxes[$a.K] = $cb
            $row = New-SwitchRow $tb '' $cb; $row.Margin = '0,0,0,1'
            [void]$script:DebloatList.Children.Add($row)
        }
        Update-DebloatButton
    })
    $t.Start()
}

function Update-DebloatButton {
    if ($null -eq $script:DebloatRunBtn) { return }
    $n = @($script:DebloatBoxes.Values | Where-Object { $_.IsChecked -eq $true }).Count
    $script:DebloatRunBtn.IsEnabled = ($n -gt 0)
    $script:DebloatRunBtn.Content = if ($n -gt 0) { "$(T 'debloatRun') ($n)" } else { T 'debloatRun' }
}

function Invoke-Debloat {
    $keys = @($script:DebloatBoxes.Keys | Where-Object { $script:DebloatBoxes[$_].IsChecked -eq $true })
    if ($keys.Count -eq 0) { return }
    if (-not (Show-Dialog (T 'ttlDebloat') ((T 'debloatAsk') -f $keys.Count) 'warn')) { return }
    $script:DebloatRescan = $true
    Add-ToolJob (T 'ttlDebloat') (Get-DebloatScript $keys)
}

# ------------------------------------------------------------------------------
# Programmi all'avvio
# ------------------------------------------------------------------------------
# Stesso metodo di Gestione attivita': lo stato sta nelle chiavi StartupApproved
# (primo byte 2 = acceso, 3 = spento). Niente si cancella: si riaccende quando
# si vuole, anche da Gestione attivita'.
$script:StartupSources = @(
    @{ Run = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run';             App = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run';           All = $false }
    @{ Run = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run';             App = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run';           All = $true }
    @{ Run = 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Run'; App = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\Run32';         All = $true }
    @{ Dir = "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup";      App = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\StartupFolder'; All = $false }
    @{ Dir = "$env:ProgramData\Microsoft\Windows\Start Menu\Programs\StartUp";  App = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\StartupApproved\StartupFolder'; All = $true }
)

function Get-StartupEntries {
    $list = @()
    foreach ($s in $script:StartupSources) {
        $names = @()
        if ($s.Run) {
            $k = Get-Item -LiteralPath $s.Run -ErrorAction SilentlyContinue
            if ($k) { foreach ($v in $k.GetValueNames()) { if ($v) { $names += @{ N = $v; Cmd = [string]$k.GetValue($v) } } } }
        } else {
            foreach ($f in @(Get-ChildItem -LiteralPath $s.Dir -File -ErrorAction SilentlyContinue | Where-Object { $_.Name -ne 'desktop.ini' })) { $names += @{ N = $f.Name; Cmd = $f.FullName } }
        }
        foreach ($n in $names) {
            $raw = (Get-ItemProperty -LiteralPath $s.App -Name $n.N -ErrorAction SilentlyContinue).($n.N)
            $on = -not ($raw -is [byte[]] -and $raw.Length -gt 0 -and ($raw[0] -band 1) -eq 1)
            $list += @{ Name = $n.N; Cmd = $n.Cmd; App = $s.App; All = $s.All; On = $on }
        }
    }
    return @($list | Sort-Object { $_.Name })
}

function Set-StartupEntry($e, [bool]$On) {
    try {
        if (-not (Test-Path -LiteralPath $e.App)) { New-Item -Path $e.App -Force | Out-Null }
        $b = New-Object byte[] 12
        if ($On) { $b[0] = 2 } else {
            $b[0] = 3
            [BitConverter]::GetBytes([DateTime]::UtcNow.ToFileTimeUtc()).CopyTo($b, 4)
        }
        New-ItemProperty -LiteralPath $e.App -Name $e.Name -PropertyType Binary -Value $b -Force | Out-Null
        Write-Log "[OK] Avvio automatico: $($e.Name) $(if ($On) { 'acceso' } else { 'spento' })"
    } catch { Write-Log "[ERRORE] Avvio automatico $($e.Name) - $($_.Exception.Message)" }
}

function Update-StartupStatus {
    $e = @($script:StartupEntries)
    $script:StartupStatus.Text = if ($e.Count -eq 0) { T 'startupNone' } else { (T 'startupCount') -f @($e | Where-Object { $_.On }).Count, $e.Count }
}

function Show-StartupList {
    if ($null -eq $script:StartupList) { return }
    $script:StartupBuilding = $true
    $script:StartupList.Children.Clear()
    $entries = Get-StartupEntries
    $script:StartupEntries = $entries
    Update-StartupStatus
    foreach ($e in $entries) {
        $cb = New-Object System.Windows.Controls.CheckBox
        $cb.Tag = $e; $cb.IsChecked = $e.On
        $handler = { if (-not $script:StartupBuilding) { Set-StartupEntry $this.Tag ($this.IsChecked -eq $true); $this.Tag.On = ($this.IsChecked -eq $true); Update-StartupStatus } }
        $cb.Add_Checked($handler); $cb.Add_Unchecked($handler)
        $tb = New-Object System.Windows.Controls.TextBlock; $tb.TextWrapping = 'Wrap'
        $r1 = New-Object System.Windows.Documents.Run $e.Name; $r1.Foreground = New-AppBrush '#FFE6E8EB'; $r1.FontSize = 12.5
        $r2 = New-Object System.Windows.Documents.Run ("   " + $(if ($e.All) { T 'startupAll' } else { T 'startupUser' })); $r2.Foreground = New-AppBrush '#FF7F858D'; $r2.FontSize = 11.5
        [void]$tb.Inlines.Add($r1); [void]$tb.Inlines.Add($r2)
        $cmd = [string]$e.Cmd; if ($cmd.Length -gt 90) { $cmd = $cmd.Substring(0, 87) + '...' }
        $row = New-SwitchRow $tb $cmd $cb; $row.Margin = '0,0,0,3'
        [void]$script:StartupList.Children.Add($row)
    }
    $script:StartupBuilding = $false
}

# Rimozione con pnputil (Windows 10 2004 e successivi), una voce alla volta.
function Get-GhostRemoveScript([string[]]$Ids) {
    $sb = New-Object System.Text.StringBuilder
    [void]$sb.AppendLine('$ok = 0; $ids = @(')
    foreach ($id in $Ids) { [void]$sb.AppendLine("    '$($id -replace "'", "''")'") }
    [void]$sb.AppendLine(')')
    [void]$sb.AppendLine("Write-Host '@@STEP $((T 'ttlGhost') -replace "'", "''")'")
    [void]$sb.AppendLine('for ($i = 0; $i -lt $ids.Count; $i++) {')
    [void]$sb.AppendLine('    & pnputil.exe /remove-device $ids[$i] | Out-Null')
    [void]$sb.AppendLine('    if ($LASTEXITCODE -eq 0 -or $LASTEXITCODE -eq 3010) { $ok++ }')
    [void]$sb.AppendLine('    Write-Host ("@@PCT " + [int](100 * ($i + 1) / $ids.Count))')
    [void]$sb.AppendLine('}')
    [void]$sb.AppendLine("Write-Host ('@@DONE ' + ('$((T 'ghostDone') -replace "'", "''")' -f `$ok, `$ids.Count))")
    [void]$sb.AppendLine('if ($ok -eq 0) { exit 1 }')
    [void]$sb.AppendLine('exit 0')
    return $sb.ToString()
}

function Invoke-GhostRemove {
    $ids = @($script:GhostBoxes | Where-Object { $_.IsChecked -eq $true } | ForEach-Object { [string]$_.Tag })
    if ($ids.Count -eq 0) { return }
    if ([Environment]::OSVersion.Version.Build -lt 19041) { Show-Dialog (T 'ttlGhost') (T 'ghostOld') 'warn' | Out-Null; return }
    if (-not (Show-Dialog (T 'ttlGhost') ((T 'ghostAsk') -f $ids.Count) 'ask')) { return }
    $script:GhostRescan = $true
    Add-ToolJob (T 'ttlGhost') (Get-GhostRemoveScript $ids)
}

function Show-ToolsPageIfNeeded {
    if ($script:ToolsBuiltLang -eq $script:LangCode) { return }
    $script:ToolsBuiltLang = $script:LangCode
    Show-ToolsPage
    Start-ToolScan
    Start-GhostScan
    Start-DebloatScan
    Show-StartupList
}

# ------------------------------------------------------------------------------
# Profili di Windows Update (pagina Avanzate)
# ------------------------------------------------------------------------------
$panWuProfiles = E 'panWuProfiles'; $txtWuCurrent = E 'txtWuCurrent'
$script:WuProfileChoice = ''
$script:WuTaskPaths = @('\Microsoft\Windows\InstallService\', '\Microsoft\Windows\UpdateOrchestrator\', '\Microsoft\Windows\UpdateAssistant\',
                       '\Microsoft\Windows\WaaSMedic\', '\Microsoft\Windows\WindowsUpdate\', '\Microsoft\WindowsUpdate\')

function Set-WuTasks([bool]$Enable) {
    $n = 0
    foreach ($p in $script:WuTaskPaths) {
        foreach ($t in @(Get-ScheduledTask -TaskPath $p -ErrorAction SilentlyContinue)) {
            try {
                if ($Enable) { Enable-ScheduledTask -InputObject $t -ErrorAction Stop | Out-Null } else { Disable-ScheduledTask -InputObject $t -ErrorAction Stop | Out-Null }
                $n++
            } catch {}
        }
    }
    Write-Log "[OK] Attivita' di Windows Update $(if ($Enable) { 'riattivate' } else { 'disattivate' }): $n."
}

function Set-WuProfile([string]$Which) {
    $wu = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate'; $au = "$wu\AU"
    $ds = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DriverSearching'
    $md = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Device Metadata'
    $ux = 'HKLM:\SOFTWARE\Microsoft\WindowsUpdate\UX\Settings'
    $do = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\DeliveryOptimization\Config'
    switch ($Which) {
        'recommended' {
            Remove-Reg $au 'NoAutoUpdate' 'Aggiornamenti automatici'
            Remove-Reg $do 'DODownloadMode' 'Ottimizzazione recapito'
            Set-Svc 'BITS' 'Manual' 'BITS' | Out-Null; Set-Svc 'wuauserv' 'Manual' 'Windows Update' | Out-Null
            Set-Svc 'UsoSvc' 'Automatic' 'Orchestratore aggiornamenti' | Out-Null
            Start-Service UsoSvc -ErrorAction SilentlyContinue
            Set-WuTasks $true
            Set-Reg $md 'PreventDeviceMetadataFromNetwork' 1 'DWord' 'Metadati dei dispositivi'
            Set-Reg $ds 'DontPromptForWindowsUpdate' 1 'DWord' 'Driver: niente richiesta'
            Set-Reg $ds 'DontSearchWindowsUpdate' 1 'DWord' 'Driver: niente ricerca'
            Set-Reg $ds 'DriverUpdateWizardWuSearchEnabled' 0 'DWord' 'Driver: procedura guidata'
            Set-Reg $wu 'ExcludeWUDriversInQualityUpdate' 1 'DWord' 'Driver esclusi dagli aggiornamenti'
            Set-Reg $wu 'DeferFeatureUpdates' 1 'DWord' 'Rinvio nuove versioni'
            Set-Reg $wu 'DeferFeatureUpdatesPeriodInDays' 365 'DWord' 'Nuove versioni: 365 giorni'
            Set-Reg $wu 'DeferQualityUpdates' 1 'DWord' 'Rinvio aggiornamenti qualitativi'
            Set-Reg $wu 'DeferQualityUpdatesPeriodInDays' 4 'DWord' 'Aggiornamenti qualitativi: 4 giorni'
            foreach ($v in 'BranchReadinessLevel', 'DeferFeatureUpdatesPeriodInDays', 'DeferQualityUpdatesPeriodInDays') { Remove-Reg $ux $v $v }
            Set-Reg $au 'AUOptions' 4 'DWord' 'Installazione pianificata'
            Set-Reg $au 'NoAutoRebootWithLoggedOnUsers' 1 'DWord' 'Niente riavvii con utenti collegati'
            Set-Reg $au 'AUPowerManagement' 0 'DWord' 'Niente risveglio per aggiornare'
        }
        'disable' {
            Set-Reg $au 'NoAutoUpdate' 1 'DWord' 'Aggiornamenti automatici spenti'
            Set-Reg $au 'AUOptions' 1 'DWord' 'Aggiornamenti: mai'
            Set-Reg $do 'DODownloadMode' 0 'DWord' 'Ottimizzazione recapito: solo HTTP'
            foreach ($s in 'BITS', 'wuauserv', 'UsoSvc') {
                Stop-Service -Name $s -Force -ErrorAction SilentlyContinue
                Set-Svc $s 'Disabled' $s | Out-Null
            }
            Remove-Item "$env:SystemRoot\SoftwareDistribution\*" -Recurse -Force -ErrorAction SilentlyContinue
            Write-Log "[OK] Aggiornamenti gia' scaricati eliminati."
            Set-WuTasks $false
            Write-Log "[AVVISO] Windows Update e' spento: niente aggiornamenti di sicurezza finche' non scegli un altro profilo."
        }
        default {
            foreach ($v in 'NoAutoUpdate', 'AUOptions', 'NoAutoRebootWithLoggedOnUsers', 'AUPowerManagement') { Remove-Reg $au $v $v }
            foreach ($v in 'ExcludeWUDriversInQualityUpdate', 'DeferFeatureUpdates', 'DeferFeatureUpdatesPeriodInDays', 'DeferQualityUpdates', 'DeferQualityUpdatesPeriodInDays') { Remove-Reg $wu $v $v }
            foreach ($v in 'BranchReadinessLevel', 'DeferFeatureUpdatesPeriodInDays', 'DeferQualityUpdatesPeriodInDays') { Remove-Reg $ux $v $v }
            Remove-Reg $md 'PreventDeviceMetadataFromNetwork' 'Metadati dei dispositivi'
            foreach ($v in 'DontPromptForWindowsUpdate', 'DontSearchWindowsUpdate', 'DriverUpdateWizardWuSearchEnabled') { Remove-Reg $ds $v $v }
            Remove-Reg $do 'DODownloadMode' 'Ottimizzazione recapito'
            Set-Svc 'BITS' 'Manual' 'BITS' | Out-Null; Set-Svc 'wuauserv' 'Manual' 'Windows Update' | Out-Null
            Set-Svc 'UsoSvc' 'Automatic' 'Orchestratore aggiornamenti' | Out-Null
            Start-Service UsoSvc -ErrorAction SilentlyContinue
            Set-WuTasks $true
        }
    }
    Write-Log "[INFO] Profilo di Windows Update applicato: $Which. Riavvia il PC per completarlo."
}

function Get-WuProfileNow {
    $au = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU'
    $wu = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate'
    if (Test-Reg $au 'NoAutoUpdate' 1) { return 'disable' }
    if ((Test-Reg $wu 'DeferFeatureUpdatesPeriodInDays' 365) -and (Test-Reg $wu 'DeferQualityUpdatesPeriodInDays' 4) -and (Test-Reg $au 'NoAutoRebootWithLoggedOnUsers' 1)) { return 'recommended' }
    if ((Test-Path $wu) -and @((Get-Item $wu -ErrorAction SilentlyContinue).Property).Count -gt 0) { return 'custom' }
    return 'default'
}

function Show-WuProfiles {
    $panWuProfiles.Children.Clear()
    foreach ($p in @('recommended', 'default', 'disable')) {
        $rb = New-Object System.Windows.Controls.RadioButton
        $rb.Style = $window.FindResource('ProfileCard'); $rb.GroupName = 'WuProfile'; $rb.Tag = $p
        $sp = New-Object System.Windows.Controls.StackPanel
        $t = New-Object System.Windows.Controls.TextBlock
        $t.Text = T "wu_$p"; $t.FontSize = 14; $t.FontWeight = 'Bold'; $t.FontFamily = 'Segoe UI Variable Display, Segoe UI'
        $t.Foreground = New-AppBrush $(if ($p -eq 'disable') { '#FFF87171' } else { '#FFEDEFF2' })
        $s = New-Object System.Windows.Controls.TextBlock
        $s.Text = T "wuSub_$p"; $s.FontSize = 11.5; $s.Margin = '0,2,0,6'
        $s.Foreground = New-AppBrush $(if ($p -eq 'disable') { '#FFF87171' } else { '#FF9DA3AB' })
        [void]$sp.Children.Add($t); [void]$sp.Children.Add($s)
        foreach ($line in ((T "wuList_$p") -split ';')) {
            $l = New-Object System.Windows.Controls.TextBlock
            $l.Text = "·  $line"; $l.FontSize = 11.5; $l.Foreground = New-AppBrush '#FFC5C9CF'; $l.TextWrapping = 'Wrap'; $l.Margin = '0,1,0,0'
            [void]$sp.Children.Add($l)
        }
        $rb.Content = $sp
        $rb.IsChecked = ($script:WuProfileChoice -eq $p)
        $rb.Add_PreviewMouseLeftButtonDown({
            if ($this.IsChecked -eq $true) {
                $this.IsChecked = $false; $script:WuProfileChoice = ''; $chkWuProfile.IsChecked = $false; $_.Handled = $true
            }
        })
        $rb.Add_Checked({ $script:WuProfileChoice = [string]$this.Tag; $chkWuProfile.IsChecked = $true })
        [void]$panWuProfiles.Children.Add($rb)
    }
    $txtWuCurrent.Text = (T 'currentSetting') -f (T "wu_$(Get-WuProfileNow)")
}

# ------------------------------------------------------------------------------
# Stato attuale delle voci: etichetta «Attivo»
# ------------------------------------------------------------------------------
# Le azioni di «Applica» sono scritte come chiamate a Set-Reg, Set-Svc e simili
# con valori fissi. Se ne legge la struttura (senza eseguirle) e si confronta
# ogni valore con quello presente sul sistema: una voce e' attiva quando tutti
# coincidono. Le voci con passaggi che non si possono verificare restano senza
# etichetta, invece di mostrarne una sbagliata.
$script:ProbeSafe = @('Write-Log', 'Test-Gpu', 'Out-Null', 'Test-Path', 'Join-Path', 'Stop-Process', 'Get-Process', 'Stop-Service')

function Resolve-ProbeArg($ast, $vars) {
    if ($ast -is [System.Management.Automation.Language.ExpandableStringExpressionAst]) {
        $s = $ast.Value
        foreach ($n in $ast.NestedExpressions) {
            if ($n -isnot [System.Management.Automation.Language.VariableExpressionAst]) { return ,[System.DBNull]::Value }
            $k = $n.VariablePath.UserPath
            if (-not $vars.ContainsKey($k)) { return ,[System.DBNull]::Value }
            $s = $s.Replace($n.Extent.Text, [string]$vars[$k])
        }
        return ,$s
    }
    if ($ast -is [System.Management.Automation.Language.ArrayExpressionAst]) {
        $st = $ast.SubExpression.Statements
        if ($st.Count -ne 1 -or $st[0] -isnot [System.Management.Automation.Language.PipelineAst] -or $st[0].PipelineElements.Count -ne 1 -or
            $st[0].PipelineElements[0] -isnot [System.Management.Automation.Language.CommandExpressionAst]) { return ,[System.DBNull]::Value }
        $inner = Resolve-ProbeArg $st[0].PipelineElements[0].Expression $vars
        if ($inner -is [System.DBNull]) { return ,[System.DBNull]::Value }
        return ,@($inner)
    }
    if ($ast -is [System.Management.Automation.Language.ArrayLiteralAst]) {
        $o = @()
        foreach ($e in $ast.Elements) { $v = Resolve-ProbeArg $e $vars; if ($v -is [System.DBNull] -or $v -is [array]) { return ,[System.DBNull]::Value }; $o += $v }
        return ,$o
    }
    if ($ast -is [System.Management.Automation.Language.StringConstantExpressionAst]) { return ,$ast.Value }
    if ($ast -is [System.Management.Automation.Language.ConstantExpressionAst]) { return ,$ast.Value }
    if ($ast -is [System.Management.Automation.Language.VariableExpressionAst]) {
        $n = $ast.VariablePath.UserPath
        if ($vars.ContainsKey($n)) { return ,$vars[$n] }
        return ,[System.DBNull]::Value
    }
    return ,[System.DBNull]::Value
}

function Get-ProbeList($statements, $vars) {
    $probes = New-Object System.Collections.ArrayList
    foreach ($st in $statements) {
        if ($st -is [System.Management.Automation.Language.AssignmentStatementAst]) {
            $left = $st.Left
            $right = $st.Right
            if ($left -is [System.Management.Automation.Language.VariableExpressionAst] -and $right -is [System.Management.Automation.Language.CommandExpressionAst]) {
                $v = Resolve-ProbeArg $right.Expression $vars
                if ($v -isnot [System.DBNull]) { $vars[$left.VariablePath.UserPath] = $v; continue }
            }
            return $null
        }
        if ($st -is [System.Management.Automation.Language.ForEachStatementAst]) {
            $cond = $st.Condition
            $vals = @()
            $expr = if ($cond -is [System.Management.Automation.Language.PipelineAst] -and $cond.PipelineElements.Count -eq 1 -and $cond.PipelineElements[0] -is [System.Management.Automation.Language.CommandExpressionAst]) { $cond.PipelineElements[0].Expression } else { $null }
            if ($expr -is [System.Management.Automation.Language.ArrayExpressionAst]) { $expr = $expr.SubExpression.Statements[0].PipelineElements[0].Expression }
            if ($expr -is [System.Management.Automation.Language.ArrayLiteralAst]) {
                foreach ($e in $expr.Elements) { $v = Resolve-ProbeArg $e $vars; if ($v -is [System.DBNull]) { return $null }; $vals += ,$v }
            } else { return $null }
            foreach ($v in $vals) {
                $vv = $vars.Clone(); $vv[$st.Variable.VariablePath.UserPath] = $v
                $inner = Get-ProbeList $st.Body.Statements $vv
                if ($null -eq $inner) { return $null }
                foreach ($p in $inner) { [void]$probes.Add($p) }
            }
            continue
        }
        if ($st -is [System.Management.Automation.Language.IfStatementAst]) {
            # Le condizioni servono solo a saltare le schede di un'altra marca.
            foreach ($clause in $st.Clauses) {
                $inner = Get-ProbeList $clause.Item2.Statements $vars
                if ($null -eq $inner) { return $null }
                foreach ($p in $inner) { [void]$probes.Add($p) }
            }
            continue
        }
        if ($st -is [System.Management.Automation.Language.ReturnStatementAst]) { continue }
        if ($st -is [System.Management.Automation.Language.TryStatementAst]) {
            $inner = Get-ProbeList $st.Body.Statements $vars
            if ($null -eq $inner) { return $null }
            foreach ($p in $inner) { [void]$probes.Add($p) }
            continue
        }
        if ($st -isnot [System.Management.Automation.Language.PipelineAst]) { return $null }
        foreach ($el in $st.PipelineElements) {
            if ($el -isnot [System.Management.Automation.Language.CommandAst]) { return $null }
            $name = $el.GetCommandName()
            $args = @($el.CommandElements | Select-Object -Skip 1 | Where-Object { $_ -isnot [System.Management.Automation.Language.CommandParameterAst] })
            $a = @($args | ForEach-Object { Resolve-ProbeArg $_ $vars })
            switch ($name) {
                'Set-Reg'            { if ($a.Count -lt 3 -or @($a[0..2] | Where-Object { $_ -is [System.DBNull] }).Count) { return $null }; [void]$probes.Add(@{ T = 'reg'; A = $a }) }
                'Set-Svc'            { if ($a.Count -lt 2 -or @($a[0..1] | Where-Object { $_ -is [System.DBNull] }).Count) { return $null }; [void]$probes.Add(@{ T = 'svc'; A = $a }) }
                'Set-PowerAc'        { if ($a.Count -lt 3 -or @($a[0..2] | Where-Object { $_ -is [System.DBNull] }).Count) { return $null }; [void]$probes.Add(@{ T = 'pwr'; A = $a }) }
                'Set-GpuClassValue'  { if ($a.Count -lt 4 -or @($a | Where-Object { $_ -is [System.DBNull] }).Count) { return $null }; [void]$probes.Add(@{ T = 'gpu'; A = $a }) }
                'Set-AmdUmdValue'    { if ($a.Count -lt 2 -or @($a[0..1] | Where-Object { $_ -is [System.DBNull] }).Count) { return $null }; [void]$probes.Add(@{ T = 'umd'; A = $a }) }
                'Set-NvProfile'      { if ($a.Count -lt 1 -or $a[0] -is [System.DBNull]) { return $null }; [void]$probes.Add(@{ T = 'nv'; A = $a }) }
                'Set-IntelFeatureBit'{ if ($a.Count -lt 1 -or $a[0] -is [System.DBNull]) { return $null }; [void]$probes.Add(@{ T = 'bit'; A = $a }) }
                'Disable-Tasks'      { if ($a.Count -lt 1 -or $a[0] -is [System.DBNull]) { return $null }; [void]$probes.Add(@{ T = 'task'; A = @(,@($a[0])) }) }
                'Remove-Reg'         { if ($a.Count -lt 2 -or @($a[0..1] | Where-Object { $_ -is [System.DBNull] }).Count) { return $null }; [void]$probes.Add(@{ T = 'noreg'; A = $a }) }
                'Set-Bcd'            { if ($a.Count -lt 1 -or $a[0] -is [System.DBNull]) { return $null }; [void]$probes.Add(@{ T = 'bcd'; A = $a }) }
                default              { if ($script:ProbeSafe -notcontains $name) { return $null } }
            }
        }
    }
    return ,$probes
}

function Get-ProbePlans {
    $plans = @{}
    $ast = (Get-Command Build-Actions).ScriptBlock.Ast
    $calls = $ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.CommandAst] -and $n.GetCommandName() -eq 'Add-IfChecked' }, $true)
    foreach ($c in $calls) {
        $el = $c.CommandElements
        if ($el.Count -lt 3 -or $el[1] -isnot [System.Management.Automation.Language.VariableExpressionAst] -or $el[2] -isnot [System.Management.Automation.Language.ScriptBlockExpressionAst]) { continue }
        $name = $el[1].VariablePath.UserPath
        $body = $el[2].ScriptBlock.EndBlock
        if ($null -eq $body) { continue }
        $list = Get-ProbeList $body.Statements @{}
        if ($null -ne $list -and $list.Count -gt 0) { $plans[$name] = $list }
    }
    return $plans
}

# $true = coincide, $false = diverso, $null = non verificabile qui (scheda assente).
function Test-Probe($p) {
    $a = $p.A
    switch ($p.T) {
        'reg' { return (Test-Reg $a[0] $a[1] $a[2]) }
        'svc' {
            $s = Get-Service -Name $a[0] -ErrorAction SilentlyContinue
            if ($null -eq $s) { return $null }
            return ([string]$s.StartType -eq [string]$a[1])
        }
        'pwr' {
            $scheme = Get-ActiveSchemeGuid
            if ($null -eq $scheme) { return $null }
            $s = [guid]$a[0]; $g = [guid]$a[1]; $v = [uint32]0
            if ([TweakAndrew.PowerApi]::PowerReadACValueIndex([IntPtr]::Zero, [ref]$scheme, [ref]$s, [ref]$g, [ref]$v) -ne 0) { return $null }
            return ([uint32]$v -eq [uint32]$a[2])
        }
        'gpu' {
            $keys = @(Get-GpuClassKeys $a[3]); if ($keys.Count -eq 0) { return $null }
            foreach ($k in $keys) { if (-not (Test-Reg $k.PSPath $a[0] $a[1])) { return $false } }
            return $true
        }
        'umd' {
            $keys = @(Get-GpuClassKeys 'AMD'); if ($keys.Count -eq 0) { return $null }
            $want = [BitConverter]::ToString([Text.Encoding]::Unicode.GetBytes([string]$a[1]))
            foreach ($k in $keys) {
                $v = (Get-ItemProperty -LiteralPath (Join-Path $k.PSPath 'UMD') -Name $a[0] -ErrorAction SilentlyContinue).($a[0])
                if ($null -eq $v -or [BitConverter]::ToString([byte[]]$v) -ne $want) { return $false }
            }
            return $true
        }
        'nv' {
            try { if (-not [TweakAndrew.NvDrs]::Available()) { return $null } } catch { return $null }
            # -1 = impostazione che questo driver non ha: non conta.
            $seen = 0
            foreach ($pair in $script:NvProfileSets[[string]$a[0]]) {
                $v = [TweakAndrew.NvDrs]::Get([uint32]$pair[0])
                if ($v -eq -1) { continue }
                $seen++
                if ($v -ne [long]$pair[1]) { return $false }
            }
            if ($seen -eq 0) { return $null }
            return $true
        }
        'task' {
            $seen = 0
            foreach ($tk in @($a[0])) {
                $task = Get-CatTask ([string]$tk)
                if ($null -eq $task) { continue }
                $seen++
                if ($task.Enabled) { return $false }
            }
            # Nessuna attivita' presente: non c'e' nulla da spegnere, la voce e' a posto.
            return $true
        }
        'noreg' {
            if (-not (Test-Path -LiteralPath $a[0])) { return $true }
            return ($null -eq (Get-ItemProperty -LiteralPath $a[0] -Name $a[1] -ErrorAction SilentlyContinue))
        }
        'bcd' {
            if ($null -eq $script:BcdText) {
                $script:BcdText = @(& "$env:SystemRoot\System32\bcdedit.exe" /enum '{current}' 2>$null) + @('---bootmgr---') + @(& "$env:SystemRoot\System32\bcdedit.exe" /enum '{bootmgr}' 2>$null)
            }
            $split = [array]::IndexOf($script:BcdText, '---bootmgr---')
            if ($split -le 0) { return $null }
            if ([string]$a[0] -match '^/timeout\s+(\d+)$') {
                $want = $Matches[1]
                $line = $script:BcdText[($split + 1)..($script:BcdText.Count - 1)] | Where-Object { $_ -match '^timeout\s+(\d+)' } | Select-Object -First 1
                if (-not $line) { return $null }
                return (($line -replace '^timeout\s+', '').Trim() -eq $want)
            }
            if ([string]$a[0] -notmatch '^/set\s+(?:\{\w+\}\s+)?(\S+)\s+(\S+)$') { return $null }
            $key = $Matches[1]; $want = $Matches[2]
            $line = $script:BcdText[0..($split - 1)] | Where-Object { $_ -match ('^' + [regex]::Escape($key) + '\s+') } | Select-Object -First 1
            # Una voce assente vale «no»: e' il comportamento predefinito.
            if (-not $line) { return ($want -eq 'no') }
            return ((($line -replace '^\S+\s+', '').Trim()) -eq $want)
        }
        'bit' {
            $keys = @(Get-GpuClassKeys 'Intel'); if ($keys.Count -eq 0) { return $null }
            foreach ($k in $keys) {
                $v = (Get-ItemProperty -LiteralPath $k.PSPath -Name FeatureTestControl -ErrorAction SilentlyContinue).FeatureTestControl
                if ($null -eq $v) { return $false }
                $on = (([int64]$v -band 0xFFFFFFFFL) -band [int64]$a[0]) -ne 0
                if ($on -ne [bool]$a[1]) { return $false }
            }
            return $true
        }
    }
    return $null
}

# Voci con controlli scritti a mano, dove le azioni non bastano a capirlo.
function Get-ExplicitActive {
    return @{
        chkHibernation = (-not (Test-Path -LiteralPath "$env:SystemDrive\hiberfil.sys"))
        chkClassicMenu = (Test-Path 'HKCU:\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\InprocServer32')
        chkWuProfile   = $null
        chkMenuSleep     = (Get-ShutdownMenuState).Sleep
        chkMenuHibernate = (Get-ShutdownMenuState).Hibernate
        chkNtfsPerf      = $(
            $fs = 'HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem'
            $la = Get-RegOrNull $fs 'NtfsDisableLastAccessUpdate'
            ($null -ne $la) -and (([int64]$la -band 1) -eq 1) -and ((Get-RegOrNull $fs 'NtfsMemoryUsage') -eq 2))
        # Attiva solo se la soglia supera la RAM: sotto, Windows divide comunque i servizi.
        chkRamTweak      = $(
            $v = Get-RegOrNull 'HKLM:\SYSTEM\CurrentControlSet\Control' 'SvcHostSplitThresholdInKB'
            $ramKb = [int64]((Get-CimInstance Win32_ComputerSystem -ErrorAction SilentlyContinue).TotalPhysicalMemory / 1KB)
            ($null -ne $v) -and $ramKb -gt 0 -and ([int64]$v -ge $ramKb))
        chkMitigations   = $(try {
            $m = Get-ProcessMitigation -System -ErrorAction Stop
            ([string]$m.CFG.Enable -eq 'OFF') -and ([string]$m.ASLR.BottomUp -eq 'OFF') -and ([string]$m.ASLR.HighEntropy -eq 'OFF') -and ([string]$m.SEHOP.Enable -eq 'OFF')
        } catch { $null })
        chkTeredo        = $(try { [bool](@(& netsh.exe interface teredo show state 2>$null) -match ':\s*disabled\s*$') } catch { $null })
        chkRemove3D      = (-not (Test-Path -LiteralPath 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\MyComputer\NameSpace\{0DB7E03F-FC29-4DC6-9020-FF41B59E513A}') -and
                            -not (Test-Path -LiteralPath 'HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Explorer\MyComputer\NameSpace\{0DB7E03F-FC29-4DC6-9020-FF41B59E513A}'))
        chkNetPowerSave  = $(
            $keys = @(Get-ChildItem 'HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4D36E972-E325-11CE-BFC1-08002BE10318}' -ErrorAction SilentlyContinue | Where-Object { $_.PSChildName -match '^\d{4}$' })
            if ($keys.Count -eq 0) { $null } else { @($keys | Where-Object { $_.GetValue('PnPCapabilities') -ne 24 }).Count -eq 0 })
        chkGpuMsi        = $(try {
            $gpus = @(Get-CimInstance Win32_VideoController -ErrorAction Stop | Where-Object { $_.PNPDeviceID -and $_.PNPDeviceID -notmatch '^ROOT\\' })
            if ($gpus.Count -eq 0) { $null } else {
                @($gpus | Where-Object { (Get-RegOrNull "HKLM:\SYSTEM\CurrentControlSet\Enum\$($_.PNPDeviceID)\Device Parameters\Interrupt Management\MessageSignaledInterruptProperties" 'MSISupported') -ne 1 }).Count -eq 0 }
        } catch { $null })
        chkNvLatency     = $(
            $keys = @(Get-GpuClassKeys 'NVIDIA')
            if ($keys.Count -eq 0 -or $null -eq $script:NvLatencyValues) { $null } else {
                $bad = 0
                foreach ($k in $keys) { foreach ($n in $script:NvLatencyValues.Keys) { if (-not (Test-Reg $k.PSPath $n $script:NvLatencyValues[$n])) { $bad++ } } }
                $bad -eq 0 })
        chkTrim          = $(try {
            $o = (@(& fsutil.exe behavior query DisableDeleteNotify 2>$null) -join ' ')
            if ($o -match 'NTFS\s+DisableDeleteNotify\s*=\s*(\d)') { $Matches[1] -eq '0' } else { $null }
        } catch { $null })
        chkReservedStorage = ((Get-RegOrNull 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\ReserveManager' 'ShippedWithReserves') -eq 0)
        chkMemCompression = (Test-MemCompressionOff)
        chkSecSpectre    = (Test-MitigationBits 3)
        chkSecDownfall   = (Test-MitigationBits 0x2000000)
    }
}

# Porta gli interruttori allo stato del sistema. Con -All tutti (avvio e dopo
# Applica); senza, solo quelli che l'utente non ha ancora cambiato.
function Sync-ChecksToSystem([hashtable]$Before = @{}, [switch]$All) {
    $script:Syncing = $true
    try {
        foreach ($cb in $script:AllCheckBoxes) {
            $n = [string]$cb.Name
            $now = $script:Baseline[$n]
            if ($null -eq $now) { if ($All) { $cb.IsChecked = $false }; continue }
            if ($All -or (($cb.IsChecked -eq $true) -eq ($Before[$n] -eq $true))) { $cb.IsChecked = [bool]$now }
        }
    } finally { $script:Syncing = $false }
    if ($script:SectionPicks) { foreach ($s in $script:SectionPicks) { Update-SectionPick $s } }
    Update-ApplyButton
}

# La compressione la gestisce SysMain: con il servizio disattivato e' spenta
# e Get-MMAgent non risponde.
function Test-MemCompressionOff {
    try {
        if ((Get-Service -Name SysMain -ErrorAction Stop).StartType -eq 'Disabled') { return $true }
        return (-not (Get-MMAgent -ErrorAction Stop).MemoryCompression)
    } catch { return $null }
}

function Update-ActiveBadges {
    $script:BcdText = $null
    if ($null -eq $script:ProbePlans) { $script:ProbePlans = Get-ProbePlans }
    $script:BaselineBefore = $script:Baseline.Clone()
    $explicit = Get-ExplicitActive
    $n = 0
    foreach ($cb in $script:AllCheckBoxes) {
        $name = [string]$cb.Name
        $state = $null
        if ($explicit.ContainsKey($name)) { $state = $explicit[$name] }
        elseif ($script:ProbePlans.ContainsKey($name)) {
            $seen = 0; $state = $true
            foreach ($p in $script:ProbePlans[$name]) {
                $r = Test-Probe $p
                if ($null -eq $r) { continue }
                $seen++
                if (-not $r) { $state = $false; break }
            }
            if ($seen -eq 0) { $state = $null }
        }
        [System.Windows.Automation.AutomationProperties]::SetHelpText($cb, $(if ($state -eq $true) { 'active' } else { '' }))
        if ($null -eq $state) { $script:Baseline.Remove($name) } else { $script:Baseline[$name] = [bool]$state }
        if ($state -eq $true) { $n++ }
    }
    Update-CurrentValues
    return $n
}

# Impostazioni a scelta multipla: si mostra quella in uso.
$txtMpoCurrent = E 'txtMpoCurrent'; $btnMpoStar = E 'btnMpoStar'
function Update-CurrentValues {
    $v = $null
    try { $v = (Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows\DWM' -Name OverlayTestMode -ErrorAction Stop).OverlayTestMode } catch {}
    $idx = switch ($v) { 5 { 1 } 2 { 2 } default { 0 } }
    $txtMpoCurrent.Text = (T 'currentSetting') -f ([string]$cmbMPO.Items[$idx].Content)
    $btnMpoStar.Tag = if ($idx -eq 1) { 'match' } else { $null }
    if ($txtWuCurrent) { $txtWuCurrent.Text = (T 'currentSetting') -f (T "wu_$(Get-WuProfileNow)") }
}

$btnMpoStar.Add_Click({
    $cmbMPO.SelectedIndex = 1
    $chkApplyMPO.IsChecked = $true
})

# ------------------------------------------------------------------------------
# Consiglio su ogni voce: la coccarda dice il valore consigliato (acceso o
# spento) ed e' piena quando la voce e' gia' li'. Il clic porta la voce al
# consiglio senza applicarla: per quello c'e' «Applica modifiche».
# ------------------------------------------------------------------------------
# Interruttori di ambito e manutenzioni: non sono impostazioni da consigliare.
$script:NoRecChecks = @('chkRestorePoint', 'chkStorageProfile', 'chkWuProfile', 'chkApplyDns',
                        'chkApplyMPO', 'chkDiskCleanup', 'chkSmartChkdsk',
                        # Personalizzazione (pagina Avanzate): gusti, non ottimizzazioni.
                        'chkTaskbarCenter', 'chkTaskbarSearch', 'chkTaskbarTaskView', 'chkTaskbarWidgets', 'chkTaskbarChat',
                        'chkTaskbarEndTask', 'chkBatteryPct', 'chkSettingsHome', 'chkWindowSnapping',
                        'chkStartMorePins', 'chkStartHideRec', 'chkStartNoWeb', 'chkStartNoAccount', 'chkMenuSleep', 'chkMenuHibernate')
function Update-RecStars {
    $server = (Get-PcType) -eq 'server'
    $names = @($script:RecommendedChecks.Values | ForEach-Object { $_ })
    if (Test-SystemSsd) { $names += $script:SsdRecommended; if (Test-RamAtLeast16) { $names += 'chkMemCompression' } }
    foreach ($cb in $script:AllCheckBoxes) {
        $show = $cb.IsEnabled -and ($script:NoRecChecks -notcontains [string]$cb.Name) -and (Test-CheckVendor $cb)
        # Su un server le voci escluse restano senza consiglio: «Consigliati» non le
        # tocca in nessun verso, perche' i valori di Windows Server sono diversi.
        if ($server -and $script:ServerSkip -contains [string]$cb.Name) { $show = $false }
        $on = ($names -contains [string]$cb.Name) -and (Test-CheckPcType $cb)
        [System.Windows.Automation.AutomationProperties]::SetItemStatus($cb, $(if (-not $show) { '' } elseif ($on) { 'rec' } else { 'recoff' }))
        if (-not $show) { continue }
        [void]$cb.ApplyTemplate()
        $hit = $cb.Template.FindName('starHit', $cb)
        if ($null -eq $hit) { continue }
        $hit.ToolTip = (T 'recTip') -f (T $(if ($on) { 'recOn' } else { 'recOff' }))
        if ($cb.Resources.Contains('starHooked')) { continue }
        $cb.Resources['starHooked'] = $true
        $hit.Add_PreviewMouseLeftButtonDown({
            $p = $this.TemplatedParent
            $p.IsChecked = ([System.Windows.Automation.AutomationProperties]::GetItemStatus($p) -eq 'rec')
            $_.Handled = $true
        })
    }
    $btnMpoStar.ToolTip = (T 'recTip') -f ([string]$cmbMPO.Items[1].Content)
}

$btnDetectActive.Add_Click({
    Set-Activity 'scan' (T 'scanRunning') -1
    $n = Update-ActiveBadges
    Sync-ChecksToSystem $script:BaselineBefore
    Clear-Activity 'scan'
    $txtProgressLabel.Text = (T 'scanDone') -f $n
    Write-Log "[INFO] Rilevamento completato: $n voci gia' attive."
})

# Appena la finestra e' disegnata parte il rilevamento delle voci gia' attive.
$window.Add_ContentRendered({
    [void]$window.Dispatcher.BeginInvoke([Action]{
        $n = Update-ActiveBadges
        Sync-ChecksToSystem -All
        Reset-TcpToSystem
        $txtProgressLabel.Text = (T 'scanDone') -f $n
        Write-Log "[INFO] Voci gia' attive su questo PC: $n."
    }, [System.Windows.Threading.DispatcherPriority]::ApplicationIdle)
})
