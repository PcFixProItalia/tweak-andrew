# Prova la scheda «Priorita' del processore»: selettori, profilo e caselle
# esadecimale/decimale restano allineati. Non scrive nel registro.
$root = Split-Path $PSScriptRoot -Parent
$text = [IO.File]::ReadAllText((Join-Path $root 'Tweak_Andrew.ps1'), [Text.Encoding]::UTF8)
$t = $text -replace '(?s)if \(-not \$principal\.IsInRole.*?\r?\n    Exit\r?\n\}', '# test'
$harness = @'
$window.Add_ContentRendered({ [void]$window.Dispatcher.BeginInvoke([Action]{
    $script:Errori = 0
    function Stato { "valore=0x{0:X2} hex={1} dec={2} profilo={3} applica={4} stato='{5}'" -f $script:PsValue, $txtPsHex.Text, $txtPsDec.Text, $cmbPsPreset.SelectedItem.Tag, $btnPsApply.IsEnabled, $txtPsDecoded.Text }
    function Atteso($cond, $cosa) { if ($cond) { Write-Host "OK: $cosa" } else { $script:Errori++; Write-Host "ERRORE: $cosa -> $(Stato)" } }
    Write-Host ("Avvio: " + (Stato))
    Select-ComboValue $cmbPsPreset 38
    Atteso ($script:PsValue -eq 38 -and $txtPsHex.Text -eq '26' -and $txtPsDec.Text -eq '38') 'profilo 0x26 aggiorna le caselle'
    $txtPsHex.Text = '2A'
    Atteso ($script:PsValue -eq 42 -and $txtPsDec.Text -eq '42' -and [int]$cmbPsPreset.SelectedItem.Tag -eq 42) 'hex 2A aggiorna decimale e profilo'
    $txtPsDec.Text = '25'
    Atteso ($script:PsValue -eq 25 -and $txtPsHex.Text -eq '19' -and [int]$cmbPsPreset.SelectedItem.Tag -eq -1) 'dec 25 da profilo personalizzato'
    $txtPsHex.Text = '0x16'
    Atteso ($script:PsValue -eq 22 -and $txtPsDec.Text -eq '22') 'hex con 0x accettato'
    $txtPsDec.Text = '99'
    Atteso ($script:PsInvalid -and -not $btnPsApply.IsEnabled -and $script:PsValue -eq 22) 'dec 99 non valido, Applica spento'
    $txtPsHex.Text = 'ZZ'
    Atteso ($script:PsInvalid -and -not $btnPsApply.IsEnabled) 'hex ZZ non valido'
    $txtPsHex.Text = '1A'
    Atteso (-not $script:PsInvalid -and $txtPsDec.Text -eq '26') 'hex 1A torna valido'
    $seg = (E 'psSegLen').Children[1]
    $ev = New-Object System.Windows.Input.MouseButtonEventArgs ([System.Windows.Input.Mouse]::PrimaryDevice), 0, ([System.Windows.Input.MouseButton]::Left)
    $ev.RoutedEvent = [System.Windows.UIElement]::MouseLeftButtonUpEvent
    $seg.RaiseEvent($ev)
    Atteso ($script:PsValue -eq 0x2A -and $txtPsHex.Text -eq '2A') 'selettore Breve porta 0x1A a 0x2A'
    Write-Host ("Fine: " + (Stato))
    Write-Host ("Errori: " + $script:Errori)
    $window.Close()
}, [System.Windows.Threading.DispatcherPriority]::ApplicationIdle) })
[void]$window.ShowDialog()
'@
$t = $t.Replace('[void]$window.ShowDialog()', $harness)
$tf = Join-Path $env:TEMP 'TweakAndrew_priority.ps1'
[IO.File]::WriteAllText($tf, $t, (New-Object Text.UTF8Encoding $true))
& powershell.exe -NoProfile -STA -ExecutionPolicy Bypass -File $tf
