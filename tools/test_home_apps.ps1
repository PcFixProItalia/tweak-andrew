# Prova la Home e la pagina delle app: aspetta le letture in background, fa gli
# screenshot e simula un'operazione con «winget download», che scarica
# l'installatore in una cartella temporanea senza installare nulla.
param([string]$ShotDir = "$env:TEMP\TweakAndrewShots", [string]$Lang = 'it', [string]$DownloadId = 'VideoLAN.VLC')
$root = Split-Path $PSScriptRoot -Parent
New-Item -ItemType Directory -Force $ShotDir | Out-Null
$text = [IO.File]::ReadAllText((Join-Path $root 'Tweak_Andrew.ps1'), [Text.Encoding]::UTF8)
$t = $text -replace '(?s)if \(-not \$principal\.IsInRole.*?\r?\n    Exit\r?\n\}', '# test'
$harness = @'
function Pump([int]$ms) {
    $until = [DateTime]::Now.AddMilliseconds($ms)
    while ([DateTime]::Now -lt $until) { [System.Windows.Threading.Dispatcher]::CurrentDispatcher.Invoke([Action]{}, [System.Windows.Threading.DispatcherPriority]::ApplicationIdle); [Threading.Thread]::Sleep(15) }
}
function Save-Shot([string]$name) {
    $window.UpdateLayout(); Pump 50
    $r = $window.Content
    $rtb = New-Object System.Windows.Media.Imaging.RenderTargetBitmap([int]$r.ActualWidth, [int]$r.ActualHeight, 96, 96, [System.Windows.Media.PixelFormats]::Pbgra32)
    $rtb.Render($r); $enc = New-Object System.Windows.Media.Imaging.PngBitmapEncoder
    $enc.Frames.Add([System.Windows.Media.Imaging.BitmapFrame]::Create($rtb))
    $fs = [System.IO.File]::Create("__DIR__\$name.png"); $enc.Save($fs); $fs.Close()
}
$window.Add_ContentRendered({
    $script:UiReady = $true
    if ('__LANG__' -ne 'it') { foreach ($i in $cmbLang.Items) { if ([string]$i.Tag -eq '__LANG__') { $cmbLang.SelectedItem = $i } } }
    $sw = [Diagnostics.Stopwatch]::StartNew()
    while (-not $script:HomeInfo -and $sw.ElapsedMilliseconds -lt 30000) { Pump 100 }
    Write-Host ("Home letta in " + $sw.ElapsedMilliseconds + " ms, tipo rilevato: " + $script:HomeInfo.PcType + ", in uso: " + (Get-PcType))
    Write-Host ("  CPU: " + $script:HomeInfo.Cpu.Count + "  GPU: " + $script:HomeInfo.Gpu.Count + "  dischi: " + $script:HomeInfo.Disks.Count + "  reti: " + $script:HomeInfo.Net.Count + "  batteria: " + $script:HomeInfo.HasBattery)
    Pump 300
    Save-Shot "__LANG__-home"
    Click $btnSelectAll
    $sel = @($script:AllCheckBoxes | Where-Object { $_.IsChecked -eq $true } | ForEach-Object { $_.Name })
    Write-Host ("Seleziona tutto: " + $sel.Count + " voci; da portatile saltate: " + (@($script:LaptopSkip | Where-Object { $sel -contains $_ }) -join ',') + " | percentuale batteria: " + ($sel -contains 'chkBatteryPct'))
    Click $btnDeselectAll

    (E 'tabNet').IsChecked = $true; Pump 400
    Write-Host ("Rete: " + $radTcpCurrent.Content)

    (E 'tabApps').IsChecked = $true
    $sw.Restart()
    while ((-not $script:AppScanDone -or $null -ne $script:AppExport) -and $sw.ElapsedMilliseconds -lt 30000) { Pump 200 }
    Write-Host ("scan fatto=" + $script:AppScanDone + " scan=" + ($null -ne $script:AppScan) + " export=" + ($null -ne $script:AppExport) + " timer=" + $script:AppTimer.IsEnabled)
    Write-Host ("App: id winget " + $script:AppInstalledIds.Count + ", aggiornamenti " + $script:AppUpdates.Count + ", programmi " + $script:AppInstalledList.Count + " (" + $sw.ElapsedMilliseconds + " ms)")
    foreach ($u in $script:AppUpdates.Values) { Write-Host ("  " + $u.Id + "  " + $u.Version + " -> " + $u.Available + "  [" + $u.Name + "]") }
    $inst = @($script:AppCatalog | Where-Object { Test-AppInstalled $_ } | ForEach-Object { $_.Name })
    Write-Host ("Catalogo gia' installate: " + $inst.Count + " - " + ($inst -join ', '))
    Pump 300
    Save-Shot "__LANG__-apps-catalog"
    $radAppsInstalled.IsChecked = $true; Pump 400
    foreach ($u in @($script:AppUpdates.Values | Select-Object -First 2)) { [void]$script:AppSel.Add("u:$($u.Id)") }
    Show-AppView; Pump 300
    Write-Host ("Pulsante aggiornamento: " + $btnAppsUpgrade.Content + " abilitato=" + $btnAppsUpgrade.IsEnabled)
    Save-Shot "__LANG__-apps-installed"
    $script:AppSel.Clear(); Show-AppView

    # Operazione finta: solo download, nessuna installazione.
    $dir = Join-Path $env:TEMP 'TweakAndrew_dltest'
    Remove-Item $dir -Recurse -Force -ErrorAction SilentlyContinue
    Add-AppJob 'install' '__ID__' $script:Winget "download --id __ID__ -e -d `"$dir`" --accept-package-agreements --accept-source-agreements --disable-interactivity" $true
    Add-AppJob 'uninstall' 'Prova in coda' 'cmd.exe' '/c ping -n 3 127.0.0.1 >nul' $false
    Start-AppBatch
    $sw.Restart(); $shots = 0; $seen = @{}
    while ((Test-AppBusy -or $script:AppBatch) -and $sw.ElapsedMilliseconds -lt 180000) {
        Pump 200
        $st = [string]$script:AppJobList[0].StateText.Text
        $key = ($st -replace '\d', '#')
        if (-not $seen.ContainsKey($key)) { $seen[$key] = $true; Write-Host ("  stato: " + $st) }
        if ($st -match '%' -and $shots -eq 0) { Save-Shot "__LANG__-apps-job-download"; $shots++ }
        if ($script:AppJobList[1].StateText.Text -eq (T 'jobUninstall') -and $shots -eq 1) { Save-Shot "__LANG__-apps-job-second"; $shots++ }
    }
    Pump 500
    Write-Host ("Fine: " + $txtAppsStatus.Text + " | " + (($script:AppJobList | ForEach-Object { $_.StateText.Text }) -join ' / '))
    Save-Shot "__LANG__-apps-job-done"
    Remove-Item $dir -Recurse -Force -ErrorAction SilentlyContinue
    $window.Close()
})
function Click($b) { $b.RaiseEvent((New-Object System.Windows.RoutedEventArgs ([System.Windows.Controls.Primitives.ButtonBase]::ClickEvent))) }
[void]$window.ShowDialog()
'@
$harness = $harness.Replace('__DIR__', $ShotDir).Replace('__LANG__', $Lang).Replace('__ID__', $DownloadId)
$t = $t.Replace('[void]$window.ShowDialog()', $harness)
$tf = Join-Path $env:TEMP 'TweakAndrew_homeapps.ps1'
[IO.File]::WriteAllText($tf, $t, (New-Object Text.UTF8Encoding $true))
& powershell.exe -NoProfile -STA -ExecutionPolicy Bypass -File $tf
