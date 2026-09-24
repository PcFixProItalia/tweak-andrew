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
    foreach ($n in @('barQueue', 'btnDetectActive', 'chkRestorePoint')) {
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
    Set-AppJobView $job (T 'jobWait') 0 '#FF6E6E78'
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
    Set-AppJobView $job (T 'jobPrep') -1 '#FFC4C4CC'
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
    if ($pct -ge 0) { Set-AppJobView $job "$text  ·  $pct%" $pct '#FFE8E8EE'; $job.Frac = $pct / 100 }
    else { Set-AppJobView $job $text -1 '#FFE8E8EE'; $job.Frac = 0.05 }
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
        Set-AppJobView $job $txt 100 $(if ($job.Reboot -or $code -eq 3010) { '#FFFDBA74' } else { '#FF2ED3A7' })
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
})

$btnToolJobsClose.Add_Click({
    if (Test-ToolBusy) { return }
    $script:ToolJobList.Clear(); $panToolJobs.Children.Clear(); $bdToolJobs.Visibility = 'Collapsed'
})

# ------------------------------------------------------------------------------
# Script degli strumenti
# ------------------------------------------------------------------------------
# Pulizia: ogni voce ha le cartelle da svuotare e, se serve, un'azione a parte.
$script:CleanItems = @(
    @{ Key = 'winTemp';   On = $true;  Paths = @('%SystemRoot%\Temp') }
    @{ Key = 'userTemp';  On = $true;  Paths = @('%TEMP%') }
    @{ Key = 'wuCache';   On = $true;  Paths = @('%SystemRoot%\SoftwareDistribution\Download') }
    @{ Key = 'doCache';   On = $true;  Paths = @('%SystemRoot%\ServiceProfiles\NetworkService\AppData\Local\Microsoft\Windows\DeliveryOptimization\Cache') }
    @{ Key = 'recycle';   On = $true;  Paths = @() }
    @{ Key = 'errors';    On = $true;  Paths = @('%ProgramData%\Microsoft\Windows\WER\ReportArchive', '%ProgramData%\Microsoft\Windows\WER\ReportQueue', '%LOCALAPPDATA%\CrashDumps', '%SystemRoot%\Minidump') }
    @{ Key = 'thumbs';    On = $false; Paths = @() }
    @{ Key = 'recent';    On = $false; Paths = @('%APPDATA%\Microsoft\Windows\Recent') }
    @{ Key = 'runHist';   On = $false; Paths = @() }
    @{ Key = 'prefetch';  On = $false; Paths = @('%SystemRoot%\Prefetch') }
)

# Funzioni comuni agli script: cartella svuotata senza toccare la cartella stessa.
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
'@

