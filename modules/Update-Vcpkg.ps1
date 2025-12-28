<#
.SYNOPSIS
Updates vcpkg installed packages.

.DESCRIPTION
`Invoke-UpdateVcpkg` calls `vcpkg upgrade --no-dry-run` when vcpkg is installed.

.PARAMETER WhatIf
If specified, the function will not perform changes.

.PARAMETER LogFile
Optional JSONL log file path to append structured results.

.EXAMPLE
Invoke-UpdateVcpkg -WhatIf -LogFile C:\Temp\updates.jsonl
#>
function Invoke-UpdateVcpkg {
    [CmdletBinding()]
    param(
        [switch]$WhatIf,
        [string]$LogFile
    )

    $start = Get-Date
    $result = [PSCustomObject]@{
        Module = 'Vcpkg'
        Success = $false
        Message = ''
        Duration = 0
        Errors = @()
    }

    if ($WhatIf) {
        $result.Message = 'WhatIf: Skipping vcpkg updates'
        $result.Success = $true
    } else {
        try {
            if (Get-Command vcpkg -ErrorAction SilentlyContinue) {
                vcpkg upgrade --no-dry-run
                $result.Success = $true
                $result.Message = 'vcpkg upgraded'
            } else {
                $result.Message = 'vcpkg not installed'
            }
        } catch {
            $result.Errors += $_.Exception.Message
            $result.Message = 'vcpkg update failed'
            $result.Success = $false
        }
    }

    $result.Duration = (Get-Date) - $start
    if ($LogFile -and (Get-Command Write-LogJsonLine -ErrorAction SilentlyContinue)) { Write-LogJsonLine -Object $result -LogFile $LogFile }
    return $result
}
