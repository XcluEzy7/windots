# w11dot-setup.ps1 - Wrapper script for Setup.ps1
# This script allows calling Setup.ps1 with the w11dot-setup command from anywhere
# Since Setup.ps1 is in PATH, this script should also be in the same directory

param(
    [switch]$Force,
    [switch]$Packages,
    [switch]$PowerShell,
    [switch]$Git,
    [switch]$Symlinks,
    [switch]$Environment,
    [switch]$Addons,
    [switch]$VSCode,
    [switch]$Themes,
    [switch]$Miscellaneous,
    [switch]$Komorebi,
    [switch]$NerdFonts,
    [switch]$WSL
)

# Find Setup.ps1 using multiple methods
$setupScript = $null

# Method 1: Use DOTFILES environment variable
if ($Env:DOTFILES -and (Test-Path "$Env:DOTFILES\Setup.ps1")) {
    $setupScript = "$Env:DOTFILES\Setup.ps1"
} 
# Method 2: Use User environment variable
elseif ([System.Environment]::GetEnvironmentVariable("DOTFILES", "User") -and (Test-Path "$([System.Environment]::GetEnvironmentVariable('DOTFILES', 'User'))\Setup.ps1")) {
    $setupScript = "$([System.Environment]::GetEnvironmentVariable('DOTFILES', 'User'))\Setup.ps1"
}
# Method 3: Find in PATH
elseif (Get-Command Setup.ps1 -ErrorAction SilentlyContinue) {
    $setupScript = (Get-Command Setup.ps1).Source
}
# Method 4: Use same directory as this script
elseif ($PSScriptRoot -and (Test-Path "$PSScriptRoot\Setup.ps1")) {
    $setupScript = "$PSScriptRoot\Setup.ps1"
}
# Method 5: Search common locations
else {
    $commonPaths = @(
        "$env:USERPROFILE\.dotfiles",
        "$env:USERPROFILE\dotfiles",
        "$env:USERPROFILE\Documents\dotfiles",
        "$env:USERPROFILE\Projects\windots"
    )
    foreach ($path in $commonPaths) {
        if (Test-Path "$path\Setup.ps1") {
            $setupScript = "$path\Setup.ps1"
            break
        }
    }
}

if ($setupScript -and (Test-Path $setupScript)) {
    & $setupScript @PSBoundParameters
} else {
    Write-Error "Setup.ps1 not found. Please ensure DOTFILES environment variable is set correctly or Setup.ps1 is in PATH."
    exit 1
}

