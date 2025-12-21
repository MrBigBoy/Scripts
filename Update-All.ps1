# ================================
# Self-elevate to Administrator
# ================================
if (-not ([Security.Principal.WindowsPrincipal] `
    [Security.Principal.WindowsIdentity]::GetCurrent()
    ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {

    Start-Process powershell `
        -ArgumentList "-NoProfile -ExecutionPolicy Bypass -File `"$PSCommandPath`"" `
        -Verb RunAs
    exit
}

if ($Host.UI -and $Host.UI.RawUI) {
    Clear-Host
}

# ================================
# Non-interactive / CI-safe mode
# ================================
$ProgressPreference = 'SilentlyContinue'
$ErrorActionPreference = 'Continue'

# ================================
# Exit code handling
# ================================
$global:ExitCode = 0
trap {
    Write-Host "Error: $_" -ForegroundColor Red
    $global:ExitCode = 1
}

Write-Host "Running as Administrator" -ForegroundColor Green

# ================================
# Chocolatey update (fail-safe)
# ================================
if (Get-Command choco -ErrorAction SilentlyContinue) {
    Write-Host "Updating Chocolatey packages..."
    choco upgrade all -y --ignore-checksums --fail-on-unfound=false
}

# ================================
# Winget update (full coverage, Office excluded)
# ================================
if (Get-Command winget -ErrorAction SilentlyContinue) {
    Write-Host "Updating Winget packages (excluding Microsoft Office)..."
    winget upgrade --all `
        --accept-source-agreements `
        --accept-package-agreements `
        --include-unknown `
        --scope machine `
        --exclude Microsoft.Office
}

# ================================
# Microsoft Update (Windows + MS)
# ================================
Write-Host "Running Microsoft Update..."

if (-not (Get-Module -ListAvailable -Name PSWindowsUpdate)) {
    Install-Module PSWindowsUpdate -Force -Confirm:$false
}

Import-Module PSWindowsUpdate
Get-WindowsUpdate `
    -MicrosoftUpdate `
    -AcceptAll `
    -Install `
    -IgnoreReboot

# ================================
# Microsoft Store apps
# ================================
Write-Host "Updating Microsoft Store apps..."
Get-CimInstance -Namespace root\cimv2\mdm\dmmap `
    -ClassName MDM_EnterpriseModernAppManagement_AppManagement01 |
    Invoke-CimMethod -MethodName UpdateScanMethod

# ================================
# Windows Defender signatures
# ================================
if (Get-Command Update-MpSignature -ErrorAction SilentlyContinue) {
    Write-Host "Updating Windows Defender signatures..."
    Update-MpSignature
}

# ================================
# PowerShell modules (PSGallery)
# ================================
Write-Host "Updating PowerShell modules..."
Get-InstalledModule -ErrorAction SilentlyContinue |
    Where-Object { $_.Repository -eq "PSGallery" } |
    ForEach-Object {
        Update-Module -Name $_.Name -Force -ErrorAction SilentlyContinue
    }

# ================================
# Node.js & npm updates
# ================================
if (Get-Command npm -ErrorAction SilentlyContinue) {
    Write-Host "Updating npm..."
    npm install -g npm
    npm update -g
    npm cache clean --force
}

# ================================
# .NET workloads
# ================================
if (Get-Command dotnet -ErrorAction SilentlyContinue) {
    Write-Host "Updating .NET workloads..."
    dotnet workload update
}

# ================================
# Clear NuGet cache
# ================================
if (Get-Command dotnet -ErrorAction SilentlyContinue) {
    Write-Host "Clearing NuGet cache..."
    dotnet nuget locals all --clear
}

$NuGetPath = "$env:USERPROFILE\.nuget\packages"
if (Test-Path $NuGetPath) {
    Remove-Item "$NuGetPath\*" -Recurse -Force -ErrorAction SilentlyContinue
}

# ================================
# Clear global node_modules
# ================================
$GlobalNodeModules = "$env:APPDATA\npm\node_modules"
if (Test-Path $GlobalNodeModules) {
    Write-Host "Clearing global node_modules..."
    Remove-Item "$GlobalNodeModules\*" -Recurse -Force -ErrorAction SilentlyContinue
}

# ================================
# WSL update
# ================================
if (Get-Command wsl -ErrorAction SilentlyContinue) {
    Write-Host "Updating WSL..."
    wsl --update
}

# ================================
# Reboot detection
# ================================
$RebootRequired = Test-Path "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired"

# ================================
# Event Log signal (user toast trigger)
# ================================
$LogName = "Application"
$Source  = "SystemUpdater"
$EventId = 1001

if (-not [System.Diagnostics.EventLog]::SourceExists($Source)) {
    New-EventLog -LogName $LogName -Source $Source
}

$EventMessage = if ($RebootRequired) {
    "System updates completed. Reboot required."
} else {
    "System updates completed. No reboot required."
}

Write-EventLog `
    -LogName $LogName `
    -Source $Source `
    -EventId $EventId `
    -EntryType Information `
    -Message $EventMessage

# ================================
# Scheduled Task creation
# ================================
$TaskName   = "Update System (Choco + Winget + Windows Update)"
$ScriptPath = "C:\Scripts\Update-All.ps1"

if (Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue) {
    Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
}

$Action = New-ScheduledTaskAction `
    -Execute "powershell.exe" `
    -Argument "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$ScriptPath`""

$Trigger = New-ScheduledTaskTrigger -Daily -At 01:00AM

$Principal = New-ScheduledTaskPrincipal `
    -UserId "SYSTEM" `
    -LogonType ServiceAccount `
    -RunLevel Highest

$Settings = New-ScheduledTaskSettingsSet `
    -AllowStartIfOnBatteries `
    -DontStopIfGoingOnBatteries `
    -StartWhenAvailable `
    -WakeToRun `
    -Hidden `
    -ExecutionTimeLimit (New-TimeSpan -Hours 4)

Register-ScheduledTask `
    -TaskName $TaskName `
    -Action $Action `
    -Trigger $Trigger `
    -Principal $Principal `
    -Settings $Settings `
    -Force

Write-Host "Scheduled task '$TaskName' created successfully." -ForegroundColor Green

exit $global:ExitCode
