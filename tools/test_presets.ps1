# Prova «Consigliati», «Seleziona tutto» e «Deseleziona» su tutte le pagine,
# catalogo, rete e profilo disco compresi. Prepara la coda ma non la esegue.
$root = Split-Path $PSScriptRoot -Parent
$text = [IO.File]::ReadAllText((Join-Path $root 'Tweak_Andrew.ps1'), [Text.Encoding]::UTF8)
$t = $text -replace '(?s)if \(-not \$principal\.IsInRole.*?\r?\n    Exit\r?\n\}', '# test'
$harness = @'
function Click($b) { $b.RaiseEvent((New-Object System.Windows.RoutedEventArgs ([System.Windows.Controls.Primitives.ButtonBase]::ClickEvent))) }
function Report($what) {
    Build-Actions
    $names = @($script:Actions | ForEach-Object { $_.Name })
    $cat = @($script:CatWant.Keys | Sort-Object)
    Write-Host ("$what -> Applica=" + $btnRun.IsEnabled + " Deseleziona=" + $btnDeselectAll.IsEnabled + " coda=" + $names.Count +
                " catalogo=" + $cat.Count + " rete=" + (Test-NetPending) + " disco=" + $chkStorageProfile.IsChecked)
    return $cat
}
$window.Add_ContentRendered({ [void]$window.Dispatcher.BeginInvoke([Action]{
    $script:DialogCalls = 0
    function global:Show-Dialog { $script:DialogCalls++; return $true }
    Write-Host ("Tipo di PC: " + (Get-PcType) + "  disco di sistema: " + $script:SystemDiskKind)
    [void](Report 'Avvio')
    Click $btnRecommended
    $cat = Report 'Consigliati'
    foreach ($id in 'pw.cpuMin','pw.display','pw.sleep','pw.nvme1','pw.nvme2','exp.compact') {
        Write-Host ("  $id ora=" + $script:CatNow[$id] + " scelto=" + $(if ($script:CatWant.ContainsKey($id)) { $script:CatWant[$id] } else { '(uguale)' }))
    }
    Write-Host ("  menu classico: " + $chkClassicMenu.IsChecked)
    foreach ($id in $cat) { $it = $script:CatById[$id]; Write-Host ("    " + $it.Page + " " + $id + " [" + $it.Kind + " rec=" + $it.Rec + " def=" + $it.Def + "] ora=" + $script:CatNow[$id] + " -> " + $script:CatWant[$id] + "  " + (Get-CatText $id)) }
    Write-Host ("  catalogo per pagina: " + (($cat | ForEach-Object { $script:CatById[$_].Page } | Group-Object | ForEach-Object { "$($_.Name)=$($_.Count)" }) -join ' '))
    Click $btnDeselectAll
    [void](Report 'Deseleziona')
    Click $btnSelectAll
    [void](Report 'Seleziona tutto')
    Click $btnDeselectAll
    # Pagina del catalogo: un interruttore cambiato non applica, accende Applica.
    (E 'tabExp').IsChecked = $true
    Show-CatPageIfNeeded 'exp'
    $row = $script:CatRows | Where-Object { $_.Item.Id -eq 'exp.compact' } | Select-Object -First 1
    $before = Get-CatState $row.Item
    $row.Control.IsChecked = -not $row.Control.IsChecked
    Write-Host ("Interruttore Vista compatta cambiato: sistema prima=$before dopo=" + (Get-CatState $row.Item) + " da applicare=" + $script:CatWant.ContainsKey('exp.compact') + " Applica=" + $btnRun.IsEnabled)
    Click $btnDeselectAll
    Write-Host ("Dopo Deseleziona: interruttore=" + $row.Control.IsChecked + " da applicare=" + $script:CatWant.Count)
    # Rete: un valore cambiato a mano accende Applica.
    $radTcpCustom.IsChecked = $true; Click $radTcpCustom
    $cmbTTL.SelectedIndex = 1 - $cmbTTL.SelectedIndex
    Write-Host ("Rete, TTL cambiato: da applicare=" + (Test-NetPending) + " Applica=" + $btnRun.IsEnabled)
    Click $btnDeselectAll
    Write-Host ("Rete dopo Deseleziona: da applicare=" + (Test-NetPending))
    Write-Host ("Conferme chieste: " + $script:DialogCalls)
    $window.Close()
}, [System.Windows.Threading.DispatcherPriority]::ApplicationIdle) })
[void]$window.ShowDialog()
'@
$t = $t.Replace('[void]$window.ShowDialog()', $harness)
$tf = Join-Path $env:TEMP 'TweakAndrew_presets.ps1'
[IO.File]::WriteAllText($tf, $t, (New-Object Text.UTF8Encoding $true))
& powershell.exe -NoProfile -STA -ExecutionPolicy Bypass -File $tf
