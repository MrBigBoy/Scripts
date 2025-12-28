<#
.SYNOPSIS
Updates Azure CLI and AWS CLI if present.

.DESCRIPTION
`Invoke-UpdateCloudCLI` attempts to update `az` and `aws` CLIs using platform-appropriate methods. For az it uses `az upgrade` when available, for aws it attempts `pip install --upgrade awscli` or `choco upgrade awscli`.

.PARAMETER WhatIf
If specified, the function will not perform changes.

.PARAMETER LogFile
Optional JSONL log file path to append structured results.

.EXAMPLE
Invoke-UpdateCloudCLI -WhatIf -LogFile C:\Temp\updates.jsonl
#>
function Invoke-UpdateCloudCLI {
    [CmdletBinding()]
    param(
        [switch]$WhatIf,
        [string]$LogFile
    )

    $start = Get-Date
    $result = [PSCustomObject]@{
        Module = 'CloudCLI'
        Success = $false
        Message = ''
        Duration = 0
        Errors = @()
        Details = @()
    }

    if ($WhatIf) {
        $result.Message = 'WhatIf: Skipping Cloud CLI updates'
        $result.Success = $true
    } else {
        try {
            # Azure CLI
            if (Get-Command az -ErrorAction SilentlyContinue) {
                try {
                    # az upgrade exists in newer versions
                    az upgrade --yes 2>$null
                    $result.Details += 'az upgrade attempted'
                } catch {
                    # fallback to package manager if available
                    if (Get-Command choco -ErrorAction SilentlyContinue) { choco upgrade azure-cli -y 2>$null; $result.Details += 'az updated via choco' }
                    elseif (Get-Command winget -ErrorAction SilentlyContinue) { winget upgrade --id Microsoft.AzureCLI --accept-package-agreements --accept-source-agreements --scope machine 2>$null; $result.Details += 'az updated via winget' }
                }
            } else { $result.Details += 'az not found' }

            # AWS CLI
            if (Get-Command aws -ErrorAction SilentlyContinue) {
                try {
                    # try pip upgrade
                    if (Get-Command pip -ErrorAction SilentlyContinue) { pip install --upgrade awscli 2>$null; $result.Details += 'awscli updated via pip' }
                    elseif (Get-Command choco -ErrorAction SilentlyContinue) { choco upgrade awscli -y 2>$null; $result.Details += 'awscli updated via choco' }
                    else { $result.Details += 'awscli present but no known updater found' }
                } catch {
                    $result.Errors += $_.Exception.Message
                }
            } else { $result.Details += 'aws not found' }

            $result.Success = $true
            $result.Message = 'Cloud CLI updates attempted (best-effort)'
        } catch {
            $result.Errors += $_.Exception.Message
            $result.Message = 'Cloud CLI updates failed'
            $result.Success = $false
        }
    }

    $result.Duration = (Get-Date) - $start
    if ($LogFile -and (Get-Command Write-LogJsonLine -ErrorAction SilentlyContinue)) { Write-LogJsonLine -Object $result -LogFile $LogFile }
    return $result
}
