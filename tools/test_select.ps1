# Prova i pulsanti di selezione: «Seleziona tutto», «Questa pagina» e
# «Consigliati». Non applica nulla: preme solo i pulsanti e legge le caselle.
$root = Split-Path $PSScriptRoot -Parent
$text = [IO.File]::ReadAllText((Join-Path $root 'Tweak_Andrew.ps1'), [Text.Encoding]::UTF8)
$t = $text -replace '(?s)if \(-not \$principal\.IsInRole.*?\r?\n    Exit\r?\n\}', '# test'
$harness = @'
function Click($b) { $b.RaiseEvent((New-Object System.Windows.RoutedEventArgs ([System.Windows.Controls.Primitives.ButtonBase]::ClickEvent))) }
function Checked { @($script:AllCheckBoxes | Where-Object { $_.IsChecked -eq $true } | ForEach-Object { $_.Name }) }
$window.Add_ContentRendered({
    $script:UiReady = $true
    Write-Host "--- SELEZIONE ---" -ForegroundColor Cyan
    Write-Host ("Schede video rilevate: " + ($script:GpuVendors -join ', '))
    Click $btnSelectAll
    $sel = Checked
    Write-Host ("Seleziona tutto: " + $sel.Count + " voci")
    Write-Host ("  spooler di stampa selezionato: " + ($sel -contains 'chkSvcPrint'))
    Write-Host ("  voci AMD selezionate: " + @($sel | Where-Object { $_ -like 'chkAmd*' }).Count)
    Write-Host ("  voci NVIDIA selezionate: " + @($sel | Where-Object { $_ -like 'chkNv*' }).Count)
    Write-Host ("  voci Intel selezionate: " + @($sel | Where-Object { $_ -like 'chkIntel*' }).Count)
    Write-Host ("  voci della pagina Avanzate: " + @($sel | Where-Object { $script:AdvancedCheckBoxes.Name -contains $_ }).Count)
    Click $btnDeselectAll
    (E 'tabGpu').IsChecked = $true
    Click $btnSelectPage
    $sel = Checked
    Write-Host ("Questa pagina (Scheda video): " + ($sel -join ' '))
    Click $btnDeselectAll
    (E 'tabPerf').IsChecked = $true
    Click $btnRecommended
    Write-Host ("Consigliati (Prestazioni): " + ((Checked) -join ' '))
    Write-Host ("  messaggio: " + $txtProgressLabel.Text)
    Click $btnDeselectAll
    (E 'tabAdv').IsChecked = $true
    Click $btnRecommended
    Write-Host ("Consigliati (Avanzate): " + @(Checked).Count + " - " + $txtProgressLabel.Text)
    (E 'tabSched').IsChecked = $true
    Click $btnRecommended
    Write-Host ("Consigliati (Priorita): preset=" + $cmbPsPreset.SelectedItem.Content + " rete=" + $cmbMmNet.SelectedItem.Content +
                " resp=" + $cmbMmResp.SelectedItem.Content + " attivita=" + $cmbMmTask.SelectedItem.Content +
                " prio=" + $cmbMmPrio.SelectedItem.Content + " sched=" + $cmbMmSched.SelectedItem.Content + " gpu=" + $cmbMmGpu.SelectedItem.Content)
    Write-Host ("  messaggio: " + $txtProgressLabel.Text)
    Write-Host ("Coda finale: " + @(Checked).Count + " voci")
    $window.Close()
})
[void]$window.ShowDialog()
'@
$t = $t.Replace('[void]$window.ShowDialog()', $harness)
$tf = Join-Path $env:TEMP 'TweakAndrew_select.ps1'
[IO.File]::WriteAllText($tf, $t, (New-Object Text.UTF8Encoding $true))
& powershell.exe -NoProfile -STA -ExecutionPolicy Bypass -File $tf
