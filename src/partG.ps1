
# ------------------------------------------------------------------------------
# 23. FINESTRE DI DIALOGO NEL TEMA DEL PROGRAMMA
# ------------------------------------------------------------------------------
# Sostituiscono le MessageBox di Windows, che stonavano con il resto
# dell'interfaccia. Scheda scura, icona colorata, due pulsanti; la finestra
# principale si oscura finche' la domanda e' aperta. Invio conferma, Esc annulla.
$script:Dimmer = E 'dimmer'

function Show-Dialog {
    param(
        [string]$Title,
        [string]$Message,
        [ValidateSet('ask','warn','danger')][string]$Kind = 'ask',
        [string]$Detail = ''
    )
    $accent = switch ($Kind) { 'warn' { '#FFFFB86B' } 'danger' { '#FFF87171' } default { '#FF1E90FF' } }
    $glyph  = if ($Kind -eq 'ask') { '?' } else { '!' }

    [xml]$dx = @'
<Window xmlns="http://schemas.microsoft.com/winfx/2006/xaml/presentation"
        xmlns:x="http://schemas.microsoft.com/winfx/2006/xaml"
        WindowStyle="None" AllowsTransparency="True" Background="Transparent"
        ShowInTaskbar="False" ResizeMode="NoResize" SizeToContent="WidthAndHeight"
        WindowStartupLocation="CenterOwner" TextOptions.TextFormattingMode="Ideal" UseLayoutRounding="True">
    <Border Margin="24" CornerRadius="20" Background="#FF101014" BorderBrush="#FF26262C" BorderThickness="1"
            Padding="26,24,24,22" MinWidth="380" MaxWidth="480">
        <Border.Effect>
            <DropShadowEffect BlurRadius="36" ShadowDepth="6" Opacity="0.7" Color="#000000"/>
        </Border.Effect>
        <StackPanel>
            <Grid>
                <Grid.ColumnDefinitions>
                    <ColumnDefinition Width="Auto"/>
                    <ColumnDefinition Width="*"/>
                </Grid.ColumnDefinitions>
                <Border x:Name="dIcon" Width="34" Height="34" CornerRadius="17" VerticalAlignment="Top" Margin="0,0,16,0">
                    <TextBlock x:Name="dGlyph" FontFamily="Raleway, Segoe UI" FontWeight="Bold" FontSize="17"
                               HorizontalAlignment="Center" VerticalAlignment="Center"/>
                </Border>
                <StackPanel Grid.Column="1">
                    <TextBlock x:Name="dTitle" FontFamily="Raleway, Segoe UI Variable Display, Segoe UI" FontWeight="Bold"
                               FontSize="16" Foreground="#FFF2F2F5" TextWrapping="Wrap" Margin="0,6,0,8"/>
                    <TextBlock x:Name="dMsg" FontFamily="Roboto, Segoe UI" FontSize="13" Foreground="#FFB4B4BE"
                               TextWrapping="Wrap" LineHeight="20"/>
                    <TextBlock x:Name="dDetail" FontFamily="Roboto, Segoe UI" FontSize="12" Margin="0,10,0,0"
                               TextWrapping="Wrap" Visibility="Collapsed"/>
                </StackPanel>
            </Grid>
            <StackPanel Orientation="Horizontal" HorizontalAlignment="Right" Margin="0,22,0,0">
                <Button x:Name="dNo" Height="38" MinWidth="104" Margin="0,0,10,0"/>
                <Button x:Name="dYes" Height="38" MinWidth="120" IsDefault="True"/>
            </StackPanel>
        </StackPanel>
    </Border>
</Window>
'@
    $dlg = [Windows.Markup.XamlReader]::Load((New-Object System.Xml.XmlNodeReader $dx))
    $dlg.Owner = $window
    $brush = New-Object System.Windows.Media.SolidColorBrush ([System.Windows.Media.ColorConverter]::ConvertFromString($accent))
    $soft  = $brush.Clone(); $soft.Opacity = 0.16
    $dlg.FindName('dIcon').Background = $soft
    $g = $dlg.FindName('dGlyph'); $g.Text = $glyph; $g.Foreground = $brush
    $dlg.FindName('dTitle').Text = $Title
    $dlg.FindName('dMsg').Text = $Message
    if ($Detail) {
        $d = $dlg.FindName('dDetail'); $d.Text = $Detail; $d.Foreground = $brush
        $d.Visibility = [System.Windows.Visibility]::Visible
    }
    $yes = $dlg.FindName('dYes'); $no = $dlg.FindName('dNo')
    $yes.Style = $window.FindResource('PrimaryBtn'); $no.Style = $window.FindResource('GhostBtn')
    $yes.Content = T 'dlgYes'; $no.Content = T 'dlgNo'
    $yes.Add_Click({ $dlg.DialogResult = $true }.GetNewClosure())
    $no.Add_Click({ $dlg.DialogResult = $false }.GetNewClosure())
    $dlg.Add_KeyDown({ if ($_.Key -eq [System.Windows.Input.Key]::Escape) { $dlg.DialogResult = $false } }.GetNewClosure())
    $dlg.Add_MouseLeftButtonDown({ try { $dlg.DragMove() } catch {} }.GetNewClosure())

    if ($null -ne $script:Dimmer) { $script:Dimmer.Visibility = [System.Windows.Visibility]::Visible }
    try { $r = $dlg.ShowDialog() } finally {
        if ($null -ne $script:Dimmer) { $script:Dimmer.Visibility = [System.Windows.Visibility]::Collapsed }
    }
    return ($r -eq $true)
}

