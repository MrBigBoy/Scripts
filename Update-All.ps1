# ================================
# Script parameters
# ================================
param(
    [switch]$WhatIf,
    [string]$LogFile = (Join-Path $env:LOCALAPPDATA 'SystemUpdater\update-log.jsonl')
)

try {
    # ================================
    # Self-elevate to Administrator
    # ================================
    if (-not ([Security.Principal.WindowsPrincipal] `
        [Security.Principal.WindowsIdentity]::GetCurrent()
        ).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {

        # Prefer PowerShell 7 if available
        $pwsh7 = Get-Command pwsh.exe -ErrorAction SilentlyContinue
        $psExecutable = if ($pwsh7) { 'pwsh' } else { 'powershell' }
        
        $currentScript = $MyInvocation.MyCommand.Path
        Start-Process -FilePath $psExecutable -ArgumentList @('-NoProfile','-ExecutionPolicy','Bypass','-File',$currentScript) -Verb RunAs
        exit
    }

    if ($Host.UI -and $Host.UI.RawUI) { Clear-Host }

    # ================================
    # Load modules
    # ================================
    $ModuleDir = Join-Path $PSScriptRoot 'modules'
    @('Helpers', 'Notify', 'Localization', 'Orchestrator', 'Environment') | ForEach-Object {
        $path = Join-Path $ModuleDir "$_.ps1"
        if (Test-Path $path) { . $path }
    }

    # ================================
    # Initialize
    # ================================
    Initialize-Environment -LogFile $LogFile
    $ScriptStopwatch = [System.Diagnostics.Stopwatch]::StartNew()
    $ToastAvailable = Initialize-ToastNotifications
    Send-StartNotification -LogFile $LogFile
    Write-Host (Get-LocalizedString -Key 'RunningAsAdmin') -ForegroundColor Green

    # ================================
    # Orchestrator: load and execute modules
    # ================================
    $moduleRegistry = Import-PowerShellDataFile -Path (Join-Path $ModuleDir 'ModuleRegistry.psd1')
    $results = @()

    foreach ($module in $moduleRegistry.Modules) {
        if ($module.PSObject.Properties.Match('Skip').Count -gt 0 -and $module.Skip) {
            Write-Host (Get-LocalizedString -Key 'ModuleSkipped' -FormatArgs $module.Name) -ForegroundColor Yellow
            continue
        }
        $result = Invoke-UpdateModule -Module $module -ModuleDir $ModuleDir -WhatIf:$WhatIf -LogFile $LogFile
        if ($result) {
            if ($result -is [System.Collections.IEnumerable] -and -not ($result -is [string])) {
                $results += @($result)
            } else {
                $results += $result
            }
        }
    }

    $summary = [PSCustomObject]@{ Timestamp = (Get-Date).ToString('o'); Results = $results }
    if ($LogFile -and (Get-Command Write-LogJsonLine -ErrorAction SilentlyContinue)) { Write-LogJsonLine -Object $summary -LogFile $LogFile }
    Write-Host (Get-LocalizedString -Key 'ModuleExecutionResults')
    Write-Host (Get-LocalizedString -Key 'DebugResultCount' -FormatArgs $results.Count) -ForegroundColor Yellow
    $results | Format-Table -AutoSize
    Write-Host (Get-LocalizedString -Key 'DebugRawResults') -ForegroundColor Yellow
    $results | ConvertTo-Json -Depth 10 | Write-Host

    # ================================
    # Finalize
    # ================================
    Send-CompletionNotification -LogFile $LogFile
    Register-UpdateTask
    $ScriptStopwatch.Stop()
    Send-EndNotification -Duration ('{0:hh\:mm\:ss}' -f $ScriptStopwatch.Elapsed) -LogFile $LogFile -Results $results
    Invoke-FailedModulesHelper -Results $results -ModuleDir $ModuleDir -LogFile $LogFile

    Write-Host (Get-LocalizedString -Key 'ScriptFinishedDuration' -FormatArgs ('{0:hh\:mm\:ss}' -f $ScriptStopwatch.Elapsed)) -ForegroundColor Green
    $null = Read-Host
    exit $global:ExitCode
} catch {
    $errTitle = if (Get-Command Get-LocalizedString -ErrorAction SilentlyContinue) {
        Get-LocalizedString -Key 'ScriptErrorTitle'
    } else {
        '[FEJL]'
    }
    $errMsg = if (Get-Command Get-LocalizedString -ErrorAction SilentlyContinue) {
        Get-LocalizedString -Key 'ScriptErrorMessage' -FormatArgs $_.Exception.Message
    } else {
        $_.Exception.Message
    }
    Write-Host ("\n{0} {1}" -f $errTitle, $errMsg) -ForegroundColor Red
    if ($_.ScriptStackTrace) {
        Write-Host ("\n{0}" -f $_.ScriptStackTrace) -ForegroundColor DarkGray
    }
    $pressEnter = if (Get-Command Get-LocalizedString -ErrorAction SilentlyContinue) {
        Get-LocalizedString -Key 'PressEnterToClose'
    } else {
        'Scriptet afsluttes. Tryk Enter for at lukke...'
    }
    Write-Host ("\n{0}" -f $pressEnter) -ForegroundColor Gray
    $null = Read-Host
    exit 1
}