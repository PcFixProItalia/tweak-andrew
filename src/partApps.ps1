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
$bdAppJobs = E 'bdAppJobs'; $panAppJobs = E 'panAppJobs'; $prgAppJobs = E 'prgAppJobs'
$txtAppJobsCount = E 'txtAppJobsCount'; $btnAppJobsClose = E 'btnAppJobsClose'

$script:AppSel = New-Object 'System.Collections.Generic.HashSet[string]'
$script:AppInstalledIds = New-Object 'System.Collections.Generic.HashSet[string]' ([System.StringComparer]::OrdinalIgnoreCase)
$script:AppInstalledList = @()
$script:AppUpdates = @{}
$script:AppJobs = New-Object System.Collections.Queue
$script:AppJobList = New-Object System.Collections.ArrayList
$script:AppJob = $null
$script:AppExport = $null
$script:AppScan = $null
$script:AppScanDone = $false
$script:AppsReady = $false
$script:Winget = $null
try { $script:Winget = (Get-Command winget.exe -ErrorAction Stop).Source } catch {}

# winget scrive l'avanzamento del download solo se crede di parlare con una
# console: con l'uscita rediretta tace fino alla fine. Una console virtuale
# (ConPTY, da Windows 10 1809) gli fa credere di averne una e ci lascia
# leggere tutto quello che scrive.
Add-Type -ErrorAction SilentlyContinue -TypeDefinition @'
using System;
using System.IO;
using System.Text;
using System.Threading;
using System.Runtime.InteropServices;
using Microsoft.Win32.SafeHandles;

namespace TweakAndrew {
public class PtyProcess {
    [StructLayout(LayoutKind.Sequential)] struct COORD { public short X; public short Y; }
    [StructLayout(LayoutKind.Sequential, CharSet = CharSet.Unicode)]
    struct STARTUPINFO {
        public int cb; public string lpReserved; public string lpDesktop; public string lpTitle;
        public int dwX; public int dwY; public int dwXSize; public int dwYSize; public int dwXCountChars; public int dwYCountChars;
        public int dwFillAttribute; public int dwFlags; public short wShowWindow; public short cbReserved2;
        public IntPtr lpReserved2; public IntPtr hStdInput; public IntPtr hStdOutput; public IntPtr hStdError;
    }
    [StructLayout(LayoutKind.Sequential)] struct STARTUPINFOEX { public STARTUPINFO StartupInfo; public IntPtr lpAttributeList; }
    [StructLayout(LayoutKind.Sequential)] struct PROCESS_INFORMATION { public IntPtr hProcess; public IntPtr hThread; public int dwProcessId; public int dwThreadId; }

    [DllImport("kernel32.dll", SetLastError = true)] static extern bool CreatePipe(out SafeFileHandle r, out SafeFileHandle w, IntPtr sa, int size);
    [DllImport("kernel32.dll", SetLastError = true)] static extern int CreatePseudoConsole(COORD size, SafeFileHandle hIn, SafeFileHandle hOut, uint flags, out IntPtr hPC);
    [DllImport("kernel32.dll", SetLastError = true)] static extern void ClosePseudoConsole(IntPtr hPC);
    [DllImport("kernel32.dll", SetLastError = true)] static extern bool InitializeProcThreadAttributeList(IntPtr list, int count, int flags, ref IntPtr size);
    [DllImport("kernel32.dll", SetLastError = true)] static extern bool UpdateProcThreadAttribute(IntPtr list, uint flags, IntPtr attr, IntPtr value, IntPtr size, IntPtr prev, IntPtr retSize);
    [DllImport("kernel32.dll", SetLastError = true)] static extern void DeleteProcThreadAttributeList(IntPtr list);
    [DllImport("kernel32.dll", SetLastError = true, CharSet = CharSet.Unicode)]
    static extern bool CreateProcessW(string app, StringBuilder cmd, IntPtr pa, IntPtr ta, bool inherit, uint flags, IntPtr env, string dir, ref STARTUPINFOEX si, out PROCESS_INFORMATION pi);
    [DllImport("kernel32.dll", SetLastError = true)] static extern uint WaitForSingleObject(IntPtr h, uint ms);
    [DllImport("kernel32.dll", SetLastError = true)] static extern bool GetExitCodeProcess(IntPtr h, out int code);
    [DllImport("kernel32.dll", SetLastError = true)] static extern bool CloseHandle(IntPtr h);

    readonly StringBuilder buf = new StringBuilder();
    volatile bool exited;
    public int ExitCode;
    public bool HasExited { get { return exited; } }
    public string Text { get { lock (buf) { return buf.ToString(); } } }

    public static PtyProcess Start(string commandLine) {
        var p = new PtyProcess();
        SafeFileHandle inR, inW, outR, outW;
        if (!CreatePipe(out inR, out inW, IntPtr.Zero, 0) || !CreatePipe(out outR, out outW, IntPtr.Zero, 0))
            throw new Exception("CreatePipe");
        IntPtr hPC;
        int hr = CreatePseudoConsole(new COORD { X = 220, Y = 50 }, inR, outW, 0, out hPC);
        if (hr != 0) throw new Exception("CreatePseudoConsole " + hr);
        IntPtr size = IntPtr.Zero;
        InitializeProcThreadAttributeList(IntPtr.Zero, 1, 0, ref size);
        var si = new STARTUPINFOEX();
        si.StartupInfo.cb = Marshal.SizeOf(typeof(STARTUPINFOEX));
        // Senza STARTF_USESTDHANDLES il figlio erediterebbe la console di PowerShell.
        si.StartupInfo.dwFlags = 0x100;
        si.lpAttributeList = Marshal.AllocHGlobal(size);
        if (!InitializeProcThreadAttributeList(si.lpAttributeList, 1, 0, ref size)) throw new Exception("InitializeProcThreadAttributeList");
        if (!UpdateProcThreadAttribute(si.lpAttributeList, 0, (IntPtr)0x00020016, hPC, (IntPtr)IntPtr.Size, IntPtr.Zero, IntPtr.Zero))
            throw new Exception("UpdateProcThreadAttribute");
        PROCESS_INFORMATION pi;
        if (!CreateProcessW(null, new StringBuilder(commandLine), IntPtr.Zero, IntPtr.Zero, false, 0x00080000, IntPtr.Zero, null, ref si, out pi)) {
            ClosePseudoConsole(hPC);
            throw new Exception("CreateProcess " + Marshal.GetLastWin32Error());
        }
        inR.Dispose(); outW.Dispose();
        var reader = new Thread(() => {
            try {
                using (var fs = new FileStream(outR, FileAccess.Read)) {
                    var dec = Encoding.UTF8.GetDecoder();
                    var b = new byte[4096]; var c = new char[8192];
                    int n;
                    while ((n = fs.Read(b, 0, b.Length)) > 0) {
                        int k = dec.GetChars(b, 0, n, c, 0);
                        lock (p.buf) { p.buf.Append(c, 0, k); if (p.buf.Length > 200000) p.buf.Remove(0, 100000); }
                    }
                }
            } catch { }
        });
        reader.IsBackground = true; reader.Start();
        var waiter = new Thread(() => {
            WaitForSingleObject(pi.hProcess, 0xFFFFFFFF);
            int code; GetExitCodeProcess(pi.hProcess, out code);
            p.ExitCode = code;
            ClosePseudoConsole(hPC);
            reader.Join(3000);
            inW.Dispose();
            CloseHandle(pi.hThread); CloseHandle(pi.hProcess);
            DeleteProcThreadAttributeList(si.lpAttributeList); Marshal.FreeHGlobal(si.lpAttributeList);
            p.exited = true;
        });
        waiter.IsBackground = true; waiter.Start();
        return p;
    }
}
}
'@

$script:AppLicColors = @{
    os = @('#FF3DBE8B', '#263DBE8B'); fw = @('#FF7DD3FC', '#2638BDF8'); fr = @('#FFFDBA74', '#26FDBA74')
    ms = @('#FFA5B4FC', '#26818CF8'); pd = @('#FFF87171', '#26F87171')
}
$script:AppTickGeometry = 'M3.6,8.6 L7,12 L13.4,4.8'

function New-AppBrush([string]$hex) { New-Object System.Windows.Media.SolidColorBrush ([System.Windows.Media.ColorConverter]::ConvertFromString($hex)) }

