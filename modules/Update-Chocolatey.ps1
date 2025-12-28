<#
.SYNOPSIS
Updates Chocolatey packages.

.DESCRIPTION
`Invoke-UpdateChocolatey` updates all Chocolatey packages using `choco upgrade all`.

.PARAMETER WhatIf
If specified, the function will not perform changes and will return a simulated result.

.PARAMETER LogFile
Optional JSONL log file path to append structured results.

.EXAMPLE
Invoke-UpdateChocolatey -WhatIf -LogFile C:\Temp\updates.jsonl
#>
function Invoke-UpdateChocolatey {
    [CmdletBinding()]
    param(
        [switch]$WhatIf,
        [string]$LogFile
    )

    $start = Get-Date
    $result = [PSCustomObject]@{
        Module = 'Chocolatey'
        Success = $false
        Message = ''
        Duration = 0
        Errors = @()
        Output = ''
    }

    if ($WhatIf) {
        $result.Message = 'WhatIf: Skipping Chocolatey updates'
        $result.Success = $true
    } else {
        try {
            if (Get-Command choco -ErrorAction SilentlyContinue) {
                # capture output (stdout+stderr) and avoid printing to console
                $out = & choco upgrade all -y --ignore-checksums --fail-on-unfound=false 2>&1
                $result.Output = ($out -join "`n")
                $result.Success = $true
                $result.Message = 'Chocolatey upgrade completed'
            } else {
                $result.Message = 'Chocolatey not installed'
                $result.Success = $false
            }
        } catch {
            $result.Errors += $_.Exception.Message
            $result.Message = 'Chocolatey upgrade failed'
            $result.Success = $false
        }
    }

    $result.Duration = (Get-Date) - $start
    if ($LogFile -and (Get-Command Write-LogJsonLine -ErrorAction SilentlyContinue)) { Write-LogJsonLine -Object $result -LogFile $LogFile }
    return $result
}
