<#
.SYNOPSIS
Updates Conda environments and packages using `conda`.

.DESCRIPTION
`Invoke-UpdateConda` attempts to run `conda update --all -y` for the base/active environment. It requires `conda` on PATH.

.PARAMETER WhatIf
If specified, the function will not perform changes.

.PARAMETER LogFile
Optional JSONL log file path to append structured results.

.EXAMPLE
Invoke-UpdateConda -WhatIf -LogFile C:\Temp\updates.jsonl
#>
function Invoke-UpdateConda {
    [CmdletBinding()]
    param(
        [switch]$WhatIf,
        [string]$LogFile
    )

    $start = Get-Date
    $result = [PSCustomObject]@{
        Module = 'Conda'
        Success = $false
        Message = ''
        Duration = 0
        Errors = @()
    }

    if ($WhatIf) {
        $result.Message = 'WhatIf: Skipping Conda updates'
        $result.Success = $true
    } else {
        try {
            if (Get-Command conda -ErrorAction SilentlyContinue) {
                # Attempt to update base environment; use conda update --all
                & conda update --all -y 2>$null
                $result.Success = $true
                $result.Message = 'Conda update attempted'
            } else {
                $result.Message = 'conda not found on PATH'
                $result.Success = $false
            }
        } catch {
            $result.Errors += $_.Exception.Message
            $result.Message = 'Conda update failed'
            $result.Success = $false
        }
    }

    $result.Duration = (Get-Date) - $start
    if ($LogFile -and (Get-Command Write-LogJsonLine -ErrorAction SilentlyContinue)) { Write-LogJsonLine -Object $result -LogFile $LogFile }
    return $result
}
