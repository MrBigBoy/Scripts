<#
.SYNOPSIS
Updates npm and yarn global packages.

.DESCRIPTION
`Invoke-UpdateNpm` updates npm itself and global packages via `npm update -g` and `yarn global upgrade` when yarn is present.

.PARAMETER WhatIf
If specified, the function will not perform changes.

.PARAMETER LogFile
Optional JSONL log file path to append structured results.

.EXAMPLE
Invoke-UpdateNpm -WhatIf -LogFile C:\Temp\updates.jsonl
#>
function Invoke-UpdateNpm {
    [CmdletBinding()]
    param(
        [switch]$WhatIf,
        [string]$LogFile
    )

    $start = Get-Date
    $result = [PSCustomObject]@{
        Module = 'Npm'
        Success = $false
        Message = ''
        Duration = 0
        Errors = @()
    }

    if ($WhatIf) {
        $result.Message = 'WhatIf: Skipping npm/yarn updates'
        $result.Success = $true
    } else {
        try {
            if (Get-Command npm -ErrorAction SilentlyContinue) {
                npm install -g npm
                npm update -g
                npm cache clean --force
                $result.Message = 'npm updated'
                $result.Success = $true
            }
            if (Get-Command yarn -ErrorAction SilentlyContinue) {
                yarn global upgrade
                $result.Message = ($result.Message + '; yarn updated')
                $result.Success = $true
            }
            if (-not (Get-Command npm -ErrorAction SilentlyContinue) -and -not (Get-Command yarn -ErrorAction SilentlyContinue)) {
                $result.Message = 'Neither npm nor yarn found'
            }
        } catch {
            $result.Errors += $_.Exception.Message
            $result.Message = 'npm/yarn update failed'
            $result.Success = $false
        }
    }

    $result.Duration = (Get-Date) - $start
    if ($LogFile -and (Get-Command Write-LogJsonLine -ErrorAction SilentlyContinue)) { Write-LogJsonLine -Object $result -LogFile $LogFile }
    return $result
}
