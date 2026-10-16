# ------------------------------------------------------------------------------
# 30. HOME: riepilogo del computer e tipo di PC
# ------------------------------------------------------------------------------
# Le letture WMI costano qualche secondo: si fanno in un runspace a parte e la
# pagina si disegna quando arrivano, senza bloccare la finestra.

$panHome = E 'panHome'
$script:HomeInfo = $null
$script:HomeJob = $null

# Portatile o fisso. La scelta manuale vale piu' del rilevamento e resta salvata.
$script:LaptopChassis = @(8, 9, 10, 11, 12, 14, 18, 21, 30, 31, 32)
$script:DesktopChassis = @(3, 4, 5, 6, 7, 13, 15, 16, 35)
# Voci che su un portatile costano batteria: «Consigliati» le lascia stare,
# «Seleziona tutto» le prende dopo un avviso.
$script:LaptopSkip = @('chkPowerThrottling', 'chkNetPowerSave', 'chkHibernation', 'chkS3Sleep',
                       'chkNvPerfMode', 'chkNvDrsPower', 'chkNvDisplayPower', 'chkAmdUlps', 'chkAmdAspm',
                       'chkIntelGfxPower', 'chkIntelDpst', 'chkCpuIntelBoostPol', 'chkCpuAmdParking', 'chkCpuIdleOff')
# Voci utili solo con la batteria: su un fisso si saltano.
$script:DesktopSkip = @('chkBatteryPct')
# Su un server «Consigliati» e «Seleziona tutto» lasciano stare:
# - le difese del kernel (VBS, Spectre, Downfall, exploit, SmartScreen): un
#   server e' esposto in rete e spesso ospita macchine virtuali;
# - priorita' al primo piano, MMCSS, modalita' gioco: su un server lavorano i
#   servizi in secondo piano, ed e' Windows Server a favorirli;
# - servizi che un server puo' usare davvero: ricerca (indicizza le
#   condivisioni), fax, diagnostica, attivita' di manutenzione e controllo disco;
# - tick dinamico, TSC, timer e DPC: su una macchina virtuale possono rendere
#   instabile l'orologio.
$script:ServerSkip = @('chkVBS', 'chkSecSpectre', 'chkSecDownfall', 'chkMitigations', 'chkSecSmartScreen',
                       'chkPriority', 'chkMMCSS', 'chkGameMode', 'chkGameDVR', 'chkHAGS', 'chkFSO', 'chkVisualFX',
                       'chkSvcSearch', 'chkServicesManual', 'chkSvcDiag', 'chkTaskExtra', 'chkTaskMaint',
                       'chkBootDynTick', 'chkBootTsc', 'chkTimer', 'chkKernelDpc', 'chkCpuIdleOff', 'chkBatteryPct')
$script:SettingsKey = 'HKCU:\Software\TweakAndrew'

function Get-PcTypeSetting {
    try { $v = [string](Get-ItemProperty -LiteralPath $script:SettingsKey -Name PcType -ErrorAction Stop).PcType } catch { $v = '' }
    if ($v -in @('desktop', 'laptop', 'server')) { return $v }
    return 'auto'
}

function Get-DetectedPcType([array]$chassis, $systemType, [bool]$battery, $productType = 1) {
    # Windows Server (controller di dominio o server membro).
    if ([int]$productType -in @(2, 3)) { return 'server' }
    if (@($chassis | Where-Object { $script:LaptopChassis -contains [int]$_ }).Count -gt 0) { return 'laptop' }
    if ($systemType -eq 2) { return 'laptop' }
    if (@($chassis | Where-Object { $script:DesktopChassis -contains [int]$_ }).Count -gt 0) { return 'desktop' }
    if ($battery) { return 'laptop' }
    return 'desktop'
}

# Tipo in uso. Se la Home non ha ancora letto l'hardware basta una lettura veloce.
function Get-PcType {
    $set = Get-PcTypeSetting
    if ($set -ne 'auto') { return $set }
    if (-not $script:PcTypeDetected) {
        if ($script:HomeInfo) {
            $script:PcTypeDetected = $script:HomeInfo.PcType
        } else {
            try {
                $ch = @((Get-CimInstance Win32_SystemEnclosure -ErrorAction Stop).ChassisTypes)
                $st = (Get-CimInstance Win32_ComputerSystem -ErrorAction Stop).PCSystemType
                $bat = @(Get-CimInstance Win32_Battery -ErrorAction SilentlyContinue).Count -gt 0
                $pt = (Get-CimInstance Win32_OperatingSystem -ErrorAction Stop).ProductType
                $script:PcTypeDetected = Get-DetectedPcType $ch $st $bat $pt
            } catch { $script:PcTypeDetected = 'desktop' }
        }
    }
    return $script:PcTypeDetected
}

