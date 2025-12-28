<#
.SYNOPSIS
Updates global Composer packages.

.DESCRIPTION
`Invoke-UpdateComposer` runs `composer global update` if composer is present.

.PARAMETER WhatIf
If specified, the function will not perform changes.

.PARAMETER LogFile
Optional JSONL log file path to append structured results.

.EXAMPLE
Invoke-UpdateComposer -WhatIf -LogFile C:\Temp\updates.jsonl
#>
function Invoke-UpdateComposer {
    [CmdletBinding()]
    param(
        [switch]$WhatIf,
        [string]$LogFile
    )

    $start = Get-Date
    $result = [PSCustomObject]@{
        Module = 'Composer'
        Success = $false
        Message = ''
        Duration = 0
        Errors = @()
    }

    if ($WhatIf) {
        $result.Message = 'WhatIf: Skipping Composer updates'
        $result.Success = $true
    } else {
        try {
            if (Get-Command composer -ErrorAction SilentlyContinue) {
                composer global update
                $result.Success = $true
                $result.Message = 'Composer global update attempted'
            } else {
                $result.Message = 'Composer not installed'
            }
        } catch {
            $result.Errors += $_.Exception.Message
            $result.Message = 'Composer update failed'
            $result.Success = $false
        }
    }

    $result.Duration = (Get-Date) - $start
    if ($LogFile -and (Get-Command Write-LogJsonLine -ErrorAction SilentlyContinue)) { Write-LogJsonLine -Object $result -LogFile $LogFile }
    return $result
}
