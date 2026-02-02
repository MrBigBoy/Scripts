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

if ($Host.UI -and $Host.UI.RawUI) {
    Clear-Host
}

# Ensure log directory exists
$logDir = Split-Path -Parent $LogFile
if (-not (Test-Path $logDir)) { New-Item -Path $logDir -ItemType Directory -Force | Out-Null }

# ================================
# Non-interactive / CI-safe mode
# ================================
$ProgressPreference = 'SilentlyContinue'
$ErrorActionPreference = 'Continue'
$ScriptStopwatch = [System.Diagnostics.Stopwatch]::StartNew()

# ================================
# Load helpers and notify
# ================================
$ModuleDir = Join-Path $PSScriptRoot 'modules'
$helpersPath = Join-Path $ModuleDir 'Helpers.ps1'
if (Test-Path $helpersPath) { . $helpersPath }
$notifyPath = Join-Path $ModuleDir 'Notify.ps1'
if (Test-Path $notifyPath) { . $notifyPath }
$localizationPath = Join-Path $ModuleDir 'Localization.ps1'
if (Test-Path $localizationPath) { . $localizationPath }
$orchestratorPath = Join-Path $ModuleDir 'Orchestrator.ps1'
if (Test-Path $orchestratorPath) { . $orchestratorPath }

# ================================
# BurntToast ensure + weekly update
# ================================
$ModuleName      = 'BurntToast'
$CheckInterval   = 7
$StateDir        = Join-Path $env:LOCALAPPDATA 'SystemUpdater'
$LastCheckFile   = Join-Path $StateDir 'BurntToast.lastcheck'

if (-not (Test-Path $StateDir)) {
    New-Item -Path $StateDir -ItemType Directory -Force | Out-Null
}

$DoUpdateCheck = -not (Test-Path $LastCheckFile) -or
    ((Get-Date) - (Get-Item $LastCheckFile).LastWriteTime).Days -ge $CheckInterval

try {
    $Installed = Get-Module -ListAvailable -Name $ModuleName |
                 Sort-Object Version -Descending |
                 Select-Object -First 1

    if ($DoUpdateCheck) {
        $Latest = Find-Module -Name $ModuleName -ErrorAction Stop

        if (-not $Installed) {
            Install-Module -Name $ModuleName -Scope CurrentUser -Force -ErrorAction Stop
        }
        elseif ($Installed.Version -lt $Latest.Version) {
            Update-Module -Name $ModuleName -Scope CurrentUser -Force -ErrorAction Stop
        }

        New-Item -Path $LastCheckFile -ItemType File -Force | Out-Null
    }

    Import-Module $ModuleName -Force -ErrorAction Stop
    $ToastAvailable = $true
}
catch {
    $ToastAvailable = $false
}

# ================================
# Start notification
# ================================
$LogName = 'Application'
$Source  = 'SystemUpdater'
$StartEventId = 1000

$StartMessage = Get-LocalizedString -Key 'DailyUpdateStarted'
$Title = Get-LocalizedString -Key 'SystemUpdate'

if (Get-Command Invoke-Notify -ErrorAction SilentlyContinue) {
    Invoke-Notify -Message $StartMessage -EventId $StartEventId -Title $Title -LogFile $LogFile
} else {
    if (-not [System.Diagnostics.EventLog]::SourceExists($Source)) { New-EventLog -LogName $LogName -Source $Source }
    Write-EventLog -LogName $LogName -Source $Source -EventId $StartEventId -EntryType Information -Message $StartMessage
    if ($ToastAvailable) { New-BurntToastNotification -Text $Title, $StartMessage }
}

# ================================
# Exit code handling
# ================================
$global:ExitCode = 0
trap {
    Write-Host "Error: $_" -ForegroundColor Red
    $global:ExitCode = 1
}

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

# Write orchestrator summary to log
$summary = [PSCustomObject]@{
    Timestamp = (Get-Date).ToString('o')
    Results = $results
}
if ($LogFile -and (Get-Command Write-LogJsonLine -ErrorAction SilentlyContinue)) { Write-LogJsonLine -Object $summary -LogFile $LogFile }

Write-Host (Get-LocalizedString -Key 'ModuleExecutionResults'); $results | Format-Table -AutoSize