function Test-CheckPcType($cb) {
    $n = [string]$cb.Name
    if ($script:LaptopSkip -notcontains $n -and $script:DesktopSkip -notcontains $n -and $script:ServerSkip -notcontains $n) { return $true }
    $type = Get-PcType
    if ($type -eq 'laptop') { return ($script:LaptopSkip -notcontains $n) }
    if ($type -eq 'server') { return ($script:ServerSkip -notcontains $n) }
    return ($script:DesktopSkip -notcontains $n)
}

function Set-PcTypeSetting([string]$value) {
    try {
        if (-not (Test-Path -LiteralPath $script:SettingsKey)) { New-Item -Path $script:SettingsKey -Force | Out-Null }
        Set-ItemProperty -LiteralPath $script:SettingsKey -Name PcType -Value $value
    } catch { Write-Log "[AVVISO] Tipo di PC non salvato: $($_.Exception.Message)" }
    Write-Log "[OK] Tipo di PC: $value (in uso: $(Get-PcType))"
    if (Get-Command Update-RecStars -ErrorAction SilentlyContinue) { Update-RecStars }
    # I consigli del catalogo dipendono dal tipo: i sigilli si ridisegnano.
    foreach ($pg in @($script:CatBuilt.Keys)) { $script:CatBuilt[$pg] = $null }
    if ($script:HomeInfo) { Show-HomeInfo }
}

# Letture dell'hardware: gira nel runspace, quindi niente T e niente controlli.
$script:HomeInfoScript = @'
function Q([string]$c, [string]$ns = 'root\cimv2') { try { @(Get-CimInstance -Namespace $ns -ClassName $c -ErrorAction Stop) } catch { @() } }
$i = @{}
$cs = Q Win32_ComputerSystem | Select-Object -First 1
$os = Q Win32_OperatingSystem | Select-Object -First 1
$cv = Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' -ErrorAction SilentlyContinue
$i.Pc = $env:COMPUTERNAME
$i.User = [Security.Principal.WindowsIdentity]::GetCurrent().Name
$i.Domain = [string]$cs.Domain; $i.PartOfDomain = [bool]$cs.PartOfDomain
$i.Maker = [string]$cs.Manufacturer; $i.Model = [string]$cs.Model
$build = 0; [void][int]::TryParse([string]$cv.CurrentBuild, [ref]$build)
$prod = [string]$cv.ProductName
if ($build -ge 22000) { $prod = $prod -replace 'Windows 10', 'Windows 11' }
$i.Os = $prod; $i.OsVersion = [string]$cv.DisplayVersion; $i.OsBuild = "$($cv.CurrentBuild).$($cv.UBR)"
$i.OsArch = [string]$os.OSArchitecture; $i.InstallDate = $os.InstallDate; $i.Boot = $os.LastBootUpTime

$i.Cpu = @(Q Win32_Processor | ForEach-Object {
    @{ Name = (([string]$_.Name).Trim() -replace '\s+', ' '); Cores = $_.NumberOfCores; Threads = $_.NumberOfLogicalProcessors; Mhz = $_.MaxClockSpeed }
})

$mods = Q Win32_PhysicalMemory
$i.RamTotal = [double](($mods | Measure-Object -Property Capacity -Sum).Sum)
if (-not $i.RamTotal) { $i.RamTotal = [double]$cs.TotalPhysicalMemory }
$i.RamMods = $mods.Count
$i.RamSlots = [int]((Q Win32_PhysicalMemoryArray | Measure-Object -Property MemoryDevices -Sum).Sum)
$types = @{ 20 = 'DDR'; 21 = 'DDR2'; 24 = 'DDR3'; 26 = 'DDR4'; 29 = 'LPDDR3'; 30 = 'LPDDR4'; 34 = 'DDR5'; 35 = 'LPDDR5' }
$m0 = $mods | Select-Object -First 1
$i.RamType = if ($m0 -and $types.ContainsKey([int]$m0.SMBIOSMemoryType)) { $types[[int]$m0.SMBIOSMemoryType] } else { '' }
$i.RamSpeed = if ($m0.ConfiguredClockSpeed) { $m0.ConfiguredClockSpeed } else { $m0.Speed }

