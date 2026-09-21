# ==============================================================================
#                  TWEAK ANDREW v6.0 - PcFixPro Italia
#        Suite offline di ottimizzazione e controllo per Windows 10 / 11
# ==============================================================================
# Requisiti: Windows 10 / 11 | Eseguire come AMMINISTRATORE
# Interfaccia bilingue (italiano / inglese), nessuna connessione richiesta.
# ==============================================================================

Add-Type -AssemblyName PresentationFramework, PresentationCore, WindowsBase

# ------------------------------------------------------------------------------
# 0. AVVIO CON PRIVILEGI DI AMMINISTRATORE
# ------------------------------------------------------------------------------
$identity = [Security.Principal.WindowsIdentity]::GetCurrent()
$principal = New-Object Security.Principal.WindowsPrincipal($identity)
if (-not $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
    try {
        $scriptPath = $MyInvocation.MyCommand.Definition
        $psi = New-Object System.Diagnostics.ProcessStartInfo
        $psi.FileName = (Get-Process -Id $PID).Path
        if ([string]::IsNullOrWhiteSpace($psi.FileName)) { $psi.FileName = "powershell.exe" }
        $psi.Arguments = '-NoProfile -ExecutionPolicy Bypass -File "' + $scriptPath + '"'
        $psi.Verb = 'runas'
        $psi.UseShellExecute = $true
        [System.Diagnostics.Process]::Start($psi) | Out-Null
    } catch {
        [System.Windows.MessageBox]::Show(
            "Tweak Andrew richiede i privilegi di Amministratore.`n`nL'avvio elevato non e' riuscito. Avvia PowerShell come amministratore e riprova.`n`nDettaglio: $($_.Exception.Message)",
            "Tweak Andrew v6.0",
            [System.Windows.MessageBoxButton]::OK,
            [System.Windows.MessageBoxImage]::Error
        ) | Out-Null
    }
    Exit
}

$ErrorActionPreference = 'Continue'

# Base64 del Piano di Alimentazione Personalizzato Bitsum