# ================================
# Event Log signal (user toast trigger)
# ================================
$LogName = 'Application'
$Source  = 'SystemUpdater'
$EventId = 1001

if (-not [System.Diagnostics.EventLog]::SourceExists($Source)) {
    New-EventLog -LogName $LogName -Source $Source
}

$RebootRequired = Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired'
$EventMessage = if ($RebootRequired) { Get-LocalizedString -Key 'SystemUpdatesCompletedReboot' } else { Get-LocalizedString -Key 'SystemUpdatesCompleted' }
$Title = Get-LocalizedString -Key 'SystemUpdate'

if (Get-Command Invoke-Notify -ErrorAction SilentlyContinue) {
    Invoke-Notify -Message $EventMessage -EventId $EventId -Title $Title -LogFile $LogFile
} else {
    Write-EventLog -LogName $LogName -Source $Source -EventId $EventId -EntryType Information -Message $EventMessage
    if ($ToastAvailable) { New-BurntToastNotification -Text $Title, $EventMessage }
}

# ================================
# Scheduled Task creation
# ================================
$TaskName   = 'Update System (Choco + Winget + Windows Update)'
$ScriptPath = 'C:\Scripts\Update-All.ps1'

if (Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue) {
    Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
}

# Build argument string safely
$Argument = "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$ScriptPath`""
$Action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument $Argument

$Trigger = New-ScheduledTaskTrigger -Daily -At 01:00AM
$Principal = New-ScheduledTaskPrincipal -UserId 'SYSTEM' -LogonType ServiceAccount -RunLevel Highest
$Settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable -WakeToRun -Hidden -ExecutionTimeLimit (New-TimeSpan -Hours 4)

# Register scheduled task and finish
Register-ScheduledTask -TaskName $TaskName -Action $Action -Trigger $Trigger -Principal $Principal -Settings $Settings -Force

Write-Host (Get-LocalizedString -Key 'ScheduledTaskCreated' -FormatArgs $TaskName) -ForegroundColor Green

$ScriptStopwatch.Stop()

$Elapsed = $ScriptStopwatch.Elapsed
$DurationText = '{0:hh\:mm\:ss}' -f $Elapsed


# ================================
# End notification
# ================================
$EndEventId = 1002
$EndMessage = Get-LocalizedString -Key 'DailyUpdateFinished' -FormatArgs $DurationText
$Title = Get-LocalizedString -Key 'SystemUpdate'

if (Get-Command Invoke-Notify -ErrorAction SilentlyContinue) {
    Invoke-Notify -Message $EndMessage -EventId $EndEventId -Title $Title -LogFile $LogFile
} else {
    Write-EventLog -LogName $LogName -Source $Source -EventId $EndEventId -EntryType Information -Message $EndMessage
    if ($ToastAvailable) { New-BurntToastNotification -Text $Title, $EndMessage }
}

# After collecting $results and logging summary, find failed PowerShell modules and trigger helper
$psModuleResult = $results | Where-Object { $_.Module -eq 'PowerShellModules' }
if ($psModuleResult) {
    $failed = @()
    if ($psModuleResult.FailedModules) { $failed = $psModuleResult.FailedModules }
    if ($failed.Count -gt 0) {
        try {
            $payload = [PSCustomObject]@{
                ParentPid = $PID
                LogFile = $LogFile
                Modules = $failed
            }
            $tmp = Join-Path $env:TEMP ("update_modules_payload_{0}.json" -f ([guid]::NewGuid().ToString()))
            $payload | ConvertTo-Json -Depth 5 | Out-File -FilePath $tmp -Encoding UTF8

            $helper = Join-Path $ModuleDir 'Update-Modules-Helper.ps1'
            if (Test-Path $helper) {
                Write-Host (Get-LocalizedString -Key 'LaunchingHelper' -FormatArgs $helper)
                Start-Process -FilePath powershell -ArgumentList @('-NoProfile','-ExecutionPolicy','Bypass','-File',$helper,$tmp) -Verb RunAs
            } else {
                Write-Host (Get-LocalizedString -Key 'HelperNotFound' -FormatArgs $helper) -ForegroundColor Yellow
            }
        } catch {
            Write-Host (Get-LocalizedString -Key 'FailedToLaunchHelper' -FormatArgs $_) -ForegroundColor Yellow
        }
    }
}

exit $global:ExitCode