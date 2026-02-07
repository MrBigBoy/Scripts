<#
.SYNOPSIS
Re-encodes all files under the current folder to UTF-8 with BOM.
#>

$Root = (Get-Location).Path

$textExtensions = @(
    '.txt', '.md', '.markdown', '.log', '.csv', '.tsv', '.json', '.yml', '.yaml', '.xml', '.html', '.htm',
    '.css', '.scss', '.less', '.js', '.jsx', '.ts', '.tsx', '.mjs', '.cjs', '.ps1', '.psm1', '.psd1', '.ps1xml',
    '.bat', '.cmd', '.ini', '.cfg', '.conf', '.toml', '.sql', '.cs', '.vb', '.cpp', '.c', '.h', '.hpp', '.java',
    '.py', '.rb', '.go', '.rs', '.sh', '.dockerfile'
)

Write-Host "This will encode all files under: $Root" -ForegroundColor Yellow
$files = Get-ChildItem -Path $Root -Recurse -File -Force -ErrorAction SilentlyContinue | Where-Object {
    $dir = $_.DirectoryName
    if (-not $dir) { return $true }
    $hasDotFolder = ($dir -split '[\\/]' | Where-Object { $_ -like '.*' }).Count -gt 0
    -not $hasDotFolder
} | Where-Object {
    $name = $_.Name.ToLowerInvariant()
    if ($name -like '.*') { return $false }
    $ext = $_.Extension.ToLowerInvariant()
    $baseName = $_.BaseName.ToLowerInvariant()
    ($textExtensions -contains $ext)
}
Write-Host "Total: $($files.Count) file(s)" -ForegroundColor Gray
Write-Host "Press Enter to continue..." -ForegroundColor Gray
$null = Read-Host

foreach ($file in $files) {
    try {
        $content = [System.IO.File]::ReadAllText($file.FullName)
        [System.IO.File]::WriteAllText($file.FullName, $content, [System.Text.UTF8Encoding]::new($true))
        Write-Host "Encoded: $($file.FullName)" -ForegroundColor DarkGray
    } catch {
        Write-Host "Failed: $($file.FullName) - $($_.Exception.Message)" -ForegroundColor Red
    }
}

Write-Host "Done." -ForegroundColor Green
Write-Host "Press Enter to close..." -ForegroundColor Gray
$null = Read-Host
