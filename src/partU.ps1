
# ------------------------------------------------------------------------------
# 14b. ANNULLA — ritorno ai valori predefiniti di Windows
# ------------------------------------------------------------------------------
# Come in WinUtil: si spuntano le voci e «Annulla selezionate» rimette per
# ognuna il comportamento di fabbrica. Non serve averle applicate con questa
# versione: ogni voce sa quali valori tocca e quali sono quelli originali.
# Un valore che su un'installazione pulita non esiste si cancella, non si
# riscrive: e' Windows a scegliere, come prima.

# Senza $Default il valore viene tolto; con $Default viene riscritto.
function Reset-Reg {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$Name,
        $Default = $null,
        [ValidateSet('DWord','QWord','String','ExpandString','Binary')][string]$Type = 'DWord'
    )
    if ($null -eq $Default) { Remove-Reg $Path $Name "$Name" }
    else { Set-Reg $Path $Name $Default $Type "$Name = $Default" | Out-Null }
}

function Enable-Tasks {
    param([Parameter(Mandatory)][string[]]$Tasks,[string]$Label)
    $done = 0
    foreach ($t in $Tasks) {
        $path = Split-Path $t -Parent
        if ([string]::IsNullOrEmpty($path)) { $path = '\' }
        if (-not $path.EndsWith('\')) { $path += '\' }
        $name = Split-Path $t -Leaf
        try {
            Enable-ScheduledTask -TaskPath $path -TaskName $name -ErrorAction Stop | Out-Null
            $done++
        } catch {}
    }
    if ($done -gt 0) { Write-Log "[OK] $Label - $done attivita' riattivate." }
    else { Write-Log "[SALTATO] $Label - nessuna attivita' presente." }
}

function Remove-GpuClassValue {
    param([string]$Name, [string]$Vendor = '')
    foreach ($k in @(Get-GpuClassKeys $Vendor)) {
        Remove-ItemProperty -LiteralPath $k.PSPath -Name $Name -ErrorAction SilentlyContinue
    }
    Write-Log "[OK] $Name tolto dalle schede video."
}

function Remove-RegAllInterfaces {
    param([string]$Name)
    Get-ChildItem 'HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces' -ErrorAction SilentlyContinue |
        ForEach-Object { Remove-ItemProperty -LiteralPath $_.PSPath -Name $Name -ErrorAction SilentlyContinue }
    Write-Log "[OK] $Name tolto da tutte le interfacce."
}

# Tipo di avvio originale dei servizi toccati dal programma.
$script:SvcDefault = @{
    MapsBroker='Automatic'; Fax='Manual'; XblAuthManager='Manual'; XblGameSave='Manual'; XboxNetApiSvc='Manual'
    XboxGipSvc='Manual'; RetailDemo='Manual'; WalletService='Manual'; PhoneSvc='Manual'
    DiagTrack='Automatic'; dmwappushservice='Manual'; lfsvc='Manual'; WerSvc='Manual'; DoSvc='Automatic'; BDESVC='Manual'
    SysMain='Automatic'; DPS='Automatic'; WdiServiceHost='Manual'; WdiSystemHost='Manual'
    'diagnosticshub.standardcollector.service'='Manual'; diagsvc='Manual'; DusmSvc='Automatic'; PcaSvc='Automatic'
    SSDPSRV='Manual'; upnphost='Manual'; fdPHost='Manual'; FDResPub='Manual'; lltdsvc='Manual'; Browser='Manual'
    NetTcpPortSharing='Disabled'; SensorService='Manual'; SensrSvc='Manual'; SensorDataService='Manual'
    SCardSvr='Manual'; ScDeviceEnum='Manual'; SCPolicySvc='Manual'; WpcMonSvc='Manual'; wisvc='Manual'
    HvHost='Manual'; vmickvpexchange='Manual'; vmicguestinterface='Manual'; vmicshutdown='Manual'; vmicheartbeat='Manual'
    vmicvmsession='Manual'; vmicrdv='Manual'; vmictimesync='Manual'; vmcompute='Manual'; vmms='Automatic'
    Spooler='Automatic'; PrintNotify='Manual'; PrintWorkflowUserSvc='Manual'; WSearch='Automatic'
    RemoteRegistry='Disabled'; RemoteAccess='Disabled'; SessionEnv='Manual'; TermService='Manual'; UmRdpService='Manual'
    RasMan='Manual'; RasAuto='Manual'; WbioSrvc='Manual'; TabletInputService='Manual'; TextInputManagementService='Automatic'
    NvTelemetryContainer='Automatic'; NvContainerNetworkService='Manual'; 'AMD Crash Defender Service'='Automatic'
    'igfxCUIService2.0.0.0'='Automatic'; IntelAudioService='Automatic'; 'Intel(R) TPM Provisioning Service'='Automatic'
}

function Reset-Svc {
    param([Parameter(Mandatory)][string[]]$Names)
    foreach ($n in $Names) {
        $type = $script:SvcDefault[$n]
        if (-not $type) { $type = 'Manual' }
        Set-Svc $n $type $n | Out-Null
    }
}

function Reset-Bcd {
    param([string]$Arguments,[string]$Label)
    # deletevalue su una voce mai impostata risponde con un errore: e' gia' predefinita.
    $p = Start-Process -FilePath "$env:SystemRoot\System32\bcdedit.exe" -ArgumentList $Arguments `
                       -Wait -PassThru -WindowStyle Hidden -ErrorAction SilentlyContinue
    if ($p -and $p.ExitCode -eq 0) { Write-Log "[OK] $Label" } else { Write-Log "[SALTATO] $Label - gia' predefinito." }
}

function Add-UndoIfChecked {
    param($Box,[scriptblock]$Do)
    if ($null -ne $Box -and $Box.IsChecked -eq $true) { Add-Action ("$(T 'undoPrefix') " + [string]$Box.Content) $Do }
}

# Voci che non hanno un «prima» da ripristinare: pulizie, file eliminati,
# app disinstallate. Si elencano comunque, cosi' il registro spiega perche'.
function Add-NoUndo {
    param($Box,[string]$Reason)
    if ($null -ne $Box -and $Box.IsChecked -eq $true) {
        $label = [string]$Box.Content
        Add-Action ("$(T 'undoPrefix') $label") ([scriptblock]::Create("Write-Log '[SALTATO] $($label -replace "'", "''") - $($Reason -replace "'", "''")'"))
    }
}

function Build-UndoActions {
    $script:Actions = @()
    $adv = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'
    $mm  = 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management'

    Add-NoUndo $chkRestorePoint 'un punto di ripristino non si annulla: si elimina da Protezione sistema.'

    # ---------- PRESTAZIONI ----------
    Add-UndoIfChecked $chkMMCSS {
        $p = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile"
        Reset-Reg $p 'AlwaysOn'; Reset-Reg $p 'NoLazyMode'
        Reset-Reg $p 'SystemResponsiveness' 20
        $g = "$p\Tasks\Games"
        Reset-Reg $g 'Affinity' 0
        Reset-Reg $g 'Background Only' 'False' 'String'
        Reset-Reg $g 'Clock Rate' 10000
        Reset-Reg $g 'GPU Priority' 8
        Reset-Reg $g 'Latency Sensitive'
        Reset-Reg $g 'Priority' 2
        Reset-Reg $g 'Scheduling Category' 'Medium' 'String'
        Reset-Reg $g 'SFIO Priority' 'Normal' 'String'
    }
    Add-UndoIfChecked $chkPriority { Reset-Reg 'HKLM:\SYSTEM\CurrentControlSet\Control\PriorityControl' 'Win32PrioritySeparation' 2 }
    Add-UndoIfChecked $chkKernelMem {
        Reset-Reg $mm 'DisablePagingExecutive' 0
        Reset-Reg $mm 'LargeSystemCache' 0
        Reset-Reg $mm 'SecondLevelDataCache' 0
    }
    Add-UndoIfChecked $chkKernelDpc {
        $k = "HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Kernel"
        Reset-Reg $k 'DpcWatchdogProfileOffset'; Reset-Reg $k 'ThreadDpcEnable'; Reset-Reg $k 'DebugPollInterval'
    }
    Add-UndoIfChecked $chkTimer {
        Reset-Reg 'HKLM:\SYSTEM\CurrentControlSet\Control\Power' 'TimerInterval'
        Reset-Reg 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager' 'TimerInterval'
    }
    Add-UndoIfChecked $chkPowerThrottling { Reset-Reg 'HKLM:\SYSTEM\CurrentControlSet\Control\Power\PowerThrottling' 'PowerThrottlingOff' }
    Add-UndoIfChecked $chkUSBSuspend { Reset-Reg 'HKLM:\SYSTEM\CurrentControlSet\Services\USB' 'DisableSelectiveSuspend' }
    Add-UndoIfChecked $chkNtfsPerf {
        # 2 = gestito dal sistema, il valore di fabbrica da Windows 10 1803.
        fsutil behavior set disablelastaccess 2 | Out-Null
        fsutil behavior set memoryusage 1 | Out-Null
        Write-Log "[OK] NTFS: ultimo accesso gestito dal sistema, cache normale."
    }
    Add-UndoIfChecked $chkRamTweak { Reset-Reg 'HKLM:\SYSTEM\CurrentControlSet\Control' 'SvcHostSplitThresholdInKB' 3670016 }

    Add-UndoIfChecked $chkGameMode {
        Reset-Reg 'HKCU:\Software\Microsoft\GameBar' 'AllowAutoGameMode'
        Reset-Reg 'HKCU:\Software\Microsoft\GameBar' 'AutoGameModeEnabled'
    }
    Add-UndoIfChecked $chkFSO {
        $g = "HKCU:\System\GameConfigStore"
        Reset-Reg $g 'GameDVR_FSEBehaviorMode' 0
        Reset-Reg $g 'GameDVR_HonorUserFSEBehaviorMode' 0
        Reset-Reg $g 'GameDVR_DXGIHonorFSEMode' 0
    }
    Add-UndoIfChecked $chkGameDVR {
        Reset-Reg 'HKCU:\System\GameConfigStore' 'GameDVR_Enabled' 1
        Reset-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\GameDVR' 'AllowGameDVR'
        Reset-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\GameDVR' 'AppCaptureEnabled'
    }
    Add-UndoIfChecked $chkHAGS { Reset-Reg 'HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers' 'HwSchMode' }
    Add-UndoIfChecked $chkVisualFX {
        Reset-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\VisualEffects' 'VisualFXSetting' 0
        Reset-Reg 'HKCU:\Control Panel\Desktop' 'DragFullWindows' '1' 'String'
    }
    Add-UndoIfChecked $chkApplyMPO { Reset-Reg 'HKLM:\SOFTWARE\Microsoft\Windows\DWM' 'OverlayTestMode' }
    Add-UndoIfChecked $chkVBS {
        Reset-Reg 'HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard' 'EnableVirtualizationBasedSecurity'
        Reset-Reg 'HKLM:\SYSTEM\CurrentControlSet\Control\DeviceGuard\Scenarios\HypervisorEnforcedCodeIntegrity' 'Enabled' 1
        Write-Log "[INFO] Integrita' della memoria riattivata: se un driver non e' compatibile, Windows la lascia spenta e lo segnala in Sicurezza di Windows."
    }
    Add-UndoIfChecked $chkMitigations {
        try {
            Set-ProcessMitigation -System -Enable CFG,BottomUp,HighEntropy,SEHOP -ErrorAction Stop
            Write-Log "[OK] Mitigazioni di sistema riattivate."
        } catch { Write-Log "[AVVISO] Mitigazioni non modificate: $($_.Exception.Message)" }
    }

    # ---------- ALIMENTAZIONE ----------
    Add-UndoIfChecked $chkFastStartup { Reset-Reg 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Power' 'HiberbootEnabled' 1 }
    Add-UndoIfChecked $chkHibernation { powercfg /h on | Out-Null; Write-Log "[OK] Ibernazione riattivata." }
    Add-UndoIfChecked $chkS0Sleep { Reset-Reg 'HKLM:\SYSTEM\CurrentControlSet\Control\Power' 'EnforceConnectivityInStandby' }
    Add-UndoIfChecked $chkS3Sleep { Reset-Reg 'HKLM:\SYSTEM\CurrentControlSet\Control\Power' 'PlatformAoAcOverride' }

    # ---------- PRIVACY ----------
    Add-UndoIfChecked $chkTelemetry {
        Reset-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection' 'AllowTelemetry'
        Reset-Svc @('DiagTrack','dmwappushservice')
    }
    Add-UndoIfChecked $chkTelemetryTasks {
        Enable-Tasks @(
            '\Microsoft\Windows\Application Experience\Microsoft Compatibility Appraiser',
            '\Microsoft\Windows\Application Experience\ProgramDataUpdater',
            '\Microsoft\Windows\Autochk\Proxy',
            '\Microsoft\Windows\Customer Experience Improvement Program\Consolidator',
            '\Microsoft\Windows\Customer Experience Improvement Program\UsbCeip',
            '\Microsoft\Windows\DiskDiagnostic\Microsoft-Windows-DiskDiagnosticDataCollector',
            '\Microsoft\Windows\Feedback\Siuf\DmClient',
            '\Microsoft\Windows\Feedback\Siuf\DmClientOnScenarioDownload'
        ) 'Attivita di telemetria'
    }
    Add-UndoIfChecked $chkActivityHistory {
        $p = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\System'
        Reset-Reg $p 'PublishUserActivities'; Reset-Reg $p 'EnableActivityFeed'; Reset-Reg $p 'UploadUserActivities'
    }
    Add-UndoIfChecked $chkLocationTracking {
        Reset-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\LocationAndSensors' 'DisableLocation'
        Reset-Svc @('lfsvc')
    }
    Add-UndoIfChecked $chkAdvertisingID {
        Reset-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\AdvertisingInfo' 'Enabled'
        Reset-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\AdvertisingInfo' 'DisabledByGroupPolicy'
    }
    Add-UndoIfChecked $chkTailoredExp { Reset-Reg 'HKCU:\Software\Policies\Microsoft\Windows\CloudContent' 'DisableTailoredExperiencesWithDiagnosticData' }
    Add-UndoIfChecked $chkFeedback {
        Reset-Reg 'HKCU:\Software\Microsoft\Siuf\Rules' 'NumberOfSIUFInPeriod'
        Reset-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DataCollection' 'DoNotShowFeedbackNotifications'
    }
    Add-UndoIfChecked $chkErrorReporting {
        Reset-Reg 'HKLM:\SOFTWARE\Microsoft\Windows\Windows Error Reporting' 'Disabled'
        Reset-Svc @('WerSvc')
    }
    Add-UndoIfChecked $chkInkingTyping {
        Reset-Reg 'HKCU:\Software\Microsoft\Input\TIPC' 'Enabled'
        Reset-Reg 'HKCU:\Software\Microsoft\Personalization\Settings' 'AcceptedPrivacyPolicy'
    }
    Add-UndoIfChecked $chkWiFiSense {
        $b = 'HKLM:\SOFTWARE\Microsoft\PolicyManager\default\WiFi'
        Reset-Reg "$b\AllowWiFiHotSpotReporting" 'Value' 1
        Reset-Reg "$b\AllowAutoConnectToWiFiSenseHotspots" 'Value' 1
    }
    Add-UndoIfChecked $chkConsumerFeatures { Reset-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\CloudContent' 'DisableWindowsConsumerFeatures' }
    Add-UndoIfChecked $chkStoreSearch {
        Reset-Reg 'HKCU:\SOFTWARE\Policies\Microsoft\Windows\Explorer' 'DisableSearchBoxSuggestions'
        Reset-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Search' 'BingSearchEnabled'
    }
    Add-UndoIfChecked $chkSuggestedContent {
        $c = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'
        foreach ($v in @('SubscribedContent-338393Enabled','SubscribedContent-353694Enabled','SubscribedContent-353696Enabled','SystemPaneSuggestionsEnabled','SilentInstalledAppsEnabled','PreInstalledAppsEnabled','OemPreInstalledAppsEnabled')) {
            Reset-Reg $c $v 1
        }
    }
    Add-UndoIfChecked $chkLockScreenAds {
        $c = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\ContentDeliveryManager'
        Reset-Reg $c 'RotatingLockScreenOverlayEnabled' 1
        Reset-Reg $c 'SubscribedContent-338387Enabled' 1
    }
    Add-UndoIfChecked $chkStartBing { Reset-Reg 'HKCU:\Software\Policies\Microsoft\Windows\Explorer' 'DisableSearchBoxSuggestions' }
    Add-UndoIfChecked $chkStartRecs { Reset-Reg $adv 'Start_IrisRecommendations' }
    Add-UndoIfChecked $chkStartTracking { Reset-Reg $adv 'Start_TrackProgs' 1; Reset-Reg $adv 'Start_TrackDocs' 1 }
    Add-UndoIfChecked $chkFolderDiscovery { Reset-Reg 'HKCU:\Software\Classes\Local Settings\Software\Microsoft\Windows\Shell\Bags\AllFolders\Shell' 'FolderType' }

    Add-UndoIfChecked $chkWindowsAI {
        Reset-Reg 'HKCU:\Software\Policies\Microsoft\Windows\WindowsCopilot' 'TurnOffWindowsCopilot'
        Reset-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsCopilot' 'TurnOffWindowsCopilot'
        Reset-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsAI' 'DisableAIDataAnalysis'
        Reset-Reg $adv 'ShowCopilotButton'
    }
    Add-UndoIfChecked $chkEdgeDebloat {
        $e = 'HKLM:\SOFTWARE\Policies\Microsoft\Edge'
        foreach ($v in @('PreloadStartPageEnabled','BackgroundModeEnabled','StartupBoostEnabled','HubsSidebarEnabled','ShowRecommendationsEnabled')) { Reset-Reg $e $v }
    }
    Add-UndoIfChecked $chkOneDriveRemove {
        Reset-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\OneDrive' 'DisableFileSyncNGSC'
        $od = "$env:LOCALAPPDATA\Microsoft\OneDrive\OneDrive.exe"
        if (Test-Path -LiteralPath $od) { Start-Process -FilePath $od -ArgumentList '/background' -ErrorAction SilentlyContinue; Write-Log "[OK] OneDrive riavviato." }
    }
    Add-UndoIfChecked $chkOutlookNew {
        Reset-Reg 'HKCU:\Software\Microsoft\Office\16.0\Outlook\Options\General' 'HideNewOutlookToggle'
        Reset-Reg 'HKCU:\Software\Policies\Microsoft\office\16.0\outlook\preferences' 'NewOutlookMigrationUserSetting'
    }

    Add-UndoIfChecked $chkServicesManual { Reset-Svc @('MapsBroker','Fax','XblAuthManager','XblGameSave','XboxNetApiSvc','XboxGipSvc','RetailDemo','WalletService','PhoneSvc') }
    Add-UndoIfChecked $chkDeliveryOpt {
        Reset-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DeliveryOptimization' 'DODownloadMode'
        Reset-Svc @('DoSvc')
    }
    Add-UndoIfChecked $chkBitLocker { Reset-Svc @('BDESVC') }
    Add-UndoIfChecked $chkWPBT { Reset-Reg 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Executive' 'DisableWpbtExecution' }
    Add-UndoIfChecked $chkBackgroundApps {
        Reset-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\BackgroundAccessApplications' 'GlobalUserDisabled'
        Reset-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppPrivacy' 'LetAppsRunInBackground'
    }
    Add-UndoIfChecked $chkTeredo { netsh interface teredo set state default | Out-Null; Write-Log "[OK] Teredo su valore predefinito." }
    Add-UndoIfChecked $chkRDPWarnings { Reset-Reg 'HKCU:\Software\Microsoft\Terminal Server Client' 'AuthenticationLevelOverride' }
    Add-UndoIfChecked $chkRemoteAssistance { Reset-Reg 'HKLM:\SYSTEM\CurrentControlSet\Control\Remote Assistance' 'fAllowToGetHelp' 1 }
    Add-UndoIfChecked $chkCompanionApps { Reset-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\DeviceInstall\Settings' 'DisableDeviceCompanionApp' }
    Add-UndoIfChecked $chkDriverUpdates {
        Reset-Reg 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\DriverSearching' 'SearchOrderConfig' 1
        Reset-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate' 'ExcludeWUDriversInQualityUpdate'
    }

    # ---------- INTERFACCIA ----------
    Add-UndoIfChecked $chkDarkTheme {
        $t = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Themes\Personalize'
        Reset-Reg $t 'AppsUseLightTheme' 1; Reset-Reg $t 'SystemUsesLightTheme' 1
    }
    Add-UndoIfChecked $chkFileExt { Reset-Reg $adv 'HideFileExt' 1 }
    Add-UndoIfChecked $chkHiddenFiles { Reset-Reg $adv 'Hidden' 2 }
    Add-UndoIfChecked $chkLongPaths { Reset-Reg 'HKLM:\SYSTEM\CurrentControlSet\Control\FileSystem' 'LongPathsEnabled' 0 }
    Add-UndoIfChecked $chkClassicMenu {
        $k = 'HKCU:\Software\Classes\CLSID\{86ca1aa0-34aa-4e8b-a509-50c905bae2a2}'
        if (Test-Path -LiteralPath $k) { Remove-Item -LiteralPath $k -Recurse -Force -ErrorAction SilentlyContinue; Write-Log "[OK] Menu contestuale di Windows 11 ripristinato (riavvia Esplora file)." }
        else { Write-Log "[SALTATO] Menu contestuale - gia' predefinito." }
    }
    Add-UndoIfChecked $chkExplorerThisPC { Reset-Reg $adv 'LaunchTo' }
    Add-UndoIfChecked $chkRemove3D {
        foreach ($p in @(
            'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\MyComputer\NameSpace\{0DB7E03F-FC29-4DC6-9020-FF41B59E513A}',
            'HKLM:\SOFTWARE\Wow6432Node\Microsoft\Windows\CurrentVersion\Explorer\MyComputer\NameSpace\{0DB7E03F-FC29-4DC6-9020-FF41B59E513A}')) {
            if (-not (Test-Path -LiteralPath $p)) { New-Item -Path $p -Force -ErrorAction SilentlyContinue | Out-Null }
        }
        Write-Log "[OK] Voce «Oggetti 3D» ripristinata (su Windows 11 resta comunque nascosta)."
    }
    Add-UndoIfChecked $chkRecycleConfirm { Reset-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Policies\Explorer' 'ConfirmFileDelete' }
    Add-UndoIfChecked $chkMenuDelay { Reset-Reg 'HKCU:\Control Panel\Desktop' 'MenuShowDelay' '400' 'String' }

    Add-UndoIfChecked $chkStartMorePins { Reset-Reg $adv 'Start_Layout' }
    Add-UndoIfChecked $chkStartHideRec {
        Reset-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Explorer' 'HideRecommendedSection'
        Reset-Reg $adv 'Start_IrisRecommendations'
    }
    Add-UndoIfChecked $chkStartNoWeb { Reset-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Explorer' 'HideRecommendedPersonalizedSites' }
    Add-UndoIfChecked $chkStartNoAccount { Reset-Reg $adv 'Start_AccountNotifications' }

    Add-UndoIfChecked $chkTaskbarCenter { Reset-Reg $adv 'TaskbarAl' }
    Add-UndoIfChecked $chkTaskbarSearch { Reset-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Search' 'SearchboxTaskbarMode' }
    Add-UndoIfChecked $chkTaskbarTaskView { Reset-Reg $adv 'ShowTaskViewButton' }
    Add-UndoIfChecked $chkTaskbarWidgets {
        Reset-Reg $adv 'TaskbarDa'
        Reset-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Dsh' 'AllowNewsAndInterests'
    }
    Add-UndoIfChecked $chkTaskbarChat { Reset-Reg $adv 'TaskbarMn' }
    Add-UndoIfChecked $chkTaskbarEndTask { Reset-Reg "$adv\TaskbarDeveloperSettings" 'TaskbarEndTask' }
    Add-UndoIfChecked $chkBatteryPct { Reset-Reg $adv 'IsBatteryPercentageEnabled' }
    Add-UndoIfChecked $chkSettingsHome { Reset-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\CurrentVersion\Policies\Explorer' 'SettingsPageVisibility' }
    Add-UndoIfChecked $chkWindowSnapping { Reset-Reg 'HKCU:\Control Panel\Desktop' 'WindowArrangementActive' '1' 'String' }
    Add-UndoIfChecked $chkMouseAccel {
        Reset-Reg 'HKCU:\Control Panel\Mouse' 'MouseSpeed' '1' 'String'
        Reset-Reg 'HKCU:\Control Panel\Mouse' 'MouseThreshold1' '6' 'String'
        Reset-Reg 'HKCU:\Control Panel\Mouse' 'MouseThreshold2' '10' 'String'
    }
    Add-UndoIfChecked $chkNumLock { Reset-Reg 'HKU:\.DEFAULT\Control Panel\Keyboard' 'InitialKeyboardIndicators' '2147483648' 'String' }
    Add-UndoIfChecked $chkStickyKeys { Reset-Reg 'HKCU:\Control Panel\Accessibility\StickyKeys' 'Flags' '510' 'String' }
    Add-UndoIfChecked $chkScrollbars { Reset-Reg 'HKCU:\Control Panel\Accessibility' 'DynamicScrollbars' }
    Add-UndoIfChecked $chkLockScreen { Reset-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\Personalization' 'NoLockScreen' }
    Add-UndoIfChecked $chkLogonBlur { Reset-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\System' 'DisableAcrylicBackgroundOnLogon' }
    Add-UndoIfChecked $chkBSODVerbose { Reset-Reg 'HKLM:\SYSTEM\CurrentControlSet\Control\CrashControl' 'DisplayParameters' }
    Add-UndoIfChecked $chkLogonVerbose { Reset-Reg 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Policies\System' 'verbosestatus' }

    # ---------- RETE ----------
    Add-UndoIfChecked $chkNetPowerSave {
        Get-ChildItem 'HKLM:\SYSTEM\CurrentControlSet\Control\Class\{4D36E972-E325-11CE-BFC1-08002BE10318}' -ErrorAction SilentlyContinue |
            Where-Object { $_.PSChildName -match '^\d{4}$' } |
            ForEach-Object { Remove-ItemProperty -LiteralPath $_.PSPath -Name 'PnPCapabilities' -ErrorAction SilentlyContinue }
        Write-Log "[OK] Risparmio energetico delle schede di rete su valore predefinito."
    }
    Add-UndoIfChecked $chkDisableIPv6 { Reset-Reg 'HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip6\Parameters' 'DisabledComponents' }
    Add-UndoIfChecked $chkApplyNetwork {
        netsh int tcp set global autotuninglevel=normal | Out-Null
        netsh int tcp set global rss=enabled | Out-Null
        netsh int tcp set global rsc=enabled | Out-Null
        netsh int tcp set global ecncapability=default | Out-Null
        netsh int tcp set global timestamps=default | Out-Null
        netsh int tcp set supplemental template=internet congestionprovider=default | Out-Null
        Write-Log "[OK] Parametri netsh TCP su valori predefiniti."
        $tcp = "HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters"
        Reset-Reg $tcp 'DefaultTTL'; Reset-Reg $tcp 'MaxUserPort'; Reset-Reg $tcp 'TcpTimedWaitDelay'
        $sp = "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile"
        Reset-Reg $sp 'NetworkThrottlingIndex' 10
        Reset-Reg $sp 'SystemResponsiveness' 20
        Remove-RegAllInterfaces 'TcpAckFrequency'; Remove-RegAllInterfaces 'TCPNoDelay'; Remove-RegAllInterfaces 'TcpDelAckTicks'
        $pr = "$tcp\ServiceProvider"
        Reset-Reg $pr 'LocalPriority' 499; Reset-Reg $pr 'HostPriority' 500
        Reset-Reg $pr 'DnsPriority' 2000; Reset-Reg $pr 'NetbtPriority' 2001
        Reset-Reg $mm 'LargeSystemCache' 0; Reset-Reg $mm 'Size'
        $ie = "HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings"
        Reset-Reg $ie 'MaxConnectionsPerServer'; Reset-Reg $ie 'MaxConnectionsPer1_0Server'
    }
    Add-UndoIfChecked $chkApplyDns {
        foreach ($adapter in (Get-NetAdapter -ErrorAction SilentlyContinue | Where-Object { $_.Status -eq 'Up' })) {
            Set-DnsClientServerAddress -InterfaceAlias $adapter.Name -ResetServerAddresses -ErrorAction SilentlyContinue
            Write-Log "[OK] DNS automatici (DHCP) su $($adapter.Name)."
        }
    }

    # ---------- SCHEDA VIDEO ----------
    Add-UndoIfChecked $chkNvTelemetry {
        Reset-Svc @('NvTelemetryContainer')
        Enable-Tasks @(
            '\NvTmRep_CrashReport1_{B2FE1952-0186-46C3-BAEC-A80AA35AC5B8}',
            '\NvTmRep_CrashReport2_{B2FE1952-0186-46C3-BAEC-A80AA35AC5B8}',
            '\NvTmRep_CrashReport3_{B2FE1952-0186-46C3-BAEC-A80AA35AC5B8}',
            '\NvTmRep_CrashReport4_{B2FE1952-0186-46C3-BAEC-A80AA35AC5B8}',
            '\NvTmMon_{B2FE1952-0186-46C3-BAEC-A80AA35AC5B8}',
            '\NvTmRepOnLogon_{B2FE1952-0186-46C3-BAEC-A80AA35AC5B8}'
        ) 'Telemetria NVIDIA'
        Reset-Reg 'HKLM:\SOFTWARE\NVIDIA Corporation\NvControlPanel2\Client' 'OptInOrOutPreference'
        foreach ($rid in @('EnableRID44231','EnableRID64640','EnableRID66610')) { Reset-Reg 'HKLM:\SOFTWARE\NVIDIA Corporation\Global\FTS' $rid }
    }
    Add-UndoIfChecked $chkNvGfe {
        Reset-Svc @('NvContainerNetworkService')
        Reset-Reg 'HKLM:\SOFTWARE\NVIDIA Corporation\NvBackend' 'StartOnLogin'
        Enable-Tasks @('\NvNodeLauncher_{B2FE1952-0186-46C3-BAEC-A80AA35AC5B8}') 'GeForce Experience'
        Write-Log "[INFO] L'avvio automatico di GeForce Experience torna reinstallando o aggiornando l'app."
    }
    Add-UndoIfChecked $chkNvPerfMode {
        foreach ($v in @('PowerMizerEnable','PowerMizerLevel','PowerMizerLevelAC','PerfLevelSrc')) { Remove-GpuClassValue $v 'NVIDIA' }
    }
    Add-UndoIfChecked $chkNvUpdates {
        Enable-Tasks @(
            '\NvDriverUpdateCheckDaily_{B2FE1952-0186-46C3-BAEC-A80AA35AC5B8}',
            '\NvProfileUpdaterDaily_{B2FE1952-0186-46C3-BAEC-A80AA35AC5B8}',
            '\NvProfileUpdaterOnLogon_{B2FE1952-0186-46C3-BAEC-A80AA35AC5B8}'
        ) 'Aggiornamenti NVIDIA'
    }
    Add-UndoIfChecked $chkAmdUx {
        Reset-Reg 'HKCU:\Software\AMD\CN' 'UserExperienceProgram'
        Reset-Reg 'HKLM:\SOFTWARE\AMD\CN' 'UserExperienceProgram'
        Enable-Tasks @('\AMD Crash Defender Task') 'AMD Crash Defender'
        Reset-Svc @('AMD Crash Defender Service')
    }
    Add-UndoIfChecked $chkAmdBloat {
        Enable-Tasks @('\StartCN', '\StartDVR', '\AMDInstallLauncher', '\AMDLinkUpdate') 'Avvii automatici AMD'
        Write-Log "[INFO] Le voci di avvio di Radeon Software tornano aprendo l'app una volta."
    }
    Add-UndoIfChecked $chkAmdUlps {
        Set-GpuClassValue 'EnableUlps' 1 'ULPS riattivato' 'AMD'
        Remove-GpuClassValue 'PP_SclkDeepSleepDisable' 'AMD'
    }
    Add-UndoIfChecked $chkNvP2 { Reset-NvProfile 'P2' 'CUDA P2' }
    Add-UndoIfChecked $chkNvDrsPower { Reset-NvProfile 'Power' 'Gestione energia' }
    Add-UndoIfChecked $chkNvLowLatency { Reset-NvProfile 'LowLatency' 'Bassa latenza' }
    Add-UndoIfChecked $chkNvThreaded { Reset-NvProfile 'Threaded' 'Ottimizzazione thread' }
    Add-UndoIfChecked $chkNvTexPerf { Reset-NvProfile 'TexPerf' 'Filtro texture' }
    Add-UndoIfChecked $chkNvAniso { Reset-NvProfile 'Aniso' 'Campioni anisotropici' }
    Add-UndoIfChecked $chkNvShaderCache { Reset-NvProfile 'Shader' 'Cache shader' }
    Add-UndoIfChecked $chkNvNoFxaa { Reset-NvProfile 'NoFxaa' 'FXAA e Ansel' }
    Add-UndoIfChecked $chkNvDisplayPower { Reset-Reg 'HKLM:\SYSTEM\CurrentControlSet\Services\nvlddmkm\Global\NVTweak' 'DisplayPowerSaving' }
    Add-UndoIfChecked $chkNvHdcp { Remove-GpuClassValue 'RMHdcpKeyglobZero' 'NVIDIA' }
    Add-UndoIfChecked $chkNvPreempt { Remove-GpuClassValue 'DisablePreemption' 'NVIDIA'; Remove-GpuClassValue 'DisableCudaContextPreemption' 'NVIDIA' }
    Add-UndoIfChecked $chkNvDynPstate { Remove-GpuClassValue 'DisableDynamicPstate' 'NVIDIA' }
    Add-UndoIfChecked $chkNvLatency { foreach ($k in $script:NvLatencyValues.Keys) { Remove-GpuClassValue $k 'NVIDIA' } }
    Add-UndoIfChecked $chkAmdAntiLag { Remove-GpuClassValue 'KMD_DeLagEnabled' 'AMD' }
    Add-UndoIfChecked $chkAmdShaderCache { Remove-AmdUmdValue 'ShaderCache' 'Cache shader' }
    Add-UndoIfChecked $chkAmdTexPerf { Remove-AmdUmdValue 'TFQ' 'Filtro texture' }
    Add-UndoIfChecked $chkAmdTess { Remove-AmdUmdValue 'Tessellation_OPTION' 'Tassellatura'; Remove-AmdUmdValue 'Tessellation' 'Tassellatura' }
    Add-UndoIfChecked $chkAmdFlipQueue { Remove-AmdUmdValue 'FlipQueueSize' 'Coda dei fotogrammi' }
    Add-UndoIfChecked $chkAmdNoFrtc { Remove-GpuClassValue 'KMD_FRTEnabled' 'AMD' }
    Add-UndoIfChecked $chkAmdStutter { Remove-GpuClassValue 'StutterMode' 'AMD' }
    Add-UndoIfChecked $chkAmdAspm { Remove-GpuClassValue 'EnableAspmL0s' 'AMD'; Remove-GpuClassValue 'EnableAspmL1' 'AMD' }
    Add-UndoIfChecked $chkAmdPowerGating { foreach ($v in 'DisableDrmdmaPowerGating','DisableUVDPowerGatingDynamic','DisableVCEPowerGating') { Remove-GpuClassValue $v 'AMD' } }
    Add-UndoIfChecked $chkAmdDma { Remove-GpuClassValue 'DisableDMACopy' 'AMD'; Remove-GpuClassValue 'DisableBlockWrite' 'AMD' }
    Add-UndoIfChecked $chkAmdPreempt { Remove-GpuClassValue 'KMD_EnableComputePreemption' 'AMD' }
    Add-UndoIfChecked $chkIntelBloat { Reset-Svc @('igfxCUIService2.0.0.0','IntelAudioService','Intel(R) TPM Provisioning Service') }
    Add-UndoIfChecked $chkGpuTdr {
        Reset-Reg 'HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers' 'TdrDelay'
        Reset-Reg 'HKLM:\SYSTEM\CurrentControlSet\Control\GraphicsDrivers' 'TdrDdiDelay'
    }
    Add-NoUndo $chkGpuMsi 'il valore originale lo scrive il driver: reinstallalo per tornare alla sua impostazione.'

    # ---------- ARCHIVIAZIONE ----------
    Add-UndoIfChecked $chkStorageSense { Reset-Reg 'HKCU:\Software\Microsoft\Windows\CurrentVersion\StorageSense\Parameters\StoragePolicy' '01' }
    Add-UndoIfChecked $chkReservedStorage {
        Dism.exe /Online /Set-ReservedStorageState /State:Enabled | Out-Null
        Write-Log "[OK] Spazio riservato riattivato."
    }
    Add-NoUndo $chkStorageProfile 'TRIM e deframmentazione non hanno uno stato da ripristinare.'
    Add-NoUndo $chkDiskCleanup 'i file eliminati non si recuperano.'
    Add-NoUndo $chkTempCleanup 'i file eliminati non si recuperano.'
    Add-UndoIfChecked $chkSmartChkdsk {
        chkntfs /d | Out-Null
        Write-Log "[OK] Controllo del disco pianificato annullato."
    }

    # ---------- AVANZATE ----------
    Add-UndoIfChecked $chkSvcSysMain { Reset-Svc @('SysMain') }
    Add-UndoIfChecked $chkSvcDiag { Reset-Svc @('DPS','WdiServiceHost','WdiSystemHost','diagnosticshub.standardcollector.service','diagsvc','DusmSvc') }
    Add-UndoIfChecked $chkSvcErrors {
        Reset-Svc @('WerSvc')
        Reset-Reg 'HKLM:\SOFTWARE\Microsoft\Windows\Windows Error Reporting' 'Disabled'
    }
    Add-UndoIfChecked $chkSvcPca { Reset-Svc @('PcaSvc') }
    Add-UndoIfChecked $chkSvcDiscovery { Reset-Svc @('SSDPSRV','upnphost','fdPHost','FDResPub','lltdsvc','Browser','NetTcpPortSharing') }
    Add-UndoIfChecked $chkSvcSensors { Reset-Svc @('SensorService','SensrSvc','SensorDataService','lfsvc') }
    Add-UndoIfChecked $chkSvcSmartCard { Reset-Svc @('SCardSvr','ScDeviceEnum','SCPolicySvc') }
    Add-UndoIfChecked $chkSvcParental { Reset-Svc @('WpcMonSvc','wisvc') }
    Add-UndoIfChecked $chkSvcHyperV { Reset-Svc @('HvHost','vmickvpexchange','vmicguestinterface','vmicshutdown','vmicheartbeat','vmicvmsession','vmicrdv','vmictimesync','vmcompute','vmms') }
    Add-UndoIfChecked $chkSvcPrint { Reset-Svc @('Spooler','PrintNotify','PrintWorkflowUserSvc') }
    Add-UndoIfChecked $chkSvcSearch { Reset-Svc @('WSearch') }
    Add-UndoIfChecked $chkSvcRemote { Reset-Svc @('RemoteRegistry','RemoteAccess','SessionEnv','TermService','UmRdpService','RasMan','RasAuto') }
    Add-UndoIfChecked $chkSvcBiometric { Reset-Svc @('WbioSrvc') }
    Add-UndoIfChecked $chkSvcTouch { Reset-Svc @('TabletInputService','TextInputManagementService') }

    Add-UndoIfChecked $chkTaskExtra {
        Enable-Tasks @(
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
    Add-UndoIfChecked $chkTaskMaint {
        Reset-Reg 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Schedule\Maintenance' 'MaintenanceDisabled'
        Enable-Tasks @('\Microsoft\Windows\TaskScheduler\Idle Maintenance',
                       '\Microsoft\Windows\TaskScheduler\Regular Maintenance',
                       '\Microsoft\Windows\TaskScheduler\Maintenance Configurator') 'Attivita di manutenzione'
    }
    Add-UndoIfChecked $chkTaskDefrag { Enable-Tasks @('\Microsoft\Windows\Defrag\ScheduledDefrag') 'Ottimizzazione unita pianificata' }

    Add-UndoIfChecked $chkPrefetch {
        $pf = "$mm\PrefetchParameters"
        Reset-Reg $pf 'EnablePrefetcher' 3; Reset-Reg $pf 'EnableSuperfetch' 3
    }
    Add-UndoIfChecked $chkFth { Reset-Reg 'HKLM:\SOFTWARE\Microsoft\FTH' 'Enabled' 1 }
    Add-UndoIfChecked $chkAppCompat {
        $a = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\AppCompat'
        foreach ($v in @('DisablePCA','DisableUAR','DisableInventory','DisableEngine','AITEnable')) { Reset-Reg $a $v }
    }
    Add-UndoIfChecked $chkSvcHostSplit { Reset-Reg 'HKLM:\SYSTEM\CurrentControlSet\Control' 'SvcHostSplitThresholdInKB' 3670016 }
    Add-UndoIfChecked $chkMemCompression {
        try { Enable-MMAgent -MemoryCompression -ErrorAction Stop; Write-Log "[OK] Compressione della memoria riattivata." }
        catch { Write-Log "[ERRORE] Compressione della memoria: $($_.Exception.Message)" }
    }

    Add-UndoIfChecked $chkWuNoReboot {
        $au = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate\AU'
        foreach ($v in @('NoAutoRebootWithLoggedOnUsers','AUOptions','AUPowerManagement')) { Reset-Reg $au $v }
    }
    Add-UndoIfChecked $chkWuDefer {
        $wu = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\WindowsUpdate'
        foreach ($v in @('DeferFeatureUpdates','DeferFeatureUpdatesPeriodInDays','DeferQualityUpdates','DeferQualityUpdatesPeriodInDays')) { Reset-Reg $wu $v }
    }
    Add-UndoIfChecked $chkWuNoStore { Reset-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\WindowsStore' 'AutoDownload' }

    Add-UndoIfChecked $chkBootQuiet {
        Reset-Bcd '/deletevalue {current} quietboot' 'Logo di avvio'
        Reset-Bcd '/deletevalue {current} bootlog' 'Registro di avvio'
    }
    Add-UndoIfChecked $chkBootMenu { Reset-Bcd '/deletevalue {current} bootmenupolicy' 'Menu di avvio' }
    Add-UndoIfChecked $chkBootTimeout { Reset-Bcd '/timeout 30' 'Attesa del menu di avvio: 30 secondi' }
    Add-UndoIfChecked $chkBootDynTick { Reset-Bcd '/deletevalue disabledynamictick' 'Tick dinamico del kernel' }
    Add-UndoIfChecked $chkBootTsc { Reset-Bcd '/deletevalue tscsyncpolicy' 'Sincronizzazione TSC' }

    Add-NoUndo $chkAppxBloat 'le app rimosse si reinstallano dal Microsoft Store.'
    Add-NoUndo $chkAppxXbox 'le app rimosse si reinstallano dal Microsoft Store.'
    Add-NoUndo $chkAppxProvision 'le app rimosse si reinstallano dal Microsoft Store.'

    Add-UndoIfChecked $chkSecSmartScreen {
        Reset-Reg 'HKLM:\SOFTWARE\Policies\Microsoft\Windows\System' 'EnableSmartScreen'
        Reset-Reg 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer' 'SmartScreenEnabled'
        Reset-Reg 'HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\AppHost' 'EnableWebContentEvaluation'
    }
    Add-UndoIfChecked $chkSecSpectre {
        Reset-Reg $mm 'FeatureSettingsOverride'; Reset-Reg $mm 'FeatureSettingsOverrideMask'
    }
    Add-UndoIfChecked $chkSecDefenderIdle {
        $s = 'HKLM:\SOFTWARE\Policies\Microsoft\Windows Defender\Scan'
        foreach ($v in @('ScanOnlyIfIdle','AvgCPULoadFactor','DisableScanningNetworkFiles')) { Reset-Reg $s $v }
        Enable-Tasks @('\Microsoft\Windows\Windows Defender\Windows Defender Scheduled Scan',
                       '\Microsoft\Windows\Windows Defender\Windows Defender Cache Maintenance') 'Scansioni pianificate di Defender'
    }
}

# Esegue la coda di azioni con avanzamento e riepilogo. La usano sia
# «Applica modifiche» sia «Annulla selezionate».
function Invoke-ActionQueue {
    param([string]$Header)
    $total = $script:Actions.Count
    $script:Running = $true
    $btnRun.IsEnabled = $false; $btnUndo.IsEnabled = $false
    $script:OkCount = 0; $script:WarnCount = 0; $script:SkipCount = 0
    $txtProgressLabel.Foreground = New-Object System.Windows.Media.SolidColorBrush ([System.Windows.Media.ColorConverter]::ConvertFromString('#FFF2F2F5'))
    Update-Progress 0 $total (T 'starting')
    Write-Log "======================================================="
    Write-Log "[AVVIO] $Header - $total operazioni in coda."

    $i = 0
    foreach ($action in $script:Actions) {
        $i++
        Update-Progress $i $total $action.Name
        Write-Log "[$i/$total] $($action.Name)"
        try { & $action.Do } catch { Write-Log "[ERRORE] $($action.Name): $($_.Exception.Message)" }
    }

    Update-Progress $total $total (T 'done')
    Show-RunSummary
    Write-Log "======================================================="
    Write-Log "[$(T 'summary')] OK: $script:OkCount | Saltati: $script:SkipCount | Avvisi ed errori: $script:WarnCount"


    $script:Running = $false
    Show-StorageInventory
    Update-PowerPlanLabel
    Update-ApplyButton
}

$btnUndo.Add_Click({
    Build-UndoActions
    $total = $script:Actions.Count
    if ($total -eq 0) {
        Write-Log "[AVVISO] $(T 'nothing')"
        return
    }
    if (-not (Show-Dialog (T 'confirmTitle') (T 'undoAsk') 'ask' ((T 'selCount') -f $total))) { return }
    Invoke-ActionQueue "Tweak Andrew v6.0 - ANNULLA"
})