# La memoria video di Win32_VideoController si ferma a 4 GB: quella vera sta nel registro del driver.
$vram = @{}
foreach ($k in @(Get-ChildItem 'HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}' -ErrorAction SilentlyContinue)) {
    $p = Get-ItemProperty -LiteralPath $k.PSPath -ErrorAction SilentlyContinue
    if (-not $p.DriverDesc) { continue }
    $q = $p.'HardwareInformation.qwMemorySize'
    if (-not $q) { $q = $p.'HardwareInformation.MemorySize'; if ($q -is [byte[]]) { $q = [BitConverter]::ToUInt32($q, 0) } }
    if ($q) { $vram[[string]$p.DriverDesc] = [double]$q }
}
$i.Gpu = @(Q Win32_VideoController | Where-Object { $_.Name -and $_.PNPDeviceID -notmatch '^ROOT\\' } | ForEach-Object {
    $v = if ($vram.ContainsKey([string]$_.Name)) { $vram[[string]$_.Name] } else { [double]$_.AdapterRAM }
    @{ Name = [string]$_.Name; Vram = $v; Driver = [string]$_.DriverVersion; DriverDate = $_.DriverDate
       W = $_.CurrentHorizontalResolution; H = $_.CurrentVerticalResolution; Hz = $_.CurrentRefreshRate }
})

$i.Disks = @()
try {
    $i.Disks = @(Get-PhysicalDisk -ErrorAction Stop | Where-Object { $_.Size -gt 0 } | Sort-Object { [int]$_.DeviceId } | ForEach-Object {
        @{ Name = ([string]$_.FriendlyName).Trim(); Size = [double]$_.Size; Media = [string]$_.MediaType; Bus = [string]$_.BusType }
    })
} catch {}
$i.Volumes = @()
try {
    $i.Volumes = @(Get-Volume -ErrorAction Stop | Where-Object { $_.DriveLetter -and $_.DriveType -eq 'Fixed' -and $_.Size -gt 0 } | Sort-Object DriveLetter | ForEach-Object {
        @{ Letter = [string]$_.DriveLetter; Label = [string]$_.FileSystemLabel; Size = [double]$_.Size; Free = [double]$_.SizeRemaining }
    })
} catch {}

$bb = Q Win32_BaseBoard | Select-Object -First 1
$bios = Q Win32_BIOS | Select-Object -First 1
$i.Board = (@([string]$bb.Manufacturer, [string]$bb.Product) | Where-Object { $_ }) -join ' '
$i.Bios = [string]$bios.SMBIOSBIOSVersion; $i.BiosDate = $bios.ReleaseDate
try {
    Add-Type -Namespace TweakAndrewHome -Name Fw -MemberDefinition '[System.Runtime.InteropServices.DllImport("kernel32.dll")] public static extern bool GetFirmwareType(out int t);' -ErrorAction Stop
    $fw = 0; [void][TweakAndrewHome.Fw]::GetFirmwareType([ref]$fw)
    $i.Firmware = switch ($fw) { 1 { 'BIOS' } 2 { 'UEFI' } default { '' } }
} catch { $i.Firmware = '' }
try { $i.SecureBoot = [bool](Confirm-SecureBootUEFI -ErrorAction Stop) } catch { $i.SecureBoot = $null }
$tpm = Q Win32_Tpm 'root\cimv2\security\microsofttpm' | Select-Object -First 1
$i.Tpm = if ($tpm) { ([string]$tpm.SpecVersion -split ',')[0].Trim() } else { '' }

$i.Net = @()
try {
    $i.Net = @(Get-NetAdapter -Physical -ErrorAction Stop | Where-Object { $_.Status -eq 'Up' } | ForEach-Object {
        $ip = @(Get-NetIPAddress -InterfaceIndex $_.ifIndex -AddressFamily IPv4 -ErrorAction SilentlyContinue | ForEach-Object { $_.IPAddress }) -join ', '
        @{ Name = [string]$_.Name; Desc = [string]$_.InterfaceDescription; Speed = [string]$_.LinkSpeed; Ip = $ip; Mac = [string]$_.MacAddress }
    })
} catch {}

$bat = Q Win32_Battery
$i.HasBattery = $bat.Count -gt 0
if ($i.HasBattery) {
    $i.Charge = $bat[0].EstimatedChargeRemaining
    $i.OnAc = @(1, 4, 5) -notcontains [int]$bat[0].BatteryStatus
    $design = (Q BatteryStaticData 'root\wmi' | Select-Object -First 1).DesignedCapacity
    $full = (Q BatteryFullChargedCapacity 'root\wmi' | Select-Object -First 1).FullChargedCapacity
    $i.Health = if ($design -and $full) { [Math]::Min(100, [Math]::Round(100 * $full / $design)) } else { $null }
}
$i.Chassis = @((Q Win32_SystemEnclosure | Select-Object -First 1).ChassisTypes)
$i.ProductType = [int]$os.ProductType
$i.SystemType = $cs.PCSystemType
$i
'@

