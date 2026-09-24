# Prova strumenti, blocco delle pagine e indicatore delle operazioni con
# operazioni finte: nessuna modifica al sistema.
param([string]$ShotDir = "$env:TEMP\TweakAndrewShots")
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
    Pump 1500
    Write-Host ("Piani di rilevamento: " + $script:ProbePlans.Count + " voci verificabili")
    $act = @($script:AllCheckBoxes | Where-Object { [System.Windows.Automation.AutomationProperties]::GetHelpText($_) -eq 'active' }).Count
    $rec = @($script:AllCheckBoxes | Where-Object { [System.Windows.Automation.AutomationProperties]::GetItemStatus($_) -eq 'rec' }).Count
    Write-Host ("Etichette Attivo: $act, stelline: $rec")
    # stellina: seleziona senza togliere
    $cb = $script:AllCheckBoxes | Where-Object { [System.Windows.Automation.AutomationProperties]::GetItemStatus($_) -eq 'rec' } | Select-Object -First 1
    $hit = $cb.Template.FindName('starHit', $cb)
    $ev = New-Object System.Windows.Input.MouseButtonEventArgs([System.Windows.Input.Mouse]::PrimaryDevice, 0, [System.Windows.Input.MouseButton]::Left)
    $ev.RoutedEvent = [System.Windows.UIElement]::PreviewMouseLeftButtonDownEvent
    $hit.RaiseEvent($ev); $a1 = $cb.IsChecked
    $ev2 = New-Object System.Windows.Input.MouseButtonEventArgs([System.Windows.Input.Mouse]::PrimaryDevice, 0, [System.Windows.Input.MouseButton]::Left)
    $ev2.RoutedEvent = [System.Windows.UIElement]::PreviewMouseLeftButtonDownEvent
    $hit.RaiseEvent($ev2)
    Write-Host ("Stellina su $($cb.Name): primo clic=$a1, secondo clic=$($cb.IsChecked)")
    $cb.IsChecked = $false
    # MPO
    Write-Host ("MPO: " + $txtMpoCurrent.Text)
    $btnMpoStar.RaiseEvent((New-Object System.Windows.RoutedEventArgs ([System.Windows.Controls.Primitives.ButtonBase]::ClickEvent)))
    Write-Host ("  stellina MPO: indice=" + $cmbMPO.SelectedIndex + " coda=" + $chkApplyMPO.IsChecked)
    $chkApplyMPO.IsChecked = $false
    # Windows Update
    Write-Host ("WU: " + $txtWuCurrent.Text + " | profili: " + $panWuProfiles.Children.Count)
    $panWuProfiles.Children[0].IsChecked = $true
    Write-Host ("  scelto: " + $script:WuProfileChoice + " coda=" + $chkWuProfile.IsChecked)
    $panWuProfiles.Children[0].IsChecked = $false; $chkWuProfile.IsChecked = $false; $script:WuProfileChoice = ''

    # Strumento finto con avanzamento
    (E 'tabTools').IsChecked = $true; Pump 400
    Add-ToolJob 'Prova strumento' "Write-Host '@@STEP Primo passo'; foreach (`$i in 1..10) { Write-Host ('@@PCT ' + (`$i*10)); Start-Sleep -Milliseconds 300 }; Write-Host '@@DONE Fatto'"
    $sw0 = [Diagnostics.Stopwatch]::StartNew(); while ((Test-ToolBusy) -and $sw0.ElapsedMilliseconds -lt 8000) { Pump 300; if ($script:ToolJob -and $script:ToolJob.Proc) { if ($script:ToolJob.Frac -ge 0.4 -and -not $shotMid) { $shotMid = $true; (E 'tabPerf').IsChecked = $true; Pump 200; Save-Shot 'tools-lock-perf'; (E 'tabTools').IsChecked = $true } } }
    Write-Host ('  stato durante: ' + $script:ToolJob.StateText.Text)
    Write-Host ("Durante lo strumento: Prestazioni abilitata=" + (E 'pagePerf').IsEnabled + ", App abilitata=" + (E 'pageApps').IsEnabled + ", barra=" + (E 'barQueue').IsEnabled)
    Write-Host ("  indicatore: " + $pillActivity.Visibility + " | " + $txtActivity.Text + " " + $txtActivityPct.Text)
    (E 'tabTools').IsChecked = $true
    $sw = [Diagnostics.Stopwatch]::StartNew()
    while ((Test-ToolBusy) -and $sw.ElapsedMilliseconds -lt 20000) { Pump 200 }
    Pump 500
    Write-Host ("Dopo: stato=" + $script:ToolJobList[0].StateText.Text + ", Prestazioni abilitata=" + (E 'pagePerf').IsEnabled + ", indicatore=" + $pillActivity.Visibility)
    Save-Shot 'tools-done'
    # Spazio della pulizia (lettura sola)
    $sw.Restart(); while ($script:ToolScanJob -and $sw.ElapsedMilliseconds -lt 60000) { Pump 300 }
    Write-Host ("Pulizia: " + (($script:CleanItems | ForEach-Object { $script:CleanBoxes[$_.Key].Content }) -join ' | '))
    Write-Host ("Funzionalita': " + (($script:Features | ForEach-Object { "$($_.Key)=" + $script:FeatureBoxes[$_.Key].IsEnabled + '/' + [System.Windows.Automation.AutomationProperties]::GetHelpText($script:FeatureBoxes[$_.Key]) }) -join ' '))
    Save-Shot 'tools-page'

    # Applica finto: coda di due azioni che attendono
    $script:Actions = @(@{ Name = 'Finta 1'; Do = { Start-Sleep -Milliseconds 400 } }, @{ Name = 'Finta 2'; Do = { $script:MidLock = (E 'pagePerf').IsEnabled; $script:MidPill = $txtActivity.Text; Start-Sleep -Milliseconds 400 } })
    Invoke-ActionQueue 'Prova'
    Write-Host ("Applica finto: Prestazioni abilitata durante=" + $script:MidLock + ", indicatore='" + $script:MidPill + "', dopo=" + (E 'pagePerf').IsEnabled)
    $window.Close()
})
[void]$window.ShowDialog()
'@
$harness = $harness.Replace('__DIR__', $ShotDir)
$t = $t.Replace('[void]$window.ShowDialog()', $harness)
$tf = Join-Path $env:TEMP 'TweakAndrew_tools.ps1'
[IO.File]::WriteAllText($tf, $t, (New-Object Text.UTF8Encoding $true))
& powershell.exe -NoProfile -STA -ExecutionPolicy Bypass -File $tf