# Riepilogo a fine operazioni: niente finestra, una riga nella barra in basso.
# «OK: 0 | 1 | 0» non diceva niente; qui ogni numero ha il suo nome.
function Show-RunSummary {
    $text = (T 'doneSummary') -f $script:OkCount, $script:SkipCount, $script:WarnCount
    if ($script:OkCount -gt 0) { $text += "  " + (T 'doneReboot') }
    $txtProgressLabel.Text = $text
    $color = if ($script:WarnCount -gt 0) { '#FFFFB86B' } else { '#FF2ED3A7' }
    $txtProgressLabel.Foreground = New-Object System.Windows.Media.SolidColorBrush ([System.Windows.Media.ColorConverter]::ConvertFromString($color))
}

# ------------------------------------------------------------------------------
# 24. MENU ARRESTA: SOSPENDI E IBERNA
# ------------------------------------------------------------------------------
# Interruttori a effetto immediato, fuori dalla coda di «Applica»: leggono lo
# stato attuale all'avvio e lo cambiano appena li tocchi. La presenza delle due
# voci nel menu Arresta e' un'impostazione di sistema, non del piano energetico:
# timeout e valori del piano attivo restano come sono.
$script:FlyoutKey = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\FlyoutMenuSettings'
$script:FlyoutPolicy = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Explorer'
$chkMenuSleep = E 'chkMenuSleep'; $chkMenuHibernate = E 'chkMenuHibernate'
$script:LiveLoading = $false

function Read-ShutdownMenu {
    $script:LiveLoading = $true
    $s = Get-RegOrNull $script:FlyoutKey 'ShowSleepOption'
    $h = Get-RegOrNull $script:FlyoutKey 'ShowHibernateOption'
    $hibOn = (Get-RegOrNull 'HKLM:\SYSTEM\CurrentControlSet\Control\Power' 'HibernateEnabled') -eq 1
    # Senza valore, Windows mostra Sospendi e nasconde Iberna.
    $chkMenuSleep.IsChecked = ($null -eq $s -or $s -ne 0)
    $chkMenuHibernate.IsChecked = ($h -eq 1 -and $hibOn)
    $script:LiveLoading = $false
}

function Set-ShutdownMenuItem {
    param([string]$Name, [bool]$Show, [string]$Label)
    Set-Reg $script:FlyoutKey $Name ([int]$Show) 'DWord' "$Label - $(if ($Show) { 'visibile' } else { 'nascosta' })" | Out-Null
    # Un criterio con lo stesso nome avrebbe la precedenza e annullerebbe la scelta.
    if ($null -ne (Get-RegOrNull $script:FlyoutPolicy $Name)) { Remove-Reg $script:FlyoutPolicy $Name "$Label (criterio)" }
}

