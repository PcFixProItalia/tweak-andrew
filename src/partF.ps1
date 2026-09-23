
# ------------------------------------------------------------------------------
# 18. PIANI DI ALIMENTAZIONE
# ------------------------------------------------------------------------------
# Tre gruppi: i due consigliati, i piani di Windows e quelli di terze parti da
# provare. I piani incorporati finiscono su disco solo al momento dell'importazione.
$script:PlanCatalog = @(
    @{ Key='ultimate'; Group='top'; Kind='duplicate'; Guid='e9a42b02-d5df-448d-aa00-03f14749eb61'
       Match='Ultimate Performance|Prestazioni eccellenti'
       Name='Prestazioni eccellenti (Ultimate Performance)'
       Desc='Piano nascosto di Windows: nessun risparmio energetico, latenza minima.' }
    @{ Key='bitsum'; Group='top'; Kind='embedded'; Match='Bitsum Highest Performance'
       Name='Bitsum Highest Performance'
       Desc='Piano di Bitsum (Process Lasso): prestazioni CPU costanti.' }

    @{ Key='high'; Group='windows'; Kind='builtin'; Guid='8c5e7fda-e8bf-4a96-9a85-a6e23a8c635c'
       Name='Prestazioni elevate'; Desc='Piano standard di Windows ad alte prestazioni.' }
    @{ Key='balanced'; Group='windows'; Kind='builtin'; Guid='381b4222-f694-41f0-9685-ff5bb260df2e'
       Name='Bilanciato'; Desc='Piano predefinito di Windows. Usalo per tornare indietro.' }
    @{ Key='saver'; Group='windows'; Kind='builtin'; Guid='a1841308-3541-4fab-bc81-f71556f20b4a'
       Name='Risparmio energia'; Desc='Consumi minimi, prestazioni ridotte.' }

    @{ Key='adamx'; Group='test'; Kind='embedded'; Match='Adamx Tweaking Utility Power Plan'
       Name='Adamx Tweaking Utility'; Desc='Favorisce le prestazioni sul risparmio energetico.' }
    @{ Key='ancel'; Group='test'; Kind='embedded'; Match='Ancels Power Plan'
       Name='Ancel'; Desc='Prestazioni massime, base Ultimate Performance.' }
    @{ Key='atlas'; Group='test'; Kind='embedded'; Match='Atlas Power Plan'
       Name='Atlas'; Desc='Ottimizzato per le prestazioni massime (v0.4.2).' }
    @{ Key='calypto'; Group='test'; Kind='embedded'; Match="Calypto's Low Latency"
       Name='Calypto Low Latency'; Desc='Disattiva il risparmio energetico per abbassare la latenza.' }
    @{ Key='core'; Group='test'; Kind='embedded'; Match="CoreVeeAir's"
       Name='CoreVeeAir'; Desc='Piano essenziale, poche modifiche mirate.' }
    @{ Key='exmfree'; Group='test'; Kind='embedded'; Match='EXM Free Power Plan'
       Name='EXM Free V6'; Desc='Piu prestazioni e meno latenza; puo alzare le temperature.' }
    @{ Key='framesyncboost'; Group='test'; Kind='embedded'; Match='FRAMESYNC Labs Boost'
       Name='FrameSync Labs Boost'; Desc='Prestazioni massime e latenza minima, idle attivo.' }
    @{ Key='hybred'; Group='test'; Kind='embedded'; Match='Hybred Low Latency'
       Name='Hybred Low Latency'; Desc='Latenza piu bassa e prestazioni piu alte.' }
    @{ Key='kaisen'; Group='test'; Kind='embedded'; Match='^PC$'
       Name='Kaisen'; Desc='Piano pensato per PC fisso.' }
    @{ Key='khorvie'; Group='test'; Kind='embedded'; Match="Khorvie's PowerPlan"
       Name='Khorvie'; Desc='Taglio prestazionale, molte voci modificate.' }
    @{ Key='kirby'; Group='test'; Kind='embedded'; Match='Kirby PowerPlan'
       Name='Kirby v1.2'; Desc='Prestazioni massime, poche voci.' }
    @{ Key='kizzimo'; Group='test'; Kind='embedded'; Match="Kizzimo's Extreme Low Latency"
       Name='Kizzimo Extreme Low Latency'; Desc='Il piu aggressivo sulla latenza.' }
    @{ Key='lawliet'; Group='test'; Kind='embedded'; Match="Lawliet's power plan"
       Name='Lawliet'; Desc='Base bilanciata modificata, consumi piu contenuti.' }
    @{ Key='nexus'; Group='test'; Kind='embedded'; Match='Nexus LiteOS Powerplan'
       Name='Nexus LiteOS'; Desc='Per il gioco, buone prestazioni su desktop.' }
    @{ Key='powerx'; Group='test'; Kind='embedded'; Match='PowerX v2'
       Name='PowerX v2'; Desc='Input lag minimo. Puo causare BSOD su alcune CPU AMD.' }
    @{ Key='sapphire'; Group='test'; Kind='embedded'; Match='^Sapphire$'
       Name='Sapphire'; Desc='Piano di SapphireOS.' }
    @{ Key='vtrl'; Group='test'; Kind='embedded'; Match='VTRL Optimized'
       Name='VTRL Optimized'; Desc='Impostato da VTRL Optimizer, base Ultimate Performance.' }
    @{ Key='xilly'; Group='test'; Kind='embedded'; Match="Xilly's Public PowerPlan"
       Name='Xilly Public'; Desc='Incremento leggero rispetto al predefinito.' }
    @{ Key='xos'; Group='test'; Kind='embedded'; Match='Dimribiy Power Plan'
       Name='xOS (Dimribiy)'; Desc='Piano della raccolta xOS.' }
)

