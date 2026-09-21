# ------------------------------------------------------------------------------
# 29. APP E SOFTWARE: catalogo da installare e programmi installati
# ------------------------------------------------------------------------------
# Le installazioni passano da winget, il gestore di pacchetti di Windows: niente
# download da siti di terze parti. Le operazioni partono una alla volta in
# background e la finestra resta utilizzabile mentre lavorano.

$radAppsCatalog = E 'radAppsCatalog'; $radAppsInstalled = E 'radAppsInstalled'
$txtAppSearch = E 'txtAppSearch'; $lblAppSearchHint = E 'lblAppSearchHint'
$cmbAppCategory = E 'cmbAppCategory'; $cmbAppLicense = E 'cmbAppLicense'
$btnAppsAction = E 'btnAppsAction'; $btnAppsUpgrade = E 'btnAppsUpgrade'
$btnAppsClear = E 'btnAppsClear'; $btnAppsRefresh = E 'btnAppsRefresh'
$txtAppsStatus = E 'txtAppsStatus'; $panApps = E 'panApps'

$script:AppSel = New-Object 'System.Collections.Generic.HashSet[string]'
$script:AppInstalledIds = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
$script:AppInstalledList = @()
$script:AppJobs = New-Object System.Collections.Queue
$script:AppProc = $null
$script:AppJob = $null
$script:AppExport = $null
$script:AppsReady = $false
$script:Winget = $null
try { $script:Winget = (Get-Command winget.exe -ErrorAction Stop).Source } catch {}

$script:AppLicColors = @{
    os = @('#FF2ED3A7', '#262ED3A7'); fw = @('#FF7DD3FC', '#2638BDF8'); fr = @('#FFFDBA74', '#26FDBA74')
    ms = @('#FFA5B4FC', '#26818CF8'); pd = @('#FFF87171', '#26F87171')
}

function New-AppBrush([string]$hex) { New-Object System.Windows.Media.SolidColorBrush ([System.Windows.Media.ColorConverter]::ConvertFromString($hex)) }

function New-AppPill([string]$text, [string]$fg, [string]$bg) {
    $b = New-Object System.Windows.Controls.Border
    $b.CornerRadius = 6; $b.Padding = '7,2,7,2'; $b.Margin = '8,0,0,0'; $b.VerticalAlignment = 'Center'
    $b.Background = New-AppBrush $bg
    $t = New-Object System.Windows.Controls.TextBlock
    $t.Text = $text; $t.FontSize = 10.5; $t.FontWeight = 'SemiBold'; $t.Foreground = New-AppBrush $fg
    $b.Child = $t
    return $b
}

# Riga di un'app: nome e descrizione a sinistra, etichette e interruttore a destra.
function New-AppRow([string]$key, [string]$title, [string]$sub, [array]$pills) {
    $g = New-Object System.Windows.Controls.Grid
    $g.Margin = '10,5,0,5'
    foreach ($w in @('*', 'Auto', 'Auto')) {
        $cd = New-Object System.Windows.Controls.ColumnDefinition
        $cd.Width = if ($w -eq '*') { New-Object System.Windows.GridLength(1, [System.Windows.GridUnitType]::Star) } else { [System.Windows.GridLength]::Auto }
        $g.ColumnDefinitions.Add($cd)
    }
    $sp = New-Object System.Windows.Controls.StackPanel; $sp.VerticalAlignment = 'Center'
    $t1 = New-Object System.Windows.Controls.TextBlock
    $t1.Text = $title; $t1.FontSize = 13; $t1.FontWeight = 'SemiBold'; $t1.Foreground = New-AppBrush '#FFE8E8EE'; $t1.TextTrimming = 'CharacterEllipsis'
    $t2 = New-Object System.Windows.Controls.TextBlock
    $t2.Text = $sub; $t2.FontSize = 11.5; $t2.Foreground = New-AppBrush '#FF8E8E98'; $t2.TextWrapping = 'Wrap'; $t2.Margin = '0,2,0,0'
    [void]$sp.Children.Add($t1); if ($sub) { [void]$sp.Children.Add($t2) }
    [void]$g.Children.Add($sp)
    $pp = New-Object System.Windows.Controls.StackPanel; $pp.Orientation = 'Horizontal'; $pp.VerticalAlignment = 'Center'
    foreach ($p in $pills) { [void]$pp.Children.Add($p) }
    [System.Windows.Controls.Grid]::SetColumn($pp, 1); [void]$g.Children.Add($pp)
    $cb = New-Object System.Windows.Controls.CheckBox
    $cb.Content = ''; $cb.Tag = $key; $cb.Margin = '4,0,0,0'; $cb.HorizontalAlignment = 'Right'; $cb.Width = 64
    $cb.IsChecked = $script:AppSel.Contains($key)
    $cb.Add_Checked({ [void]$script:AppSel.Add([string]$this.Tag); Update-AppButtons })
    $cb.Add_Unchecked({ [void]$script:AppSel.Remove([string]$this.Tag); Update-AppButtons })
    [System.Windows.Controls.Grid]::SetColumn($cb, 2); [void]$g.Children.Add($cb)
    return $g
}