$chkMenuSleep.Add_Click({
    if ($script:LiveLoading) { return }
    Set-ShutdownMenuItem 'ShowSleepOption' ($chkMenuSleep.IsChecked -eq $true) 'Sospendi nel menu Arresta'
})
$chkMenuHibernate.Add_Click({
    if ($script:LiveLoading) { return }
    $show = ($chkMenuHibernate.IsChecked -eq $true)
    if ($show -and (Get-RegOrNull 'HKLM:\SYSTEM\CurrentControlSet\Control\Power' 'HibernateEnabled') -ne 1) {
        # La voce compare solo se l'ibernazione esiste: si riattiva il file di ibernazione.
        powercfg /hibernate on | Out-Null
        Write-Log "[OK] Ibernazione riattivata: serve per mostrare la voce Iberna."
    }
    Set-ShutdownMenuItem 'ShowHibernateOption' $show 'Iberna nel menu Arresta'
})

# ------------------------------------------------------------------------------
# 25. PRIORITA' DEL PROCESSORE (Win32PrioritySeparation)
# ------------------------------------------------------------------------------
# Sei bit, tre coppie: durata del quanto (breve/lunga), quanto fisso o
# variabile, e quanto vantaggio dare alla finestra in primo piano.
$script:PsPath = 'HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl'
$cmbPsPreset = E 'cmbPsPreset'; $txtPsCustom = E 'txtPsCustom'; $txtPsDecoded = E 'txtPsDecoded'
$txtPsCurrent = E 'txtPsCurrent'; $btnPsApply = E 'btnPsApply'; $btnPsDefault = E 'btnPsDefault'

function Format-PrioritySeparation([int]$v) {
    $interval = ($v -shr 4) -band 3
    $length   = ($v -shr 2) -band 3
    $boost    = $v -band 3
    $i = switch ($interval) { 1 { T 'psLong' } 2 { T 'psShort' } default { T 'psAuto' } }
    $l = switch ($length)   { 1 { T 'psVariable' } 2 { T 'psFixed' } default { T 'psAuto' } }
    $b = switch ($boost)    { 0 { '1:1' } 1 { '2:1' } default { '3:1' } }
    return ("0x{0:X2} ({0})  ·  {1}: {2}  ·  {3}: {4}  ·  {5}: {6}" -f $v, (T 'psInterval'), $i, (T 'psQuantum'), $l, (T 'psBoost'), $b)
}

function Get-PsSelected {
    $item = $cmbPsPreset.SelectedItem
    if ($null -eq $item) { return $null }
    $tag = [int]$item.Tag
    if ($tag -ge 0) { return $tag }
    $raw = ([string]$txtPsCustom.Text).Trim() -replace '^0x', ''
    if ($raw -notmatch '^[0-9A-Fa-f]{1,2}$') { return $null }
    $n = [Convert]::ToInt32($raw, 16)
    if ($n -gt 0x3F) { return $null }
    return $n
}

function Update-PsView {
    $cur = Get-RegOrNull $script:PsPath 'Win32PrioritySeparation'
    if ($null -ne $cur) { $txtPsCurrent.Text = Format-PrioritySeparation ([int]$cur) }
    $isCustom = ($null -ne $cmbPsPreset.SelectedItem -and [int]$cmbPsPreset.SelectedItem.Tag -lt 0)
    $txtPsCustom.IsEnabled = $isCustom
    $sel = Get-PsSelected
    $txtPsDecoded.Text = if ($null -ne $sel) { Format-PrioritySeparation $sel } else { T 'psInvalid' }
}

$cmbPsPreset.Add_SelectionChanged({ Update-PsView })
$txtPsCustom.Add_TextChanged({ Update-PsView })
$btnPsApply.Add_Click({
    $v = Get-PsSelected
    if ($null -eq $v) { Write-Log "[AVVISO] $(T 'psInvalid')"; return }
    Set-Reg $script:PsPath 'Win32PrioritySeparation' $v 'DWord' ("Win32PrioritySeparation = 0x{0:X2}" -f $v) | Out-Null
    Update-PsView
})
$btnPsDefault.Add_Click({
    Set-Reg $script:PsPath 'Win32PrioritySeparation' 2 'DWord' 'Win32PrioritySeparation = 0x02 (predefinito)' | Out-Null
    $cmbPsPreset.SelectedIndex = 0
    Update-PsView
})

