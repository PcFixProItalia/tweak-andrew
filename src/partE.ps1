
# ------------------------------------------------------------------------------
# 16. CORNICE DELLA FINESTRA
# ------------------------------------------------------------------------------
# Tema nero pieno: niente backdrop acrilico, che su uno sfondo opaco non si
# vedrebbe e lasciava intravedere il desktop negli angoli. A DWM si chiedono
# solo il bordo scuro e gli angoli arrotondati di Windows 11.
Add-Type -Namespace TweakAndrew -Name Dwm -MemberDefinition @'
[System.Runtime.InteropServices.DllImport("dwmapi.dll")]
public static extern int DwmSetWindowAttribute(System.IntPtr hwnd, int attr, ref int value, int size);
'@ -ErrorAction SilentlyContinue

function Enable-DarkFrame {
    try {
        $hwnd = (New-Object System.Windows.Interop.WindowInteropHelper($window)).Handle
        if ($hwnd -eq [System.IntPtr]::Zero) { return }
        $dark = 1
        [TweakAndrew.Dwm]::DwmSetWindowAttribute($hwnd, 20, [ref]$dark, 4) | Out-Null
        $round = 2
        [TweakAndrew.Dwm]::DwmSetWindowAttribute($hwnd, 33, [ref]$round, 4) | Out-Null
        # 34 = colore del bordo, in formato 0x00BBGGRR: grigio quasi nero.
        $border = 0x001F1C1C
        [TweakAndrew.Dwm]::DwmSetWindowAttribute($hwnd, 34, [ref]$border, 4) | Out-Null
    } catch {}
}

# ------------------------------------------------------------------------------
# 17. BARRA DEL TITOLO E MENU LATERALE
# ------------------------------------------------------------------------------
$shell = E 'shell'
$btnMin = E 'btnMin'; $btnMax = E 'btnMax'; $btnClose = E 'btnClose'
$lblPageTitle = E 'lblPageTitle'; $script:PageAccent = E 'pageAccent'; $script:GlowPage = E 'glowPage'

# Alone morbido in alto: stesso disegno per ogni pagina, cambia solo il colore.
function Set-PageGlow([System.Windows.Media.Color]$c) {
    $b = New-Object System.Windows.Media.RadialGradientBrush
    $b.GradientOrigin = New-Object System.Windows.Point(0.6, -0.1)
    $b.Center = New-Object System.Windows.Point(0.6, -0.1)
    $b.RadiusX = 0.8; $b.RadiusY = 0.9
    $b.GradientStops.Add((New-Object System.Windows.Media.GradientStop(([System.Windows.Media.Color]::FromArgb(0x2E, $c.R, $c.G, $c.B)), 0)))
    $b.GradientStops.Add((New-Object System.Windows.Media.GradientStop(([System.Windows.Media.Color]::FromArgb(0, $c.R, $c.G, $c.B)), 1)))
    $b.Freeze()
    $script:GlowPage.Background = $b
}

$btnMin.Add_Click({ $window.WindowState = [System.Windows.WindowState]::Minimized })
$btnMax.Add_Click({
    if ($window.WindowState -eq [System.Windows.WindowState]::Maximized) {
        $window.WindowState = [System.Windows.WindowState]::Normal
    } else {
        $window.WindowState = [System.Windows.WindowState]::Maximized
    }
})
$btnClose.Add_Click({ $window.Close() })

# Da massimizzata la finestra sborda oltre lo schermo: si compensa con un margine.
$window.Add_StateChanged({
    if ($window.WindowState -eq [System.Windows.WindowState]::Maximized) {
        $shell.Margin = New-Object System.Windows.Thickness(7)
        $shell.CornerRadius = New-Object System.Windows.CornerRadius(0)
    } else {
        $shell.Margin = New-Object System.Windows.Thickness(0)
        $shell.CornerRadius = New-Object System.Windows.CornerRadius(0)
    }
})

# Voci del menu laterale e pagine corrispondenti.
$script:NavPages = @(
    @{ Nav = (E 'tabHome');    Page = (E 'pageHome');   Home = $true },
    @{ Nav = (E 'tabPerf');    Page = (E 'pagePerf') },
    @{ Nav = (E 'tabSched');   Page = (E 'pageSched') },
    @{ Nav = (E 'tabPower');   Page = (E 'pagePower');  Cat = 'power' },
    @{ Nav = (E 'tabGpu');     Page = (E 'pageGpu') },
    @{ Nav = (E 'tabStorage'); Page = (E 'pageStorage') },
    @{ Nav = (E 'tabNet');     Page = (E 'pageNet') },
    @{ Nav = (E 'tabPrivacy'); Page = (E 'pagePrivacy') },
    @{ Nav = (E 'tabPriv2');   Page = (E 'pagePriv2');  Cat = 'priv' },
    @{ Nav = (E 'tabUi');      Page = (E 'pageUi') },
    @{ Nav = (E 'tabExp');     Page = (E 'pageExp');    Cat = 'exp' },
    @{ Nav = (E 'tabTask');    Page = (E 'pageTask');   Cat = 'task' },
    @{ Nav = (E 'tabNotif');   Page = (E 'pageNotif');  Cat = 'notif' },
    @{ Nav = (E 'tabGame');    Page = (E 'pageGame');   Cat = 'game' },
    @{ Nav = (E 'tabWin');     Page = (E 'pageWin');    Cat = 'win' },
    @{ Nav = (E 'tabApps');    Page = (E 'pageApps');   Apps = $true },
    @{ Nav = (E 'tabTools');   Page = (E 'pageTools');  Tools = $true },
    @{ Nav = (E 'tabAdv');     Page = (E 'pageAdv') }
)

