<#
.SYNOPSIS
Updates installed PowerShell modules from PSGallery.

.DESCRIPTION
`Invoke-UpdatePowerShellModules` enumerates modules installed from PSGallery and attempts to update them. If modules are locked/in use, the orchestrator may schedule an elevated helper to retry updates after exit.

.PARAMETER WhatIf
If specified, the function will not perform changes.

.PARAMETER LogFile
Optional JSONL log file path to append structured results.

.EXAMPLE
Invoke-UpdatePowerShellModules -WhatIf -LogFile C:\Temp\updates.jsonl
#>
function Invoke-UpdatePowerShellModules {
    [CmdletBinding()]
    param(
        [switch]$WhatIf,
        [string]$LogFile
    )

    $start = Get-Date
    $failedModules = @()
    $errors = @()
    $result = [PSCustomObject]@{
        Module = 'PowerShellModules'
        Success = $false
        Message = ''
        Duration = 0
        Errors = @()
        FailedModules = @()
    }

    if ($WhatIf) {
        $result.Message = (Get-LocalizedString -Key 'WhatIfPowerShellModules')
        $result.Success = $true
    } else {
        try {
            Write-Host (Get-LocalizedString -Key 'UpdatingPowerShellModules')
            
            # Get installed modules and check for updates
            $installedModules = Get-InstalledModule -ErrorAction SilentlyContinue | Where-Object { $_.Repository -eq 'PSGallery' }
            $outdatedModules = @()
            
            Write-Host "Checking for outdated modules..." -ForegroundColor Cyan
            foreach ($module in $installedModules) {
                try {
                    $online = Find-Module -Name $module.Name -ErrorAction SilentlyContinue
                    if ($online -and ($online.Version -gt $module.Version)) {
                        $outdatedModules += [PSCustomObject]@{
                            Name = $module.Name
                            InstalledVersion = $module.Version
                            AvailableVersion = $online.Version
                            Location = $module.InstalledLocation
                        }
                    }
                } catch {
                    # Silently continue if we can't check a module
                }
            }
            
            if ($outdatedModules.Count -eq 0) {
                Write-Host "All modules are up to date." -ForegroundColor Green
            } else {
                Write-Host "`nFound $($outdatedModules.Count) outdated module(s):" -ForegroundColor Yellow
                $outdatedModules | ForEach-Object {
                    Write-Host "  - $($_.Name): $($_.InstalledVersion) -> $($_.AvailableVersion)" -ForegroundColor Gray
                }
                Write-Host ""
                
                # Update the outdated modules
                $outdatedModules | ForEach-Object {
                    $name = $_.Name
                    try {
                        Update-Module -Name $name -Force -ErrorAction Stop
                        Write-Host (Get-LocalizedString -Key 'UpdatedPowerShellModule' -FormatArgs $name)
                    } catch {
                        $msg = $_.Exception.Message
                        Write-Host (Get-LocalizedString -Key 'FailedToUpdateModule' -FormatArgs $name, $msg) -ForegroundColor Yellow
                        $errors += $msg
                        if ($msg -match 'in use|currently in use|being used') { $failedModules += $name }
                    }
                }
            }

            $result.Success = ($failedModules.Count -eq 0)
            $result.Message = (Get-LocalizedString -Key 'PowerShellModulesUpdateAttempted')
            $result.FailedModules = $failedModules
            $result.Errors = $errors
        } catch {
            $result.Errors += $_.Exception.Message
            $result.Message = (Get-LocalizedString -Key 'PowerShellModulesUpdateFailed')
            $result.Success = $false
        }
    }

    $result.Duration = (Get-Date) - $start
    if ($LogFile -and (Get-Command Write-LogJsonLine -ErrorAction SilentlyContinue)) { Write-LogJsonLine -Object $result -LogFile $LogFile }
    return $result
}
