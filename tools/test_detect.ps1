# Apre il programma, aspetta il rilevamento iniziale e stampa lo stato letto
# per ogni interruttore: attivo, non attivo, non rilevabile. Non applica nulla.
$root = Split-Path $PSScriptRoot -Parent
$text = [IO.File]::ReadAllText((Join-Path $root 'Tweak_Andrew.ps1'), [Text.Encoding]::UTF8)
$t = $text -replace '(?s)if \(-not \$principal\.IsInRole.*?\r?\n    Exit\r?\n\}', '# test'
$harness = @'
$window.Add_ContentRendered({ [void]$window.Dispatcher.BeginInvoke([Action]{
    $on = @(); $off = @(); $unk = @()
    foreach ($cb in $script:AllCheckBoxes) {
        $n = [string]$cb.Name
        if (-not $script:Baseline.ContainsKey($n)) { $unk += $n } elseif ($script:Baseline[$n]) { $on += $n } else { $off += $n }
    }
    Write-Host ("ATTIVE " + $on.Count + ": " + ($on -join ' '))
    Write-Host ("NON ATTIVE " + $off.Count + ": " + ($off -join ' '))
    Write-Host ("NON RILEVABILI " + $unk.Count + ": " + ($unk -join ' '))
    $window.Close()
}, [System.Windows.Threading.DispatcherPriority]::ApplicationIdle) })
[void]$window.ShowDialog()
'@
$t = $t -replace '(?s)\[void\]\$window\.ShowDialog\(\)\s*$', ''
$tmp = Join-Path $env:TEMP 'ta_detect.ps1'
[IO.File]::WriteAllText($tmp, $t + "`r`n" + $harness, (New-Object Text.UTF8Encoding $true))
$sw = [Diagnostics.Stopwatch]::StartNew()
& powershell -NoProfile -ExecutionPolicy Bypass -File $tmp 2>&1 | Where-Object { $_ -match '^(ATTIVE|NON ATTIVE|NON RILEVABILI)|rror' }
"tempo totale: $([int]$sw.Elapsed.TotalSeconds) s"
Remove-Item $tmp -Force
