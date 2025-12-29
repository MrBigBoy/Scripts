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

$StartMessage = 'Daglig opdatering startet'

if (Get-Command Invoke-Notify -ErrorAction SilentlyContinue) {
    Invoke-Notify -Message $StartMessage -EventId $StartEventId -Title 'Systemopdatering' -LogFile $LogFile
} else {
    if (-not [System.Diagnostics.EventLog]::SourceExists($Source)) { New-EventLog -LogName $LogName -Source $Source }
    Write-EventLog -LogName $LogName -Source $Source -EventId $StartEventId -EntryType Information -Message $StartMessage
    if ($ToastAvailable) { New-BurntToastNotification -Text 'Systemopdatering', $StartMessage }
}

# ================================
# Exit code handling
# ================================
$global:ExitCode = 0
trap {
    Write-Host "Error: $_" -ForegroundColor Red
    $global:ExitCode = 1
}

Write-Host "Running as Administrator" -ForegroundColor Green

# Orchestrator: load modular updaters and execute
# Add new modules to the list
$moduleFiles = @(
    'Update-Chocolatey.ps1',
    'Update-Winget.ps1',
    'Update-WindowsUpdate.ps1',
    'Update-PowerShellModules.ps1',
    'Update-Python.ps1',
    'Update-Docker.ps1',
    'Update-Scoop.ps1',
    'Update-Npm.ps1',
    'Update-Vcpkg.ps1',
    'Update-Composer.ps1',
    'Update-WSL.ps1',
    'Update-Conda.ps1',
    'Update-KubeHelm.ps1',
    'Update-CloudCLI.ps1'
)

$invokeMap = @{
    'Update-Chocolatey.ps1' = 'Invoke-UpdateChocolatey'
    'Update-Winget.ps1' = 'Invoke-UpdateWinget'
    'Update-WindowsUpdate.ps1' = 'Invoke-UpdateWindows'
    'Update-PowerShellModules.ps1' = 'Invoke-UpdatePowerShellModules'
    'Update-Python.ps1' = 'Invoke-UpdatePython'
    'Update-Docker.ps1' = 'Invoke-UpdateDocker'
    'Update-Scoop.ps1' = 'Invoke-UpdateScoop'
    'Update-Npm.ps1' = 'Invoke-UpdateNpm'
    'Update-Vcpkg.ps1' = 'Invoke-UpdateVcpkg'
    'Update-Composer.ps1' = 'Invoke-UpdateComposer'
    'Update-WSL.ps1' = 'Invoke-UpdateWSL'
    'Update-Conda.ps1' = 'Invoke-UpdateConda'
    'Update-KubeHelm.ps1' = 'Invoke-UpdateKubeHelm'
    'Update-CloudCLI.ps1' = 'Invoke-UpdateCloudCLI'
}

$shortMap = @{
    'Update-Chocolatey.ps1' = 'Chocolatey'
    'Update-Winget.ps1' = 'Winget'
    'Update-WindowsUpdate.ps1' = 'WindowsUpdate'
    'Update-PowerShellModules.ps1' = 'PowerShellModules'
    'Update-Python.ps1' = 'Python'
    'Update-Docker.ps1' = 'Docker'
    'Update-Scoop.ps1' = 'Scoop'
    'Update-Npm.ps1' = 'Npm'
    'Update-Vcpkg.ps1' = 'Vcpkg'
    'Update-Composer.ps1' = 'Composer'
    'Update-WSL.ps1' = 'WSL'
    'Update-Conda.ps1' = 'Conda'
    'Update-KubeHelm.ps1' = 'KubeHelm'
    'Update-CloudCLI.ps1' = 'CloudCLI'
}