function Get-PowerPlanList {
    $result = @()
    try {
        foreach ($line in (powercfg /list)) {
            $m = [regex]::Match([string]$line, '([0-9a-fA-F]{8}-[0-9a-fA-F-]{27})\s*\(([^\)]*)\)\s*(\*)?')
            if ($m.Success) {
                $result += [pscustomobject]@{
                    Guid   = $m.Groups[1].Value
                    Name   = $m.Groups[2].Value.Trim()
                    Active = $m.Groups[3].Success
                }
            }
        }
    } catch {}
    return $result
}

function Find-PowerPlan {
    param([string]$Pattern)
    if ([string]::IsNullOrWhiteSpace($Pattern)) { return $null }
    return (Get-PowerPlanList | Where-Object { $_.Name -match $Pattern } | Select-Object -First 1)
}

function Import-EmbeddedPlan {
    param([string]$Key)
    if (-not $script:PlanData.ContainsKey($Key)) {
        Write-Log "[ERRORE] Piano '$Key' non presente nel catalogo incorporato."
        return
    }
    $temp = Join-Path $env:TEMP "TweakAndrew_$Key.pow"
    try {
        [System.IO.File]::WriteAllBytes($temp, [System.Convert]::FromBase64String($script:PlanData[$Key]))
        powercfg -import "$temp" | Out-Null
        Write-Log "[OK] Piano '$Key' importato."
    } catch {
        Write-Log "[ERRORE] Importazione di '$Key': $($_.Exception.Message)"
    } finally {
        Remove-Item -LiteralPath $temp -Force -ErrorAction SilentlyContinue
    }
}

function Enable-CatalogPlan {
    param($Entry)
    try {
        $guid = $null
        switch ($Entry.Kind) {
            'builtin' { $guid = $Entry.Guid }
            'duplicate' {
                $found = Find-PowerPlan $Entry.Match
                if (-not $found) {
                    powercfg -duplicatescheme $Entry.Guid | Out-Null
                    $found = Find-PowerPlan $Entry.Match
                }
                if ($found) { $guid = $found.Guid }
            }
            'embedded' {
                $found = Find-PowerPlan $Entry.Match
                if (-not $found) {
                    Import-EmbeddedPlan $Entry.Key
                    $found = Find-PowerPlan $Entry.Match
                }
                if ($found) { $guid = $found.Guid }
            }
        }
        if ($guid) {
            powercfg -setactive $guid | Out-Null
            Write-Log "[OK] Piano attivo: $($Entry.Name) ($guid)."
        } else {
            Write-Log "[AVVISO] Piano '$($Entry.Name)' non trovato dopo l'installazione."
        }
    } catch {
        Write-Log "[ERRORE] Piano '$($Entry.Name)': $($_.Exception.Message)"
    }
    Update-PowerPlanLabel
    Show-PlanList
}

function New-Brush([string]$hex) {
    return (New-Object System.Windows.Media.BrushConverter).ConvertFromString($hex)
}

# Le righe dell'elenco si creano a runtime: venticinque schede scritte a mano nel
# markup sarebbero illeggibili e andrebbero ritoccate a ogni piano aggiunto.
function Add-PlanRow {
    param($Entry, $Parent)

    $card = New-Object System.Windows.Controls.Border
    $card.Style = $window.FindResource("GlassInner")
    $card.Margin = New-Object System.Windows.Thickness(0, 0, 0, 8)
    $card.Padding = New-Object System.Windows.Thickness(14, 11, 12, 11)

    $grid = New-Object System.Windows.Controls.Grid
    $c1 = New-Object System.Windows.Controls.ColumnDefinition
    $c1.Width = New-Object System.Windows.GridLength(1, [System.Windows.GridUnitType]::Star)
    $c2 = New-Object System.Windows.Controls.ColumnDefinition
    $c2.Width = [System.Windows.GridLength]::Auto
    $grid.ColumnDefinitions.Add($c1) | Out-Null
    $grid.ColumnDefinitions.Add($c2) | Out-Null

    $texts = New-Object System.Windows.Controls.StackPanel
    $texts.Margin = New-Object System.Windows.Thickness(0, 0, 12, 0)

    $title = New-Object System.Windows.Controls.TextBlock
    $title.Text = [string]$Entry.Name
    $title.FontFamily = New-Object System.Windows.Media.FontFamily("Raleway, Segoe UI")
    $title.FontWeight = [System.Windows.FontWeights]::SemiBold
    $title.FontSize = 13
    $title.TextWrapping = [System.Windows.TextWrapping]::Wrap
    $title.Foreground = New-Brush "#FFF2F2F5"

    $desc = New-Object System.Windows.Controls.TextBlock
    $desc.Text = [string]$Entry.Desc
    $desc.Style = $window.FindResource("SubTitle")
    $desc.Margin = New-Object System.Windows.Thickness(0, 3, 0, 0)

    $texts.Children.Add($title) | Out-Null
    $texts.Children.Add($desc) | Out-Null
    [System.Windows.Controls.Grid]::SetColumn($texts, 0)

    $btn = New-Object System.Windows.Controls.Button
    $btn.Style = $window.FindResource("GhostBtn")
    $btn.VerticalAlignment = [System.Windows.VerticalAlignment]::Center
    $btn.MinWidth = 104
    $btn.Tag = $Entry
    [System.Windows.Controls.Grid]::SetColumn($btn, 1)

    $isActive = $false
    if ($Entry.Kind -eq 'builtin') {
        $isActive = ($script:ActivePlanGuid -eq $Entry.Guid)
    } elseif ($script:ActivePlanName -and $Entry.Match) {
        $isActive = ($script:ActivePlanName -match $Entry.Match)
    }

    if ($isActive) {
        $btn.Content = T 'planActive'
        $btn.IsEnabled = $false
        $card.BorderBrush = New-Brush "#FFFFC53D"
        $card.Background = New-Brush "#1FFFC53D"
    } else {
        $btn.Content = T 'planApply'
        $btn.Add_Click({ Enable-CatalogPlan $this.Tag })
    }

    $grid.Children.Add($texts) | Out-Null
    $grid.Children.Add($btn) | Out-Null
    $card.Child = $grid
    $Parent.Children.Add($card) | Out-Null
}

