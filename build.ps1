# Riassembla Tweak_Andrew.ps1 dalle parti in src\ e ne verifica la sintassi.
# Uso: powershell -NoProfile -ExecutionPolicy Bypass -File build.ps1 [-Desktop]
param([switch]$Desktop)

$root = $PSScriptRoot
$src = Join-Path $root 'src'
$enc = [System.Text.Encoding]::UTF8
$ErrorActionPreference = 'Stop'
$version = '7.0'

# Catalogo delle impostazioni: si rigenera a ogni build.
& python (Join-Path $root 'tools\gen_catalog.py')
if ($LASTEXITCODE -ne 0) { throw 'Catalogo non valido.' }

function Read-Part([string]$name) { [System.IO.File]::ReadAllText((Join-Path $src $name), $enc) }

$a = (Read-Part 'partA.ps1') -replace '# Base64 del Piano di Alimentazione Personalizzato Bitsum\s*$', ''
$d = (Read-Part 'partD.ps1').Replace('[void]$window.ShowDialog()', '')

$parts = @(
    $a,
    (Read-Part 'partPlans.ps1'),
    (Read-Part 'partB2.ps1'),
    (Read-Part 'partC.ps1'),
    (Read-Part 'partL.ps1'),
    (Read-Part 'partK_data.ps1'),
    (Read-Part 'partApps_data.ps1'),
    $d,
    (Read-Part 'partU.ps1'),
    (Read-Part 'partE.ps1'),
    (Read-Part 'partF.ps1'),
    (Read-Part 'partG.ps1'),
    (Read-Part 'partK.ps1'),
    (Read-Part 'partApps.ps1'),
    (Read-Part 'partTail.ps1')
)

$t = ($parts -join "`r`n")
$t = $t -replace '<!--\s*-+\s*([^<>]*?)\s*-+\s*-->', '<!-- $1 -->'
$t = $t -replace 'v6\.[0-9]', "v$version"

$out = Join-Path $root 'Tweak_Andrew.ps1'
[System.IO.File]::WriteAllText($out, $t, (New-Object System.Text.UTF8Encoding $true))
if ($Desktop) {
    Copy-Item $out (Join-Path ([Environment]::GetFolderPath('Desktop')) "Tweak_Andrew_v$version.ps1") -Force
}

$e = $null
[System.Management.Automation.Language.Parser]::ParseFile($out, [ref]$null, [ref]$e) | Out-Null
if ($e.Count -eq 0) {
    "SINTASSI OK - righe: " + (Get-Content -LiteralPath $out).Count
} else {
    $e | Select-Object -First 6 | ForEach-Object { "$($_.Extent.StartLineNumber): $($_.Message)" }
}
