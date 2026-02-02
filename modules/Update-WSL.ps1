<#
.SYNOPSIS
Attempts to update packages inside each WSL distro (best-effort for Debian-based distros).

.DESCRIPTION
`Invoke-UpdateWSL` enumerates WSL distros and runs `sudo apt update && sudo apt upgrade -y` inside each distro using `wsl.exe`.

.PARAMETER WhatIf
If specified, the function will not perform changes.

.PARAMETER LogFile
Optional JSONL log file path to append structured results.

.EXAMPLE
Invoke-UpdateWSL -WhatIf -LogFile C:\Temp\updates.jsonl
#>
function Invoke-UpdateWSL {
    [CmdletBinding()]
    param(
        [switch]$WhatIf,
        [string]$LogFile
    )

    $start = Get-Date
    $result = [PSCustomObject]@{
        Module = 'WSL'
        Success = $false
        Message = ''
        Duration = 0
        Errors = @()
        DistroResults = @()
        Output = ''
    }

    if ($WhatIf) {
        $result.Message = 'WhatIf: Skipping WSL distro updates'
        $result.Success = $true
    } else {
        try {
            # Check if wsl.exe exists
            if (-not (Get-Command wsl.exe -ErrorAction SilentlyContinue)) {
                # WSL not installed, try to enable it
                Write-Host "  WSL not found. Attempting to enable WSL..." -ForegroundColor Yellow
                
                try {
                    # Enable WSL and Virtual Machine Platform
                    Enable-WindowsOptionalFeature -FeatureName Microsoft-Windows-Subsystem-Linux -Online -NoRestart -ErrorAction Stop | Out-Null
                    Enable-WindowsOptionalFeature -FeatureName VirtualMachinePlatform -Online -NoRestart -ErrorAction Stop | Out-Null
                    
                    Write-Host "  WSL features enabled. Restart required to complete installation." -ForegroundColor Yellow
                    $result.Message = 'WSL features enabled. Please restart your computer, then install a Linux distribution from Microsoft Store.'
                    $result.Success = $false
                } catch {
                    $result.Errors += $_.Exception.Message
                    $result.Message = "WSL not installed and failed to enable: $($_.Exception.Message)"
                    $result.Success = $false
                }
            } else {
                # Try preferred list options, capture both stdout and stderr to avoid raw help printing
                $raw = & wsl.exe --list --quiet 2>&1
                if (-not $raw -or ($raw -join "`n") -match 'Usage:') {
                    $raw = & wsl.exe -l -q 2>&1
                }

                if (-not $raw) {
                    $result.Message = 'WSL is installed but no distributions found. Install a Linux distribution from Microsoft Store (e.g., Ubuntu).'
                    $result.Success = $true
                } elseif (($raw -join "`n") -match 'Usage:') {
                    # wsl produced usage text -> likely unsupported flags; do not emit help to user
                    $result.Message = 'wsl present but list flags unsupported on this host'
                    $result.Output = ($raw -join "`n")
                } else {
                    $lines = $raw -split "`n" | ForEach-Object { $_.Trim() } | Where-Object { $_ -and ($_ -notmatch '^Windows') -and ($_ -notmatch '^Usage:') }
                    $distros = $lines | Where-Object { $_ -ne '' }

                    if ($distros.Count -gt 0) {
                        foreach ($distro in $distros) {
                            try {
                                # Run command inside distro, capture output and exit code
                                $cmdOut = & wsl.exe -d $distro -- sh -lc 'sudo apt update && sudo DEBIAN_FRONTEND=noninteractive apt -y upgrade' 2>&1
                                $combined = ($cmdOut -join "`n")
                                if ($LASTEXITCODE -eq 0) {
                                    $result.DistroResults += [PSCustomObject]@{ Distro = $distro; Success = $true; Output = $combined }
                                } else {
                                    $result.DistroResults += [PSCustomObject]@{ Distro = $distro; Success = $false; Error = $combined }
                                }
                            } catch {
                                $result.DistroResults += [PSCustomObject]@{ Distro = $distro; Success = $false; Error = $_.Exception.Message }
                            }
                        }
                        $result.Success = $true
                        $result.Message = 'WSL distro updates attempted'
                    } else {
                        $result.Message = 'No WSL distros found'
                        $result.Success = $true
                    }
                }
            } else {
                $result.Message = 'wsl.exe not found'
            }
        } catch {
            $result.Errors += $_.Exception.Message
            $result.Message = 'WSL update failed'
            $result.Success = $false
        }
    }

    $result.Duration = (Get-Date) - $start
    if ($LogFile -and (Get-Command Write-LogJsonLine -ErrorAction SilentlyContinue)) { Write-LogJsonLine -Object $result -LogFile $LogFile }
    return $result
}