function Start-HomeInfo {
    if ($null -ne $script:HomeJob) { return }
    $ps = [powershell]::Create()
    [void]$ps.AddScript($script:HomeInfoScript)
    $script:HomeJob = @{ Ps = $ps; Handle = $ps.BeginInvoke() }
    $script:HomeTimer = New-Object System.Windows.Threading.DispatcherTimer
    $script:HomeTimer.Interval = [TimeSpan]::FromMilliseconds(150)
    $script:HomeTimer.Add_Tick({
        if (-not $script:HomeJob.Handle.IsCompleted) { return }
        $script:HomeTimer.Stop()
        try { $res = $script:HomeJob.Ps.EndInvoke($script:HomeJob.Handle) } catch { $res = @() }
        $script:HomeJob.Ps.Dispose()
        $info = @($res | Where-Object { $_ -is [hashtable] }) | Select-Object -First 1
        if ($null -eq $info) { $info = @{ Pc = $env:COMPUTERNAME } }
        $info.PcType = Get-DetectedPcType $info.Chassis $info.SystemType ([bool]$info.HasBattery) $info.ProductType
        $script:HomeInfo = $info
        $script:PcTypeDetected = $info.PcType
        Show-HomeInfo
    })
    $script:HomeTimer.Start()
}

# --- disegno ---
function New-HomeText([string]$text, [double]$size, [string]$color, [string]$weight = 'Normal') {
    $t = New-Object System.Windows.Controls.TextBlock
    $t.Text = $text; $t.FontSize = $size; $t.Foreground = New-AppBrush $color; $t.FontWeight = $weight
    $t.TextWrapping = 'Wrap'; $t.FontFamily = 'Segoe UI Variable Text, Segoe UI'
    return $t
}

function Add-HomeRow($panel, [string]$label, [string]$value) {
    if (-not $value) { return }
    $g = New-Object System.Windows.Controls.Grid; $g.Margin = '0,3,0,3'
    $c0 = New-Object System.Windows.Controls.ColumnDefinition; $c0.Width = New-Object System.Windows.GridLength(118)
    $c1 = New-Object System.Windows.Controls.ColumnDefinition
    $g.ColumnDefinitions.Add($c0); $g.ColumnDefinitions.Add($c1)
    $l = New-HomeText $label 12 '#FF8B8E99'
    $v = New-HomeText $value 12.5 '#FFE9EAEE'
    $v.Margin = '8,0,0,0'
    [System.Windows.Controls.Grid]::SetColumn($v, 1)
    [void]$g.Children.Add($l); [void]$g.Children.Add($v)
    [void]$panel.Children.Add($g)
}

function Add-HomeItem($panel, [string]$title) {
    $t = New-HomeText $title 13 '#FFEEEFF2' 'SemiBold'
    $t.Margin = if ($panel.Children.Count -gt 1) { '0,12,0,3' } else { '0,0,0,3' }
    [void]$panel.Children.Add($t)
}

function Format-HomeSize([double]$b, [switch]$Binary) {
    $u = if ($Binary) { 1GB } else { 1e9 }
    $g = $b / $u
    if ($g -ge 1000) { return ('{0:0.0} TB' -f ($g / 1000)) }
    if ($g -ge 10) { return ('{0:0} GB' -f $g) }
    return ('{0:0.#} GB' -f $g)
}

function Format-HomeDate($d) {
    if (-not $d) { return '' }
    try { return ([datetime]$d).ToString('dd/MM/yyyy') } catch { return '' }
}

function Get-PcTypeName([string]$t) {
    switch ($t) { 'laptop' { T 'homeTypeLaptop' } 'server' { T 'homeTypeServer' } default { T 'homeTypeDesktop' } }
}

