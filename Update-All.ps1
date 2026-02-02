# ================================
# Script parameters
# ================================
param(
    [switch]$WhatIf,
    [string[]]$SkipModules,
    [string[]]$RunModules,
    [string]$LogFile = (Join-Path $env:LOCALAPPDATA 'SystemUpdater\update-log.jsonl')
)

# ================================
# Self-elevate to Administrator
# ================================
if (-not ([Security.Principal.WindowsPrincipal] `
    [Security.Principal.WindowsIdentity]::GetCurrent()
    ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {

    $currentScript = $MyInvocation.MyCommand.Path
    Start-Process -FilePath powershell -ArgumentList @('-NoProfile','-ExecutionPolicy','Bypass','-File',$currentScript) -Verb RunAs
    exit
}

if ($Host.UI -and $Host.UI.RawUI) { Clear-Host }

# ================================
# Load modules
# ================================
$ModuleDir = Join-Path $PSScriptRoot 'modules'
@('Helpers', 'Notify', 'Localization', 'Orchestrator', 'Environment') | ForEach-Object {
    $path = Join-Path $ModuleDir "$_.ps1"
    if (Test-Path $path) { . $path }
}

# ================================
# Initialize
# ================================
Initialize-Environment -LogFile $LogFile
$ScriptStopwatch = [System.Diagnostics.Stopwatch]::StartNew()
$ToastAvailable = Initialize-ToastNotifications
Send-StartNotification -LogFile $LogFile
Write-Host (Get-LocalizedString -Key 'RunningAsAdmin') -ForegroundColor Green

# ================================
# Orchestrator: load and execute modules
# ================================
$moduleRegistry = Import-PowerShellDataFile -Path (Join-Path $ModuleDir 'ModuleRegistry.psd1')
$results = @()

foreach ($module in $moduleRegistry) {
    if ($RunModules -and ($RunModules -ne $null) -and -not ($RunModules -contains $module.Name)) {
        Write-Host (Get-LocalizedString -Key 'Skipping' -FormatArgs $module.Name) -ForegroundColor Yellow
        continue
    }
    if ($SkipModules -and ($SkipModules -contains $module.Name)) {
        Write-Host (Get-LocalizedString -Key 'SkippingAsRequested' -FormatArgs $module.Name) -ForegroundColor Yellow
        continue
    }
    
    $result = Invoke-UpdateModule -Module $module -ModuleDir $ModuleDir -WhatIf:$WhatIf -LogFile $LogFile
    if ($result) { $results += $result }
}

$summary = [PSCustomObject]@{ Timestamp = (Get-Date).ToString('o'); Results = $results }
if ($LogFile -and (Get-Command Write-LogJsonLine -ErrorAction SilentlyContinue)) { Write-LogJsonLine -Object $summary -LogFile $LogFile }
Write-Host (Get-LocalizedString -Key 'ModuleExecutionResults'); $results | Format-Table -AutoSize

# ================================
# Finalize
# ================================
Send-CompletionNotification -LogFile $LogFile
Register-UpdateTask
$ScriptStopwatch.Stop()
Send-EndNotification -Duration ('{0:hh\:mm\:ss}' -f $ScriptStopwatch.Elapsed) -LogFile $LogFile
Invoke-FailedModulesHelper -Results $results -ModuleDir $ModuleDir -LogFile $LogFile

exit $global:ExitCode