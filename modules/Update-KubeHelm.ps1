<#
.SYNOPSIS
Updates kubectl and helm CLIs and optionally runs helm repo updates.

.DESCRIPTION
`Invoke-UpdateKubeHelm` checks for `kubectl` and `helm` on PATH and, if present, attempts to update them using platform-specific methods where available. For helm, it runs `helm repo update`.

.PARAMETER WhatIf
If specified, the function will not perform changes.

.PARAMETER LogFile
Optional JSONL log file path to append structured results.

.EXAMPLE
Invoke-UpdateKubeHelm -WhatIf -LogFile C:\Temp\updates.jsonl
#>
function Invoke-UpdateKubeHelm {
    [CmdletBinding()]
    param(
        [switch]$WhatIf,
        [string]$LogFile
    )

    $start = Get-Date
    $result = [PSCustomObject]@{
        Module = 'KubeHelm'
        Success = $false
        Message = ''
        Duration = 0
        Errors = @()
        Details = @()
    }

    if ($WhatIf) {
        $result.Message = 'WhatIf: Skipping kubectl/helm updates'
        $result.Success = $true
    } else {
        try {
            if (Get-Command kubectl -ErrorAction SilentlyContinue) {
                # Best-effort: try to update kubectl via choco/winget if available
                if (Get-Command choco -ErrorAction SilentlyContinue) { choco upgrade kubernetes-cli -y 2>$null }
                elseif (Get-Command winget -ErrorAction SilentlyContinue) { winget upgrade --id Kubernetes.Kubectl --accept-package-agreements --accept-source-agreements --scope machine 2>$null }
                $result.Details += 'kubectl update attempted via choco/winget'
            } else {
                $result.Details += 'kubectl not found'
            }

            if (Get-Command helm -ErrorAction SilentlyContinue) {
                # Attempt helm repo update
                helm repo update 2>$null
                $result.Details += 'helm repo update attempted'
            } else {
                $result.Details += 'helm not found'
            }

            $result.Success = $true
            $result.Message = 'kubectl/helm update attempted (best-effort)'
        } catch {
            $result.Errors += $_.Exception.Message
            $result.Message = 'kubectl/helm update failed'
            $result.Success = $false
        }
    }

    $result.Duration = (Get-Date) - $start
    if ($LogFile -and (Get-Command Write-LogJsonLine -ErrorAction SilentlyContinue)) { Write-LogJsonLine -Object $result -LogFile $LogFile }
    return $result
}