function New-HomeHero($i) {
    $card = New-Object System.Windows.Controls.Border
    $card.Style = $window.FindResource('Glass')
    $g = New-Object System.Windows.Controls.Grid
    $c0 = New-Object System.Windows.Controls.ColumnDefinition
    $c1 = New-Object System.Windows.Controls.ColumnDefinition; $c1.Width = [System.Windows.GridLength]::Auto
    $g.ColumnDefinitions.Add($c0); $g.ColumnDefinitions.Add($c1)

    $left = New-Object System.Windows.Controls.StackPanel; $left.VerticalAlignment = 'Center'
    $cap = New-Object System.Windows.Controls.TextBlock; $cap.Text = T 'homeThisPc'; $cap.Style = $window.FindResource('CardTitle'); $cap.Margin = '0,0,0,4'
    [void]$left.Children.Add($cap)
    $name = New-HomeText $i.Pc 28 '#FFFFFFFF' 'Bold'; $name.FontFamily = 'Segoe UI Variable Display, Segoe UI'
    [void]$left.Children.Add($name)
    $grp = if ($i.PartOfDomain) { T 'homeDomain' } else { T 'homeWorkgroup' }
    $l1 = New-HomeText "$($i.User)   ·   $grp $($i.Domain)" 12.5 '#FFA1A4AE'; $l1.Margin = '0,4,0,0'
    [void]$left.Children.Add($l1)
    $osLine = (@($i.Os, $i.OsVersion) | Where-Object { $_ }) -join ' '
    $l2 = New-HomeText "$osLine   ·   build $($i.OsBuild)   ·   $($i.OsArch)" 12.5 '#FFA1A4AE'; $l2.Margin = '0,2,0,0'
    [void]$left.Children.Add($l2)

    $chips = New-Object System.Windows.Controls.WrapPanel; $chips.Margin = '0,12,0,0'
    $up = ''
    if ($i.Boot) {
        $s = (Get-Date) - [datetime]$i.Boot
        $up = if ($s.Days -gt 0) { (T 'homeUptimeD') -f $s.Days, $s.Hours, $s.Minutes } else { (T 'homeUptimeH') -f $s.Hours, $s.Minutes }
    }
    $model = (@($i.Maker, $i.Model) | Where-Object { $_ -and $_ -notmatch 'System manufacturer|System Product Name|To be filled|Default string' }) -join ' '
    foreach ($c in @(
        $(if ($up) { (T 'homeUptime') -f $up }),
        $(if ($i.InstallDate) { (T 'homeInstalledOn') -f (Format-HomeDate $i.InstallDate) }),
        $model)) {
        if (-not $c) { continue }
        $p = New-AppPill $c '#FFC9CBD2' '#FF1B1D23'; $p.Margin = '0,0,8,6'; $p.Padding = '10,4,10,4'
        [void]$chips.Children.Add($p)
    }
    [void]$left.Children.Add($chips)
    [void]$g.Children.Add($left)

    $card.Child = $g
    return $card
}

# Tipo di computer: quattro riquadri grandi, uno per scelta. Decide cosa fanno
# «Consigliati» e «Seleziona tutto», quindi sta in cima, subito visibile.
function New-HomeTypeTile([string]$value, [string]$title, [string]$desc, [bool]$selected) {
    $b = New-Object System.Windows.Controls.Border
    $b.CornerRadius = 8; $b.Padding = '12,10,12,10'; $b.Margin = '0,0,10,0'; $b.Cursor = 'Hand'
    $b.BorderThickness = 1
    $b.BorderBrush = New-AppBrush $(if ($selected) { '#FF2563EB' } else { '#FF2A2D36' })
    $b.Background = New-AppBrush $(if ($selected) { '#FF15244A' } else { '#FF1C1F26' })
    $b.Tag = $value
    $sp = New-Object System.Windows.Controls.StackPanel
    $top = New-Object System.Windows.Controls.Grid
    $tc0 = New-Object System.Windows.Controls.ColumnDefinition; $tc1 = New-Object System.Windows.Controls.ColumnDefinition; $tc1.Width = [System.Windows.GridLength]::Auto
    $top.ColumnDefinitions.Add($tc0); $top.ColumnDefinitions.Add($tc1)
    $t = New-HomeText $title 13 $(if ($selected) { '#FFFFFFFF' } else { '#FFA1A4AE' }) 'SemiBold'
    [void]$top.Children.Add($t)
    if ($selected) { $tk = New-AppTick '#FFE9EAEE' 11; $tk.VerticalAlignment = 'Center'; [System.Windows.Controls.Grid]::SetColumn($tk, 1); [void]$top.Children.Add($tk) }
    [void]$sp.Children.Add($top)
    $d = New-HomeText $desc 12 '#FFA1A4AE'; $d.Margin = '0,5,0,0'
    [void]$sp.Children.Add($d)
    $b.Child = $sp
    $b.Add_MouseLeftButtonUp({ if ((Get-PcTypeSetting) -ne [string]$this.Tag) { Set-PcTypeSetting ([string]$this.Tag) } })
    return $b
}

