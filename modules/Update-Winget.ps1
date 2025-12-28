<#
.SYNOPSIS
Updates packages via winget (excluding Microsoft Office by default).

.DESCRIPTION
`Invoke-UpdateWinget` scans available upgrades from `winget upgrade` and attempts upgrades while skipping Microsoft Office packages.

.PARAMETER WhatIf
If specified, the function will not perform changes.

.PARAMETER LogFile
Optional JSONL log file path to append structured results.

.EXAMPLE
Invoke-UpdateWinget -WhatIf -LogFile C:\Temp\updates.jsonl
#>
function Invoke-UpdateWinget {
    [CmdletBinding()]
    param(
        [switch]$WhatIf,
        [string]$LogFile
    )

    $start = Get-Date
    $result = [PSCustomObject]@{
        Module = 'Winget'
        Success = $false
        Message = ''
        Duration = 0
        Errors = @()
        Output = ''
    }

    if ($WhatIf) {
        $result.Message = 'WhatIf: Skipping Winget updates'
        $result.Success = $true
    } else {
        try {
            if (Get-Command winget -ErrorAction SilentlyContinue) {
                # capture upgrade list and operations
                $rawList = & winget upgrade --source winget 2>&1 | Select-Object -Skip 1
                $result.Output = ($rawList -join "`n")

                foreach ($line in $rawList) {
                    if ($line -match "Microsoft\.Office") { continue }
                    if ($line -match "^\s*(.+?)\s{2,}(\S+)\s{2,}") {
                        $packageId = $matches[2]
                        & winget upgrade --id $packageId --accept-source-agreements --accept-package-agreements --scope machine 2>&1 | Out-Null
                    }
                }

                $result.Success = $true
                $result.Message = 'Winget upgrades attempted'
            } else {
                $result.Message = 'Winget not installed'
                $result.Success = $false
            }
        } catch {
            $result.Errors += $_.Exception.Message
            $result.Message = 'Winget upgrade failed'
            $result.Success = $false
        }
    }

    $result.Duration = (Get-Date) - $start
    if ($LogFile -and (Get-Command Write-LogJsonLine -ErrorAction SilentlyContinue)) { Write-LogJsonLine -Object $result -LogFile $LogFile }
    return $result
}