# ------------------------------------------------------------------------------
# 26. MULTIMEDIA CLASS SCHEDULER (MMCSS)
# ------------------------------------------------------------------------------
# Lo stesso pannello del «Multimedia Scheduler Configuration Tool»: due valori
# generali e le variabili di ogni attivita' (Games, Audio, Pro Audio...).
# Il servizio legge i valori all'avvio: le modifiche valgono dopo un riavvio.
$script:MmRoot = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile'
$cmbMmNet = E 'cmbMmNet'; $cmbMmResp = E 'cmbMmResp'; $cmbMmTask = E 'cmbMmTask'
$txtMmAffinity = E 'txtMmAffinity'; $txtMmClock = E 'txtMmClock'
$cmbMmGpu = E 'cmbMmGpu'; $cmbMmPrio = E 'cmbMmPrio'; $cmbMmSched = E 'cmbMmSched'; $cmbMmSfio = E 'cmbMmSfio'
$cmbMmBgOnly = E 'cmbMmBgOnly'; $cmbMmBgPrio = E 'cmbMmBgPrio'; $cmbMmLatency = E 'cmbMmLatency'
$btnMmApply = E 'btnMmApply'; $btnMmDefault = E 'btnMmDefault'; $btnMmBackup = E 'btnMmBackup'; $btnMmReload = E 'btnMmReload'

# Valori di fabbrica di Windows per le attivita' standard.
$script:MmDefaults = @{
    'Games'          = @{ Prio = 2; Sched = 'Medium'; Bg = 'False' }
    'Audio'          = @{ Prio = 6; Sched = 'Medium'; Bg = 'True'  }
    'Pro Audio'      = @{ Prio = 1; Sched = 'High';   Bg = 'False' }
    'Capture'        = @{ Prio = 5; Sched = 'Medium'; Bg = 'False' }
    'Distribution'   = @{ Prio = 4; Sched = 'Medium'; Bg = 'True'  }
    'Playback'       = @{ Prio = 3; Sched = 'Medium'; Bg = 'False' }
    'Window Manager' = @{ Prio = 5; Sched = 'Medium'; Bg = 'True'  }
}

function Add-ComboValues($combo, $values) {
    $combo.Items.Clear()
    foreach ($v in $values) {
        $it = New-Object System.Windows.Controls.ComboBoxItem
        $it.Content = [string]$v; $it.Tag = $v
        [void]$combo.Items.Add($it)
    }
}
function Select-ComboValue($combo, $value) {
    foreach ($it in $combo.Items) {
        if ([string]$it.Tag -eq [string]$value) { $combo.SelectedItem = $it; return }
    }
    $combo.SelectedIndex = 0
}
function Get-ComboValue($combo) { if ($null -eq $combo.SelectedItem) { return $null }; return $combo.SelectedItem.Tag }

Add-ComboValues $cmbMmGpu (0..31)
Add-ComboValues $cmbMmPrio (1..8)
Add-ComboValues $cmbMmSched @('High','Medium','Low')
Add-ComboValues $cmbMmSfio @('High','Normal','Low','Idle')
Add-ComboValues $cmbMmBgOnly @('True','False')
Add-ComboValues $cmbMmBgPrio @('-','1','2','3','4','5','6','7','8')
Add-ComboValues $cmbMmLatency @('-','True','False')

function Read-MmTask {
    $name = Get-ComboValue $cmbMmTask
    if (-not $name) { return }
    $p = "$script:MmRoot\Tasks\$name"
    $aff = Get-RegOrNull $p 'Affinity'
    $txtMmAffinity.Text = if ($null -eq $aff) { '0' } else { '{0:X}' -f [uint32]([int64]$aff -band 0xFFFFFFFF) }
    $clk = Get-RegOrNull $p 'Clock Rate'
    $txtMmClock.Text = if ($null -eq $clk) { '10000' } else { [string]$clk }
    Select-ComboValue $cmbMmGpu  ($(if ($null -ne ($v = Get-RegOrNull $p 'GPU Priority')) { $v } else { 8 }))
    Select-ComboValue $cmbMmPrio ($(if ($null -ne ($v = Get-RegOrNull $p 'Priority')) { $v } else { 2 }))
    Select-ComboValue $cmbMmSched ($(if ($v = Get-RegOrNull $p 'Scheduling Category') { $v } else { 'Medium' }))
    Select-ComboValue $cmbMmSfio  ($(if ($v = Get-RegOrNull $p 'SFIO Priority') { $v } else { 'Normal' }))
    Select-ComboValue $cmbMmBgOnly ($(if ($v = Get-RegOrNull $p 'Background Only') { $v } else { 'False' }))
    Select-ComboValue $cmbMmBgPrio ($(if ($null -ne ($v = Get-RegOrNull $p 'Background Priority')) { $v } else { '-' }))
    Select-ComboValue $cmbMmLatency ($(if ($v = Get-RegOrNull $p 'Latency Sensitive') { $v } else { '-' }))
}