function New-AppTick([string]$color, [double]$size) {
    $p = New-Object System.Windows.Shapes.Path
    $p.Data = [System.Windows.Media.Geometry]::Parse($script:AppTickGeometry)
    $p.Stroke = New-AppBrush $color; $p.StrokeThickness = 2.2
    $p.StrokeStartLineCap = 'Round'; $p.StrokeEndLineCap = 'Round'; $p.StrokeLineJoin = 'Round'
    $p.Stretch = 'Uniform'; $p.Width = $size; $p.Height = $size
    return $p
}

function New-AppPill([string]$text, [string]$fg, [string]$bg, [switch]$Tick) {
    $b = New-Object System.Windows.Controls.Border
    $b.CornerRadius = 6; $b.Padding = '7,2,7,2'; $b.Margin = '8,0,0,0'; $b.VerticalAlignment = 'Center'
    $b.Background = New-AppBrush $bg
    $sp = New-Object System.Windows.Controls.StackPanel; $sp.Orientation = 'Horizontal'
    if ($Tick) { $i = New-AppTick $fg 9; $i.Margin = '0,0,5,0'; $i.VerticalAlignment = 'Center'; [void]$sp.Children.Add($i) }
    $t = New-Object System.Windows.Controls.TextBlock
    $t.Text = $text; $t.FontSize = 10.5; $t.FontWeight = 'SemiBold'; $t.Foreground = New-AppBrush $fg
    [void]$sp.Children.Add($t)
    $b.Child = $sp
    return $b
}

# Contenuto di una riga: nome e descrizione a sinistra, etichette a destra.
function New-AppContent([string]$title, [string]$sub, [array]$pills) {
    $g = New-Object System.Windows.Controls.Grid
    foreach ($w in @('*', 'Auto')) {
        $cd = New-Object System.Windows.Controls.ColumnDefinition
        $cd.Width = if ($w -eq '*') { New-Object System.Windows.GridLength(1, [System.Windows.GridUnitType]::Star) } else { [System.Windows.GridLength]::Auto }
        $g.ColumnDefinitions.Add($cd)
    }
    $sp = New-Object System.Windows.Controls.StackPanel; $sp.VerticalAlignment = 'Center'
    $t1 = New-Object System.Windows.Controls.TextBlock
    $t1.Text = $title; $t1.FontSize = 13; $t1.FontWeight = 'SemiBold'; $t1.Foreground = New-AppBrush '#FFE9EAEE'; $t1.TextTrimming = 'CharacterEllipsis'
    [void]$sp.Children.Add($t1)
    if ($sub) {
        $t2 = New-Object System.Windows.Controls.TextBlock
        $t2.Text = $sub; $t2.FontSize = 11.5; $t2.Foreground = New-AppBrush '#FF8E919C'; $t2.TextWrapping = 'Wrap'; $t2.Margin = '0,2,0,0'
        [void]$sp.Children.Add($t2)
    }
    [void]$g.Children.Add($sp)
    $pp = New-Object System.Windows.Controls.StackPanel; $pp.Orientation = 'Horizontal'; $pp.VerticalAlignment = 'Center'
    foreach ($p in $pills) { [void]$pp.Children.Add($p) }
    [System.Windows.Controls.Grid]::SetColumn($pp, 1); [void]$g.Children.Add($pp)
    return $g
}

# Riga selezionabile: tutta la riga e' la casella.
function New-AppPick([string]$key, $content) {
    $cb = New-Object System.Windows.Controls.CheckBox
    $cb.Style = $window.FindResource('PickRow')
    $cb.Content = $content; $cb.Tag = $key
    $cb.IsChecked = $script:AppSel.Contains($key)
    $cb.Add_Checked({ [void]$script:AppSel.Add([string]$this.Tag); Update-AppButtons })
    $cb.Add_Unchecked({ [void]$script:AppSel.Remove([string]$this.Tag); Update-AppButtons })
    return $cb
}

# Riga di un'app gia' installata e aggiornata: niente da scegliere, al posto
# della casella un segno di spunta verde.
function New-AppStatic($content) {
    $b = New-Object System.Windows.Controls.Border
    $b.Background = New-AppBrush '#FF15161B'; $b.BorderBrush = New-AppBrush '#FF1C1E24'; $b.BorderThickness = 1
    $b.CornerRadius = 12; $b.Padding = '11,8,11,8'; $b.Margin = '0,2,0,2'
    $g = New-Object System.Windows.Controls.Grid
    $c0 = New-Object System.Windows.Controls.ColumnDefinition; $c0.Width = [System.Windows.GridLength]::Auto
    $c1 = New-Object System.Windows.Controls.ColumnDefinition
    $g.ColumnDefinitions.Add($c0); $g.ColumnDefinitions.Add($c1)
    $dot = New-Object System.Windows.Controls.Border
    $dot.Width = 20; $dot.Height = 20; $dot.CornerRadius = 10; $dot.Margin = '0,0,12,0'; $dot.VerticalAlignment = 'Center'
    $dot.Background = New-AppBrush '#263DBE8B'
    $dot.Child = New-AppTick '#FF3DBE8B' 10
    [void]$g.Children.Add($dot)
    [System.Windows.Controls.Grid]::SetColumn($content, 1); [void]$g.Children.Add($content)
    $b.Child = $g
    return $b
}

function New-AppCard([string]$title, $button) {
    $card = New-Object System.Windows.Controls.Border
    $card.Style = $window.FindResource('Glass')
    $sp = New-Object System.Windows.Controls.StackPanel
    $hg = New-Object System.Windows.Controls.Grid; $hg.Margin = '0,0,0,10'
    $c0 = New-Object System.Windows.Controls.ColumnDefinition
    $c1 = New-Object System.Windows.Controls.ColumnDefinition; $c1.Width = [System.Windows.GridLength]::Auto
    $hg.ColumnDefinitions.Add($c0); $hg.ColumnDefinitions.Add($c1)
    $h = New-Object System.Windows.Controls.TextBlock
    $h.Text = $title.ToUpper(); $h.Style = $window.FindResource('CardTitle'); $h.Margin = '0'; $h.VerticalAlignment = 'Center'
    [void]$hg.Children.Add($h)
    if ($button) { [System.Windows.Controls.Grid]::SetColumn($button, 1); [void]$hg.Children.Add($button) }
    [void]$sp.Children.Add($hg)
    $card.Child = $sp
    return @{ Card = $card; Panel = $sp }
}

function New-AppNote([string]$text) {
    $t = New-Object System.Windows.Controls.TextBlock
    $t.Text = $text; $t.Style = $window.FindResource('SubTitle'); $t.Margin = '4,0,0,4'
    return $t
}

function Get-AppFilterText { return $txtAppSearch.Text.Trim() }

