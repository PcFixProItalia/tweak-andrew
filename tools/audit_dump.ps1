# Legge (senza eseguirle) le azioni di «Applica» e di ripristino e scrive, per
# ogni interruttore, quali valori tocca. Serve a tools/audit.py.
param([string]$Out = "$env:TEMP\tweak_audit.json")
$root = Split-Path $PSScriptRoot -Parent
$A = [System.Management.Automation.Language.Parser]
$known = @{ adv = 'HKCU:\Software\Microsoft\Windows\CurrentVersion\Explorer\Advanced'; mm = 'HKLM:\SYSTEM\CurrentControlSet\Control\Session Manager\Memory Management' }

function Resolve($ast, $vars) {
    if ($ast -is [System.Management.Automation.Language.ExpandableStringExpressionAst]) {
        $outs = @($ast.Value)
        foreach ($n in $ast.NestedExpressions) {
            $vals = Resolve $n $vars
            if ($null -eq $vals) { return $null }
            $outs = foreach ($o in $outs) { foreach ($v in $vals) { $o.Replace($n.Extent.Text, [string]$v) } }
        }
        return @($outs)
    }
    if ($ast -is [System.Management.Automation.Language.StringConstantExpressionAst]) { return @($ast.Value) }
    if ($ast -is [System.Management.Automation.Language.ConstantExpressionAst]) { return @($ast.Value) }
    if ($ast -is [System.Management.Automation.Language.VariableExpressionAst]) {
        $n = $ast.VariablePath.UserPath
        if ($n -eq 'true') { return @($true) }; if ($n -eq 'false') { return @($false) }; if ($n -eq 'null') { return @('<null>') }
        if ($vars.ContainsKey($n)) { return @($vars[$n]) }
        return $null
    }
    if ($ast -is [System.Management.Automation.Language.ArrayLiteralAst]) {
        $o = @(); foreach ($e in $ast.Elements) { $v = Resolve $e $vars; if ($null -eq $v) { return $null }; $o += $v }; return ,@(($o -join ','))
    }
    if ($ast -is [System.Management.Automation.Language.ParenExpressionAst] -or $ast -is [System.Management.Automation.Language.ArrayExpressionAst]) { return @($ast.Extent.Text) }
    return $null
}

function Walk($statements, $vars, $acc) {
    foreach ($st in $statements) {
        if ($st -is [System.Management.Automation.Language.AssignmentStatementAst] -and $st.Left -is [System.Management.Automation.Language.VariableExpressionAst] -and $st.Right -is [System.Management.Automation.Language.CommandExpressionAst]) {
            $v = Resolve $st.Right.Expression $vars
            if ($null -ne $v -and @($v).Count -eq 1) { $vars[$st.Left.VariablePath.UserPath] = @($v)[0] }
            continue
        }
        if ($st -is [System.Management.Automation.Language.ForEachStatementAst]) {
            $expr = $st.Condition
            $els = $expr.Find({ param($n) $n -is [System.Management.Automation.Language.ArrayLiteralAst] }, $true)
            if ($els -and $els.Parent -and ($expr.Extent.Text.Trim('@', '(', ')', ' ') -eq $els.Extent.Text)) {
                foreach ($e in $els.Elements) {
                    $v = Resolve $e $vars; $vv = $vars.Clone()
                    if ($null -ne $v) { $vv[$st.Variable.VariablePath.UserPath] = @($v)[0] }
                    Walk $st.Body.Statements $vv $acc
                }
            } else { Walk $st.Body.Statements $vars.Clone() $acc }
            continue
        }
        if ($st -is [System.Management.Automation.Language.IfStatementAst]) {
            foreach ($c in $st.Clauses) { Walk @($c.Item1) $vars $acc; Walk $c.Item2.Statements $vars $acc }
            if ($st.ElseClause) { Walk $st.ElseClause.Statements $vars $acc }
            continue
        }
        if ($st -is [System.Management.Automation.Language.TryStatementAst]) {
            Walk $st.Body.Statements $vars $acc
            foreach ($c in $st.CatchClauses) { Walk $c.Body.Statements $vars $acc }
            continue
        }
        foreach ($cmd in $st.FindAll({ param($n) $n -is [System.Management.Automation.Language.CommandAst] }, $true)) {
            $name = $cmd.GetCommandName(); if (-not $name) { $name = $cmd.CommandElements[0].Extent.Text }
            $args = @($cmd.CommandElements | Select-Object -Skip 1 | Where-Object { $_ -isnot [System.Management.Automation.Language.CommandParameterAst] })
            $res = @($args | ForEach-Object { $r = Resolve $_ $vars; if ($null -eq $r) { '?' + $_.Extent.Text } elseif (@($r).Count -eq 1) { [string]@($r)[0] } else { (@($r) -join '||') } })
            [void]$acc.Add(@{ c = $name; a = $res; t = $cmd.Extent.Text })
        }
    }
}

$result = @{ apply = @{}; undo = @{}; noundo = @() }
foreach ($f in 'partD', 'partU') {
    $ast = $A::ParseFile("$root\src\$f.ps1", [ref]$null, [ref]$null)
    foreach ($c in $ast.FindAll({ param($n) $n -is [System.Management.Automation.Language.CommandAst] -and @('Add-IfChecked', 'Add-UndoIfChecked', 'Add-NoUndo') -contains $n.GetCommandName() }, $true)) {
        $el = $c.CommandElements
        if ($el.Count -lt 3 -or $el[1] -isnot [System.Management.Automation.Language.VariableExpressionAst]) { continue }
        $box = $el[1].VariablePath.UserPath
        if ($c.GetCommandName() -eq 'Add-NoUndo') { $result.noundo += $box; continue }
        if ($el[2] -isnot [System.Management.Automation.Language.ScriptBlockExpressionAst]) { continue }
        $acc = New-Object System.Collections.ArrayList
        Walk $el[2].ScriptBlock.EndBlock.Statements $known.Clone() $acc
        $slot = if ($c.GetCommandName() -eq 'Add-IfChecked') { 'apply' } else { 'undo' }
        if (-not $result[$slot].ContainsKey($box)) { $result[$slot][$box] = @() }
        $result[$slot][$box] += @($acc)
    }
}
$result | ConvertTo-Json -Depth 6 | Out-File $Out -Encoding utf8
"scritto $Out  apply=$($result.apply.Count) undo=$($result.undo.Count) noundo=$($result.noundo.Count)"
