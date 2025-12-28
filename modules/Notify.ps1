function Ensure-ToastAvailable {
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
            $toastOk = Ensure-ToastAvailable
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