function Add-PlanGroupTitle {
    param([string]$Text, $Parent, [string]$Color)
    $t = New-Object System.Windows.Controls.TextBlock
    $t.Text = $Text
    $t.Style = $window.FindResource("CardTitle")
    if ($Color) { $t.Foreground = New-Brush $Color }
    $t.Margin = New-Object System.Windows.Thickness(0, 6, 0, 10)
    $Parent.Children.Add($t) | Out-Null
}

function Show-PlanList {
    if ($null -eq $panPlans) { return }
    $current = Get-PowerPlanList | Where-Object { $_.Active } | Select-Object -First 1
    $script:ActivePlanName = if ($current) { $current.Name } else { "" }
    $script:ActivePlanGuid = if ($current) { $current.Guid } else { "" }

    $panPlans.Children.Clear()

    Add-PlanGroupTitle (T 'planTop') $panPlans "#FFFFC53D"
    foreach ($e in ($script:PlanCatalog | Where-Object { $_.Group -eq 'top' })) { Add-PlanRow $e $panPlans }

    Add-PlanGroupTitle (T 'planWindows') $panPlans "#FF8E8E98"
    foreach ($e in ($script:PlanCatalog | Where-Object { $_.Group -eq 'windows' })) { Add-PlanRow $e $panPlans }

    Add-PlanGroupTitle (T 'planTest') $panPlans "#FFE0A25E"
    $hint = New-Object System.Windows.Controls.TextBlock
    $hint.Text = T 'planTestHint'
    $hint.Style = $window.FindResource("SubTitle")
    $hint.Foreground = New-Brush "#FFD9A470"
    $hint.Margin = New-Object System.Windows.Thickness(0, -4, 0, 12)
    $panPlans.Children.Add($hint) | Out-Null
    foreach ($e in ($script:PlanCatalog | Where-Object { $_.Group -eq 'test' })) { Add-PlanRow $e $panPlans }
}

$btnRefreshPlans.Add_Click({ Update-PowerPlanLabel; Show-PlanList })

# Toglie i piani di prova importati. Un piano attivo non si puo' eliminare,
# quindi prima si torna su Bilanciato.
$btnRemoveTestPlans.Add_Click({
    if (-not (Show-Dialog (T 'confirmTitle') (T 'planRemoveAsk') 'warn')) { return }

    powercfg -setactive 381b4222-f694-41f0-9685-ff5bb260df2e | Out-Null
    $removed = 0
    foreach ($entry in ($script:PlanCatalog | Where-Object { $_.Group -eq 'test' })) {
        $found = Find-PowerPlan $entry.Match
        if ($found) {
            try { powercfg -delete $found.Guid | Out-Null; $removed++ } catch {}
        }
    }
    Write-Log "[OK] Piani di prova rimossi: $removed."
    Update-PowerPlanLabel
    Show-PlanList
})

# ------------------------------------------------------------------------------
# 19. SCHEDA VIDEO
# ------------------------------------------------------------------------------
$script:GpuVendor = 'Unknown'
# Tutte le marche presenti nel PC: un portatile ha spesso Intel integrata piu'
# una scheda dedicata, e le voci dell'una non devono finire sull'altra.
$script:GpuVendors = @()

function Show-GpuInfo {
    if ($null -eq $txtGpuDetected) { return }
    try {
        $gpus = @(Get-CimInstance Win32_VideoController -ErrorAction Stop |
                  Where-Object { $_.Name -and $_.PNPDeviceID -notmatch '^ROOT\\' })
    } catch { $gpus = @() }

    if ($gpus.Count -eq 0) {
        $txtGpuDetected.Text = T 'gpuNone'
        $script:GpuVendor = 'Unknown'
        $script:GpuVendors = @()
        return
    }

    $names = ($gpus | ForEach-Object { $_.Name }) -join ' '
    if     ($names -match 'NVIDIA|GeForce|RTX|GTX|Quadro') { $script:GpuVendor = 'NVIDIA' }
    elseif ($names -match 'Radeon|AMD|ATI')                { $script:GpuVendor = 'AMD' }
    elseif ($names -match 'Intel')                         { $script:GpuVendor = 'Intel' }
    else                                                   { $script:GpuVendor = 'Unknown' }

    $script:GpuVendors = @(
        @(@{ V = 'NVIDIA'; P = 'NVIDIA|GeForce|RTX|GTX|Quadro' }, @{ V = 'AMD'; P = 'Radeon|AMD|ATI' }, @{ V = 'Intel'; P = 'Intel' }) |
        Where-Object { $names -match $_.P } | ForEach-Object { $_.V }
    )

    $lines = foreach ($g in $gpus) {
        $data = if ($g.DriverDate) { ([datetime]$g.DriverDate).ToString('dd/MM/yyyy') } else { '?' }
        "  $($g.Name)`n    driver $($g.DriverVersion) del $data"
    }
    $txtGpuDetected.Text = "$(T 'gpuVendor') $($script:GpuVendor)`n" + ($lines -join "`n")
}