function Read-Mmcss {
    $keep = Get-ComboValue $cmbMmTask
    $tasks = @(Get-ChildItem "$script:MmRoot\Tasks" -ErrorAction SilentlyContinue | ForEach-Object { $_.PSChildName } | Sort-Object)
    Add-ComboValues $cmbMmTask $tasks
    if ($keep -and $tasks -contains $keep) { Select-ComboValue $cmbMmTask $keep }
    elseif ($tasks -contains 'Games') { Select-ComboValue $cmbMmTask 'Games' }
    else { $cmbMmTask.SelectedIndex = 0 }

    $net = Get-RegOrNull $script:MmRoot 'NetworkThrottlingIndex'
    if ($null -eq $net) { $net = 10 }
    if ([int64]$net -eq -1 -or [int64]$net -eq 4294967295) { $net = -1 }
    Select-ComboValue $cmbMmNet $net
    $resp = Get-RegOrNull $script:MmRoot 'SystemResponsiveness'
    if ($null -eq $resp) { $resp = 20 }
    Select-ComboValue $cmbMmResp $resp
    Read-MmTask
}

# Voci dei due menu generali: il testo resta leggibile, il Tag porta il valore.
function Set-MmGlobalItems {
    $cmbMmNet.Items.Clear()
    foreach ($pair in @(@(-1, (T 'mmNetOff')), @(10, (T 'mmNetDefault')), @(20, '20'), @(40, '40'), @(70, '70'))) {
        $it = New-Object System.Windows.Controls.ComboBoxItem; $it.Tag = $pair[0]; $it.Content = $pair[1]
        [void]$cmbMmNet.Items.Add($it)
    }
    $cmbMmResp.Items.Clear()
    foreach ($n in 0..10) {
        $v = $n * 10
        $it = New-Object System.Windows.Controls.ComboBoxItem; $it.Tag = $v
        $it.Content = if ($v -eq 20) { "20% ($(T 'mmDefaultWord'))" } else { "$v%" }
        [void]$cmbMmResp.Items.Add($it)
    }
}

$cmbMmTask.Add_SelectionChanged({ Read-MmTask })
$btnMmReload.Add_Click({ Read-Mmcss })

$btnMmBackup.Add_Click({
    $file = Join-Path ([Environment]::GetFolderPath('Desktop')) ("MMCSS_backup_{0}.reg" -f (Get-Date -Format 'yyyyMMdd_HHmm'))
    $p = Start-Process -FilePath "$env:SystemRoot\System32\reg.exe" -WindowStyle Hidden -Wait -PassThru `
        -ArgumentList @('export', '"HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile"', "`"$file`"", '/y')
    if ($p.ExitCode -eq 0) { Write-Log "[OK] Backup MMCSS salvato: $file" }
    else { Write-Log "[ERRORE] Backup MMCSS non riuscito (codice $($p.ExitCode))." }
})

