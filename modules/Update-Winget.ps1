<#
.SYNOPSIS
Updates packages via winget (runs a silent `winget upgrade --all`).

.DESCRIPTION
`Invoke-UpdateWinget` ensures winget is present and runs a best-effort silent upgrade for all packages.

.PARAMETER WhatIf
If specified, the function will not perform changes.

.PARAMETER LogFile
Optional JSONL log file path to append structured results.

.EXAMPLE
Invoke-UpdateWinget -WhatIf -LogFile C:\Temp\updates.jsonl
#>
function Invoke-UpdateWinget {
    [CmdletBinding()]
    param(
        [switch]$WhatIf,
        [string]$LogFile
    )

    $start = Get-Date
    $result = [PSCustomObject]@{
        Module = 'Winget'
        Success = $false
        Message = ''
        Duration = 0
        Errors = @()
        Output = ''
    }

    if ($WhatIf) {
        $result.Message = 'WhatIf: Skipping Winget updates (would run: winget upgrade --all --accept-source-agreements --accept-package-agreements --silent)'
        $result.Success = $true
        $result.Duration = (Get-Date) - $start
        if ($LogFile -and (Get-Command Write-LogJsonLine -ErrorAction SilentlyContinue)) { Write-LogJsonLine -Object $result -LogFile $LogFile }
        return $result
    }

    try {
        if (-not (Get-Command winget -ErrorAction SilentlyContinue)) {
            $result.Message = 'Winget not installed'
            $result.Success = $false
        } else {
            # Run winget upgrade --all silently and capture output
            $args = @('upgrade','--all','--accept-source-agreements','--accept-package-agreements','--silent')
            $outFile = Join-Path $env:TEMP ("winget_up_all_out_{0}.txt" -f ([guid]::NewGuid().ToString()))
            $errFile = Join-Path $env:TEMP ("winget_up_all_err_{0}.txt" -f ([guid]::NewGuid().ToString()))

            $proc = Start-Process -FilePath (Get-Command winget).Source -ArgumentList $args -NoNewWindow -Wait -PassThru -RedirectStandardOutput $outFile -RedirectStandardError $errFile

            $outText = ''
            if (Test-Path $outFile) { $outText += (Get-Content $outFile -Raw) }
            if (Test-Path $errFile) { $outText += "`nERR:`n" + (Get-Content $errFile -Raw) }
            $result.Output = $outText

            $ec = $proc.ExitCode
            if ($ec -eq 0) {
                $result.Success = $true
                $result.Message = 'Winget upgrade --all completed'
            } else {
                # Treat cases where no upgrades were available as success
                if ($result.Output -match '(?i)No applicable upgrades|No installed package found|No packages found|0 upgraded') {
                    $result.Success = $true
                    $result.Message = 'Winget reported no applicable upgrades'
                } else {
                    $result.Success = $false
                    $result.Message = "Winget upgrade failed (exit code $ec)"
                }
            }

            if (Test-Path $outFile) { Remove-Item $outFile -ErrorAction SilentlyContinue }
            if (Test-Path $errFile) { Remove-Item $errFile -ErrorAction SilentlyContinue }
        }
    } catch {
        $result.Errors += $_.Exception.Message
        $result.Message = 'Winget upgrade encountered an error'
        $result.Success = $false
    }

    $result.Duration = (Get-Date) - $start
    if ($LogFile -and (Get-Command Write-LogJsonLine -ErrorAction SilentlyContinue)) { Write-LogJsonLine -Object $result -LogFile $LogFile }
    return $result
}