function New-HomeTypeCard($i) {
    $card = New-Object System.Windows.Controls.Border
    $card.Style = $window.FindResource('Glass')
    $sp = New-Object System.Windows.Controls.StackPanel
    $hg = New-Object System.Windows.Controls.Grid; $hg.Margin = '0,0,0,12'
    $hc0 = New-Object System.Windows.Controls.ColumnDefinition; $hc0.Width = [System.Windows.GridLength]::Auto
    $hc1 = New-Object System.Windows.Controls.ColumnDefinition
    $hg.ColumnDefinitions.Add($hc0); $hg.ColumnDefinitions.Add($hc1)
    $cap = New-Object System.Windows.Controls.TextBlock; $cap.Text = T 'homePcType'; $cap.Style = $window.FindResource('CardTitle'); $cap.Margin = '0'; $cap.VerticalAlignment = 'Center'
    [void]$hg.Children.Add($cap)
    $now = New-AppPill ((T 'homeTypeInUse') -f (Get-PcTypeName (Get-PcType))) '#FF9EC2FF' '#332563EB'
    $now.Margin = '12,0,0,0'
    [System.Windows.Controls.Grid]::SetColumn($now, 1); $now.HorizontalAlignment = 'Left'
    [void]$hg.Children.Add($now)
    [void]$sp.Children.Add($hg)
    $sub = New-HomeText (T 'homeTypeHint') 12.5 '#FFA1A4AE'; $sub.Margin = '0,0,0,12'
    [void]$sp.Children.Add($sub)
    $grid = New-Object System.Windows.Controls.Grid
    $set = Get-PcTypeSetting
    $tiles = @(
        @{ V = 'auto';    T = ((T 'homeTypeAuto') -f (Get-PcTypeName $i.PcType)); D = (T 'homeTypeDescAuto') },
        @{ V = 'desktop'; T = (T 'homeTypeDesktop'); D = (T 'homeTypeDescDesktop') },
        @{ V = 'laptop';  T = (T 'homeTypeLaptop');  D = (T 'homeTypeDescLaptop') },
        @{ V = 'server';  T = (T 'homeTypeServer');  D = (T 'homeTypeDescServer') })
    for ($k = 0; $k -lt $tiles.Count; $k++) {
        $cd = New-Object System.Windows.Controls.ColumnDefinition
        $cd.Width = New-Object System.Windows.GridLength(1, [System.Windows.GridUnitType]::Star)
        $grid.ColumnDefinitions.Add($cd)
        $tile = New-HomeTypeTile $tiles[$k].V $tiles[$k].T $tiles[$k].D ($set -eq $tiles[$k].V)
        if ($k -eq $tiles.Count - 1) { $tile.Margin = '0' }
        [System.Windows.Controls.Grid]::SetColumn($tile, $k)
        [void]$grid.Children.Add($tile)
    }
    [void]$sp.Children.Add($grid)
    $card.Child = $sp
    return $card
}

# Archiviazione: a sinistra i dischi fisici, a destra le unita' con la barra
# dello spazio occupato. Una riga per elemento, anche con molti dischi.
function New-HomeDiskRow($d) {
    $g = New-Object System.Windows.Controls.Grid; $g.Margin = '0,0,0,8'
    $c0 = New-Object System.Windows.Controls.ColumnDefinition
    $c1 = New-Object System.Windows.Controls.ColumnDefinition; $c1.Width = [System.Windows.GridLength]::Auto
    $g.ColumnDefinitions.Add($c0); $g.ColumnDefinitions.Add($c1)
    $n = New-HomeText $d.Name 12.5 '#FFE9EAEE'; $n.TextWrapping = 'NoWrap'; $n.TextTrimming = 'CharacterEllipsis'; $n.VerticalAlignment = 'Center'
    [void]$g.Children.Add($n)
    $tags = New-Object System.Windows.Controls.StackPanel; $tags.Orientation = 'Horizontal'
    $kind = if ($d.Bus -eq 'NVMe') { 'NVMe' } elseif ($d.Media -in @('SSD', 'HDD')) { $d.Media } else { '' }
    if ($kind) {
        $col = switch ($kind) { 'NVMe' { '#FF9EC2FF' } 'SSD' { '#FF7FD1B9' } default { '#FFE0A25E' } }
        [void]$tags.Children.Add((New-AppPill $kind $col '#FF1B1D23'))
    }
    if ($d.Bus -and $d.Bus -notin @('NVMe', 'Unspecified')) { [void]$tags.Children.Add((New-AppPill $d.Bus '#FFC9CBD2' '#FF1B1D23')) }
    $sz = New-HomeText (Format-HomeSize $d.Size) 12.5 '#FFC9CBD2'; $sz.Margin = '10,0,0,0'; $sz.VerticalAlignment = 'Center'; $sz.Width = 64; $sz.TextAlignment = 'Right'
    [void]$tags.Children.Add($sz)
    [System.Windows.Controls.Grid]::SetColumn($tags, 1); [void]$g.Children.Add($tags)
    return $g
}

