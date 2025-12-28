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
