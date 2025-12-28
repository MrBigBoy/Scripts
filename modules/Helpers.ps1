function Invoke-WithRetry {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][ScriptBlock]$Script,
        [int]$Retries = 2,
        [int]$DelaySeconds = 2
    )

    for ($i = 0; $i -le $Retries; $i++) {
        try {
            return & $Script
        } catch {
            if ($i -lt $Retries) { Start-Sleep -Seconds $DelaySeconds } else { throw }
        }
    }
}

function Write-LogJsonLine {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)][PSObject]$Object,
        [Parameter(Mandatory=$true)][string]$LogFile
    )

    try {
        $json = $Object | ConvertTo-Json -Depth 5 -Compress
        $json | Out-File -FilePath $LogFile -Encoding UTF8 -Append
    } catch {
        Write-Host "Failed to write log: $_" -ForegroundColor Yellow
    }
}

# Note: Helper functions are intended to be dot-sourced
