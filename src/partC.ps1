
# ------------------------------------------------------------------------------
# 2. CARICAMENTO DELLA FINESTRA
# ------------------------------------------------------------------------------
$script:StartupLog = Join-Path $env:TEMP "TweakAndrew_startup.log"
try { "$(Get-Date -Format s) - Tweak Andrew v6.0 avvio" | Set-Content -LiteralPath $script:StartupLog -Encoding UTF8 } catch {}

try {
    $reader = (New-Object System.Xml.XmlNodeReader $xaml)
    $window = [Windows.Markup.XamlReader]::Load($reader)
} catch {
    [System.Windows.MessageBox]::Show(
        "Impossibile avviare l'interfaccia di Tweak Andrew.`n`nErrore XAML: $($_.Exception.Message)",
        "Tweak Andrew v6.0 - Errore di avvio",
        [System.Windows.MessageBoxButton]::OK,
        [System.Windows.MessageBoxImage]::Error
    ) | Out-Null
    throw
}

# Unita' del registro usate da alcuni tweak (HKCR e HKU non esistono di default).
try { if (-not (Get-PSDrive -Name HKCR -ErrorAction SilentlyContinue)) { New-PSDrive -Name HKCR -PSProvider Registry -Root HKEY_CLASSES_ROOT | Out-Null } } catch {}
try { if (-not (Get-PSDrive -Name HKU  -ErrorAction SilentlyContinue)) { New-PSDrive -Name HKU  -PSProvider Registry -Root HKEY_USERS | Out-Null } } catch {}

# Scorciatoia: recupera un controllo per nome.
function E($name) { return $window.FindName($name) }

