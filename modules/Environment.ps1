function Initialize-Environment {
    [CmdletBinding()]
    param(
        [string]$LogFile
    )
    
    # Ensure log directory exists
    $logDir = Split-Path -Parent $LogFile
    if (-not (Test-Path $logDir)) { 
        New-Item -Path $logDir -ItemType Directory -Force | Out-Null 
    }
    
    # Non-interactive / CI-safe mode
    $script:ProgressPreference = 'SilentlyContinue'
    $script:ErrorActionPreference = 'Continue'
    
    # Exit code handling
    $global:ExitCode = 0
    trap {
        Write-Host "Error: $_" -ForegroundColor Red
        $global:ExitCode = 1
    }
}

function Register-UpdateTask {
    [CmdletBinding()]
    param(
        [string]$TaskName = 'Update System (Choco + Winget + Windows Update)',
        [string]$ScriptPath = 'C:\Scripts\Update-All.ps1',
        [string]$Time = '01:00AM'
    )
    
    if (Get-ScheduledTask -TaskName $TaskName -ErrorAction SilentlyContinue) {
        Unregister-ScheduledTask -TaskName $TaskName -Confirm:$false
    }
    
    $Argument = "-NoProfile -ExecutionPolicy Bypass -WindowStyle Hidden -File `"$ScriptPath`""
    $Action = New-ScheduledTaskAction -Execute 'powershell.exe' -Argument $Argument
    $Trigger = New-ScheduledTaskTrigger -Daily -At $Time
    $Principal = New-ScheduledTaskPrincipal -UserId 'SYSTEM' -LogonType ServiceAccount -RunLevel Highest
    $Settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable -WakeToRun -Hidden -ExecutionTimeLimit (New-TimeSpan -Hours 4)
    
    Register-ScheduledTask -TaskName $TaskName -Action $Action -Trigger $Trigger -Principal $Principal -Settings $Settings -Force | Out-Null
    
    Write-Host (Get-LocalizedString -Key 'ScheduledTaskCreated' -FormatArgs $TaskName) -ForegroundColor Green
}

function Invoke-FailedModulesHelper {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        $Results,
        
        [Parameter(Mandatory=$true)]
        [string]$ModuleDir,
        
        [string]$LogFile
    )
    
    $psModuleResult = $Results | Where-Object { $_.Module -eq 'PowerShellModules' }
    if (-not $psModuleResult) { return }
    
    $failed = @()
    if ($psModuleResult.FailedModules) { $failed = $psModuleResult.FailedModules }
    if ($failed.Count -eq 0) { return }
    
    try {
        $payload = [PSCustomObject]@{
            ParentPid = $PID
            LogFile = $LogFile
            Modules = $failed
        }
        $tmp = Join-Path $env:TEMP ("update_modules_payload_{0}.json" -f ([guid]::NewGuid().ToString()))
        $payload | ConvertTo-Json -Depth 5 | Out-File -FilePath $tmp -Encoding UTF8
        
        $helper = Join-Path $ModuleDir 'Update-Modules-Helper.ps1'
        if (Test-Path $helper) {
            Write-Host (Get-LocalizedString -Key 'LaunchingHelper' -FormatArgs $helper)
            Start-Process -FilePath powershell -ArgumentList @('-NoProfile','-ExecutionPolicy','Bypass','-File',$helper,$tmp) -Verb RunAs
        } else {
            Write-Host (Get-LocalizedString -Key 'HelperNotFound' -FormatArgs $helper) -ForegroundColor Yellow
        }
    } catch {
        Write-Host (Get-LocalizedString -Key 'FailedToLaunchHelper' -FormatArgs $_) -ForegroundColor Yellow
    }
}

Export-ModuleMember -Function Initialize-Environment, Register-UpdateTask, Invoke-FailedModulesHelper
