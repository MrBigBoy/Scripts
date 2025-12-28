function Invoke-UpdatePython {
    [CmdletBinding()]
    param()

    Write-Host "Updating Python packages..."
    $pythonCmd = $null
    if (Get-Command python -ErrorAction SilentlyContinue) { $pythonCmd = "python" }
    elseif (Get-Command py -ErrorAction SilentlyContinue) { $pythonCmd = "py" }

    if (-not $pythonCmd) {
        Write-Host "Python not found, skipping." 
        return $false
    }

    try {
        if ($pythonCmd -eq 'py') {
            & py -3 -m pip install --upgrade pip setuptools wheel 2>$null
        } else {
            & python -m pip install --upgrade pip setuptools wheel 2>$null
        }
    } catch {
        Write-Host "Failed to upgrade pip/core tooling: $_" -ForegroundColor Yellow
    }

    try {
        if ($pythonCmd -eq 'py') {
            $outdated = & py -3 -m pip list --outdated --format=freeze 2>$null
        } else {
            $outdated = & python -m pip list --outdated --format=freeze 2>$null
        }

        if ($outdated) {
            $outdated | ForEach-Object {
                $name = ($_ -split '==')[0]
                if ($name) {
                    Write-Host "Upgrading Python package: $name"
                    if ($pythonCmd -eq 'py') {
                        & py -3 -m pip install --upgrade $name 2>$null
                    } else {
                        & python -m pip install --upgrade $name 2>$null
                    }
                }
            }
        }
    } catch {
        Write-Host "Failed to enumerate or upgrade Python packages: $_" -ForegroundColor Yellow
        return $false
    }

    if (Get-Command pipx -ErrorAction SilentlyContinue) {
        Write-Host "Updating pipx-managed packages..."
        try {
            pipx upgrade-all 2>$null
        } catch {
            Write-Host "pipx upgrade-all failed: $_" -ForegroundColor Yellow
        }
    }

    return $true
}
