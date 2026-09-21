# Avvio remoto di Tweak Andrew. Si lancia con:
#   $t='TOKEN';irm https://raw.githubusercontent.com/PcFixProItalia/tweak-andrew/main/run.ps1 -H @{Authorization="token $t"}|iex
# Scarica l'ultima versione dal repository privato e la apre come amministratore:
# uno script eseguito con iex non ha un file da cui ripartire con i privilegi.
& {
    $ErrorActionPreference = 'Stop'
    [Net.ServicePointManager]::SecurityProtocol = [Net.ServicePointManager]::SecurityProtocol -bor [Net.SecurityProtocolType]::Tls12
    if (-not $t) { Write-Host 'ERRORE: manca il token. Definisci $t prima del comando.' -ForegroundColor Red; return }
    $file = Join-Path $env:TEMP 'Tweak_Andrew.ps1'
    Write-Host 'Scarico Tweak Andrew...' -ForegroundColor Cyan
    try {
        Invoke-WebRequest -UseBasicParsing -Uri 'https://raw.githubusercontent.com/PcFixProItalia/tweak-andrew/main/Tweak_Andrew.ps1' `
            -Headers @{ Authorization = "token $t" } -OutFile $file
    } catch {
        Write-Host "ERRORE: download non riuscito ($($_.Exception.Message)). Controlla il token." -ForegroundColor Red
        return
    }
    Write-Host 'OK: avvio come amministratore.' -ForegroundColor Green
    Start-Process powershell.exe -Verb RunAs -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$file`""
}
# Il token non resta nella sessione.
Remove-Variable t -ErrorAction SilentlyContinue
