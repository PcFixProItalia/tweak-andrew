# ------------------------------------------------------------------------------
# 28. PAGINE A INTERRUTTORE: lettura, scrittura e disegno del catalogo
# ------------------------------------------------------------------------------
# Ogni voce del catalogo mostra lo stato reale del sistema e lo cambia appena
# la tocchi, come negli strumenti di privacy dedicati: niente coda, niente
# «Applica». Le pagine si costruiscono alla prima apertura, per non rallentare
# l'avvio con centinaia di controlli che magari non guarderai.

Add-Type -Namespace TweakAndrew -Name PowerApi -MemberDefinition @'
[System.Runtime.InteropServices.DllImport("powrprof.dll")]
public static extern uint PowerGetActiveScheme(System.IntPtr root, out System.IntPtr scheme);
[System.Runtime.InteropServices.DllImport("powrprof.dll")]
public static extern uint PowerReadACValueIndex(System.IntPtr root, ref System.Guid scheme, ref System.Guid sub, ref System.Guid setting, out uint value);
[System.Runtime.InteropServices.DllImport("powrprof.dll")]
public static extern uint PowerWriteACValueIndex(System.IntPtr root, ref System.Guid scheme, ref System.Guid sub, ref System.Guid setting, uint value);
[System.Runtime.InteropServices.DllImport("powrprof.dll")]
public static extern uint PowerWriteDCValueIndex(System.IntPtr root, ref System.Guid scheme, ref System.Guid sub, ref System.Guid setting, uint value);
[System.Runtime.InteropServices.DllImport("powrprof.dll")]
public static extern uint PowerSetActiveScheme(System.IntPtr root, ref System.Guid scheme);
[System.Runtime.InteropServices.DllImport("kernel32.dll")]
public static extern System.IntPtr LocalFree(System.IntPtr mem);
'@ -ErrorAction SilentlyContinue

$script:CatById = @{}
foreach ($it in $script:Catalog) { $script:CatById[$it.Id] = $it }
$script:CatRows = New-Object System.Collections.ArrayList
$script:CatBuilt = @{}
$script:CatLoading = $false
$script:CatScope = 'U'

function Get-CatText([string]$key) {
    $t = Get-Text $script:CatText[$key]
    if ($t) { return $t }
    return $key
}

