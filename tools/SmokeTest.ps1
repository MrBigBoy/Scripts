<#
.SYNOPSIS
Runs all updater modules in -WhatIf mode to verify signatures and loading.
#>
param(
    [string]$ModuleDir = (Join-Path $PSScriptRoot '..\modules'),
    [string]$LogFile = (Join-Path $env:TEMP 'smoketest-updates.jsonl')
)

$moduleFiles = Get-ChildItem -Path $ModuleDir -Filter 'Update-*.ps1' -File -ErrorAction SilentlyContinue | Select-Object -ExpandProperty Name
$results = @()
foreach ($f in $moduleFiles) {
    $path = Join-Path $ModuleDir $f
    . $path
    $func = 'Invoke-' + ($f -replace '\.ps1$','') -replace 'Update-','Update-'
    if (Get-Command $func -ErrorAction SilentlyContinue) {
        try {
            $res = & $func -WhatIf -LogFile $LogFile
            $results += $res
        } catch {
            $results += [PSCustomObject]@{ Module = $f; Success = $false; Message = 'Smoke invocation failed'; Errors = @($_.Exception.Message) }
        }
    } else {
        $results += [PSCustomObject]@{ Module = $f; Success = $false; Message = "Function $func not found"; Errors = @() }
    }
}

Write-Host (Get-LocalizedString -Key 'SmokeTestResults'); $results | Format-Table -AutoSize

if (Get-Command Write-LogJsonLine -ErrorAction SilentlyContinue) { Write-LogJsonLine -Object ([PSCustomObject]@{ Timestamp = (Get-Date).ToString('o'); Results = $results }) -LogFile $LogFile }