function New-AppCard([string]$title) {
    $card = New-Object System.Windows.Controls.Border
    $card.Style = $window.FindResource('Glass')
    $sp = New-Object System.Windows.Controls.StackPanel
    $h = New-Object System.Windows.Controls.TextBlock
    $h.Text = $title.ToUpper(); $h.Style = $window.FindResource('CardTitle')
    [void]$sp.Children.Add($h)
    $card.Child = $sp
    return @{ Card = $card; Panel = $sp }
}

function Get-AppFilterText { return $txtAppSearch.Text.Trim() }

function Show-AppCatalog {
    $panApps.Children.Clear()
    $grid = New-Object System.Windows.Controls.Grid
    foreach ($i in 0..1) { $cd = New-Object System.Windows.Controls.ColumnDefinition; $cd.Width = New-Object System.Windows.GridLength(1, [System.Windows.GridUnitType]::Star); $grid.ColumnDefinitions.Add($cd) }
    $cols = @((New-Object System.Windows.Controls.StackPanel), (New-Object System.Windows.Controls.StackPanel))
    for ($i = 0; $i -lt 2; $i++) { [System.Windows.Controls.Grid]::SetColumn($cols[$i], $i); [void]$grid.Children.Add($cols[$i]) }
    $h = @(0, 0)
    $q = Get-AppFilterText
    $cat = if ($cmbAppCategory.SelectedItem) { [string]$cmbAppCategory.SelectedItem.Tag } else { '' }
    $lic = if ($cmbAppLicense.SelectedItem) { [string]$cmbAppLicense.SelectedItem.Tag } else { '' }
    $shown = 0
    foreach ($c in $script:AppCategories) {
        if ($cat -and $c.Key -ne $cat) { continue }
        $apps = @($script:AppCatalog | Where-Object {
            $_.Cat -eq $c.Key -and (-not $lic -or $_.Lic -eq $lic) -and
            (-not $q -or $_.Name -like "*$q*" -or (Get-Text $_.Desc) -like "*$q*")
        })
        if ($apps.Count -eq 0) { continue }
        $card = New-AppCard (T "appCat_$($c.Key)")
        foreach ($a in $apps) {
            $col = $script:AppLicColors[$a.Lic]
            $pills = @(New-AppPill (T "lic_$($a.Lic)") $col[0] $col[1])
            $wid = $a.Id -replace '^store:', ''
            if ($script:AppInstalledIds.Contains($wid)) { $pills += New-AppPill (T 'appInstalled') '#FF2ED3A7' '#1A2ED3A7' }
            [void]$card.Panel.Children.Add((New-AppRow $a.Id $a.Name (Get-Text $a.Desc) $pills))
            $shown++
        }
        $k = if ($h[0] -le $h[1]) { 0 } else { 1 }
        [void]$cols[$k].Children.Add($card.Card)
        $h[$k] += $apps.Count + 2
    }
    [void]$panApps.Children.Add($grid)
    if ($shown -eq 0) { $txtAppsStatus.Text = T 'appsNone' }
}

