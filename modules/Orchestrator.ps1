function Get-ModuleStatus {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        $Result
    )
    
    if ($Result -and $Result.Success) {
        return @{
            Text = Get-LocalizedString -Key 'Success'
            Color = 'Green'
        }
    }
    
    $msg = if ($Result -and $Result.Message) { $Result.Message } else { '' }
    $out = if ($Result -and $Result.Output) { $Result.Output } else { '' }
    
    $notInstalledPattern = '(?i)(not installed|not found|no supported updater|no updater|not present|no wsl distros|no wsl distros found|not managed|installed but not managed)'
    
    if ($msg -match $notInstalledPattern -or $out -match '(?i)(No installed package found|not found)') {
        return @{
            Text = Get-LocalizedString -Key 'NotInstalled'
            Color = 'Yellow'
        }
    }
    
    return @{
        Text = Get-LocalizedString -Key 'Failed'
        Color = 'Red'
    }
}

function Invoke-UpdateModule {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [hashtable]$Module,
        
        [Parameter(Mandatory=$true)]
        [string]$ModuleDir,
        
        [switch]$WhatIf,
        [string]$LogFile
    )
    
    # Skip logic: do not load or run if Skip is true (bool or string)
    if ($Module.ContainsKey('Skip')) {
        $skipVal = ($Module['Skip'] -as [string]).Trim().ToLowerInvariant()
        if ($skipVal -eq 'true' -or $skipVal -eq '1' -or $Module['Skip'] -eq $true) {
            Write-Host (Get-LocalizedString -Key 'ModuleSkipped' -FormatArgs $Module['Name']) -ForegroundColor Yellow
            return $null
        }
    }

    $path = Join-Path $ModuleDir $Module.File

    if (-not (Test-Path $path)) {
        Write-Host (Get-LocalizedString -Key 'ModuleFileNotFound' -FormatArgs @($Module.Name, $path)) -ForegroundColor Yellow
        return $null
    }

    Write-Host (Get-LocalizedString -Key 'Checking' -FormatArgs $Module.Name)
    . $path

    if (-not (Get-Command $Module.Function -ErrorAction SilentlyContinue)) {
        Write-Host (Get-LocalizedString -Key 'FunctionNotFound' -FormatArgs @($Module.Name, $Module.File)) -ForegroundColor Yellow
        return $null
    }
    
    try {
        $result = & $Module.Function -WhatIf:$WhatIf -LogFile $LogFile
        $status = Get-ModuleStatus -Result $result
        Write-Host (Get-LocalizedString -Key 'Checked' -FormatArgs @($Module.Name, $status.Text)) -ForegroundColor $status.Color
        return $result
    }
    catch {
        $errObj = [PSCustomObject]@{ 
            Module = $Module.Name
            Success = $false
            Message = (Get-LocalizedString -Key 'InvocationFailed')
            Errors = @($_.Exception.Message)
            Duration = 0
        }
        Write-Host (Get-LocalizedString -Key 'Checked' -FormatArgs @($Module.Name, (Get-LocalizedString -Key 'InvocationFailed'))) -ForegroundColor Red
        return $errObj
    }
}
