function Invoke-UpdatePowerShellModules {
    [CmdletBinding()]
    param()

    $failedModules = @()
    try {
        Write-Host "Updating PowerShell modules..."
        Get-InstalledModule -ErrorAction SilentlyContinue |
            Where-Object { $_.Repository -eq 'PSGallery' } |
            ForEach-Object {
                $name = $_.Name
                try {
                    Update-Module -Name $name -Force -ErrorAction Stop
                    Write-Host "Updated PowerShell module: $name"
                } catch {
                    $msg = $_.Exception.Message
                    Write-Host ("Failed to update module {0}: {1}" -f $name, $msg) -ForegroundColor Yellow
                    if ($msg -match 'in use|currently in use|being used') {
                        $failedModules += $name
                    }
                }
            }

        $success = $true
        if ($failedModules.Count -gt 0) {
            Write-Host "Some modules are in use and could not be updated now: $($failedModules -join ', ')" -ForegroundColor Yellow
            $success = $false
        }

        return [PSCustomObject]@{
            Success = $success
            FailedModules = $failedModules
        }
    } catch {
        Write-Host "PowerShell modules update failed: $_" -ForegroundColor Yellow
        return [PSCustomObject]@{
            Success = $false
            FailedModules = @()
        }
    }
}
