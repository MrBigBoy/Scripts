function Invoke-Notify {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][string]$Message,
        [int]$EventId = 1000,
        [string]$Title = 'Systemopdatering',
        [string]$LogName = 'Application',
        [string]$Source = 'SystemUpdater',
        [ValidateSet('Information','Warning','Error')] [string]$EntryType = 'Information'
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
        }
    } catch {
        Write-Host "Toast notification failed: $_" -ForegroundColor Yellow
    }
}