$btnMmApply.Add_Click({
    $name = Get-ComboValue $cmbMmTask
    $clock = 0; $aff = 0
    if (-not [int]::TryParse(([string]$txtMmClock.Text).Trim(), [ref]$clock) -or $clock -lt 1000 -or $clock -gt 100000) {
        Write-Log "[AVVISO] $(T 'mmBadClock')"; return
    }
    $affRaw = ([string]$txtMmAffinity.Text).Trim() -replace '^0x', ''
    if ($affRaw -notmatch '^[0-9A-Fa-f]{1,8}$') { Write-Log "[AVVISO] $(T 'mmBadAffinity')"; return }
    $aff = [Convert]::ToInt64($affRaw, 16)
    if ($aff -gt [int]::MaxValue) { $aff = $aff - 4294967296 }

    Set-Reg $script:MmRoot 'NetworkThrottlingIndex' ([int](Get-ComboValue $cmbMmNet)) 'DWord' 'MMCSS / NetworkThrottlingIndex' | Out-Null
    Set-Reg $script:MmRoot 'SystemResponsiveness' ([int](Get-ComboValue $cmbMmResp)) 'DWord' 'MMCSS / SystemResponsiveness' | Out-Null
    if ($name) {
        $p = "$script:MmRoot\Tasks\$name"
        Set-Reg $p 'Affinity' ([int]$aff) 'DWord' "$name / Affinity" | Out-Null
        Set-Reg $p 'Clock Rate' $clock 'DWord' "$name / Clock Rate" | Out-Null
        Set-Reg $p 'GPU Priority' ([int](Get-ComboValue $cmbMmGpu)) 'DWord' "$name / GPU Priority" | Out-Null
        Set-Reg $p 'Priority' ([int](Get-ComboValue $cmbMmPrio)) 'DWord' "$name / Priority" | Out-Null
        Set-Reg $p 'Scheduling Category' ([string](Get-ComboValue $cmbMmSched)) 'String' "$name / Scheduling Category" | Out-Null
        Set-Reg $p 'SFIO Priority' ([string](Get-ComboValue $cmbMmSfio)) 'String' "$name / SFIO Priority" | Out-Null
        Set-Reg $p 'Background Only' ([string](Get-ComboValue $cmbMmBgOnly)) 'String' "$name / Background Only" | Out-Null
        $bp = [string](Get-ComboValue $cmbMmBgPrio)
        if ($bp -eq '-') { if ($null -ne (Get-RegOrNull $p 'Background Priority')) { Remove-Reg $p 'Background Priority' "$name / Background Priority" } }
        else { Set-Reg $p 'Background Priority' ([int]$bp) 'DWord' "$name / Background Priority" | Out-Null }
        $ls = [string](Get-ComboValue $cmbMmLatency)
        if ($ls -eq '-') { if ($null -ne (Get-RegOrNull $p 'Latency Sensitive')) { Remove-Reg $p 'Latency Sensitive' "$name / Latency Sensitive" } }
        else { Set-Reg $p 'Latency Sensitive' $ls 'String' "$name / Latency Sensitive" | Out-Null }
    }
    Write-Log "[INFO] $(T 'mmReboot')"
})

$btnMmDefault.Add_Click({
    $name = Get-ComboValue $cmbMmTask
    Select-ComboValue $cmbMmNet 10
    Select-ComboValue $cmbMmResp 20
    $txtMmAffinity.Text = '0'; $txtMmClock.Text = '10000'
    Select-ComboValue $cmbMmGpu 8
    Select-ComboValue $cmbMmSfio 'Normal'
    Select-ComboValue $cmbMmBgPrio '-'
    Select-ComboValue $cmbMmLatency '-'
    $d = $script:MmDefaults[[string]$name]
    if ($d) {
        Select-ComboValue $cmbMmPrio $d.Prio; Select-ComboValue $cmbMmSched $d.Sched; Select-ComboValue $cmbMmBgOnly $d.Bg
        Write-Log "[INFO] $(T 'mmDefaultsLoaded')"
    } else {
        Write-Log "[AVVISO] $(T 'mmNoDefaults')"
    }
})

# Stato iniziale delle pagine a effetto immediato.
function Initialize-LivePages {
    Set-MmGlobalItems
    Read-Mmcss
    Read-ShutdownMenu
    $cur = Get-RegOrNull $script:PsPath 'Win32PrioritySeparation'
    $match = $null
    foreach ($it in $cmbPsPreset.Items) { if ($null -ne $cur -and [int]$it.Tag -eq [int]$cur) { $match = $it } }
    if ($match) { $cmbPsPreset.SelectedItem = $match }
    else {
        $cmbPsPreset.SelectedIndex = $cmbPsPreset.Items.Count - 1
        if ($null -ne $cur) { $txtPsCustom.Text = '{0:X2}' -f [int]$cur }
    }
    Update-PsView
}
Initialize-LivePages
