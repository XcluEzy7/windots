# Quick script to check module availability across package managers
# Usage: .\Check-ModuleAvailability.ps1 -ModuleName "posh-git"

param(
    [Parameter(Mandatory=$true)]
    [string]$ModuleName
)

Write-Host "`n=== Checking availability for: $ModuleName ===" -ForegroundColor Cyan

# Check PowerShell Gallery (in PowerShell 5.1)
Write-Host "`n[PowerShell Gallery - PowerShell 5.1]" -ForegroundColor Blue
$psgCheckScript = @"
try {
	`$module = Find-Module -Name '$ModuleName' -ErrorAction Stop
	if (`$module) {
		Write-Output "FOUND:`$(`$module.Version)"
	} else {
		Write-Output 'NOT_FOUND'
	}
} catch {
	Write-Output 'NOT_FOUND'
}
"@

$psgResult = & powershell.exe -NoProfile -Command $psgCheckScript
if ($psgResult -match '^FOUND:') {
    $version = $psgResult -replace 'FOUND:', ''
    Write-Host "  ✓ Available" -ForegroundColor Green
    Write-Host "    Version: $version" -ForegroundColor Yellow
    Write-Host "    Install: Install-Module -Name $ModuleName (in PowerShell 5.1)" -ForegroundColor Gray
} else {
    Write-Host "  ✗ Not found" -ForegroundColor Red
}

# Check Scoop
Write-Host "`n[Scoop]" -ForegroundColor Blue
if (Get-Command scoop -ErrorAction SilentlyContinue) {
    $scoopResult = scoop search $ModuleName 2>&1
    if ($scoopResult -match $ModuleName) {
        Write-Host "  ✓ Available" -ForegroundColor Green
        Write-Host "    Install: scoop install $ModuleName" -ForegroundColor Gray
    } else {
        Write-Host "  ✗ Not found" -ForegroundColor Red
    }
} else {
    Write-Host "  ⚠ Scoop not installed" -ForegroundColor Yellow
}

# Check Chocolatey
Write-Host "`n[Chocolatey]" -ForegroundColor Blue
if (Get-Command choco -ErrorAction SilentlyContinue) {
    $chocoResult = choco search $ModuleName --exact 2>&1
    if ($chocoResult -match $ModuleName) {
        Write-Host "  ✓ Available" -ForegroundColor Green
        Write-Host "    Install: choco install $ModuleName" -ForegroundColor Gray
    } else {
        # Try with -psmodule suffix
        $chocoResult2 = choco search "$ModuleName-psmodule" --exact 2>&1
        if ($chocoResult2 -match "$ModuleName-psmodule") {
            Write-Host "  ✓ Available (as $ModuleName-psmodule)" -ForegroundColor Green
            Write-Host "    Install: choco install $ModuleName-psmodule" -ForegroundColor Gray
        } else {
            Write-Host "  ✗ Not found" -ForegroundColor Red
        }
    }
} else {
    Write-Host "  ⚠ Chocolatey not installed" -ForegroundColor Yellow
}

# Check if already installed (in PowerShell 5.1)
Write-Host "`n[Current Installation Status - PowerShell 5.1]" -ForegroundColor Blue
$installedCheckScript = @"
`$installed = Get-InstalledModule -Name '$ModuleName' -ErrorAction SilentlyContinue
if (`$installed) {
	Write-Output "INSTALLED:`$(`$installed.Version)|`$(`$installed.InstalledLocation)"
} else {
	Write-Output 'NOT_INSTALLED'
}
"@

$installedResult = & powershell.exe -NoProfile -Command $installedCheckScript
if ($installedResult -match '^INSTALLED:') {
    $info = $installedResult -replace 'INSTALLED:', ''
    $parts = $info -split '\|'
    Write-Host "  ✓ Installed: v$($parts[0])" -ForegroundColor Green
    Write-Host "    Location: $($parts[1])" -ForegroundColor Gray
} else {
    Write-Host "  ✗ Not installed" -ForegroundColor Red
}

Write-Host "`n"