# ------------------------------------------------------------------------------
# 19b. PROCESSORE: marca, architettura ibrida e X3D a due chiplet
# ------------------------------------------------------------------------------
Add-Type -ErrorAction SilentlyContinue -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
namespace TweakAndrew {
public static class CpuInfo {
    [DllImport("kernel32.dll", SetLastError = true)]
    static extern bool GetLogicalProcessorInformationEx(int relation, IntPtr buffer, ref int length);
    // Vero se i core non hanno tutti la stessa classe di efficienza (core P ed E).
    public static bool IsHybrid() {
        int len = 0;
        GetLogicalProcessorInformationEx(0, IntPtr.Zero, ref len);
        if (len <= 0) return false;
        IntPtr buf = Marshal.AllocHGlobal(len);
        try {
            if (!GetLogicalProcessorInformationEx(0, buf, ref len)) return false;
            int off = 0; int first = -1;
            while (off < len) {
                IntPtr item = new IntPtr(buf.ToInt64() + off);
                int size = Marshal.ReadInt32(item, 4);
                int eff = Marshal.ReadByte(item, 9);
                if (first < 0) first = eff; else if (eff != first) return true;
                if (size <= 0) break;
                off += size;
            }
            return false;
        } finally { Marshal.FreeHGlobal(buf); }
    }
}
}
'@

$script:CpuName = ''
try { $script:CpuName = ([string](Get-ItemProperty 'HKLM:\HARDWARE\DESCRIPTION\System\CentralProcessor\0' -ErrorAction Stop).ProcessorNameString).Trim() -replace '\s+', ' ' } catch {}
$script:CpuVendor = if ($env:PROCESSOR_IDENTIFIER -match 'GenuineIntel') { 'Intel' } elseif ($env:PROCESSOR_IDENTIFIER -match 'AuthenticAMD') { 'AMD' } else { '' }
$script:CpuHybrid = $false
try { $script:CpuHybrid = [TweakAndrew.CpuInfo]::IsHybrid() } catch {}
# Ryzen X3D con due chiplet: Windows parcheggia di proposito i core senza cache
# 3D mentre si gioca. Togliere il parcheggio lì peggiora le prestazioni.
$script:CpuDualX3D = $script:CpuName -match '(7900|7950|9900|9950)X3D'

function Show-CpuInfo {
    if ($null -eq $txtCpuDetected) { return }
    $name = if ($script:CpuName) { $script:CpuName } else { T 'cpuUnknown' }
    $txtCpuDetected.Text = (T 'cpuDetected') -f $name
    foreach ($cb in @($chkCpuIntelBoostPol, $chkCpuIntelHybrid)) { $cb.IsEnabled = ($script:CpuVendor -eq 'Intel') }
    if (-not $script:CpuHybrid) { $chkCpuIntelHybrid.IsEnabled = $false }
    $chkCpuAmdParking.IsEnabled = ($script:CpuVendor -eq 'AMD') -and -not $script:CpuDualX3D
    foreach ($cb in @($chkCpuIntelBoostPol, $chkCpuIntelHybrid, $chkCpuAmdParking)) {
        [System.Windows.Controls.ToolTipService]::SetShowOnDisabled($cb, $true)
        if (-not $cb.IsEnabled) { $cb.IsChecked = $false }
    }
}

# Impostazioni del piano energetico attivo, solo con l'alimentazione collegata:
# a batteria il portatile resta com'era. Il valore di prima si salva in
# HKCU\Software\TweakAndrew\PowerBackup e «Reimposta» lo rimette.
$script:PowerBackupKey = 'HKCU:\Software\TweakAndrew\PowerBackup'

function Set-PowerAc([string]$Sub, [string]$Set, [uint32]$Value, [string]$Label) {
    $scheme = Get-ActiveSchemeGuid
    if ($null -eq $scheme) { Write-Log "[SALTATO] $Label - piano energetico non leggibile."; return }
    $s = [guid]$Sub; $g = [guid]$Set; $old = [uint32]0
    if ([TweakAndrew.PowerApi]::PowerReadACValueIndex([IntPtr]::Zero, [ref]$scheme, [ref]$s, [ref]$g, [ref]$old) -ne 0) {
        Write-Log "[SALTATO] $Label - impostazione non presente su questo computer."; return
    }
    try {
        if (-not (Test-Path -LiteralPath $script:PowerBackupKey)) { New-Item -Path $script:PowerBackupKey -Force | Out-Null }
        $prev = Get-ItemProperty -LiteralPath $script:PowerBackupKey -Name $Set -ErrorAction SilentlyContinue
        if ($null -eq $prev) { New-ItemProperty -LiteralPath $script:PowerBackupKey -Name $Set -Value "$Sub|$old" -PropertyType String -Force | Out-Null }
    } catch {}
    $r = [TweakAndrew.PowerApi]::PowerWriteACValueIndex([IntPtr]::Zero, [ref]$scheme, [ref]$s, [ref]$g, $Value)
    [TweakAndrew.PowerApi]::PowerSetActiveScheme([IntPtr]::Zero, [ref]$scheme) | Out-Null
    if ($r -eq 0) { Write-Log "[OK] $Label - $old -> $Value (con alimentazione collegata)." }
    else { Write-Log "[ERRORE] $Label - powrprof ha restituito $r." }
}

