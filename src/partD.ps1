
# ------------------------------------------------------------------------------
# 13. ESECUZIONE — elenco di azioni costruito dalle sole voci selezionate
# ------------------------------------------------------------------------------
# Ogni voce spuntata aggiunge un'azione alla coda. Niente viene applicato senza
# una spunta: la versione precedente toccava sempre MPO, TCP e DNS anche quando
# l'utente aveva scelto tutt'altro.
$script:Actions = @()

function Add-Action {
    param([string]$Name,[scriptblock]$Do)
    $script:Actions += ,@{ Name = $Name; Do = $Do }
}

function Add-IfChecked {
    param($Box,[scriptblock]$Do)
    if ($null -ne $Box -and $Box.IsChecked -eq $true) { Add-Action ([string]$Box.Content) $Do }
}

# Modifica la configurazione di avvio. bcdedit non ha un equivalente in
# PowerShell: si lancia e si controlla il codice di uscita.
function Set-Bcd {
    param([Parameter(Mandatory)][string]$Arguments,[string]$Label)
    if ([string]::IsNullOrWhiteSpace($Label)) { $Label = $Arguments }
    try {
        $p = Start-Process -FilePath "$env:SystemRoot\System32\bcdedit.exe" -ArgumentList $Arguments `
                           -Wait -PassThru -WindowStyle Hidden -ErrorAction Stop
        if ($p.ExitCode -eq 0) { Write-Log "[OK] $Label"; return $true }
        Write-Log "[ERRORE] $Label - bcdedit ha risposto $($p.ExitCode)."
        return $false
    } catch {
        Write-Log "[ERRORE] $Label - $($_.Exception.Message)"
        return $false
    }
}

# Disattiva un elenco di attivita' pianificate. Le attivita' assenti non sono
# un errore: cambiano da una versione di Windows all'altra.
# Attenzione al percorso radice: Split-Path di '\Nome' restituisce gia' '\',
# e aggiungere un secondo separatore faceva fallire ogni ricerca.
function Disable-Tasks {
    param([Parameter(Mandatory)][string[]]$Tasks,[string]$Label)
    $done = 0; $absent = 0
    foreach ($t in $Tasks) {
        $path = Split-Path $t -Parent
        if ([string]::IsNullOrEmpty($path)) { $path = '\' }
        if (-not $path.EndsWith('\')) { $path += '\' }
        $name = Split-Path $t -Leaf
        try {
            $st = Get-ScheduledTask -TaskPath $path -TaskName $name -ErrorAction Stop
            if ($st.State -ne 'Disabled') {
                Disable-ScheduledTask -TaskPath $path -TaskName $name -ErrorAction Stop | Out-Null
            }
            $done++
        } catch { $absent++ }
    }
    if ($done -gt 0) { Write-Log "[OK] $Label - $done attivita' disattivate su $($Tasks.Count)." }
    else { Write-Log "[SALTATO] $Label - nessuna attivita' presente." }
}

# Rimuove app preinstallate per l'utente corrente. Con $AlsoProvisioned toglie
# anche la copia di sistema, quella che Windows reinstalla ai nuovi profili.
function Remove-AppxList {
    param([Parameter(Mandatory)][string[]]$Names,[bool]$AlsoProvisioned = $false,[string]$Label = 'App')
    $removed = 0
    $provisioned = $null
    if ($AlsoProvisioned) {
        try { $provisioned = @(Get-AppxProvisionedPackage -Online -ErrorAction Stop) } catch { $provisioned = @() }
    }
    foreach ($n in $Names) {
        try {
            foreach ($pkg in @(Get-AppxPackage -Name $n -ErrorAction SilentlyContinue)) {
                Remove-AppxPackage -Package $pkg.PackageFullName -ErrorAction Stop
                Write-Log "[OK] Rimossa: $($pkg.Name)"
                $removed++
            }
        } catch { Write-Log "[AVVISO] $n - $($_.Exception.Message)" }
        if ($AlsoProvisioned) {
            foreach ($pp in @($provisioned | Where-Object { $_.DisplayName -eq $n })) {
                try {
                    Remove-AppxProvisionedPackage -Online -PackageName $pp.PackageName -ErrorAction Stop | Out-Null
                    Write-Log "[OK] Non tornera' per i nuovi utenti: $($pp.DisplayName)"
                } catch {}
            }
        }
    }
    if ($removed -eq 0) { Write-Log "[SALTATO] $Label - nessuna app da rimuovere." }
    else { Write-Log "[OK] $Label - $removed app rimosse." }
}

# Svuota una cartella e ne vieta la scrittura a tutti: il programma che la usa
# per installarsi non riesce piu' a copiarci nulla.
function Lock-Folder([string]$Path, [string]$Label) {
    try {
        if (Test-Path -LiteralPath $Path) { Remove-Item -Path (Join-Path $Path '*') -Recurse -Force -ErrorAction SilentlyContinue }
        else { New-Item -ItemType Directory -Path $Path -Force | Out-Null }
        & icacls.exe $Path /deny '*S-1-1-0:(W)' | Out-Null
        if ($LASTEXITCODE -eq 0) { Write-Log "[OK] $Label - scrittura bloccata." } else { Write-Log "[ERRORE] $Label - icacls $LASTEXITCODE." }
    } catch { Write-Log "[ERRORE] $Label - $($_.Exception.Message)" }
}

function Unlock-Folder([string]$Path, [string]$Label) {
    if (-not (Test-Path -LiteralPath $Path)) { Write-Log "[SALTATO] $Label - cartella assente."; return }
    & icacls.exe $Path /remove:d '*S-1-1-0' | Out-Null
    if ($LASTEXITCODE -eq 0) { Write-Log "[OK] $Label - scrittura di nuovo permessa." } else { Write-Log "[ERRORE] $Label - icacls $LASTEXITCODE." }
}

function Build-Actions {
    $script:Actions = @()

    # ---------- Punto di ripristino: sempre per primo ----------
    Add-IfChecked $chkRestorePoint {
        try {
            Enable-ComputerRestore -Drive "C:\" -ErrorAction SilentlyContinue
            Checkpoint-Computer -Description "TweakAndrew_v6" -RestorePointType "MODIFY_SETTINGS" -ErrorAction Stop
            Write-Log "[OK] Punto di ripristino creato."
        } catch { Write-Log "[AVVISO] Punto di ripristino non creato: $($_.Exception.Message)" }
    }

    # ---------- PRESTAZIONI ----------
    Add-IfChecked $chkMMCSS {
        $p = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile"
        Set-Reg $p 'AlwaysOn' 1 'DWord' 'MMCSS / AlwaysOn'
        Set-Reg $p 'NoLazyMode' 1 'DWord' 'MMCSS / NoLazyMode'
        Set-Reg $p 'SystemResponsiveness' 10 'DWord' 'MMCSS / SystemResponsiveness'
        $g = "$p\Tasks\Games"
        Set-Reg $g 'Affinity' 0 'DWord' 'Games / Affinity'
        Set-Reg $g 'Background Only' 'False' 'String' 'Games / Background Only'
        Set-Reg $g 'Clock Rate' 10000 'DWord' 'Games / Clock Rate'
        Set-Reg $g 'GPU Priority' 8 'DWord' 'Games / GPU Priority'
        Set-Reg $g 'Latency Sensitive' 'True' 'String' 'Games / Latency Sensitive'
        Set-Reg $g 'Priority' 6 'DWord' 'Games / Priority'
        Set-Reg $g 'Scheduling Category' 'High' 'String' 'Games / Scheduling Category'
        Set-Reg $g 'SFIO Priority' 'High' 'String' 'Games / SFIO Priority'
    }

    Add-IfChecked $chkPriority {
        Set-Reg 'HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl' 'Win32PrioritySeparation' 38 'DWord' 'Win32PrioritySeparation (0x26)'
    }

    Add-IfChecked $chkKernelMem {
        $m = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management"
        Set-Reg $m 'DisablePagingExecutive' 1 'DWord' 'DisablePagingExecutive'
        Set-Reg $m 'LargeSystemCache' 1 'DWord' 'LargeSystemCache'
        Set-Reg $m 'SecondLevelDataCache' 0 'DWord' 'SecondLevelDataCache'
    }

    Add-IfChecked $chkKernelDpc {
        $k = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Kernel"
        Set-Reg $k 'DpcWatchdogProfileOffset' 0x2010 'DWord' 'DpcWatchdogProfileOffset'
        Set-Reg $k 'ThreadDpcEnable' 0 'DWord' 'ThreadDpcEnable'
        Set-Reg $k 'DebugPollInterval' 0x3E8 'DWord' 'DebugPollInterval'
    }

    Add-IfChecked $chkTimer {
        Set-Reg 'HKLM:\SYSTEM\CurrentControlSet\Control\Power' 'TimerInterval' 0 'DWord' 'Timer coalescing (Power)'
        Set-Reg 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager' 'TimerInterval' 0 'DWord' 'Timer coalescing (Session Manager)'
    }

    Add-IfChecked $chkPowerThrottling {
        Set-Reg 'HKLM:\SYSTEM\CurrentControlSet\Control\Power\PowerThrottling' 'PowerThrottlingOff' 1 'DWord' 'Power Throttling'
    }

    Add-IfChecked $chkUSBSuspend {
        Set-Reg 'HKLM:\SYSTEM\CurrentControlSet\Services\USB' 'DisableSelectiveSuspend' 1 'DWord' 'USB Selective Suspend'
    }

    Add-IfChecked $chkNtfsPerf {
        try {
            fsutil behavior set disablelastaccess 1 | Out-Null
            fsutil behavior set memoryusage 2 | Out-Null
            Write-Log "[OK] NTFS: ultimo accesso disattivato, cache impostata su 2."
        } catch { Write-Log "[ERRORE] NTFS: $($_.Exception.Message)" }
    }

    Add-IfChecked $chkRamTweak {
        $selectedRam = [string]$cmbRamAmount.Text
        $svcValue = switch -Regex ($selectedRam) {
            '^2 '   { 131072;  break }
            '^4 '   { 262144;  break }
            '^8 '   { 524288;  break }
            '^16 '  { 1000000; break }
            '^32 '  { 2000000; break }
            '^64 '  { 4000000; break }
            '^128 ' { 8000000; break }
            default { 2000000 }
        }
        Set-Reg 'HKLM:\SYSTEM\CurrentControlSet\Control' 'SvcHostSplitThresholdInKB' $svcValue 'DWord' "SvcHostSplitThresholdInKB ($selectedRam)"
    }

    # ---------- GRAFICA E GIOCHI ----------
    Add-IfChecked $chkGameMode {
        Set-Reg 'HKCU:\Software\Microsoft\GameBar' 'AllowAutoGameMode' 1 'DWord' 'Game Mode / AllowAutoGameMode'
        Set-Reg 'HKCU:\Software\Microsoft\GameBar' 'AutoGameModeEnabled' 1 'DWord' 'Game Mode / AutoGameModeEnabled'
    }

    Add-IfChecked $chkFSO {
        $g = "HKCU:\System\GameConfigStore"
        Set-Reg $g 'GameDVR_FSEBehaviorMode' 2 'DWord' 'FSO / FSEBehaviorMode'
        Set-Reg $g 'GameDVR_HonorUserFSEBehaviorMode' 1 'DWord' 'FSO / HonorUserFSEBehaviorMode'
        Set-Reg $g 'GameDVR_DXGIHonorFSEMode' 1 'DWord' 'FSO / DXGIHonorFSEMode'
    }

    Add-IfChecked $chkGameDVR {
        Set-Reg 'HKCU:\System\GameConfigStore' 'GameDVR_Enabled' 0 'DWord' 'Game DVR / GameConfigStore'
        Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\GameDVR' 'AllowGameDVR' 0 'DWord' 'Game DVR / criterio'
        Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR' 'AppCaptureEnabled' 0 'DWord' 'Game DVR / AppCapture'
    }

    Add-IfChecked $chkHAGS {
        Set-Reg 'HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers' 'HwSchMode' 2 'DWord' 'GPU scheduling accelerato (HAGS)'
    }

    Add-IfChecked $chkVisualFX {
        Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects' 'VisualFXSetting' 2 'DWord' 'Effetti visivi su prestazioni'
        Set-Reg 'HKCU:\Control Panel\Desktop' 'DragFullWindows' '0' 'String' 'Trascinamento finestre semplificato'
    }

    Add-IfChecked $chkApplyMPO {
        # Per posizione e non per testo: le voci cambiano con la lingua.
        $dwm = "HKLM:\SOFTWARE\Microsoft\Windows\DWM"
        switch ($cmbMPO.SelectedIndex) {
            1       { Set-Reg $dwm 'OverlayTestMode' 5 'DWord' 'MPO disattivato' }
            2       { Set-Reg $dwm 'OverlayTestMode' 2 'DWord' 'MPO compatibile (2 piani)' }
            default { Remove-Reg $dwm 'OverlayTestMode' 'MPO predefinito' }
        }
    }

    # ---------- AVANZATE RISCHIOSE ----------
    Add-IfChecked $chkVBS {
        Set-Reg 'HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard' 'EnableVirtualizationBasedSecurity' 0 'DWord' 'VBS'
        Set-Reg 'HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\HypervisorEnforcedCodeIntegrity' 'Enabled' 0 'DWord' 'Integrita della memoria'
    }

    Add-IfChecked $chkMitigations {
        try {
            Set-ProcessMitigation -System -Disable CFG,BottomUp,HighEntropy,SEHOP -ErrorAction Stop
            Write-Log "[OK] Mitigazioni di sistema disattivate."
        } catch { Write-Log "[AVVISO] Mitigazioni non modificate: $($_.Exception.Message)" }
    }

    # ---------- ALIMENTAZIONE ----------
    Add-IfChecked $chkFastStartup {
        Set-Reg 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power' 'HiberbootEnabled' 0 'DWord' 'Avvio rapido'
    }
    Add-IfChecked $chkHibernation {
        powercfg /h off | Out-Null
        Write-Log "[OK] Ibernazione disattivata."
    }
    # Criterio «Consenti la connettività di rete durante lo standby connesso»:
    # 0 = niente rete mentre il PC dorme, niente download e risvegli in borsa.
    Add-IfChecked $chkS0Sleep {
        $p = 'HKLM:\SOFTWARE\Policies\Microsoft\Power\PowerSettings\f15576e8-98b7-4186-b944-eafa664402d9'
        Set-Reg $p 'ACSettingIndex' 0 'DWord' 'Rete in standby (alimentazione)'
        Set-Reg $p 'DCSettingIndex' 0 'DWord' 'Rete in standby (batteria)'
    }
    Add-IfChecked $chkS3Sleep {
        Set-Reg 'HKLM:\SYSTEM\CurrentControlSet\Control\Power' 'PlatformAoAcOverride' 0 'DWord' 'Sospensione S3'
    }
    # Dischi, SSD SATA e NVMe senza stati di risparmio, solo con l'alimentazione collegata.
    Add-IfChecked $chkDiskNoSleep {
        $d = '0012ee47-9041-4b5d-9b77-535fba8b1442'
        Set-PowerAc $d '6738e2c4-e8a5-4a42-b16a-e040e769756e' 0 'Spegni i dischi: mai'
        Set-PowerAc $d '0b2d69d7-a2a1-449c-9680-f91c70521c60' 0 'Collegamento SATA sempre attivo'
        Set-PowerAc $d 'd639518a-e56d-4345-8af2-b9f32fb26109' 0 'NVMe: nessun riposo'
        Set-PowerAc $d 'd3d55efd-c1ff-424e-9dc3-441be7833010' 0 'NVMe: nessun riposo profondo'
    }

    # ---------- PRIVACY ----------
    Add-IfChecked $chkTelemetry {
        Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection' 'AllowTelemetry' 0 'DWord' 'Telemetria'
        Set-Svc 'DiagTrack' 'Disabled' 'DiagTrack'
        Set-Svc 'dmwappushservice' 'Disabled' 'dmwappushservice'
    }

    Add-IfChecked $chkTelemetryTasks {
        $tasks = @(
            '\Microsoft\Windows\Application Experience\Microsoft Compatibility Appraiser',
            '\Microsoft\Windows\Application Experience\ProgramDataUpdater',
            '\Microsoft\Windows\Autochk\Proxy',
            '\Microsoft\Windows\Customer Experience Improvement Program\Consolidator',
            '\Microsoft\Windows\Customer Experience Improvement Program\UsbCeip',
            '\Microsoft\Windows\DiskDiagnostic\Microsoft-Windows-DiskDiagnosticDataCollector',
            '\Microsoft\Windows\Feedback\Siuf\DmClient',
            '\Microsoft\Windows\Feedback\Siuf\DmClientOnScenarioDownload'
        )
        $n = 0
        foreach ($t in $tasks) {
            try {
                $path = Split-Path $t -Parent
                $name = Split-Path $t -Leaf
                Disable-ScheduledTask -TaskPath "$path\" -TaskName $name -ErrorAction Stop | Out-Null
                $n++
            } catch {}
        }
        Write-Log "[OK] Attivita' pianificate di telemetria disattivate: $n."
    }

    Add-IfChecked $chkActivityHistory {
        $p = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\System'
        Set-Reg $p 'PublishUserActivities' 0 'DWord' 'Cronologia attività'
        Set-Reg $p 'EnableActivityFeed' 0 'DWord' 'Feed attivita'
        Set-Reg $p 'UploadUserActivities' 0 'DWord' 'Caricamento attivita'
    }

    Add-IfChecked $chkLocationTracking {
        Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\LocationAndSensors' 'DisableLocation' 1 'DWord' 'Posizione'
        Set-Svc 'lfsvc' 'Disabled' 'Servizio posizione (lfsvc)'
    }

    Add-IfChecked $chkAdvertisingID {
        Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo' 'Enabled' 0 'DWord' 'ID pubblicita'
        Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\AdvertisingInfo' 'DisabledByGroupPolicy' 1 'DWord' 'ID pubblicita (criterio)'
    }

    Add-IfChecked $chkTailoredExp {
        Set-Reg 'HKCU:\Software\Policies\Microsoft\Windows\CloudContent' 'DisableTailoredExperiencesWithDiagnosticData' 1 'DWord' 'Esperienze personalizzate'
        Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Privacy' 'TailoredExperiencesWithDiagnosticDataEnabled' 0 'DWord' 'Esperienze personalizzate (impostazione)'
    }

    Add-IfChecked $chkFeedback {
        Set-Reg 'HKCU:\Software\Microsoft\Siuf\Rules' 'NumberOfSIUFInPeriod' 0 'DWord' 'Frequenza feedback'
        Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection' 'DoNotShowFeedbackNotifications' 1 'DWord' 'Notifiche di feedback'
    }

    Add-IfChecked $chkErrorReporting {
        Set-Reg 'HKLM:\SOFTWARE\Microsoft\Windows\Windows Error Reporting' 'Disabled' 1 'DWord' 'Segnalazione errori'
        Set-Svc 'WerSvc' 'Disabled' 'Servizio segnalazione errori'
    }

    Add-IfChecked $chkInkingTyping {
        Set-Reg 'HKCU:\Software\Microsoft\Input\TIPC' 'Enabled' 0 'DWord' 'Raccolta dati digitazione'
        Set-Reg 'HKCU:\Software\Microsoft\Personalization\Settings' 'AcceptedPrivacyPolicy' 0 'DWord' 'Personalizzazione input'
        Set-Reg 'HKCU:\Software\Microsoft\InputPersonalization' 'RestrictImplicitInkCollection' 1 'DWord' 'Raccolta scrittura a mano'
        Set-Reg 'HKCU:\Software\Microsoft\InputPersonalization' 'RestrictImplicitTextCollection' 1 'DWord' 'Raccolta testo digitato'
        Set-Reg 'HKCU:\Software\Microsoft\InputPersonalization\TrainedDataStore' 'HarvestContacts' 0 'DWord' 'Raccolta contatti'
    }

    Add-IfChecked $chkWiFiSense {
        $b = 'HKLM:\SOFTWARE\Microsoft\PolicyManager\default\WiFi'
        Set-Reg "$b\AllowWiFiHotSpotReporting" 'Value' 0 'DWord' 'Wi-Fi Sense / hotspot reporting'
        Set-Reg "$b\AllowAutoConnectToWiFiSenseHotspots" 'Value' 0 'DWord' 'Wi-Fi Sense / connessione automatica'
    }

    Add-IfChecked $chkConsumerFeatures {
        Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent' 'DisableWindowsConsumerFeatures' 1 'DWord' 'App suggerite'
    }


    Add-IfChecked $chkSuggestedContent {
        $c = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'
        foreach ($v in @('SubscribedContent-338393Enabled','SubscribedContent-353694Enabled','SubscribedContent-353696Enabled','SystemPaneSuggestionsEnabled','SilentInstalledAppsEnabled','PreInstalledAppsEnabled','OemPreInstalledAppsEnabled')) {
            Set-Reg $c $v 0 'DWord' "Contenuti suggeriti / $v"
        }
    }

    Add-IfChecked $chkLockScreenAds {
        $c = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'
        Set-Reg $c 'RotatingLockScreenOverlayEnabled' 0 'DWord' 'Spotlight schermata di blocco'
        Set-Reg $c 'SubscribedContent-338387Enabled' 0 'DWord' 'Annunci schermata di blocco'
    }

    Add-IfChecked $chkStartBing {
        Set-Reg 'HKCU:\Software\Policies\Microsoft\Windows\Explorer' 'DisableSearchBoxSuggestions' 1 'DWord' 'Bing nel menu Start'
        Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Search' 'BingSearchEnabled' 0 'DWord' 'Ricerca Bing'
    }


    Add-IfChecked $chkStartTracking {
        $a = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'
        Set-Reg $a 'Start_TrackProgs' 0 'DWord' 'Tracciamento app'
        Set-Reg $a 'Start_TrackDocs' 0 'DWord' 'Tracciamento documenti'
    }

    Add-IfChecked $chkFolderDiscovery {
        Set-Reg 'HKCU:\Software\Classes\Local Settings\Software\Microsoft\Windows\Shell\Bags\AllFolders\Shell' 'FolderType' 'NotSpecified' 'String' 'Tipo cartella in Esplora file'
    }

    # ---------- APP MICROSOFT ----------
    Add-IfChecked $chkWindowsAI {
        Set-Reg 'HKCU:\Software\Policies\Microsoft\Windows\WindowsCopilot' 'TurnOffWindowsCopilot' 1 'DWord' 'Copilot (utente)'
        Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot' 'TurnOffWindowsCopilot' 1 'DWord' 'Copilot (sistema)'
        Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI' 'DisableAIDataAnalysis' 1 'DWord' 'Recall'
        Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI' 'AllowRecallEnablement' 0 'DWord' 'Recall disponibile'
        Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI' 'TurnOffSavingSnapshots' 1 'DWord' 'Istantanee di Recall'
        Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' 'ShowCopilotButton' 0 'DWord' 'Pulsante Copilot'
    }

    Add-IfChecked $chkEdgeDebloat {
        $e = 'HKLM:\SOFTWARE\Policies\Microsoft\Edge'
        Set-Reg $e 'PreloadStartPageEnabled' 0 'DWord' 'Edge / precaricamento'
        Set-Reg $e 'BackgroundModeEnabled' 0 'DWord' 'Edge / esecuzione in background'
        Set-Reg $e 'StartupBoostEnabled' 0 'DWord' 'Edge / avvio rapido'
        Set-Reg $e 'HubsSidebarEnabled' 0 'DWord' 'Edge / barra laterale'
        Set-Reg $e 'ShowRecommendationsEnabled' 0 'DWord' 'Edge / consigli'
    }

    Add-IfChecked $chkOneDriveRemove {
        Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\OneDrive' 'DisableFileSyncNGSC' 1 'DWord' 'OneDrive / sincronizzazione'
        Get-Process -Name "OneDrive" -ErrorAction SilentlyContinue | Stop-Process -Force -ErrorAction SilentlyContinue
        Write-Log "[OK] OneDrive disattivato."
    }

    Add-IfChecked $chkOutlookNew {
        Set-Reg 'HKCU:\Software\Microsoft\Office\16.0\Outlook\Options\General' 'HideNewOutlookToggle' 1 'DWord' 'Nuovo Outlook / interruttore'
        Set-Reg 'HKCU:\Software\Policies\Microsoft\office\16.0\outlook\preferences' 'NewOutlookMigrationUserSetting' 0 'DWord' 'Nuovo Outlook / migrazione'
    }

    # ---------- SERVIZI E COMPONENTI ----------
    Add-IfChecked $chkServicesManual {
        foreach ($s in @('MapsBroker','Fax','XblAuthManager','XblGameSave','XboxNetApiSvc','XboxGipSvc','RetailDemo','WalletService','PhoneSvc')) {
            Set-Svc $s 'Manual' $s
        }
    }
    Add-IfChecked $chkDeliveryOpt {
        Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DeliveryOptimization' 'DODownloadMode' 0 'DWord' 'Ottimizzazione recapito'
        Set-Svc 'DoSvc' 'Disabled' 'DoSvc'
    }
    Add-IfChecked $chkBitLocker { Set-Svc 'BDESVC' 'Manual' 'BitLocker (BDESVC)' }
    Add-IfChecked $chkWPBT {
        Set-Reg 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Executive' 'DisableWpbtExecution' 1 'DWord' 'WPBT'
    }
    Add-IfChecked $chkBackgroundApps {
        Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications' 'GlobalUserDisabled' 1 'DWord' 'App in background'
        Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppPrivacy' 'LetAppsRunInBackground' 2 'DWord' 'App in background (criterio)'
    }
    Add-IfChecked $chkTeredo {
        netsh interface teredo set state disabled | Out-Null
        Write-Log "[OK] Teredo disattivato."
    }
    Add-IfChecked $chkRDPWarnings {
        Set-Reg 'HKCU:\Software\Microsoft\Terminal Server Client' 'AuthenticationLevelOverride' 0 'DWord' 'Avvisi RDP'
    }
    Add-IfChecked $chkRemoteAssistance {
        Set-Reg 'HKLM:\SYSTEM\CurrentControlSet\Control\Remote Assistance' 'fAllowToGetHelp' 0 'DWord' 'Assistenza remota'
    }
    Add-IfChecked $chkCompanionApps {
        Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DeviceInstall\Settings' 'DisableDeviceCompanionApp' 1 'DWord' 'App companion'
        Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Device Metadata' 'PreventDeviceMetadataFromNetwork' 1 'DWord' 'Metadati dei dispositivi dalla rete'
    }
    Add-IfChecked $chkDriverUpdates {
        Set-Reg 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\DriverSearching' 'SearchOrderConfig' 0 'DWord' 'Driver da Windows Update'
        Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate' 'ExcludeWUDriversInQualityUpdate' 1 'DWord' 'Driver negli aggiornamenti qualitativi'
    }

    # ---------- INTERFACCIA ----------
    Add-IfChecked $chkDarkTheme {
        $t = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize'
        Set-Reg $t 'AppsUseLightTheme' 0 'DWord' 'Tema scuro app'
        Set-Reg $t 'SystemUsesLightTheme' 0 'DWord' 'Tema scuro sistema'
    }
    Add-IfChecked $chkFileExt   { Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' 'HideFileExt' 0 'DWord' 'Estensioni dei file' }
    Add-IfChecked $chkHiddenFiles { Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' 'Hidden' 1 'DWord' 'File nascosti' }
    Add-IfChecked $chkLongPaths { Set-Reg 'HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem' 'LongPathsEnabled' 1 'DWord' 'Percorsi lunghi' }
    Add-IfChecked $chkClassicMenu {
        $clsid = 'HKCU:\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}\InprocServer32'
        try {
            if (-not (Test-Path -LiteralPath $clsid)) { New-Item -Path $clsid -Force -ErrorAction Stop | Out-Null }
            Set-Item -LiteralPath $clsid -Value '' -Force -ErrorAction Stop
            Write-Log "[OK] Menu contestuale classico attivato (richiede riavvio di Esplora file)."
        } catch { Write-Log "[ERRORE] Menu contestuale classico: $($_.Exception.Message)" }
    }
    Add-IfChecked $chkExplorerThisPC { Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' 'LaunchTo' 1 'DWord' 'Esplora file su Questo PC' }
    Add-IfChecked $chkRemove3D {
        foreach ($p in @(
            'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\MyComputer\NameSpace\{0DB7E03F-FC29-4DC6-9020-FF41B59E513A}',
            'HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Explorer\MyComputer\NameSpace\{0DB7E03F-FC29-4DC6-9020-FF41B59E513A}')) {
            if (Test-Path -LiteralPath $p) { Remove-Item -LiteralPath $p -Recurse -Force -ErrorAction SilentlyContinue }
        }
        Write-Log "[OK] Voce «Oggetti 3D» rimossa."
    }
    Add-IfChecked $chkRecycleConfirm { Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer' 'ConfirmFileDelete' 1 'DWord' 'Conferma eliminazione' }
    Add-IfChecked $chkMenuDelay { Set-Reg 'HKCU:\Control Panel\Desktop' 'MenuShowDelay' '0' 'String' 'Ritardo menu' }

    # ---------- MENU START ----------
    Add-IfChecked $chkStartMorePins {
        Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' 'Start_Layout' 1 'DWord' 'Layout Start con più collegamenti'
    }
    Add-IfChecked $chkStartHideRec {
        Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Explorer' 'HideRecommendedSection' 1 'DWord' 'Sezione Consigliati'
        Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' 'Start_IrisRecommendations' 0 'DWord' 'Suggerimenti nel menu Start'
    }
    Add-IfChecked $chkStartNoWeb {
        Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Explorer' 'HideRecommendedPersonalizedSites' 1 'DWord' 'Siti consigliati'
    }
    Add-IfChecked $chkStartNoAccount {
        Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' 'Start_AccountNotifications' 0 'DWord' 'Notifiche account nel menu Start'
    }

    Add-IfChecked $chkTaskbarCenter { Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' 'TaskbarAl' 1 'DWord' 'Icone centrate' }
    Add-IfChecked $chkTaskbarSearch { Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Search' 'SearchboxTaskbarMode' 0 'DWord' 'Icona Cerca' }
    Add-IfChecked $chkTaskbarTaskView { Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' 'ShowTaskViewButton' 0 'DWord' 'Visualizzazione attivita' }
    Add-IfChecked $chkTaskbarWidgets {
        Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' 'TaskbarDa' 0 'DWord' 'Widget'
        Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Dsh' 'AllowNewsAndInterests' 0 'DWord' 'Notizie e interessi'
        Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Windows Feeds' 'EnableFeeds' 0 'DWord' 'Notizie nella barra'
    }
    Add-IfChecked $chkTaskbarChat { Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' 'TaskbarMn' 0 'DWord' 'Icona Chat' }
    Add-IfChecked $chkTaskbarEndTask { Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced\TaskbarDeveloperSettings' 'TaskbarEndTask' 1 'DWord' 'Termina attivita' }
    Add-IfChecked $chkBatteryPct { Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced' 'IsBatteryPercentageEnabled' 1 'DWord' 'Percentuale batteria' }
    Add-IfChecked $chkSettingsHome { Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\CurrentVersion\Policies\Explorer' 'SettingsPageVisibility' 'hide:home' 'String' 'Pagina iniziale Impostazioni' }
    Add-IfChecked $chkWindowSnapping { Set-Reg 'HKCU:\Control Panel\Desktop' 'WindowArrangementActive' '1' 'String' 'Affiancamento finestre' }

    Add-IfChecked $chkMouseAccel {
        Set-Reg 'HKCU:\Control Panel\Mouse' 'MouseSpeed' '0' 'String' 'Accelerazione mouse'
        Set-Reg 'HKCU:\Control Panel\Mouse' 'MouseThreshold1' '0' 'String' 'Soglia mouse 1'
        Set-Reg 'HKCU:\Control Panel\Mouse' 'MouseThreshold2' '0' 'String' 'Soglia mouse 2'
    }
    Add-IfChecked $chkNumLock { Set-Reg 'HKU:\.DEFAULT\Control Panel\Keyboard' 'InitialKeyboardIndicators' '2' 'String' 'Bloc Num all avvio' }
    Add-IfChecked $chkStickyKeys { Set-Reg 'HKCU:\Control Panel\Accessibility\StickyKeys' 'Flags' '506' 'String' 'Tasti permanenti' }
    Add-IfChecked $chkScrollbars { Set-Reg 'HKCU:\Control Panel\Accessibility' 'DynamicScrollbars' 0 'DWord' 'Barre di scorrimento' }

    Add-IfChecked $chkLockScreen { Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Personalization' 'NoLockScreen' 1 'DWord' 'Schermata di blocco' }
    Add-IfChecked $chkLogonBlur { Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\System' 'DisableAcrylicBackgroundOnLogon' 1 'DWord' 'Sfocatura all accesso' }
    Add-IfChecked $chkBSODVerbose { Set-Reg 'HKLM:\SYSTEM\CurrentControlSet\Control\CrashControl' 'DisplayParameters' 1 'DWord' 'Schermata blu dettagliata' }
    Add-IfChecked $chkLogonVerbose { Set-Reg 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System' 'verbosestatus' 1 'DWord' 'Accesso dettagliato' }

    # ---------- RETE ----------
    Add-IfChecked $chkNetPowerSave {
        $n = 0
        Get-ChildItem 'HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4D36E972-E325-11CE-BFC1-08002BE10318}' -ErrorAction SilentlyContinue |
            Where-Object { $_.PSChildName -match '^\d{4}$' } | ForEach-Object {
                try { New-ItemProperty -LiteralPath $_.PSPath -Name 'PnPCapabilities' -Value 24 -PropertyType DWord -Force -ErrorAction Stop | Out-Null; $n++ } catch {}
            }
        Write-Log "[OK] Risparmio energetico disattivato su $n schede di rete."
    }

    # IPv4 prima di IPv6: IPv6 resta attivo, cambia solo la preferenza (0x20).
    # Se e' scelto anche «IPv6» vince la disattivazione completa.
    Add-IfChecked $chkIPv4Pref {
        if ($chkDisableIPv6.IsChecked -eq $true) { Write-Log "[SALTATO] IPv4 preferito - IPv6 viene disattivato del tutto."; return }
        Set-Reg 'HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip6\Parameters' 'DisabledComponents' 32 'DWord' 'IPv4 preferito a IPv6'
    }
    Add-IfChecked $chkDisableIPv6 {
        Set-Reg 'HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip6\Parameters' 'DisabledComponents' 255 'DWord' 'IPv6'
    }

    if ($chkApplyNetwork.IsChecked -eq $true -and $radTcpCurrent.IsChecked -ne $true) {
        Add-Action "TCP / IP" {
            $tcpParams = "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters"
            netsh int tcp set global autotuninglevel=$([string]$cmbTcpAutoTuning.Text) | Out-Null
            netsh int tcp set global scalingheuristics=$([string]$cmbScalingHeuristics.Text) | Out-Null
            netsh int tcp set global congestionprovider=$([string]$cmbCongestionControl.Text) | Out-Null
            netsh int tcp set global rss=$([string]$cmbRSS.Text) | Out-Null
            netsh int tcp set global rsc=$([string]$cmbRSC.Text) | Out-Null
            netsh int tcp set global ecncapability=$([string]$cmbECN.Text) | Out-Null
            netsh int tcp set global timestamps=$([string]$cmbTimestamps.Text) | Out-Null
            Write-Log "[OK] Parametri netsh TCP applicati."

            Set-Reg $tcpParams 'DefaultTTL' ([int]$cmbTTL.Text) 'DWord' 'DefaultTTL'

            $sysProfile = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile"
            if ([string]$cmbNetThrottling.Text -match 'ffffffff') {
                Set-Reg $sysProfile 'NetworkThrottlingIndex' (-1) 'DWord' 'NetworkThrottlingIndex'
            } else {
                Set-Reg $sysProfile 'NetworkThrottlingIndex' 10 'DWord' 'NetworkThrottlingIndex'
            }
            $respText = [string]$cmbSysResponsiveness.Text
            $respVal = if ($respText -match 'gaming') { 0 } elseif ($respText -match 'default') { 20 } else { 10 }
            Set-Reg $sysProfile 'SystemResponsiveness' $respVal 'DWord' 'SystemResponsiveness'

            if ([string]$cmbNagle.Text -match 'disabled') {
                Set-RegAllInterfaces 'TcpAckFrequency' 1 'Nagle / TcpAckFrequency'
                Set-RegAllInterfaces 'TCPNoDelay' 1 'Nagle / TCPNoDelay'
                Set-RegAllInterfaces 'TcpDelAckTicks' 0 'Nagle / TcpDelAckTicks'
            } else {
                Set-RegAllInterfaces 'TcpAckFrequency' 2 'Nagle / TcpAckFrequency'
                Set-RegAllInterfaces 'TCPNoDelay' 0 'Nagle / TCPNoDelay'
            }

            $sp = "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\ServiceProvider"
            if ([string]$cmbHostPriority.Text -match 'Optimal') {
                Set-Reg $sp 'LocalPriority' 4 'DWord' 'LocalPriority'
                Set-Reg $sp 'HostPriority'  5 'DWord' 'HostPriority'
                Set-Reg $sp 'DnsPriority'   6 'DWord' 'DnsPriority'
                Set-Reg $sp 'NetbtPriority' 7 'DWord' 'NetbtPriority'
            } else { Write-Log "[SALTATO] Priorita' di risoluzione host: valori predefiniti." }

            $mem = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management"
            if ([string]$cmbNetMemAlloc.Text -match 'Optimal') {
                Set-Reg $mem 'LargeSystemCache' 1 'DWord' 'LargeSystemCache'
                Set-Reg $mem 'Size' 3 'DWord' 'Memory Management / Size'
            } else { Write-Log "[SALTATO] LargeSystemCache: valori predefiniti." }

            if ([string]$cmbPortAlloc.Text -match '65534') {
                Set-Reg $tcpParams 'MaxUserPort' 65534 'DWord' 'MaxUserPort'
                Set-Reg $tcpParams 'TcpTimedWaitDelay' 30 'DWord' 'TcpTimedWaitDelay'
            } else { Write-Log "[SALTATO] Porte dinamiche: valori predefiniti." }

            $ie = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings"
            $connText = [string]$cmbMaxConn.Text
            $conn = if ($connText -match '16') { 16 } elseif ($connText -match 'Default') { 2 } else { 10 }
            Set-Reg $ie 'MaxConnectionsPerServer' $conn 'DWord' 'MaxConnectionsPerServer'
            Set-Reg $ie 'MaxConnectionsPer1_0Server' $conn 'DWord' 'MaxConnectionsPer1_0Server'
        }
    }

    if ($chkApplyDns.IsChecked -eq $true) {
        Add-Action ([string]$chkApplyDns.Content) {
            $choice = [string]$cmbDnsProvider.Text
            $primary = ""; $secondary = ""
            if     ($choice -match 'Cloudflare') { $primary = "1.1.1.1";        $secondary = "1.0.0.1" }
            elseif ($choice -match 'Google')     { $primary = "8.8.8.8";        $secondary = "8.8.4.4" }
            elseif ($choice -match 'Quad9')      { $primary = "9.9.9.9";        $secondary = "149.112.112.112" }
            elseif ($choice -match 'OpenDNS')    { $primary = "208.67.222.222"; $secondary = "208.67.220.220" }
            elseif ($choice -match 'AdGuard')    { $primary = "94.140.14.14";   $secondary = "94.140.15.15" }

            foreach ($adapter in (Get-NetAdapter | Where-Object { $_.Status -eq 'Up' })) {
                if ($primary -ne "") {
                    Set-DnsClientServerAddress -InterfaceAlias $adapter.Name -ServerAddresses ($primary, $secondary) -ErrorAction SilentlyContinue
                    Write-Log "[OK] DNS su $($adapter.Name): $primary, $secondary"
                } else {
                    Set-DnsClientServerAddress -InterfaceAlias $adapter.Name -ResetServerAddresses -ErrorAction SilentlyContinue
                    Write-Log "[OK] DNS ripristinati su DHCP per $($adapter.Name)."
                }
            }
        }
    }

    # ---------- SCHEDA VIDEO ----------
    # Le GUID delle attivita' NVIDIA sono fisse su tutte le installazioni.
    Add-IfChecked $chkNvTelemetry {
        if (-not (Test-Gpu 'NVIDIA' 'Telemetria NVIDIA')) { return }
        Set-Svc 'NvTelemetryContainer' 'Disabled' 'Contenitore telemetria NVIDIA'
        Disable-Tasks @(
            '\NvTmRep_CrashReport1_{B2FE1952-0186-46C3-BAEC-A80AA35AC5B8}',
            '\NvTmRep_CrashReport2_{B2FE1952-0186-46C3-BAEC-A80AA35AC5B8}',
            '\NvTmRep_CrashReport3_{B2FE1952-0186-46C3-BAEC-A80AA35AC5B8}',
            '\NvTmRep_CrashReport4_{B2FE1952-0186-46C3-BAEC-A80AA35AC5B8}',
            '\NvTmMon_{B2FE1952-0186-46C3-BAEC-A80AA35AC5B8}',
            '\NvTmRepOnLogon_{B2FE1952-0186-46C3-BAEC-A80AA35AC5B8}'
        ) 'Telemetria NVIDIA'
        Set-Reg 'HKLM:\SOFTWARE\NVIDIA Corporation\NvControlPanel2\Client' 'OptInOrOutPreference' 0 'DWord' 'NVIDIA / invio dati'
        foreach ($rid in @('EnableRID44231','EnableRID64640','EnableRID66610')) {
            Set-Reg 'HKLM:\SOFTWARE\NVIDIA Corporation\Global\FTS' $rid 0 'DWord' "NVIDIA / $rid"
        }
    }

    Add-IfChecked $chkNvGfe {
        if (-not (Test-Gpu 'NVIDIA' 'GeForce Experience')) { return }
        Set-Svc 'NvContainerNetworkService' 'Disabled' 'NVIDIA Container Network'
        Set-Reg 'HKLM:\SOFTWARE\NVIDIA Corporation\NvBackend' 'StartOnLogin' 0 'DWord' 'GeForce Experience all avvio'
        Disable-Tasks @(
            '\NvNodeLauncher_{B2FE1952-0186-46C3-BAEC-A80AA35AC5B8}'
        ) 'GeForce Experience'
        Remove-Reg 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run' 'NvBackend' 'Avvio automatico GeForce Experience'
    }

    Add-IfChecked $chkNvPerfMode {
        if (-not (Test-Gpu 'NVIDIA' 'Gestione energia GPU')) { return }
        Set-GpuClassValue 'PowerMizerEnable' 1 'PowerMizer attivo' 'NVIDIA'
        Set-GpuClassValue 'PowerMizerLevel' 1 'PowerMizer su prestazioni' 'NVIDIA'
        Set-GpuClassValue 'PowerMizerLevelAC' 1 'PowerMizer su rete elettrica' 'NVIDIA'
        Set-GpuClassValue 'PerfLevelSrc' 0x2222 'Origine livello prestazioni' 'NVIDIA'
    }

    Add-IfChecked $chkNvUpdates {
        if (-not (Test-Gpu 'NVIDIA' 'Aggiornamenti NVIDIA')) { return }
        Disable-Tasks @(
            '\NvDriverUpdateCheckDaily_{B2FE1952-0186-46C3-BAEC-A80AA35AC5B8}',
            '\NvProfileUpdaterDaily_{B2FE1952-0186-46C3-BAEC-A80AA35AC5B8}',
            '\NvProfileUpdaterOnLogon_{B2FE1952-0186-46C3-BAEC-A80AA35AC5B8}'
        ) 'Aggiornamenti NVIDIA'
    }

    Add-IfChecked $chkAmdUx {
        if (-not (Test-Gpu 'AMD' 'Esperienza utente AMD')) { return }
        Set-Reg 'HKCU:\Software\AMD\CN' 'UserExperienceProgram' 'false' 'String' 'AMD / esperienza utente (utente)'
        Set-Reg 'HKLM:\SOFTWARE\AMD\CN' 'UserExperienceProgram' 'false' 'String' 'AMD / esperienza utente (sistema)'
        Disable-Tasks @('\AMD Crash Defender Task') 'AMD Crash Defender'
        Set-Svc 'AMD Crash Defender Service' 'Disabled' 'AMD Crash Defender'
    }

    Add-IfChecked $chkAmdBloat {
        if (-not (Test-Gpu 'AMD' 'Avvii automatici AMD')) { return }
        Disable-Tasks @('\StartCN', '\StartDVR', '\AMDInstallLauncher', '\AMDLinkUpdate') 'Avvii automatici AMD'
        foreach ($v in @('StartCN','AMD Link')) {
            Remove-Reg 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Run' $v "Avvio automatico $v"
        }
    }

    # ULPS spegne la scheda AMD quando e' a riposo: al risveglio le frequenze
    # ripartono dal minimo e compaiono scatti. Spento, la scheda resta pronta.
    Add-IfChecked $chkAmdUlps {
        if (-not (Test-Gpu 'AMD' 'ULPS AMD')) { return }
        Set-GpuClassValue 'EnableUlps' 0 'ULPS disattivato' 'AMD'
        Set-GpuClassValue 'PP_SclkDeepSleepDisable' 1 'Sospensione profonda del core disattivata' 'AMD'
    }

    # ---------- PRESTAZIONI NVIDIA: PROFILO DEL DRIVER ----------
    Add-IfChecked $chkNvP2 { if (Test-Gpu 'NVIDIA' 'CUDA P2') { Set-NvProfile 'P2' 'CUDA senza stato P2 forzato' } }
    Add-IfChecked $chkNvDrsPower { if (Test-Gpu 'NVIDIA' 'Gestione energia') { Set-NvProfile 'Power' 'Gestione energia: prestazioni massime' } }
    Add-IfChecked $chkNvLowLatency { if (Test-Gpu 'NVIDIA' 'Bassa latenza') { Set-NvProfile 'LowLatency' 'Modalita bassa latenza attiva' } }
    Add-IfChecked $chkNvThreaded { if (Test-Gpu 'NVIDIA' 'Ottimizzazione thread') { Set-NvProfile 'Threaded' 'Ottimizzazione thread' } }
    Add-IfChecked $chkNvTexPerf { if (Test-Gpu 'NVIDIA' 'Filtro texture') { Set-NvProfile 'TexPerf' 'Filtro texture prestazioni elevate' } }
    Add-IfChecked $chkNvAniso { if (Test-Gpu 'NVIDIA' 'Campioni anisotropici') { Set-NvProfile 'Aniso' 'Ottimizzazione campioni anisotropici' } }
    Add-IfChecked $chkNvShaderCache { if (Test-Gpu 'NVIDIA' 'Cache shader') { Set-NvProfile 'Shader' 'Cache shader illimitata' } }
    Add-IfChecked $chkNvNoAnsel { if (Test-Gpu 'NVIDIA' 'Ansel') { Set-NvProfile 'NoAnsel' 'Ansel spento' } }

    # ---------- PRESTAZIONI NVIDIA: REGISTRO DEL DRIVER ----------
    Add-IfChecked $chkNvDisplayPower {
        if (-not (Test-Gpu 'NVIDIA' 'Risparmio display')) { return }
        Set-Reg 'HKLM:\SYSTEM\CurrentControlSet\Services\nvlddmkm\Global\NVTweak' 'DisplayPowerSaving' 0 'DWord' 'Risparmio energetico del display'
    }
    Add-IfChecked $chkNvHdcp { if (Test-Gpu 'NVIDIA' 'HDCP') { Set-GpuClassValue 'RMHdcpKeyglobZero' 1 'HDCP spento' 'NVIDIA' } }
    Add-IfChecked $chkNvPreempt {
        if (-not (Test-Gpu 'NVIDIA' 'Prelazione')) { return }
        Set-GpuClassValue 'DisablePreemption' 1 'Prelazione grafica spenta' 'NVIDIA'
        Set-GpuClassValue 'DisableCudaContextPreemption' 1 'Prelazione CUDA spenta' 'NVIDIA'
    }
    Add-IfChecked $chkNvDynPstate { if (Test-Gpu 'NVIDIA' 'P-state dinamico') { Set-GpuClassValue 'DisableDynamicPstate' 1 'Frequenze fisse al massimo' 'NVIDIA' } }
    Add-IfChecked $chkNvLatency {
        if (-not (Test-Gpu 'NVIDIA' 'Pacchetto latenza')) { return }
        foreach ($k in $script:NvLatencyValues.Keys) { Set-GpuClassValue $k $script:NvLatencyValues[$k] "Latenza / $k" 'NVIDIA' }
    }

    # ---------- PRESTAZIONI AMD ----------
    Add-IfChecked $chkAmdAntiLag { if (Test-Gpu 'AMD' 'Anti-Lag') { Set-GpuClassValue 'KMD_DeLagEnabled' 1 'Anti-Lag' 'AMD' } }
    Add-IfChecked $chkAmdShaderCache { if (Test-Gpu 'AMD' 'Cache shader') { Set-AmdUmdValue 'ShaderCache' '2' 'Cache shader sempre attiva' } }
    Add-IfChecked $chkAmdTexPerf { if (Test-Gpu 'AMD' 'Filtro texture') { Set-AmdUmdValue 'TFQ' '2' 'Filtro texture su prestazioni' } }
    Add-IfChecked $chkAmdTess {
        if (-not (Test-Gpu 'AMD' 'Tassellatura')) { return }
        Set-AmdUmdValue 'Tessellation_OPTION' '2' 'Tassellatura decisa dal driver'
        Set-AmdUmdValue 'Tessellation' '1' 'Tassellatura 1x'
    }
    Add-IfChecked $chkAmdFlipQueue { if (Test-Gpu 'AMD' 'Coda fotogrammi') { Set-AmdUmdValue 'FlipQueueSize' '1' 'Coda dei fotogrammi a 1' } }
    Add-IfChecked $chkAmdNoFrtc { if (Test-Gpu 'AMD' 'Limite fotogrammi') { Set-GpuClassValue 'KMD_FRTEnabled' 0 'Limite fotogrammi del driver' 'AMD' } }
    Add-IfChecked $chkAmdStutter { if (Test-Gpu 'AMD' 'Stutter mode') { Set-GpuClassValue 'StutterMode' 0 'Modalita stutter' 'AMD' } }
    Add-IfChecked $chkAmdAspm {
        if (-not (Test-Gpu 'AMD' 'ASPM')) { return }
        Set-GpuClassValue 'EnableAspmL0s' 0 'ASPM L0s' 'AMD'
        Set-GpuClassValue 'EnableAspmL1' 0 'ASPM L1' 'AMD'
    }
    Add-IfChecked $chkAmdPowerGating {
        if (-not (Test-Gpu 'AMD' 'Power gating')) { return }
        Set-GpuClassValue 'DisableDrmdmaPowerGating' 1 'Power gating DRM DMA' 'AMD'
        Set-GpuClassValue 'DisableUVDPowerGatingDynamic' 1 'Power gating UVD' 'AMD'
        Set-GpuClassValue 'DisableVCEPowerGating' 1 'Power gating VCE' 'AMD'
    }
    Add-IfChecked $chkAmdDma {
        if (-not (Test-Gpu 'AMD' 'DMA')) { return }
        Set-GpuClassValue 'DisableDMACopy' 1 'Copie DMA' 'AMD'
        Set-GpuClassValue 'DisableBlockWrite' 0 'Scrittura a blocchi' 'AMD'
    }
    Add-IfChecked $chkAmdPreempt { if (Test-Gpu 'AMD' 'Prelazione') { Set-GpuClassValue 'KMD_EnableComputePreemption' 0 'Prelazione dei calcoli' 'AMD' } }

    Add-IfChecked $chkIntelBloat {
        if (-not (Test-Gpu 'Intel' 'Servizi Intel Graphics')) { return }
        foreach ($svc in @('igfxCUIService2.0.0.0','IntelAudioService','Intel(R) TPM Provisioning Service')) {
            Set-Svc $svc 'Manual' $svc
        }
    }

    # ---------- INTEL GRAPHICS ----------
    Add-IfChecked $chkIntelTelemetry {
        # Programma di miglioramento e resoconto d'uso dell'assistente driver Intel.
        foreach ($svc in @('ESRV_SVC_QUEENCREEK', 'SystemUsageReportSvc_QUEENCREEK')) { Set-Svc $svc 'Disabled' $svc | Out-Null }
    }
    Add-IfChecked $chkIntelGfxPower {
        if (-not (Test-Gpu 'Intel' 'Piano grafico Intel')) { return }
        Set-PowerAc '44f3beca-a7c0-460e-9df2-bb8b99e0cba6' '3619c3f2-afb2-4afc-b0e9-e7fef372de36' 2 'Piano grafico Intel: prestazioni massime'
    }
    Add-IfChecked $chkIntelDpst {
        if (-not (Test-Gpu 'Intel' 'DPST')) { return }
        Set-IntelFeatureBit 0x10 $true 'Risparmio energetico del display (DPST) spento'
        Write-Log "[INFO] Su alcuni portatili il driver Intel riaccende il DPST al riavvio."
    }

    # ---------- PROCESSORE ----------
    Add-IfChecked $chkCpuIntelBoostPol {
        if ($script:CpuVendor -ne 'Intel') { Write-Log "[SALTATO] Politica turbo - processore non Intel."; return }
        Set-PowerAc '54533251-82be-4824-96c1-47b60b740d00' '45bcc044-d885-43e2-8605-ee0ec6e96b59' 100 'Politica del turbo al 100%'
    }
    Add-IfChecked $chkCpuIntelHybrid {
        if (-not $script:CpuHybrid) { Write-Log "[SALTATO] Core P - processore senza core ibridi."; return }
        Set-PowerAc '54533251-82be-4824-96c1-47b60b740d00' '93b8b6dc-0698-4d1c-9ee4-0644e900c85d' 2 'Thread sui core P quando possibile'
        Set-PowerAc '54533251-82be-4824-96c1-47b60b740d00' 'bae08b81-2d5e-4688-ad6a-13243356654b' 2 'Thread brevi sui core P quando possibile'
    }
    Add-IfChecked $chkCpuAmdParking {
        if ($script:CpuVendor -ne 'AMD' -or $script:CpuDualX3D) { Write-Log "[SALTATO] Parcheggio dei core - non adatto a questo processore."; return }
        Set-PowerAc '54533251-82be-4824-96c1-47b60b740d00' '0cc5b647-c1df-4637-891a-dec35c318583' 100 'Core sempre attivi'
    }
    Add-IfChecked $chkCpuIdleOff {
        Set-PowerAc '54533251-82be-4824-96c1-47b60b740d00' '5d76a2ca-e8c0-402f-a133-2158492d58ad' 1 'Stati di riposo del processore spenti'
    }

    Add-IfChecked $chkGpuTdr {
        $g = 'HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers'
        Set-Reg $g 'TdrDelay' 10 'DWord' 'TdrDelay'
        Set-Reg $g 'TdrDdiDelay' 10 'DWord' 'TdrDdiDelay'
    }

    # MSI: si scrive sotto la chiave del dispositivo, non nella classe display.
    Add-IfChecked $chkGpuMsi {
        $n = 0
        try {
            foreach ($gpu in (Get-CimInstance Win32_VideoController -ErrorAction Stop |
                              Where-Object { $_.PNPDeviceID -and $_.PNPDeviceID -notmatch '^ROOT\\' })) {
                $path = "HKLM:\SYSTEM\CurrentControlSet\Enum\$($gpu.PNPDeviceID)\Device Parameters\Interrupt Management\MessageSignaledInterruptProperties"
                if (Set-Reg $path 'MSISupported' 1 'DWord' "MSI / $($gpu.Name)") { $n++ }
            }
        } catch {}
        Write-Log "[OK] Interrupt MSI configurati su $n schede (serve un riavvio)."
    }

    # ---------- ARCHIVIAZIONE ----------
    Add-IfChecked $chkStorageSense {
        Set-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\StorageSense\Parameters\StoragePolicy' '01' 0 'DWord' 'Sensore memoria'
    }
    Add-IfChecked $chkReservedStorage {
        Dism.exe /Online /Set-ReservedStorageState /State:Disabled | Out-Null
        Write-Log "[OK] Spazio riservato disattivato."
    }

    if ($chkStorageProfile.IsChecked -eq $true) {
        $diskProfile = if ($radStorageSSD.IsChecked) { 'SSD' } elseif ($radStorageHDD.IsChecked) { 'HDD' } else { 'Unknown' }
        Add-Action "$([string]$chkStorageProfile.Content) ($diskProfile)" {
            $p = if ($radStorageSSD.IsChecked) { 'SSD' } elseif ($radStorageHDD.IsChecked) { 'HDD' } else { 'Unknown' }
            if ($p -eq 'Unknown') {
                Write-Log "[AVVISO] $(T 'chooseProfile')"
                return
            }
            if ($p -eq 'SSD') {
                Get-Volume | Where-Object { $_.DriveLetter -and $_.DriveType -eq 'Fixed' } | ForEach-Object {
                    Optimize-Volume -DriveLetter $_.DriveLetter -ReTrim -ErrorAction SilentlyContinue | Out-Null
                }
                Write-Log "[OK] TRIM eseguito sulle unita' disponibili."
            } else {
                $pf = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management\PrefetchParameters"
                Set-Reg $pf 'EnablePrefetcher' 3 'DWord' 'Prefetch'
                Set-Reg $pf 'EnableSuperfetch' 3 'DWord' 'Superfetch'
                Set-Svc 'SysMain' 'Automatic' 'SysMain'
                Start-Service -Name SysMain -ErrorAction SilentlyContinue
                defrag.exe C: /O /U | Out-Null
                Write-Log "[OK] Ottimizzazione HDD completata."
            }
        }
    }

    Add-IfChecked $chkDiskCleanup {
        $sage = "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches"
        Get-ChildItem $sage -ErrorAction SilentlyContinue | ForEach-Object {
            Set-ItemProperty -LiteralPath $_.PSPath -Name "StateFlags0064" -Value 2 -Type DWord -Force -ErrorAction SilentlyContinue
        }
        Start-Process -FilePath "cleanmgr.exe" -ArgumentList "/sagerun:64" -NoNewWindow -Wait
        Dism.exe /Online /Cleanup-Image /StartComponentCleanup /ResetBase | Out-Null
        Write-Log "[OK] Pulizia disco e compattazione WinSxS completate."
    }


    Add-IfChecked $chkSmartChkdsk {
        try {
            $disk = Get-PhysicalDisk | Where-Object { $_.DeviceId -eq 0 } | Select-Object -First 1
            if (-not $disk) { $disk = Get-PhysicalDisk | Select-Object -First 1 }
            if ($disk -and ($disk.MediaType -eq 'SSD' -or $disk.BusType -eq 'NVMe')) {
                Write-Log "[INFO] Disco di sistema SSD/NVMe: CHKDSK senza /r."
                "Y" | chkdsk C: /f | Out-Null
            } else {
                Write-Log "[INFO] Disco di sistema meccanico: CHKDSK con /r."
                "Y" | chkdsk C: /f /r | Out-Null
            }
            Write-Log "[OK] CHKDSK pianificato al prossimo riavvio."
        } catch { Write-Log "[ERRORE] CHKDSK: $($_.Exception.Message)" }
    }

    # ---------- AVANZATE: servizi ----------
    # Ogni voce spegne un gruppo di servizi. Set-Svc salta da solo quelli che
    # su questa installazione non esistono, quindi l'elenco puo' essere ampio.
    Add-IfChecked $chkSvcSysMain {
        Set-Svc 'SysMain' 'Disabled' 'SysMain'
    }
    Add-IfChecked $chkSvcDiag {
        foreach ($s in @('DPS','WdiServiceHost','WdiSystemHost','diagnosticshub.standardcollector.service','diagsvc','DusmSvc')) {
            Set-Svc $s 'Disabled' $s
        }
    }
    Add-IfChecked $chkSvcPca {
        Set-Svc 'PcaSvc' 'Disabled' 'Assistente compatibilita'
    }
    Add-IfChecked $chkSvcDiscovery {
        foreach ($s in @('SSDPSRV','upnphost','fdPHost','FDResPub','lltdsvc','Browser','NetTcpPortSharing')) {
            Set-Svc $s 'Disabled' $s
        }
    }
    Add-IfChecked $chkSvcSensors {
        foreach ($s in @('SensorService','SensrSvc','SensorDataService','lfsvc')) { Set-Svc $s 'Disabled' $s }
    }
    Add-IfChecked $chkSvcSmartCard {
        foreach ($s in @('SCardSvr','ScDeviceEnum','SCPolicySvc')) { Set-Svc $s 'Disabled' $s }
    }
    Add-IfChecked $chkSvcParental {
        foreach ($s in @('WpcMonSvc','wisvc')) { Set-Svc $s 'Disabled' $s }
    }
    Add-IfChecked $chkSvcHyperV {
        foreach ($s in @('HvHost','vmickvpexchange','vmicguestinterface','vmicshutdown','vmicheartbeat',
                         'vmicvmsession','vmicrdv','vmictimesync','vmcompute','vmms')) {
            Set-Svc $s 'Disabled' $s
        }
    }
    Add-IfChecked $chkSvcPrint {
        foreach ($s in @('Spooler','PrintNotify','PrintWorkflowUserSvc')) { Set-Svc $s 'Disabled' $s }
    }
    Add-IfChecked $chkSvcSearch {
        Set-Svc 'WSearch' 'Disabled' 'Ricerca di Windows'
    }
    Add-IfChecked $chkSvcRemote {
        foreach ($s in @('RemoteRegistry','RemoteAccess','SessionEnv','TermService','UmRdpService','RasMan','RasAuto')) {
            Set-Svc $s 'Disabled' $s
        }
    }
    Add-IfChecked $chkSvcBiometric {
        Set-Svc 'WbioSrvc' 'Disabled' 'Biometria'
    }
    Add-IfChecked $chkSvcTouch {
        foreach ($s in @('TabletInputService','TextInputManagementService')) { Set-Svc $s 'Disabled' $s }
    }

    # ---------- AVANZATE: attivita' pianificate ----------
    Add-IfChecked $chkTaskExtra {
        Disable-Tasks @(
            '\Microsoft\Windows\Application Experience\StartupAppTask',
            '\Microsoft\Windows\Application Experience\PcaPatchDbTask',
            '\Microsoft\Windows\Application Experience\MareBackup',
            '\Microsoft\Windows\CloudExperienceHost\CreateObjectTask',
            '\Microsoft\Windows\Maps\MapsToastTask',
            '\Microsoft\Windows\Maps\MapsUpdateTask',
            '\Microsoft\Windows\Windows Error Reporting\QueueReporting',
            '\Microsoft\Windows\Speech\SpeechModelDownloadTask',
            '\Microsoft\Windows\Retail Demo\CleanupOfflineContent',
            '\Microsoft\Windows\PI\Sqm-Tasks',
            '\Microsoft\Windows\DiskFootprint\Diagnostics',
            '\Microsoft\Windows\DiskDiagnostic\Microsoft-Windows-DiskDiagnosticResolver',
            '\Microsoft\Windows\FileHistory\File History (maintenance mode)',
            '\Microsoft\Windows\License Manager\TempSignedLicenseExchange',
            '\Microsoft\Windows\Shell\FamilySafetyMonitor',
            '\Microsoft\Windows\Shell\FamilySafetyRefreshTask',
            '\Microsoft\Windows\Power Efficiency Diagnostics\AnalyzeSystem',
            '\Microsoft\Windows\Chkdsk\ProactiveScan',
            '\Microsoft\Windows\Offline Files\Background Synchronization',
            '\Microsoft\Windows\Offline Files\Logon Synchronization'
        ) 'Attivita non essenziali'
    }
    Add-IfChecked $chkTaskMaint {
        Set-Reg 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Schedule\Maintenance' 'MaintenanceDisabled' 1 'DWord' 'Manutenzione automatica'
        Disable-Tasks @('\Microsoft\Windows\TaskScheduler\Idle Maintenance',
                        '\Microsoft\Windows\TaskScheduler\Regular Maintenance',
                        '\Microsoft\Windows\TaskScheduler\Maintenance Configurator') 'Attivita di manutenzione'
    }
    Add-IfChecked $chkTaskDefrag {
        Disable-Tasks @('\Microsoft\Windows\Defrag\ScheduledDefrag') 'Ottimizzazione unita pianificata'
        Write-Log "[AVVISO] Su SSD questa attivita' inviava anche il TRIM: ricordati di lanciarlo a mano dalla pagina Archiviazione."
    }

    # ---------- AVANZATE: memoria e processi ----------
    Add-IfChecked $chkPrefetch {
        $pf = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management\PrefetchParameters"
        Set-Reg $pf 'EnablePrefetcher' 0 'DWord' 'Prefetcher'
        Set-Reg $pf 'EnableSuperfetch' 0 'DWord' 'Superfetch'
    }
    Add-IfChecked $chkFth {
        Set-Reg 'HKLM:\SOFTWARE\Microsoft\FTH' 'Enabled' 0 'DWord' 'Fault Tolerant Heap'
    }
    Add-IfChecked $chkAppCompat {
        $a = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppCompat'
        Set-Reg $a 'DisablePCA' 1 'DWord' 'Assistente compatibilita'
        Set-Reg $a 'DisableUAR' 1 'DWord' 'Segnalazione compatibilita'
        Set-Reg $a 'DisableInventory' 1 'DWord' 'Inventario programmi'
        Set-Reg $a 'DisableEngine' 1 'DWord' 'Motore di compatibilita'
        Set-Reg $a 'AITEnable' 0 'DWord' 'Application Impact Telemetry'
    }
    Add-IfChecked $chkMemCompression {
        try {
            Disable-MMAgent -MemoryCompression -ErrorAction Stop
            Write-Log "[OK] Compressione della memoria disattivata."
        } catch { Write-Log "[ERRORE] Compressione della memoria: $($_.Exception.Message)" }
    }

    # ---------- AVANZATE: aggiornamenti ----------
    Add-IfChecked $chkWuProfile { Set-WuProfile $script:WuProfileChoice }
    # ---------- AVANZATE: orologio e periferiche ----------
    Add-IfChecked $chkAdvUtc {
        Set-Reg 'HKLM:\SYSTEM\CurrentControlSet\Control\TimeZoneInformation' 'RealTimeIsUniversal' 1 'QWord' 'Orologio del BIOS in UTC'
    }
    # Le periferiche Razer installano Synapse da sole tramite un co-installer: si
    # bloccano i co-installer e si rende non scrivibile la cartella che lo riceve.
    Add-IfChecked $chkAdvRazer {
        Set-Reg 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Device Installer' 'DisableCoInstallers' 1 'DWord' 'Co-installer dei driver'
        Lock-Folder "$env:SystemRoot\Installer\Razer" 'Cartella di installazione Razer'
    }
    Add-IfChecked $chkAdvLogi {
        Stop-Process -Name 'logi_download_assistant' -Force -ErrorAction SilentlyContinue
        $pf = if ($env:ProgramW6432) { $env:ProgramW6432 } else { $env:ProgramFiles }
        Lock-Folder "$pf\LogiDownloadAssistant" 'Assistente download Logitech'
    }
    Add-IfChecked $chkWuNoStore {
        Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\WindowsStore' 'AutoDownload' 2 'DWord' 'Aggiornamento automatico app Store'
    }

    # ---------- AVANZATE: avvio del sistema ----------
    Add-IfChecked $chkBootQuiet {
        Set-Bcd '/set {current} quietboot yes' 'Avvio senza logo'
        Set-Bcd '/set {current} bootlog no' 'Niente registro di avvio'
    }
    Add-IfChecked $chkBootMenu {
        Set-Bcd '/set {current} bootmenupolicy legacy' 'Menu di avvio classico'
    }
    Add-IfChecked $chkBootTimeout {
        Set-Bcd '/timeout 0' 'Attesa del menu di avvio'
    }
    Add-IfChecked $chkBootDynTick {
        Set-Bcd '/set disabledynamictick yes' 'Tick dinamico del kernel'
    }
    Add-IfChecked $chkBootTsc {
        Set-Bcd '/set tscsyncpolicy Enhanced' 'Sincronizzazione TSC'
    }

    # ---------- AVANZATE: app preinstallate ----------
    Add-IfChecked $chkAppxBloat {
        Remove-AppxList @(
            'Microsoft.3DBuilder','Microsoft.549981C3F5F10','Microsoft.BingFinance','Microsoft.BingNews',
            'Microsoft.BingSports','Microsoft.BingWeather','Microsoft.GetHelp','Microsoft.Getstarted',
            'Microsoft.Messaging','Microsoft.Microsoft3DViewer','Microsoft.MicrosoftOfficeHub',
            'Microsoft.MicrosoftSolitaireCollection','Microsoft.MixedReality.Portal','Microsoft.NetworkSpeedTest',
            'Microsoft.OneConnect','Microsoft.People','Microsoft.Print3D','Microsoft.SkypeApp','Microsoft.Wallet',
            'Microsoft.WindowsAlarms','Microsoft.WindowsFeedbackHub','Microsoft.WindowsMaps',
            'Microsoft.WindowsSoundRecorder','Microsoft.YourPhone','Microsoft.ZuneMusic','Microsoft.ZuneVideo',
            'Microsoft.Todos','Microsoft.PowerAutomateDesktop','Microsoft.Windows.DevHome',
            'MicrosoftTeams','MSTeams','Clipchamp.Clipchamp','MicrosoftCorporationII.QuickAssist'
        ) ($chkAppxProvision.IsChecked -eq $true) 'App non essenziali'
    }
    Add-IfChecked $chkAppxXbox {
        Remove-AppxList @(
            'Microsoft.XboxApp','Microsoft.GamingApp','Microsoft.XboxGameOverlay','Microsoft.XboxGamingOverlay',
            'Microsoft.XboxSpeechToTextOverlay','Microsoft.XboxIdentityProvider'
        ) ($chkAppxProvision.IsChecked -eq $true) 'App Xbox'
        Write-Log "[INFO] Xbox.TCUI resta installata: alcuni giochi la richiedono per l'accesso."
    }

    # ---------- AVANZATE: sicurezza ridotta ----------
    Add-IfChecked $chkSecSmartScreen {
        Set-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\System' 'EnableSmartScreen' 0 'DWord' 'SmartScreen'
        Set-Reg 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer' 'SmartScreenEnabled' 'Off' 'String' 'SmartScreen in Esplora file'
        Set-Reg 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppHost' 'EnableWebContentEvaluation' 0 'DWord' 'SmartScreen nelle app'
    }
    Add-IfChecked $chkSecSpectre {
        # Valori documentati da Microsoft per disattivare le mitigazioni delle
        # vulnerabilita' speculative. Restituiscono prestazioni sulle CPU vecchie.
        $m = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management"
        Set-Reg $m 'FeatureSettingsOverride' 3 'DWord' 'Mitigazioni Spectre/Meltdown'
        Set-Reg $m 'FeatureSettingsOverrideMask' 3 'DWord' 'Maschera mitigazioni'
    }
    Add-IfChecked $chkSecDefenderIdle {
        # Non spegne Defender: la protezione antimanomissione lo rimetterebbe in
        # piedi. Riduce solo il peso delle scansioni pianificate.
        $s = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\Scan'
        Set-Reg $s 'ScanOnlyIfIdle' 1 'DWord' 'Defender: scansioni solo a computer fermo'
        Set-Reg $s 'AvgCPULoadFactor' 20 'DWord' 'Defender: tetto di CPU'
        Set-Reg $s 'DisableScanningNetworkFiles' 1 'DWord' 'Defender: niente scansione dei file in rete'
        Disable-Tasks @('\Microsoft\Windows\Windows Defender\Windows Defender Scheduled Scan',
                        '\Microsoft\Windows\Windows Defender\Windows Defender Cache Maintenance') 'Scansioni pianificate di Defender'
        Write-Log "[INFO] La protezione in tempo reale resta attiva: la disattiva solo l'utente da Sicurezza di Windows."
    }
}

# ------------------------------------------------------------------------------
# 14. PULSANTE APPLICA
# ------------------------------------------------------------------------------
$btnRun.Add_Click({
    Build-Actions
    $total = $script:Actions.Count
    if ($total -eq 0) {
        Write-Log "[AVVISO] $(T 'nothing')"
        Update-ApplyButton
        return
    }

    if (-not (Show-Dialog (T 'confirmTitle') (T 'confirmRun') 'ask' ((T 'selCount') -f $total))) { return }

    # Le voci della pagina Avanzate tolgono pezzi di Windows: seconda conferma.
    $advChecked = @($script:AdvancedCheckBoxes | Where-Object { $_.IsChecked -eq $true }).Count
    if ($advChecked -gt 0) {
        if (-not (Show-Dialog (T 'advWarnTitle') (T 'advWarn') 'warn')) { return }
    }

    Invoke-ActionQueue "Tweak Andrew v6.0"
})

# ------------------------------------------------------------------------------
# 15. INIZIALIZZAZIONE
# ------------------------------------------------------------------------------
# RAM installata: preseleziona la voce piu' vicina alla memoria reale.
try {
    $ramGB = [math]::Round((Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory / 1GB, 0)
    $options = @(2,4,8,16,32,64,128)
    $closest = ($options | Sort-Object { [math]::Abs($_ - $ramGB) } | Select-Object -First 1)
    foreach ($item in $cmbRamAmount.Items) {
        if ([string]$item.Content -eq "$closest GB") { $cmbRamAmount.SelectedItem = $item; break }
    }
} catch {}

$cmbLang.Add_SelectionChanged({
    $item = $cmbLang.SelectedItem
    if ($null -ne $item) { Set-Language ([string]$item.Tag) }
})

Set-Language 'it'
Show-StorageInventory
Update-PowerPlanLabel
Update-ApplyButton


[void]$window.ShowDialog()