$results = @()
foreach ($f in $moduleFiles) {
    $path = Join-Path $ModuleDir $f
    $shortName = $shortMap[$f]

    if ($RunModules -and ($RunModules -ne $null) -and -not ($RunModules -contains $shortName)) {
        Write-Host "Skipping $shortName because not in RunModules list" -ForegroundColor Yellow
        continue
    }
    if ($SkipModules -and ($SkipModules -contains $shortName)) {
        Write-Host "Skipping $shortName as requested" -ForegroundColor Yellow
        continue
    }

    if (Test-Path $path) {
        Write-Host "Checking: $shortName"
        . $path
        $invoke = $invokeMap[$f]
        if (Get-Command $invoke -ErrorAction SilentlyContinue) {
            try {
                $res = & $invoke -WhatIf:$WhatIf -LogFile $LogFile
                $results += $res
                # Determine display status and color
                $statusText = 'Failed'
                $color = 'Red'
                if ($res -and $res.Success) {
                    $statusText = 'Success'
                    $color = 'Green'
                } else {
                    $msg = if ($res -and $res.Message) { $res.Message } else { '' }
                    $out = if ($res -and $res.Output) { $res.Output } else { '' }
                    if ($msg -match '(?i)(not installed|not found|no supported updater|no updater|not present|no wsl distros|no wsl distros found|not managed|installed but not managed)' -or $out -match '(?i)(No installed package found|not found)') {
                        $statusText = 'Not installed'
                        $color = 'Yellow'
                    } else {
                        $statusText = 'Failed'
                        $color = 'Red'
                    }
                }
                Write-Host "Checked: $shortName - $statusText" -ForegroundColor $color
            } catch {
                $errObj = [PSCustomObject]@{ Module = $shortName; Success = $false; Message = 'Invocation failed'; Errors = @($_.Exception.Message); Duration = 0 }
                $results += $errObj
                Write-Host "Checked: $shortName - Invocation failed" -ForegroundColor Red
            }
        } else {
            Write-Host "Function for $shortName not found in $f" -ForegroundColor Yellow
        }
    } else {
        Write-Host "Module file for $shortName not found: $path" -ForegroundColor Yellow
    }
}

# Write orchestrator summary to log
$summary = [PSCustomObject]@{
    Timestamp = (Get-Date).ToString('o')
    Results = $results
}
if ($LogFile -and (Get-Command Write-LogJsonLine -ErrorAction SilentlyContinue)) { Write-LogJsonLine -Object $summary -LogFile $LogFile }

Write-Host "Module execution results:"; $results | Format-Table -AutoSize

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
$EventMessage = if ($RebootRequired) { 'System updates completed. Reboot required.' } else { 'System updates completed. No reboot required.' }

if (Get-Command Invoke-Notify -ErrorAction SilentlyContinue) {
    Invoke-Notify -Message $EventMessage -EventId $EventId -Title 'Systemopdatering' -LogFile $LogFile
} else {
    Write-EventLog -LogName $LogName -Source $Source -EventId $EventId -EntryType Information -Message $EventMessage
    if ($ToastAvailable) { New-BurntToastNotification -Text 'Systemopdatering', $EventMessage }
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

Write-Host "Scheduled task $TaskName created successfully." -ForegroundColor Green

$ScriptStopwatch.Stop()

$Elapsed = $ScriptStopwatch.Elapsed
$DurationText = '{0:hh\:mm\:ss}' -f $Elapsed


# ================================
# End notification
# ================================
$EndEventId = 1002
$EndMessage = "Daglig opdatering færdig (tid: $DurationText)"

if (Get-Command Invoke-Notify -ErrorAction SilentlyContinue) {
    Invoke-Notify -Message $EndMessage -EventId $EndEventId -Title 'Systemopdatering' -LogFile $LogFile
} else {
    Write-EventLog -LogName $LogName -Source $Source -EventId $EndEventId -EntryType Information -Message $EndMessage
    if ($ToastAvailable) { New-BurntToastNotification -Text 'Systemopdatering', $EndMessage }
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
                Write-Host "Launching elevated helper to update locked modules after exit: $helper"
                Start-Process -FilePath powershell -ArgumentList @('-NoProfile','-ExecutionPolicy','Bypass','-File',$helper,$tmp) -Verb RunAs
            } else {
                Write-Host "Helper not found: $helper" -ForegroundColor Yellow
            }
        } catch {
            Write-Host "Failed to launch helper: $_" -ForegroundColor Yellow
        }
    }
}

exit $global:ExitCode