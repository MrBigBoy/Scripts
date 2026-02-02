# ================================
# Localization module
# ================================

$Script:Strings = @{}
$Script:LocalesPath = Join-Path $PSScriptRoot 'locales'

function Load-LanguageFile {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Language
    )
    
    $languageFile = Join-Path $Script:LocalesPath "$Language.psd1"
    
    if (Test-Path $languageFile) {
        try {
            $Script:Strings[$Language] = Import-PowerShellDataFile -Path $languageFile
            return $true
        }
        catch {
            Write-Warning "Failed to load language file for '$Language': $_"
            return $false
        }
    }
    
    return $false
}

# Pre-load English as fallback
Load-LanguageFile -Language 'en' | Out-Null

function Get-LocalizedString {
    [CmdletBinding()]
    param(
        [Parameter(Mandatory=$true)]
        [string]$Key,
        
        [Parameter(Mandatory=$false)]
        [object[]]$FormatArgs,
        
        [Parameter(Mandatory=$false)]
        [string]$Language
    )
    
    # Auto-detect language if not specified
    if (-not $Language) {
        $Language = Get-SystemLanguage
    }
    
    # Load language file if not already loaded
    if (-not $Script:Strings.ContainsKey($Language)) {
        $loaded = Load-LanguageFile -Language $Language
        if (-not $loaded) {
            $Language = 'en'
        }
    }
    
    $localizedString = $Script:Strings[$Language][$Key]
    
    # Fallback to English if key not found
    if (-not $localizedString -and $Language -ne 'en') {
        $localizedString = $Script:Strings['en'][$Key]
    }
    
    # Fallback to key itself if still not found
    if (-not $localizedString) {
        $localizedString = $Key
    }
    
    # Apply formatting if arguments provided
    if ($FormatArgs) {
        return ($localizedString -f $FormatArgs)
    }
    
    return $localizedString
}

function Get-SystemLanguage {
    [CmdletBinding()]
    param()
    
    try {
        $cultureName = [System.Globalization.CultureInfo]::CurrentUICulture.TwoLetterISOLanguageName
        
        # Support Danish and English, default to English
        if ($cultureName -eq 'da') {
            return 'da'
        }
        return 'en'
    }
    catch {
        return 'en'
    }
}

# Alias for convenience
New-Alias -Name 'L' -Value 'Get-LocalizedString' -Force -ErrorAction SilentlyContinue

Export-ModuleMember -Function Get-LocalizedString, Get-SystemLanguage -Alias L
