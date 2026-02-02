function Initialize-ToastNotifications {
    [CmdletBinding()]
    param(
        [int]$CheckInterval = 7,
        [string]$ModuleName = 'BurntToast'
    )

    $StateDir = Join-Path $env:LOCALAPPDATA 'SystemUpdater'
    $LastCheckFile = Join-Path $StateDir "$ModuleName.lastcheck"

    if (-not (Test-Path $StateDir)) { New-Item -Path $StateDir -ItemType Directory -Force | Out-Null }

    $DoUpdateCheck = -not (Test-Path $LastCheckFile) -or ((Get-Date) - (Get-Item $LastCheckFile).LastWriteTime).Days -ge $CheckInterval

    try {
        $Installed = Get-Module -ListAvailable -Name $ModuleName | Sort-Object Version -Descending | Select-Object -First 1
        if ($DoUpdateCheck) {
            $Latest = Find-Module -Name $ModuleName -ErrorAction Stop
            if (-not $Installed) { Install-Module -Name $ModuleName -Scope CurrentUser -Force -ErrorAction Stop }
            elseif ($Installed.Version -lt $Latest.Version) { Update-Module -Name $ModuleName -Scope CurrentUser -Force -ErrorAction Stop }
            New-Item -Path $LastCheckFile -ItemType File -Force | Out-Null
        }
        Import-Module $ModuleName -Force -ErrorAction Stop
        return $true
    } catch {
        return $false
    }
}

function Send-StartNotification {
    [CmdletBinding()]
    param(
        [string]$LogFile
    )
    
    $message = Get-LocalizedString -Key 'DailyUpdateStarted'
    $title = Get-LocalizedString -Key 'SystemUpdate'
    Invoke-Notify -Message $message -EventId 1000 -Title $title -LogFile $LogFile
}

function Send-CompletionNotification {
    [CmdletBinding()]
    param(
        [string]$LogFile
    )
    
    $rebootRequired = Test-Path 'HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired'
    $message = if ($rebootRequired) { 
        Get-LocalizedString -Key 'SystemUpdatesCompletedReboot' 
    } else { 
        Get-LocalizedString -Key 'SystemUpdatesCompleted' 
    }
    $title = Get-LocalizedString -Key 'SystemUpdate'
    Invoke-Notify -Message $message -EventId 1001 -Title $title -LogFile $LogFile
}

function Send-EndNotification {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Duration,
        
        [string]$LogFile,
        
        [Parameter(Mandatory=$false)]
        $Results
    )
    
    $message = Get-LocalizedString -Key 'DailyUpdateFinished' -FormatArgs $Duration
    $title = Get-LocalizedString -Key 'SystemUpdate'
    
    # Save results to temp file for viewer
    if ($Results) {
        try {
            $resultsFile = Join-Path $env:TEMP "SystemUpdater_LastResults.json"
            $Results | ConvertTo-Json -Depth 10 | Out-File -FilePath $resultsFile -Encoding UTF8 -Force
            
            # Create button to view results
            $viewerScript = Join-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) 'tools\Show-Results.ps1'
            if (Test-Path $viewerScript) {
                # Prefer PowerShell 7 if available
                $pwsh7Path = (Get-Command pwsh.exe -ErrorAction SilentlyContinue).Source
                $psExecutable = if ($pwsh7Path) { $pwsh7Path } else { 'powershell.exe' }
                
                $argument = "-NoProfile -ExecutionPolicy Bypass -NoExit -Command `"& '$viewerScript' -ResultsFile '$resultsFile'`""
                
                # Create toast with clickable action
                if (Get-Command New-BurntToastNotification -ErrorAction SilentlyContinue) {
                    $action = New-BTAction -ActivationType Protocol -Arguments "powershell://open?cmd=$([uri]::EscapeDataString($argument))"
                    # Fallback: use simple button since protocol might not work
                    New-BurntToastNotification -Text $title, $message -SuppressPopup $false -Button (New-BTButton -Content "Se resultater" -Arguments "$psExecutable $argument")
                } else {
                    Invoke-Notify -Message $message -EventId 1002 -Title $title -LogFile $LogFile
                }
                return
            }
        } catch {
            Write-Host "Failed to create results viewer: $_" -ForegroundColor Yellow
        }
    }
    
    # Fallback to regular notification
    Invoke-Notify -Message $message -EventId 1002 -Title $title -LogFile $LogFile
}

function Invoke-Notify {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][string]$Message,
        [int]$EventId = 1000,
        [string]$Title = 'Systemopdatering',
        [string]$LogName = 'Application',
        [string]$Source = 'SystemUpdater',
        [ValidateSet('Information','Warning','Error')] [string]$EntryType = 'Information',
        [string]$LogFile
    )

    try {
        if (-not [System.Diagnostics.EventLog]::SourceExists($Source)) {
            New-EventLog -LogName $LogName -Source $Source
        }

        Write-EventLog -LogName $LogName -Source $Source -EventId $EventId -EntryType $EntryType -Message $Message
    } catch {
        Write-Host "Failed to write event log: $_" -ForegroundColor Yellow
    }

    try {
        if (Get-Command New-BurntToastNotification -ErrorAction SilentlyContinue) {
            New-BurntToastNotification -Text $Title, $Message
        } else {
            $toastOk = Initialize-ToastNotifications
            if ($toastOk) { New-BurntToastNotification -Text $Title, $Message }
        }
    } catch {
        Write-Host "Toast notification failed: $_" -ForegroundColor Yellow
    }

    if ($LogFile) {
        if (Get-Command Write-LogJsonLine -ErrorAction SilentlyContinue) {
            $obj = [PSCustomObject]@{
                Timestamp = (Get-Date).ToString('o')
                Message = $Message
                EventId = $EventId
                Title = $Title
                EntryType = $EntryType
            }
            Write-LogJsonLine -Object $obj -LogFile $LogFile
        }
    }
}