# Un'app del catalogo e' installata se winget la riconosce per id, oppure se
# nell'elenco dei programmi c'e' un nome che comincia esattamente con il suo.
function Test-AppInstalled($a) {
    $wid = $a.Id -replace '^store:', ''
    if ($script:AppInstalledIds.Contains($wid)) { return $true }
    if ($a.Name.Length -lt 3) { return $false }
    $rx = '^' + [regex]::Escape($a.Name) + '(\s|$|\()'
    foreach ($i in $script:AppInstalledList) { if ($i.Name -match $rx) { return $true } }
    return $false
}

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
            $upd = $script:AppUpdates[$wid]
            if (Test-AppInstalled $a) {
                if ($upd) {
                    $pills += New-AppPill ((T 'appUpdatable') + " $($upd.Available)") '#FFFDBA74' '#26FDBA74'
                    $row = New-AppPick "u:$wid" (New-AppContent $a.Name (Get-Text $a.Desc) $pills)
                } else {
                    $pills += New-AppPill (T 'appInstalled') '#FF3DBE8B' '#263DBE8B' -Tick
                    $row = New-AppStatic (New-AppContent $a.Name (Get-Text $a.Desc) $pills)
                }
            } else {
                $row = New-AppPick $a.Id (New-AppContent $a.Name (Get-Text $a.Desc) $pills)
            }
            [void]$card.Panel.Children.Add($row)
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
    $stack = New-Object System.Windows.Controls.StackPanel
    $lc = New-LeftoverCard
    if ($lc) { [void]$stack.Children.Add($lc) }

    # Aggiornamenti: quelli che winget sa aggiornare, da scegliere uno per uno.
    $updates = @($script:AppUpdates.Values | Sort-Object Name | Where-Object { -not $q -or $_.Name -like "*$q*" -or $_.Id -like "*$q*" })
    $btnAll = $null
    if ($updates.Count -gt 0) {
        $btnAll = New-Object System.Windows.Controls.Button
        $btnAll.Style = $window.FindResource('DotBtn'); $btnAll.Content = T 'appsSelectUpdates'
        $btnAll.Add_Click({
            foreach ($u in $script:AppUpdates.Values) { [void]$script:AppSel.Add("u:$($u.Id)") }
            Show-AppView
        })
    }
    $uc = New-AppCard ((T 'appsUpdatesTitle') -f $script:AppUpdates.Count) $btnAll
    if (-not $script:Winget) {
        [void]$uc.Panel.Children.Add((New-AppNote (T 'appsNoWinget')))
    } elseif (-not $script:AppScanDone) {
        [void]$uc.Panel.Children.Add((New-AppNote (T 'appsScanning')))
    } elseif ($script:AppUpdates.Count -eq 0) {
        [void]$uc.Panel.Children.Add((New-AppNote (T 'appsNoUpdates')))
    }
    foreach ($u in $updates) {
        $sub = "$($u.Version)  $([char]0x2192)  $($u.Available)    $($u.Id)"
        $pill = New-AppPill (T 'appUpdatable') '#FFFDBA74' '#26FDBA74'
        [void]$uc.Panel.Children.Add((New-AppPick "u:$($u.Id)" (New-AppContent $u.Name $sub @($pill))))
    }
    [void]$stack.Children.Add($uc.Card)

    $updNames = @{}
    foreach ($u in $script:AppUpdates.Values) { $updNames[$u.Name] = $true }
    $card = New-AppCard ((T 'appsInstalledTitle') -f $script:AppInstalledList.Count)
    foreach ($a in $script:AppInstalledList) {
        if ($q -and $a.Name -notlike "*$q*" -and $a.Publisher -notlike "*$q*") { continue }
        $sub = (@($a.Version, $a.Publisher) | Where-Object { $_ }) -join '  ·  '
        $pills = @(if ($a.Kind -eq 'Store') { New-AppPill 'Store' '#FFA5B4FC' '#26818CF8' } else { New-AppPill 'Win32' '#FFC9CBD2' '#FF24262D' })
        if ($updNames.ContainsKey($a.Name)) { $pills = @(New-AppPill (T 'appUpdatable') '#FFFDBA74' '#26FDBA74') + $pills }
        [void]$card.Panel.Children.Add((New-AppPick $a.Key (New-AppContent $a.Name $sub $pills)))
    }
    [void]$stack.Children.Add($card.Card)
    [void]$panApps.Children.Add($stack)
}