function Reset-PowerAc([string]$Set, [string]$Label) {
    $prev = [string](Get-ItemProperty -LiteralPath $script:PowerBackupKey -Name $Set -ErrorAction SilentlyContinue).$Set
    if (-not $prev) { Write-Log "[SALTATO] $Label - nessun valore salvato da ripristinare."; return }
    $p = $prev -split '\|'
    $scheme = Get-ActiveSchemeGuid
    $s = [guid]$p[0]; $g = [guid]$Set
    $r = [TweakAndrew.PowerApi]::PowerWriteACValueIndex([IntPtr]::Zero, [ref]$scheme, [ref]$s, [ref]$g, [uint32]$p[1])
    [TweakAndrew.PowerApi]::PowerSetActiveScheme([IntPtr]::Zero, [ref]$scheme) | Out-Null
    if ($r -eq 0) {
        Remove-ItemProperty -LiteralPath $script:PowerBackupKey -Name $Set -ErrorAction SilentlyContinue
        Write-Log "[OK] $Label - tornato a $($p[1])."
    } else { Write-Log "[ERRORE] $Label - powrprof ha restituito $r." }
}

# Un bit di FeatureTestControl nelle chiavi della scheda Intel: gli altri bit restano com'erano.
function Set-IntelFeatureBit([uint32]$Mask, [bool]$On, [string]$Label) {
    $n = 0
    foreach ($k in @(Get-GpuClassKeys 'Intel')) {
        try {
            $cur = [uint32]0
            $v = (Get-ItemProperty -LiteralPath $k.PSPath -Name FeatureTestControl -ErrorAction SilentlyContinue).FeatureTestControl
            if ($null -ne $v) { $cur = [uint32]([int64]$v -band 0xFFFFFFFFL) }
            $new = if ($On) { $cur -bor $Mask } else { $cur -band (-bnot $Mask -band 0xFFFFFFFFL) }
            $dw = [BitConverter]::ToInt32([BitConverter]::GetBytes([uint32]$new), 0)
            New-ItemProperty -LiteralPath $k.PSPath -Name FeatureTestControl -Value $dw -PropertyType DWord -Force -ErrorAction Stop | Out-Null
            $n++
        } catch {}
    }
    if ($n -gt 0) { Write-Log "[OK] $Label - schede aggiornate: $n." } else { Write-Log "[SALTATO] $Label - nessuna scheda Intel." }
}

$btnDetectGpu.Add_Click({ Show-GpuInfo; Write-Log "[INFO] Scheda video: $($script:GpuVendor)." })

# La scheda dichiara che le voci del produttore sbagliato vengono ignorate:
# senza questo controllo scriveva comunque le chiavi.
function Test-Gpu {
    param([string]$Vendor, [string]$Label)
    if ($script:GpuVendors -contains $Vendor) { return $true }
    Write-Log "[SALTATO] $Label - nessuna scheda $Vendor rilevata."
    return $false
}