# ------------------------------------------------------------------------------
# 3. TESTI DELL'INTERFACCIA — italiano e inglese
# ------------------------------------------------------------------------------
# Chiave = x:Name del controllo. Il tipo del controllo decide quale proprieta'
# viene scritta: Text per i TextBlock, Header per le schede, Content per il resto.
$script:Loc = @{
    lblSubtitle        = @{ it = "Ottimizzazione e controllo di Windows — PcFixPro Italia"; en = "Windows optimization and control — PcFixPro Italia" }

    tabPerf            = @{ it = "Prestazioni";   en = "Performance" }
    tabPrivacy         = @{ it = "Privacy";       en = "Privacy" }
    tabUi              = @{ it = "Interfaccia";   en = "Interface" }
    tabNet             = @{ it = "Rete";          en = "Network" }
    tabStorage         = @{ it = "Archiviazione"; en = "Storage" }

    ttlLatency         = @{ it = "LATENZA E SCHEDULING"; en = "LATENCY AND SCHEDULING" }
    chkMMCSS           = @{ it = "MMCSS — reattività per giochi e audio"; en = "MMCSS — gaming and audio responsiveness" }
    chkPriority        = @{ it = "Scheduling CPU — priorità al primo piano (0x26)"; en = "CPU scheduling — foreground priority (0x26)" }
    chkKernelMem       = @{ it = "Memoria kernel — niente paging dell'executive"; en = "Kernel memory — disable executive paging" }
    chkKernelDpc       = @{ it = "Kernel e latenza DPC"; en = "Kernel and DPC latency" }
    chkTimer           = @{ it = "Timer di sistema — massima precisione"; en = "System timer — precision policy" }
    chkPowerThrottling = @{ it = "Power Throttling — disattiva"; en = "Power throttling — disable" }
    chkUSBSuspend      = @{ it = "Sospensione selettiva USB — disattiva"; en = "USB selective suspend — disable" }
    chkNtfsPerf        = @{ it = "NTFS — niente data ultimo accesso, cache ampia"; en = "NTFS — disable last access time, large cache" }

    ttlRam             = @{ it = "MEMORIA"; en = "MEMORY" }
    chkRamTweak        = @{ it = "Soglia di divisione SvcHost (in base alla RAM)"; en = "SvcHost split threshold (based on RAM)" }
    lblRamInstalled    = @{ it = "RAM installata:"; en = "Installed RAM:" }
    lblRamHint         = @{ it = "Rilevata automaticamente all'avvio; modificabile a mano."; en = "Detected automatically at startup; can be changed manually." }

    ttlGraphics        = @{ it = "GRAFICA E GIOCHI"; en = "GRAPHICS AND GAMING" }
    chkGameMode        = @{ it = "Modalità gioco — attiva"; en = "Game Mode — enable" }
    chkFSO             = @{ it = "Ottimizzazioni schermo intero (FSO) — disattiva"; en = "Fullscreen optimizations (FSO) — disable" }
    chkGameDVR         = @{ it = "Game DVR e registrazione Xbox — disattiva"; en = "Game DVR and Xbox recording — disable" }
    chkHAGS            = @{ it = "Pianificazione GPU accelerata via hardware — attiva"; en = "Hardware-accelerated GPU scheduling — enable" }
    chkVisualFX        = @{ it = "Effetti visivi — regola per prestazioni migliori"; en = "Visual effects — adjust for best performance" }
    chkApplyMPO        = @{ it = "Applica impostazione Multiplane Overlay (MPO)"; en = "Apply Multiplane Overlay (MPO) setting" }
    mpoOn              = @{ it = "Attivo (predefinito Windows)"; en = "Enabled (Windows default)" }
    mpoOff             = @{ it = "Disattivo (risolve stutter e sfarfallio)"; en = "Disabled (fixes stutter and flicker)" }
    mpoCompat          = @{ it = "Attivo compatibile (2 piani)"; en = "Enabled, compatible (2 planes)" }

    ttlRisky           = @{ it = "AVANZATE — RIDUCONO LA SICUREZZA"; en = "ADVANCED — THESE REDUCE SECURITY" }
    lblRiskyHint       = @{ it = "Escluse da «Seleziona tutto». Attivale solo se sai cosa comportano."; en = "Excluded from «Select all». Enable only if you know the consequences." }
    chkVBS             = @{ it = "VBS / Integrità della memoria — disattiva"; en = "VBS / Memory integrity — disable" }
    chkMitigations     = @{ it = "Mitigazioni exploit di sistema — disattiva"; en = "System exploit mitigations — disable" }

    tabPower           = @{ it = "Alimentazione"; en = "Power" }
    tabGpu             = @{ it = "Scheda video";  en = "Graphics" }

    ttlPlans           = @{ it = "PIANI DI ALIMENTAZIONE"; en = "POWER PLANS" }
    btnRefreshPlans    = @{ it = "Aggiorna"; en = "Refresh" }
    btnRemoveTestPlans = @{ it = "Rimuovi piani di prova"; en = "Remove test plans" }
    ttlSleep           = @{ it = "RISPARMIO E SOSPENSIONE"; en = "SLEEP AND SAVING" }
    lblSleepHint       = @{ it = "Si applicano con il pulsante Applica."; en = "These are applied with the Apply button." }
    ttlPlanWarn        = @{ it = "PRIMA DI PROVARE"; en = "BEFORE YOU TRY" }
    lblPlanWarn        = @{ it = "I piani della sezione «Da testare» arrivano da terze parti. Provane uno alla volta e torna su Bilanciato se il computer diventa instabile."; en = "The plans under «To test» come from third parties. Try one at a time and go back to Balanced if the computer becomes unstable." }

    ttlGpuDetected     = @{ it = "SCHEDA RILEVATA"; en = "DETECTED CARD" }
    btnDetectGpu       = @{ it = "Aggiorna"; en = "Refresh" }
    lblGpuHint         = @{ it = "Qui si alleggerisce il driver già installato: telemetria, servizi accessori e avvii automatici."; en = "This trims the driver already installed: telemetry, extra services and auto-start entries." }
    ttlGpuCommon       = @{ it = "IMPOSTAZIONI COMUNI"; en = "COMMON SETTINGS" }
    chkGpuTdr          = @{ it = "TDR — allunga il timeout del driver a 10 s"; en = "TDR — raise the driver timeout to 10 s" }
    chkGpuMsi          = @{ it = "Interrupt MSI per la scheda video — attiva"; en = "MSI interrupts for the graphics card — enable" }
    ttlNvidia          = @{ it = "NVIDIA"; en = "NVIDIA" }
    lblNvidiaHint      = @{ it = "Voci ignorate se la scheda non è NVIDIA."; en = "Skipped if the card is not NVIDIA." }
    chkNvTelemetry     = @{ it = "Telemetria NVIDIA — disattiva"; en = "NVIDIA telemetry — disable" }
    chkNvGfe           = @{ it = "GeForce Experience in background — disattiva"; en = "GeForce Experience in background — disable" }
    chkNvPerfMode      = @{ it = "Gestione energia GPU — prestazioni massime"; en = "GPU power management — maximum performance" }
    chkNvUpdates       = @{ it = "Controllo aggiornamenti driver NVIDIA — disattiva"; en = "NVIDIA driver update check — disable" }
    ttlAmd             = @{ it = "AMD RADEON"; en = "AMD RADEON" }
    lblAmdHint         = @{ it = "Voci ignorate se la scheda non è AMD."; en = "Skipped if the card is not AMD." }
    chkAmdUx           = @{ it = "Programma esperienza utente AMD — disattiva"; en = "AMD User Experience Program — disable" }
    chkAmdBloat        = @{ it = "Servizi e avvii automatici AMD — disattiva"; en = "AMD services and auto-start entries — disable" }
    ttlIntelGpu        = @{ it = "INTEL GRAPHICS"; en = "INTEL GRAPHICS" }
    chkIntelBloat      = @{ it = "Servizi accessori Intel Graphics — disattiva"; en = "Intel Graphics extra services — disable" }

    lblUiScale         = @{ it = "Scala interfaccia"; en = "Interface scale" }
    ttlShader          = @{ it = "CACHE SHADER"; en = "SHADER CACHE" }
    lblShaderHint      = @{ it = "Gli shader già compilati dai giochi. Svuotarla libera spazio e risolve gli artefatti dopo un cambio driver. Il primo avvio di ogni gioco sarà più lento, poi torna normale."; en = "Shaders already compiled by games. Clearing frees space and fixes artifacts after a driver change. The first launch of each game will be slower, then back to normal." }
    btnShaderScan      = @{ it = "Calcola spazio occupato"; en = "Measure used space" }
    btnShaderClear     = @{ it = "Svuota cache shader"; en = "Clear shader cache" }

    ttlStart           = @{ it = "MENU START"; en = "START MENU" }
    chkStartMorePins   = @{ it = "Piu spazio ai collegamenti, meno ai consigli"; en = "More room for pins, less for recommendations" }
    chkStartHideRec    = @{ it = "Sezione «Consigliati» — nascondi"; en = "«Recommended» section — hide" }
    chkStartNoWeb      = @{ it = "Siti consigliati nel menu Start — togli"; en = "Recommended websites in Start — remove" }
    chkStartNoAccount  = @{ it = "Notifiche dell'account nel menu Start — togli"; en = "Account notifications in Start — remove" }

    ttlFeat            = @{ it = "FUNZIONI NASCOSTE"; en = "HIDDEN FEATURES" }
    lblFeatHint        = @{ it = "Attiva o disattiva una funzione di Windows tramite il suo numero identificativo, come fa ViVeTool. I numeri cambiano a ogni build: prendili da una fonte aggiornata per la tua."; en = "Turn a Windows feature on or off by its numeric id, the same way ViVeTool does. The ids change with every build: take them from a source that matches yours." }
    featOn             = @{ it = "Attiva"; en = "Enable" }
    featOff            = @{ it = "Disattiva"; en = "Disable" }
    featReset          = @{ it = "Torna al predefinito"; en = "Back to default" }
    lblFeatId          = @{ it = "Numero della funzione"; en = "Feature id" }
    btnFeatApply       = @{ it = "Applica"; en = "Apply" }
    btnFeatList        = @{ it = "Elenca le modifiche attive"; en = "List active changes" }

    chkFastStartup     = @{ it = "Avvio rapido — disattiva"; en = "Fast startup — disable" }
    chkHibernation     = @{ it = "Ibernazione — disattiva (libera spazio su C:)"; en = "Hibernation — disable (frees space on C:)" }
    chkS0Sleep         = @{ it = "Connessione di rete in standby moderno — disattiva"; en = "Network connectivity in modern standby — disable" }
    chkS3Sleep         = @{ it = "Sospensione classica S3 — forza"; en = "Classic S3 sleep — force" }

    ttlTelemetry       = @{ it = "TELEMETRIA E TRACCIAMENTO"; en = "TELEMETRY AND TRACKING" }
    chkTelemetry       = @{ it = "Telemetria e DiagTrack — disattiva"; en = "Telemetry and DiagTrack — disable" }
    chkTelemetryTasks  = @{ it = "Attività pianificate di telemetria — disattiva"; en = "Telemetry scheduled tasks — disable" }
    chkActivityHistory = @{ it = "Cronologia attività — disattiva"; en = "Activity history — disable" }
    chkLocationTracking= @{ it = "Tracciamento posizione — disattiva"; en = "Location tracking — disable" }
    chkAdvertisingID   = @{ it = "ID pubblicità — disattiva"; en = "Advertising ID — disable" }
    chkTailoredExp     = @{ it = "Esperienze personalizzate — disattiva"; en = "Tailored experiences — disable" }
    chkFeedback        = @{ it = "Richieste di feedback — disattiva"; en = "Feedback requests — disable" }
    chkErrorReporting  = @{ it = "Segnalazione errori Windows — disattiva"; en = "Windows error reporting — disable" }
    chkInkingTyping    = @{ it = "Personalizzazione input penna e digitazione — disattiva"; en = "Inking and typing personalization — disable" }
    chkWiFiSense       = @{ it = "Wi-Fi Sense — disattiva"; en = "Wi-Fi Sense — disable" }

    ttlContent         = @{ it = "SUGGERIMENTI E CONTENUTI"; en = "SUGGESTIONS AND CONTENT" }
    chkConsumerFeatures= @{ it = "App suggerite e installazioni automatiche — blocca"; en = "Suggested apps and auto-install — block" }
    chkStoreSearch     = @{ it = "Suggerimenti di ricerca Microsoft Store — disattiva"; en = "Microsoft Store search suggestions — disable" }
    chkSuggestedContent= @{ it = "Contenuti suggeriti nelle Impostazioni — disattiva"; en = "Suggested content in Settings — disable" }
    chkLockScreenAds   = @{ it = "Spotlight e annunci nella schermata di blocco — disattiva"; en = "Lock screen Spotlight and ads — disable" }
    chkStartBing       = @{ it = "Ricerca Bing nel menu Start — disattiva"; en = "Bing search in Start menu — disable" }
    chkStartRecs       = @{ it = "Suggerimenti del menu Start — disattiva"; en = "Start menu recommendations — disable" }
    chkStartTracking   = @{ it = "App più usate e documenti recenti — non tracciare"; en = "Most used apps and recent documents — stop tracking" }
    chkFolderDiscovery = @{ it = "Rilevamento tipo cartella in Esplora file — disattiva"; en = "File Explorer folder type discovery — disable" }

    ttlMsApps          = @{ it = "APP MICROSOFT"; en = "MICROSOFT APPS" }
    chkWindowsAI       = @{ it = "Copilot, Recall e Windows AI — disattiva"; en = "Copilot, Recall and Windows AI — disable" }
    chkEdgeDebloat     = @{ it = "Microsoft Edge — alleggerisci"; en = "Microsoft Edge — debloat" }
    chkOneDriveRemove  = @{ it = "OneDrive — disattiva sincronizzazione"; en = "OneDrive — disable sync" }
    chkOutlookNew      = @{ it = "Passaggio automatico al nuovo Outlook — blocca"; en = "Automatic switch to new Outlook — block" }

    ttlServices        = @{ it = "SERVIZI E COMPONENTI"; en = "SERVICES AND COMPONENTS" }
    chkServicesManual  = @{ it = "Servizi non essenziali — imposta su Manuale"; en = "Non-essential services — set to Manual" }
    chkDeliveryOpt     = @{ it = "Ottimizzazione recapito — disattiva"; en = "Delivery Optimization — disable" }
    chkBitLocker       = @{ it = "Crittografia automatica BitLocker — disattiva"; en = "BitLocker automatic encryption — disable" }
    chkWPBT            = @{ it = "Tabella binaria OEM (WPBT) — disattiva"; en = "OEM binary table (WPBT) — disable" }
    chkBackgroundApps  = @{ it = "App in background — disattiva"; en = "Background apps — disable" }
    chkTeredo          = @{ it = "Tunneling Teredo — disattiva"; en = "Teredo tunneling — disable" }
    chkRDPWarnings     = @{ it = "Avvisi RDP su file non firmati — disattiva"; en = "RDP unsigned file warnings — disable" }
    chkRemoteAssistance= @{ it = "Assistenza remota — disattiva"; en = "Remote Assistance — disable" }
    chkCompanionApps   = @{ it = "App companion dei dispositivi — blocca"; en = "Device companion apps — block" }
    chkDriverUpdates   = @{ it = "Driver da Windows Update — blocca"; en = "Drivers from Windows Update — block" }

    ttlSystemUi        = @{ it = "SISTEMA ED ESPLORA FILE"; en = "SYSTEM AND FILE EXPLORER" }
    chkDarkTheme       = @{ it = "Tema scuro di Windows — attiva"; en = "Windows dark theme — enable" }
    chkFileExt         = @{ it = "Mostra estensioni dei file"; en = "Show file extensions" }
    chkHiddenFiles     = @{ it = "Mostra file nascosti"; en = "Show hidden files" }
    chkLongPaths       = @{ it = "Percorsi lunghi oltre 260 caratteri — attiva"; en = "Long paths over 260 characters — enable" }
    chkClassicMenu     = @{ it = "Menu contestuale classico (Windows 11)"; en = "Classic context menu (Windows 11)" }
    chkExplorerThisPC  = @{ it = "Esplora file si apre su «Questo PC»"; en = "File Explorer opens to «This PC»" }
    chkRemove3D        = @{ it = "Rimuovi «Oggetti 3D» da Questo PC"; en = "Remove «3D Objects» from This PC" }
    chkRecycleConfirm  = @{ it = "Chiedi conferma prima di eliminare"; en = "Ask for confirmation before deleting" }
    chkMenuDelay       = @{ it = "Ritardo di apertura dei menu — azzera"; en = "Menu show delay — set to zero" }

    ttlTaskbar         = @{ it = "BARRA APPLICAZIONI E START"; en = "TASKBAR AND START" }
    chkTaskbarCenter   = @{ it = "Icone al centro della barra"; en = "Centered taskbar icons" }
    chkTaskbarSearch   = @{ it = "Icona Cerca — nascondi"; en = "Search icon — hide" }
    chkTaskbarTaskView = @{ it = "Icona Visualizzazione attività — nascondi"; en = "Task View icon — hide" }
    chkTaskbarWidgets  = @{ it = "Widget e Notizie — nascondi"; en = "Widgets and News — hide" }
    chkTaskbarChat     = @{ it = "Icona Chat / Teams — nascondi"; en = "Chat / Teams icon — hide" }
    chkTaskbarEndTask  = @{ it = "«Termina attività» nel menu della barra — attiva"; en = "«End task» in taskbar menu — enable" }
    chkBatteryPct      = @{ it = "Percentuale batteria nell'area di notifica"; en = "Battery percentage in the system tray" }
    chkSettingsHome    = @{ it = "Pagina iniziale delle Impostazioni — nascondi"; en = "Settings home page — hide" }
    chkWindowSnapping  = @{ it = "Affiancamento finestre — attiva"; en = "Window snapping — enable" }

    ttlInput           = @{ it = "INPUT E ACCESSIBILITÀ"; en = "INPUT AND ACCESSIBILITY" }
    chkMouseAccel      = @{ it = "Accelerazione del mouse — disattiva"; en = "Mouse acceleration — disable" }
    chkNumLock         = @{ it = "Bloc Num all'avvio — attiva"; en = "Num Lock on startup — enable" }
    chkStickyKeys      = @{ it = "Richiesta Tasti permanenti — disattiva"; en = "Sticky Keys prompt — disable" }
    chkScrollbars      = @{ it = "Barre di scorrimento sempre visibili"; en = "Always visible scrollbars" }

    ttlLock            = @{ it = "ACCESSO E DIAGNOSTICA"; en = "SIGN-IN AND DIAGNOSTICS" }
    chkLockScreen      = @{ it = "Schermata di blocco — disattiva"; en = "Lock screen — disable" }
    chkLogonBlur       = @{ it = "Sfocatura acrilica all'accesso — disattiva"; en = "Sign-in acrylic blur — disable" }
    chkBSODVerbose     = @{ it = "Schermata blu dettagliata"; en = "Verbose blue screen" }
    chkLogonVerbose    = @{ it = "Messaggi dettagliati all'accesso"; en = "Verbose sign-in messages" }

    chkApplyNetwork    = @{ it = "Applica le impostazioni di rete al clic su «Applica»"; en = "Apply network settings when «Apply» is clicked" }
    lblNetHint         = @{ it = "Senza questa spunta la scheda Rete resta solo informativa e nulla viene modificato."; en = "Without this box the Network tab stays informational and nothing is changed." }
    btnFlushDns        = @{ it = "Svuota cache DNS"; en = "Flush DNS cache" }

    ttlTcpProfile      = @{ it = "PROFILO TCP"; en = "TCP PROFILE" }
    radTcpOptimal      = @{ it = "Ottimale (gioco)"; en = "Optimal (gaming)" }
    radTcpDefault      = @{ it = "Predefinito Windows"; en = "Windows default" }
    radTcpCurrent      = @{ it = "Profilo attuale"; en = "Current profile" }
    radTcpCustom       = @{ it = "Personalizzato"; en = "Custom" }
    ttlTcpIp           = @{ it = "TCP / IP"; en = "TCP / IP" }
    lblAutoTuning      = @{ it = "Auto-Tuning finestra TCP:"; en = "TCP window auto-tuning:" }
    lblHeuristics      = @{ it = "Euristiche di scaling:"; en = "Scaling heuristics:" }
    lblCongestion      = @{ it = "Controllo congestione:"; en = "Congestion control provider:" }
    lblRss             = @{ it = "Receive-Side Scaling (RSS):"; en = "Receive-Side Scaling (RSS):" }
    lblRsc             = @{ it = "Receive Segment Coalescing (RSC):"; en = "Receive Segment Coalescing (RSC):" }
    lblTtl             = @{ it = "Time To Live (TTL):"; en = "Time To Live (TTL):" }
    lblEcn             = @{ it = "Funzionalità ECN:"; en = "ECN capability:" }
    lblTimestamps      = @{ it = "Timestamp TCP (RFC 1323):"; en = "TCP timestamps (RFC 1323):" }

    ttlDns             = @{ it = "DNS"; en = "DNS" }
    chkApplyDns        = @{ it = "Cambia i server DNS delle schede attive"; en = "Change DNS servers on active adapters" }
    dnsAuto            = @{ it = "Automatico dal router (DHCP)"; en = "Automatic from router (DHCP)" }
    ttlNetAdv          = @{ it = "RETE AVANZATA"; en = "ADVANCED NETWORK" }
    lblThrottling      = @{ it = "Network Throttling Index:"; en = "Network throttling index:" }
    lblResponsiveness  = @{ it = "System Responsiveness:"; en = "System responsiveness:" }
    lblNagle           = @{ it = "Algoritmo di Nagle:"; en = "Nagle's algorithm:" }
    lblHostPriority    = @{ it = "Priorità risoluzione host:"; en = "Host resolution priority:" }
    lblNetMem          = @{ it = "LargeSystemCache / Size:"; en = "LargeSystemCache / Size:" }
    lblPortAlloc       = @{ it = "Porte dinamiche:"; en = "Dynamic port allocation:" }
    lblMaxConn         = @{ it = "Connessioni massime per server:"; en = "Max connections per server:" }
    chkNetPowerSave    = @{ it = "Risparmio energetico delle schede di rete — disattiva"; en = "Network adapter power saving — disable" }
    chkDisableIPv6     = @{ it = "IPv6 — disattiva (solo se il provider non lo usa)"; en = "IPv6 — disable (only if your ISP does not use it)" }

    ttlDrives          = @{ it = "UNITÀ RILEVATE"; en = "DETECTED DRIVES" }
    lblDrivesHint      = @{ it = "Dischi installati e spazio libero di ogni volume."; en = "Installed drives and free space on each volume." }
    btnDetectStorage   = @{ it = "Aggiorna"; en = "Refresh" }
    ttlProfile         = @{ it = "PROFILO DA APPLICARE"; en = "PROFILE TO APPLY" }
    lblProfileHint     = @{ it = "SSD: esegue TRIM e lascia il disco senza deframmentazione. HDD: mantiene Prefetch e SysMain e avvia l'ottimizzazione."; en = "SSD: runs TRIM and never defragments. HDD: keeps Prefetch and SysMain and starts optimization." }
    radStorageSSD      = @{ it = "SSD / NVMe"; en = "SSD / NVMe" }
    radStorageHDD      = @{ it = "HDD meccanico"; en = "Mechanical HDD" }
    chkStorageProfile  = @{ it = "Profilo del disco"; en = "Disk profile" }

    ttlNow             = @{ it = "AZIONI IMMEDIATE"; en = "IMMEDIATE ACTIONS" }
    lblNowHint         = @{ it = "Partono subito al clic, senza passare da «Applica»."; en = "These run right away, without going through «Apply»." }
    btnTrimNow         = @{ it = "Esegui TRIM ora"; en = "Run TRIM now" }
    btnOptimizeNow     = @{ it = "Ottimizza / deframmenta C:"; en = "Optimize / defragment C:" }
    btnEmptyRecycle    = @{ it = "Svuota il Cestino"; en = "Empty the Recycle Bin" }
    btnCleanUpdates    = @{ it = "Elimina cache di Windows Update"; en = "Delete Windows Update cache" }

    ttlMaintenance     = @{ it = "MANUTENZIONE ALL'APPLICAZIONE"; en = "MAINTENANCE ON APPLY" }
    chkDiskCleanup     = @{ it = "Pulizia Disco e compattazione WinSxS (DISM)"; en = "Disk Cleanup and WinSxS compaction (DISM)" }
    chkTempCleanup     = @{ it = "Elimina i file temporanei"; en = "Delete temporary files" }
    chkSmartChkdsk     = @{ it = "CHKDSK intelligente (SSD o HDD)"; en = "Smart CHKDSK (SSD or HDD)" }

    ttlSpace           = @{ it = "SPAZIO E CRITERI"; en = "SPACE AND POLICIES" }
    chkStorageSense    = @{ it = "Sensore memoria — disattiva"; en = "Storage Sense — disable" }
    chkReservedStorage = @{ it = "Spazio riservato di Windows (7 GB) — disattiva"; en = "Windows reserved storage (7 GB) — disable" }

    lblSelected        = @{ it = "Selezionati:"; en = "Selected:" }
    chkRestorePoint    = @{ it = "Punto di ripristino"; en = "Restore point" }
    btnSelectAll       = @{ it = "Seleziona tutto"; en = "Select all" }
    btnDeselectAll     = @{ it = "Deseleziona"; en = "Clear all" }
    btnDetectActive    = @{ it = "Rileva già attivi"; en = "Detect applied" }
    btnRun             = @{ it = "Applica modifiche"; en = "Apply changes" }

    btnUndo            = @{ it = "Reimposta predefiniti"; en = "Restore defaults" }
    tabAdv             = @{ it = "Avanzate"; en = "Advanced" }
    ttlAdvIntro        = @{ it = "PRIMA DI PROCEDERE"; en = "BEFORE YOU START" }
    lblAdvIntro        = @{ it = "Queste voci tolgono parti di Windows che la maggior parte dei computer non usa. Il guadagno è reale su una macchina dedicata a giochi o lavoro, ma qualcosa smette di funzionare: leggi la descrizione di ogni voce. Crea un punto di ripristino prima di applicare, e riavvia dopo."; en = "These options strip out parts of Windows that most computers never use. The gain is real on a machine dedicated to gaming or work, but some things stop working: read each entry. Create a restore point before applying, and reboot afterwards." }

    ttlSvc             = @{ it = "SERVIZI DA FERMARE"; en = "SERVICES TO STOP" }
    lblSvcHint         = @{ it = "I servizi assenti vengono ignorati. Si possono sempre riattivare da services.msc."; en = "Missing services are skipped. They can always be turned back on from services.msc." }
    chkSvcSysMain      = @{ it = "SysMain — precaricamento delle app in memoria"; en = "SysMain — preloading apps into memory" }
    chkSvcDiag         = @{ it = "Diagnostica e tracciamento eventi"; en = "Diagnostics and event tracing" }
    chkSvcErrors       = @{ it = "Segnalazione errori Windows"; en = "Windows Error Reporting" }
    chkSvcPca          = @{ it = "Assistente compatibilità programmi"; en = "Program Compatibility Assistant" }
    chkSvcDiscovery    = @{ it = "Rilevamento dispositivi in rete (UPnP, SSDP)"; en = "Network device discovery (UPnP, SSDP)" }
    chkSvcSensors      = @{ it = "Sensori e geolocalizzazione"; en = "Sensors and geolocation" }
    chkSvcSmartCard    = @{ it = "Smart card"; en = "Smart cards" }
    chkSvcParental     = @{ it = "Controllo genitori e programma Insider"; en = "Parental controls and Insider program" }
    chkSvcHyperV       = @{ it = "Servizi Hyper-V (se non usi macchine virtuali)"; en = "Hyper-V services (if you run no virtual machines)" }
    chkSvcPrint        = @{ it = "Spooler di stampa — rischioso: niente stampanti"; en = "Print spooler — risky: no printing" }
    chkSvcSearch       = @{ it = "Ricerca di Windows — rischioso: niente ricerca nel menu Start"; en = "Windows Search — risky: no Start menu search" }
    chkSvcRemote       = @{ it = "Desktop remoto e registro remoto — rischioso se ti colleghi da fuori"; en = "Remote Desktop and Remote Registry — risky if you connect from outside" }
    chkSvcBiometric    = @{ it = "Biometria — rischioso: niente Windows Hello"; en = "Biometrics — risky: no Windows Hello" }
    chkSvcTouch        = @{ it = "Penna e tastiera su schermo — rischioso sui portatili touch"; en = "Pen and on-screen keyboard — risky on touch laptops" }

    ttlTasks           = @{ it = "ATTIVITÀ PIANIFICATE"; en = "SCHEDULED TASKS" }
    chkTaskExtra       = @{ it = "Attività non essenziali di Microsoft"; en = "Non-essential Microsoft tasks" }
    chkTaskMaint       = @{ it = "Manutenzione automatica notturna"; en = "Nightly automatic maintenance" }
    chkTaskDefrag      = @{ it = "Ottimizzazione unità pianificata — rischioso: su SSD manda anche il TRIM"; en = "Scheduled drive optimization — risky: it also issues TRIM on SSDs" }

    ttlMem             = @{ it = "MEMORIA E PROCESSI"; en = "MEMORY AND PROCESSES" }
    chkPrefetch        = @{ it = "Prefetch e Superfetch nel registro"; en = "Prefetch and Superfetch registry values" }
    chkFth             = @{ it = "Fault Tolerant Heap — niente correzioni automatiche"; en = "Fault Tolerant Heap — no automatic patching" }
    chkAppCompat       = @{ it = "Motore di compatibilità e inventario programmi"; en = "Compatibility engine and program inventory" }
    chkSvcHostSplit    = @{ it = "Meno processi svchost (accorpa i servizi)"; en = "Fewer svchost processes (group the services)" }
    chkMemCompression  = @{ it = "Compressione della memoria — rischioso sotto 16 GB di RAM"; en = "Memory compression — risky below 16 GB of RAM" }

    ttlWu              = @{ it = "WINDOWS UPDATE"; en = "WINDOWS UPDATE" }
    chkWuNoStore       = @{ it = "Aggiornamento automatico delle app dello Store"; en = "Automatic Store app updates" }

    ttlBoot            = @{ it = "AVVIO DEL SISTEMA"; en = "SYSTEM STARTUP" }
    btnBootReset       = @{ it = "Ripristina"; en = "Restore" }
    lblBootHint        = @{ it = "Modifiche alla configurazione di avvio. Il pulsante Ripristina rimette i valori predefiniti di Windows."; en = "Changes to the boot configuration. Restore puts the Windows defaults back." }
    chkBootQuiet       = @{ it = "Avvio senza logo animato"; en = "Boot without the animated logo" }
    chkBootMenu        = @{ it = "Menu di avvio classico (F8 disponibile)"; en = "Classic boot menu (F8 available)" }
    chkBootTimeout     = @{ it = "Nessuna attesa nel menu di avvio"; en = "No wait in the boot menu" }
    chkBootDynTick     = @{ it = "Tick dinamico del kernel — rischioso: provalo e misura"; en = "Kernel dynamic tick — risky: try it and measure" }
    chkBootTsc         = @{ it = "Sincronizzazione TSC potenziata — rischioso: provala e misura"; en = "Enhanced TSC sync policy — risky: try it and measure" }

    ttlAppx            = @{ it = "APP PREINSTALLATE"; en = "PREINSTALLED APPS" }
    lblAppxHint        = @{ it = "Si reinstallano dallo Store quando servono."; en = "They can be reinstalled from the Store whenever needed." }
    chkAppxBloat       = @{ it = "App non essenziali (notizie, meteo, mappe, Skype...)"; en = "Non-essential apps (news, weather, maps, Skype...)" }
    chkAppxXbox        = @{ it = "App Xbox e overlay di gioco"; en = "Xbox apps and game overlay" }
    chkAppxProvision   = @{ it = "Non ripristinarle per i nuovi utenti"; en = "Do not restore them for new users" }

    ttlSec             = @{ it = "SICUREZZA RIDOTTA"; en = "REDUCED SECURITY" }
    lblSecHint         = @{ it = "Tutte rischiose e mai incluse in «Seleziona tutto». Abbassano davvero le difese del computer: usale solo su una macchina che non naviga e non apre allegati."; en = "All risky and never part of «Select all». They genuinely lower the computer's defenses: use them only on a machine that does not browse the web or open attachments." }
    chkSecSmartScreen  = @{ it = "SmartScreen — controllo dei file scaricati"; en = "SmartScreen — checking downloaded files" }
    chkSecSpectre      = @{ it = "Mitigazioni Spectre e Meltdown"; en = "Spectre and Meltdown mitigations" }
    chkSecDefenderIdle = @{ it = "Defender: scansioni solo a computer fermo, CPU al 20%"; en = "Defender: scan only when idle, CPU capped at 20%" }
    tabSched           = @{ it = "Priorità"; en = "Priority" }
    ttlPs              = @{ it = "PRIORITÀ DEL PROCESSORE"; en = "PROCESSOR PRIORITY" }
    lblPsHint          = @{ it = "Decide quanto tempo di processore ricevono i programmi e quanto vantaggio ha la finestra in primo piano. Vale subito, senza riavvio."; en = "Decides how much processor time programs get and how much of an edge the foreground window has. Takes effect immediately, no restart." }
    lblPsCurrent       = @{ it = "Valore attuale"; en = "Current value" }
    lblPsPreset        = @{ it = "Profilo"; en = "Profile" }
    psI02              = @{ it = "0x02 · Predefinito di Windows"; en = "0x02 · Windows default" }
    psI26              = @{ it = "0x26 · Breve, variabile, primo piano 3:1 (giochi)"; en = "0x26 · Short, variable, foreground 3:1 (gaming)" }
    psI28              = @{ it = "0x28 · Breve, fisso, nessun vantaggio"; en = "0x28 · Short, fixed, no boost" }
    psI2A              = @{ it = "0x2A · Breve, fisso, primo piano 3:1"; en = "0x2A · Short, fixed, foreground 3:1" }
    psI24              = @{ it = "0x24 · Breve, variabile, nessun vantaggio"; en = "0x24 · Short, variable, no boost" }
    psI16              = @{ it = "0x16 · Lungo, variabile, primo piano 3:1"; en = "0x16 · Long, variable, foreground 3:1" }
    psI18              = @{ it = "0x18 · Lungo, fisso (server)"; en = "0x18 · Long, fixed (server)" }
    psICustom          = @{ it = "Personalizzato"; en = "Custom" }
    lblPsCustom        = @{ it = "Valore esadecimale"; en = "Hex value" }
    btnPsDefault       = @{ it = "Predefinito"; en = "Default" }
    btnPsApply         = @{ it = "Applica"; en = "Apply" }
    ttlMm              = @{ it = "MULTIMEDIA CLASS SCHEDULER"; en = "MULTIMEDIA CLASS SCHEDULER" }
    btnMmReload        = @{ it = "Rileggi"; en = "Reload" }
    lblMmHint          = @{ it = "Il servizio di Windows che dà la precedenza a giochi, audio e video. Le modifiche valgono dal prossimo riavvio."; en = "The Windows service that gives priority to games, audio and video. Changes take effect after the next restart." }
    lblMmNet           = @{ it = "Limitazione della rete"; en = "Network throttling" }
    lblMmResp          = @{ it = "CPU riservata al sistema"; en = "CPU reserved for the system" }
    lblMmTask          = @{ it = "Attività"; en = "Task" }
    lblMmAffinity      = @{ it = "Affinità (esadecimale, 0 = tutti i core)"; en = "Affinity (hex, 0 = all cores)" }
    lblMmClock         = @{ it = "Clock rate (unità da 100 ns)"; en = "Clock rate (100 ns units)" }
    lblMmGpu           = @{ it = "Priorità GPU"; en = "GPU priority" }
    lblMmPrio          = @{ it = "Priorità"; en = "Priority" }
    lblMmSched         = @{ it = "Categoria di scheduling"; en = "Scheduling category" }
    lblMmSfio          = @{ it = "Priorità I/O"; en = "I/O priority" }
    lblMmBgOnly        = @{ it = "Solo in background"; en = "Background only" }
    lblMmBgPrio        = @{ it = "Priorità in background"; en = "Background priority" }
    lblMmLatency       = @{ it = "Sensibile alla latenza"; en = "Latency sensitive" }
    btnMmBackup        = @{ it = "Salva backup"; en = "Save backup" }
    btnMmDefault       = @{ it = "Predefiniti"; en = "Defaults" }
    btnMmApply         = @{ it = "Salva"; en = "Save" }
    chkAmdUlps         = @{ it = "Prestazioni massime — ULPS spento"; en = "Maximum performance — ULPS off" }
    ttlShutdownMenu    = @{ it = "MENU ARRESTA"; en = "POWER MENU" }
    lblShutdownHint    = @{ it = "Valgono subito, senza Applica. Le impostazioni del piano energetico non vengono toccate."; en = "Take effect immediately, without Apply. The power plan settings are not touched." }
    chkMenuSleep       = @{ it = "Sospendi nel menu Arresta"; en = "Sleep in the power menu" }
    chkMenuHibernate   = @{ it = "Iberna nel menu Arresta"; en = "Hibernate in the power menu" }
    tabPriv2           = @{ it = "Privacy avanzata"; en = "Advanced privacy" }
    tabExp             = @{ it = "Esplora file"; en = "File Explorer" }
    tabTask            = @{ it = "Start e barra"; en = "Start and taskbar" }
    tabNotif           = @{ it = "Notifiche e suoni"; en = "Notifications and sounds" }
    tabGame            = @{ it = "Giochi ed effetti"; en = "Games and effects" }
    tabWin             = @{ it = "Windows e servizi"; en = "Windows and services" }
    tabApps            = @{ it = "App e software"; en = "Apps and software" }
    navGrpSystem       = @{ it = "SISTEMA"; en = "SYSTEM" }
    navGrpPrivacy      = @{ it = "PRIVACY"; en = "PRIVACY" }
    navGrpCustom       = @{ it = "PERSONALIZZA"; en = "CUSTOMIZE" }
    navGrpWindows      = @{ it = "WINDOWS E APP"; en = "WINDOWS AND APPS" }
    ttlNvProfile       = @{ it = "NVIDIA: PRESTAZIONI DEL PROFILO"; en = "NVIDIA: PROFILE PERFORMANCE" }
    lblNvProfileHint   = @{ it = "Scritte nel profilo globale del driver, come nel Pannello di controllo NVIDIA."; en = "Written to the driver's global profile, as in the NVIDIA Control Panel." }
    chkNvP2            = @{ it = "CUDA: niente stato P2 forzato"; en = "CUDA: no forced P2 state" }
    chkNvDrsPower      = @{ it = "Gestione energia: prestazioni massime"; en = "Power management: maximum performance" }
    chkNvLowLatency    = @{ it = "Modalità bassa latenza: attiva"; en = "Low latency mode: On" }
    chkNvThreaded      = @{ it = "Ottimizzazione thread attiva"; en = "Threaded optimization on" }
    chkNvTexPerf       = @{ it = "Filtro texture: prestazioni elevate"; en = "Texture filtering: high performance" }
    chkNvAniso         = @{ it = "Ottimizzazione campioni anisotropici"; en = "Anisotropic sample optimization" }
    chkNvShaderCache   = @{ it = "Cache shader illimitata"; en = "Unlimited shader cache" }
    ttlNvReg           = @{ it = "NVIDIA: REGISTRO DEL DRIVER"; en = "NVIDIA: DRIVER REGISTRY" }
    chkNvDisplayPower  = @{ it = "Risparmio energetico del display spento"; en = "Display power saving off" }
    chkNvHdcp          = @{ it = "HDCP spento"; en = "HDCP off" }
    chkNvPreempt       = @{ it = "Prelazione dei calcoli spenta"; en = "Compute preemption off" }
    chkNvDynPstate     = @{ it = "Frequenze sempre al massimo (P0)"; en = "Clocks always at maximum (P0)" }
    chkNvLatency       = @{ it = "Pacchetto latenza del driver"; en = "Driver latency pack" }
    chkAmdAntiLag      = @{ it = "Anti-Lag attivo"; en = "Anti-Lag on" }
    chkAmdShaderCache  = @{ it = "Cache shader sempre attiva"; en = "Shader cache always on" }
    chkAmdTexPerf      = @{ it = "Filtro texture: prestazioni"; en = "Texture filtering: performance" }
    chkAmdTess         = @{ it = "Tassellatura limitata dal driver"; en = "Tessellation limited by the driver" }
    chkAmdFlipQueue    = @{ it = "Coda dei fotogrammi a 1"; en = "Frame queue set to 1" }
    chkAmdNoFrtc       = @{ it = "Limite fotogrammi del driver spento"; en = "Driver frame limiter off" }
    chkAmdStutter      = @{ it = "Modalità stutter spenta"; en = "Stutter mode off" }
    chkAmdAspm         = @{ it = "Risparmio PCIe della scheda spento"; en = "Card PCIe power saving off" }
    chkAmdPowerGating  = @{ it = "Power gating spento"; en = "Power gating off" }
    chkAmdDma          = @{ it = "Copie DMA e scrittura a blocchi"; en = "DMA copies and block write" }
    chkAmdPreempt      = @{ it = "Prelazione dei calcoli spenta"; en = "Compute preemption off" }
    ttlPowerAdv        = @{ it = "IMPOSTAZIONI DEL PIANO IN USO"; en = "SETTINGS OF THE PLAN IN USE" }
    lblPowerAdvHint    = @{ it = "Cambiano subito il piano attivo, sia con l'alimentatore sia a batteria: non serve premere Applica. Se attivi un altro piano, valgono le impostazioni di quello."; en = "They change the active plan right away, both plugged in and on battery: no need to press Apply. If you switch to another plan, its own settings apply." }
    radAppsCatalog     = @{ it = "Catalogo"; en = "Catalog" }
    radAppsInstalled   = @{ it = "Installate"; en = "Installed" }
    lblAppSearchHint   = @{ it = "Cerca..."; en = "Search..." }
    btnAppsUpgrade     = @{ it = "Aggiorna selezionate"; en = "Update selected" }
    btnAppsClear       = @{ it = "Deseleziona"; en = "Clear selection" }
    btnAppsRefresh     = @{ it = "Aggiorna elenco"; en = "Refresh list" }
    lblProfileQueued   = @{ it = "Scegli un profilo: entra tra le modifiche da applicare. Un secondo clic lo toglie."; en = "Pick a profile: it joins the changes to apply. A second click removes it." }
    btnSelectPage      = @{ it = "Questa pagina"; en = "This page" }
    btnRecommended     = @{ it = "Consigliati"; en = "Recommended" }
    ttlAdvExplorer     = @{ it = "ESPLORA FILE"; en = "FILE EXPLORER" }
    lblAdvExplorerHint = @{ it = "Mostrano file che Windows tiene nascosti per non farli cancellare per sbaglio. Fuori da «Seleziona tutto»."; en = "They show files Windows hides so they don't get deleted by mistake. Left out of «Select all»." }
    tabHome            = @{ it = "Home"; en = "Home" }
    lblHomeLoading     = @{ it = "Lettura dell'hardware..."; en = "Reading the hardware..." }
    ttlAppJobs         = @{ it = "OPERAZIONI"; en = "OPERATIONS" }
    btnAppJobsClose    = @{ it = "Chiudi"; en = "Close" }
    chkNvNoAnsel       = @{ it = "Ansel spento"; en = "Ansel off" }
    chkIntelTelemetry  = @{ it = "Telemetria Intel spenta"; en = "Intel telemetry off" }
    chkIntelGfxPower   = @{ it = "Piano grafico Intel: prestazioni massime"; en = "Intel graphics power plan: maximum performance" }
    chkIntelDpst       = @{ it = "Risparmio energetico del display (DPST) spento"; en = "Display power saving (DPST) off" }
    ttlCpu             = @{ it = "PROCESSORE"; en = "PROCESSOR" }
    chkCpuIntelBoostPol = @{ it = "Intel: turbo senza freni di politica"; en = "Intel: turbo with no policy limit" }
    chkCpuIntelHybrid  = @{ it = "Intel ibridi: app in primo piano sui core P"; en = "Intel hybrid: foreground apps on P-cores" }
    chkCpuAmdParking   = @{ it = "AMD Ryzen: nessun core parcheggiato"; en = "AMD Ryzen: no parked cores" }
    chkCpuIdleOff      = @{ it = "Processore sempre sveglio (niente stati di riposo)"; en = "Processor always awake (no idle states)" }
    tabTools           = @{ it = "Strumenti"; en = "Tools" }
    ttlToolJobs        = @{ it = "OPERAZIONI"; en = "OPERATIONS" }
    btnToolJobsClose   = @{ it = "Chiudi"; en = "Close" }
    lblWuHint          = @{ it = "Scegli un profilo: entra tra le modifiche da applicare. Un secondo clic lo toglie."; en = "Pick a profile: it joins the changes to apply. A second click removes it." }
    chkWuProfile       = @{ it = "Profilo di Windows Update"; en = "Windows Update profile" }
    ttlAdvCompat       = @{ it = "OROLOGIO E PERIFERICHE"; en = "CLOCK AND PERIPHERALS" }
    chkAdvUtc          = @{ it = "Orologio del BIOS in UTC (doppio avvio con Linux)"; en = "BIOS clock in UTC (dual boot with Linux)" }
    chkAdvRazer        = @{ it = "Niente installazione automatica del software Razer"; en = "No automatic Razer software install" }
    chkAdvLogi         = @{ it = "Niente assistente download Logitech"; en = "No Logitech download assistant" }
    chkIPv4Pref        = @{ it = "IPv4 prima di IPv6"; en = "IPv4 before IPv6" }
    chkDiskNoSleep     = @{ it = "Dischi e SSD sempre attivi (con alimentazione collegata)"; en = "Disks and SSDs always on (while plugged in)" }
}

