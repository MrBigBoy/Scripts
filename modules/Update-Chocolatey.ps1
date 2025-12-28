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
    }

    if ($WhatIf) {
        $result.Message = 'WhatIf: Skipping Chocolatey updates'
        $result.Success = $true
    } else {
        try {
            if (Get-Command choco -ErrorAction SilentlyContinue) {
                Write-Host "Updating Chocolatey packages..."
                choco upgrade all -y --ignore-checksums --fail-on-unfound=false
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

    if ($LogFile -and (Get-Command Write-LogJsonLine -ErrorAction SilentlyContinue)) {
        Write-LogJsonLine -Object $result -LogFile $LogFile
    }

    return $result
}