# Disattiva un elenco di attivita' pianificate, saltando quelle non presenti.
# Le attivita' nella radice hanno percorso "\": Split-Path restituisce gia' la
# barra, quindi aggiungerne un'altra dava "\\" e non trovava mai nulla.
function Disable-Tasks {
    param([string[]]$Paths, [string]$Label)
    $n = 0
    foreach ($t in $Paths) {
        try {
            $folder = Split-Path $t -Parent
            if ([string]::IsNullOrEmpty($folder)) { $folder = '\' }
            if (-not $folder.EndsWith('\')) { $folder = "$folder\" }
            $name = Split-Path $t -Leaf
            Disable-ScheduledTask -TaskPath $folder -TaskName $name -ErrorAction Stop | Out-Null
            $n++
        } catch {}
    }
    if ($n -gt 0) { Write-Log "[OK] $Label - attivita' disattivate: $n." }
    else          { Write-Log "[SALTATO] $Label - nessuna attivita' presente." }
}


# ------------------------------------------------------------------------------
# 19b. CACHE SHADER
# ------------------------------------------------------------------------------
# Ogni driver tiene gli shader compilati in cartelle sue. Sono dati rigenerabili:
# cancellarli non tocca i giochi, costa solo una ricompilazione al primo avvio.
function Get-ShaderCachePaths {
    $l = $env:LOCALAPPDATA
    $paths = @(
        "$l\NVIDIA\DXCache",
        "$l\NVIDIA\GLCache",
        "$l\NVIDIA Corporation\NV_Cache",
        "$env:ProgramData\NVIDIA Corporation\NV_Cache",
        "$l\AMD\DxCache",
        "$l\AMD\DxcCache",
        "$l\AMD\GLCache",
        "$l\AMD\VkCache",
        "$l\Intel\ShaderCache",
        "$l\D3DSCache"
    )
    return @($paths | Where-Object { Test-Path -LiteralPath $_ })
}

function Measure-Folder {
    param([string]$Path)
    try {
        $sum = (Get-ChildItem -LiteralPath $Path -Recurse -Force -File -ErrorAction SilentlyContinue |
                Measure-Object -Property Length -Sum).Sum
        if ($null -eq $sum) { return 0 }
        return [long]$sum
    } catch { return 0 }
}

function Format-Size {
    param([long]$Bytes)
    if ($Bytes -ge 1GB) { return ("{0:N1} GB" -f ($Bytes / 1GB)) }
    return ("{0:N0} MB" -f ($Bytes / 1MB))
}

function Show-ShaderCache {
    if ($null -eq $txtShaderSize) { return }
    $paths = Get-ShaderCachePaths
    if ($paths.Count -eq 0) {
        $txtShaderSize.Text = T 'shaderNone'
        return
    }
    $txtShaderSize.Text = T 'shaderScanning'
    [System.Windows.Threading.Dispatcher]::CurrentDispatcher.Invoke([Action]{}, [System.Windows.Threading.DispatcherPriority]::Background)

    $totale = 0
    $righe = foreach ($p in $paths) {
        $b = Measure-Folder $p
        $totale += $b
        "  {0,-14}{1,9}" -f (Split-Path $p -Leaf), (Format-Size $b)
    }
    $txtShaderSize.Text = ($righe -join "`n") + "`n  " + ("-" * 23) + "`n" +
                          ("  {0,-14}{1,9}" -f (T 'shaderTotal'), (Format-Size $totale))
}

$btnShaderScan.Add_Click({ Show-ShaderCache })

$btnShaderClear.Add_Click({
    if (-not (Show-Dialog (T 'confirmTitle') (T 'shaderAsk') 'warn')) { return }

    $liberati = 0
    foreach ($p in (Get-ShaderCachePaths)) {
        $prima = Measure-Folder $p
        # Si svuota la cartella, non la si elimina: il driver la ricrea comunque,
        # ma se manca qualche gioco puo' lamentarsi al primo avvio.
        Get-ChildItem -LiteralPath $p -Force -ErrorAction SilentlyContinue |
            Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
        $dopo = Measure-Folder $p
        $liberati += ($prima - $dopo)
        Write-Log ("[OK] {0} - liberati {1:N0} MB." -f (Split-Path $p -Leaf), (($prima - $dopo) / 1MB))
    }
    Write-Log ("[OK] Cache shader svuotata: {0:N0} MB liberati in totale." -f ($liberati / 1MB))
    Show-ShaderCache
})

# ------------------------------------------------------------------------------
# 19c. FUNZIONI NASCOSTE DI WINDOWS
# ------------------------------------------------------------------------------
# Stesso meccanismo di ViVeTool: si scrive un override sotto FeatureManagement.
# EnabledState 2 = funzione attiva, 1 = disattiva. Togliere la chiave rimette il
# comportamento predefinito della build.
$script:FeatureRoot = 'HKLM:\SYSTEM\CurrentControlSet\Control\FeatureManagement\Overrides\4'

function Set-WindowsFeature {
    param([string]$Id, [ValidateSet('on','off','reset')][string]$State)
    $path = "$script:FeatureRoot\$Id"
    try {
        if ($State -eq 'reset') {
            if (Test-Path -LiteralPath $path) {
                Remove-Item -LiteralPath $path -Recurse -Force -ErrorAction Stop
                Write-Log "[OK] Funzione $Id riportata al predefinito."
            } else {
                Write-Log "[SALTATO] Funzione $Id - nessuna modifica da togliere."
            }
            return
        }
        $enabled = if ($State -eq 'on') { 2 } else { 1 }
        if (-not (Test-Path -LiteralPath $path)) { New-Item -Path $path -Force -ErrorAction Stop | Out-Null }
        foreach ($v in @(
            @{ N = 'EnabledState';        V = $enabled },
            @{ N = 'EnabledStateOptions'; V = 0 },
            @{ N = 'Variant';             V = 0 },
            @{ N = 'VariantPayload';      V = 0 },
            @{ N = 'VariantPayloadKind';  V = 0 })) {
            New-ItemProperty -LiteralPath $path -Name $v.N -Value $v.V -PropertyType DWord -Force -ErrorAction Stop | Out-Null
        }
        $parola = if ($State -eq 'on') { T 'featStateOn' } else { T 'featStateOff' }
        Write-Log "[OK] Funzione $Id $parola (serve un riavvio)."
    } catch {
        Write-Log "[ERRORE] Funzione $Id - $($_.Exception.Message)"
    }
}

function Show-FeatureOverrides {
    if ($null -eq $txtFeatList) { return }
    $righe = @()
    try {
        foreach ($k in (Get-ChildItem -LiteralPath $script:FeatureRoot -ErrorAction SilentlyContinue)) {
            $stato = Get-RegOrNull $k.PSPath 'EnabledState'
            $parola = switch ($stato) {
                2 { T 'featStateOn' }
                1 { T 'featStateOff' }
                default { "?" }
            }
            $righe += "  $($k.PSChildName)  $parola"
        }
    } catch {}
    if ($righe.Count -eq 0) { $txtFeatList.Text = T 'featEmpty' }
    else { $txtFeatList.Text = ($righe -join "`n") }
}

$btnFeatApply.Add_Click({
    $id = ([string]$txtFeatId.Text).Trim()
    if ($id -notmatch '^\d+$') {
        Write-Log "[AVVISO] $(T 'featNeedId')"
        return
    }
    $stato = 'on'
    switch ($cmbFeatState.SelectedIndex) {
        0 { $stato = 'on' }
        1 { $stato = 'off' }
        2 { $stato = 'reset' }
    }
    Set-WindowsFeature $id $stato
    Show-FeatureOverrides
})

$btnFeatList.Add_Click({ Show-FeatureOverrides })

# Scorre le sottochiavi della classe display: i valori della GPU stanno li'.
# Sottochiavi della classe display, filtrate per produttore: senza filtro un
# valore NVIDIA finiva anche sulla grafica integrata Intel dello stesso PC.
function Get-GpuClassKeys {
    param([string]$Vendor = '')
    $pattern = switch ($Vendor) { 'NVIDIA' { 'NVIDIA' } 'AMD' { 'AMD|Advanced Micro|ATI |Radeon' } 'Intel' { 'Intel' } default { '.' } }
    $base = 'HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4d36e968-e325-11ce-bfc1-08002be10318}'
    Get-ChildItem $base -ErrorAction SilentlyContinue |
        Where-Object { $_.PSChildName -match '^\d{4}$' } |
        Where-Object {
            $p = Get-ItemProperty -LiteralPath $_.PSPath -ErrorAction SilentlyContinue
            ("$($p.ProviderName) $($p.DriverDesc)") -match $pattern
        }
}

function Set-GpuClassValue {
    param([string]$Name, $Value, [string]$Label, [string]$Vendor = '')
    $n = 0
    foreach ($k in @(Get-GpuClassKeys $Vendor)) {
        try { New-ItemProperty -LiteralPath $k.PSPath -Name $Name -Value $Value -PropertyType DWord -Force -ErrorAction Stop | Out-Null; $n++ } catch {}
    }
    if ($n -gt 0) { Write-Log "[OK] $Label - schede aggiornate: $n." }
    else { Write-Log "[SALTATO] $Label - nessuna scheda corrispondente." }
}

# ------------------------------------------------------------------------------
# 22. AVVIO DEL SISTEMA — ritorno ai valori predefiniti
# ------------------------------------------------------------------------------
# deletevalue toglie la voce dalla configurazione: Windows torna al suo
# comportamento di fabbrica, che non e' lo stesso di scriverci il valore
# opposto. Le voci mai impostate rispondono con un errore, ed e' normale.
$btnBootReset.Add_Click({
    if (-not (Show-Dialog (T 'confirmTitle') (T 'bootResetAsk') 'warn')) { return }
    foreach ($arg in @(
        '/deletevalue {current} quietboot',
        '/deletevalue {current} bootlog',
        '/deletevalue {current} bootmenupolicy',
        '/deletevalue disabledynamictick',
        '/deletevalue tscsyncpolicy')) {
        Start-Process -FilePath "$env:SystemRoot\System32\bcdedit.exe" -ArgumentList $arg `
                      -Wait -WindowStyle Hidden -ErrorAction SilentlyContinue | Out-Null
    }
    Start-Process -FilePath "$env:SystemRoot\System32\bcdedit.exe" -ArgumentList '/timeout 30' `
                  -Wait -WindowStyle Hidden -ErrorAction SilentlyContinue | Out-Null
    Write-Log "[OK] $(T 'bootResetDone')"
})

# ------------------------------------------------------------------------------
# 19d. PROFILO GLOBALE DEL DRIVER NVIDIA (DRS)
# ------------------------------------------------------------------------------
# Le stesse impostazioni del Pannello di controllo NVIDIA e di Profile Inspector,
# scritte con l'API ufficiale del driver (nvapi64.dll): nessun programma esterno.
Add-Type -TypeDefinition @'
using System;
using System.Runtime.InteropServices;
namespace TweakAndrew {
public static class NvDrs {
    [DllImport("nvapi64.dll", EntryPoint = "nvapi_QueryInterface", CallingConvention = CallingConvention.Cdecl)]
    static extern IntPtr QueryInterface(uint id);
    [UnmanagedFunctionPointer(CallingConvention.Cdecl)] delegate int NoArg();
    [UnmanagedFunctionPointer(CallingConvention.Cdecl)] delegate int OutPtr(out IntPtr h);
    [UnmanagedFunctionPointer(CallingConvention.Cdecl)] delegate int OnePtr(IntPtr h);
    [UnmanagedFunctionPointer(CallingConvention.Cdecl)] delegate int PtrOutPtr(IntPtr h, out IntPtr p);
    [UnmanagedFunctionPointer(CallingConvention.Cdecl)] delegate int SetFn(IntPtr h, IntPtr p, IntPtr s);
    [UnmanagedFunctionPointer(CallingConvention.Cdecl)] delegate int GetFn(IntPtr h, IntPtr p, uint id, IntPtr s);
    [UnmanagedFunctionPointer(CallingConvention.Cdecl)] delegate int IdFn(IntPtr h, IntPtr p, uint id);

    const int Size = 0x3020;
    static T Fn<T>(uint id) where T : class {
        IntPtr p = QueryInterface(id);
        if (p == IntPtr.Zero) throw new Exception("funzione NVAPI assente 0x" + id.ToString("X8"));
        return Marshal.GetDelegateForFunctionPointer(p, typeof(T)) as T;
    }
    static void Check(int r, string what) { if (r != 0) throw new Exception(what + ": codice NVAPI " + r); }

    static IntPtr Open(out IntPtr profile) {
        Check(Fn<NoArg>(0x0150E828)(), "Initialize");
        IntPtr h;
        Check(Fn<OutPtr>(0x0694D52E)(out h), "CreateSession");
        Check(Fn<OnePtr>(0x375DBD6B)(h), "LoadSettings");
        Check(Fn<PtrOutPtr>(0xDA8466A0)(h, out profile), "GetBaseProfile");
        return h;
    }
    static void Close(IntPtr h, bool save) {
        try { if (save) Check(Fn<OnePtr>(0xFCBC7E14)(h), "SaveSettings"); }
        finally { Fn<OnePtr>(0xDAD9CFF8)(h); }
    }
    public static bool Available() {
        try { return QueryInterface(0x0150E828) != IntPtr.Zero && Fn<NoArg>(0x0150E828)() == 0; } catch { return false; }
    }
    // Valore attuale nel profilo globale, oppure -1 se resta quello del driver.
    public static long Get(uint id) {
        IntPtr profile; IntPtr h = Open(out profile);
        IntPtr buf = Marshal.AllocHGlobal(Size);
        try {
            for (int i = 0; i < Size; i++) Marshal.WriteByte(buf, i, 0);
            Marshal.WriteInt32(buf, 0, Size | (1 << 16));
            int r = Fn<GetFn>(0x73BF8338)(h, profile, id, buf);
            if (r != 0) return -1;
            return (uint)Marshal.ReadInt32(buf, 8220);
        } finally { Marshal.FreeHGlobal(buf); Close(h, false); }
    }
    public static void Set(uint id, uint value) {
        IntPtr profile; IntPtr h = Open(out profile);
        IntPtr buf = Marshal.AllocHGlobal(Size);
        bool ok = false;
        try {
            for (int i = 0; i < Size; i++) Marshal.WriteByte(buf, i, 0);
            Marshal.WriteInt32(buf, 0, Size | (1 << 16));
            Marshal.WriteInt32(buf, 4100, (int)id);
            Marshal.WriteInt32(buf, 4104, 0);
            Marshal.WriteInt32(buf, 8220, (int)value);
            Check(Fn<SetFn>(0x577DD202)(h, profile, buf), "SetSetting");
            ok = true;
        } finally { Marshal.FreeHGlobal(buf); Close(h, ok); }
    }
    // Riporta l'impostazione al valore del driver.
    public static void Restore(uint id) {
        IntPtr profile; IntPtr h = Open(out profile);
        bool ok = false;
        try {
            int r = Fn<IdFn>(0x53F0381E)(h, profile, id);
            if (r != 0) r = Fn<IdFn>(0xE4A26362)(h, profile, id);
            ok = true;
        } finally { Close(h, ok); }
    }
}
}
'@ -ErrorAction SilentlyContinue

# Impostazioni del profilo usate dalle caselle della pagina Scheda video.
$script:NvProfileSets = @{
    P2         = @(,@(0x50166C5E, 0))
    Power      = @(,@(0x1057EB71, 1))
    # Bassa latenza «Attiva» del pannello NVIDIA: un fotogramma pronto in anticipo,
    # senza la pianificazione Ultra, che con alcuni giochi e con G-SYNC da' problemi.
    LowLatency = @(@(0x0005F543, 1), @(0x10835000, 0), @(0x007BA09E, 1))
    Threaded   = @(,@(0x20C1221E, 1))
    TexPerf    = @(,@(0x00CE2691, 20))
    Aniso      = @(,@(0x00E73211, 1))
    Shader     = @(,@(0x00AC8497, 4294967295))
    NoAnsel    = @(,@(0x1075543B, 0))
}

function Set-NvProfile([string]$set, [string]$label) {
    if (-not [TweakAndrew.NvDrs]::Available()) { Write-Log "[SALTATO] $label - driver NVIDIA non disponibile."; return }
    foreach ($pair in $script:NvProfileSets[$set]) {
        try {
            [TweakAndrew.NvDrs]::Set([uint32]$pair[0], [uint32]$pair[1])
            Write-Log ("[OK] $label - 0x{0:X8} = {1}" -f $pair[0], $pair[1])
        } catch { Write-Log "[ERRORE] $label - $($_.Exception.Message)" }
    }
}

function Reset-NvProfile([string]$set, [string]$label) {
    if (-not [TweakAndrew.NvDrs]::Available()) { Write-Log "[SALTATO] $label - driver NVIDIA non disponibile."; return }
    foreach ($pair in $script:NvProfileSets[$set]) {
        try { [TweakAndrew.NvDrs]::Restore([uint32]$pair[0]); Write-Log ("[OK] $label - 0x{0:X8} predefinito" -f $pair[0]) }
        catch { Write-Log "[ERRORE] $label - $($_.Exception.Message)" }
    }
}

# Valori nella sottochiave UMD delle schede AMD: stringhe di cifre in UTF-16.
function Set-AmdUmdValue([string]$Name, [string]$Digits, [string]$Label) {
    $n = 0
    foreach ($k in @(Get-GpuClassKeys 'AMD')) {
        try {
            $umd = Join-Path $k.PSPath 'UMD'
            if (-not (Test-Path -LiteralPath $umd)) { New-Item -Path $umd -Force | Out-Null }
            $bytes = [System.Text.Encoding]::Unicode.GetBytes($Digits)
            New-ItemProperty -LiteralPath $umd -Name $Name -Value ([byte[]]$bytes) -PropertyType Binary -Force | Out-Null
            $n++
        } catch {}
    }
    if ($n -gt 0) { Write-Log "[OK] $Label - schede aggiornate: $n." } else { Write-Log "[SALTATO] $Label - nessuna scheda AMD." }
}

function Remove-AmdUmdValue([string]$Name, [string]$Label) {
    foreach ($k in @(Get-GpuClassKeys 'AMD')) {
        Remove-ItemProperty -LiteralPath (Join-Path $k.PSPath 'UMD') -Name $Name -ErrorAction SilentlyContinue
    }
    Write-Log "[OK] $Label - valore del driver ripristinato."
}

# Pacchetto latenza del driver NVIDIA: valori noti nelle guide di ottimizzazione.
$script:NvLatencyValues = [ordered]@{
    D3PCLatency = 1; F1TransitionLatency = 1; LOWLATENCY = 1; Node3DLowLatency = 1
    PciLatencyTimerControl = 0x20; RMDeepL1EntryLatencyUsec = 1; RmGspcMaxFtuS = 1; RmGspcMinFtuS = 1
    RmGspcPerioduS = 1; RMLpwrEiIdleThresholdUs = 1; RMLpwrGrIdleThresholdUs = 1; RMLpwrGrRgIdleThresholdUs = 1
    RMLpwrMsIdleThresholdUs = 1; VRDirectFlipDPCDelayUs = 1; VRDirectFlipTimingMarginUs = 1
    VRDirectJITFlipMsHybridFlipDelayUs = 1; vrrCursorMarginUs = 1; vrrDeflickerMarginUs = 1; vrrDeflickerMaxUs = 1
}
