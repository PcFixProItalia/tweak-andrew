# Disegna tutta la Home (anche la parte da scorrere) in un'immagine.
param([string]$Out = "$env:TEMP\TweakAndrewShots\home-full.png")
$root = Split-Path $PSScriptRoot -Parent
$text = [IO.File]::ReadAllText((Join-Path $root 'Tweak_Andrew.ps1'), [Text.Encoding]::UTF8)
$t = $text -replace '(?s)if \(-not \$principal\.IsInRole.*?\r?\n    Exit\r?\n\}', '# test'
$harness = @'
$script:ShotOut = '__OUT__'
$script:ShotTimer = New-Object System.Windows.Threading.DispatcherTimer
$script:ShotTimer.Interval = [TimeSpan]::FromMilliseconds(400)
$script:ShotTimer.Add_Tick({
    if (-not $script:HomeInfo) { return }
    $script:ShotTimer.Stop()
    $panHome.UpdateLayout()
    $w = [int]$panHome.ActualWidth; $h = [int]$panHome.ActualHeight
    $rtb = New-Object System.Windows.Media.Imaging.RenderTargetBitmap($w, $h, 96, 96, [System.Windows.Media.PixelFormats]::Pbgra32)
    $bg = New-Object System.Windows.Shapes.Rectangle
    $rtb.Render($panHome)
    $enc = New-Object System.Windows.Media.Imaging.PngBitmapEncoder
    $enc.Frames.Add([System.Windows.Media.Imaging.BitmapFrame]::Create($rtb))
    $fs = [IO.File]::Create($script:ShotOut); $enc.Save($fs); $fs.Close()
    Write-Host "salvata $w x $h"
    $window.Close()
})
$window.Add_ContentRendered({ $script:ShotTimer.Start() })
[void]$window.ShowDialog()
'@
$t = $t.Replace('[void]$window.ShowDialog()', $harness.Replace('__OUT__', $Out))
$tf = Join-Path $env:TEMP 'TweakAndrew_home.ps1'
[IO.File]::WriteAllText($tf, $t, (New-Object Text.UTF8Encoding $true))
& powershell.exe -NoProfile -STA -ExecutionPolicy Bypass -File $tf
