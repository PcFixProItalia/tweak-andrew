# Verifiche statiche di Tweak_Andrew.ps1 e giro di tutte le pagine con
# screenshot. Non tocca il sistema: le pagine a interruttore si limitano a
# leggere lo stato.
param([string]$ShotDir = "$env:TEMP\TweakAndrewShots", [string[]]$Pages = @(), [string]$Lang = 'it', [int]$Scale = 0)
Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase
$root = Split-Path $PSScriptRoot -Parent
$file = Join-Path $root 'Tweak_Andrew.ps1'
$text = [System.IO.File]::ReadAllText($file, [System.Text.Encoding]::UTF8)
New-Item -ItemType Directory -Force $ShotDir | Out-Null

$m = [regex]::Match($text, "(?s)\[xml\]\`$xaml = @'\r?\n(.*?)\r?\n'@")
[xml]$xaml = $m.Groups[1].Value
try { $window = [Windows.Markup.XamlReader]::Load((New-Object System.Xml.XmlNodeReader $xaml)); Write-Host "OK: XAML caricato" -ForegroundColor Green }
catch { Write-Host "ERRORE XAML: $($_.Exception.InnerException.Message) $($_.Exception.Message)" -ForegroundColor Red; exit 1 }

$used = [regex]::Matches($text, "E '([A-Za-z0-9_]+)'") | ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique
$missing = @($used | Where-Object { $null -eq $window.FindName($_) })
if ($missing.Count -eq 0) { Write-Host "OK: $($used.Count) controlli richiesti esistono" -ForegroundColor Green } else { Write-Host "MANCANTI: $($missing -join ', ')" -ForegroundColor Red }

$locBlock = [regex]::Match($text, "(?s)\`$script:Loc = @\{(.*?)\r?\n\}")
$locKeys = [regex]::Matches($locBlock.Groups[1].Value, "(?m)^\s{4}([A-Za-z0-9_]+)\s*=") | ForEach-Object { $_.Groups[1].Value }
$locMissing = @($locKeys | Where-Object { $null -eq $window.FindName($_) })
if ($locMissing.Count -eq 0) { Write-Host "OK: $($locKeys.Count) testi hanno un controllo" -ForegroundColor Green } else { Write-Host "TESTI SENZA CONTROLLO: $($locMissing -join ', ')" -ForegroundColor Yellow }

$msgBlock = [regex]::Match($text, "(?s)\`$script:Msg = @\{(.*?)\r?\n\}")
$msgKeys = [regex]::Matches($msgBlock.Groups[1].Value, "(?m)^\s{4}([A-Za-z0-9_]+)\s*=") | ForEach-Object { $_.Groups[1].Value }
$tUsed = [regex]::Matches($text, "T '([A-Za-z0-9_]+)'") | ForEach-Object { $_.Groups[1].Value } | Sort-Object -Unique
$tMissing = @($tUsed | Where-Object { $msgKeys -notcontains $_ })
if ($tMissing.Count -eq 0) { Write-Host "OK: $($tUsed.Count) messaggi esistono" -ForegroundColor Green } else { Write-Host "MESSAGGI MANCANTI: $($tMissing -join ', ')" -ForegroundColor Red }
$window.Close()

# Copia di prova: niente richiesta di amministratore, giro delle pagine e chiusura.
$t = $text -replace '(?s)if \(-not \$principal\.IsInRole.*?\r?\n    Exit\r?\n\}', '# test'
$Pages = @($Pages | ForEach-Object { $_ -split "," } | Where-Object { $_ })
$pagesArg = ($Pages | ForEach-Object { "'$_'" }) -join ','
$harness = @"
function Save-Shot([string]`$name) {
    `$window.UpdateLayout()
    [System.Windows.Threading.Dispatcher]::CurrentDispatcher.Invoke([Action]{}, [System.Windows.Threading.DispatcherPriority]::SystemIdle) | Out-Null
    `$r = `$window.Content; `$s = 1.0
    `$rtb = New-Object System.Windows.Media.Imaging.RenderTargetBitmap([int](`$r.ActualWidth*`$s), [int](`$r.ActualHeight*`$s), 96, 96, [System.Windows.Media.PixelFormats]::Pbgra32)
    `$rtb.Render(`$r); `$enc = New-Object System.Windows.Media.Imaging.PngBitmapEncoder
    `$enc.Frames.Add([System.Windows.Media.Imaging.BitmapFrame]::Create(`$rtb))
    `$fs = [System.IO.File]::Create("$ShotDir\`$name.png"); `$enc.Save(`$fs); `$fs.Close()
}
`$window.Add_ContentRendered({
    `$script:UiReady = `$true
    if ('$Lang' -ne 'it') { foreach (`$i in `$cmbLang.Items) { if ([string]`$i.Tag -eq '$Lang') { `$cmbLang.SelectedItem = `$i } } }
    if ($Scale -gt 0) { `$cmbUiScale.SelectedIndex = $Scale }
    `$list = @($pagesArg)
    foreach (`$e in `$script:NavPages) {
        `$n = [string]`$e.Nav.Name
        if (`$list.Count -gt 0 -and `$list -notcontains `$n) { continue }
        `$sw = [Diagnostics.Stopwatch]::StartNew()
        try { `$e.Nav.IsChecked = `$true } catch { Write-Host "ERRORE pagina `$n : `$(`$_.Exception.Message)" -ForegroundColor Red }
        `$until = [DateTime]::Now.AddMilliseconds(400)
        while ([DateTime]::Now -lt `$until) { [System.Windows.Threading.Dispatcher]::CurrentDispatcher.Invoke([Action]{}, [System.Windows.Threading.DispatcherPriority]::Background); [Threading.Thread]::Sleep(15) }
        Save-Shot "$Lang-`$n"
        Write-Host ("pagina {0,-12} {1,6} ms" -f `$n, `$sw.ElapsedMilliseconds)
    }
    if (`$list.Count -eq 0 -or `$list -contains 'tabApps') {
        (E 'tabApps').IsChecked = `$true; `$radAppsInstalled.IsChecked = `$true
        `$until = [DateTime]::Now.AddMilliseconds(600)
        while ([DateTime]::Now -lt `$until) { [System.Windows.Threading.Dispatcher]::CurrentDispatcher.Invoke([Action]{}, [System.Windows.Threading.DispatcherPriority]::Background); [Threading.Thread]::Sleep(15) }
        Save-Shot "$Lang-appsInstalled"
        Write-Host ("Programmi installati letti: " + `$script:AppInstalledList.Count)
    }
    Write-Host ("Righe catalogo: " + `$script:CatRows.Count)
    `$bad = @(`$script:CatRows | Where-Object { `$_.Item.Kind -in @('T','J') -and -not `$_.Control.IsEnabled })
    Write-Host ("Voci non disponibili su questo PC: " + (`$bad | ForEach-Object { `$_.Item.Id }) -join ', ')
    `$window.Close()
})
[void]`$window.ShowDialog()
"@
$t = $t.Replace('[void]$window.ShowDialog()', $harness)
$tf = Join-Path $env:TEMP 'TweakAndrew_test.ps1'
[System.IO.File]::WriteAllText($tf, $t, (New-Object System.Text.UTF8Encoding $true))
& powershell.exe -NoProfile -STA -ExecutionPolicy Bypass -File $tf
