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
# Winget update (Office excluded, version-safe)
# ================================
if (Get-Command winget -ErrorAction SilentlyContinue) {
    Write-Host "Updating Winget packages (excluding Microsoft Office)..."

    $packages = winget upgrade --source winget | Select-Object -Skip 1

    foreach ($line in $packages) {
        if ($line -match "Microsoft\.Office") {
            Write-Host "Skipping Microsoft Office (handled by C2R)"
            continue
        }

        if ($line -match "^\s*(.+?)\s{2,}(\S+)\s{2,}") {
            $packageId = $matches[2]

            winget upgrade `
                --id $packageId `
                --accept-source-agreements `
                --accept-package-agreements `
                --scope machine
        }
    }
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
try {
    $cim = Get-CimInstance -Namespace root\cimv2\mdm\dmmap -ClassName MDM_EnterpriseModernAppManagement_AppManagement01 -ErrorAction Stop
    $storeRes = $cim | Invoke-CimMethod -MethodName UpdateScanMethod -ErrorAction Stop
    if ($storeRes -and $storeRes.ReturnValue -ne 0) {
        Write-Host "Store update reported non-zero return value: $($storeRes.ReturnValue)" -ForegroundColor Yellow
    } else {
        Write-Host "Store update invoked successfully." -ForegroundColor Green
    }
} catch {
    Write-Host "Microsoft Store update failed: $_" -ForegroundColor Yellow
}

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
# Scoop (if installed)
# ================================
if (Get-Command scoop -ErrorAction SilentlyContinue) {
    Write-Host "Updating Scoop and Scoop packages..."
    try {
        # use wildcard to update all apps; avoid bare '@' token which breaks parsing
        scoop update *
        scoop cleanup -f
    } catch {
        Write-Host "Scoop update failed: $_" -ForegroundColor Yellow
    }
}

# ================================
# Python packages (pip & pipx)
# ================================
Write-Host "Updating Python packages..."
$pythonCmd = $null
if (Get-Command python -ErrorAction SilentlyContinue) { $pythonCmd = "python" }
elseif (Get-Command py -ErrorAction SilentlyContinue) { $pythonCmd = "py" }

if ($pythonCmd) {
    try {
        if ($pythonCmd -eq 'py') {
            & py -3 -m pip install --upgrade pip setuptools wheel 2>$null
        } else {
            & python -m pip install --upgrade pip setuptools wheel 2>$null
        }
    } catch {
        Write-Host "Failed to upgrade pip/core tooling: $_" -ForegroundColor Yellow
    }

    try {
        if ($pythonCmd -eq 'py') {
            $outdated = & py -3 -m pip list --outdated --format=freeze 2>$null
        } else {
            $outdated = & python -m pip list --outdated --format=freeze 2>$null
        }

        if ($outdated) {
            $outdated | ForEach-Object {
                $name = ($_ -split '==')[0]
                if ($name) {
                    Write-Host "Upgrading Python package: $name"
                    if ($pythonCmd -eq 'py') {
                        & py -3 -m pip install --upgrade $name 2>$null
                    } else {
                        & python -m pip install --upgrade $name 2>$null
                    }
                }
            }
        }
    } catch {
        Write-Host "Failed to enumerate or upgrade Python packages: $_" -ForegroundColor Yellow
    }
}

if (Get-Command pipx -ErrorAction SilentlyContinue) {
    Write-Host "Updating pipx-managed packages..."
    try {
        pipx upgrade-all 2>$null
    } catch {
        Write-Host "pipx upgrade-all failed: $_" -ForegroundColor Yellow
    }
}

# ================================
# Rust (rustup)
# ================================
if (Get-Command rustup -ErrorAction SilentlyContinue) {
    Write-Host "Updating Rust toolchain..."
    try {
        rustup update
    } catch {
        Write-Host "rustup update failed: $_" -ForegroundColor Yellow
    }
}

# ================================
# Ruby Gems
# ================================
if (Get-Command gem -ErrorAction SilentlyContinue) {
    Write-Host "Updating RubyGems and installed gems..."
    try {
        gem update --system --no-document 2>$null
        gem update --no-document 2>$null
    } catch {
        Write-Host "gem update failed: $_" -ForegroundColor Yellow
    }
}

# ================================
# Visual Studio Code extensions
# ================================
if (Get-Command code -ErrorAction SilentlyContinue) {
    Write-Host "Refreshing Visual Studio Code extensions..."
    try {
        $extensions = code --list-extensions 2>$null
        if ($extensions) {
            $extensions | ForEach-Object {
                Write-Host "Reinstalling extension: $_"
                code --install-extension $_ --force 2>$null
            }
        }
    } catch {
        Write-Host "VSCode extension refresh failed: $_" -ForegroundColor Yellow
    }
}

# ================================
# Docker images cleanup and pull existing images
# ================================
if (Get-Command docker -ErrorAction SilentlyContinue) {
    Write-Host 'Checking Docker status...'
    try {
        docker info > $null 2>&1
        if ($LASTEXITCODE -eq 0) {
            Write-Host 'Updating Docker images present on the system...'
            try {
                $images = docker images --format "{{.Repository}}:{{.Tag}}" | Where-Object { $_ -and ($_ -notmatch '<none>') }
                foreach ($img in $images) {
                    try {
                        Write-Host "Pulling image: $img"
                        docker pull $img 2>$null
                    } catch {
                        Write-Host ('Failed to pull {0}: {1}' -f $img, $_) -ForegroundColor Yellow
                    }
                }

                Write-Host 'Pruning unused Docker data...'
                docker system prune -af 2>$null
            } catch {
                Write-Host ('Docker image update failed: {0}' -f $_) -ForegroundColor Yellow
            }
        } else {
            Write-Host 'Docker present but not running or accessible — skipping Docker updates.'
        }
    } catch {
        Write-Host ('Docker status check failed: {0}' -f $_) -ForegroundColor Yellow
    }
}

# ================================
# .NET workloads
# ================================
if (Get-Command dotnet -ErrorAction SilentlyContinue) {
    Write-Host 'Updating .NET workloads...'
    dotnet workload update
}

# ================================
# Clear NuGet cache
# ================================
if (Get-Command dotnet -ErrorAction SilentlyContinue) {
    Write-Host 'Clearing NuGet cache...'
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
    Write-Host 'Clearing global node_modules...'
    Remove-Item "$GlobalNodeModules\*" -Recurse -Force -ErrorAction SilentlyContinue
}

# ================================
# WSL presence check (safe)
# ================================
if (Get-Command wsl.exe -ErrorAction SilentlyContinue) {
    Write-Host 'Checking WSL status...'
    $wslOut = & wsl.exe --status 2>&1
    if ($LASTEXITCODE -eq 0) {
        Write-Host 'WSL detected — updates handled via Store or Windows Update'
    } else {
        Write-Host 'WSL present but status check failed — skipping' -ForegroundColor Yellow
        Write-Host "wsl.exe output: $wslOut"
    }
}

# ================================
# Visual Studio Installer - Update All (if available)
# ================================
$vsInstaller = "$env:ProgramFiles(x86)\Microsoft Visual Studio\Installer\setup.exe"
if (Test-Path $vsInstaller) {
    Write-Host "Running Visual Studio Installer update..."
    try {
        # Attempt to invoke installer update; arguments may vary across versions.
        Start-Process -FilePath $vsInstaller -ArgumentList 'update','--quiet' -Wait -NoNewWindow -ErrorAction Stop
        Write-Host "Visual Studio Installer update started." -ForegroundColor Green
    } catch {
        Write-Host "Visual Studio Installer update failed to start: $_" -ForegroundColor Yellow
    }
} else {
    Write-Host "Visual Studio Installer not found at '$vsInstaller' - skipping." -ForegroundColor Yellow
}

# ================================
# Windows system cleanup
# ================================
Write-Host "Running DISM component cleanup (may take a while)..."
try {
    Start-Process -FilePath dism.exe -ArgumentList '/Online','/Cleanup-Image','/StartComponentCleanup','/ResetBase' -Wait -NoNewWindow -ErrorAction Stop
    Write-Host "DISM component cleanup completed." -ForegroundColor Green
} catch {
    Write-Host "DISM component cleanup failed: $_" -ForegroundColor Yellow
}

Write-Host "Configuring Disk Cleanup (CleanMgr) sageset 1 to select all Volume Caches..."
$vcKey = 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Explorer\VolumeCaches'
try {
    if (Test-Path $vcKey) {
        Get-ChildItem -Path $vcKey -ErrorAction SilentlyContinue | ForEach-Object {
            $path = $_.PsPath
            # StateFlags0001 corresponds to sageset:1; set value to 2 to mark for cleanup
            New-ItemProperty -Path $path -Name 'StateFlags0001' -PropertyType DWord -Value 2 -Force -ErrorAction SilentlyContinue | Out-Null
        }
        Write-Host "VolumeCaches configured for CleanMgr sageset 1." -ForegroundColor Green

        Write-Host "Running CleanMgr /sagerun:1 (system cleanup using sageset 1)..."
        try {
            Start-Process -FilePath cleanmgr.exe -ArgumentList '/sagerun:1' -Wait -NoNewWindow -ErrorAction Stop
            Write-Host "CleanMgr completed." -ForegroundColor Green
        } catch {
            Write-Host "CleanMgr run failed: $_" -ForegroundColor Yellow
        }
    } else {
        Write-Host "VolumeCaches registry path not found - skipping CleanMgr configuration." -ForegroundColor Yellow
    }
} catch {
    Write-Host "Failed configuring CleanMgr sageset: $_" -ForegroundColor Yellow
}

# ================================
# Reboot detection
# ================================
$RebootRequired = Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired'

# ================================
# Event Log signal (user toast trigger)
# ================================
$LogName = 'Application'
$Source  = 'SystemUpdater'
$EventId = 1001

if (-not [System.Diagnostics.EventLog]::SourceExists($Source)) {
    New-EventLog -LogName $LogName -Source $Source
}

$EventMessage = if ($RebootRequired) { 'System updates completed. Reboot required.' } else { 'System updates completed. No reboot required.' }

Write-EventLog -LogName $LogName -Source $Source -EventId $EventId -EntryType Information -Message $EventMessage

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

exit $global:ExitCode