function New-HomeVolumeRow($v) {
    $sp = New-Object System.Windows.Controls.StackPanel; $sp.Margin = '0,0,0,9'
    $g = New-Object System.Windows.Controls.Grid
    $c0 = New-Object System.Windows.Controls.ColumnDefinition
    $c1 = New-Object System.Windows.Controls.ColumnDefinition; $c1.Width = [System.Windows.GridLength]::Auto
    $g.ColumnDefinitions.Add($c0); $g.ColumnDefinitions.Add($c1)
    $lbl = if ($v.Label) { "$($v.Letter):  $($v.Label)" } else { "$($v.Letter):" }
    $n = New-HomeText $lbl 12.5 '#FFE9EAEE'; $n.TextWrapping = 'NoWrap'; $n.TextTrimming = 'CharacterEllipsis'
    [void]$g.Children.Add($n)
    $f = New-HomeText ((T 'homeFreeFmt') -f (Format-HomeSize $v.Free), (Format-HomeSize $v.Size)) 12 '#FFA1A4AE'; $f.TextWrapping = 'NoWrap'
    [System.Windows.Controls.Grid]::SetColumn($f, 1); [void]$g.Children.Add($f)
    [void]$sp.Children.Add($g)
    # Con un 1 intero [Math]::Min sceglie la versione per interi e arrotonda a 0 o 1.
    $used = if ($v.Size -gt 0) { [Math]::Max([double]0, [Math]::Min([double]1, [double](1 - $v.Free / $v.Size))) } else { [double]0 }
    $bar = New-Object System.Windows.Controls.Grid; $bar.Height = 5; $bar.Margin = '0,5,0,0'
    $u = New-Object System.Windows.Controls.ColumnDefinition; $u.Width = New-Object System.Windows.GridLength([Math]::Max(0.001, $used), [System.Windows.GridUnitType]::Star)
    $r = New-Object System.Windows.Controls.ColumnDefinition; $r.Width = New-Object System.Windows.GridLength([Math]::Max(0.001, 1 - $used), [System.Windows.GridUnitType]::Star)
    $bar.ColumnDefinitions.Add($u); $bar.ColumnDefinitions.Add($r)
    $bg = New-Object System.Windows.Controls.Border; $bg.CornerRadius = 3; $bg.Background = New-AppBrush '#FF24262D'
    [System.Windows.Controls.Grid]::SetColumnSpan($bg, 2); [void]$bar.Children.Add($bg)
    $fill = New-Object System.Windows.Controls.Border; $fill.CornerRadius = 3
    $fill.Background = New-AppBrush $(if ($used -ge 0.9) { '#FFF87171' } elseif ($used -ge 0.75) { '#FFE0A25E' } else { '#FF2563EB' })
    [void]$bar.Children.Add($fill)
    [void]$sp.Children.Add($bar)
    return $sp
}

function New-HomeStorageCard($i) {
    $c = New-AppCard (T 'homeDisks')
    $g = New-Object System.Windows.Controls.Grid
    foreach ($w in 1, 1) { $cd = New-Object System.Windows.Controls.ColumnDefinition; $cd.Width = New-Object System.Windows.GridLength($w, [System.Windows.GridUnitType]::Star); $g.ColumnDefinitions.Add($cd) }
    $left = New-Object System.Windows.Controls.StackPanel; $left.Margin = '0,0,14,0'
    $right = New-Object System.Windows.Controls.StackPanel; $right.Margin = '14,0,0,0'
    [System.Windows.Controls.Grid]::SetColumn($right, 1)
    $h1 = New-HomeText (T 'homePhysDisks') 12 '#FF8B8E99' 'SemiBold'; $h1.Margin = '0,0,0,8'
    [void]$left.Children.Add($h1)
    foreach ($d in $i.Disks) { [void]$left.Children.Add((New-HomeDiskRow $d)) }
    $h2 = New-HomeText (T 'homeVolumes') 12 '#FF8B8E99' 'SemiBold'; $h2.Margin = '0,0,0,8'
    [void]$right.Children.Add($h2)
    foreach ($v in $i.Volumes) { [void]$right.Children.Add((New-HomeVolumeRow $v)) }
    [void]$g.Children.Add($left); [void]$g.Children.Add($right)
    [void]$c.Panel.Children.Add($g)
    return $c
}

