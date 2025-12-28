function Invoke-UpdateDocker {
    [CmdletBinding()]
    param()

    try {
        if (-not (Get-Command docker -ErrorAction SilentlyContinue)) {
            Write-Host "Docker not installed, skipping."
            return $false
        }

        Write-Host 'Checking Docker status...'
        docker info > $null 2>&1
        if ($LASTEXITCODE -ne 0) {
            Write-Host 'Docker present but not running or accessible — skipping Docker updates.'
            return $false
        }

        Write-Host 'Updating Docker images present on the system...'
        $images = docker images --format "{{.Repository}}:{{.Tag}}" | Where-Object { $_ -and ($_ -notmatch '<none>') }
        foreach ($img in $images) {
            try {
                Write-Host "Pulling image: $img"
                docker pull $img 2>$null
            } catch {
                Write-Host ('Failed to pull {0}: {1}' -f $img, $_) -ForegroundColor Yellow
            }
        }

        Write-Host 'Pruning unused Docker data...'
        docker system prune -af 2>$null
        return $true
    } catch {
        Write-Host ('Docker update failed: {0}' -f $_) -ForegroundColor Yellow
        return $false
    }
}