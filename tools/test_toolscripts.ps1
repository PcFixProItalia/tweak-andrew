# Genera gli script degli strumenti (pulizia con tutte le voci, rimozione dei
# dispositivi) e ne controlla la sintassi in ogni lingua. Non li esegue.
$root = Split-Path $PSScriptRoot -Parent
$text = [IO.File]::ReadAllText((Join-Path $root 'Tweak_Andrew.ps1'), [Text.Encoding]::UTF8)
$t = $text -replace '(?s)if \(-not \$principal\.IsInRole.*?\r?\n    Exit\r?\n\}', '# test'
$harness = @'
$window.Add_ContentRendered({ [void]$window.Dispatcher.BeginInvoke([Action]{
    foreach ($lg in 'it', 'en', 'de', 'fr', 'ru') {
        Set-Language $lg
        $keys = @($script:CleanItems | ForEach-Object { $_.Key })
        $scripts = @{ pulizia = (Get-CleanScript $keys); dispositivi = (Get-GhostRemoveScript @("USB\VID_0951&PID_1666\60A44C42'5", 'HID\X')) }
        foreach ($k in $scripts.Keys) {
            $err = $null; [void][System.Management.Automation.Language.Parser]::ParseInput($scripts[$k], [ref]$null, [ref]$err)
            Write-Host ("$lg $k : errori di sintassi " + @($err).Count + $(if (@($err).Count) { ' - ' + $err[0].Message } else { '' }))
        }
    }
    $window.Close()
}, [System.Windows.Threading.DispatcherPriority]::ApplicationIdle) })
[void]$window.ShowDialog()
'@
$t = $t.Replace('[void]$window.ShowDialog()', $harness)
$tf = Join-Path $env:TEMP 'TweakAndrew_toolscripts.ps1'
[IO.File]::WriteAllText($tf, $t, (New-Object Text.UTF8Encoding $true))
& powershell.exe -NoProfile -STA -ExecutionPolicy Bypass -File $tf