# Messaggi non legati a un controllo: log, finestre di dialogo, etichette dinamiche.
$script:Msg = @{
    ready            = @{ it = "Pronto."; en = "Ready." }
    starting         = @{ it = "Avvio in corso..."; en = "Starting..." }
    done             = @{ it = "Completato"; en = "Completed" }
    nothing          = @{ it = "Nessuna voce selezionata."; en = "Nothing selected." }
    activePlan       = @{ it = "Piano attivo:"; en = "Active plan:" }
    detecting        = @{ it = "Rilevamento in corso..."; en = "Detecting..." }
    profileDetected  = @{ it = "Profilo rilevato:"; en = "Detected profile:" }
    noDisks          = @{ it = "Impossibile rilevare le unità con Get-PhysicalDisk."; en = "Unable to detect drives with Get-PhysicalDisk." }
    free             = @{ it = "liberi su"; en = "free of" }
    chooseProfile    = @{ it = "Seleziona SSD oppure HDD prima di applicare il profilo di archiviazione."; en = "Select SSD or HDD before applying the storage profile." }
    finished         = @{ it = "Operazioni completate. Riavvia il computer per rendere effettive tutte le modifiche."; en = "All operations completed. Restart the computer to apply every change." }
    finishedTitle    = @{ it = "Tweak Andrew v6.0"; en = "Tweak Andrew v6.0" }
    confirmRun       = @{ it = "Vuoi applicare le modifiche selezionate?"; en = "Apply the selected changes?" }
    confirmTitle     = @{ it = "Conferma"; en = "Confirm" }
    emptyRecycleAsk  = @{ it = "Svuotare definitivamente il Cestino? L'operazione non si può annullare."; en = "Permanently empty the Recycle Bin? This cannot be undone." }
    summary          = @{ it = "Riepilogo"; en = "Summary" }
    winTitle         = @{ it = "Tweak Andrew v6.1 - PcFixPro Italia"; en = "Tweak Andrew v6.1 - PcFixPro Italia" }
    planTop          = @{ it = "CONSIGLIATI"; en = "RECOMMENDED" }
    planWindows      = @{ it = "PIANI DI WINDOWS"; en = "WINDOWS PLANS" }
    planTest         = @{ it = "DA TESTARE"; en = "TO TEST" }
    planTestHint     = @{ it = "Piani di terze parti inclusi nel programma. Uno alla volta."; en = "Third-party plans bundled with the program. One at a time." }
    planApply        = @{ it = "Attiva"; en = "Activate" }
    planActive       = @{ it = "Attivo"; en = "Active" }
    planRemoveAsk    = @{ it = "Rimuovere dal sistema i piani della sezione «Da testare»? Il computer torna al piano Bilanciato."; en = "Remove the «To test» plans from the system? The computer goes back to the Balanced plan." }
    gpuVendor        = @{ it = "Produttore:"; en = "Vendor:" }
    gpuNone          = @{ it = "Nessuna scheda video rilevata."; en = "No graphics card detected." }
    shaderScanning   = @{ it = "Calcolo in corso..."; en = "Measuring..." }
    shaderNone       = @{ it = "Nessuna cache shader trovata."; en = "No shader cache found." }
    shaderTotal      = @{ it = "Totale"; en = "Total" }
    shaderAsk        = @{ it = "Svuotare la cache shader?`n`nIl primo avvio di ogni gioco sarà più lento perché gli shader vengono ricompilati. Nessun dato di gioco viene toccato."; en = "Clear the shader cache?`n`nThe first launch of each game will be slower because shaders get recompiled. No game data is touched." }
    featNeedId       = @{ it = "Scrivi il numero della funzione prima di applicare."; en = "Enter the feature id before applying." }
    featEmpty        = @{ it = "Nessuna funzione modificata su questo computer."; en = "No feature overridden on this computer." }
    featStateOn      = @{ it = "attiva"; en = "enabled" }
    featStateOff     = @{ it = "disattivata"; en = "disabled" }
    bootResetAsk     = @{ it = "Rimettere i valori di avvio predefiniti di Windows?"; en = "Restore the default Windows boot settings?" }
    bootResetDone    = @{ it = "Configurazione di avvio riportata ai valori predefiniti."; en = "Boot configuration restored to its defaults." }
    undoPrefix       = @{ it = "Predefinito:"; en = "Default:" }
    undoAsk          = @{ it = "Rimettere i valori predefiniti di Windows per le voci selezionate?"; en = "Restore the Windows defaults for the selected entries?" }
    advWarnTitle     = @{ it = "Voci avanzate"; en = "Advanced options" }
    advWarn          = @{ it = "Hai selezionato voci della sezione Avanzate: tolgono parti di Windows e qualcosa potrebbe smettere di funzionare. Procedere?"; en = "You selected entries from the Advanced section: they strip out parts of Windows and something may stop working. Continue?" }
    dlgYes           = @{ it = "Sì, procedi"; en = "Yes, go ahead" }
    dlgNo            = @{ it = "Annulla"; en = "Cancel" }
    selCount         = @{ it = "Voci selezionate: {0}"; en = "Selected entries: {0}" }
    doneSummary      = @{ it = "Fatto: {0} modifiche applicate, {1} già a posto, {2} errori."; en = "Done: {0} changes applied, {1} already set, {2} errors." }
    doneReboot       = @{ it = "Riavvia il PC per completarle."; en = "Restart the PC to finish." }
    psInterval       = @{ it = "Quanto"; en = "Quantum" }
    psQuantum        = @{ it = "Durata"; en = "Length" }
    psBoost          = @{ it = "Primo piano"; en = "Foreground" }
    psShort          = @{ it = "breve"; en = "short" }
    psLong           = @{ it = "lungo"; en = "long" }
    psVariable       = @{ it = "variabile"; en = "variable" }
    psFixed          = @{ it = "fisso"; en = "fixed" }
    psAuto           = @{ it = "automatico"; en = "automatic" }
    psInvalid        = @{ it = "Valore non valido: usa da 00 a 3F."; en = "Invalid value: use 00 to 3F." }
    mmNetOff         = @{ it = "Disattivata"; en = "Disabled" }
    mmNetDefault     = @{ it = "10 (predefinito)"; en = "10 (default)" }
    mmDefaultWord    = @{ it = "predefinito"; en = "default" }
    mmBadClock       = @{ it = "Clock rate non valido: usa un numero tra 1000 e 100000."; en = "Invalid clock rate: use a number between 1000 and 100000." }
    mmBadAffinity    = @{ it = "Affinità non valida: usa un valore esadecimale, 0 per tutti i core."; en = "Invalid affinity: use a hex value, 0 for all cores." }
    mmReboot         = @{ it = "Valori MMCSS salvati. Valgono dal prossimo riavvio."; en = "MMCSS values saved. They take effect after the next restart." }
    mmDefaultsLoaded = @{ it = "Valori di fabbrica caricati nel pannello: premi Salva per scriverli."; en = "Factory values loaded into the panel: press Save to write them." }
    mmNoDefaults     = @{ it = "Per questa attività Windows non ha valori noti: caricati solo quelli generali."; en = "Windows has no known values for this task: only the general ones were loaded." }
    catCustom          = @{ it = "Personalizzato"; en = "Custom" }
    svcAuto            = @{ it = "Automatico"; en = "Automatic" }
    svcAutoDelayed     = @{ it = "Automatico ritardato"; en = "Automatic (delayed)" }
    svcManual          = @{ it = "Manuale"; en = "Manual" }
    svcDisabled        = @{ it = "Disattivato"; en = "Disabled" }
    recYes             = @{ it = "Consigliata"; en = "Recommended" }
    recLimited         = @{ it = "Consigliata con limitazioni"; en = "Recommended with limits" }
    recNo              = @{ it = "Sconsigliata: toglie una funzione utile"; en = "Not recommended: removes a useful feature" }
    aiTag              = @{ it = "IA"; en = "AI" }
    aiRelevant         = @{ it = "Riguarda le funzioni di intelligenza artificiale"; en = "Concerns artificial intelligence features" }
    catBulkTitle       = @{ it = "Modifica di più impostazioni"; en = "Change several settings" }
    applyRecYes        = @{ it = "Applica le consigliate"; en = "Apply recommended" }
    applyRecLimited    = @{ it = "Consigliate e con limitazioni"; en = "Recommended and limited" }
    applyRecAll        = @{ it = "Applica tutte"; en = "Apply all" }
    undoAllFactory     = @{ it = "Annulla tutto (impostazioni di fabbrica)"; en = "Undo all (factory settings)" }
    makeRestorePoint   = @{ it = "Crea un punto di ripristino"; en = "Create a restore point" }
    askRecYes          = @{ it = "Attivo tutte le protezioni consigliate, senza toccare le altre. Procedo?"; en = "I'll turn on every recommended protection and leave the rest alone. Go ahead?" }
    askRecLimited      = @{ it = "Attivo le consigliate e quelle con limitazioni: qualche funzione potrebbe smettere di funzionare. Procedo?"; en = "I'll turn on recommended and limited ones: some features may stop working. Go ahead?" }
    askRecAll          = @{ it = "Attivo tutte le voci, anche le sconsigliate: fotocamera, microfono e altre funzioni verranno bloccate. Procedo?"; en = "I'll turn on everything, even the not-recommended ones: camera, microphone and other features will be blocked. Go ahead?" }
    askFactory         = @{ it = "Riporto ogni voce della pagina com'era su Windows appena installato. Procedo?"; en = "I'll put every item on this page back as on a fresh Windows install. Go ahead?" }
    privLegend         = @{ it = "Interruttore acceso = protezione attiva. Pallino verde consigliata, arancio con limitazioni, rosso sconsigliata. IA = riguarda l'intelligenza artificiale."; en = "Switch on = protection active. Green dot recommended, orange with limits, red not recommended. AI = concerns artificial intelligence." }
    scopeUser          = @{ it = "Utente corrente"; en = "Current user" }
    scopeMachine       = @{ it = "Macchina locale"; en = "Local machine" }
    scopeAll           = @{ it = "Tutte"; en = "All" }
    applyRecommended   = @{ it = "Applica le consigliate"; en = "Apply recommended" }
    restoreWindows     = @{ it = "Predefiniti di Windows"; en = "Windows defaults" }
    askRecommended     = @{ it = "Porto le voci di questa pagina sui valori consigliati. Quelle senza consiglio restano come sono. Procedo?"; en = "I'll set this page's items to the recommended values. Items without a recommendation stay as they are. Go ahead?" }
    askWindowsDefaults = @{ it = "Riporto le voci di questa pagina ai valori di Windows appena installato. Procedo?"; en = "I'll put this page's items back to the values of a fresh Windows install. Go ahead?" }
    restartExplorer    = @{ it = "Riavvia Esplora risorse"; en = "Restart File Explorer" }
    catSearch          = @{ it = "Cerca un'impostazione..."; en = "Search a setting..." }
    catLoading         = @{ it = "Lettura dello stato delle impostazioni..."; en = "Reading the settings state..." }
    restoreDone        = @{ it = "Punto di ripristino creato."; en = "Restore point created." }
    restoreFail        = @{ it = "Punto di ripristino non creato: controlla che Protezione sistema sia attiva."; en = "Restore point not created: check that System Protection is on." }
    diskSystem         = @{ it = "Sistema"; en = "System" }
    diskHealthy        = @{ it = "Disco in salute"; en = "Healthy disk" }
    diskWarning        = @{ it = "Il disco segnala problemi: fai un backup"; en = "The disk reports problems: make a backup" }
    volFree            = @{ it = "{0} liberi su {1}"; en = "{0} free of {1}" }
    profileSysSsd      = @{ it = "Windows è installato su un {0} ({1}): ti consigliamo il profilo SSD / NVMe."; en = "Windows is installed on an {0} ({1}): we recommend the SSD / NVMe profile." }
    profileSysHdd      = @{ it = "Windows è installato su un disco meccanico ({0}): ti consigliamo il profilo HDD."; en = "Windows is installed on a mechanical drive ({0}): we recommend the HDD profile." }
    profileSysUnknown  = @{ it = "Non riesco a capire su che disco si trova Windows: scegli tu il profilo."; en = "I can't tell which drive Windows is on: pick the profile yourself." }
    recommendedTag     = @{ it = "(consigliato)"; en = "(recommended)" }
    lic_os             = @{ it = "Open source"; en = "Open source" }
    lic_fw             = @{ it = "Freeware"; en = "Freeware" }
    lic_fr             = @{ it = "Gratuita + a pagamento"; en = "Free + paid" }
    lic_ms             = @{ it = "Microsoft"; en = "Microsoft" }
    lic_pd             = @{ it = "A pagamento"; en = "Paid" }
    appInstalled       = @{ it = "Installata"; en = "Installed" }
    appsNone           = @{ it = "Nessuna app corrisponde ai filtri."; en = "No app matches the filters." }
    appsInstalledTitle = @{ it = "Programmi installati ({0})"; en = "Installed programs ({0})" }
    appsUninstallSel   = @{ it = "Disinstalla selezionate"; en = "Uninstall selected" }
    appsInstallSel     = @{ it = "Installa selezionate"; en = "Install selected" }
    appsAllCategories  = @{ it = "Tutte le categorie"; en = "All categories" }
    appsAllLicenses    = @{ it = "Tutte le licenze"; en = "All licenses" }
    appsWorking        = @{ it = "{0}... (in coda: {1})"; en = "{0}... (queued: {1})" }
    appsDone           = @{ it = "Operazioni completate. Il dettaglio è nella finestra di PowerShell."; en = "Operations completed. Details are in the PowerShell window." }
    appsChecking       = @{ it = "Controllo delle app già installate..."; en = "Checking installed apps..." }
    appsInstalledCount = @{ it = "{0} pacchetti riconosciuti da winget su questo PC."; en = "{0} packages recognized by winget on this PC." }
    appsAskUninstall   = @{ it = "Disinstallo {0} programmi. Alcuni potrebbero aprire la propria finestra di disinstallazione. Procedo?"; en = "I'll uninstall {0} programs. Some may open their own uninstall window. Go ahead?" }
    appsUninstalling   = @{ it = "Disinstallazione di"; en = "Uninstalling" }
    appsAskInstall     = @{ it = "Installo {0} app con winget, una alla volta, senza finestre. Procedo?"; en = "I'll install {0} apps with winget, one at a time, silently. Go ahead?" }
    appsInstalling     = @{ it = "Installazione di"; en = "Installing" }
    appsAskUpgrade     = @{ it = "Aggiorno con winget tutte le app che hanno una versione nuova. Può richiedere diversi minuti. Procedo?"; en = "I'll update every app with a newer version through winget. It may take several minutes. Go ahead?" }
    appsUpgradeAll     = @{ it = "Aggiornamento di tutte le app"; en = "Updating all apps" }
    appsNoWinget       = @{ it = "winget non è disponibile: installa «Programma di installazione app» dal Microsoft Store."; en = "winget is not available: install «App Installer» from the Microsoft Store." }
    appCat_browser     = @{ it = "Browser"; en = "Browsers" }
    appCat_chat        = @{ it = "Comunicazione"; en = "Communication" }
    appCat_docs        = @{ it = "Documenti e ufficio"; en = "Documents and office" }
    appCat_media       = @{ it = "Foto, audio e video"; en = "Photo, audio and video" }
    appCat_games       = @{ it = "Giochi"; en = "Games" }
    appCat_tools       = @{ it = "Utilità"; en = "Utilities" }
    appCat_system      = @{ it = "Sistema e diagnostica"; en = "System and diagnostics" }
    appCat_security    = @{ it = "Sicurezza e privacy"; en = "Security and privacy" }
    appCat_net         = @{ it = "Rete, cloud e download"; en = "Network, cloud and downloads" }
    appCat_dev         = @{ it = "Sviluppo"; en = "Development" }
    appCat_runtime     = @{ it = "Componenti di sistema"; en = "System components" }
    selPageNone        = @{ it = "Su questa pagina non ci sono voci da mettere in coda."; en = "This page has no entries to queue." }
    recNone            = @{ it = "Qui le voci si scelgono una per una: leggi la descrizione di ognuna."; en = "Here entries are picked one by one: read each description." }
    recSelected        = @{ it = "Selezionate {0} voci consigliate: premi Applica modifiche."; en = "Selected {0} recommended entries: press Apply changes." }
    recSched           = @{ it = "Valori consigliati pronti nei due pannelli: premi Applica e Salva per scriverli."; en = "Recommended values ready in both panels: press Apply and Save to write them." }
    appUpdatable       = @{ it = "Aggiornabile"; en = "Update available" }
    appsUpgradeSel     = @{ it = "Aggiorna selezionate"; en = "Update selected" }
    appsSelectUpdates  = @{ it = "Seleziona tutti"; en = "Select all" }
    appsUpdatesTitle   = @{ it = "Aggiornamenti disponibili ({0})"; en = "Available updates ({0})" }
    appsNoUpdates      = @{ it = "Tutte le app gestite da winget sono aggiornate."; en = "Every app managed by winget is up to date." }
    appsScanning       = @{ it = "Controllo degli aggiornamenti in corso..."; en = "Checking for updates..." }
    appsAskUpgradeSel  = @{ it = "Aggiorno {0} app con winget, una alla volta, senza finestre. Procedo?"; en = "I'll update {0} apps with winget, one at a time, without windows. Go ahead?" }
    appsUpgrading      = @{ it = "Aggiornamento di"; en = "Updating" }
    jobWait            = @{ it = "In attesa"; en = "Waiting" }
    jobPrep            = @{ it = "Preparazione..."; en = "Preparing..." }
    jobDownload        = @{ it = "Download {0}%"; en = "Download {0}%" }
    jobInstall         = @{ it = "Installazione..."; en = "Installing..." }
    jobInstallPct      = @{ it = "Installazione {0}%"; en = "Installing {0}%" }
    jobUninstall       = @{ it = "Disinstallazione..."; en = "Uninstalling..." }
    jobOk              = @{ it = "Completata"; en = "Done" }
    jobOkReboot        = @{ it = "Completata, serve un riavvio"; en = "Done, restart needed" }
    jobErr             = @{ it = "Errore (codice {0})"; en = "Error (code {0})" }
    jobsProgress       = @{ it = "{0} di {1}"; en = "{0} of {1}" }
    appsDoneSum        = @{ it = "Operazioni completate: {0} riuscite, {1} con errori."; en = "Operations completed: {0} succeeded, {1} with errors." }
    homeThisPc         = @{ it = "QUESTO PC"; en = "THIS PC" }
    homeDomain         = @{ it = "Dominio"; en = "Domain" }
    homeWorkgroup      = @{ it = "Gruppo di lavoro"; en = "Workgroup" }
    homeUptime         = @{ it = "Acceso da {0}"; en = "Up for {0}" }
    homeUptimeD        = @{ it = "{0} g {1} h {2} min"; en = "{0} d {1} h {2} min" }
    homeUptimeH        = @{ it = "{0} h {1} min"; en = "{0} h {1} min" }
    homeInstalledOn    = @{ it = "Windows installato il {0}"; en = "Windows installed on {0}" }
    homePcType         = @{ it = "TIPOLOGIA DEL COMPUTER"; en = "COMPUTER TYPE" }
    homeTypeAuto       = @{ it = "Rilevamento automatico: {0}"; en = "Automatic detection: {0}" }
    homeTypeDesktop    = @{ it = "Computer fisso"; en = "Desktop computer" }
    homeTypeLaptop     = @{ it = "Computer portatile"; en = "Laptop" }
    homeTypeHint       = @{ it = "Su un portatile «Consigliati» esclude le voci che consumano più batteria. Si possono comunque selezionare manualmente."; en = "On a laptop «Recommended» leaves out the entries that drain the battery most. You can still select them manually." }
    homeCpu            = @{ it = "Processore"; en = "Processor" }
    homeRam            = @{ it = "Memoria"; en = "Memory" }
    homeGpu            = @{ it = "Scheda video"; en = "Graphics card" }
    homeDisks          = @{ it = "Archiviazione"; en = "Storage" }
    homeVolumes        = @{ it = "Unità"; en = "Drives" }
    homeFreeFmt        = @{ it = "{0} liberi su {1}"; en = "{0} free of {1}" }
    homeBoard          = @{ it = "Scheda madre e firmware"; en = "Motherboard and firmware" }
    homeNet            = @{ it = "Rete"; en = "Network" }
    homeNoNet          = @{ it = "Nessuna connessione attiva."; en = "No active connection." }
    homeBattery        = @{ it = "Batteria"; en = "Battery" }
    homeSlotsFmt       = @{ it = "{0} su {1} slot"; en = "{0} of {1} slots" }
    hkCores            = @{ it = "Core / thread"; en = "Cores / threads" }
    hkClock            = @{ it = "Frequenza max"; en = "Max clock" }
    hkTotal            = @{ it = "Totale"; en = "Total" }
    hkRamType          = @{ it = "Tipo e velocità"; en = "Type and speed" }
    hkSlots            = @{ it = "Moduli"; en = "Modules" }
    hkVram             = @{ it = "Memoria video"; en = "Video memory" }
    hkDriver           = @{ it = "Driver"; en = "Driver" }
    hkRes              = @{ it = "Schermo"; en = "Display" }
    hkType             = @{ it = "Tipo"; en = "Type" }
    hkModel            = @{ it = "Modello"; en = "Model" }
    hkAdapter          = @{ it = "Scheda"; en = "Adapter" }
    hkSpeed            = @{ it = "Velocità"; en = "Speed" }
    hkCharge           = @{ it = "Carica"; en = "Charge" }
    hkPower            = @{ it = "Alimentazione"; en = "Power" }
    hkHealth           = @{ it = "Salute"; en = "Health" }
    valOn              = @{ it = "Attivo"; en = "On" }
    valOff             = @{ it = "Spento"; en = "Off" }
    valNone            = @{ it = "Assente"; en = "Not present" }
    valOnAc            = @{ it = "Collegato alla corrente"; en = "Plugged in" }
    valOnBattery       = @{ it = "A batteria"; en = "On battery" }
    jobRetry           = @{ it = "Nuovo tentativo: sostituisco la versione installata..."; en = "Retrying: replacing the installed version..." }
    wgErr_8A150008     = @{ it = "Download non riuscito"; en = "Download failed" }
    wgErr_8A150011     = @{ it = "File scaricato non valido"; en = "Downloaded file not valid" }
    wgErr_8A150014     = @{ it = "Pacchetto non trovato"; en = "Package not found" }
    wgErr_8A15008E     = @{ it = "Tipo di installatore cambiato: aggiornala dal suo sito"; en = "Installer type changed: update it from its website" }
    wgErr_8A150101     = @{ it = "App aperta: chiudila e riprova"; en = "App is running: close it and retry" }
    wgErr_8A150102     = @{ it = "Un'altra installazione è in corso"; en = "Another installation is running" }
    wgErr_8A150103     = @{ it = "File in uso: chiudi l'app e riprova"; en = "File in use: close the app and retry" }
    wgErr_8A150104     = @{ it = "Manca un componente richiesto"; en = "A required component is missing" }
    wgErr_8A150105     = @{ it = "Disco pieno"; en = "Disk full" }
    wgErr_8A150106     = @{ it = "Memoria insufficiente"; en = "Not enough memory" }
    wgErr_8A150107     = @{ it = "Nessuna connessione a Internet"; en = "No Internet connection" }
    wgErr_8A15010A     = @{ it = "Riavvia il PC prima di installarla"; en = "Restart the PC before installing it" }
    wgErr_8A15010C     = @{ it = "Annullata"; en = "Cancelled" }
    wgErr_8A15010E     = @{ it = "È già installata una versione più recente"; en = "A newer version is already installed" }
    wgErr_8A15010F     = @{ it = "Bloccata da un criterio di sistema"; en = "Blocked by a system policy" }
    cpuDetected        = @{ it = "Rilevato: {0}. Si attivano solo le voci adatte a questo processore."; en = "Detected: {0}. Only the entries suited to this processor are enabled." }
    cpuUnknown         = @{ it = "processore non riconosciuto"; en = "unrecognized processor" }
    sectionSelect      = @{ it = "Tutta la sezione"; en = "Whole section" }
    laptopSelTitle     = @{ it = "Computer portatile"; en = "Laptop" }
    laptopSelAsk       = @{ it = "Su un portatile è consigliato usare «Consigliati»: «Seleziona tutto» include anche voci che riducono la durata della batteria. Selezionare comunque tutto?"; en = "On a laptop «Recommended» is the better choice: «Select all» also includes entries that shorten battery life. Select everything anyway?" }
    actRun             = @{ it = "Modifiche: {0}"; en = "Changes: {0}" }
    jobWorking         = @{ it = "In corso..."; en = "Working..." }
    badgeActive        = @{ it = "Attivo"; en = "Active" }
    starTip            = @{ it = "Consigliato: un clic lo seleziona, poi premi «Applica modifiche»."; en = "Recommended: one click selects it, then press «Apply changes»." }
    scanRunning        = @{ it = "Controllo delle voci già attive..."; en = "Checking entries already active..." }
    scanDone           = @{ it = "Voci già attive su questo PC: {0}. Sono segnate con «Attivo»."; en = "Entries already active on this PC: {0}. They are marked «Active»." }
    currentSetting     = @{ it = "Impostazione attuale: {0}"; en = "Current setting: {0}" }
    ttlClean           = @{ it = "Pulizia del PC"; en = "PC cleanup" }
    cleanHint          = @{ it = "Scegli cosa pulire. Le voci spente sono dati utili: cancellale solo se sai che non ti servono."; en = "Choose what to clean. The unchecked entries are useful data: delete them only if you know you don't need them." }
    cleanScan          = @{ it = "Calcola spazio"; en = "Measure space" }
    cleanRun           = @{ it = "Pulisci selezionati"; en = "Clean selected" }
    cleanAsk           = @{ it = "Pulisco {0} voci. I file eliminati non finiscono nel Cestino. Procedo?"; en = "I'll clean {0} entries. Deleted files do not go to the Recycle Bin. Go ahead?" }
    cleanMeasuring     = @{ it = "calcolo..."; en = "measuring..." }
    cleanFreed         = @{ it = "Liberati {0}"; en = "{0} freed" }
    clean_winTemp      = @{ it = "File temporanei di Windows"; en = "Windows temporary files" }
    clean_userTemp     = @{ it = "File temporanei dell'utente"; en = "User temporary files" }
    clean_wuCache      = @{ it = "Aggiornamenti di Windows già scaricati"; en = "Already downloaded Windows updates" }
    clean_doCache      = @{ it = "Cache di Ottimizzazione recapito"; en = "Delivery Optimization cache" }
    clean_recycle      = @{ it = "Cestino"; en = "Recycle Bin" }
    clean_errors       = @{ it = "Segnalazioni errori e dump"; en = "Error reports and dumps" }
    clean_thumbs       = @{ it = "Cache delle miniature"; en = "Thumbnail cache" }
    clean_recent       = @{ it = "File recenti ed elenchi di salto"; en = "Recent files and jump lists" }
    clean_runHist      = @{ it = "Cronologia di Esegui e dei percorsi digitati"; en = "Run and typed path history" }
    clean_prefetch     = @{ it = "Prefetch"; en = "Prefetch" }
    cleanTip_winTemp   = @{ it = "File lasciati dai programmi di installazione e dal sistema."; en = "Files left behind by installers and the system." }
    cleanTip_userTemp  = @{ it = "File temporanei dei programmi che usi. Quelli in uso vengono saltati."; en = "Temporary files of the programs you use. Files in use are skipped." }
    cleanTip_wuCache   = @{ it = "Pacchetti già installati. Windows Update si ferma per pochi secondi."; en = "Packages already installed. Windows Update pauses for a few seconds." }
    cleanTip_doCache   = @{ it = "Copie degli aggiornamenti condivise con altri PC."; en = "Update copies shared with other PCs." }
    cleanTip_recycle   = @{ it = "Svuota il Cestino su tutti i dischi."; en = "Empties the Recycle Bin on every drive." }
    cleanTip_errors    = @{ it = "Rapporti già inviati e file di arresto anomalo."; en = "Reports already sent and crash files." }
    cleanTip_thumbs    = @{ it = "Windows le ricrea aprendo le cartelle: la prima apertura sarà più lenta."; en = "Windows rebuilds them when you open folders: the first opening will be slower." }
    cleanTip_recent    = @{ it = "Toglie i file recenti da Esplora file, Start e barra delle applicazioni."; en = "Removes recent files from File Explorer, Start and the taskbar." }
    cleanTip_runHist   = @{ it = "Comandi scritti in Esegui (Win+R) e percorsi digitati in Esplora file."; en = "Commands typed in Run (Win+R) and paths typed in File Explorer." }
    cleanTip_prefetch  = @{ it = "Windows lo usa per aprire prima i programmi: dopo la pulizia i primi avvii saranno più lenti."; en = "Windows uses it to open programs faster: after cleaning the first launches will be slower." }
    ttlFix             = @{ it = "Riparazioni"; en = "Repairs" }
    fixHint            = @{ it = "Partono subito, una alla volta. L'avanzamento resta visibile in alto anche dalle altre pagine."; en = "They start right away, one at a time. Progress stays visible at the top from the other pages too." }
    toolRun            = @{ it = "Esegui"; en = "Run" }
    tool_netQuick      = @{ it = "Rete: ripristino rapido"; en = "Network: quick reset" }
    toolDesc_netQuick  = @{ it = "Svuota la cache DNS e rinnova l'indirizzo IP. La connessione cade per qualche secondo."; en = "Flushes the DNS cache and renews the IP address. The connection drops for a few seconds." }
    tool_netFull       = @{ it = "Rete: ripristino completo"; en = "Network: full reset" }
    toolDesc_netFull   = @{ it = "Winsock, stack IP, proxy di sistema e parametri TCP di Windows tornano come nuovi. Serve un riavvio."; en = "Winsock, IP stack, system proxy and Windows TCP settings go back to factory state. Needs a restart." }
    toolAsk_netQuick   = @{ it = "La connessione si interrompe per qualche secondo. Procedo?"; en = "The connection drops for a few seconds. Go ahead?" }
    toolAsk_netFull    = @{ it = "Rimetto la rete come appena installata. VPN e programmi che modificano Winsock potrebbero dover essere reinstallati. Procedo?"; en = "I'll reset networking to a fresh state. VPNs and programs that change Winsock may need reinstalling. Go ahead?" }
    tool_firewall      = @{ it = "Firewall: impostazioni predefinite"; en = "Firewall: default settings" }
    toolDesc_firewall  = @{ it = "Cancella tutte le regole aggiunte da te e dai programmi. Usalo solo se il firewall blocca connessioni che dovrebbero funzionare."; en = "Deletes every rule added by you and by programs. Use it only if the firewall blocks connections that should work." }
    toolAsk_firewall   = @{ it = "Tutte le regole personalizzate del firewall verranno cancellate e non si possono recuperare. Procedo?"; en = "All custom firewall rules will be deleted and cannot be recovered. Go ahead?" }
    tool_wuReset       = @{ it = "Windows Update: ripristino"; en = "Windows Update: reset" }
    toolDesc_wuReset   = @{ it = "Per aggiornamenti bloccati o in errore: ferma i servizi, rinomina SoftwareDistribution e catroot2, ripristina i componenti e riparte. Serve un riavvio."; en = "For stuck or failing updates: stops the services, renames SoftwareDistribution and catroot2, restores the components and restarts. Needs a restart." }
    toolAsk_wuReset    = @{ it = "La cronologia degli aggiornamenti mostrata da Windows verrà azzerata; gli aggiornamenti installati restano. Procedo?"; en = "The update history Windows shows will be cleared; installed updates stay. Go ahead?" }
    tool_repair        = @{ it = "File di sistema: controllo e riparazione"; en = "System files: check and repair" }
    toolDesc_repair    = @{ it = "DISM ripara l'immagine di Windows, poi SFC sistema i file danneggiati. Può richiedere 15-30 minuti."; en = "DISM repairs the Windows image, then SFC fixes damaged files. It can take 15-30 minutes." }
    toolAsk_repair     = @{ it = "Il controllo dura a lungo e usa molto il disco. Puoi continuare a usare il PC. Procedo?"; en = "The check takes a while and uses the disk heavily. You can keep using the PC. Go ahead?" }
    tool_ntp           = @{ it = "Orologio: sincronizza l'ora"; en = "Clock: sync the time" }
    toolDesc_ntp       = @{ it = "Usa pool.ntp.org e time.windows.com e sincronizza subito."; en = "Uses pool.ntp.org and time.windows.com and syncs right away." }
    tool_winget        = @{ it = "winget: riparazione"; en = "winget: repair" }
    toolDesc_winget    = @{ it = "Registra di nuovo il Programma di installazione app e ripristina le origini dei pacchetti."; en = "Re-registers App Installer and resets the package sources." }
    tool_regBackup     = @{ it = "Registro: copia di sicurezza giornaliera"; en = "Registry: daily backup" }
    toolDesc_regBackup = @{ it = "Riattiva la copia automatica del registro in System32\config\RegBack e ne crea subito una."; en = "Re-enables the automatic registry copy in System32\config\RegBack and makes one now." }
    tool_store         = @{ it = "Microsoft Store: svuota la cache"; en = "Microsoft Store: clear cache" }
    toolDesc_store     = @{ it = "Per download dello Store bloccati. Al termine lo Store si apre da solo."; en = "For stuck Store downloads. The Store opens by itself when done." }
    tool_explorer      = @{ it = "Esplora risorse: riavvia"; en = "File Explorer: restart" }
    toolDesc_explorer  = @{ it = "Chiude e riapre barra delle applicazioni, Start e cartelle. Utile se qualcosa è bloccato."; en = "Closes and reopens the taskbar, Start and folders. Useful when something is stuck." }
    tool_icons         = @{ it = "Icone e miniature: ricostruisci"; en = "Icons and thumbnails: rebuild" }
    toolDesc_icons     = @{ it = "Per icone vuote o sbagliate. Esplora risorse si riavvia."; en = "For blank or wrong icons. File Explorer restarts." }
    toolAsk_icons      = @{ it = "Le finestre di Esplora file aperte verranno chiuse. Procedo?"; en = "Open File Explorer windows will be closed. Go ahead?" }
    ttlFeatures        = @{ it = "Funzionalità di Windows"; en = "Windows features" }
    featHint           = @{ it = "Quelle già attive sono segnate con «Attivo». L'attivazione scarica i file da Windows Update e di solito chiede un riavvio."; en = "The ones already active are marked «Active». Enabling downloads files from Windows Update and usually needs a restart." }
    featRun            = @{ it = "Attiva selezionate"; en = "Enable selected" }
    featAsk            = @{ it = "Attivo {0} funzionalità con DISM. Procedo?"; en = "I'll enable {0} features with DISM. Go ahead?" }
    featMissing        = @{ it = "Non disponibile in questa edizione di Windows."; en = "Not available in this edition of Windows." }
    feat_netfx         = @{ it = ".NET Framework 3.5 e servizi avanzati 4.x"; en = ".NET Framework 3.5 and 4.x advanced services" }
    feat_hyperv        = @{ it = "Hyper-V"; en = "Hyper-V" }
    feat_sandbox       = @{ it = "Sandbox di Windows"; en = "Windows Sandbox" }
    feat_wsl           = @{ it = "Sottosistema Windows per Linux (WSL)"; en = "Windows Subsystem for Linux (WSL)" }
    feat_media         = @{ it = "Componenti multimediali legacy (Windows Media Player, DirectPlay)"; en = "Legacy media components (Windows Media Player, DirectPlay)" }
    feat_nfs           = @{ it = "Client NFS"; en = "NFS client" }
    featTip_netfx      = @{ it = "Serve a programmi e giochi meno recenti."; en = "Needed by older programs and games." }
    featTip_hyperv     = @{ it = "Macchine virtuali con Hyper-V. Solo edizioni Pro, Enterprise ed Education."; en = "Virtual machines with Hyper-V. Pro, Enterprise and Education only." }
    featTip_sandbox    = @{ it = "Un Windows usa e getta per provare programmi sospetti. Solo edizioni Pro ed Enterprise."; en = "A disposable Windows to try suspicious programs. Pro and Enterprise only." }
    featTip_wsl        = @{ it = "Distribuzioni Linux dentro Windows."; en = "Linux distributions inside Windows." }
    featTip_media      = @{ it = "Per giochi e programmi vecchi che richiedono DirectPlay o Windows Media Player."; en = "For old games and programs that need DirectPlay or Windows Media Player." }
    featTip_nfs        = @{ it = "Accesso alle cartelle condivise NFS di NAS e server Linux."; en = "Access to NFS shares on NAS and Linux servers." }
    oosuHint           = @{ it = "Lo strumento di privacy di O&O, gratuito e senza installazione. Si scarica dal sito ufficiale in una cartella del programma, se ne controlla la firma digitale e si apre."; en = "O&O's free privacy tool, no install needed. It is downloaded from the official site into a program folder, its digital signature is checked and it opens." }
    oosuRun            = @{ it = "Scarica e apri"; en = "Download and open" }
    oosuAsk            = @{ it = "Scarico O&O ShutUp10++ da oo-software.com (circa 3 MB) e lo apro. Procedo?"; en = "I'll download O&O ShutUp10++ from oo-software.com (about 3 MB) and open it. Go ahead?" }
    ttlPanels          = @{ it = "Pannelli di Windows"; en = "Windows panels" }
    panelsHint         = @{ it = "Le finestre classiche delle impostazioni, a un clic."; en = "The classic settings windows, one click away." }
    panel_control      = @{ it = "Pannello di controllo"; en = "Control Panel" }
    panel_compmgmt     = @{ it = "Gestione computer"; en = "Computer Management" }
    panel_devmgmt      = @{ it = "Gestione dispositivi"; en = "Device Manager" }
    panel_diskmgmt     = @{ it = "Gestione disco"; en = "Disk Management" }
    panel_services     = @{ it = "Servizi"; en = "Services" }
    panel_eventvwr     = @{ it = "Visualizzatore eventi"; en = "Event Viewer" }
    panel_appwiz       = @{ it = "Programmi e funzionalità"; en = "Programs and Features" }
    panel_ncpa         = @{ it = "Connessioni di rete"; en = "Network Connections" }
    panel_powercfg     = @{ it = "Opzioni risparmio energia"; en = "Power Options" }
    panel_printers     = @{ it = "Stampanti"; en = "Printers" }
    panel_mouse        = @{ it = "Mouse"; en = "Mouse" }
    panel_sound        = @{ it = "Audio"; en = "Sound" }
    panel_sysdm        = @{ it = "Proprietà del sistema"; en = "System Properties" }
    panel_region       = @{ it = "Area geografica"; en = "Region" }
    panel_time         = @{ it = "Data e ora"; en = "Date and Time" }
    panel_security     = @{ it = "Sicurezza e manutenzione"; en = "Security and Maintenance" }
    panel_firewall     = @{ it = "Windows Defender Firewall"; en = "Windows Defender Firewall" }
    panel_restore      = @{ it = "Ripristino configurazione di sistema"; en = "System Restore" }
    wu_recommended     = @{ it = "Consigliato"; en = "Recommended" }
    wu_default         = @{ it = "Predefinito di Windows"; en = "Windows default" }
    wu_disable         = @{ it = "Aggiornamenti spenti"; en = "Updates off" }
    wu_custom          = @{ it = "Personalizzato"; en = "Custom" }
    wuSub_recommended  = @{ it = "Sicurezza e stabilità insieme"; en = "Security and stability together" }
    wuSub_default      = @{ it = "Il controllo torna a Windows"; en = "Control goes back to Windows" }
    wuSub_disable      = @{ it = "Solo per usi particolari: niente aggiornamenti di sicurezza"; en = "For special uses only: no security updates" }
    wuList_recommended = @{ it = "Nuove versioni di Windows rinviate di 365 giorni;Aggiornamenti mensili rinviati di 4 giorni;Driver esclusi da Windows Update;Nessun riavvio automatico con un utente collegato"; en = "New Windows versions deferred by 365 days;Monthly updates deferred by 4 days;Drivers excluded from Windows Update;No automatic restart while a user is signed in" }
    wuList_default     = @{ it = "Toglie i criteri di Windows Update impostati;Rimette i servizi di aggiornamento come in origine;Riattiva le attività pianificate degli aggiornamenti"; en = "Removes the Windows Update policies that were set;Restores the update services to their original state;Re-enables the scheduled update tasks" }
    wuList_disable     = @{ it = "Aggiornamenti automatici spenti;Servizi e attività di aggiornamento fermi;Aggiornamenti già scaricati eliminati"; en = "Automatic updates off;Update services and tasks stopped;Downloaded updates deleted" }
    pn_ultimate        = @{ it = "Prestazioni eccellenti (Ultimate Performance)"; en = "Ultimate Performance" }
    pn_high            = @{ it = "Prestazioni elevate"; en = "High performance" }
    pn_balanced        = @{ it = "Bilanciato"; en = "Balanced" }
    pn_saver           = @{ it = "Risparmio energia"; en = "Power saver" }
    pd_ultimate        = @{ it = "Piano nascosto di Windows: nessun risparmio energetico, latenza minima."; en = "Hidden Windows plan: no power saving, minimum latency." }
    pd_bitsum          = @{ it = "Piano di Bitsum (Process Lasso): prestazioni CPU costanti."; en = "Bitsum plan (Process Lasso): steady CPU performance." }
    pd_high            = @{ it = "Piano standard di Windows ad alte prestazioni."; en = "Standard Windows high performance plan." }
    pd_balanced        = @{ it = "Piano predefinito di Windows. Usalo per tornare indietro."; en = "Default Windows plan. Use it to go back." }
    pd_saver           = @{ it = "Consumi minimi, prestazioni ridotte."; en = "Minimum power use, reduced performance." }
    pd_adamx           = @{ it = "Favorisce le prestazioni sul risparmio energetico."; en = "Favors performance over power saving." }
    pd_ancel           = @{ it = "Prestazioni massime, base Ultimate Performance."; en = "Maximum performance, based on Ultimate Performance." }
    pd_atlas           = @{ it = "Ottimizzato per le prestazioni massime (v0.4.2)."; en = "Tuned for maximum performance (v0.4.2)." }
    pd_calypto         = @{ it = "Disattiva il risparmio energetico per abbassare la latenza."; en = "Turns off power saving to lower latency." }
    pd_core            = @{ it = "Piano essenziale, poche modifiche mirate."; en = "Minimal plan, a few targeted changes." }
    pd_exmfree         = @{ it = "Più prestazioni e meno latenza; può alzare le temperature."; en = "More performance, less latency; may raise temperatures." }
    pd_framesyncboost  = @{ it = "Prestazioni massime e latenza minima, idle attivo."; en = "Maximum performance and minimum latency, idle kept on." }
    pd_hybred          = @{ it = "Latenza più bassa e prestazioni più alte."; en = "Lower latency and higher performance." }
    pd_kaisen          = @{ it = "Piano pensato per PC fisso."; en = "Plan designed for desktop PCs." }
    pd_khorvie         = @{ it = "Taglio prestazionale, molte voci modificate."; en = "Performance-oriented, many settings changed." }
    pd_kirby           = @{ it = "Prestazioni massime, poche voci."; en = "Maximum performance, few settings." }
    pd_kizzimo         = @{ it = "Il più aggressivo sulla latenza."; en = "The most aggressive on latency." }
    pd_lawliet         = @{ it = "Base bilanciata modificata, consumi più contenuti."; en = "Modified balanced base, lower power use." }
    pd_nexus           = @{ it = "Per il gioco, buone prestazioni su desktop."; en = "For gaming, good performance on desktops." }
    pd_powerx          = @{ it = "Input lag minimo. Può causare BSOD su alcune CPU AMD."; en = "Minimum input lag. May cause BSODs on some AMD CPUs." }
    pd_sapphire        = @{ it = "Piano di SapphireOS."; en = "SapphireOS plan." }
    pd_vtrl            = @{ it = "Impostato da VTRL Optimizer, base Ultimate Performance."; en = "Set by VTRL Optimizer, based on Ultimate Performance." }
    pd_xilly           = @{ it = "Incremento leggero rispetto al predefinito."; en = "A slight boost over the default." }
    pd_xos             = @{ it = "Piano della raccolta xOS."; en = "Plan from the xOS collection." }
    hkFirmware         = @{ it = "Firmware"; en = "Firmware" }
    pwRecBtn           = @{ it = "Usa i valori consigliati"; en = "Use recommended values" }
    pwDefBtn           = @{ it = "Torna ai valori di Windows"; en = "Back to Windows values" }
    pwAskRec           = @{ it = "Imposto i valori consigliati sul piano in uso. Le modifiche valgono subito. Procedo?"; en = "I'll set the recommended values on the plan in use. The changes apply right away. Go ahead?" }
    pwAskDef           = @{ it = "Riporto il piano in uso ai valori predefiniti di Windows. Le modifiche valgono subito. Procedo?"; en = "I'll put the plan in use back to the Windows default values. The changes apply right away. Go ahead?" }
    svcMissing         = @{ it = "Non presente su questo PC"; en = "Not on this PC" }
}

