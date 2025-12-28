<#
.SYNOPSIS
Updates Scoop and installed buckets/apps.

.DESCRIPTION
`Invoke-UpdateScoop` runs `scoop update *` and `scoop cleanup -f` when Scoop is available.

.PARAMETER WhatIf
If specified, the function will not perform changes.

.PARAMETER LogFile
Optional JSONL log file path to append structured results.

.EXAMPLE
Invoke-UpdateScoop -WhatIf -LogFile C:\Temp\updates.jsonl
#>
function Invoke-UpdateScoop {
    [CmdletBinding()]
    param(
        [switch]$WhatIf,
        [string]$LogFile
    )

    $start = Get-Date
    $result = [PSCustomObject]@{
        Module = 'Scoop'
        Success = $false
        Message = ''
        Duration = 0
        Errors = @()
    }

    if ($WhatIf) {
        $result.Message = 'WhatIf: Skipping Scoop updates'
        $result.Success = $true
    } else {
        try {
            if (Get-Command scoop -ErrorAction SilentlyContinue) {
                scoop update *
                scoop cleanup -f
                $result.Success = $true
                $result.Message = 'Scoop updated'
            } else {
                $result.Message = 'Scoop not installed'
            }
        } catch {
            $result.Errors += $_.Exception.Message
            $result.Message = 'Scoop update failed'
            $result.Success = $false
        }
    }

    $result.Duration = (Get-Date) - $start
    if ($LogFile -and (Get-Command Write-LogJsonLine -ErrorAction SilentlyContinue)) { Write-LogJsonLine -Object $result -LogFile $LogFile }
    return $result
}