function Update-AppButtons {
    $upd = @($script:AppSel | Where-Object { $_ -like 'u:*' }).Count
    $n = $script:AppSel.Count - $upd
    $label = if ($radAppsInstalled.IsChecked) { T 'appsUninstallSel' } else { T 'appsInstallSel' }
    $btnAppsAction.Content = if ($n -gt 0) { "$label ($n)" } else { $label }
    $btnAppsAction.IsEnabled = ($n -gt 0) -and ($radAppsInstalled.IsChecked -or $script:Winget)
    $btnAppsAction.Tag = if ($radAppsInstalled.IsChecked) { New-AppBrush '#FFF87171' } else { New-AppBrush '#FF3DBE8B' }
    $label = T 'appsUpgradeSel'
    $btnAppsUpgrade.Content = if ($upd -gt 0) { "$label ($upd)" } else { $label }
    $btnAppsUpgrade.IsEnabled = ($upd -gt 0) -and ($null -ne $script:Winget)
    $btnAppsUpgrade.Tag = New-AppBrush '#FFFDBA74'
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

# ------------------------------------------------------------------------------
# Operazioni: coda, righe di avanzamento e lettura dell'uscita di winget
# ------------------------------------------------------------------------------
function Test-AppBusy { return ($null -ne $script:AppJob) -or ($script:AppJobs.Count -gt 0) }

# Riga di un'operazione: nome e stato sopra, barra sotto. La barra ha due modi:
# a percentuale (download) e a scorrimento, quando winget non dice quanto manca.
function New-AppJobRow($job, $Panel = $panAppJobs) {
    $g = New-Object System.Windows.Controls.Grid; $g.Margin = '0,0,0,9'
    $r0 = New-Object System.Windows.Controls.RowDefinition; $r0.Height = [System.Windows.GridLength]::Auto
    $r1 = New-Object System.Windows.Controls.RowDefinition; $r1.Height = [System.Windows.GridLength]::Auto
    $g.RowDefinitions.Add($r0); $g.RowDefinitions.Add($r1)
    $c0 = New-Object System.Windows.Controls.ColumnDefinition
    $c1 = New-Object System.Windows.Controls.ColumnDefinition; $c1.Width = [System.Windows.GridLength]::Auto
    $g.ColumnDefinitions.Add($c0); $g.ColumnDefinitions.Add($c1)
    $name = New-Object System.Windows.Controls.TextBlock
    $name.Text = $job.Name; $name.FontSize = 12.5; $name.FontWeight = 'SemiBold'; $name.Foreground = New-AppBrush '#FFE9EAEE'
    $name.TextTrimming = 'CharacterEllipsis'
    [void]$g.Children.Add($name)
    $state = New-Object System.Windows.Controls.TextBlock
    $state.FontSize = 11.5; $state.Margin = '12,0,0,0'; $state.Foreground = New-AppBrush '#FF8E919C'
    [System.Windows.Controls.Grid]::SetColumn($state, 1); [void]$g.Children.Add($state)
    $track = New-Object System.Windows.Controls.Grid
    $track.Height = 4; $track.Margin = '0,6,0,0'; $track.ClipToBounds = $true
    [System.Windows.Controls.Grid]::SetRow($track, 1); [System.Windows.Controls.Grid]::SetColumnSpan($track, 2)
    $bar = New-Object System.Windows.Controls.ProgressBar
    $bar.Minimum = 0; $bar.Maximum = 100; $bar.Value = 0; $bar.Height = 4
    [void]$track.Children.Add($bar)
    $run = New-Object System.Windows.Controls.Border
    $run.Width = 110; $run.HorizontalAlignment = 'Left'; $run.CornerRadius = 2; $run.Visibility = 'Collapsed'
    $lg = New-Object System.Windows.Media.LinearGradientBrush
    $lg.StartPoint = '0,0'; $lg.EndPoint = '1,0'
    $lg.GradientStops.Add((New-Object System.Windows.Media.GradientStop ([System.Windows.Media.Color]::FromArgb(0, 0x1E, 0x90, 0xFF)), 0))
    $lg.GradientStops.Add((New-Object System.Windows.Media.GradientStop ([System.Windows.Media.ColorConverter]::ConvertFromString('#FFA78BFA')), 0.6))
    $lg.GradientStops.Add((New-Object System.Windows.Media.GradientStop ([System.Windows.Media.Color]::FromArgb(0, 0xF4, 0x72, 0xB6)), 1))
    $run.Background = $lg
    $run.RenderTransform = New-Object System.Windows.Media.TranslateTransform
    [void]$track.Children.Add($run)
    [void]$g.Children.Add($track)
    $job.Row = $g; $job.StateText = $state; $job.Bar = $bar; $job.Runner = $run; $job.Track = $track
    $job.Moving = $false
    [void]$Panel.Children.Add($g)
}

function Set-AppJobView($job, [string]$text, [double]$pct = -1, [string]$color = '#FF8E919C') {
    $job.StateText.Text = $text
    $job.StateText.Foreground = New-AppBrush $color
    if ($pct -ge 0) {
        $job.Bar.Value = [Math]::Min(100, $pct); $job.Bar.Visibility = 'Visible'
        if ($job.Moving) { $job.Runner.RenderTransform.BeginAnimation([System.Windows.Media.TranslateTransform]::XProperty, $null); $job.Moving = $false }
        $job.Runner.Visibility = 'Collapsed'
    } else {
        $job.Bar.Value = 0
        $job.Runner.Visibility = 'Visible'
        if (-not $job.Moving) {
            $w = [Math]::Max(300, $job.Track.ActualWidth)
            $an = New-Object System.Windows.Media.Animation.DoubleAnimation(-110, $w, [TimeSpan]::FromSeconds(1.4))
            $an.RepeatBehavior = [System.Windows.Media.Animation.RepeatBehavior]::Forever
            $job.Runner.RenderTransform.BeginAnimation([System.Windows.Media.TranslateTransform]::XProperty, $an)
            $job.Moving = $true
        }
    }
}

function Add-AppJob([string]$kind, [string]$name, [string]$file, [string]$arguments, [bool]$pty) {
    # Un nuovo giro dopo uno finito riparte da un pannello pulito.
    if (-not (Test-AppBusy)) {
        foreach ($j in $script:AppJobList) { if ($j.Moving) { $j.Runner.RenderTransform.BeginAnimation([System.Windows.Media.TranslateTransform]::XProperty, $null) } }
        $script:AppJobList.Clear(); $panAppJobs.Children.Clear()
    }
    $prefix = switch ($kind) { 'install' { T 'appsInstalling' } 'upgrade' { T 'appsUpgrading' } default { T 'appsUninstalling' } }
    $job = @{ Kind = $kind; Name = $name; Label = "$prefix $name"; File = $file; Args = $arguments; Pty = $pty
              Proc = $null; Done = $false; Ok = $false; Frac = 0.0; SawDl = $false; DlDone = $false }
    New-AppJobRow $job
    Set-AppJobView $job (T 'jobWait') 0 '#FF767985'
    [void]$script:AppJobList.Add($job)
    $script:AppJobs.Enqueue($job)
    $bdAppJobs.Visibility = 'Visible'; $btnAppJobsClose.Visibility = 'Collapsed'
}

function Start-AppJob($job) {
    $script:AppJob = $job
    $job.Proc = $null
    if ($job.Pty) {
        try { $job.Proc = [TweakAndrew.PtyProcess]::Start("`"$($job.File)`" $($job.Args)") } catch { $job.Proc = $null }
    }
    if ($null -eq $job.Proc) {
        try {
            $psi = New-Object System.Diagnostics.ProcessStartInfo
            $psi.FileName = $job.File; $psi.Arguments = $job.Args
            $psi.UseShellExecute = $false; $psi.CreateNoWindow = $true
            $job.Proc = [System.Diagnostics.Process]::Start($psi)
        } catch {
            Write-Log "[ERRORE] $($job.Label) - $($_.Exception.Message)"
            Complete-AppJob $job -1
            return
        }
    }
    $first = if ($job.Kind -eq 'uninstall') { T 'jobUninstall' } else { T 'jobPrep' }
    Set-AppJobView $job $first -1 '#FFC9CBD2'
}

function ConvertTo-AppBytes([string]$num, [string]$unit) {
    $v = 0.0
    [void][double]::TryParse(($num -replace ',', '.'), [System.Globalization.NumberStyles]::Float, [System.Globalization.CultureInfo]::InvariantCulture, [ref]$v)
    $m = switch -Regex ($unit) { '^K' { 1KB } '^M' { 1MB } '^G' { 1GB } '^T' { 1TB } default { 1 } }
    return $v * $m
}

# Legge quello che winget ha scritto finora. Due fonti: il testo «12.3 MB / 45.0 MB»
# della barra e la sequenza ESC ] 9;4;stato;percento che winget manda alla
# barra delle applicazioni (stato 1 = percentuale, 3 = attesa senza stima).
function Update-AppJobProgress($job) {
    if ($job.Proc.GetType().Name -ne 'PtyProcess') { return }
    $raw = $job.Proc.Text
    if ($raw.Length -gt 6000) { $raw = $raw.Substring($raw.Length - 6000) }
    $osc = [regex]::Matches($raw, "\x1b\]9;4;(\d);(\d+)")
    $clean = $raw -replace "\x1b\][^\x07\x1b]*(\x07|\x1b\\)?", '' -replace "\x1b\[[0-9;?]*[ -/]*[@-~]", ''
    $sizes = [regex]::Matches($clean, '([\d.,]+)\s*([KMGT]i?B)\s*/\s*([\d.,]+)\s*([KMGT]i?B)')
    $oState = -1; $oPct = 0
    if ($osc.Count -gt 0) { $o = $osc[$osc.Count - 1]; $oState = [int]$o.Groups[1].Value; $oPct = [int]$o.Groups[2].Value }
    $sizeText = ''; $sPct = -1
    if ($sizes.Count -gt 0) {
        $s = $sizes[$sizes.Count - 1]
        $cur = ConvertTo-AppBytes $s.Groups[1].Value $s.Groups[2].Value
        $tot = ConvertTo-AppBytes $s.Groups[3].Value $s.Groups[4].Value
        if ($tot -gt 0) { $sPct = [Math]::Floor(100 * $cur / $tot) }
        $sizeText = "$($s.Groups[1].Value) $($s.Groups[2].Value) / $($s.Groups[3].Value) $($s.Groups[4].Value)"
        $job.SawDl = $true
        # Download finito: barra piena, oppure dopo la barra winget ha gia' scritto
        # altro (la verifica dell'hash, l'avvio dell'installazione).
        $after = $clean.Substring($s.Index + $s.Length)
        if ($sPct -ge 100 -or $after -match '\n[^\n]*\p{L}{3,}') { $job.DlDone = $true }
    }

    if (-not $job.DlDone -and ($sPct -ge 0 -or $oState -eq 1)) {
        $pct = if ($sPct -ge 0) { $sPct } else { $oPct }
        $text = (T 'jobDownload') -f $pct
        if ($sizeText) { $text += "  ·  $sizeText" }
        Set-AppJobView $job $text $pct '#FFE9EAEE'
        $job.Frac = 0.7 * $pct / 100
    } elseif ($job.DlDone -or $job.SawDl) {
        if ($oState -eq 1 -and $oPct -gt 0 -and $oPct -lt 100) {
            Set-AppJobView $job ((T 'jobInstallPct') -f $oPct) $oPct '#FFE9EAEE'
            $job.Frac = 0.7 + 0.3 * $oPct / 100
        } else {
            Set-AppJobView $job (T 'jobInstall') -1 '#FFE9EAEE'
            $job.Frac = 0.8
        }
    } elseif ($oState -eq 1 -and $oPct -gt 0) {
        # Pacchetti dello Store: una sola percentuale per tutto il lavoro.
        Set-AppJobView $job ((T 'jobDownload') -f $oPct) $oPct '#FFE9EAEE'
        $job.Frac = $oPct / 100
    }
}

# Codici di uscita di winget, in esadecimale come li stampa «winget error».
# Quelli con un testo in wgErr_ si mostrano spiegati, gli altri con il codice.
$script:WingetOkCodes = @('8A15002B', '8A150061', '8A15010D')   # nessun aggiornamento, gia' installato
$script:WingetRebootCodes = @('8A150109')                       # installato, il riavvio completa il lavoro
$script:WingetKnownErrors = @('8A150008', '8A150011', '8A150014', '8A15008E', '8A150101', '8A150102', '8A150103',
                              '8A150104', '8A150105', '8A150106', '8A150107', '8A15010A', '8A15010C', '8A15010E', '8A15010F')

function Complete-AppJob($job, [int]$code) {
    $hex = '{0:X8}' -f $code
    # 0x8A15008E: la versione nuova usa un altro tipo di installatore (per esempio
    # MSI al posto di EXE) e winget non la mette sopra alla vecchia. Con
    # --uninstall-previous toglie prima quella installata; le impostazioni
    # dell'utente restano nella sua cartella.
    if ($hex -eq '8A15008E' -and -not $job.Retried -and $job.File -eq $script:Winget) {
        $job.Retried = $true
        $job.Args += ' --uninstall-previous'
        $job.SawDl = $false; $job.DlDone = $false; $job.Frac = 0.0
        Write-Log "[AVVISO] $($job.Label) - tipo di installatore cambiato, nuovo tentativo sostituendo la versione installata"
        Start-AppJob $job
        if ($job.Proc) { Set-AppJobView $job (T 'jobRetry') -1 '#FFFDBA74' }
        return
    }
    $job.Done = $true; $job.Frac = 1.0
    # I codici di winget si leggono in esadecimale, quelli degli installatori in decimale.
    $codeText = if ($hex -like '8A15*') { "0x$hex" } else { "$code" }
    $job.StateText.ToolTip = $codeText
    # 3010 e 1641: riuscito, ma Windows vuole un riavvio.
    if ($code -in @(3010, 1641) -or $script:WingetRebootCodes -contains $hex) {
        $job.Ok = $true; Write-Log "[OK] $($job.Label) - serve un riavvio"
        Set-AppJobView $job (T 'jobOkReboot') 100 '#FFFDBA74'
    } elseif ($code -eq 0 -or $script:WingetOkCodes -contains $hex) {
        $job.Ok = $true; Write-Log "[OK] $($job.Label)"
        Set-AppJobView $job (T 'jobOk') 100 '#FF3DBE8B'
    } else {
        $msg = if ($script:WingetKnownErrors -contains $hex) { T "wgErr_$hex" } else { (T 'jobErr') -f $codeText }
        Write-Log "[ERRORE] $($job.Label) - $codeText $msg"
        Set-AppJobView $job $msg 0 '#FFF87171'
    }
    if ($script:AppJob -eq $job) { $script:AppJob = $null }
}

function Update-AppJobsHeader {
    $total = $script:AppJobList.Count
    if ($total -eq 0) { return }
    $done = @($script:AppJobList | Where-Object { $_.Done }).Count
    $sum = 0.0; foreach ($j in $script:AppJobList) { $sum += $j.Frac }
    $prgAppJobs.Value = $sum / $total
    $txtAppJobsCount.Text = (T 'jobsProgress') -f $done, $total
    # Anche dalle altre pagine si vede che le app stanno lavorando.
    if ($script:AppJob) {
        $st = [string]$script:AppJob.StateText.Text
        Set-Activity 'apps' ("$($script:AppJob.Label) · $st  ($done/$total)") ([Math]::Round(100 * $sum / $total)) 'tabApps'
    }
}

$script:AppTimer = New-Object System.Windows.Threading.DispatcherTimer
$script:AppTimer.Interval = [TimeSpan]::FromMilliseconds(250)
$script:AppTimer.Add_Tick({
    if ($null -ne $script:AppExport -and $script:AppExport.HasExited) { Complete-AppExport }
    if ($null -ne $script:AppScan -and $script:AppScan.HasExited) { Complete-AppUpgradeScan }
    $job = $script:AppJob
    if ($null -ne $job) {
        if ($job.Proc.HasExited) { Complete-AppJob $job $job.Proc.ExitCode }
        else { Update-AppJobProgress $job }
    }
    if ($null -eq $script:AppJob -and $script:AppJobs.Count -gt 0) {
        Start-AppJob ($script:AppJobs.Dequeue())
        $txtAppsStatus.Text = (T 'appsWorking') -f $script:AppJob.Label, $script:AppJobs.Count
    }
    Update-AppJobsHeader
    if (Test-AppBusy) { return }
    if ($script:AppBatch) {
        # Giro finito: riepilogo e rilettura di cio' che e' installato.
        $script:AppBatch = $false
        Clear-Activity 'apps'
        $ok = @($script:AppJobList | Where-Object { $_.Ok }).Count
        $txtAppsStatus.Text = (T 'appsDoneSum') -f $ok, ($script:AppJobList.Count - $ok)
        $txtProgressLabel.Text = $txtAppsStatus.Text
        $prgTweaks.Value = 1
        $btnAppJobsClose.Visibility = 'Visible'
        $script:AppInstalledList = @()
        Start-AppExport
        Start-AppUpgradeScan
        Show-AppView
        Start-LeftoverWatch
        return
    }
    if ($null -eq $script:AppExport -and $null -eq $script:AppScan) { $script:AppTimer.Stop() }
})

function Start-AppBatch { $script:AppBatch = $true; $script:AppSel.Clear(); Show-AppView; $script:AppTimer.Start() }

function Start-AppHidden([string]$file, [string]$arguments) {
    $psi = New-Object System.Diagnostics.ProcessStartInfo
    $psi.FileName = $file; $psi.Arguments = $arguments
    $psi.UseShellExecute = $false; $psi.CreateNoWindow = $true
    return [System.Diagnostics.Process]::Start($psi)
}

# Elenco degli id winget installati: winget export scrive un file JSON.
function Start-AppExport {
    if (-not $script:Winget -or $null -ne $script:AppExport) { return }
    $script:AppExportFile = Join-Path $env:TEMP 'TweakAndrew_winget.json'
    Remove-Item -LiteralPath $script:AppExportFile -ErrorAction SilentlyContinue
    try {
        $script:AppExport = Start-AppHidden $script:Winget "export -o `"$($script:AppExportFile)`" --accept-source-agreements --disable-interactivity"
        if ($script:AppJobList.Count -eq 0) { $txtAppsStatus.Text = T 'appsChecking' }
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
    if ($txtAppsStatus.Text -eq (T 'appsChecking')) { $txtAppsStatus.Text = (T 'appsInstalledCount') -f $script:AppInstalledIds.Count }
    if (-not $radAppsInstalled.IsChecked) { Show-AppCatalog }
}

# Aggiornamenti disponibili: winget upgrade stampa una tabella. Con l'uscita
# rediretta le colonne restano intere; le intestazioni cambiano con la lingua
# di Windows, quindi le colonne si ricavano dalle posizioni e non dai nomi.
function Start-AppUpgradeScan {
    if (-not $script:Winget -or $null -ne $script:AppScan) { return }
    $script:AppScanFile = Join-Path $env:TEMP 'TweakAndrew_upgrade.txt'
    Remove-Item -LiteralPath $script:AppScanFile -ErrorAction SilentlyContinue
    try {
        $script:AppScan = Start-AppHidden 'cmd.exe' "/d /s /c `"`"$($script:Winget)`" upgrade --accept-source-agreements --disable-interactivity > `"$($script:AppScanFile)`" 2>&1`""
        $script:AppTimer.Start()
    } catch { $script:AppScan = $null }
}

function ConvertFrom-WingetTable([string]$text) {
    $out = @()
    $lines = @($text -split "`n" | ForEach-Object {
        # I ritorni a capo in mezzo alla riga sono le rotelline di attesa: conta l'ultimo pezzo.
        $l = ($_.TrimEnd("`r") -split "`r")[-1]
        $l -replace "\x1b\[[0-9;?]*[ -/]*[@-~]", ''
    })
    for ($i = 1; $i -lt $lines.Count; $i++) {
        if ($lines[$i] -notmatch '^-{10,}\s*$') { continue }
        $head = $lines[$i - 1]
        $rows = @()
        for ($k = $i + 1; $k -lt $lines.Count; $k++) {
            if ($lines[$k] -match '^\s*$') { break }
            # Sotto la tabella winget scrive il riepilogo: non e' una riga di dati.
            if ($lines[$k] -match '\s(winget|msstore)\s*$') { $rows += $lines[$k].TrimEnd() }
        }
        # Una colonna comincia dove l'intestazione riprende dopo uno spazio e
        # in tutte le righe il carattere prima e' uno spazio.
        $starts = @(0)
        for ($p = 1; $p -lt $head.Length; $p++) {
            if ($head[$p] -ne ' ' -and $head[$p - 1] -eq ' ') {
                $okCol = $true
                foreach ($r in $rows) { if ($r.Length -gt $p -and $r[$p - 1] -ne ' ') { $okCol = $false; break } }
                if ($okCol) { $starts += $p }
            }
        }
        if ($starts.Count -lt 5) { continue }
        foreach ($r in $rows) {
            $cells = @()
            for ($c = 0; $c -lt $starts.Count; $c++) {
                $a = $starts[$c]
                $b = if ($c + 1 -lt $starts.Count) { $starts[$c + 1] } else { $r.Length }
                $cells += if ($r.Length -gt $a) { $r.Substring($a, [Math]::Min($b, $r.Length) - $a).Trim() } else { '' }
            }
            $src = $cells[$cells.Count - 1]
            if ($src -notin @('winget', 'msstore') -or -not $cells[1] -or $cells[1] -match '\s') { continue }
            $out += [pscustomobject]@{ Name = $cells[0]; Id = $cells[1]; Version = $cells[2]; Available = $cells[3]; Source = $src }
        }
    }
    return $out
}

function Complete-AppUpgradeScan {
    $script:AppScan = $null
    $script:AppScanDone = $true
    $script:AppUpdates = @{}
    try {
        $text = [IO.File]::ReadAllText($script:AppScanFile, [Text.Encoding]::UTF8)
        foreach ($u in @(ConvertFrom-WingetTable $text)) { $script:AppUpdates[$u.Id] = $u }
    } catch {}
    # Le scelte di aggiornamento non piu' valide spariscono.
    foreach ($k in @($script:AppSel | Where-Object { $_ -like 'u:*' })) {
        if (-not $script:AppUpdates.ContainsKey($k.Substring(2))) { [void]$script:AppSel.Remove($k) }
    }
    if ($script:AppsReady) { Show-AppView }
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
    $keys = @($script:AppSel | Where-Object { $_ -notlike 'u:*' })
    if ($keys.Count -eq 0) { return }
    if ($radAppsInstalled.IsChecked) {
        if (-not (Show-Dialog (T 'confirmTitle') ((T 'appsAskUninstall') -f $keys.Count) 'danger')) { return }
        foreach ($a in @($script:AppInstalledList | Where-Object { $keys -contains $_.Key })) {
            # I dati per cercare i residui si prendono adesso: dopo la voce non c'e' piu'.
            if ($a.Kind -eq 'Win32') { [void]$script:LeftoverPending.Add((Get-LeftoverHint $a)) }
            $c = Get-UninstallCommand $a
            Add-AppJob 'uninstall' $a.Name $c[0] $c[1] $false
        }
    } else {
        if (-not (Show-Dialog (T 'confirmTitle') ((T 'appsAskInstall') -f $keys.Count) 'ask')) { return }
        foreach ($a in @($script:AppCatalog | Where-Object { $keys -contains $_.Id })) {
            $src = if ($a.Id -like 'store:*') { 'msstore' } else { 'winget' }
            $id = $a.Id -replace '^store:', ''
            Add-AppJob 'install' $a.Name $script:Winget "install --id $id -e --source $src --silent --accept-package-agreements --accept-source-agreements --disable-interactivity" $true
        }
    }
    Start-AppBatch
})

$btnAppsUpgrade.Add_Click({
    $ids = @($script:AppSel | Where-Object { $_ -like 'u:*' } | ForEach-Object { $_.Substring(2) })
    if ($ids.Count -eq 0) { return }
    if (-not (Show-Dialog (T 'confirmTitle') ((T 'appsAskUpgradeSel') -f $ids.Count) 'ask')) { return }
    foreach ($id in $ids) {
        $u = $script:AppUpdates[$id]
        $name = if ($u) { $u.Name } else { $id }
        $src = if ($u -and $u.Source -eq 'msstore') { 'msstore' } else { 'winget' }
        Add-AppJob 'upgrade' $name $script:Winget "upgrade --id $id -e --source $src --silent --accept-package-agreements --accept-source-agreements --disable-interactivity" $true
    }
    Start-AppBatch
})

$btnAppJobsClose.Add_Click({
    if (Test-AppBusy) { return }
    $script:AppJobList.Clear(); $panAppJobs.Children.Clear()
    $bdAppJobs.Visibility = 'Collapsed'
})

$btnAppsClear.Add_Click({ $script:AppSel.Clear(); Show-AppView })
$btnAppsRefresh.Add_Click({ $script:AppInstalledList = @(); Start-AppExport; Start-AppUpgradeScan; Show-AppView })
$radAppsCatalog.Add_Checked({ if ($script:AppsReady) { $script:AppSel.Clear(); Show-AppView } })
$radAppsInstalled.Add_Checked({ if ($script:AppsReady) { $script:AppSel.Clear(); Show-AppView } })
$cmbAppCategory.Add_SelectionChanged({ if ($script:AppsReady -and -not $script:AppFiltersLoading) { Show-AppCatalog } })
$cmbAppLicense.Add_SelectionChanged({ if ($script:AppsReady -and -not $script:AppFiltersLoading) { Show-AppCatalog } })
$txtAppSearch.Add_TextChanged({
    $lblAppSearchHint.Visibility = if ($txtAppSearch.Text) { 'Collapsed' } else { 'Visible' }
    if ($script:AppsReady) { Show-AppView }
})

# ------------------------------------------------------------------------------
# Residui dopo la disinstallazione (come Revo Uninstaller)
# ------------------------------------------------------------------------------
# Finita la disinstallazione si cercano le tracce rimaste: cartelle del
# programma, chiavi di registro, avvii automatici, attivita' pianificate,
# servizi e collegamenti. Si propongono solo elementi con il nome del
# programma o dentro la sua cartella; le cartelle generiche (Windows,
# Microsoft, Common Files...) e quelle dell'editore con altri programmi dentro
# non compaiono mai. Prima di togliere qualcosa: le chiavi di registro e le
# attivita' finiscono in una copia di sicurezza, cartelle e collegamenti nel
# Cestino.
$script:LeftoverPending = New-Object System.Collections.ArrayList
$script:LeftoverResults = @()
$script:LeftoverBoxes = @()
$script:LeftoverBackup = Join-Path $env:ProgramData 'TweakAndrew\Residui'

$script:LeftoverScanScript = @'
param($apps)
$protected = @('windows', 'microsoft', 'common files', 'windowsapps', 'program files', 'program files (x86)', 'programdata',
               'users', 'packages', 'temp', 'microsoft corporation', 'microsoft.net', 'internet explorer', 'windows defender',
               'windows nt', 'windowspowershell', 'reference assemblies', 'msbuild', 'installer', 'intel', 'nvidia corporation',
               'amd', 'google', 'mozilla', 'apple', 'adobe', 'package cache', 'start menu', 'programs', 'startup', 'desktop')
function Core([string]$n) {
    $c = $n -replace '\s*\(.*?\)', '' -replace '\s+(v|version\s*)?\d+(\.\d+)+.*$', '' -replace '\s+\d{4}$', '' -replace '(?i)\s+(x64|x86|64-bit|32-bit|\(64-bit\))$', ''
    return $c.Trim(' ', '-', '_', '.')
}
function Norm([string]$s) { return ($s -replace '[\s\-_\.]', '').ToLowerInvariant() }
function Add-Item($list, $kind, $path, $label, $sure) {
    if (-not $path) { return }
    if (@($list | Where-Object { $_.Path -eq $path -and $_.Kind -eq $kind }).Count) { return }
    [void]$list.Add(@{ Kind = $kind; Path = $path; Label = $label; Sure = [bool]$sure })
}
$out = @()
foreach ($a in $apps) {
    $list = New-Object System.Collections.ArrayList
    $core = Core $a.Name
    $pub = Core ($a.Publisher -replace '(?i),?\s*(inc|ltd|llc|gmbh|s\.?r\.?l|s\.?p\.?a|corporation|corp|co)\.?$', '')
    $nc = Norm $core; $np = Norm $pub
    if ($nc.Length -lt 3 -or $protected -contains $core.ToLowerInvariant()) { $out += @{ Name = $a.Name; Items = @() }; continue }
    $sysRoots = @($env:SystemRoot, "$env:SystemDrive\", $env:ProgramFiles, ${env:ProgramFiles(x86)}, $env:ProgramData, $env:APPDATA, $env:LOCALAPPDATA) | ForEach-Object { $_.TrimEnd('\') }

    # 1. La cartella dichiarata dal programma e quella del suo disinstallatore.
    $dirs = @()
    if ($a.Location) { $dirs += $a.Location.Trim('"').TrimEnd('\') }
    foreach ($s in @($a.Icon, $a.Uninstall)) {
        if ($s -match '^"?([A-Za-z]:\\[^",]+?\.(exe|ico|dll))') { $dirs += (Split-Path $Matches[1] -Parent) }
    }
    foreach ($d in $dirs) {
        if (-not $d -or -not (Test-Path -LiteralPath $d)) { continue }
        if ($sysRoots -contains $d -or $d -like "$env:SystemRoot*") { continue }
        if ($protected -contains (Split-Path $d -Leaf).ToLowerInvariant()) { continue }
        Add-Item $list 'dir' $d $d $true
    }
    $known = @($list | ForEach-Object { $_.Path })

    # 2. Cartelle con il nome del programma, anche dentro quella dell'editore.
    $roots = @($env:ProgramFiles, ${env:ProgramFiles(x86)}, $env:ProgramData, $env:APPDATA, $env:LOCALAPPDATA, (Join-Path (Split-Path $env:LOCALAPPDATA -Parent) 'LocalLow')) | Where-Object { $_ -and (Test-Path -LiteralPath $_) } | Select-Object -Unique
    foreach ($r in $roots) {
        foreach ($d in @(Get-ChildItem -LiteralPath $r -Directory -Force -ErrorAction SilentlyContinue)) {
            $n = Norm $d.Name
            if ($protected -contains $d.Name.ToLowerInvariant()) {
                if ($np -and $n -eq $np) { } else { continue }
            }
            if ($n -eq $nc) { Add-Item $list 'dir' $d.FullName $d.FullName $true; continue }
            if ($np -and $np.Length -ge 3 -and $n -eq $np) {
                $subs = @(Get-ChildItem -LiteralPath $d.FullName -Directory -Force -ErrorAction SilentlyContinue)
                foreach ($s in $subs) { if ((Norm $s.Name) -eq $nc) { Add-Item $list 'dir' $s.FullName $s.FullName $true } }
                $files = @(Get-ChildItem -LiteralPath $d.FullName -File -Force -ErrorAction SilentlyContinue)
                $others = @($subs | Where-Object { (Norm $_.Name) -ne $nc })
                if ($others.Count -eq 0 -and $files.Count -eq 0 -and $subs.Count -gt 0) { Add-Item $list 'dir' $d.FullName $d.FullName $false }
                continue
            }
            if ($nc.Length -ge 5 -and $n.StartsWith($nc)) { Add-Item $list 'dir' $d.FullName $d.FullName $false }
        }
    }

    # 3. Registro: la voce di disinstallazione se e' rimasta, e le chiavi del programma.
    if ($a.RegPath -and (Test-Path -LiteralPath $a.RegPath)) { Add-Item $list 'reg' $a.RegPath (($a.RegPath -replace '^Microsoft\.PowerShell\.Core\\Registry::', '')) $true }
    foreach ($hive in 'HKCU:\Software', 'HKLM:\SOFTWARE', 'HKLM:\SOFTWARE\WOW6432Node') {
        foreach ($k in @(Get-ChildItem -LiteralPath $hive -ErrorAction SilentlyContinue)) {
            $n = Norm $k.PSChildName
            if ($n -eq $nc -and $protected -notcontains $k.PSChildName.ToLowerInvariant()) { Add-Item $list 'reg' $k.PSPath $k.Name $true; continue }
            if ($np -and $np.Length -ge 3 -and $n -eq $np) {
                $subs = @(Get-ChildItem -LiteralPath $k.PSPath -ErrorAction SilentlyContinue)
                foreach ($s in $subs) { if ((Norm $s.PSChildName) -eq $nc) { Add-Item $list 'reg' $s.PSPath $s.Name $true } }
                if ($subs.Count -gt 0 -and @($subs | Where-Object { (Norm $_.PSChildName) -ne $nc }).Count -eq 0 -and $protected -notcontains $k.PSChildName.ToLowerInvariant()) {
                    Add-Item $list 'reg' $k.PSPath $k.Name $false
                }
            }
        }
    }
    $dirsNow = @($list | Where-Object { $_.Kind -eq 'dir' } | ForEach-Object { $_.Path })
    function Test-Mine([string]$text) {
        if (-not $text) { return $false }
        foreach ($d in $dirsNow) { if ($text -like "*$d*") { return $true } }
        return ((Norm $text) -like "*$nc*")
    }

    # 4. Avvio automatico: chiavi Run e cartelle Esecuzione automatica.
    foreach ($rk in 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Run', 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run', 'HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Run') {
        $p = Get-Item -LiteralPath $rk -ErrorAction SilentlyContinue
        if (-not $p) { continue }
        foreach ($v in $p.GetValueNames()) {
            if ((Test-Mine ([string]$p.GetValue($v))) -or (Norm $v) -eq $nc) { Add-Item $list 'run' "$rk|$v" "$($p.Name)  →  $v" $true }
        }
    }
    foreach ($sf in "$env:APPDATA\Microsoft\Windows\Start Menu\Programs\Startup", "$env:ProgramData\Microsoft\Windows\Start Menu\Programs\StartUp") {
        foreach ($f in @(Get-ChildItem -LiteralPath $sf -File -ErrorAction SilentlyContinue)) {
            if ((Norm $f.BaseName) -like "*$nc*") { Add-Item $list 'file' $f.FullName $f.FullName $true }
        }
    }

    # 5. Menu Start: collegamenti e cartelle con il nome del programma.
    foreach ($sm in "$env:ProgramData\Microsoft\Windows\Start Menu\Programs", "$env:APPDATA\Microsoft\Windows\Start Menu\Programs") {
        foreach ($f in @(Get-ChildItem -LiteralPath $sm -Force -ErrorAction SilentlyContinue)) {
            $n = Norm $f.BaseName
            if ($n -eq $nc -or ($np -and $n -eq $np -and $f.PSIsContainer)) { Add-Item $list $(if ($f.PSIsContainer) { 'dir' } else { 'file' }) $f.FullName $f.FullName $true }
        }
    }
    foreach ($dk in [Environment]::GetFolderPath('Desktop'), [Environment]::GetFolderPath('CommonDesktopDirectory')) {
        foreach ($f in @(Get-ChildItem -LiteralPath $dk -Filter '*.lnk' -ErrorAction SilentlyContinue)) {
            if ((Norm $f.BaseName) -eq $nc) { Add-Item $list 'file' $f.FullName $f.FullName $true }
        }
    }

    # 6. Attivita' pianificate e servizi che puntano al programma.
    try {
        foreach ($t in @(Get-ScheduledTask -ErrorAction Stop | Where-Object { $_.TaskPath -notlike '\Microsoft\*' })) {
            $exe = (@($t.Actions | ForEach-Object { [string]$_.Execute + ' ' + [string]$_.Arguments }) -join ' ')
            if ((Norm $t.TaskName) -like "*$nc*" -or (Test-Mine $exe)) { Add-Item $list 'task' "$($t.TaskPath)|$($t.TaskName)" "$($t.TaskPath)$($t.TaskName)" $true }
        }
    } catch {}
    foreach ($s in @(Get-CimInstance Win32_Service -ErrorAction SilentlyContinue)) {
        $pn = [string]$s.PathName
        if ($pn -like "*$env:SystemRoot*") { continue }
        if (Test-Mine $pn) { Add-Item $list 'svc' $s.Name "$($s.DisplayName)  ($($s.Name))" $false }
    }
    # Cartelle e file dentro una cartella gia' proposta: basta la cartella.
    $dirsAll = @($list | Where-Object { $_.Kind -eq 'dir' } | ForEach-Object { $_.Path.TrimEnd('\') + '\' })
    $list = @($list | Where-Object { $it = $_; -not ($it.Kind -in 'dir', 'file' -and @($dirsAll | Where-Object { $it.Path.StartsWith($_, [StringComparison]::OrdinalIgnoreCase) }).Count -gt 0) })
    $out += @{ Name = $a.Name; Items = @($list) }
}
$out
'@

# Dati del programma presi prima di disinstallarlo: dopo la voce non c'e' piu'.
function Get-LeftoverHint($a) {
    $p = $null
    if ($a.Key -like 'w:*') { $p = Get-ItemProperty -LiteralPath ($a.Key.Substring(2)) -ErrorAction SilentlyContinue }
    return @{ Name = $a.Name; Publisher = $a.Publisher; Location = [string]$p.InstallLocation; Icon = [string]$p.DisplayIcon
              Uninstall = [string]$p.UninstallString; RegPath = $(if ($a.Key -like 'w:*') { $a.Key.Substring(2) } else { '' }); Since = Get-Date }
}

# Si aspetta che il programma sparisca dall'elenco: molti disinstallatori aprono
# una finestra e il comando finisce prima di loro. Si cerca solo quando la
# voce di disinstallazione non c'e' piu', o dopo 10 minuti.
function Start-LeftoverWatch {
    if ($script:LeftoverPending.Count -eq 0) { return }
    if ($script:LeftoverTimer) { $script:LeftoverTimer.Start(); return }
    $script:LeftoverTimer = New-Object System.Windows.Threading.DispatcherTimer
    $script:LeftoverTimer.Interval = [TimeSpan]::FromSeconds(3)
    $script:LeftoverTimer.Add_Tick({
        if ($script:LeftoverJob) { return }
        $ready = @($script:LeftoverPending | Where-Object { -not $_.RegPath -or -not (Test-Path -LiteralPath $_.RegPath) -or ((Get-Date) - $_.Since).TotalMinutes -ge 10 })
        if ($ready.Count -eq 0) { return }
        foreach ($r in $ready) { $script:LeftoverPending.Remove($r) }
        if ($script:LeftoverPending.Count -eq 0) { $this.Stop() }
        Start-LeftoverScan $ready
    })
    $script:LeftoverTimer.Start()
}

function Start-LeftoverScan([array]$apps) {
    $txtAppsStatus.Text = T 'leftScanning'
    $ps = [powershell]::Create()
    [void]$ps.AddScript($script:LeftoverScanScript).AddArgument($apps)
    $script:LeftoverJob = @{ Ps = $ps; H = $ps.BeginInvoke() }
    $t = New-Object System.Windows.Threading.DispatcherTimer
    $t.Interval = [TimeSpan]::FromMilliseconds(300)
    $t.Add_Tick({
        if (-not $script:LeftoverJob.H.IsCompleted) { return }
        $this.Stop()
        try { $r = @($script:LeftoverJob.Ps.EndInvoke($script:LeftoverJob.H) | Where-Object { $_ -is [hashtable] }) } catch { $r = @() }
        $script:LeftoverJob.Ps.Dispose(); $script:LeftoverJob = $null
        $script:LeftoverResults = @($script:LeftoverResults) + @($r | Where-Object { @($_.Items).Count -gt 0 })
        $n = 0; foreach ($x in $r) { $n += @($x.Items).Count }
        $txtAppsStatus.Text = if ($n -gt 0) { (T 'leftFound') -f $n } else { T 'leftNone' }
        Write-Log "[INFO] Residui trovati: $n"
        if ($script:AppsReady) { Show-AppView }
    })
    $t.Start()
}

# Scheda dei residui, in cima all'elenco dei programmi installati.
function New-LeftoverCard {
    $script:LeftoverBoxes = @()
    if (@($script:LeftoverResults).Count -eq 0) { return $null }
    $btn = New-Object System.Windows.Controls.Button
    $btn.Style = $window.FindResource('DotBtn'); $btn.Content = T 'leftRemove'; $btn.Tag = New-AppBrush '#FFF87171'
    $btn.Add_Click({ Invoke-LeftoverRemove })
    $c = New-AppCard (T 'leftTitle') $btn
    [void]$c.Panel.Children.Add((New-AppNote (T 'leftHint')))
    foreach ($res in $script:LeftoverResults) {
        $h = New-Object System.Windows.Controls.TextBlock
        $h.Text = $res.Name; $h.FontWeight = 'SemiBold'; $h.FontSize = 13; $h.Foreground = New-AppBrush '#FFE9EAEE'; $h.Margin = '4,10,0,4'
        [void]$c.Panel.Children.Add($h)
        foreach ($it in $res.Items) {
            $cb = New-Object System.Windows.Controls.CheckBox
            $cb.Tag = $it; $cb.IsChecked = $it.Sure
            $tb = New-Object System.Windows.Controls.TextBlock; $tb.TextWrapping = 'Wrap'
            $r1 = New-Object System.Windows.Documents.Run ("$(T "leftKind_$($it.Kind)")   "); $r1.Foreground = New-AppBrush '#FF7EB1FF'; $r1.FontSize = 11.5; $r1.FontWeight = 'SemiBold'
            $r2 = New-Object System.Windows.Documents.Run $it.Label; $r2.Foreground = New-AppBrush '#FFC9CBD2'; $r2.FontSize = 12
            [void]$tb.Inlines.Add($r1); [void]$tb.Inlines.Add($r2)
            if (-not $it.Sure) { $r3 = New-Object System.Windows.Documents.Run ("   $(T 'leftCheck')"); $r3.Foreground = New-AppBrush '#FFFDBA74'; $r3.FontSize = 11.5; [void]$tb.Inlines.Add($r3) }
            $script:LeftoverBoxes += $cb
            [void]$c.Panel.Children.Add((New-SwitchRow $tb '' $cb))
        }
    }
    return $c.Card
}

# Toglie gli elementi scelti. Registro e attivita' prima si salvano in
# %ProgramData%\TweakAndrew\Residui, cartelle e file vanno nel Cestino.
function Remove-LeftoverItems([array]$items, [switch]$Permanent) {
    Add-Type -AssemblyName Microsoft.VisualBasic
    $dir = Join-Path $script:LeftoverBackup (Get-Date -Format 'yyyyMMdd_HHmmss')
    $ok = 0; $i = 0
    foreach ($it in $items) {
        $i++
        try {
            switch ($it.Kind) {
                'dir' {
                    if (-not (Test-Path -LiteralPath $it.Path)) { $ok++; break }
                    if ($Permanent) { Remove-Item -LiteralPath $it.Path -Recurse -Force -ErrorAction Stop }
                    else { [Microsoft.VisualBasic.FileIO.FileSystem]::DeleteDirectory($it.Path, 'OnlyErrorDialogs', 'SendToRecycleBin', 'DoNothing') }
                    $ok++
                }
                'file' {
                    if (-not (Test-Path -LiteralPath $it.Path)) { $ok++; break }
                    if ($Permanent) { Remove-Item -LiteralPath $it.Path -Force -ErrorAction Stop }
                    else { [Microsoft.VisualBasic.FileIO.FileSystem]::DeleteFile($it.Path, 'OnlyErrorDialogs', 'SendToRecycleBin', 'DoNothing') }
                    $ok++
                }
                'reg' {
                    New-Item -ItemType Directory -Force $dir | Out-Null
                    $native = (Get-Item -LiteralPath $it.Path -ErrorAction Stop).Name
                    & reg.exe export $native (Join-Path $dir "registro_$i.reg") /y | Out-Null
                    if ($LASTEXITCODE -ne 0) { throw "copia di sicurezza non riuscita" }
                    Remove-Item -LiteralPath $it.Path -Recurse -Force -ErrorAction Stop
                    $ok++
                }
                'run' {
                    $k, $v = $it.Path -split '\|', 2
                    New-Item -ItemType Directory -Force $dir | Out-Null
                    $native = (Get-Item -LiteralPath $k -ErrorAction Stop).Name
                    & reg.exe export $native (Join-Path $dir "avvio_$i.reg") /y | Out-Null
                    if ($LASTEXITCODE -ne 0) { throw "copia di sicurezza non riuscita" }
                    Remove-ItemProperty -LiteralPath $k -Name $v -ErrorAction Stop
                    $ok++
                }
                'task' {
                    $tp, $tn = $it.Path -split '\|', 2
                    New-Item -ItemType Directory -Force $dir | Out-Null
                    Export-ScheduledTask -TaskPath $tp -TaskName $tn -ErrorAction Stop | Out-File (Join-Path $dir "attivita_$i.xml") -Encoding Unicode
                    Unregister-ScheduledTask -TaskPath $tp -TaskName $tn -Confirm:$false -ErrorAction Stop
                    $ok++
                }
                'svc' {
                    # Solo se il programma del servizio non esiste piu': altrimenti e' ancora in uso.
                    $s = Get-CimInstance Win32_Service -Filter "Name='$($it.Path -replace "'", "''")'" -ErrorAction Stop
                    $exe = if ([string]$s.PathName -match '^"?([^"]+?\.exe)') { $Matches[1] } else { '' }
                    if ($exe -and (Test-Path -LiteralPath $exe)) { Write-Log "[SALTATO] Servizio $($it.Path) - il programma c'e' ancora."; break }
                    New-Item -ItemType Directory -Force $dir | Out-Null
                    & reg.exe export "HKLM\SYSTEM\CurrentControlSet\Services\$($it.Path)" (Join-Path $dir "servizio_$i.reg") /y | Out-Null
                    Stop-Service -Name $it.Path -Force -ErrorAction SilentlyContinue
                    & sc.exe delete $it.Path | Out-Null
                    if ($LASTEXITCODE -eq 0) { $ok++ }
                }
            }
            Write-Log "[OK] Residuo tolto: $($it.Label)"
        } catch { Write-Log "[ERRORE] Residuo $($it.Label) - $($_.Exception.Message)" }
    }
    return @{ Ok = $ok; Backup = $dir }
}

function Invoke-LeftoverRemove {
    $items = @($script:LeftoverBoxes | Where-Object { $_.IsChecked -eq $true } | ForEach-Object { $_.Tag })
    if ($items.Count -eq 0) { return }
    if (-not (Show-Dialog (T 'leftTitle') ((T 'leftAsk') -f $items.Count) 'warn')) { return }
    $window.Cursor = 'Wait'
    try { $r = Remove-LeftoverItems $items } finally { $window.Cursor = $null }
    $script:LeftoverResults = @()
    $txtAppsStatus.Text = (T 'leftDone') -f $r.Ok, $items.Count
    if (Test-Path -LiteralPath $r.Backup) { Write-Log "[INFO] Copia di sicurezza dei residui: $($r.Backup)" }
    $script:AppInstalledList = @()
    Show-AppView
}

# Prima apertura della pagina: filtri, catalogo e controllo delle app gia' presenti.
function Show-AppsPageIfNeeded {
    if ($script:AppsBuiltLang -eq $script:LangCode) { return }
    $script:AppsBuiltLang = $script:LangCode
    Initialize-AppFilters
    $script:AppsReady = $true
    Show-AppView
    if (-not $script:Winget) {
        $txtAppsStatus.Text = T 'appsNoWinget'
    } else {
        if ($script:AppInstalledIds.Count -eq 0) { Start-AppExport }
        if (-not $script:AppScanDone) { Start-AppUpgradeScan }
    }
    # L'elenco dei programmi serve anche al catalogo, per riconoscere le app
    # installate senza winget: si legge appena la pagina e' disegnata.
    if ($script:AppInstalledList.Count -eq 0) {
        [void]$window.Dispatcher.BeginInvoke([Action]{
            $script:AppInstalledList = Get-InstalledApps
            Show-AppView
        }, [System.Windows.Threading.DispatcherPriority]::ApplicationIdle)
    }
}
