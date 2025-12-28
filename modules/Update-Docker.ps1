<#
.SYNOPSIS
Refreshes and pulls Docker images present on the host and prunes unused data.

.DESCRIPTION
`Invoke-UpdateDocker` checks Docker daemon status, attempts to `docker pull` for existing images and prunes unused resources.

.PARAMETER WhatIf
If specified, the function will not perform changes.

.PARAMETER LogFile
Optional JSONL log file path to append structured results.

.EXAMPLE
Invoke-UpdateDocker -WhatIf -LogFile C:\Temp\updates.jsonl
#>
function Invoke-UpdateDocker {
    [CmdletBinding()]
    param(
        [switch]$WhatIf,
        [string]$LogFile
    )

    $start = Get-Date
    $result = [PSCustomObject]@{
        Module = 'Docker'
        Success = $false
        Message = ''
        Duration = 0
        Errors = @()
    }

    if ($WhatIf) {
        $result.Message = 'WhatIf: Skipping Docker updates'
        $result.Success = $true
    } else {
        try {
            if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
                $result.Message = 'Docker not installed'
                $result.Success = $false
            } else {
                docker info > $null 2>&1
                if ($LASTEXITCODE -ne 0) {
                    $result.Message = 'Docker present but not running'
                    $result.Success = $false
                } else {
                    $images = docker images --format "{{.Repository}}:{{.Tag}}" | Where-Object { $_ -and ($_ -notmatch '<none>') }
                    foreach ($img in $images) {
                        try { docker pull $img 2>$null } catch { $result.Errors += $_.Exception.Message }
                    }
                    try { docker system prune -af 2>$null } catch { $result.Errors += $_.Exception.Message }

                    $result.Success = ($result.Errors.Count -eq 0)
                    $result.Message = 'Docker updates attempted'
                }
            }
        } catch {
            $result.Errors += $_.Exception.Message
            $result.Success = $false
            $result.Message = 'Docker update failed'
        }
    }

    $result.Duration = (Get-Date) - $start
    if ($LogFile -and (Get-Command Write-LogJsonLine -ErrorAction SilentlyContinue)) { Write-LogJsonLine -Object $result -LogFile $LogFile }
    return $result
}