function Show-HomeInfo {
    $i = $script:HomeInfo
    if ($null -eq $i) { return }
    $panHome.Children.Clear()
    [void]$panHome.Children.Add((New-HomeHero $i))
    [void]$panHome.Children.Add((New-HomeTypeCard $i))

    $cards = New-Object System.Collections.ArrayList
    $on = T 'valOn'; $off = T 'valOff'

    $c = New-AppCard (T 'homeCpu')
    foreach ($p in $i.Cpu) {
        Add-HomeItem $c.Panel $p.Name
        Add-HomeRow $c.Panel (T 'hkCores') "$($p.Cores) / $($p.Threads)"
        if ($p.Mhz) { Add-HomeRow $c.Panel (T 'hkClock') ('{0:0.00} GHz' -f ($p.Mhz / 1000)) }
    }
    [void]$cards.Add($c)

    $c = New-AppCard (T 'homeRam')
    Add-HomeRow $c.Panel (T 'hkTotal') (Format-HomeSize $i.RamTotal -Binary)
    $rt = (@($i.RamType, $(if ($i.RamSpeed) { "$($i.RamSpeed) MT/s" })) | Where-Object { $_ }) -join '  ·  '
    Add-HomeRow $c.Panel (T 'hkRamType') $rt
    if ($i.RamMods) {
        $slots = if ($i.RamSlots -ge $i.RamMods) { (T 'homeSlotsFmt') -f $i.RamMods, $i.RamSlots } else { "$($i.RamMods)" }
        Add-HomeRow $c.Panel (T 'hkSlots') $slots
    }
    [void]$cards.Add($c)

    $c = New-AppCard (T 'homeGpu')
    foreach ($p in $i.Gpu) {
        Add-HomeItem $c.Panel $p.Name
        if ($p.Vram -gt 0) { Add-HomeRow $c.Panel (T 'hkVram') (Format-HomeSize $p.Vram -Binary) }
        $d = Format-HomeDate $p.DriverDate
        Add-HomeRow $c.Panel (T 'hkDriver') ($(if ($d) { "$($p.Driver)  ($d)" } else { $p.Driver }))
        if ($p.W) { Add-HomeRow $c.Panel (T 'hkRes') ("$($p.W) × $($p.H)" + $(if ($p.Hz) { "  ·  $($p.Hz) Hz" })) }
    }
    [void]$cards.Add($c)

    $c = New-AppCard (T 'homeBoard')
    Add-HomeRow $c.Panel (T 'hkModel') $i.Board
    $bd = Format-HomeDate $i.BiosDate
    Add-HomeRow $c.Panel 'BIOS' ($(if ($bd) { "$($i.Bios)  ($bd)" } else { $i.Bios }))
    Add-HomeRow $c.Panel (T 'hkFirmware') $i.Firmware
    if ($null -ne $i.SecureBoot) { Add-HomeRow $c.Panel 'Secure Boot' ($(if ($i.SecureBoot) { $on } else { $off })) }
    Add-HomeRow $c.Panel 'TPM' ($(if ($i.Tpm) { $i.Tpm } else { T 'valNone' }))
    [void]$cards.Add($c)

    $c = New-AppCard (T 'homeNet')
    if ($i.Net.Count -eq 0) { [void]$c.Panel.Children.Add((New-AppNote (T 'homeNoNet'))) }
    foreach ($p in $i.Net) {
        Add-HomeItem $c.Panel $p.Name
        Add-HomeRow $c.Panel (T 'hkAdapter') $p.Desc
        Add-HomeRow $c.Panel (T 'hkSpeed') $p.Speed
        Add-HomeRow $c.Panel 'IPv4' $p.Ip
    }
    [void]$cards.Add($c)

    if ($i.HasBattery) {
        $c = New-AppCard (T 'homeBattery')
        if ($null -ne $i.Charge) { Add-HomeRow $c.Panel (T 'hkCharge') "$($i.Charge)%" }
        Add-HomeRow $c.Panel (T 'hkPower') ($(if ($i.OnAc) { T 'valOnAc' } else { T 'valOnBattery' }))
        if ($i.Health) { Add-HomeRow $c.Panel (T 'hkHealth') "$($i.Health)%" }
        [void]$cards.Add($c)
    }

    # Tre colonne riempite a turno verso la piu' corta.
    $grid = New-Object System.Windows.Controls.Grid
    $cols = @()
    for ($k = 0; $k -lt 3; $k++) {
        $cd = New-Object System.Windows.Controls.ColumnDefinition
        $cd.Width = New-Object System.Windows.GridLength(1, [System.Windows.GridUnitType]::Star)
        $grid.ColumnDefinitions.Add($cd)
        $sp = New-Object System.Windows.Controls.StackPanel
        [System.Windows.Controls.Grid]::SetColumn($sp, $k); [void]$grid.Children.Add($sp)
        $cols += $sp
    }
    $h = @(0, 0, 0)
    foreach ($cd in $cards) {
        $k = 0; for ($j = 1; $j -lt 3; $j++) { if ($h[$j] -lt $h[$k]) { $k = $j } }
        [void]$cols[$k].Children.Add($cd.Card)
        $h[$k] += $cd.Panel.Children.Count + 2
    }
    [void]$panHome.Children.Add($grid)
    if ($i.Disks.Count -gt 0 -or $i.Volumes.Count -gt 0) { [void]$panHome.Children.Add((New-HomeStorageCard $i).Card) }
}

function Show-HomePageIfNeeded {
    if ($script:HomeInfo) {
        if ($script:HomeBuiltLang -ne $script:LangCode) { $script:HomeBuiltLang = $script:LangCode; Show-HomeInfo }
        return
    }
    $script:HomeBuiltLang = $script:LangCode
    Start-HomeInfo
}

# All'avvio la Home e' la pagina aperta, ma Show-Page e' gia' passato quando
# queste funzioni non esistevano ancora.
if ((E 'tabHome').IsChecked) { Show-HomePageIfNeeded }
