# Prova la ricerca e la rimozione dei residui con un programma finto: una
# cartella in %TEMP%, chiavi in HKCU\Software e un avvio automatico. Il test
# crea tutto e lo toglie; i dati veri non si toccano.
$root = Split-Path $PSScriptRoot -Parent
$text = [IO.File]::ReadAllText((Join-Path $root 'Tweak_Andrew.ps1'), [Text.Encoding]::UTF8)
$t = $text -replace '(?s)if \(-not \$principal\.IsInRole.*?\r?\n    Exit\r?\n\}', '# test'
$harness = @'
$window.Add_ContentRendered({ [void]$window.Dispatcher.BeginInvoke([Action]{
    $fail = 0
    function Check($name, $cond) { if ($cond) { Write-Host "OK   $name" } else { Write-Host "FAIL $name"; $script:fail++ } }
    $name = 'TweakAndrewFakeApp'
    $dir = Join-Path $env:TEMP "$name"
    New-Item -ItemType Directory -Force "$dir\bin" | Out-Null
    [IO.File]::WriteAllText("$dir\bin\fake.exe", 'x')
    New-Item -Path "HKCU:\Software\$name\Settings" -Force | Out-Null
    New-Item -Path "HKCU:\Software\TAFakePublisher\$name" -Force | Out-Null
    $run = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run'
    New-ItemProperty -Path $run -Name "$name Helper" -Value "`"$dir\bin\fake.exe`" --tray" -Force | Out-Null
    try {
        $app = @{ Name = "$name 2.4.1 (x64)"; Publisher = 'TAFakePublisher, Inc.'; Location = $dir; Icon = "$dir\bin\fake.exe,0"; Uninstall = "`"$dir\unins000.exe`""; RegPath = '' }
        $ps = [powershell]::Create(); [void]$ps.AddScript($script:LeftoverScanScript).AddArgument(@($app))
        $r = @($ps.Invoke() | Where-Object { $_ -is [hashtable] }); $ps.Dispose()
        $items = @($r[0].Items)
        foreach ($i in $items) { Write-Host ("  trovato: {0,-5} {1} {2}" -f $i.Kind, $i.Label, $(if ($i.Sure) { '' } else { '(da controllare)' })) }
        Check 'cartella del programma' (@($items | Where-Object { $_.Kind -eq 'dir' -and $_.Path -eq $dir -and $_.Sure }).Count -eq 1)
        Check 'chiave con il nome del programma' (@($items | Where-Object { $_.Kind -eq 'reg' -and $_.Label -like "*\Software\$name" }).Count -eq 1)
        Check "chiave dentro quella dell'editore" (@($items | Where-Object { $_.Kind -eq 'reg' -and $_.Label -like "*TAFakePublisher\$name" }).Count -eq 1)
        Check 'avvio automatico' (@($items | Where-Object { $_.Kind -eq 'run' -and $_.Path -like "*|$name Helper" }).Count -eq 1)
        Check 'niente cartelle di sistema' (@($items | Where-Object { $_.Path -match '\\(Windows|Microsoft|Common Files)$' }).Count -eq 0)
        $res = Remove-LeftoverItems $items -Permanent
        Check 'rimossi tutti' ($res.Ok -eq $items.Count)
        Check 'cartella tolta' (-not (Test-Path $dir))
        Check 'chiavi tolte' (-not (Test-Path "HKCU:\Software\$name") -and -not (Test-Path "HKCU:\Software\TAFakePublisher\$name"))
        Check 'avvio tolto' ($null -eq (Get-ItemProperty $run -Name "$name Helper" -ErrorAction SilentlyContinue))
        Check 'copia di sicurezza del registro' (@(Get-ChildItem $res.Backup -Filter '*.reg' -ErrorAction SilentlyContinue).Count -ge 3)
        # Un programma con nome generico non deve proporre nulla.
        $ps = [powershell]::Create(); [void]$ps.AddScript($script:LeftoverScanScript).AddArgument(@(@{ Name = 'Microsoft'; Publisher = 'Microsoft Corporation' }))
        $r2 = @($ps.Invoke() | Where-Object { $_ -is [hashtable] }); $ps.Dispose()
        Check 'nome generico: nessun residuo' (@($r2[0].Items).Count -eq 0)
        Remove-Item $res.Backup -Recurse -Force -ErrorAction SilentlyContinue
    } finally {
        Remove-Item $dir -Recurse -Force -ErrorAction SilentlyContinue
        Remove-Item "HKCU:\Software\$name" -Recurse -Force -ErrorAction SilentlyContinue
        Remove-Item "HKCU:\Software\TAFakePublisher" -Recurse -Force -ErrorAction SilentlyContinue
        Remove-ItemProperty $run -Name "$name Helper" -ErrorAction SilentlyContinue
    }
    # Script del debloat: sintassi in due lingue.
    foreach ($lg in 'it', 'de') {
        Set-Language $lg
        $err = $null; [void][System.Management.Automation.Language.Parser]::ParseInput((Get-DebloatScript @('news', 'xbox', 'onedrive')), [ref]$null, [ref]$err)
        Check "script del debloat ($lg)" (@($err).Count -eq 0)
    }
    Write-Host "FALLITI: $fail"
    $window.Close()
}, [System.Windows.Threading.DispatcherPriority]::ApplicationIdle) })
[void]$window.ShowDialog()
'@
$t = $t.Replace('[void]$window.ShowDialog()', $harness)
$tf = Join-Path $env:TEMP 'TweakAndrew_leftover.ps1'
[IO.File]::WriteAllText($tf, $t, (New-Object Text.UTF8Encoding $true))
& powershell.exe -NoProfile -STA -ExecutionPolicy Bypass -File $tf