$script:LangCode = "it"
$script:Languages = @('it','en','es','de','fr','pl','pt','ro','ru')

# Testo nella lingua scelta; se manca, in inglese; se manca anche quello, in italiano.
function Get-Text($entry) {
    if ($null -eq $entry) { return $null }
    foreach ($c in @($script:LangCode, 'en', 'it')) {
        if ($entry.ContainsKey($c) -and $entry[$c]) { return $entry[$c] }
    }
    return $null
}

function T([string]$key) {
    if ($script:Msg.ContainsKey($key)) { return (Get-Text $script:Msg[$key]) }
    return $key
}

# Descrizione a comparsa di ogni voce. Il popup non eredita le risorse della
# pagina, quindi il colore della barretta gli si passa qui.
function Set-Tooltips {
    foreach ($cb in @($script:AllCheckBoxes) + @($script:LiveCheckBoxes)) {
        $entry = $script:Tips[[string]$cb.Name]
        $text = Get-Text $entry
        if (-not $text) { $cb.ToolTip = $null; continue }
        $tt = New-Object System.Windows.Controls.ToolTip
        $tt.Content = $text
        $pa = $cb.TryFindResource('PA')
        if ($null -ne $pa) { $tt.Resources['PA'] = $pa }
        $cb.ToolTip = $tt
    }
}