# Programmi installati: registro di disinstallazione e app dello Store.
function Get-InstalledApps {
    $list = New-Object System.Collections.ArrayList
    $roots = @(
        'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall',
        'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall',
        'HKCU:\Software\Microsoft\Windows\CurrentVersion\Uninstall'
    )
    $seen = @{}
    foreach ($r in $roots) {
        foreach ($k in @(Get-ChildItem -LiteralPath $r -ErrorAction SilentlyContinue)) {
            $p = Get-ItemProperty -LiteralPath $k.PSPath -ErrorAction SilentlyContinue
            if (-not $p.DisplayName -or -not $p.UninstallString) { continue }
            if ($p.SystemComponent -eq 1 -or $p.ParentKeyName -or $p.ReleaseType -in @('Update','Hotfix','Security Update')) { continue }
            $sig = "$($p.DisplayName)|$($p.DisplayVersion)"
            if ($seen.ContainsKey($sig)) { continue }
            $seen[$sig] = $true
            [void]$list.Add([pscustomobject]@{
                Key = "w:$($k.PSPath)"; Name = [string]$p.DisplayName; Version = [string]$p.DisplayVersion
                Publisher = [string]$p.Publisher; Kind = 'Win32'
                Uninstall = [string]$p.UninstallString; Quiet = [string]$p.QuietUninstallString; Pkg = ''
            })
        }
    }
    try {
        foreach ($a in @(Get-AppxPackage -PackageTypeFilter Main -ErrorAction Stop | Where-Object { -not $_.NonRemovable -and $_.SignatureKind -ne 'System' })) {
            # Il nome leggibile sta nel manifest; se e' una risorsa da tradurre si ripiega
            # sul nome del pacchetto senza il prefisso dell'editore.
            $name = ([string]$a.Name -replace '^[0-9A-F]+[A-Za-z]*\.', '')
            $pub = ''
            try {
                [xml]$mf = [IO.File]::ReadAllText((Join-Path $a.InstallLocation 'AppxManifest.xml'))
                $dn = [string]$mf.Package.Properties.DisplayName
                $pd = [string]$mf.Package.Properties.PublisherDisplayName
                if ($dn -and $dn -notlike 'ms-resource:*') { $name = $dn }
                if ($pd -and $pd -notlike 'ms-resource:*') { $pub = $pd }
            } catch {}
            [void]$list.Add([pscustomobject]@{
                Key = "x:$($a.PackageFullName)"; Name = $name; Version = [string]$a.Version
                Publisher = $pub; Kind = 'Store'
                Uninstall = ''; Quiet = ''; Pkg = [string]$a.PackageFullName
            })
        }
    } catch {}
    return @($list | Sort-Object Name)
}

function Show-AppInstalled {
    $panApps.Children.Clear()
    $q = Get-AppFilterText
    $card = New-AppCard ((T 'appsInstalledTitle') -f $script:AppInstalledList.Count)
    foreach ($a in $script:AppInstalledList) {
        if ($q -and $a.Name -notlike "*$q*" -and $a.Publisher -notlike "*$q*") { continue }
        $sub = (@($a.Version, $a.Publisher) | Where-Object { $_ }) -join '  ·  '
        $pill = if ($a.Kind -eq 'Store') { New-AppPill 'Store' '#FFA5B4FC' '#26818CF8' } else { New-AppPill 'Win32' '#FFC4C4CC' '#1FFFFFFF' }
        [void]$card.Panel.Children.Add((New-AppRow $a.Key $a.Name $sub @($pill)))
    }
    [void]$panApps.Children.Add($card.Card)
}

function Update-AppButtons {
    $n = $script:AppSel.Count
    $label = if ($radAppsInstalled.IsChecked) { T 'appsUninstallSel' } else { T 'appsInstallSel' }
    $btnAppsAction.Content = if ($n -gt 0) { "$label ($n)" } else { $label }
    $busy = ($null -ne $script:AppProc) -or ($script:AppJobs.Count -gt 0)
    $btnAppsAction.IsEnabled = ($n -gt 0) -and -not $busy -and ($radAppsInstalled.IsChecked -or $script:Winget)
    $btnAppsUpgrade.IsEnabled = ($null -ne $script:Winget) -and -not $busy
    $btnAppsAction.Tag = if ($radAppsInstalled.IsChecked) { New-AppBrush '#FFF87171' } else { New-AppBrush '#FF2ED3A7' }
}

function Show-AppView {
    if ($radAppsInstalled.IsChecked) {
        $cmbAppCategory.Visibility = 'Collapsed'; $cmbAppLicense.Visibility = 'Collapsed'
        if ($script:AppInstalledList.Count -eq 0) { $script:AppInstalledList = Get-InstalledApps }
        Show-AppInstalled
    } else {
        $cmbAppCategory.Visibility = 'Visible'; $cmbAppLicense.Visibility = 'Visible'
        Show-AppCatalog
    }
    Update-AppButtons
}

