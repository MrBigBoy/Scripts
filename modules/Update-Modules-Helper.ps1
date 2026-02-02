param(
    [Parameter(Mandatory=$true)][string]$PayloadPath
)

# Payload expected as JSON with fields: ParentPid, LogFile, Modules (array of module names)
try {
    $payload = Get-Content -Path $PayloadPath -Raw | ConvertFrom-Json
} catch {
    $msg = Get-LocalizedString -Key 'FailedToReadPayload' -FormatArgs $_
    Write-Host $msg -ForegroundColor Red
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
        $msg = Get-LocalizedString -Key 'UpdatingModule' -FormatArgs $m
        Write-Host $msg
        Start-Process -FilePath powershell.exe -ArgumentList @('-NoProfile','-ExecutionPolicy','Bypass','-Command',"Update-Module -Name '$m' -Force") -Wait -NoNewWindow
        if ($LASTEXITCODE -eq 0) { $res.Success = $true; $res.Message = (Get-LocalizedString -Key 'ModuleUpdated') } else { $res.Message = (Get-LocalizedString -Key 'UpdateModuleNonZero') }
    } catch {
        $res.Errors += $_.Exception.Message
        $res.Message = (Get-LocalizedString -Key 'ModuleUpdateFailed')
    }
    $results += $res
}

# Log results
if ($logFile -and (Get-Command Write-LogJsonLine -ErrorAction SilentlyContinue)) {
    $obj = [PSCustomObject]@{ Timestamp = (Get-Date).ToString('o'); HelperResults = $results }
    Write-LogJsonLine -Object $obj -LogFile $logFile
}

Write-Host (Get-LocalizedString -Key 'ModuleHelperFinished')
exit 0