function Get-CleanScript([string[]]$Keys) {
    $sb = New-Object System.Text.StringBuilder
    [void]$sb.AppendLine($script:ToolHelpers)
    [void]$sb.AppendLine('$freed = 0')
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
                [void]$sb.AppendLine("Start-Service wuauserv -ErrorAction SilentlyContinue")
            }
            'doCache' {
                [void]$sb.AppendLine("try { Delete-DeliveryOptimizationCache -Force -ErrorAction Stop } catch { `$freed += Clear-Dir '$($item.Paths[0])' }")
            }
            'recycle' {
                [void]$sb.AppendLine("foreach (`$d in [IO.DriveInfo]::GetDrives() | Where-Object { `$_.DriveType -eq 'Fixed' -and `$_.IsReady }) { `$freed += Clear-Dir (Join-Path `$d.RootDirectory '`$Recycle.Bin') }")
                [void]$sb.AppendLine("Clear-RecycleBin -Force -ErrorAction SilentlyContinue")
            }
            'thumbs' {
                [void]$sb.AppendLine("Get-ChildItem `"`$env:LOCALAPPDATA\Microsoft\Windows\Explorer`" -Filter 'thumbcache_*.db' -Force -ErrorAction SilentlyContinue | ForEach-Object { try { `$l = `$_.Length; Remove-Item -LiteralPath `$_.FullName -Force -ErrorAction Stop; `$freed += `$l } catch {} }")
            }
            'runHist' {
                [void]$sb.AppendLine("Remove-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\RunMRU' -Name * -ErrorAction SilentlyContinue")
                [void]$sb.AppendLine("Remove-ItemProperty 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\TypedPaths' -Name * -ErrorAction SilentlyContinue")
            }
            default {
                foreach ($p in $item.Paths) { [void]$sb.AppendLine("`$freed += Clear-Dir '$p'") }
            }
        }
    }
    [void]$sb.AppendLine("Write-Host '@@PCT 100'")
    [void]$sb.AppendLine("Write-Host ('@@DONE ' + '$((T 'cleanFreed') -replace "'", "''")' -f (Size-Text `$freed))")
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
function New-ToolCard([string]$Title, [string]$Hint) {
    $card = New-Object System.Windows.Controls.Border
    $card.Style = $window.FindResource('Glass')
    $sp = New-Object System.Windows.Controls.StackPanel
    $h = New-Object System.Windows.Controls.TextBlock
    $h.Text = $Title.ToUpper(); $h.Style = $window.FindResource('CardTitle')
    [void]$sp.Children.Add($h)
    if ($Hint) {
        $s = New-Object System.Windows.Controls.TextBlock
        $s.Text = $Hint; $s.Style = $window.FindResource('SubTitle'); $s.Margin = '0,-4,0,10'
        [void]$sp.Children.Add($s)
    }
    $card.Child = $sp
    return @{ Card = $card; Panel = $sp }
}

function New-ToolButton([string]$Text, [scriptblock]$Click, [string]$Style = 'GhostBtn') {
    $b = New-Object System.Windows.Controls.Button
    $b.Content = $Text; $b.Style = $window.FindResource($Style); $b.Margin = '0,0,8,8'
    $b.Add_Click($Click)
    return $b
}

# Riga di una riparazione: titolo e spiegazione a sinistra, pulsante a destra.
function New-ToolRow([string]$Key, [scriptblock]$Click) {
    $g = New-Object System.Windows.Controls.Grid; $g.Margin = '0,0,0,12'
    $c0 = New-Object System.Windows.Controls.ColumnDefinition
    $c1 = New-Object System.Windows.Controls.ColumnDefinition; $c1.Width = [System.Windows.GridLength]::Auto
    $g.ColumnDefinitions.Add($c0); $g.ColumnDefinitions.Add($c1)
    $sp = New-Object System.Windows.Controls.StackPanel; $sp.VerticalAlignment = 'Center'; $sp.Margin = '0,0,12,0'
    $t = New-Object System.Windows.Controls.TextBlock
    $t.Text = T "tool_$Key"; $t.FontSize = 13; $t.FontWeight = 'SemiBold'; $t.Foreground = New-AppBrush '#FFE8E8EE'; $t.TextWrapping = 'Wrap'
    $d = New-Object System.Windows.Controls.TextBlock
    $d.Text = T "toolDesc_$Key"; $d.Style = $window.FindResource('SubTitle'); $d.Margin = '0,2,0,0'
    [void]$sp.Children.Add($t); [void]$sp.Children.Add($d)
    [void]$g.Children.Add($sp)
    $b = New-Object System.Windows.Controls.Button
    $b.Content = T 'toolRun'; $b.Style = $window.FindResource('DotBtn'); $b.Tag = New-AppBrush '#FF2DD4BF'
    $b.VerticalAlignment = 'Center'; $b.Add_Click($Click)
    [System.Windows.Controls.Grid]::SetColumn($b, 1); [void]$g.Children.Add($b)
    return $g
}

function Confirm-Tool([string]$Key, [string]$Kind = 'ask') {
    return (Show-Dialog (T "tool_$Key") (T "toolAsk_$Key") $Kind)
}

$script:CleanBoxes = @{}
$script:FeatureBoxes = @{}

function Show-ToolsPage {
    $panTools.Children.Clear()
    $grid = New-Object System.Windows.Controls.Grid
    foreach ($i in 0..1) { $cd = New-Object System.Windows.Controls.ColumnDefinition; $cd.Width = New-Object System.Windows.GridLength(1, [System.Windows.GridUnitType]::Star); $grid.ColumnDefinitions.Add($cd) }
    $left = New-Object System.Windows.Controls.StackPanel; $right = New-Object System.Windows.Controls.StackPanel
    [System.Windows.Controls.Grid]::SetColumn($right, 1)
    [void]$grid.Children.Add($left); [void]$grid.Children.Add($right)

    # Pulizia
    $c = New-ToolCard (T 'ttlClean') (T 'cleanHint')
    $script:CleanBoxes = @{}
    foreach ($it in $script:CleanItems) {
        $cb = New-Object System.Windows.Controls.CheckBox
        $cb.Tag = 'tool'; $cb.IsChecked = $it.On
        $cb.Content = T "clean_$($it.Key)"
        $cb.ToolTip = T "cleanTip_$($it.Key)"
        $script:CleanBoxes[$it.Key] = $cb
        [void]$c.Panel.Children.Add($cb)
    }
    $wp = New-Object System.Windows.Controls.WrapPanel; $wp.Margin = '0,10,0,0'
    [void]$wp.Children.Add((New-ToolButton (T 'cleanScan') { Start-ToolScan }))
    [void]$wp.Children.Add((New-ToolButton (T 'cleanRun') {
        $keys = @($script:CleanItems | Where-Object { $script:CleanBoxes[$_.Key].IsChecked -eq $true } | ForEach-Object { $_.Key })
        if ($keys.Count -eq 0) { return }
        if (-not (Show-Dialog (T 'ttlClean') ((T 'cleanAsk') -f $keys.Count) 'warn')) { return }
        $script:ToolsNeedRefresh = $true
        Add-ToolJob (T 'ttlClean') (Get-CleanScript $keys)
    } 'PrimaryBtn'))
    [void]$c.Panel.Children.Add($wp)
    [void]$left.Children.Add($c.Card)

    # Riparazioni
    $c = New-ToolCard (T 'ttlFix') (T 'fixHint')
    [void]$c.Panel.Children.Add((New-ToolRow 'netQuick' { if (Confirm-Tool 'netQuick') { Add-ToolJob (T 'tool_netQuick') $script:ToolScripts.netQuick } }))
    [void]$c.Panel.Children.Add((New-ToolRow 'netFull' { if (Confirm-Tool 'netFull' 'warn') { Add-ToolJob (T 'tool_netFull') $script:ToolScripts.netFull -Reboot } }))
    [void]$c.Panel.Children.Add((New-ToolRow 'firewall' { if (Confirm-Tool 'firewall' 'danger') { Add-ToolJob (T 'tool_firewall') $script:ToolScripts.firewall } }))
    [void]$c.Panel.Children.Add((New-ToolRow 'wuReset' { if (Confirm-Tool 'wuReset' 'warn') { Add-ToolJob (T 'tool_wuReset') $script:ToolScripts.wuReset -Reboot } }))
    [void]$c.Panel.Children.Add((New-ToolRow 'repair' { if (Confirm-Tool 'repair') { Add-ToolJob (T 'tool_repair') $script:ToolScripts.repair } }))
    [void]$c.Panel.Children.Add((New-ToolRow 'ntp' { Add-ToolJob (T 'tool_ntp') $script:ToolScripts.ntp }))
    [void]$c.Panel.Children.Add((New-ToolRow 'winget' { Add-ToolJob (T 'tool_winget') $script:ToolScripts.winget }))
    [void]$c.Panel.Children.Add((New-ToolRow 'regBackup' { Add-ToolJob (T 'tool_regBackup') $script:ToolScripts.regBackup }))
    [void]$c.Panel.Children.Add((New-ToolRow 'store' {
        Start-Process "$env:SystemRoot\System32\wsreset.exe" -ErrorAction SilentlyContinue
        Write-Log "[OK] Cache del Microsoft Store: wsreset avviato."
    }))
    [void]$c.Panel.Children.Add((New-ToolRow 'explorer' {
        Stop-Process -Name explorer -Force -ErrorAction SilentlyContinue
        Write-Log "[OK] Esplora risorse riavviato."
    }))
    [void]$c.Panel.Children.Add((New-ToolRow 'icons' {
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
    [void]$left.Children.Add($c.Card)

    # Funzionalita' di Windows
    $c = New-ToolCard (T 'ttlFeatures') (T 'featHint')
    $script:FeatureBoxes = @{}
    foreach ($f in $script:Features) {
        $cb = New-Object System.Windows.Controls.CheckBox
        $cb.Tag = 'tool'; $cb.Content = T "feat_$($f.Key)"; $cb.ToolTip = T "featTip_$($f.Key)"
        $script:FeatureBoxes[$f.Key] = $cb
        [void]$c.Panel.Children.Add($cb)
    }
    $wp = New-Object System.Windows.Controls.WrapPanel; $wp.Margin = '0,10,0,0'
    [void]$wp.Children.Add((New-ToolButton (T 'featRun') {
        $keys = @($script:Features | Where-Object { $script:FeatureBoxes[$_.Key].IsChecked -eq $true -and $script:FeatureBoxes[$_.Key].IsEnabled } | ForEach-Object { $_.Key })
        if ($keys.Count -eq 0) { return }
        if (-not (Show-Dialog (T 'ttlFeatures') ((T 'featAsk') -f $keys.Count) 'ask')) { return }
        foreach ($k in $keys) { $script:FeatureBoxes[$k].IsChecked = $false }
        $script:ToolsNeedRefresh = $true
        Add-ToolJob (T 'ttlFeatures') (Get-FeatureScript $keys) -Reboot
    } 'PrimaryBtn'))
    [void]$c.Panel.Children.Add($wp)
    [void]$right.Children.Add($c.Card)

    # Pannelli di Windows
    $c = New-ToolCard (T 'ttlPanels') (T 'panelsHint')
    $ug = New-Object System.Windows.Controls.Primitives.UniformGrid; $ug.Columns = 2
    foreach ($p in $script:Panels) {
        $b = New-Object System.Windows.Controls.Button
        $b.Content = T "panel_$($p.Key)"; $b.Style = $window.FindResource('GhostBtn'); $b.Margin = '0,0,8,8'; $b.Tag = $p.Cmd
        $b.Add_Click({ try { Start-Process ([string]$this.Tag) } catch { Write-Log "[ERRORE] $($this.Content): $($_.Exception.Message)" } })
        [void]$ug.Children.Add($b)
    }
    [void]$c.Panel.Children.Add($ug)
    [void]$right.Children.Add($c.Card)

    [void]$panTools.Children.Add($grid)
}

# Spazio occupato dalle voci di pulizia e stato delle funzionalita': letture
# lente, in un runspace. Il risultato torna sulle caselle.
$script:ToolScanScript = @'
param($items, $features)
$out = @{ Sizes = @{}; Features = @{} }
foreach ($it in $items) {
    $sum = 0
    foreach ($p in $it.Paths) {
        $x = [Environment]::ExpandEnvironmentVariables($p)
        if (Test-Path -LiteralPath $x) { $sum += (Get-ChildItem -LiteralPath $x -Force -Recurse -File -ErrorAction SilentlyContinue | Measure-Object Length -Sum).Sum }
    }
    if ($it.Key -eq 'recycle') {
        foreach ($d in [IO.DriveInfo]::GetDrives() | Where-Object { $_.DriveType -eq 'Fixed' -and $_.IsReady }) {
            $r = Join-Path $d.RootDirectory '$Recycle.Bin'
            if (Test-Path -LiteralPath $r) { $sum += (Get-ChildItem -LiteralPath $r -Force -Recurse -File -ErrorAction SilentlyContinue | Measure-Object Length -Sum).Sum }
        }
    }
    if ($it.Key -eq 'thumbs') {
        $sum += (Get-ChildItem "$env:LOCALAPPDATA\Microsoft\Windows\Explorer" -Filter 'thumbcache_*.db' -Force -ErrorAction SilentlyContinue | Measure-Object Length -Sum).Sum
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
    [void]$ps.AddScript($script:ToolScanScript).AddArgument($script:CleanItems).AddArgument($script:Features)
    $script:ToolScanJob = @{ Ps = $ps; H = $ps.BeginInvoke() }
    foreach ($k in $script:CleanBoxes.Keys) { $script:CleanBoxes[$k].Content = "$(T "clean_$k")  ·  $(T 'cleanMeasuring')" }
    $t = New-Object System.Windows.Threading.DispatcherTimer
    $t.Interval = [TimeSpan]::FromMilliseconds(250)
    $t.Add_Tick({
        if (-not $script:ToolScanJob.H.IsCompleted) { return }
        $this.Stop()
        try { $r = @($script:ToolScanJob.Ps.EndInvoke($script:ToolScanJob.H)) | Where-Object { $_ -is [hashtable] } | Select-Object -First 1 } catch { $r = $null }
        $script:ToolScanJob.Ps.Dispose(); $script:ToolScanJob = $null
        if ($null -eq $r) { return }
        foreach ($k in $script:CleanBoxes.Keys) {
            $b = [double]$r.Sizes[$k]
            $sz = if ($k -eq 'runHist') { '' } elseif ($b -ge 1GB) { '{0:0.0} GB' -f ($b / 1GB) } else { '{0:0} MB' -f ($b / 1MB) }
            $script:CleanBoxes[$k].Content = if ($sz) { "$(T "clean_$k")  ·  $sz" } else { T "clean_$k" }
        }
        foreach ($k in $script:FeatureBoxes.Keys) {
            $cb = $script:FeatureBoxes[$k]; $st = [string]$r.Features[$k]
            [System.Windows.Automation.AutomationProperties]::SetHelpText($cb, $(if ($st -eq 'on') { 'active' } else { '' }))
            $cb.IsEnabled = ($st -eq 'off')
            [System.Windows.Controls.ToolTipService]::SetShowOnDisabled($cb, $true)
            if ($st -eq 'missing') { $cb.ToolTip = T 'featMissing' }
        }
    })
    $t.Start()
}

function Show-ToolsPageIfNeeded {
    if ($script:ToolsBuiltLang -eq $script:LangCode) { return }
    $script:ToolsBuiltLang = $script:LangCode
    Show-ToolsPage
    Start-ToolScan
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
        $t.Text = T "wu_$p"; $t.FontSize = 14; $t.FontWeight = 'Bold'; $t.FontFamily = 'Raleway, Segoe UI'
        $t.Foreground = New-AppBrush $(if ($p -eq 'disable') { '#FFF87171' } else { '#FFF2F2F5' })
        $s = New-Object System.Windows.Controls.TextBlock
        $s.Text = T "wuSub_$p"; $s.FontSize = 11.5; $s.Margin = '0,2,0,6'
        $s.Foreground = New-AppBrush $(if ($p -eq 'disable') { '#FFF87171' } else { '#FFA1A1AA' })
        [void]$sp.Children.Add($t); [void]$sp.Children.Add($s)
        foreach ($line in ((T "wuList_$p") -split ';')) {
            $l = New-Object System.Windows.Controls.TextBlock
            $l.Text = "·  $line"; $l.FontSize = 11.5; $l.Foreground = New-AppBrush '#FFC4C4CC'; $l.TextWrapping = 'Wrap'; $l.Margin = '0,1,0,0'
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
$script:ProbeSafe = @('Write-Log', 'Test-Gpu', 'Out-Null', 'Test-Path', 'Join-Path', 'Stop-Process')

function Resolve-ProbeArg($ast, $vars) {
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
            foreach ($pair in $script:NvProfileSets[[string]$a[0]]) {
                if ([TweakAndrew.NvDrs]::Get([uint32]$pair[0]) -ne [long]$pair[1]) { return $false }
            }
            return $true
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
    }
}

function Update-ActiveBadges {
    if ($null -eq $script:ProbePlans) { $script:ProbePlans = Get-ProbePlans }
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
$script:NoRecChecks = @('chkRestorePoint', 'chkStorageProfile', 'chkWuProfile', 'chkApplyNetwork', 'chkApplyDns',
                        'chkApplyMPO', 'chkDiskCleanup', 'chkSmartChkdsk')
function Update-RecStars {
    $names = @($script:RecommendedChecks.Values | ForEach-Object { $_ })
    foreach ($cb in $script:AllCheckBoxes) {
        $show = $cb.IsEnabled -and ($script:NoRecChecks -notcontains [string]$cb.Name) -and (Test-CheckVendor $cb)
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
    Clear-Activity 'scan'
    $txtProgressLabel.Text = (T 'scanDone') -f $n
    Write-Log "[INFO] Rilevamento completato: $n voci gia' attive."
})

# Appena la finestra e' disegnata parte il rilevamento delle voci gia' attive.
$window.Add_ContentRendered({
    [void]$window.Dispatcher.BeginInvoke([Action]{
        $n = Update-ActiveBadges
        $txtProgressLabel.Text = (T 'scanDone') -f $n
        Write-Log "[INFO] Voci gia' attive su questo PC: $n."
    }, [System.Windows.Threading.DispatcherPriority]::ApplicationIdle)
})