function Initialize-AppFilters {
    $keepCat = if ($cmbAppCategory.SelectedItem) { [string]$cmbAppCategory.SelectedItem.Tag } else { '' }
    $keepLic = if ($cmbAppLicense.SelectedItem) { [string]$cmbAppLicense.SelectedItem.Tag } else { '' }
    $script:AppFiltersLoading = $true
    $cmbAppCategory.Items.Clear(); $cmbAppLicense.Items.Clear()
    $all = New-Object System.Windows.Controls.ComboBoxItem; $all.Tag = ''; $all.Content = T 'appsAllCategories'; [void]$cmbAppCategory.Items.Add($all)
    foreach ($c in $script:AppCategories) {
        $ci = New-Object System.Windows.Controls.ComboBoxItem; $ci.Tag = $c.Key; $ci.Content = T "appCat_$($c.Key)"
        [void]$cmbAppCategory.Items.Add($ci)
        if ($c.Key -eq $keepCat) { $cmbAppCategory.SelectedItem = $ci }
    }
    if ($null -eq $cmbAppCategory.SelectedItem) { $cmbAppCategory.SelectedIndex = 0 }
    foreach ($l in @('', 'os', 'fw', 'fr', 'ms', 'pd')) {
        $ci = New-Object System.Windows.Controls.ComboBoxItem; $ci.Tag = $l
        $ci.Content = if ($l) { T "lic_$l" } else { T 'appsAllLicenses' }
        [void]$cmbAppLicense.Items.Add($ci)
        if ($l -eq $keepLic) { $cmbAppLicense.SelectedItem = $ci }
    }
    $script:AppFiltersLoading = $false
}

# --- esecuzione in background, un processo alla volta ---
function Add-AppJob([string]$label, [string]$file, [string]$arguments) {
    $script:AppJobs.Enqueue(@{ Label = $label; File = $file; Args = $arguments })
}

$script:AppTimer = New-Object System.Windows.Threading.DispatcherTimer
$script:AppTimer.Interval = [TimeSpan]::FromMilliseconds(600)
$script:AppTimer.Add_Tick({
    if ($null -ne $script:AppExport -and $script:AppExport.HasExited) { Complete-AppExport }
    if ($null -ne $script:AppProc) {
        if (-not $script:AppProc.HasExited) { return }
        $code = $script:AppProc.ExitCode
        # -1978335189 e -1978335135: gia' installato o nessun aggiornamento, non sono errori.
        if ($code -eq 0 -or $code -eq -1978335189 -or $code -eq -1978335135) { Write-Log "[OK] $($script:AppJob.Label)" }
        else { Write-Log "[ERRORE] $($script:AppJob.Label) - codice $code" }
        $script:AppProc = $null
    }
    if ($script:AppJobs.Count -gt 0) {
        $script:AppJob = $script:AppJobs.Dequeue()
        $txtAppsStatus.Text = (T 'appsWorking') -f $script:AppJob.Label, $script:AppJobs.Count
        try {
            $psi = New-Object System.Diagnostics.ProcessStartInfo
            $psi.FileName = $script:AppJob.File; $psi.Arguments = $script:AppJob.Args
            $psi.UseShellExecute = $false; $psi.CreateNoWindow = $true
            $script:AppProc = [System.Diagnostics.Process]::Start($psi)
        } catch {
            Write-Log "[ERRORE] $($script:AppJob.Label) - $($_.Exception.Message)"
            $script:AppProc = $null
        }
        Update-AppButtons
        return
    }
    if ($null -eq $script:AppExport) {
        $script:AppTimer.Stop()
        if ($script:AppJob) {
            $script:AppJob = $null
            $txtAppsStatus.Text = T 'appsDone'
            $script:AppInstalledList = @()
            Start-AppExport
            Show-AppView
        }
    }
    Update-AppButtons
})

