
# ------------------------------------------------------------------------------
# 20. AVVIO
# ------------------------------------------------------------------------------
Show-GpuInfo
Show-CpuInfo
Add-SectionPicks
Show-WuProfiles
Update-RecStars
Update-PowerPlanLabel
Show-PlanList
$script:UiReady = $true

Write-Log "[INFO] Tweak Andrew v6.1 pronto. Il registro dettagliato resta in questa finestra."

[void]$window.ShowDialog()
