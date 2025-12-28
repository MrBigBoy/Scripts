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
    }

    if ($WhatIf) {
        $result.Message = 'WhatIf: Skipping WSL distro updates'
        $result.Success = $true
    } else {
        try {
            if (Get-Command wsl.exe -ErrorAction SilentlyContinue) {
                # Try preferred list options, capture both stdout and stderr to avoid raw help printing
                $raw = & wsl.exe --list --quiet 2>&1
                if (-not $raw -or ($raw -join "`n") -match 'Usage:') {
                    $raw = & wsl.exe -l -q 2>&1
                }

                if (-not $raw) {
                    $result.Message = 'wsl --list returned no output'
                } elseif (($raw -join "`n") -match 'Usage:') {
                    # wsl produced usage text -> likely unsupported flags; do not emit help to user
                    $result.Message = 'wsl present but list flags unsupported on this host'
                } else {
                    $lines = $raw -split "`n" | ForEach-Object { $_.Trim() } | Where-Object { $_ -and ($_ -notmatch '^Windows') -and ($_ -notmatch '^Usage:') }
                    $distros = $lines | Where-Object { $_ -ne '' }

                    if ($distros.Count -gt 0) {
                        foreach ($distro in $distros) {
                            try {
                                # Run command inside distro, capture output and exit code
                                $cmdOut = & wsl.exe -d $distro -- sh -lc 'sudo apt update && sudo DEBIAN_FRONTEND=noninteractive apt -y upgrade' 2>&1
                                if ($LASTEXITCODE -eq 0) {
                                    $result.DistroResults += [PSCustomObject]@{ Distro = $distro; Success = $true }
                                } else {
                                    $result.DistroResults += [PSCustomObject]@{ Distro = $distro; Success = $false; Error = ($cmdOut -join "`n") }
                                }
                            } catch {
                                $result.DistroResults += [PSCustomObject]@{ Distro = $distro; Success = $false; Error = $_.Exception.Message }
                            }
                        }
                        $result.Success = $true
                        $result.Message = 'WSL distro updates attempted'
                    } else {
                        $result.Message = 'No WSL distros found'
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
