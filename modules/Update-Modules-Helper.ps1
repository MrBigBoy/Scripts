param(
    [Parameter(Mandatory=$true)][string]$PayloadPath
)

# Payload expected as JSON with fields: ParentPid, LogFile, Modules (array of module names)
try {
    $payload = Get-Content -Path $PayloadPath -Raw | ConvertFrom-Json
} catch {
    Write-Host "Failed to read payload: $_" -ForegroundColor Red
    exit 2
}

$parentPid = $payload.ParentPid
$logFile = $payload.LogFile
$modules = $payload.Modules

# Wait for parent to exit (with timeout)
$timeout = 60
$waited = 0
while ($waited -lt $timeout) {
    if (-not (Get-Process -Id $parentPid -ErrorAction SilentlyContinue)) { break }
    Start-Sleep -Seconds 1
    $waited++
}

$results = @()
foreach ($m in $modules) {
    $res = [PSCustomObject]@{ Module = $m; Success = $false; Message = ''; Errors = @() }
    try {
        Write-Host "Updating module: $m"
        Start-Process -FilePath powershell.exe -ArgumentList @('-NoProfile','-ExecutionPolicy','Bypass','-Command',"Update-Module -Name '$m' -Force") -Wait -NoNewWindow
        if ($LASTEXITCODE -eq 0) { $res.Success = $true; $res.Message = 'Updated' } else { $res.Message = 'Update-Module returned non-zero' }
    } catch {
        $res.Errors += $_.Exception.Message
        $res.Message = 'Failed'
    }
    $results += $res
}

# Log results
if ($logFile -and (Get-Command Write-LogJsonLine -ErrorAction SilentlyContinue)) {
    $obj = [PSCustomObject]@{ Timestamp = (Get-Date).ToString('o'); HelperResults = $results }
    Write-LogJsonLine -Object $obj -LogFile $logFile
}

Write-Host "Module helper finished"
exit 0