# --- registro, via .NET: piu' veloce del provider e senza problemi con «*» ---
function Get-CatKey([string]$path, [bool]$write) {
    $i = $path.IndexOf('\')
    $root = $path.Substring(0, $i); $sub = $path.Substring($i + 1)
    $hive = if ($root -eq 'HKCU') { [Microsoft.Win32.RegistryHive]::CurrentUser } else { [Microsoft.Win32.RegistryHive]::LocalMachine }
    if ($root -eq 'HKCR') { $sub = 'SOFTWARE\Classes\' + $sub }
    $base = [Microsoft.Win32.RegistryKey]::OpenBaseKey($hive, [Microsoft.Win32.RegistryView]::Registry64)
    if ($write) { return @{ Base = $base; Sub = $sub; Key = $base.CreateSubKey($sub) } }
    return @{ Base = $base; Sub = $sub; Key = $base.OpenSubKey($sub) }
}

function Get-CatRaw([string]$path, [string]$name) {
    $k = Get-CatKey $path $false
    if ($null -eq $k.Key) { return $null }
    try {
        $v = $k.Key.GetValue($name, $null, [Microsoft.Win32.RegistryValueOptions]::DoNotExpandEnvironmentNames)
        # Un byte[] restituito cosi' com'e' verrebbe srotolato da PowerShell: la virgola lo tiene intero.
        if ($v -is [array]) { return ,$v }
        return $v
    } finally { $k.Key.Close() }
}

function ConvertTo-CatBytes([string]$hex) {
    return ,[byte[]]@($hex.Trim() -split '\s+' | Where-Object { $_ } | ForEach-Object { [Convert]::ToByte($_, 16) })
}

function Get-CatKv([string]$s, [string]$name) {
    if (-not $s) { return $null }
    foreach ($part in $s.Split(';')) {
        $kv = $part.Split('=', 2)
        if ($kv.Count -eq 2 -and $kv[0] -eq $name) { return $kv[1] }
    }
    return $null
}

# Vero se il valore attuale corrisponde a una delle alternative della specifica.
function Test-CatValue($op, [string]$spec) {
    $path = $op[0]; $name = $op[1]; $type = $op[2]
    foreach ($alt in $spec.Split(',')) {
        if ($type -eq 'Key') {
            $k = Get-CatKey $path $false
            $exists = $null -ne $k.Key
            if ($exists) { $k.Key.Close() }
            if (($alt -eq '+') -eq $exists) { return $true }
            continue
        }
        $raw = Get-CatRaw $path $name
        if ($type -like 'Kv:*') {
            $v = Get-CatKv ([string]$raw) $type.Substring(3)
            if ($alt -eq '-') { if ($null -eq $v) { return $true } } elseif ($v -eq $alt) { return $true }
            continue
        }
        if ($alt -eq '-') { if ($null -eq $raw) { return $true }; continue }
        if ($null -eq $raw) { continue }
        switch -Wildcard ($type) {
            'D' { try { if (([int64]$raw -band 4294967295L) -eq ([int64]$alt -band 4294967295L)) { return $true } } catch {} }
            'Q' { try { if ([int64]$raw -eq [int64]$alt) { return $true } } catch {} }
            'B' { if ($raw -is [byte[]] -and [BitConverter]::ToString($raw) -eq [BitConverter]::ToString((ConvertTo-CatBytes $alt))) { return $true } }
            'Byte:*' {
                $n = [int]$type.Split(':')[1]
                if ($raw -is [byte[]] -and $raw.Length -gt $n -and $raw[$n] -eq [int]$alt) { return $true }
            }
            'Bit:*' {
                $p = $type.Split(':'); $n = [int]$p[1]; $mask = [Convert]::ToInt32($p[2], 16)
                if ($raw -is [byte[]] -and $raw.Length -gt $n) {
                    $set = ($raw[$n] -band $mask) -ne 0
                    if ($set -eq ($alt -eq '1')) { return $true }
                }
            }
            default {
                $want = if ($alt -eq '""') { '' } else { $alt }
                if ([string]$raw -eq $want) { return $true }
            }
        }
    }
    return $false
}

# Scrive la prima alternativa della specifica.
function Set-CatValue($op, [string]$spec) {
    $path = $op[0]; $name = $op[1]; $type = $op[2]
    $val = $spec.Split(',')[0]
    if ($type -eq 'Key') {
        if ($val -eq '+') { $k = Get-CatKey $path $true; if ($k.Key) { $k.Key.Close() } }
        else {
            $k = Get-CatKey $path $false
            if ($null -ne $k.Key) { $k.Key.Close(); $k.Base.DeleteSubKeyTree($k.Sub, $false) }
        }
        return
    }
    if ($type -like 'Kv:*') {
        $pair = $type.Substring(3)
        $raw = [string](Get-CatRaw $path $name)
        $parts = @($raw.Split(';') | Where-Object { $_ -and -not $_.StartsWith("$pair=") })
        if ($val -ne '-') { $parts += "$pair=$val" }
        $k = Get-CatKey $path $true
        try { $k.Key.SetValue($name, (($parts -join ';') + ';'), [Microsoft.Win32.RegistryValueKind]::String) } finally { $k.Key.Close() }
        return
    }
    if ($val -eq '-') {
        $k = Get-CatKey $path $false
        if ($null -ne $k.Key) {
            $k.Key.Close()
            $k = Get-CatKey $path $true
            try { $k.Key.DeleteValue($name, $false) } finally { $k.Key.Close() }
        }
        return
    }
    if ($type -like 'Byte:*' -or $type -like 'Bit:*') {
        $raw = Get-CatRaw $path $name
        if (-not ($raw -is [byte[]])) { throw "valore binario assente" }
        $p = $type.Split(':'); $n = [int]$p[1]
        if ($type -like 'Byte:*') { $raw[$n] = [byte][int]$val }
        else {
            $mask = [Convert]::ToInt32($p[2], 16)
            if ($val -eq '1') { $raw[$n] = [byte]($raw[$n] -bor $mask) } else { $raw[$n] = [byte]($raw[$n] -band (-bnot $mask) -band 0xFF) }
        }
        $k = Get-CatKey $path $true
        try { $k.Key.SetValue($name, [byte[]]$raw, [Microsoft.Win32.RegistryValueKind]::Binary) } finally { $k.Key.Close() }
        return
    }
    $k = Get-CatKey $path $true
    try {
        switch ($type) {
            'D' {
                # Valori negativi o oltre 2^31 (es. -1 = FFFFFFFF) vanno passati come int32 con gli stessi bit.
                $u = [uint32]([int64]$val -band 4294967295L)
                $k.Key.SetValue($name, [BitConverter]::ToInt32([BitConverter]::GetBytes($u), 0), [Microsoft.Win32.RegistryValueKind]::DWord)
            }
            'Q' { $k.Key.SetValue($name, [int64]$val, [Microsoft.Win32.RegistryValueKind]::QWord) }
            'B' { $k.Key.SetValue($name, [byte[]](ConvertTo-CatBytes $val), [Microsoft.Win32.RegistryValueKind]::Binary) }
            'E' { $k.Key.SetValue($name, $val, [Microsoft.Win32.RegistryValueKind]::ExpandString) }
            default {
                $s = if ($val -eq '""') { '' } else { $val }
                $kind = if ($s -match '%\w+%') { [Microsoft.Win32.RegistryValueKind]::ExpandString } else { [Microsoft.Win32.RegistryValueKind]::String }
                $k.Key.SetValue($name, $s, $kind)
            }
        }
    } finally { $k.Key.Close() }
}

# --- servizi, attivita' pianificate, piano energetico ---
function Get-CatServiceMode([string]$svc) {
    $start = Get-CatRaw "HKLM\SYSTEM\CurrentControlSet\Services\$svc" 'Start'
    if ($null -eq $start) { return $null }
    switch ([int]$start) {
        2 { if ((Get-CatRaw "HKLM\SYSTEM\CurrentControlSet\Services\$svc" 'DelayedAutostart') -eq 1) { return 'AD' } else { return 'A' } }
        3 { return 'M' }
        4 { return 'X' }
        default { return 'A' }
    }
}

function Set-CatServiceMode([string]$svc, [string]$mode) {
    $arg = switch ($mode) { 'A' { 'auto' } 'AD' { 'delayed-auto' } 'M' { 'demand' } default { 'disabled' } }
    $out = & sc.exe config $svc start= $arg 2>&1
    if ($LASTEXITCODE -ne 0) {
        # Alcuni servizi protetti rifiutano sc.exe: si scrive il registro, vale dal riavvio.
        $n = switch ($mode) { 'M' { 3 } 'X' { 4 } default { 2 } }
        Set-CatValue @("HKLM\SYSTEM\CurrentControlSet\Services\$svc", 'Start', 'D') "$n"
        Set-CatValue @("HKLM\SYSTEM\CurrentControlSet\Services\$svc", 'DelayedAutostart', 'D') $(if ($mode -eq 'AD') { '1' } else { '-' })
    }
}

$script:TaskService = $null
function Get-CatTask([string]$full) {
    if ($null -eq $script:TaskService) {
        $script:TaskService = New-Object -ComObject Schedule.Service
        $script:TaskService.Connect()
    }
    $i = $full.LastIndexOf('\')
    $folder = if ($i -le 0) { '\' } else { $full.Substring(0, $i) }
    try { return $script:TaskService.GetFolder($folder).GetTask($full.Substring($i + 1)) } catch { return $null }
}

function Get-ActiveSchemeGuid {
    $ptr = [IntPtr]::Zero
    if ([TweakAndrew.PowerApi]::PowerGetActiveScheme([IntPtr]::Zero, [ref]$ptr) -ne 0) { return $null }
    try { return [System.Runtime.InteropServices.Marshal]::PtrToStructure($ptr, [type][guid]) }
    finally { [TweakAndrew.PowerApi]::LocalFree($ptr) | Out-Null }
}

function Get-CatPowerValue($it) {
    $scheme = Get-ActiveSchemeGuid
    if ($null -eq $scheme) { return $null }
    $sub = [guid]$it.Sub; $set = [guid]$it.Set; $v = [uint32]0
    if ([TweakAndrew.PowerApi]::PowerReadACValueIndex([IntPtr]::Zero, [ref]$scheme, [ref]$sub, [ref]$set, [ref]$v) -ne 0) { return $null }
    return [string]$v
}

function Set-CatPowerValue($it, [string]$value) {
    $scheme = Get-ActiveSchemeGuid
    $sub = [guid]$it.Sub; $set = [guid]$it.Set
    $r1 = [TweakAndrew.PowerApi]::PowerWriteACValueIndex([IntPtr]::Zero, [ref]$scheme, [ref]$sub, [ref]$set, [uint32]$value)
    $r2 = [TweakAndrew.PowerApi]::PowerWriteDCValueIndex([IntPtr]::Zero, [ref]$scheme, [ref]$sub, [ref]$set, [uint32]$value)
    [TweakAndrew.PowerApi]::PowerSetActiveScheme([IntPtr]::Zero, [ref]$scheme) | Out-Null
    if ($r1 -ne 0 -and $r2 -ne 0) { throw "powrprof ha restituito $r1" }
}

# --- stato di una voce: $true/$false per gli interruttori, la chiave per i menu ---
function Get-CatState($it) {
    switch ($it.Kind) {
        'T' {
            foreach ($op in $it.Ops) { if (-not (Test-CatValue $op $op[3])) { return $false } }
            return $true
        }
        'S' {
            foreach ($o in $it.Opts) {
                $ok = $true
                for ($i = 0; $i -lt $it.Ops.Count; $i++) { if (-not (Test-CatValue $it.Ops[$i] $o.Vals[$i])) { $ok = $false; break } }
                if ($ok) { return $o.Key }
            }
            return $null
        }
        'V' { return (Get-CatServiceMode $it.Svcs[0]) }
        'J' {
            $any = $false
            foreach ($t in $it.Tasks) { $task = Get-CatTask $t; if ($null -ne $task) { $any = $true; if (-not $task.Enabled) { return $false } } }
            if (-not $any) { return $null }
            return $true
        }
        'N' { return (Get-CatPowerValue $it) }
    }
}

# Porta la voce allo stato richiesto e scrive una riga nel registro operazioni.
function Set-CatState($it, $state) {
    $label = Get-Text $script:CatText[$it.Id]
    try {
        switch ($it.Kind) {
            'T' { foreach ($op in $it.Ops) { Set-CatValue $op $(if ($state) { $op[3] } else { $op[4] }) } }
            'S' {
                $o = $it.Opts | Where-Object { $_.Key -eq $state } | Select-Object -First 1
                for ($i = 0; $i -lt $it.Ops.Count; $i++) { Set-CatValue $it.Ops[$i] $o.Vals[$i] }
            }
            'V' { foreach ($s in $it.Svcs) { if ($null -ne (Get-CatServiceMode $s)) { Set-CatServiceMode $s $state } } }
            'J' { foreach ($t in $it.Tasks) { $task = Get-CatTask $t; if ($null -ne $task) { $task.Enabled = [bool]$state } } }
            'N' { Set-CatPowerValue $it ([string]$state) }
        }
        $shown = if ($state -is [bool]) { if ($state) { 'ON' } else { 'OFF' } } else { Get-CatText "$($it.Id)#$state" }
        Write-Log "[OK] $label - $shown"
        if ($it.Flags -match 'X') { $script:CatNeedsExplorer = $true }
        return $true
    } catch {
        Write-Log "[ERRORE] $label - $($_.Exception.Message)"
        return $false
    }
}

# --- disegno ---
function New-CatBrush([string]$hex) { return (New-Object System.Windows.Media.SolidColorBrush ([System.Windows.Media.ColorConverter]::ConvertFromString($hex))) }

function Set-CatTooltip($el, $it, $page) {
    $text = Get-Text $script:CatTip[$it.Id]
    if (-not $text) { return }
    $tt = New-Object System.Windows.Controls.ToolTip
    $tt.Content = $text
    $pa = $page.TryFindResource('PA')
    if ($null -ne $pa) { $tt.Resources['PA'] = $pa }
    $el.ToolTip = $tt
    [System.Windows.Controls.ToolTipService]::SetInitialShowDelay($el, 450)
    [System.Windows.Controls.ToolTipService]::SetShowDuration($el, 30000)
}

function Update-CatRow($row) {
    $script:CatLoading = $true
    try {
        $state = Get-CatState $row.Item
        if ($row.Item.Kind -in @('T','J')) {
            if ($null -eq $state) { $row.Control.IsEnabled = $false; $row.Control.IsChecked = $false }
            else { $row.Control.IsChecked = [bool]$state }
        } else {
            $combo = $row.Control
            if ($null -eq $state) {
                if ($row.Item.Kind -eq 'V') {
                    # Servizio assente su questo PC: lo si dice invece di lasciare la casella vuota.
                    $na = @($combo.Items | Where-Object { [string]$_.Tag -eq '_na' }) | Select-Object -First 1
                    if ($null -eq $na) { $na = New-Object System.Windows.Controls.ComboBoxItem; $na.Tag = '_na'; $na.Content = T 'svcMissing'; [void]$combo.Items.Add($na) }
                    $combo.IsEnabled = $false; $combo.SelectedItem = $na; return
                }
                # Nessuna opzione corrisponde ai valori attuali: si mostra «Personalizzato».
                $state = 'custom'
            }
            $match = $null
            foreach ($ci in $combo.Items) { if ([string]$ci.Tag -eq [string]$state) { $match = $ci } }
            if ($null -eq $match) {
                # Valore fuori dall'elenco: lo mostriamo com'e', senza toccarlo.
                $match = New-Object System.Windows.Controls.ComboBoxItem
                $match.Tag = [string]$state
                $match.Content = if ($state -eq 'custom') { T 'catCustom' } else { "$(T 'catCustom') ($state)" }
                [void]$combo.Items.Add($match)
            }
            $combo.SelectedItem = $match
        }
    } finally { $script:CatLoading = $false }
}

function Get-CatOptions($it) {
    if ($it.Kind -eq 'V') {
        return @(
            @{ Key = 'A';  Text = (T 'svcAuto') },
            @{ Key = 'AD'; Text = (T 'svcAutoDelayed') },
            @{ Key = 'M';  Text = (T 'svcManual') },
            @{ Key = 'X';  Text = (T 'svcDisabled') }
        )
    }
    return @($it.Opts | ForEach-Object { @{ Key = $_.Key; Text = (Get-CatText "$($it.Id)#$($_.Key)") } })
}

function New-CatRow($it, $page) {
    $grid = New-Object System.Windows.Controls.Grid
    $c0 = New-Object System.Windows.Controls.ColumnDefinition; $c0.Width = [System.Windows.GridLength]::Auto
    $c1 = New-Object System.Windows.Controls.ColumnDefinition; $c1.Width = New-Object System.Windows.GridLength(1, [System.Windows.GridUnitType]::Star)
    $grid.ColumnDefinitions.Add($c0); $grid.ColumnDefinitions.Add($c1)
    $label = Get-CatText $it.Id

    # Pallino del livello consigliato e sigla IA, solo nella privacy avanzata.
    if ($it.Page -eq 'priv') {
        $badges = New-Object System.Windows.Controls.StackPanel
        $badges.Orientation = 'Horizontal'; $badges.VerticalAlignment = 'Center'; $badges.Margin = '10,0,0,0'
        $dot = New-Object System.Windows.Shapes.Ellipse
        $dot.Width = 8; $dot.Height = 8
        $dot.Fill = New-CatBrush $(switch ($it.Rec) { 'y' { '#FF2ED3A7' } 'l' { '#FFE0A25E' } default { '#FFF87171' } })
        $dot.ToolTip = T $(switch ($it.Rec) { 'y' { 'recYes' } 'l' { 'recLimited' } default { 'recNo' } })
        [void]$badges.Children.Add($dot)
        $ai = New-Object System.Windows.Controls.Border
        $ai.Width = 22; $ai.Height = 15; $ai.CornerRadius = 4; $ai.Margin = '6,0,0,0'
        if ($it.Flags -match 'A') {
            $ai.Background = New-CatBrush '#2438BDF8'
            $t = New-Object System.Windows.Controls.TextBlock
            $t.Text = T 'aiTag'; $t.FontSize = 9.5; $t.FontWeight = 'Bold'; $t.Foreground = New-CatBrush '#FF7DD3FC'
            $t.HorizontalAlignment = 'Center'; $t.VerticalAlignment = 'Center'
            $ai.Child = $t
            $ai.ToolTip = T 'aiRelevant'
        }
        [void]$badges.Children.Add($ai)
        [System.Windows.Controls.Grid]::SetColumn($badges, 0)
        [void]$grid.Children.Add($badges)
    }

    if ($it.Kind -in @('T','J')) {
        $cb = New-Object System.Windows.Controls.CheckBox
        $cb.Content = $label
        $cb.Tag = $it.Id
        [System.Windows.Controls.Grid]::SetColumn($cb, 1)
        [void]$grid.Children.Add($cb)
        $ctl = $cb
        $handler = {
            if ($script:CatLoading) { return }
            $item = $script:CatById[[string]$this.Tag]
            [void](Set-CatState $item ($this.IsChecked -eq $true))
            $r = $script:CatRows | Where-Object { $_.Control -eq $this } | Select-Object -First 1
            if ($r) { Update-CatRow $r }
            Update-CatExplorerHint
        }
        $cb.Add_Checked($handler); $cb.Add_Unchecked($handler)
    } else {
        $inner = New-Object System.Windows.Controls.Grid
        $inner.Margin = '10,4,10,4'
        $ic0 = New-Object System.Windows.Controls.ColumnDefinition; $ic0.Width = New-Object System.Windows.GridLength(1, [System.Windows.GridUnitType]::Star)
        $ic1 = New-Object System.Windows.Controls.ColumnDefinition; $ic1.Width = [System.Windows.GridLength]::Auto
        $inner.ColumnDefinitions.Add($ic0); $inner.ColumnDefinitions.Add($ic1)
        $tb = New-Object System.Windows.Controls.TextBlock
        $tb.Text = $label; $tb.TextWrapping = 'Wrap'; $tb.VerticalAlignment = 'Center'; $tb.Margin = '0,0,12,0'
        $tb.Foreground = New-CatBrush '#FFC4C4CC'; $tb.FontSize = 12.5
        $tb.FontFamily = New-Object System.Windows.Media.FontFamily('Roboto, Segoe UI Variable Text, Segoe UI')
        [void]$inner.Children.Add($tb)
        $combo = New-Object System.Windows.Controls.ComboBox
        $combo.Width = 210; $combo.Tag = $it.Id; $combo.VerticalAlignment = 'Center'
        foreach ($o in (Get-CatOptions $it)) {
            $ci = New-Object System.Windows.Controls.ComboBoxItem
            $ci.Tag = $o.Key; $ci.Content = $o.Text
            [void]$combo.Items.Add($ci)
        }
        [System.Windows.Controls.Grid]::SetColumn($combo, 1)
        [void]$inner.Children.Add($combo)
        [System.Windows.Controls.Grid]::SetColumn($inner, 1)
        [void]$grid.Children.Add($inner)
        $ctl = $combo
        $combo.Add_SelectionChanged({
            if ($script:CatLoading) { return }
            $sel = $this.SelectedItem
            if ($null -eq $sel -or [string]$sel.Tag -eq '_na' -or [string]$sel.Content -like "$(T 'catCustom')*") { return }
            $item = $script:CatById[[string]$this.Tag]
            [void](Set-CatState $item ([string]$sel.Tag))
            $r = $script:CatRows | Where-Object { $_.Control -eq $this } | Select-Object -First 1
            if ($r) { Update-CatRow $r }
            Update-CatExplorerHint
        })
        $tb.Tag = 'label'
    }
    Set-CatTooltip $grid $it $page
    $row = [pscustomobject]@{ Item = $it; Control = $ctl; Element = $grid; Label = $label; Card = $null }
    [void]$script:CatRows.Add($row)
    Update-CatRow $row
    return $row
}

function New-CatCard([string]$title) {
    $card = New-Object System.Windows.Controls.Border
    $card.Style = $window.FindResource('Glass')
    $sp = New-Object System.Windows.Controls.StackPanel
    $h = New-Object System.Windows.Controls.TextBlock
    $h.Text = $title.ToUpper(); $h.Style = $window.FindResource('CardTitle')
    [void]$sp.Children.Add($h)
    $card.Child = $sp
    return @{ Card = $card; Panel = $sp }
}

function New-CatButton([string]$text, [string]$dot) {
    $b = New-Object System.Windows.Controls.Button
    $b.Style = $window.FindResource('DotBtn')
    $b.Margin = '0,0,8,8'
    $b.Content = $text
    if ($dot) { $b.Tag = New-CatBrush $dot }
    return $b
}

# Applica lo stesso stato a molte voci, con una sola conferma.
function Invoke-CatBulk([string]$page, [scriptblock]$pick, [string]$question) {
    if (-not (Show-Dialog -Title (T 'catBulkTitle') -Message $question -Kind 'warn')) { return }
    $script:OkCount = 0; $script:WarnCount = 0; $script:SkipCount = 0
    $rows = @($script:CatRows | Where-Object { $_.Item.Page -eq $page })
    $n = 0
    foreach ($r in $rows) {
        $n++
        $target = & $pick $r.Item
        if ($null -eq $target) { continue }
        $now = Get-CatState $r.Item
        if ($null -eq $now) { continue }
        if ([string]$now -eq [string]$target) { $script:SkipCount++; continue }
        Update-Progress -Current $n -Total $rows.Count -Label (Get-CatText $r.Item.Id)
        [void](Set-CatState $r.Item $target)
    }
    foreach ($r in $rows) { Update-CatRow $r }
    Update-Progress -Current $rows.Count -Total $rows.Count -Label ''
    Show-RunSummary
    Update-CatExplorerHint
}

function Get-CatRecTarget($it) {
    if ($it.Rec -eq '-' -or [string]::IsNullOrEmpty($it.Rec)) { return $null }
    if ($it.Kind -in @('T','J')) { return ($it.Rec -eq '1') }
    return $it.Rec
}
function Get-CatDefTarget($it) {
    if ($it.Kind -in @('T','J')) { return ($it.Def -eq '1') }
    if ($it.Page -eq 'priv') { return ($it.Def -eq '1') }
    return $it.Def
}

$script:CatNeedsExplorer = $false
$script:CatExplorerButtons = @()
function Update-CatExplorerHint {
    foreach ($b in $script:CatExplorerButtons) {
        $b.Tag = if ($script:CatNeedsExplorer) { New-CatBrush '#FFFFB86B' } else { $null }
    }
}

function Restart-Explorer {
    Get-Process -Name explorer -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
    Start-Sleep -Milliseconds 700
    if (-not (Get-Process -Name explorer -ErrorAction SilentlyContinue)) { Start-Process explorer.exe }
    $script:CatNeedsExplorer = $false
    Write-Log "[OK] Esplora risorse riavviato."
}

function Update-CatFilter([string]$page) {
    $box = $script:CatSearch[$page]
    $q = if ($box) { $box.Text.Trim() } else { '' }
    foreach ($card in $script:CatCards[$page]) {
        $visible = 0
        foreach ($r in $card.Rows) {
            $ok = (-not $q) -or ($r.Label -like "*$q*")
            if ($page -eq 'priv' -and $script:CatScope -ne 'all') { $ok = $ok -and ($r.Item.Flags -match $script:CatScope) }
            $r.Element.Visibility = if ($ok) { 'Visible' } else { 'Collapsed' }
            if ($ok) { $visible++ }
        }
        $card.Card.Visibility = if ($visible -gt 0) { 'Visible' } else { 'Collapsed' }
    }
}

$script:CatSearch = @{}
$script:CatCards = @{}

# Costruisce una pagina del catalogo dentro il contenitore indicato.
function Initialize-CatPage([string]$page, $hostEl, [bool]$embedded = $false) {
    if ($null -eq $hostEl) { return }
    $old = @($script:CatRows | Where-Object { $_.Item.Page -eq $page })
    foreach ($o in $old) { $script:CatRows.Remove($o) }
    $hostEl.Children.Clear()
    $script:CatCards[$page] = @()

    $root = New-Object System.Windows.Controls.Grid
    $r0 = New-Object System.Windows.Controls.RowDefinition; $r0.Height = [System.Windows.GridLength]::Auto
    $r1 = New-Object System.Windows.Controls.RowDefinition; $r1.Height = New-Object System.Windows.GridLength(1, [System.Windows.GridUnitType]::Star)
    $root.RowDefinitions.Add($r0); $root.RowDefinitions.Add($r1)

    # Barra degli strumenti: ricerca e azioni sull'intera pagina.
    $bar = New-Object System.Windows.Controls.WrapPanel
    $bar.Margin = '7,0,7,6'
    $search = New-Object System.Windows.Controls.TextBox
    $search.Width = 240; $search.Height = 34; $search.Margin = '0,0,12,8'; $search.Padding = '10,0'
    $search.VerticalContentAlignment = 'Center'
    $search.Tag = $page
    $hint = New-Object System.Windows.Controls.TextBlock
    $hint.Text = T 'catSearch'; $hint.Foreground = New-CatBrush '#FF6E6E78'; $hint.IsHitTestVisible = $false
    $hint.Margin = '12,0,0,0'; $hint.VerticalAlignment = 'Center'
    $sgrid = New-Object System.Windows.Controls.Grid
    $sgrid.Margin = '0,0,12,8'
    $search.Margin = '0'
    [void]$sgrid.Children.Add($search); [void]$sgrid.Children.Add($hint)
    $search.Add_TextChanged({
        $p = [string]$this.Tag
        $h = ($this.Parent.Children | Where-Object { $_ -is [System.Windows.Controls.TextBlock] } | Select-Object -First 1)
        if ($h) { $h.Visibility = if ($this.Text) { 'Collapsed' } else { 'Visible' } }
        Update-CatFilter $p
    })
    $script:CatSearch[$page] = $search
    if (-not $embedded) { [void]$bar.Children.Add($sgrid) }

    if ($page -eq 'priv') {
        foreach ($s in @(@{ K = 'U'; T = 'scopeUser' }, @{ K = 'M'; T = 'scopeMachine' }, @{ K = 'all'; T = 'scopeAll' })) {
            $rb = New-Object System.Windows.Controls.RadioButton
            $rb.Content = T $s.T; $rb.GroupName = 'CatScope'; $rb.Tag = $s.K
            $rb.Margin = '0,6,4,8'; $rb.VerticalAlignment = 'Center'
            if ($script:CatScope -eq $s.K) { $rb.IsChecked = $true }
            $rb.Add_Checked({ $script:CatScope = [string]$this.Tag; Update-CatFilter 'priv' })
            [void]$bar.Children.Add($rb)
        }
        $bar2 = New-Object System.Windows.Controls.WrapPanel
        $bar2.Margin = '7,0,7,6'
        $b1 = New-CatButton (T 'applyRecYes') '#FF2ED3A7'
        $b1.Add_Click({ Invoke-CatBulk 'priv' { param($i) if ($i.Rec -eq 'y') { $true } else { $null } } (T 'askRecYes') })
        $b2 = New-CatButton (T 'applyRecLimited') '#FFE0A25E'
        $b2.Add_Click({ Invoke-CatBulk 'priv' { param($i) if ($i.Rec -in @('y','l')) { $true } else { $null } } (T 'askRecLimited') })
        $b3 = New-CatButton (T 'applyRecAll') '#FFF87171'
        $b3.Add_Click({ Invoke-CatBulk 'priv' { param($i) $true } (T 'askRecAll') })
        $b4 = New-CatButton (T 'undoAllFactory') ''
        $b4.Add_Click({ Invoke-CatBulk 'priv' { param($i) Get-CatDefTarget $i } (T 'askFactory') })
        $b5 = New-CatButton (T 'makeRestorePoint') ''
        $b5.Add_Click({ New-TweakRestorePoint })
        foreach ($b in @($b1, $b2, $b3, $b4, $b5)) { [void]$bar2.Children.Add($b) }
        $legend = New-Object System.Windows.Controls.TextBlock
        $legend.Text = T 'privLegend'; $legend.Style = $window.FindResource('SubTitle'); $legend.Margin = '7,0,7,8'; $legend.TextWrapping = 'Wrap'
        $top = New-Object System.Windows.Controls.StackPanel
        [void]$top.Children.Add($bar); [void]$top.Children.Add($bar2); [void]$top.Children.Add($legend)
        [System.Windows.Controls.Grid]::SetRow($top, 0)
        [void]$root.Children.Add($top)
    } else {
        # In Alimentazione i pulsanti agiscono sul piano in uso e valgono subito: lo dicono le loro frasi.
        $pw = $page -eq 'power'
        $bRec = New-CatButton (T $(if ($pw) { 'pwRecBtn' } else { 'applyRecommended' })) '#FF2ED3A7'
        $bRec.DataContext = $page
        $bRec.Add_Click({ $p = [string]$this.DataContext; Invoke-CatBulk $p { param($i) Get-CatRecTarget $i } (T $(if ($p -eq 'power') { 'pwAskRec' } else { 'askRecommended' })) })
        $bDef = New-CatButton (T $(if ($pw) { 'pwDefBtn' } else { 'restoreWindows' })) ''
        $bDef.DataContext = $page
        $bDef.Add_Click({ $p = [string]$this.DataContext; Invoke-CatBulk $p { param($i) Get-CatDefTarget $i } (T $(if ($p -eq 'power') { 'pwAskDef' } else { 'askWindowsDefaults' })) })
        [void]$bar.Children.Add($bRec); [void]$bar.Children.Add($bDef)
        if (@($script:Catalog | Where-Object { $_.Page -eq $page -and $_.Flags -match 'X' }).Count -gt 0) {
            $bEx = New-CatButton (T 'restartExplorer') ''
            $bEx.Add_Click({ Restart-Explorer; Update-CatExplorerHint })
            $script:CatExplorerButtons += $bEx
            [void]$bar.Children.Add($bEx)
        }
        [System.Windows.Controls.Grid]::SetRow($bar, 0)
        [void]$root.Children.Add($bar)
    }

    # Due colonne di schede, riempite tenendo le altezze il piu' possibile pari.
    # Dentro Alimentazione le schede stanno in una colonna sola, accanto ai piani.
    $nCols = if ($embedded) { 1 } else { 2 }
    $cols = New-Object System.Windows.Controls.Grid
    foreach ($i in 0..($nCols - 1)) {
        $cd = New-Object System.Windows.Controls.ColumnDefinition
        $cd.Width = New-Object System.Windows.GridLength(1, [System.Windows.GridUnitType]::Star)
        $cols.ColumnDefinitions.Add($cd)
    }
    $stacks = @((New-Object System.Windows.Controls.StackPanel), (New-Object System.Windows.Controls.StackPanel))
    $heights = @(0, 0)
    for ($i = 0; $i -lt $nCols; $i++) { [System.Windows.Controls.Grid]::SetColumn($stacks[$i], $i); [void]$cols.Children.Add($stacks[$i]) }

    $items = @($script:Catalog | Where-Object { $_.Page -eq $page })
    $groups = @($items | ForEach-Object { $_.Group } | Select-Object -Unique)
    # Dove c'e' una disposizione fissa, le schede seguono l'argomento e non l'altezza.
    $layout = $script:CatLayout[$page]
    $fixed = @{}
    if ($layout) {
        for ($ci = 0; $ci -lt $layout.Count; $ci++) { foreach ($lg in $layout[$ci]) { $fixed[$lg] = [Math]::Min($ci, $nCols - 1) } }
        $groups = @(@($layout | ForEach-Object { $_ } | Where-Object { $groups -contains $_ }) + @($groups | Where-Object { -not $fixed.ContainsKey($_) }))
    }
    foreach ($g in $groups) {
        $gi = @($items | Where-Object { $_.Group -eq $g })
        $c = New-CatCard (Get-CatText "g.$page.$g")
        $rows = @()
        foreach ($it in $gi) {
            $row = New-CatRow $it $hostEl
            [void]$c.Panel.Children.Add($row.Element)
            $rows += $row
        }
        $col = if ($fixed.ContainsKey($g)) { $fixed[$g] } elseif ($nCols -eq 1 -or $heights[0] -le $heights[1]) { 0 } else { 1 }
        [void]$stacks[$col].Children.Add($c.Card)
        $heights[$col] += $gi.Count + 2
        $script:CatCards[$page] += @{ Card = $c.Card; Rows = $rows }
    }

    if ($embedded) {
        [System.Windows.Controls.Grid]::SetRow($cols, 1)
        [void]$root.Children.Add($cols)
    } else {
        $sv = New-Object System.Windows.Controls.ScrollViewer
        $sv.VerticalScrollBarVisibility = 'Auto'; $sv.Padding = '0,0,6,0'
        $sv.Content = $cols
        [System.Windows.Controls.Grid]::SetRow($sv, 1)
        [void]$root.Children.Add($sv)
    }
    [void]$hostEl.Children.Add($root)
    $script:CatBuilt[$page] = $script:LangCode
    Update-CatFilter $page
}

function New-TweakRestorePoint {
    try {
        Enable-ComputerRestore -Drive "$env:SystemDrive\" -ErrorAction SilentlyContinue
        # Windows accetta un punto ogni 24 ore: per crearne uno adesso si toglie il limite.
        Set-CatValue @('HKLM\SOFTWARE\Microsoft\Windows NT\CurrentVersion\SystemRestore', 'SystemRestorePointCreationFrequency', 'D') '0'
        Checkpoint-Computer -Description 'Tweak Andrew' -RestorePointType MODIFY_SETTINGS -ErrorAction Stop
        Write-Log "[OK] Punto di ripristino creato."
        $txtProgressLabel.Text = T 'restoreDone'
    } catch {
        Write-Log "[ERRORE] Punto di ripristino - $($_.Exception.Message)"
        $txtProgressLabel.Text = T 'restoreFail'
    }
}

# Disposizione delle schede: colonna sinistra, colonna destra. Le pagine che
# non compaiono qui riempiono le colonne pareggiando le altezze.
$script:CatLayout = @{
    exp   = @(@('gen'), @('ctx', 'nav', 'thispc', 'dev', 'desk'))
    task  = @(@('start'), @('bar'))
    notif = @(@('toast', 'tips', 'sys'), @('sound', 'access'))
    game  = @(@('gfx'), @('vfx'))
    win   = @(@('sec', 'upd', 'browser', 'tasks'), @('svc'))
    power = @(,@('cpu', 'sleep', 'dev', 'buttons', 'media'))
}

# Pagine del catalogo e contenitori: la pagina si costruisce quando la apri.
$script:CatHosts = @{
    exp   = (E 'catExp')
    task  = (E 'catTask')
    notif = (E 'catNotif')
    game  = (E 'catGame')
    win   = (E 'catWin')
    priv  = (E 'catPriv')
    power = (E 'catPower')
}

function Show-CatPageIfNeeded([string]$page) {
    if (-not $script:CatHosts.ContainsKey($page)) { return }
    if ($script:CatBuilt[$page] -eq $script:LangCode) { return }
    $txtProgressLabel.Text = T 'catLoading'
    [System.Windows.Threading.Dispatcher]::CurrentDispatcher.Invoke([Action]{}, [System.Windows.Threading.DispatcherPriority]::Background)
    Initialize-CatPage $page $script:CatHosts[$page] ($page -eq 'power')
    $txtProgressLabel.Text = T 'ready'
}
