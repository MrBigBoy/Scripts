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
            $performed = $false
            $haveKubectl = (Get-Command kubectl -ErrorAction SilentlyContinue) -ne $null
            $haveHelm = (Get-Command helm -ErrorAction SilentlyContinue) -ne $null

            if ($haveKubectl) {
                if (Get-Command choco -ErrorAction SilentlyContinue) {
                    & choco upgrade kubernetes-cli -y 2>$null
                    $result.Details += 'kubectl update attempted via choco'
                    $performed = $true
                } elseif (Get-Command winget -ErrorAction SilentlyContinue) {
                    & winget upgrade --id Kubernetes.Kubectl --accept-package-agreements --accept-source-agreements --scope machine 2>$null
                    $result.Details += 'kubectl update attempted via winget'
                    $performed = $true
                } else {
                    $result.Details += 'kubectl present but no package manager updater available'
                }
            } else {
                $result.Details += 'kubectl not found'
            }

            if ($haveHelm) {
                # Attempt helm repo update
                try {
                    helm repo update 2>$null
                    $result.Details += 'helm repo update attempted'
                    $performed = $true
                } catch {
                    $result.Details += 'helm present but repo update failed or not applicable'
                }
            } else {
                $result.Details += 'helm not found'
            }

            if ($performed) {
                $result.Success = $true
                $result.Message = 'kubectl/helm update attempted (best-effort)'
            } else {
                if ($haveKubectl -or $haveHelm) {
                    $result.Success = $false
                    $result.Message = 'kubectl/helm installed but not managed by package manager (skipping)'
                } else {
                    $result.Success = $false
                    $result.Message = 'kubectl and helm not found'
                }
            }
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
