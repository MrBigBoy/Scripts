<#
.SYNOPSIS
Updates Vivaldi browser using winget or Chocolatey.
#>
function Invoke-UpdateVivaldi {
    [CmdletBinding()]
    param(
        [switch]$WhatIf,
        [string]$LogFile
    )

    $start = Get-Date
    $result = [PSCustomObject]@{
        Module = 'Vivaldi'
        Success = $false
        Message = ''
        Duration = 0
        Errors = @()
        Output = ''
    }

    if ($WhatIf) {
        $result.Message = 'WhatIf: Skipping Vivaldi updates'
        $result.Success = $true
    } else {
        try {
            if (Get-Command winget -ErrorAction SilentlyContinue) {
                $out = & winget upgrade --id Vivaldi.Vivaldi --accept-source-agreements --accept-package-agreements --scope machine 2>&1
                $result.Output = ($out -join "`n")
                $result.Success = ($LASTEXITCODE -eq 0 -and -not ($result.Output -match 'No installed package found'))
                $result.Message = 'Vivaldi attempted via winget'
            } elseif (Get-Command choco -ErrorAction SilentlyContinue) {
                $out = & choco upgrade vivaldi -y 2>&1
                $result.Output = ($out -join "`n")
                $result.Success = ($LASTEXITCODE -eq 0)
                $result.Message = 'Vivaldi attempted via choco'
            } else {
                $result.Message = 'No updater (winget/choco) available for Vivaldi'
                $result.Success = $false
            }
        } catch {
            $result.Errors += $_.Exception.Message
            $result.Message = 'Vivaldi update failed'
            $result.Success = $false
        }
    }

    $result.Duration = (Get-Date) - $start
    if ($LogFile -and (Get-Command Write-LogJsonLine -ErrorAction SilentlyContinue)) { Write-LogJsonLine -Object $result -LogFile $LogFile }
    return $result
}
