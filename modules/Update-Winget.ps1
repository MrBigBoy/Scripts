function Invoke-UpdateWinget {
    [CmdletBinding()]
    param()

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
            return $true
        } else {
            Write-Host "Winget not installed, skipping."
            return $false
        }
    } catch {
        Write-Host "Winget update failed: $_" -ForegroundColor Yellow
        return $false
    }
}