# Elenco degli id winget installati: winget export scrive un file JSON.
function Start-AppExport {
    if (-not $script:Winget -or $null -ne $script:AppExport) { return }
    $script:AppExportFile = Join-Path $env:TEMP 'TweakAndrew_winget.json'
    Remove-Item -LiteralPath $script:AppExportFile -ErrorAction SilentlyContinue
    try {
        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName = $script:Winget
        $psi.Arguments = "export -o `"$($script:AppExportFile)`" --accept-source-agreements --disable-interactivity"
        $psi.UseShellExecute = $false; $psi.CreateNoWindow = $true
        $script:AppExport = [System.Diagnostics.Process]::Start($psi)
        $txtAppsStatus.Text = T 'appsChecking'
        $script:AppTimer.Start()
    } catch { $script:AppExport = $null }
}

function Complete-AppExport {
    $script:AppExport = $null
    $script:AppInstalledIds.Clear()
    try {
        $j = Get-Content -LiteralPath $script:AppExportFile -Raw -ErrorAction Stop | ConvertFrom-Json
        foreach ($s in $j.Sources) { foreach ($p in $s.Packages) { [void]$script:AppInstalledIds.Add([string]$p.PackageIdentifier) } }
    } catch {}
    if (-not $script:AppJob) { $txtAppsStatus.Text = (T 'appsInstalledCount') -f $script:AppInstalledIds.Count }
    if (-not $radAppsInstalled.IsChecked) { Show-AppCatalog }
}

function Get-UninstallCommand($a) {
    if ($a.Kind -eq 'Store') {
        return @('powershell.exe', "-NoProfile -Command `"Remove-AppxPackage -Package '$($a.Pkg)'`"")
    }
    if ($a.Uninstall -match '(?i)msiexec(\.exe)?\s+/[IX]\s*(\{[0-9A-F\-]+\})') {
        return @('msiexec.exe', "/x $($Matches[2]) /qb /norestart")
    }
    $cmd = if ($a.Quiet) { $a.Quiet } else { $a.Uninstall }
    return @('cmd.exe', "/c `"$cmd`"")
}

$btnAppsAction.Add_Click({
    $n = $script:AppSel.Count
    if ($n -eq 0) { return }
    if ($radAppsInstalled.IsChecked) {
        if (-not (Show-Dialog (T 'confirmTitle') ((T 'appsAskUninstall') -f $n) 'danger')) { return }
        foreach ($a in @($script:AppInstalledList | Where-Object { $script:AppSel.Contains($_.Key) })) {
            $c = Get-UninstallCommand $a
            Add-AppJob "$(T 'appsUninstalling') $($a.Name)" $c[0] $c[1]
        }
    } else {
        if (-not (Show-Dialog (T 'confirmTitle') ((T 'appsAskInstall') -f $n) 'ask')) { return }
        foreach ($a in @($script:AppCatalog | Where-Object { $script:AppSel.Contains($_.Id) })) {
            $src = if ($a.Id -like 'store:*') { 'msstore' } else { 'winget' }
            $id = $a.Id -replace '^store:', ''
            Add-AppJob "$(T 'appsInstalling') $($a.Name)" $script:Winget "install --id $id -e --source $src --silent --accept-package-agreements --accept-source-agreements --disable-interactivity"
        }
    }
    $script:AppSel.Clear()
    Show-AppView
    $script:AppTimer.Start()
})

$btnAppsUpgrade.Add_Click({
    if (-not (Show-Dialog (T 'confirmTitle') (T 'appsAskUpgrade') 'ask')) { return }
    Add-AppJob (T 'appsUpgradeAll') $script:Winget 'upgrade --all --silent --accept-package-agreements --accept-source-agreements --disable-interactivity'
    $script:AppTimer.Start()
    Update-AppButtons
})

$btnAppsClear.Add_Click({ $script:AppSel.Clear(); Show-AppView })
$btnAppsRefresh.Add_Click({ $script:AppInstalledList = @(); Start-AppExport; Show-AppView })
$radAppsCatalog.Add_Checked({ if ($script:AppsReady) { $script:AppSel.Clear(); Show-AppView } })
$radAppsInstalled.Add_Checked({ if ($script:AppsReady) { $script:AppSel.Clear(); Show-AppView } })
$cmbAppCategory.Add_SelectionChanged({ if ($script:AppsReady -and -not $script:AppFiltersLoading) { Show-AppCatalog } })
$cmbAppLicense.Add_SelectionChanged({ if ($script:AppsReady -and -not $script:AppFiltersLoading) { Show-AppCatalog } })
$txtAppSearch.Add_TextChanged({
    $lblAppSearchHint.Visibility = if ($txtAppSearch.Text) { 'Collapsed' } else { 'Visible' }
    if ($script:AppsReady) { Show-AppView }
})

# Prima apertura della pagina: filtri, catalogo e controllo delle app gia' presenti.
function Show-AppsPageIfNeeded {
    if ($script:AppsBuiltLang -eq $script:LangCode) { return }
    $script:AppsBuiltLang = $script:LangCode
    Initialize-AppFilters
    $script:AppsReady = $true
    Show-AppView
    if (-not $script:Winget) {
        $txtAppsStatus.Text = T 'appsNoWinget'
    } elseif ($script:AppInstalledIds.Count -eq 0) { Start-AppExport }
}
