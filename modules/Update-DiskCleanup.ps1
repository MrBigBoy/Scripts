<#
.SYNOPSIS
Runs full disk cleanup via Disk Cleanup utility.

.DESCRIPTION
`Invoke-UpdateDiskCleanup` runs the Windows Disk Cleanup tool to remove temporary files, cache, and other unnecessary data.

.PARAMETER WhatIf
If specified, the function will not perform changes.

.PARAMETER LogFile
Optional JSONL log file path to append structured results.

.EXAMPLE
Invoke-UpdateDiskCleanup -WhatIf -LogFile C:\Temp\updates.jsonl
#>
function Invoke-UpdateDiskCleanup {
    [CmdletBinding()]
    param(
        [switch]$WhatIf,
        [string]$LogFile
    )

    $start = Get-Date
    $result = [PSCustomObject]@{
        Module = 'DiskCleanup'
        Success = $false
        Message = ''
        Duration = 0
        Errors = @()
    }

    if ($WhatIf) {
        $result.Message = (Get-LocalizedString -Key 'WhatIfDiskCleanup')
        $result.Success = $true
    } else {
        try {
            Write-Host (Get-LocalizedString -Key 'RunningDiskCleanup')

            # Measure free space before cleanup
            $driveBefore = Get-PSDrive -Name C
            $freeSpaceBefore = $driveBefore.Free

            # Run cleanmgr with /verylowdisk (GUI may briefly appear, but it's safer than manual file deletion)
            Start-Process -FilePath "cleanmgr.exe" -ArgumentList "/verylowdisk" -Wait

            # Measure free space after cleanup
            $driveAfter = Get-PSDrive -Name C
            $freeSpaceAfter = $driveAfter.Free
            $spaceFreed = $freeSpaceAfter - $freeSpaceBefore
            $spaceFreedMB = [math]::Round($spaceFreed / 1MB, 2)

            $result.Message = (Get-LocalizedString -Key 'DiskCleanupCompleted' -FormatArgs $spaceFreedMB)
            $result.Success = $true
        } catch {
            $result.Errors += $_.Exception.Message
            $result.Message = (Get-LocalizedString -Key 'DiskCleanupFailed' -FormatArgs $_.Exception.Message)
        }
    }

    $result.Duration = ((Get-Date) - $start).TotalSeconds

    if ($LogFile) {
        Write-LogJsonLine -Object $result -LogFile $LogFile
    }

    return $result
}
