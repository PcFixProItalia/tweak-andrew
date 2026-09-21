# Prova il motore del catalogo su una chiave di test in HKCU, poi la cancella.
$root = Split-Path $PSScriptRoot -Parent
function E($n) { $null }
function Get-Text($e) { if ($e) { $e['it'] } }
function T($k) { $k }
$script:Log = @()
function Write-Log($m) { $script:Log += $m }
$script:Catalog = @(); $script:CatText = @{}; $script:CatTip = @{}
. ([ScriptBlock]::Create([IO.File]::ReadAllText("$root\src\partK.ps1")))

$base = 'HKCU\Software\TweakAndrewTest'
$fail = 0
function Check($name, $cond) { if ($cond) { Write-Host "OK   $name" } else { Write-Host "FAIL $name" -ForegroundColor Red; $script:fail++ } }

$items = @(
    @{ Id = 'd'; Kind = 'T'; Flags = ''; Ops = @(,@("$base", 'Dw', 'D', '0', '1,-')) },
    @{ Id = 'neg'; Kind = 'T'; Flags = ''; Ops = @(,@("$base", 'Neg', 'D', '-1', '-')) },
    @{ Id = 's'; Kind = 'T'; Flags = ''; Ops = @(,@("$base", 'Str', 'S', 'Deny', 'Allow,-')) },
    @{ Id = 'empty'; Kind = 'T'; Flags = ''; Ops = @(,@("$base", 'Emp', 'S', '""', '-')) },
    @{ Id = 'b'; Kind = 'T'; Flags = ''; Ops = @(,@("$base", 'Bin', 'B', '00 00 00 00', '-')) },
    @{ Id = 'kv'; Kind = 'T'; Flags = ''; Ops = @(,@("$base", 'Kv', 'Kv:VRROptimizeEnable', '1', '0,-')) },
    @{ Id = 'key'; Kind = 'T'; Flags = ''; Ops = @(@("$base\Sub", 'X', 'S', 'y', '-'), @("$base\Sub", '', 'Key', '+', '-')) }
)
foreach ($it in $items) {
    Check "$($it.Id) spento all'inizio" ((Get-CatState $it) -eq $false)
    [void](Set-CatState $it $true);  Check "$($it.Id) acceso" ((Get-CatState $it) -eq $true)
    [void](Set-CatState $it $false); Check "$($it.Id) spento" ((Get-CatState $it) -eq $false)
}
# Kv: la coppia convive con le altre nella stessa stringa.
Set-CatValue @("$base", 'Kv', 'S') 'SwapEffectUpgradeEnable=1;'
[void](Set-CatState $items[5] $true)
Check 'kv conserva le altre coppie' ((Get-CatRaw $base 'Kv') -eq 'SwapEffectUpgradeEnable=1;VRROptimizeEnable=1;')
# Byte e Bit su un valore binario esistente.
Set-CatValue @("$base", 'Mask', 'B') '90 12 03 80 10 00 00 00'
$bit = @{ Id = 'bit'; Kind = 'T'; Flags = ''; Ops = @(,@("$base", 'Mask', 'Bit:1:0x08', '1', '0')) }
Check 'bit acceso letto' ((Get-CatState $bit) -eq $false)
[void](Set-CatState $bit $true); Check 'bit acceso' ((Get-CatState $bit) -eq $true)
Check 'bit non tocca il resto' (((Get-CatRaw $base 'Mask') | ForEach-Object { $_.ToString('X2') }) -join ' ' -eq '90 1A 03 80 10 00 00 00')
[void](Set-CatState $bit $false); Check 'bit spento' ((Get-CatState $bit) -eq $false)
$byte = @{ Id = 'byte'; Kind = 'T'; Flags = ''; Ops = @(,@("$base", 'Mask', 'Byte:3', '3', '2')) }
[void](Set-CatState $byte $true); Check 'byte 3' ((Get-CatRaw $base 'Mask')[3] -eq 3)
# Menu con due valori.
$sel = @{ Id = 'sel'; Kind = 'S'; Flags = ''; Ops = @(@("$base", 'A', 'D'), @("$base", 'B', 'D'));
          Opts = @(@{ Key = 'x'; Vals = @('-', '-') }, @{ Key = 'y'; Vals = @('5', '1') }, @{ Key = 'z'; Vals = @('0', '0') }) }
Check 'menu predefinito' ((Get-CatState $sel) -eq 'x')
[void](Set-CatState $sel 'y'); Check 'menu y' ((Get-CatState $sel) -eq 'y')
Set-CatValue @("$base", 'B', 'D') '7'; Check 'menu fuori elenco' ($null -eq (Get-CatState $sel))
# Negativo scritto come FFFFFFFF
[void](Set-CatState $items[1] $true); Check 'dword -1' ([BitConverter]::ToUInt32([BitConverter]::GetBytes([int](Get-CatRaw $base 'Neg')), 0) -eq 4294967295)

Remove-Item -Path 'HKCU:\Software\TweakAndrewTest' -Recurse -Force
Check 'chiave di test rimossa' (-not (Test-Path 'HKCU:\Software\TweakAndrewTest'))
$errs = @($script:Log | Where-Object { $_ -like '*ERRORE*' })
if ($errs) { $errs | ForEach-Object { Write-Host $_ -ForegroundColor Yellow } }
"FALLITI: $fail"
