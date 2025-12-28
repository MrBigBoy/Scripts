function Invoke-UpdateChocolatey {
    [CmdletBinding()]
    param()

    try {
        if (Get-Command choco -ErrorAction SilentlyContinue) {
            Write-Host "Updating Chocolatey packages..."
            choco upgrade all -y --ignore-checksums --fail-on-unfound=false
            return $true
        } else {
            Write-Host "Chocolatey not installed, skipping."
            return $false
        }
    } catch {
        Write-Host "Chocolatey update failed: $_" -ForegroundColor Yellow
        return $false
    }
}
