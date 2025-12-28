function Invoke-UpdateWindows {
    [CmdletBinding()]
    param()

    try {
        Write-Host "Running Microsoft Update..."

        if (-not (Get-Module -ListAvailable -Name PSWindowsUpdate)) {
            Install-Module PSWindowsUpdate -Force -Confirm:$false
        }

        Import-Module PSWindowsUpdate -ErrorAction Stop
        Get-WindowsUpdate `
            -MicrosoftUpdate `
            -AcceptAll `
            -Install `
            -IgnoreReboot

        return $true
    } catch {
        Write-Host "Microsoft Update failed: $_" -ForegroundColor Yellow
        return $false
    }
}
