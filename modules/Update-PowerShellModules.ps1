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
        $result.Message = 'WhatIf: Skipping PowerShell modules update'
        $result.Success = $true
    } else {
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
                        $errors += $msg
                        if ($msg -match 'in use|currently in use|being used') { $failedModules += $name }
                    }
                }

            $result.Success = ($failedModules.Count -eq 0)
            $result.Message = 'PowerShell modules update attempted'
            $result.FailedModules = $failedModules
            $result.Errors = $errors
        } catch {
            $result.Errors += $_.Exception.Message
            $result.Message = 'PowerShell modules update failed'
            $result.Success = $false
        }
    }

    $result.Duration = (Get-Date) - $start
    if ($LogFile -and (Get-Command Write-LogJsonLine -ErrorAction SilentlyContinue)) { Write-LogJsonLine -Object $result -LogFile $LogFile }
    return $result
}
