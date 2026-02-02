param(
    [string]$ResultsFile
)

try {
    if (-not $ResultsFile -or -not (Test-Path $ResultsFile)) {
        Write-Host "No results file found." -ForegroundColor Yellow
        Write-Host "Press Enter to close..." -ForegroundColor Gray
        $null = Read-Host
        exit
    }

    # Load localization if available
    $ModuleDir = Join-Path (Split-Path (Split-Path $PSScriptRoot -Parent) -Parent) 'modules'
    $localizationPath = Join-Path $ModuleDir 'Localization.ps1'
    if (Test-Path $localizationPath) { . $localizationPath }

    Clear-Host

    # Read results
    $results = Get-Content $ResultsFile -Raw | ConvertFrom-Json

    # Display header
    $title = if (Get-Command Get-LocalizedString -ErrorAction SilentlyContinue) {
        Get-LocalizedString -Key 'ModuleExecutionResults'
    } else {
        'Module execution results:'
    }

    Write-Host ""
    Write-Host "═══════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host "  $title" -ForegroundColor White
    Write-Host "═══════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host ""

    # Display results in a formatted way
    foreach ($result in $results) {
        $color = 'Yellow'
        $status = '?'
        
        if ($result.Success) {
            $color = 'Green'
            $status = '✓'
        } elseif ($result.Message -match '(?i)(not installed|not found)') {
            $color = 'Yellow'
            $status = '○'
        } else {
            $color = 'Red'
            $status = '✗'
        }
        
        Write-Host " $status " -ForegroundColor $color -NoNewline
        Write-Host ("{0,-25}" -f $result.Module) -NoNewline
        
        if ($result.Duration) {
            Write-Host (" [{0:F2}s]" -f $result.Duration) -ForegroundColor Gray -NoNewline
        }
        
        Write-Host ""
        
        if ($result.Message -and -not $result.Success) {
            Write-Host "    └─ $($result.Message)" -ForegroundColor DarkGray
        }
    }

    Write-Host ""
    Write-Host "═══════════════════════════════════════════════════════" -ForegroundColor Cyan
    Write-Host ""
    Write-Host "Press Enter to close..." -ForegroundColor Gray
    $null = Read-Host
} catch {
    Write-Host "\n[FEJL] $($_.Exception.Message)" -ForegroundColor Red
    if ($_.ScriptStackTrace) {
        Write-Host "\n$($_.ScriptStackTrace)" -ForegroundColor DarkGray
    }
    Write-Host "\nPress Enter to close..." -ForegroundColor Gray
    $null = Read-Host
}
