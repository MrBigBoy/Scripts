<#
.SYNOPSIS
Updates Python packages (pip, pipx-managed packages).

.DESCRIPTION
`Invoke-UpdatePython` upgrades pip tooling and enumerates outdated packages to upgrade. Also calls `pipx upgrade-all` when pipx is present.

.PARAMETER WhatIf
If specified, the function will not perform changes.

.PARAMETER LogFile
Optional JSONL log file path to append structured results.

.EXAMPLE
Invoke-UpdatePython -WhatIf -LogFile C:\Temp\updates.jsonl
#>
function Invoke-UpdatePython {
    [CmdletBinding()]
    param(
        [switch]$WhatIf,
        [string]$LogFile
    )

    $start = Get-Date
    $result = [PSCustomObject]@{
        Module = 'Python'
        Success = $false
        Message = ''
        Duration = 0
        Errors = @()
    }

    if ($WhatIf) {
        $result.Message = 'WhatIf: Skipping Python updates'
        $result.Success = $true
    } else {
        $pythonCmd = $null
        if (Get-Command python -ErrorAction SilentlyContinue) { $pythonCmd = "python" }
        elseif (Get-Command py -ErrorAction SilentlyContinue) { $pythonCmd = "py" }

        if (-not $pythonCmd) {
            $result.Message = 'Python not found'
            $result.Success = $false
        } else {
            try {
                if ($pythonCmd -eq 'py') { & py -3 -m pip install --upgrade pip setuptools wheel 2>$null }
                else { & python -m pip install --upgrade pip setuptools wheel 2>$null }
            } catch {
                $result.Errors += $_.Exception.Message
            }

            try {
                if ($pythonCmd -eq 'py') { $outdated = & py -3 -m pip list --outdated --format=freeze 2>$null }
                else { $outdated = & python -m pip list --outdated --format=freeze 2>$null }

                if ($outdated) {
                    $outdated | ForEach-Object {
                        $name = ($_ -split '==')[0]
                        if ($name) {
                            if ($pythonCmd -eq 'py') { & py -3 -m pip install --upgrade $name 2>$null }
                            else { & python -m pip install --upgrade $name 2>$null }
                        }
                    }
                }
            } catch {
                $result.Errors += $_.Exception.Message
            }

            if (Get-Command pipx -ErrorAction SilentlyContinue) {
                try { pipx upgrade-all 2>$null } catch { $result.Errors += $_.Exception.Message }
            }

            $result.Success = ($result.Errors.Count -eq 0)
            $result.Message = 'Python updates attempted'
        }
    }

    $result.Duration = (Get-Date) - $start
    if ($LogFile -and (Get-Command Write-LogJsonLine -ErrorAction SilentlyContinue)) { Write-LogJsonLine -Object $result -LogFile $LogFile }
    return $result
}