function Set-Language([string]$code) {
    if ($script:Languages -notcontains $code) { return }
    $script:LangCode = $code
    foreach ($name in $script:Loc.Keys) {
        $el = $window.FindName($name)
        if ($null -eq $el) { continue }
        $text = Get-Text $script:Loc[$name]
        if ($null -eq $text) { continue }
        if     ($el -is [System.Windows.Controls.TextBlock])                { $el.Text = $text }
        elseif ($el -is [System.Windows.Controls.HeaderedContentControl])   { $el.Header = $text }
        elseif ($el -is [System.Windows.Controls.ContentControl])           { $el.Content = $text }
    }
    $window.Title = T 'winTitle'
    if ($null -ne $txtProgressLabel -and -not $script:Running) { $txtProgressLabel.Text = T 'ready' }
    if (Get-Command Set-Tooltips -ErrorAction SilentlyContinue) { if ($script:AllCheckBoxes) { Set-Tooltips } }
    Update-PowerPlanLabel
    Show-StorageInventory
    # Show-PagIna esiste solo dopo il blocco della barra laterale: alla prima
    # chiamata di Set-Language non c'e' ancora.
    if (Get-Command Show-Page -ErrorAction SilentlyContinue) { Show-Page }
    if ($script:SectionPicks) { Update-SectionPickText }
    $window.Resources['BadgeActive'] = [string](T 'badgeActive')
    if (Get-Command Show-WuProfiles -ErrorAction SilentlyContinue) { Show-WuProfiles; Update-CurrentValues }
    if (Get-Command Update-RecStars -ErrorAction SilentlyContinue) { Update-RecStars }
    if (Get-Command Show-PlanList -ErrorAction SilentlyContinue) { Show-PlanList }
    # Menu del pannello MMCSS e decodifica della priorita': testi nella nuova lingua.
    if (Get-Command Set-MmGlobalItems -ErrorAction SilentlyContinue) { Set-MmGlobalItems; Read-Mmcss; Update-PsView }
}

