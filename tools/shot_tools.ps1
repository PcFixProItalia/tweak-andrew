# Apre la pagina Strumenti, aspetta i calcoli e la disegna tutta in un'immagine.
param([string]$Out = "$env:TEMP\TweakAndrewShots\tools-full.png", [string]$Lang = 'it')
$root = Split-Path $PSScriptRoot -Parent
$text = [IO.File]::ReadAllText((Join-Path $root 'Tweak_Andrew.ps1'), [Text.Encoding]::UTF8)
$t = $text -replace '(?s)if \(-not \$principal\.IsInRole.*?\r?\n    Exit\r?\n\}', '# test'
$harness = @'
$script:ShotOut = '__OUT__'
$script:ShotTicks = 0
$script:ShotTimer = New-Object System.Windows.Threading.DispatcherTimer
$script:ShotTimer.Interval = [TimeSpan]::FromMilliseconds(500)
$script:ShotTimer.Add_Tick({
    $script:ShotTicks++
    if ($script:ShotTicks -eq 1) { Set-Language '__LANG__'; (E 'tabTools').IsChecked = $true; return }
    if (($script:ToolScanJob -or $script:GhostJob) -and $script:ShotTicks -lt 120) { return }
    $script:ShotTimer.Stop()
    $panTools.UpdateLayout()
    $w = [int]$panTools.ActualWidth; $h = [int]$panTools.ActualHeight
    $rtb = New-Object System.Windows.Media.Imaging.RenderTargetBitmap($w, $h, 96, 96, [System.Windows.Media.PixelFormats]::Pbgra32)
    $rtb.Render($panTools)
    $enc = New-Object System.Windows.Media.Imaging.PngBitmapEncoder
    $enc.Frames.Add([System.Windows.Media.Imaging.BitmapFrame]::Create($rtb))
    $fs = [IO.File]::Create($script:ShotOut); $enc.Save($fs); $fs.Close()
    Write-Host "salvata $w x $h dopo $($script:ShotTicks) giri"
    foreach ($k in $script:CleanSizes.Keys) { Write-Host ("  {0} = {1:N0} MB" -f $k, ($script:CleanSizes[$k] / 1MB)) }
    Write-Host ("  dispositivi: " + $script:GhostStatus.Text)
    $window.Close()
})
$window.Add_ContentRendered({ $script:ShotTimer.Start() })
[void]$window.ShowDialog()
'@
$t = $t.Replace('[void]$window.ShowDialog()', $harness.Replace('__OUT__', $Out).Replace('__LANG__', $Lang))
$tf = Join-Path $env:TEMP 'TweakAndrew_tools.ps1'
[IO.File]::WriteAllText($tf, $t, (New-Object Text.UTF8Encoding $true))
& powershell.exe -NoProfile -STA -ExecutionPolicy Bypass -File $tf