function Show-Page {
    foreach ($entry in $script:NavPages) {
        if ($null -eq $entry.Nav -or $null -eq $entry.Page) { continue }
        if ($entry.Nav.IsChecked -eq $true) {
            $entry.Page.Visibility = [System.Windows.Visibility]::Visible
            if ($null -ne $lblPageTitle) { $lblPageTitle.Text = [string]$entry.Nav.Content }
            # La barretta accanto al titolo prende il colore della pagina.
            $pa = $entry.Nav.Resources['PA']
            if ($null -ne $pa -and $null -ne $script:PageAccent) { $script:PageAccent.Background = $pa }
            if ($null -ne $pa -and $null -ne $script:GlowPage) { Set-PageGlow $pa.Color }
            # Sulle pagine a effetto immediato la coda di «Applica» non serve: si nasconde.
            $live = ($entry.Cat -and $entry.Cat -ne 'power') -or $entry.Apps -or $entry.Home -or $entry.Tools
            foreach ($n in @('barQueue', 'pillSelected', 'chkRestorePoint')) {
                $el = $window.FindName($n)
                if ($el) { $el.Visibility = if ($live) { 'Collapsed' } else { 'Visible' } }
            }
            # Le pagine a interruttore e quella delle app si costruiscono alla prima apertura.
            if ($entry.Cat -and (Get-Command Show-CatPageIfNeeded -ErrorAction SilentlyContinue)) { Show-CatPageIfNeeded $entry.Cat }
            if ($entry.Apps -and (Get-Command Show-AppsPageIfNeeded -ErrorAction SilentlyContinue)) { Show-AppsPageIfNeeded }
            if ($entry.Home -and (Get-Command Show-HomePageIfNeeded -ErrorAction SilentlyContinue)) { Show-HomePageIfNeeded }
            if ($entry.Tools -and (Get-Command Show-ToolsPageIfNeeded -ErrorAction SilentlyContinue)) { Show-ToolsPageIfNeeded }
        } else {
            $entry.Page.Visibility = [System.Windows.Visibility]::Collapsed
        }
    }
}

foreach ($entry in $script:NavPages) {
    if ($null -ne $entry.Nav) { $entry.Nav.Add_Checked({ Show-Page }) }
}

$window.Add_SourceInitialized({ Enable-DarkFrame })
Show-Page

# ------------------------------------------------------------------------------
# 17b. SCHERMI AD ALTA RISOLUZIONE
# ------------------------------------------------------------------------------
# Senza questa dichiarazione Windows ingrandisce la finestra come bitmap su un
# 4K, e il risultato e' sfocato. Con la consapevolezza DPI per monitor WPF
# ridisegna tutto a risoluzione piena, testo compreso.
Add-Type -Namespace TweakAndrew -Name Dpi -MemberDefinition @'
[System.Runtime.InteropServices.DllImport("user32.dll")]
public static extern bool SetProcessDpiAwarenessContext(System.IntPtr value);

[System.Runtime.InteropServices.DllImport("user32.dll")]
public static extern bool SetProcessDPIAware();
'@ -ErrorAction SilentlyContinue

try {
    # -4 = PER_MONITOR_AWARE_V2. Se non c'e' (Windows 10 vecchi) si ripiega.
    if (-not [TweakAndrew.Dpi]::SetProcessDpiAwarenessContext([System.IntPtr](-4))) {
        [TweakAndrew.Dpi]::SetProcessDPIAware() | Out-Null
    }
} catch {
    try { [TweakAndrew.Dpi]::SetProcessDPIAware() | Out-Null } catch {}
}

$rootScale = E 'rootScale'
$cmbUiScale = E 'cmbUiScale'
$script:UiReady = $false

function Set-UiScale {
    if ($null -eq $rootScale -or $null -eq $cmbUiScale) { return }
    # Durante SelectionChanged la proprieta' Text ha ancora il valore vecchio:
    # il valore giusto va letto dalla voce selezionata.
    $pct = 100
    $scelta = if ($cmbUiScale.SelectedItem) { [string]$cmbUiScale.SelectedItem.Content } else { [string]$cmbUiScale.Text }
    if ($scelta -match '(\d+)') { $pct = [int]$Matches[1] }
    $f = $pct / 100.0

    $rootScale.LayoutTransform = New-Object System.Windows.Media.ScaleTransform($f, $f)

    $area = [System.Windows.SystemParameters]::WorkArea
    $window.MinWidth  = [math]::Min(1180 * $f, $area.Width)
    $window.MinHeight = [math]::Min(700 * $f, $area.Height)
    if ($window.WindowState -ne [System.Windows.WindowState]::Maximized) {
        $window.Width  = [math]::Min(1340 * $f, $area.Width)
        $window.Height = [math]::Min(840 * $f, $area.Height)
    }
    Write-Log "[INFO] Scala interfaccia: $pct%."
}

$cmbUiScale.Add_SelectionChanged({ if ($script:UiReady) { Set-UiScale } })