# ------------------------------------------------------------------------------
# 4. RIFERIMENTI AI CONTROLLI
# ------------------------------------------------------------------------------
$cmbLang = E 'cmbLang'
$prgTweaks = E 'prgTweaks'; $txtProgressLabel = E 'txtProgressLabel'; $txtProgressCount = E 'txtProgressCount'
$txtSelectedCount = E 'txtSelectedCount'
$btnRun = E 'btnRun'; $btnUndo = E 'btnUndo'; $btnSelectAll = E 'btnSelectAll'; $btnDeselectAll = E 'btnDeselectAll'; $btnDetectActive = E 'btnDetectActive'
$btnSelectPage = E 'btnSelectPage'; $btnRecommended = E 'btnRecommended'
$chkRestorePoint = E 'chkRestorePoint'

# Prestazioni
$chkMMCSS = E 'chkMMCSS'; $chkPriority = E 'chkPriority'; $chkKernelMem = E 'chkKernelMem'
$chkKernelDpc = E 'chkKernelDpc'; $chkTimer = E 'chkTimer'; $chkPowerThrottling = E 'chkPowerThrottling'
$chkUSBSuspend = E 'chkUSBSuspend'; $chkNtfsPerf = E 'chkNtfsPerf'
$chkRamTweak = E 'chkRamTweak'; $cmbRamAmount = E 'cmbRamAmount'
$chkGameMode = E 'chkGameMode'; $chkFSO = E 'chkFSO'; $chkGameDVR = E 'chkGameDVR'
$chkHAGS = E 'chkHAGS'; $chkVisualFX = E 'chkVisualFX'
$chkApplyMPO = E 'chkApplyMPO'; $cmbMPO = E 'cmbMPO'
$chkVBS = E 'chkVBS'; $chkMitigations = E 'chkMitigations'
$lblPowerActive = E 'lblPowerActive'
$panPlans = E 'panPlans'; $btnRefreshPlans = E 'btnRefreshPlans'; $btnRemoveTestPlans = E 'btnRemoveTestPlans'

# Scheda video
$txtGpuDetected = E 'txtGpuDetected'; $btnDetectGpu = E 'btnDetectGpu'
$chkGpuTdr = E 'chkGpuTdr'; $chkGpuMsi = E 'chkGpuMsi'
$chkNvTelemetry = E 'chkNvTelemetry'; $chkNvGfe = E 'chkNvGfe'; $chkNvPerfMode = E 'chkNvPerfMode'
$chkNvUpdates = E 'chkNvUpdates'
$chkAmdUx = E 'chkAmdUx'; $chkAmdBloat = E 'chkAmdBloat'; $chkAmdUlps = E 'chkAmdUlps'
$chkIntelBloat = E 'chkIntelBloat'; $chkIntelTelemetry = E 'chkIntelTelemetry'
$chkIntelGfxPower = E 'chkIntelGfxPower'; $chkIntelDpst = E 'chkIntelDpst'
$txtCpuDetected = E 'txtCpuDetected'
$chkCpuIntelBoostPol = E 'chkCpuIntelBoostPol'; $chkCpuIntelHybrid = E 'chkCpuIntelHybrid'
$chkCpuAmdParking = E 'chkCpuAmdParking'; $chkCpuIdleOff = E 'chkCpuIdleOff'
$chkNvP2 = E 'chkNvP2'
$chkNvDrsPower = E 'chkNvDrsPower'
$chkNvLowLatency = E 'chkNvLowLatency'
$chkNvThreaded = E 'chkNvThreaded'
$chkNvTexPerf = E 'chkNvTexPerf'
$chkNvAniso = E 'chkNvAniso'
$chkNvShaderCache = E 'chkNvShaderCache'
$chkNvNoAnsel = E 'chkNvNoAnsel'
$chkNvDisplayPower = E 'chkNvDisplayPower'
$chkNvHdcp = E 'chkNvHdcp'
$chkNvPreempt = E 'chkNvPreempt'
$chkNvDynPstate = E 'chkNvDynPstate'
$chkNvLatency = E 'chkNvLatency'
$chkAmdAntiLag = E 'chkAmdAntiLag'
$chkAmdShaderCache = E 'chkAmdShaderCache'
$chkAmdTexPerf = E 'chkAmdTexPerf'
$chkAmdTess = E 'chkAmdTess'
$chkAmdFlipQueue = E 'chkAmdFlipQueue'
$chkAmdNoFrtc = E 'chkAmdNoFrtc'
$chkAmdStutter = E 'chkAmdStutter'
$chkAmdAspm = E 'chkAmdAspm'
$chkAmdPowerGating = E 'chkAmdPowerGating'
$chkAmdDma = E 'chkAmdDma'
$chkAmdPreempt = E 'chkAmdPreempt'
$btnShaderScan = E 'btnShaderScan'; $btnShaderClear = E 'btnShaderClear'; $txtShaderSize = E 'txtShaderSize'

# Menu Start e funzioni nascoste
$chkStartMorePins = E 'chkStartMorePins'; $chkStartHideRec = E 'chkStartHideRec'
$chkStartNoWeb = E 'chkStartNoWeb'; $chkStartNoAccount = E 'chkStartNoAccount'
$txtFeatId = E 'txtFeatId'; $cmbFeatState = E 'cmbFeatState'
$btnFeatApply = E 'btnFeatApply'; $btnFeatList = E 'btnFeatList'; $txtFeatList = E 'txtFeatList'
$chkFastStartup = E 'chkFastStartup'; $chkHibernation = E 'chkHibernation'
$chkS0Sleep = E 'chkS0Sleep'; $chkS3Sleep = E 'chkS3Sleep'; $chkDiskNoSleep = E 'chkDiskNoSleep'

# Privacy
$chkTelemetry = E 'chkTelemetry'; $chkTelemetryTasks = E 'chkTelemetryTasks'
$chkActivityHistory = E 'chkActivityHistory'; $chkLocationTracking = E 'chkLocationTracking'
$chkAdvertisingID = E 'chkAdvertisingID'; $chkTailoredExp = E 'chkTailoredExp'
$chkFeedback = E 'chkFeedback'; $chkErrorReporting = E 'chkErrorReporting'
$chkInkingTyping = E 'chkInkingTyping'; $chkWiFiSense = E 'chkWiFiSense'
$chkConsumerFeatures = E 'chkConsumerFeatures'; $chkStoreSearch = E 'chkStoreSearch'
$chkSuggestedContent = E 'chkSuggestedContent'; $chkLockScreenAds = E 'chkLockScreenAds'
$chkStartBing = E 'chkStartBing'; $chkStartRecs = E 'chkStartRecs'
$chkStartTracking = E 'chkStartTracking'; $chkFolderDiscovery = E 'chkFolderDiscovery'
$chkWindowsAI = E 'chkWindowsAI'; $chkEdgeDebloat = E 'chkEdgeDebloat'
$chkOneDriveRemove = E 'chkOneDriveRemove'; $chkOutlookNew = E 'chkOutlookNew'
$chkServicesManual = E 'chkServicesManual'; $chkDeliveryOpt = E 'chkDeliveryOpt'
$chkBitLocker = E 'chkBitLocker'; $chkWPBT = E 'chkWPBT'; $chkBackgroundApps = E 'chkBackgroundApps'
$chkTeredo = E 'chkTeredo'; $chkRDPWarnings = E 'chkRDPWarnings'
$chkRemoteAssistance = E 'chkRemoteAssistance'; $chkCompanionApps = E 'chkCompanionApps'
$chkDriverUpdates = E 'chkDriverUpdates'

# Interfaccia
$chkDarkTheme = E 'chkDarkTheme'; $chkFileExt = E 'chkFileExt'; $chkHiddenFiles = E 'chkHiddenFiles'
$chkLongPaths = E 'chkLongPaths'; $chkClassicMenu = E 'chkClassicMenu'
$chkExplorerThisPC = E 'chkExplorerThisPC'; $chkRemove3D = E 'chkRemove3D'
$chkRecycleConfirm = E 'chkRecycleConfirm'; $chkMenuDelay = E 'chkMenuDelay'
$chkTaskbarCenter = E 'chkTaskbarCenter'; $chkTaskbarSearch = E 'chkTaskbarSearch'
$chkTaskbarTaskView = E 'chkTaskbarTaskView'; $chkTaskbarWidgets = E 'chkTaskbarWidgets'
$chkTaskbarChat = E 'chkTaskbarChat'; $chkTaskbarEndTask = E 'chkTaskbarEndTask'
$chkBatteryPct = E 'chkBatteryPct'
$chkSettingsHome = E 'chkSettingsHome'; $chkWindowSnapping = E 'chkWindowSnapping'
$chkMouseAccel = E 'chkMouseAccel'; $chkNumLock = E 'chkNumLock'
$chkStickyKeys = E 'chkStickyKeys'; $chkScrollbars = E 'chkScrollbars'
$chkLockScreen = E 'chkLockScreen'; $chkLogonBlur = E 'chkLogonBlur'
$chkBSODVerbose = E 'chkBSODVerbose'; $chkLogonVerbose = E 'chkLogonVerbose'

# Rete
$chkApplyNetwork = E 'chkApplyNetwork'; $chkApplyDns = E 'chkApplyDns'; $btnFlushDns = E 'btnFlushDns'
$radTcpOptimal = E 'radTcpOptimal'; $radTcpDefault = E 'radTcpDefault'
$radTcpCurrent = E 'radTcpCurrent'; $radTcpCustom = E 'radTcpCustom'
$cmbDnsProvider = E 'cmbDnsProvider'
$cmbTcpAutoTuning = E 'cmbTcpAutoTuning'; $cmbScalingHeuristics = E 'cmbScalingHeuristics'
$cmbCongestionControl = E 'cmbCongestionControl'; $cmbRSS = E 'cmbRSS'; $cmbRSC = E 'cmbRSC'
$cmbTTL = E 'cmbTTL'; $cmbECN = E 'cmbECN'; $cmbTimestamps = E 'cmbTimestamps'
$cmbNetThrottling = E 'cmbNetThrottling'; $cmbSysResponsiveness = E 'cmbSysResponsiveness'
$cmbNagle = E 'cmbNagle'; $cmbHostPriority = E 'cmbHostPriority'; $cmbNetMemAlloc = E 'cmbNetMemAlloc'
$cmbPortAlloc = E 'cmbPortAlloc'; $cmbMaxConn = E 'cmbMaxConn'
$chkNetPowerSave = E 'chkNetPowerSave'; $chkDisableIPv6 = E 'chkDisableIPv6'

# Archiviazione
$btnDetectStorage = E 'btnDetectStorage'
$radStorageSSD = E 'radStorageSSD'; $radStorageHDD = E 'radStorageHDD'; $chkStorageProfile = E 'chkStorageProfile'
$btnTrimNow = E 'btnTrimNow'; $btnOptimizeNow = E 'btnOptimizeNow'
$btnEmptyRecycle = E 'btnEmptyRecycle'; $btnCleanUpdates = E 'btnCleanUpdates'
$chkDiskCleanup = E 'chkDiskCleanup'; $chkTempCleanup = E 'chkTempCleanup'; $chkSmartChkdsk = E 'chkSmartChkdsk'
$chkStorageSense = E 'chkStorageSense'; $chkReservedStorage = E 'chkReservedStorage'

# Avanzate
$chkSvcSysMain = E 'chkSvcSysMain'; $chkSvcDiag = E 'chkSvcDiag'; $chkSvcErrors = E 'chkSvcErrors'
$chkSvcPca = E 'chkSvcPca'; $chkSvcDiscovery = E 'chkSvcDiscovery'; $chkSvcSensors = E 'chkSvcSensors'
$chkSvcSmartCard = E 'chkSvcSmartCard'; $chkSvcParental = E 'chkSvcParental'; $chkSvcHyperV = E 'chkSvcHyperV'
$chkSvcPrint = E 'chkSvcPrint'; $chkSvcSearch = E 'chkSvcSearch'; $chkSvcRemote = E 'chkSvcRemote'
$chkSvcBiometric = E 'chkSvcBiometric'; $chkSvcTouch = E 'chkSvcTouch'
$chkTaskExtra = E 'chkTaskExtra'; $chkTaskMaint = E 'chkTaskMaint'; $chkTaskDefrag = E 'chkTaskDefrag'
$chkPrefetch = E 'chkPrefetch'; $chkFth = E 'chkFth'; $chkAppCompat = E 'chkAppCompat'
$chkSvcHostSplit = E 'chkSvcHostSplit'; $chkMemCompression = E 'chkMemCompression'
$chkWuNoStore = E 'chkWuNoStore'; $chkWuProfile = E 'chkWuProfile'
$chkAdvUtc = E 'chkAdvUtc'; $chkAdvRazer = E 'chkAdvRazer'; $chkAdvLogi = E 'chkAdvLogi'; $chkIPv4Pref = E 'chkIPv4Pref'
$chkBootQuiet = E 'chkBootQuiet'; $chkBootMenu = E 'chkBootMenu'; $chkBootTimeout = E 'chkBootTimeout'
$chkBootDynTick = E 'chkBootDynTick'; $chkBootTsc = E 'chkBootTsc'; $btnBootReset = E 'btnBootReset'
$chkAppxBloat = E 'chkAppxBloat'; $chkAppxXbox = E 'chkAppxXbox'; $chkAppxProvision = E 'chkAppxProvision'
$chkSecSmartScreen = E 'chkSecSmartScreen'; $chkSecSpectre = E 'chkSecSpectre'; $chkSecDefenderIdle = E 'chkSecDefenderIdle'

# ------------------------------------------------------------------------------
# 5. REGISTRO DELLE OPERAZIONI E AVANZAMENTO
# ------------------------------------------------------------------------------
$script:OkCount = 0; $script:WarnCount = 0; $script:SkipCount = 0
$script:Running = $false

function Write-Log($msg) {
    # Il registro dettagliato resta nella finestra di PowerShell. Nessuna emoji:
    # su un terminale non UTF-8 la scrittura fallirebbe e la GUI andrebbe in errore.
    if     ($msg -match '^\[OK\]')      { $script:OkCount++ }
    elseif ($msg -match '^\[ERRORE\]')  { $script:WarnCount++ }
    elseif ($msg -match '^\[AVVISO\]')  { $script:WarnCount++ }
    elseif ($msg -match '^\[SALTATO\]') { $script:SkipCount++ }

    $color = switch -Wildcard ($msg) {
        "*[ERRORE]*"  { "Red"; break }
        "*[AVVISO]*"  { "Yellow"; break }
        "*[SALTATO]*" { "DarkGray"; break }
        "*[OK]*"      { "Green"; break }
        default       { "Gray" }
    }
    Write-Host $msg -ForegroundColor $color
}

function Update-Progress {
    param([int]$Current, [int]$Total, [string]$Label)
    if ($null -eq $prgTweaks) { return }
    if ($Total -le 0) { $Total = 1 }
    $prgTweaks.Maximum = $Total
    $prgTweaks.Value = $Current
    if ($null -ne $txtProgressLabel) { $txtProgressLabel.Text = $Label }
    if ($null -ne $txtProgressCount) { $txtProgressCount.Text = "$Current / $Total" }
    if ($script:Running -and (Get-Command Set-Activity -ErrorAction SilentlyContinue)) {
        Set-Activity 'run' ((T 'actRun') -f $Label) ([Math]::Round(100 * $Current / $Total))
    }
    # Forza il ridisegno della finestra durante l'esecuzione sincrona.
    [System.Windows.Threading.Dispatcher]::CurrentDispatcher.Invoke([Action]{}, [System.Windows.Threading.DispatcherPriority]::Background)
}

# ------------------------------------------------------------------------------
# 6. AIUTI PER LE MODIFICHE DI SISTEMA
# ------------------------------------------------------------------------------
# Le chiavi dei criteri (Policies\...) spesso non esistono su un'installazione
# pulita: senza crearle prima, Set-ItemProperty fallisce e il tweak non viene
# applicato. Set-Reg crea sempre la chiave mancante.
function Set-Reg {
    param(
        [Parameter(Mandatory)][string]$Path,
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)]$Value,
        [ValidateSet('DWord','QWord','String','ExpandString','Binary')][string]$Type = 'DWord',
        [string]$Label
    )
    if ([string]::IsNullOrWhiteSpace($Label)) { $Label = "$Path\$Name" }
    try {
        if (-not (Test-Path -LiteralPath $Path)) { New-Item -Path $Path -Force -ErrorAction Stop | Out-Null }
        $current = $null
        try { $current = (Get-ItemProperty -LiteralPath $Path -Name $Name -ErrorAction Stop).$Name } catch {}
        if ($null -ne $current -and [string]$current -eq [string]$Value) {
            Write-Log "[SALTATO] $Label - gia' configurato."
            return $true
        }
        New-ItemProperty -LiteralPath $Path -Name $Name -Value $Value -PropertyType $Type -Force -ErrorAction Stop | Out-Null
        Write-Log "[OK] $Label"
        return $true
    } catch {
        Write-Log "[ERRORE] $Label - $($_.Exception.Message)"
        return $false
    }
}

