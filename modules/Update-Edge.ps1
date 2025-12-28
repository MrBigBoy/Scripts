<#
.SYNOPSIS
Updates Microsoft Edge using winget or Chocolatey.
#>
function Invoke-UpdateEdge {
    [CmdletBinding()]
    param(
        [switch]$WhatIf,
        [string]$LogFile
    )

    $start = Get-Date
    $result = [PSCustomObject]@{
        Module = 'Edge'
        Success = $false
        Message = ''
        Duration = 0
        Errors = @()
        Output = ''
    }

    if ($WhatIf) {
        $result.Message = 'WhatIf: Skipping Edge updates'
        $result.Success = $true
    } else {
        try {
            if (Get-Command winget -ErrorAction SilentlyContinue) {
                $out = & winget upgrade --id Microsoft.Edge --accept-source-agreements --accept-package-agreements --scope machine 2>&1
                $result.Output = ($out -join "`n")
                $result.Success = ($LASTEXITCODE -eq 0 -and -not ($result.Output -match 'No installed package found'))
                $result.Message = 'Edge attempted via winget'
            } elseif (Get-Command choco -ErrorAction SilentlyContinue) {
                $out = & choco upgrade microsoft-edge -y 2>&1
                $result.Output = ($out -join "`n")
                $result.Success = ($LASTEXITCODE -eq 0)
                $result.Message = 'Edge attempted via choco'
            } else {
                $result.Message = 'No updater (winget/choco) available for Edge'
                $result.Success = $false
            }
        } catch {
            $result.Errors += $_.Exception.Message
            $result.Message = 'Edge update failed'
            $result.Success = $false
        }
    }

    $result.Duration = (Get-Date) - $start
    if ($LogFile -and (Get-Command Write-LogJsonLine -ErrorAction SilentlyContinue)) { Write-LogJsonLine -Object $result -LogFile $LogFile }
    return $result
}
