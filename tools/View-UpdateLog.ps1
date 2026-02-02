<#
.SYNOPSIS
Displays the update log file contents
#>

$LogDir = "$env:LOCALAPPDATA\SystemUpdater"

# Get the most recent log file
$LogFile = Get-ChildItem -Path $LogDir -Filter "update-log_*.jsonl" -ErrorAction SilentlyContinue | Sort-Object -Property LastWriteTime -Descending | Select-Object -First 1

if ($LogFile) {
    Write-Host "=== System Update Log ===" -ForegroundColor Cyan
    Write-Host "File: $($LogFile.FullName)" -ForegroundColor Gray
    Write-Host ""
    Get-Content $LogFile.FullName | ConvertFrom-Json | Format-List
} else {
    Write-Host "No log files found in: $LogDir" -ForegroundColor Red
}

Write-Host "Press Enter to close..." -ForegroundColor Gray
$null = Read-Host