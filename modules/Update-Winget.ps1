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
    }

    if ($WhatIf) {
        $result.Message = 'WhatIf: Skipping Winget updates'
        $result.Success = $true
    } else {
        try {
            if (Get-Command winget -ErrorAction SilentlyContinue) {
                Write-Host "Updating Winget packages (excluding Microsoft Office)..."

                $packages = winget upgrade --source winget | Select-Object -Skip 1

                foreach ($line in $packages) {
                    if ($line -match "Microsoft\.Office") {
                        Write-Host "Skipping Microsoft Office (handled by C2R)"
                        continue
                    }

                    if ($line -match "^\s*(.+?)\s{2,}(\S+)\s{2,}") {
                        $packageId = $matches[2]

                        winget upgrade `
                            --id $packageId `
                            --accept-source-agreements `
                            --accept-package-agreements `
                            --scope machine
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