function Remove-Reg {
    param([Parameter(Mandatory)][string]$Path,[Parameter(Mandatory)][string]$Name,[string]$Label)
    if ([string]::IsNullOrWhiteSpace($Label)) { $Label = "$Path\$Name" }
    try {
        Remove-ItemProperty -LiteralPath $Path -Name $Name -Force -ErrorAction Stop
        Write-Log "[OK] $Label - rimosso."
    } catch {
        Write-Log "[SALTATO] $Label - non presente."
    }
}

function Set-Svc {
    param(
        [Parameter(Mandatory)][string]$Name,
        [Parameter(Mandatory)][ValidateSet('Automatic','Manual','Disabled')][string]$StartupType,
        [string]$Label
    )
    if ([string]::IsNullOrWhiteSpace($Label)) { $Label = $Name }
    try {
        $svc = Get-CimInstance Win32_Service -Filter "Name='$Name'" -ErrorAction Stop
        if (-not $svc) { Write-Log "[SALTATO] $Label - servizio non presente."; return $true }
        if ($svc.StartMode -eq $StartupType) { Write-Log "[SALTATO] $Label - gia' su $StartupType."; return $true }
        Set-Service -Name $Name -StartupType $StartupType -ErrorAction Stop
        Write-Log "[OK] $Label - avvio $StartupType."
        return $true
    } catch {
        Write-Log "[AVVISO] $Label - Windows ha negato la modifica; gli altri tweak proseguono."
        return $false
    }
}

# Applica un valore a tutte le sottochiavi delle interfacce di rete.
function Set-RegAllInterfaces {
    param([string]$Name,$Value,[string]$Label)
    $base = 'HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces'
    $n = 0
    Get-ChildItem $base -ErrorAction SilentlyContinue | ForEach-Object {
        try { New-ItemProperty -LiteralPath $_.PSPath -Name $Name -Value $Value -PropertyType DWord -Force -ErrorAction Stop | Out-Null; $n++ } catch {}
    }
    Write-Log "[OK] $Label - $n interfacce aggiornate."
}

function Get-RegOrNull {
    param([string]$Path,[string]$Name)
    try { return (Get-ItemProperty -LiteralPath $Path -Name $Name -ErrorAction Stop).$Name } catch { return $null }
}

function Test-Reg {
    param([string]$Path,[string]$Name,[object]$Expected)
    try {
        if (-not (Test-Path -LiteralPath $Path)) { return $false }
        $v = (Get-ItemProperty -LiteralPath $Path -Name $Name -ErrorAction Stop).$Name
        return ([string]$v -eq [string]$Expected)
    } catch { return $false }
}

# ------------------------------------------------------------------------------
# 7. ARCHIVIAZIONE — rilevamento unita' e spazio
# ------------------------------------------------------------------------------
$script:DetectedStorageType = "Unknown"

function New-DiskBrush([string]$hex) { New-Object System.Windows.Media.SolidColorBrush ([System.Windows.Media.ColorConverter]::ConvertFromString($hex)) }

function New-DiskPill([string]$text, [string]$fg, [string]$bg) {
    $b = New-Object System.Windows.Controls.Border
    $b.CornerRadius = 6; $b.Padding = '7,2,7,2'; $b.Margin = '0,0,8,0'; $b.VerticalAlignment = 'Center'
    $b.Background = New-DiskBrush $bg
    $tb = New-Object System.Windows.Controls.TextBlock
    $tb.Text = $text; $tb.FontSize = 10.5; $tb.FontWeight = 'SemiBold'; $tb.Foreground = New-DiskBrush $fg
    $b.Child = $tb
    return $b
}

function Format-DiskSize([double]$bytes) {
    if ($bytes -ge 1TB) { return ('{0:N2} TB' -f ($bytes / 1TB)) }
    return ('{0:N1} GB' -f ($bytes / 1GB))
}

# Tipo di un disco fisico: NVMe, SSD, HDD o USB.
function Get-DiskKind($d) {
    if ($d.BusType -eq 'USB') { return 'USB' }
    if ($d.BusType -eq 'NVMe') { return 'NVMe' }
    if ($d.MediaType -eq 'SSD') { return 'SSD' }
    if ($d.MediaType -eq 'HDD') { return 'HDD' }
    return '?'
}

# Una scheda per ogni disco, con i volumi che contiene: niente righe doppie,
# niente testo a spaziatura fissa.
function Show-StorageInventory {
    $pan = E 'panDisks'
    if ($null -eq $pan) { return }
    $pan.Children.Clear()
    try { $disks = @(Get-PhysicalDisk -ErrorAction Stop | Where-Object { $_.OperationalStatus -ne 'No Media' } | Sort-Object { [int]$_.DeviceId }) } catch { $disks = @() }
    try { $parts = @(Get-Partition -ErrorAction Stop | Where-Object { $_.DriveLetter }) } catch { $parts = @() }
    try { $vols = @(Get-Volume -ErrorAction Stop | Where-Object { $_.DriveLetter -and $_.Size -gt 0 }) } catch { $vols = @() }

    $sysLetter = $env:SystemDrive.TrimEnd(':')
    $sysDiskNum = ($parts | Where-Object { [string]$_.DriveLetter -eq $sysLetter } | Select-Object -First 1).DiskNumber
    $disks = @($disks | Sort-Object @{ Expression = { [string]$_.DeviceId -ne [string]$sysDiskNum } }, @{ Expression = { [int]$_.DeviceId } })
    $script:SystemDiskKind = '?'
    $script:SystemDiskName = ''

    if ($disks.Count -eq 0) {
        $tb = New-Object System.Windows.Controls.TextBlock
        $tb.Text = T 'noDisks'; $tb.Style = $window.FindResource('SubTitle')
        [void]$pan.Children.Add($tb)
    }

    $types = @()
    foreach ($d in $disks) {
        $kind = Get-DiskKind $d
        if ($kind -in @('NVMe','SSD')) { $types += 'SSD' } elseif ($kind -eq 'HDD') { $types += 'HDD' }
        $isSys = ([string]$d.DeviceId -eq [string]$sysDiskNum)
        if ($isSys) { $script:SystemDiskKind = $kind; $script:SystemDiskName = [string]$d.FriendlyName }

        $card = New-Object System.Windows.Controls.Border
        $card.Style = $window.FindResource('GlassInner')
        $card.Margin = '0,0,0,8'; $card.Padding = '14,11,14,12'
        $sp = New-Object System.Windows.Controls.StackPanel

        $head = New-Object System.Windows.Controls.Grid
        foreach ($w in @('Auto', '*', 'Auto')) {
            $cd = New-Object System.Windows.Controls.ColumnDefinition
            $cd.Width = if ($w -eq '*') { New-Object System.Windows.GridLength(1, [System.Windows.GridUnitType]::Star) } else { [System.Windows.GridLength]::Auto }
            $head.ColumnDefinitions.Add($cd)
        }
        $pillColor = switch ($kind) { 'NVMe' { @('#FFA5B4FC', '#26818CF8') } 'SSD' { @('#FF7DD3FC', '#2638BDF8') } 'HDD' { @('#FFFCD34D', '#26F59E0B') } 'USB' { @('#FFC4C4CC', '#1FFFFFFF') } default { @('#FFC4C4CC', '#1FFFFFFF') } }
        $pills = New-Object System.Windows.Controls.StackPanel; $pills.Orientation = 'Horizontal'
        [void]$pills.Children.Add((New-DiskPill $kind $pillColor[0] $pillColor[1]))
        if ($isSys) { [void]$pills.Children.Add((New-DiskPill (T 'diskSystem') '#FF2ED3A7' '#262ED3A7')) }
        [void]$head.Children.Add($pills)

        $name = New-Object System.Windows.Controls.TextBlock
        $name.Text = [string]$d.FriendlyName; $name.FontWeight = 'SemiBold'; $name.FontSize = 13
        $name.Foreground = New-DiskBrush '#FFF2F2F5'; $name.VerticalAlignment = 'Center'; $name.TextTrimming = 'CharacterEllipsis'
        [System.Windows.Controls.Grid]::SetColumn($name, 1); [void]$head.Children.Add($name)

        $right = New-Object System.Windows.Controls.StackPanel; $right.Orientation = 'Horizontal'; $right.VerticalAlignment = 'Center'
        $healthy = ($d.HealthStatus -eq 'Healthy')
        $dot = New-Object System.Windows.Shapes.Ellipse; $dot.Width = 7; $dot.Height = 7; $dot.Margin = '10,0,6,0'; $dot.VerticalAlignment = 'Center'
        $dot.Fill = New-DiskBrush $(if ($healthy) { '#FF2ED3A7' } else { '#FFFFB86B' })
        $dot.ToolTip = if ($healthy) { T 'diskHealthy' } else { T 'diskWarning' }
        $size = New-Object System.Windows.Controls.TextBlock
        $size.Text = Format-DiskSize ([double]$d.Size); $size.Foreground = New-DiskBrush '#FFA1A1AA'; $size.FontSize = 12
        [void]$right.Children.Add($size); [void]$right.Children.Add($dot)
        [System.Windows.Controls.Grid]::SetColumn($right, 2); [void]$head.Children.Add($right)
        [void]$sp.Children.Add($head)

        foreach ($p in @($parts | Where-Object { [string]$_.DiskNumber -eq [string]$d.DeviceId } | Sort-Object DriveLetter)) {
            $v = $vols | Where-Object { [string]$_.DriveLetter -eq [string]$p.DriveLetter } | Select-Object -First 1
            if ($null -eq $v) { continue }
            $used = if ($v.Size -gt 0) { 1 - ($v.SizeRemaining / $v.Size) } else { 0 }
            $row = New-Object System.Windows.Controls.Grid
            $row.Margin = '0,10,0,0'
            foreach ($w in @(34, '*', 'Auto')) {
                $cd = New-Object System.Windows.Controls.ColumnDefinition
                $cd.Width = if ($w -eq '*') { New-Object System.Windows.GridLength(1, [System.Windows.GridUnitType]::Star) } elseif ($w -eq 'Auto') { [System.Windows.GridLength]::Auto } else { New-Object System.Windows.GridLength($w) }
                $row.ColumnDefinitions.Add($cd)
            }
            $letter = New-Object System.Windows.Controls.TextBlock
            $letter.Text = "$($p.DriveLetter):"; $letter.FontWeight = 'Bold'; $letter.Foreground = $window.FindResource('TextMain'); $letter.VerticalAlignment = 'Center'
            [void]$row.Children.Add($letter)
            $bar = New-Object System.Windows.Controls.ProgressBar
            $bar.Minimum = 0; $bar.Maximum = 100; $bar.Value = [math]::Round($used * 100); $bar.Height = 6; $bar.VerticalAlignment = 'Center'
            if ($used -gt 0.9) { $bar.Foreground = New-DiskBrush '#FFF87171' }
            [System.Windows.Controls.Grid]::SetColumn($bar, 1); [void]$row.Children.Add($bar)
            $free = New-Object System.Windows.Controls.TextBlock
            $free.Text = (T 'volFree') -f (Format-DiskSize ([double]$v.SizeRemaining)), (Format-DiskSize ([double]$v.Size))
            $free.Foreground = New-DiskBrush '#FFA1A1AA'; $free.FontSize = 11.5; $free.Margin = '12,0,0,0'; $free.VerticalAlignment = 'Center'
            [System.Windows.Controls.Grid]::SetColumn($free, 2); [void]$row.Children.Add($free)
            if ($v.FileSystemLabel) { $row.ToolTip = [string]$v.FileSystemLabel }
            [void]$sp.Children.Add($row)
        }
        $card.Child = $sp
        [void]$pan.Children.Add($card)
    }

    if ($types -contains 'SSD' -and $types -contains 'HDD') { $script:DetectedStorageType = 'Mixed' }
    elseif ($types -contains 'SSD') { $script:DetectedStorageType = 'SSD' }
    elseif ($types -contains 'HDD') { $script:DetectedStorageType = 'HDD' }
    else { $script:DetectedStorageType = 'Unknown' }

    # Profilo consigliato: conta il disco dove sta Windows.
    $hint = E 'lblProfileHint'
    $ssdText = Get-Text $script:Loc['radStorageSSD']; $hddText = Get-Text $script:Loc['radStorageHDD']
    $radStorageSSD.Content = $ssdText; $radStorageHDD.Content = $hddText
    if ($script:SystemDiskKind -in @('NVMe','SSD')) {
        $hint.Text = (T 'profileSysSsd') -f $script:SystemDiskKind, $script:SystemDiskName
        $radStorageSSD.Content = "$ssdText  $(T 'recommendedTag')"
    } elseif ($script:SystemDiskKind -eq 'HDD') {
        $hint.Text = (T 'profileSysHdd') -f $script:SystemDiskName
        $radStorageHDD.Content = "$hddText  $(T 'recommendedTag')"
    } else {
        $hint.Text = T 'profileSysUnknown'
    }
}

# Il profilo entra nella coda appena lo scegli; un secondo clic lo toglie.
foreach ($rb in @($radStorageSSD, $radStorageHDD)) {
    $rb.IsChecked = $false
    $rb.Add_PreviewMouseLeftButtonDown({
        if ($this.IsChecked -eq $true) {
            $this.IsChecked = $false
            $chkStorageProfile.IsChecked = $false
            $_.Handled = $true
        }
    })
    $rb.Add_Checked({ $chkStorageProfile.IsChecked = $true })
}

$btnDetectStorage.Add_Click({
    Show-StorageInventory
    Write-Log "[INFO] Rilevamento archiviazione: $($script:DetectedStorageType)."
})

# ------------------------------------------------------------------------------
# 8. AZIONI IMMEDIATE DELLA SCHEDA ARCHIVIAZIONE
# ------------------------------------------------------------------------------
$btnTrimNow.Add_Click({
    Write-Log "[STORAGE] TRIM in corso..."
    try {
        Get-Volume | Where-Object { $_.DriveLetter -and $_.DriveType -eq 'Fixed' } | ForEach-Object {
            Optimize-Volume -DriveLetter $_.DriveLetter -ReTrim -ErrorAction SilentlyContinue | Out-Null
        }
        Write-Log "[OK] TRIM completato sulle unita' disponibili."
    } catch { Write-Log "[ERRORE] TRIM: $($_.Exception.Message)" }
    Show-StorageInventory
})

$btnOptimizeNow.Add_Click({
    Write-Log "[STORAGE] Ottimizzazione di C: in corso (puo' richiedere diversi minuti)..."
    try {
        defrag.exe C: /O /U | Out-Null
        Write-Log "[OK] Ottimizzazione di C: completata."
    } catch { Write-Log "[ERRORE] Ottimizzazione: $($_.Exception.Message)" }
    Show-StorageInventory
})

$btnEmptyRecycle.Add_Click({
    if (-not (Show-Dialog (T 'confirmTitle') (T 'emptyRecycleAsk') 'danger')) { return }
    try {
        Clear-RecycleBin -Force -ErrorAction Stop
        Write-Log "[OK] Cestino svuotato."
    } catch { Write-Log "[AVVISO] Cestino: $($_.Exception.Message)" }
    Show-StorageInventory
})

$btnCleanUpdates.Add_Click({
    Write-Log "[STORAGE] Pulizia della cache di Windows Update..."
    try {
        Stop-Service -Name wuauserv -Force -ErrorAction SilentlyContinue
        Stop-Service -Name bits -Force -ErrorAction SilentlyContinue
        $sd = "$env:SystemRoot\SoftwareDistribution\Download"
        if (Test-Path $sd) {
            Get-ChildItem -LiteralPath $sd -Force -ErrorAction SilentlyContinue |
                Remove-Item -Recurse -Force -ErrorAction SilentlyContinue
        }
        Start-Service -Name bits -ErrorAction SilentlyContinue
        Start-Service -Name wuauserv -ErrorAction SilentlyContinue
        Write-Log "[OK] Cache di Windows Update eliminata."
    } catch { Write-Log "[ERRORE] Cache di Windows Update: $($_.Exception.Message)" }
    Show-StorageInventory
})

# ------------------------------------------------------------------------------
# 9. PIANI DI ALIMENTAZIONE
# ------------------------------------------------------------------------------
function Update-PowerPlanLabel {
    if ($null -eq $lblPowerActive) { return }
    try {
        $out = (powercfg /getactivescheme) -join ' '
        $m = [regex]::Match($out, '\(([^\)]+)\)\s*$')
        $name = if ($m.Success) { $m.Groups[1].Value } else { $out.Trim() }
        $lblPowerActive.Text = "$(T 'activePlan') $name"
    } catch { $lblPowerActive.Text = "$(T 'activePlan') ?" }
}


# ------------------------------------------------------------------------------
# 10. PROFILI TCP
# ------------------------------------------------------------------------------
$script:TcpCombos = @()

function Set-TcpControlsState($enabled) {
    foreach ($cmb in $script:TcpCombos) { if ($null -ne $cmb) { $cmb.IsEnabled = $enabled } }
}

function Select-TcpValue {
    param([Parameter(Mandatory)]$ComboBox,[Parameter(Mandatory)][string]$Value)
    foreach ($item in $ComboBox.Items) {
        if ([string]$item.Content -ieq $Value) { $ComboBox.SelectedItem = $item; return }
    }
}

