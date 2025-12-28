<#
.SYNOPSIS
Runs Windows Update via PSWindowsUpdate module.

.DESCRIPTION
`Invoke-UpdateWindows` ensures PSWindowsUpdate is available, imports it, and invokes `Get-WindowsUpdate` to install Microsoft updates.

.PARAMETER WhatIf
If specified, the function will not perform changes.

.PARAMETER LogFile
Optional JSONL log file path to append structured results.

.EXAMPLE
Invoke-UpdateWindows -WhatIf -LogFile C:\Temp\updates.jsonl
#>
function Invoke-UpdateWindows {
    [CmdletBinding()]
    param(
        [switch]$WhatIf,
        [string]$LogFile
    )

    $start = Get-Date
    $result = [PSCustomObject]@{
        Module = 'WindowsUpdate'
        Success = $false
        Message = ''
        Duration = 0
        Errors = @()
    }

    if ($WhatIf) {
        $result.Message = 'WhatIf: Skipping Windows Update'
        $result.Success = $true
    } else {
        try {
            Write-Host "Running Microsoft Update..."

            if (-not (Get-Module -ListAvailable -Name PSWindowsUpdate)) {
                Install-Module PSWindowsUpdate -Force -Confirm:$false
            }

            Import-Module PSWindowsUpdate -ErrorAction Stop
            Get-WindowsUpdate `
                -MicrosoftUpdate `
                -AcceptAll `
                -Install `
                -IgnoreReboot

            $result.Success = $true
            $result.Message = 'Windows Update invoked'
        } catch {
            $result.Errors += $_.Exception.Message
            $result.Message = 'Windows Update failed'
            $result.Success = $false
        }
    }

    $result.Duration = (Get-Date) - $start
    if ($LogFile -and (Get-Command Write-LogJsonLine -ErrorAction SilentlyContinue)) { Write-LogJsonLine -Object $result -LogFile $LogFile }
    return $result
}
