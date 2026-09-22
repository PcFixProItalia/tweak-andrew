# v7.1: selezione per pagina, voci consigliate, «seleziona tutto» che rispetta
# la scheda video rilevata, spooler di stampa solo nella pagina Avanzate.
import io, os
ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))

def patch(name, old, new, cnt=1):
    p = os.path.join(ROOT, name)
    t = io.open(p, encoding='utf-8').read()
    assert t.count(old) == cnt, (name, old[:70], t.count(old))
    io.open(p, 'w', encoding='utf-8').write(t.replace(old, new))

# 1. Barra in basso: due pulsanti nuovi, e la riga va a capo se non ci stanno.
patch('src/partB2.ps1', '''                                    <StackPanel Grid.Column="0" Orientation="Horizontal">
                                        <Button x:Name="btnSelectAll" Style="{StaticResource GhostBtn}" Height="40" Margin="0,0,8,0" Content="Seleziona tutto"/>
                                        <Button x:Name="btnDeselectAll" Style="{StaticResource GhostBtn}" Height="40" Margin="0,0,8,0" Content="Deseleziona"/>
                                        <Button x:Name="btnDetectActive" Style="{StaticResource GhostBtn}" Height="40" Margin="0,0,8,0" Content="Rileva gia attivi"/>
                                    </StackPanel>''',
'''                                    <WrapPanel Grid.Column="0" Orientation="Horizontal">
                                        <Button x:Name="btnSelectAll" Style="{StaticResource GhostBtn}" Height="40" Margin="0,0,8,4" Content="Seleziona tutto"/>
                                        <Button x:Name="btnSelectPage" Style="{StaticResource GhostBtn}" Height="40" Margin="0,0,8,4" Content="Questa pagina"/>
                                        <Button x:Name="btnRecommended" Style="{StaticResource GhostBtn}" Height="40" Margin="0,0,8,4" Content="Consigliati"/>
                                        <Button x:Name="btnDeselectAll" Style="{StaticResource GhostBtn}" Height="40" Margin="0,0,8,4" Content="Deseleziona"/>
                                        <Button x:Name="btnDetectActive" Style="{StaticResource GhostBtn}" Height="40" Margin="0,0,8,4" Content="Rileva gia attivi"/>
                                    </WrapPanel>''')

# 2. Schede video presenti: serve a Test-Gpu e alla selezione.
patch('src/partF.ps1', """$script:GpuVendor = 'Unknown'

function Show-GpuInfo {""", """$script:GpuVendor = 'Unknown'
# Tutte le marche presenti nel PC: un portatile ha spesso Intel integrata piu'
# una scheda dedicata, e le voci dell'una non devono finire sull'altra.
$script:GpuVendors = @()

function Show-GpuInfo {""")
patch('src/partF.ps1', """        $txtGpuDetected.Text = T 'gpuNone'
        $script:GpuVendor = 'Unknown'
        return""", """        $txtGpuDetected.Text = T 'gpuNone'
        $script:GpuVendor = 'Unknown'
        $script:GpuVendors = @()
        return""")
patch('src/partF.ps1', """    else                                                   { $script:GpuVendor = 'Unknown' }""",
"""    else                                                   { $script:GpuVendor = 'Unknown' }

    $script:GpuVendors = @(
        @(@{ V = 'NVIDIA'; P = 'NVIDIA|GeForce|RTX|GTX|Quadro' }, @{ V = 'AMD'; P = 'Radeon|AMD|ATI' }, @{ V = 'Intel'; P = 'Intel' }) |
        Where-Object { $names -match $_.P } | ForEach-Object { $_.V }
    )""")
patch('src/partF.ps1', """    if ($script:GpuVendor -eq $Vendor) { return $true }""",
"""    if ($script:GpuVendors -contains $Vendor) { return $true }""")