function Show-CurrentTcpSettings {
    # Legge lo stato reale del sistema. La variabile del percorso ServiceProvider
    # NON puo' chiamarsi $host: e' una variabile automatica di PowerShell in sola
    # lettura e l'assegnazione interrompeva l'intera funzione.
    $tcpGlobal = (netsh int tcp show global 2>$null) -join "`n"
    $auto = [regex]::Match($tcpGlobal, '(?im)(?:auto.?tuning|ottimizzazione automatica)[^:]*:\s*([^\r\n]+)')
    if ($auto.Success) { Select-TcpValue $cmbTcpAutoTuning $auto.Groups[1].Value.Trim().ToLowerInvariant() }
    $rss = [regex]::Match($tcpGlobal, '(?im)(?:receive-side scaling|scalabilit.{0,3} lato ricezione)[^:]*:\s*([^\r\n]+)')
    if ($rss.Success) { Select-TcpValue $cmbRSS $rss.Groups[1].Value.Trim().ToLowerInvariant() }
    $rsc = [regex]::Match($tcpGlobal, '(?im)(?:receive segment coalescing|coalescenza segmenti ricevuti)[^:]*:\s*([^\r\n]+)')
    if ($rsc.Success) { Select-TcpValue $cmbRSC $rsc.Groups[1].Value.Trim().ToLowerInvariant() }
    $ecn = [regex]::Match($tcpGlobal, '(?im)(?:ecn capability|funzionalit.{0,3} ecn)[^:]*:\s*([^\r\n]+)')
    if ($ecn.Success) { Select-TcpValue $cmbECN $ecn.Groups[1].Value.Trim().ToLowerInvariant() }
    $ts = [regex]::Match($tcpGlobal, '(?im)(?:timestamps|timestamp)[^:]*:\s*([^\r\n]+)')
    if ($ts.Success) { Select-TcpValue $cmbTimestamps $ts.Groups[1].Value.Trim().ToLowerInvariant() }

    $heuristics = (netsh int tcp show heuristics 2>$null) -join "`n"
    if     ($heuristics -match '(?im)(?:disabled|disabilitat)') { Select-TcpValue $cmbScalingHeuristics 'disabled' }
    elseif ($heuristics -match '(?im)(?:enabled|abilitat)')     { Select-TcpValue $cmbScalingHeuristics 'enabled' }

    $tcpParams = 'HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters'
    $ttl = Get-RegOrNull $tcpParams 'DefaultTTL'
    if ($ttl -eq 64 -or $ttl -eq 128) { Select-TcpValue $cmbTTL ([string]$ttl) }

    $sysProfile = 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion\Multimedia\SystemProfile'
    $throttling = Get-RegOrNull $sysProfile 'NetworkThrottlingIndex'
    if ($throttling -eq 4294967295 -or $throttling -eq -1) { Select-TcpValue $cmbNetThrottling 'disabled: ffffffff' }
    else { Select-TcpValue $cmbNetThrottling 'default: 10' }

    $resp = Get-RegOrNull $sysProfile 'SystemResponsiveness'
    if     ($resp -eq 10) { Select-TcpValue $cmbSysResponsiveness 'optimal: 10' }
    elseif ($resp -eq 0)  { Select-TcpValue $cmbSysResponsiveness 'gaming: 0' }
    elseif ($resp -eq 20) { Select-TcpValue $cmbSysResponsiveness 'default: 20' }

    $interfaces = @(Get-ChildItem 'HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\Interfaces' -ErrorAction SilentlyContinue)
    $nagleOff = $interfaces.Count -gt 0 -and (@($interfaces | Where-Object {
        (Get-RegOrNull $_.PSPath 'TcpAckFrequency') -eq 1 -and (Get-RegOrNull $_.PSPath 'TCPNoDelay') -eq 1
    }).Count -eq $interfaces.Count)
    if ($nagleOff) { Select-TcpValue $cmbNagle 'disabled: 1' } else { Select-TcpValue $cmbNagle 'enabled: 0' }

    $spPath = 'HKLM:\SYSTEM\CurrentControlSet\Services\Tcpip\Parameters\ServiceProvider'
    $hostOptimal = (Get-RegOrNull $spPath 'LocalPriority') -eq 4 -and (Get-RegOrNull $spPath 'HostPriority') -eq 5 -and
                   (Get-RegOrNull $spPath 'DnsPriority') -eq 6 -and (Get-RegOrNull $spPath 'NetbtPriority') -eq 7
    if ($hostOptimal) { Select-TcpValue $cmbHostPriority 'Optimal (4-5-6-7)' } else { Select-TcpValue $cmbHostPriority 'Default Windows' }

    $memPath = 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management'
    $memOptimal = (Get-RegOrNull $memPath 'LargeSystemCache') -eq 1 -and (Get-RegOrNull $memPath 'Size') -eq 3
    if ($memOptimal) { Select-TcpValue $cmbNetMemAlloc 'Optimal (1 / 3)' } else { Select-TcpValue $cmbNetMemAlloc 'Default Windows' }

    $portsOptimal = (Get-RegOrNull $tcpParams 'MaxUserPort') -eq 65534 -and (Get-RegOrNull $tcpParams 'TcpTimedWaitDelay') -eq 30
    if ($portsOptimal) { Select-TcpValue $cmbPortAlloc 'Max 65534 / Wait 30s' } else { Select-TcpValue $cmbPortAlloc 'Default Windows' }

    $maxConn = Get-RegOrNull 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Internet Settings' 'MaxConnectionsPerServer'
    if     ($maxConn -eq 10) { Select-TcpValue $cmbMaxConn '10 Connections' }
    elseif ($maxConn -eq 16) { Select-TcpValue $cmbMaxConn '16 Connections' }
    else                     { Select-TcpValue $cmbMaxConn 'Default (2)' }
}

$script:TcpCombos = @(
    $cmbTcpAutoTuning, $cmbScalingHeuristics, $cmbCongestionControl, $cmbRSS, $cmbRSC,
    $cmbTTL, $cmbECN, $cmbTimestamps, $cmbNetThrottling, $cmbSysResponsiveness,
    $cmbNagle, $cmbHostPriority, $cmbNetMemAlloc, $cmbPortAlloc, $cmbMaxConn
)

$radTcpOptimal.Add_Click({
    Set-TcpControlsState $false
    $cmbTcpAutoTuning.SelectedIndex = 0; $cmbScalingHeuristics.SelectedIndex = 0
    $cmbCongestionControl.SelectedIndex = 0; $cmbRSS.SelectedIndex = 0; $cmbRSC.SelectedIndex = 0
    $cmbTTL.SelectedIndex = 0; $cmbECN.SelectedIndex = 0; $cmbTimestamps.SelectedIndex = 0
    $cmbNetThrottling.SelectedIndex = 0; $cmbSysResponsiveness.SelectedIndex = 0
    $cmbNagle.SelectedIndex = 0; $cmbHostPriority.SelectedIndex = 0
    $cmbNetMemAlloc.SelectedIndex = 0; $cmbPortAlloc.SelectedIndex = 0; $cmbMaxConn.SelectedIndex = 0
})

$radTcpDefault.Add_Click({
    Set-TcpControlsState $false
    $cmbTcpAutoTuning.SelectedIndex = 0; $cmbScalingHeuristics.SelectedIndex = 1
    $cmbCongestionControl.SelectedIndex = 0; $cmbRSS.SelectedIndex = 0; $cmbRSC.SelectedIndex = 1
    $cmbTTL.SelectedIndex = 1; $cmbECN.SelectedIndex = 1; $cmbTimestamps.SelectedIndex = 0
    $cmbNetThrottling.SelectedIndex = 1; $cmbSysResponsiveness.SelectedIndex = 2
    $cmbNagle.SelectedIndex = 1; $cmbHostPriority.SelectedIndex = 1
    $cmbNetMemAlloc.SelectedIndex = 1; $cmbPortAlloc.SelectedIndex = 1; $cmbMaxConn.SelectedIndex = 2
})

$radTcpCurrent.Add_Click({ Set-TcpControlsState $false; Show-CurrentTcpSettings })
$radTcpCustom.Add_Click({ Show-CurrentTcpSettings; Set-TcpControlsState $true })
Set-TcpControlsState $false

$btnFlushDns.Add_Click({
    try {
        ipconfig /flushdns | Out-Null
        Clear-DnsClientCache -ErrorAction SilentlyContinue
        Write-Log "[OK] Cache DNS svuotata."
    } catch { Write-Log "[ERRORE] Cache DNS: $($_.Exception.Message)" }
})

# ------------------------------------------------------------------------------
# 11. RACCOLTA DELLE CHECKBOX
# ------------------------------------------------------------------------------
function Get-CheckBoxesFromTree($parent) {
    $found = @()
    if ($null -eq $parent) { return $found }
    foreach ($child in [System.Windows.LogicalTreeHelper]::GetChildren($parent)) {
        if ($child -is [System.Windows.Controls.CheckBox]) { $found += $child }
        if ($child -is [System.Windows.DependencyObject]) { $found += Get-CheckBoxesFromTree $child }
    }
    return $found
}

# Le caselle con Tag «live» agiscono appena le tocchi: restano fuori dalla coda
# di «Applica», dal conteggio e da «Seleziona tutto».
$script:LiveCheckBoxes = @(Get-CheckBoxesFromTree $window | Where-Object { [string]$_.Tag -eq 'live' })
$script:AllCheckBoxes = @(Get-CheckBoxesFromTree $window | Where-Object { [string]$_.Tag -ne 'live' })

# Voci della pagina Avanzate: servono a parte per la seconda conferma e per
# tenerle fuori da «Seleziona tutto». Qui si tolgono pezzi di Windows, e la
# scelta deve restare una per una.
$script:AdvancedCheckBoxes = @(Get-CheckBoxesFromTree (E 'pageAdv'))

# Voci che «Seleziona tutto» non deve toccare: manutenzione, interruttori di
# ambito (rete, MPO, DNS, profilo disco), i tweak marcati come rischiosi e
# tutta la pagina Avanzate.
$script:ExcludedFromSelectAll = @(@(
    $chkRestorePoint, $chkDiskCleanup, $chkTempCleanup, $chkSmartChkdsk,
    $chkStorageProfile, $chkWuProfile, $chkApplyNetwork, $chkApplyDns, $chkApplyMPO
) + $script:AdvancedCheckBoxes | Where-Object { $null -ne $_ })

$script:SelectableCheckBoxes = @(
    $script:AllCheckBoxes | Where-Object {
        ($script:ExcludedFromSelectAll -notcontains $_) -and ([string]$_.Tag -ne 'risky')
    }
)

# ------------------------------------------------------------------------------
# 11b. SELEZIONE DI UNA SEZIONE
# ------------------------------------------------------------------------------
# Nelle pagine con tante voci, accanto al titolo di ogni scheda con almeno
# quattro caselle c'e' una casella piccola che le sceglie tutte. Niente sulle
# pagine a interruttore (hanno «Applica consigliati»), su Rete e su Avanzate,
# dove le voci si scelgono una per una.
$script:SectionPicks = New-Object System.Collections.ArrayList
$script:SectionSync = $false

function Update-SectionPick($sp) {
    $on = @($sp.Items | Where-Object { $_.IsEnabled })
    $script:SectionSync = $true
    $sp.Box.IsChecked = ($on.Count -gt 0) -and (@($on | Where-Object { $_.IsChecked -ne $true }).Count -eq 0)
    $script:SectionSync = $false
}

function Add-SectionPicks {
    $sel = $script:SelectableCheckBoxes
    foreach ($pageName in @('pagePerf', 'pagePrivacy', 'pageUi', 'pageGpu')) {
        $page = E $pageName
        $stack = New-Object System.Collections.Stack
        $stack.Push($page)
        while ($stack.Count -gt 0) {
            $node = $stack.Pop()
            if ($node -is [System.Windows.Controls.Border] -and $node.Child -is [System.Windows.Controls.StackPanel] -and
                $node.Child.Children.Count -gt 0 -and $node.Child.Children[0] -is [System.Windows.Controls.TextBlock] -and
                $node.Child.Children[0].Style -eq $window.FindResource('CardTitle')) {
                $items = @(Get-CheckBoxesFromTree $node | Where-Object { $sel -contains $_ })
                if ($items.Count -ge 4) {
                    $panel = $node.Child; $title = $panel.Children[0]
                    $panel.Children.RemoveAt(0)
                    $g = New-Object System.Windows.Controls.Grid
                    $g.Margin = $title.Margin; $title.Margin = '0'; $title.VerticalAlignment = 'Center'; $title.TextWrapping = 'Wrap'
                    $c0 = New-Object System.Windows.Controls.ColumnDefinition
                    $c1 = New-Object System.Windows.Controls.ColumnDefinition; $c1.Width = [System.Windows.GridLength]::Auto
                    $g.ColumnDefinitions.Add($c0); $g.ColumnDefinitions.Add($c1)
                    [void]$g.Children.Add($title)
                    $box = New-Object System.Windows.Controls.CheckBox
                    $box.Style = $window.FindResource('SectionPick'); $box.Tag = 'section'; $box.Margin = '8,-4,-6,-4'
                    $box.Content = T 'sectionSelect'
                    [System.Windows.Controls.Grid]::SetColumn($box, 1); [void]$g.Children.Add($box)
                    $panel.Children.Insert(0, $g)
                    $sp = @{ Box = $box; Items = $items }
                    $box.Add_Click({
                        $mine = $null
                        foreach ($s in $script:SectionPicks) { if ($s.Box -eq $this) { $mine = $s } }
                        if ($null -eq $mine) { return }
                        $want = ($this.IsChecked -eq $true)
                        $script:SectionSync = $true
                        foreach ($cb in $mine.Items) { if ($cb.IsEnabled) { $cb.IsChecked = $want } }
                        $script:SectionSync = $false
                        Update-SectionPick $mine
                        Update-ApplyButton
                    })
                    foreach ($cb in $items) {
                        $cb.Add_Checked({ if (-not $script:SectionSync) { foreach ($s in $script:SectionPicks) { if ($s.Items -contains $this) { Update-SectionPick $s } } } })
                        $cb.Add_Unchecked({ if (-not $script:SectionSync) { foreach ($s in $script:SectionPicks) { if ($s.Items -contains $this) { Update-SectionPick $s } } } })
                    }
                    [void]$script:SectionPicks.Add($sp)
                    continue
                }
            }
            foreach ($ch in [System.Windows.LogicalTreeHelper]::GetChildren($node)) {
                if ($ch -is [System.Windows.DependencyObject]) { $stack.Push($ch) }
            }
        }
    }
}

function Update-SectionPickText {
    foreach ($s in $script:SectionPicks) { $s.Box.Content = T 'sectionSelect'; Update-SectionPick $s }
}

# All'avvio nulla e' selezionato.
foreach ($cb in $script:AllCheckBoxes) { $cb.IsChecked = $false }

function Update-ApplyButton {
    $total = @($script:AllCheckBoxes | Where-Object { $_.IsChecked -eq $true }).Count
    $btnRun.IsEnabled = ($total -gt 0)
    if ($null -ne $btnUndo) { $btnUndo.IsEnabled = ($total -gt 0) }
    if ($null -ne $txtSelectedCount) {
        $txtSelectedCount.Text = "$total"
        if ($total -gt 0) { $txtSelectedCount.Foreground = "#FF2ED3A7" } else { $txtSelectedCount.Foreground = "#FF5E5E68" }
    }
}

foreach ($cb in $script:AllCheckBoxes) {
    $cb.Add_Checked({ Update-ApplyButton })
    $cb.Add_Unchecked({ Update-ApplyButton })
}

# Voci del produttore sbagliato: su un PC con scheda AMD le caselle NVIDIA
# restano ferme anche con «Seleziona tutto», perche' non farebbero nulla.
function Test-CheckVendor($cb) {
    # Processore: le voci Intel o AMD valgono solo sul processore di quella marca.
    if ([string]$cb.Name -match '^chkCpu(Intel|Amd)') {
        $want = if ($Matches[1] -eq 'Intel') { 'Intel' } else { 'AMD' }
        return (-not $script:CpuVendor) -or ($script:CpuVendor -eq $want)
    }
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

# -ByPcType vale per «Consigliati»: tiene conto di portatile e fisso. «Seleziona
# tutto» invece prende davvero tutto, e sul portatile chiede conferma.
function Get-SelectableChecks([switch]$CurrentPageOnly, [switch]$ByPcType) {
    $list = @($script:SelectableCheckBoxes | Where-Object {
        $_.IsEnabled -and (Test-CheckVendor $_) -and (-not $ByPcType -or (Test-CheckPcType $_))
    })
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
    pagePerf    = @('chkMMCSS','chkPriority','chkKernelMem','chkPowerThrottling','chkUSBSuspend','chkNtfsPerf','chkRamTweak','chkGameMode','chkGameDVR',
                    'chkCpuIntelBoostPol','chkCpuAmdParking')
    pagePrivacy = @('chkTelemetry','chkTelemetryTasks','chkActivityHistory','chkAdvertisingID','chkTailoredExp','chkFeedback','chkErrorReporting',
                    'chkInkingTyping','chkWiFiSense','chkConsumerFeatures','chkStoreSearch','chkSuggestedContent','chkLockScreenAds','chkStartBing',
                    'chkStartRecs','chkStartTracking','chkWindowsAI','chkEdgeDebloat','chkDeliveryOpt','chkWPBT','chkBackgroundApps',
                    'chkRemoteAssistance','chkCompanionApps','chkServicesManual','chkTeredo')
    pageUi      = @('chkDarkTheme','chkFileExt','chkLongPaths','chkExplorerThisPC','chkRemove3D','chkRecycleConfirm','chkMenuDelay','chkStartNoWeb',
                    'chkStartNoAccount','chkTaskbarWidgets','chkTaskbarChat','chkTaskbarEndTask','chkMouseAccel','chkNumLock','chkStickyKeys')
    pageNet     = @('chkNetPowerSave')
    pageStorage = @('chkReservedStorage')
    pagePower   = @('chkFastStartup','chkHibernation','chkS0Sleep','chkS3Sleep','chkDiskNoSleep')
    pageGpu     = @('chkGpuTdr','chkNvTelemetry','chkNvGfe','chkNvPerfMode','chkNvUpdates','chkNvP2','chkNvDrsPower','chkNvLowLatency',
                    'chkNvShaderCache','chkNvDisplayPower','chkAmdUx','chkAmdBloat','chkAmdUlps','chkAmdAntiLag','chkAmdShaderCache','chkIntelBloat',
                    'chkIntelTelemetry','chkIntelGfxPower')
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

# Su un portatile «Seleziona tutto» prende anche le voci che consumano batteria:
# prima un avviso che indica «Consigliati» come scelta migliore.
function Confirm-LaptopSelection([array]$list) {
    if ((Get-PcType) -ne 'laptop') { return $true }
    $hit = @($list | Where-Object { $script:LaptopSkip -contains [string]$_.Name })
    if ($hit.Count -eq 0) { return $true }
    return (Show-Dialog (T 'laptopSelTitle') (T 'laptopSelAsk') 'warn')
}

$btnSelectAll.Add_Click({
    $found = @(Get-SelectableChecks)
    if (-not (Confirm-LaptopSelection $found)) { return }
    foreach ($cb in $found) { $cb.IsChecked = $true }
    Update-ApplyButton
})

$btnSelectPage.Add_Click({
    $found = @(Get-SelectableChecks -CurrentPageOnly)
    if (-not (Confirm-LaptopSelection $found)) { return }
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
    foreach ($cb in @(Get-SelectableChecks -CurrentPageOnly -ByPcType)) {
        if ($names -contains [string]$cb.Name) { $cb.IsChecked = $true; $n++ }
    }
    $txtProgressLabel.Text = (T 'recSelected') -f $n
    Update-ApplyButton
})

$btnDeselectAll.Add_Click({
    foreach ($cb in $script:AllCheckBoxes) { $cb.IsChecked = $false }
    Update-ApplyButton
})

# ------------------------------------------------------------------------------
# 12. RILEVAMENTO DEI TWEAK GIA' ATTIVI
# ------------------------------------------------------------------------------
# Il pulsante «Rileva gia' attivi» e' in partTools: segna le voci con l'etichetta «Attivo».