# 3. Selezione: filtro per scheda video, per pagina aperta e voci consigliate.
patch('src/partC.ps1', """$btnSelectAll.Add_Click({
    foreach ($cb in $script:SelectableCheckBoxes) { $cb.IsChecked = $true }
    Update-ApplyButton
})""", """# Voci del produttore sbagliato: su un PC con scheda AMD le caselle NVIDIA
# restano ferme anche con «Seleziona tutto», perche' non farebbero nulla.
function Test-CheckVendor($cb) {
    $vendor = switch -Regex ([string]$cb.Name) {
        '^chkNv'    { 'NVIDIA' }
        '^chkAmd'   { 'AMD' }
        '^chkIntel' { 'Intel' }
        default     { '' }
    }
    if (-not $vendor) { return $true }
    if (@($script:GpuVendors).Count -eq 0) { return $true }
    return ($script:GpuVendors -contains $vendor)
}

function Get-CurrentPage {
    foreach ($entry in $script:NavPages) {
        if ($entry.Nav.IsChecked -eq $true) { return $entry.Page }
    }
    return $null
}

function Get-SelectableChecks([switch]$CurrentPageOnly) {
    $list = @($script:SelectableCheckBoxes | Where-Object { Test-CheckVendor $_ })
    if (-not $CurrentPageOnly) { return $list }
    $page = Get-CurrentPage
    if ($null -eq $page) { return @() }
    $onPage = @(Get-CheckBoxesFromTree $page)
    return @($list | Where-Object { $onPage -contains $_ })
}

# Voci consigliate: quelle sicure e utili su quasi tutti i computer. La pagina
# Avanzate non ne ha: li' si tolgono pezzi di Windows e la scelta resta una
# per una.
$script:RecommendedChecks = @{
    pagePerf    = @('chkMMCSS','chkPriority','chkKernelMem','chkPowerThrottling','chkUSBSuspend','chkNtfsPerf','chkRamTweak','chkGameMode','chkGameDVR')
    pagePrivacy = @('chkTelemetry','chkTelemetryTasks','chkActivityHistory','chkAdvertisingID','chkTailoredExp','chkFeedback','chkErrorReporting',
                    'chkInkingTyping','chkWiFiSense','chkConsumerFeatures','chkStoreSearch','chkSuggestedContent','chkLockScreenAds','chkStartBing',
                    'chkStartRecs','chkStartTracking','chkWindowsAI','chkEdgeDebloat','chkDeliveryOpt','chkWPBT','chkBackgroundApps',
                    'chkRemoteAssistance','chkCompanionApps','chkServicesManual','chkTeredo')
    pageUi      = @('chkDarkTheme','chkFileExt','chkLongPaths','chkExplorerThisPC','chkRemove3D','chkRecycleConfirm','chkMenuDelay','chkStartNoWeb',
                    'chkStartNoAccount','chkTaskbarWidgets','chkTaskbarChat','chkTaskbarEndTask','chkMouseAccel','chkNumLock','chkStickyKeys')
    pageNet     = @('chkNetPowerSave')
    pageStorage = @('chkReservedStorage')
    pagePower   = @('chkFastStartup')
    pageGpu     = @('chkGpuTdr','chkNvTelemetry','chkNvGfe','chkNvPerfMode','chkNvUpdates','chkNvP2','chkNvDrsPower','chkNvLowLatency',
                    'chkNvShaderCache','chkNvDisplayPower','chkAmdUx','chkAmdBloat','chkAmdUlps','chkAmdAntiLag','chkAmdShaderCache','chkIntelBloat')
}

# La pagina Priorita' non ha caselle: i valori consigliati si preparano nei due
# pannelli, poi restano da confermare con Applica e Salva.
function Set-SchedRecommended {
    Select-ComboValue $cmbPsPreset 38
    Select-ComboValue $cmbMmNet -1
    Select-ComboValue $cmbMmResp 10
    Select-ComboValue $cmbMmTask 'Games'
    Select-ComboValue $cmbMmPrio 6
    Select-ComboValue $cmbMmSched 'High'
    Select-ComboValue $cmbMmGpu 8
    Select-ComboValue $cmbMmSfio 'High'
    Select-ComboValue $cmbMmBgOnly 'False'
}

$btnSelectAll.Add_Click({
    foreach ($cb in (Get-SelectableChecks)) { $cb.IsChecked = $true }
    Update-ApplyButton
})

$btnSelectPage.Add_Click({
    $found = @(Get-SelectableChecks -CurrentPageOnly)
    foreach ($cb in $found) { $cb.IsChecked = $true }
    if ($found.Count -eq 0) { $txtProgressLabel.Text = T 'selPageNone' }
    Update-ApplyButton
})

$btnRecommended.Add_Click({
    $page = Get-CurrentPage
    if ($null -eq $page) { return }
    $name = [string]$page.Name
    if ($name -eq 'pageSched') {
        Set-SchedRecommended
        $txtProgressLabel.Text = T 'recSched'
        return
    }
    $names = $script:RecommendedChecks[$name]
    if (-not $names) { $txtProgressLabel.Text = T 'recNone'; return }
    $n = 0
    foreach ($cb in @(Get-SelectableChecks -CurrentPageOnly)) {
        if ($names -contains [string]$cb.Name) { $cb.IsChecked = $true; $n++ }
    }
    $txtProgressLabel.Text = (T 'recSelected') -f $n
    Update-ApplyButton
})""")
patch('src/partC.ps1', """$btnSelectAll = E 'btnSelectAll'; $btnDeselectAll = E 'btnDeselectAll'; $btnDetectActive = E 'btnDetectActive'""",
"""$btnSelectAll = E 'btnSelectAll'; $btnDeselectAll = E 'btnDeselectAll'; $btnDetectActive = E 'btnDetectActive'
$btnSelectPage = E 'btnSelectPage'; $btnRecommended = E 'btnRecommended'""")

# 4. Spooler di stampa: resta solo tra le voci Avanzate, fuori da «Seleziona tutto».
cat = os.path.join(ROOT, 'catalog', 'catalog.txt')
t = io.open(cat, encoding='utf-8').read()
i = t.index('V|win.svcSpooler|')
j = t.index('V|win.svcDiagTrack|')
assert 'svcSpooler' in t[i:j]
io.open(cat, 'w', encoding='utf-8').write(t[:i] + t[j:])
print('ok')
