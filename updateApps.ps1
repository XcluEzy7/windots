#Requires -Version 7

<#
.SYNOPSIS
    Updates installed applications from appList.json using appropriate package managers.

.DESCRIPTION
    This script updates packages listed in appList.json using Winget, Chocolatey, or Scoop.
    - Scoop: Always runs in non-admin context (spawns non-admin process if running as admin)
    - Winget/Choco: Require admin context (auto-elevates if not admin)

.PARAMETER Scoop
    Update only Scoop packages. Alias: -scp

.PARAMETER Winget
    Update only Winget packages. Alias: -win

.PARAMETER Choco
    Update only Chocolatey packages. Alias: -cho

.PARAMETER All
    Update all packages from all managers. Alias: -a (default if no switch specified)

.EXAMPLE
    .\updateApps.ps1
    Updates all packages (default behavior).

.EXAMPLE
    .\updateApps.ps1 -Scoop
    Updates only Scoop packages.

.EXAMPLE
    .\updateApps.ps1 -win -cho
    Updates Winget and Chocolatey packages only.

.NOTES
    Author: eagarcia@techforexcellence.org
    Version: 2.0.0
#>

[CmdletBinding()]
Param(
    [Alias('scp')][switch]$Scoop,
    [Alias('win')][switch]$Winget,
    [Alias('cho')][switch]$Choco,
    [Alias('a')][switch]$All
)

$ErrorActionPreference = "Continue"

#region Configuration
$script:ScriptRoot = $PSScriptRoot
if (!$script:ScriptRoot) {
    $script:ScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
}

$script:LogDir = Join-Path $env:USERPROFILE "w11dot_logs\apps"
$script:Timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$script:SuccessLog = Join-Path $script:LogDir "appUpdate_$($script:Timestamp)_success.log"
$script:ErrorLog = Join-Path $script:LogDir "appUpdate_$($script:Timestamp)_error.log"

$script:Summary = @{
    Updated = @()
    Skipped = @()
    Failed  = @()
}
#endregion

#region Helper Functions

function Test-Administrator {
    $currentUser = [System.Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object System.Security.Principal.WindowsPrincipal($currentUser)
    return $principal.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Initialize-Logging {
    if (!(Test-Path $script:LogDir)) {
        New-Item -ItemType Directory -Path $script:LogDir -Force | Out-Null
    }

    $header = "========================================`nUpdate Started: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')`n========================================"
    $header | Out-File $script:SuccessLog -Encoding utf8
    $header | Out-File $script:ErrorLog -Encoding utf8
}

function Write-Log {
    param(
        [string]$Message,
        [ValidateSet('Success', 'Error')][string]$Type = 'Success'
    )

    $logFile = if ($Type -eq 'Success') { $script:SuccessLog } else { $script:ErrorLog }
    $Message | Out-File $logFile -Append -Encoding utf8
}

function Write-Status {
    param(
        [string]$Manager,
        [string]$Package,
        [ValidateSet('Updating', 'Success', 'UpToDate', 'Skipped', 'Failed', 'Error')][string]$Status,
        [string]$Details = ""
    )

    $colors = @{
        Updating = "Gray"
        Success  = "Green"
        UpToDate = "Green"
        Skipped  = "Yellow"
        Failed   = "Red"
        Error    = "Red"
    }

    $symbols = @{
        Updating = "..."
        Success  = "(success)"
        UpToDate = "(up to date)"
        Skipped  = "(skipped)"
        Failed   = "(failed)"
        Error    = "(error)"
    }

    $color = $colors[$Status]
    $symbol = $symbols[$Status]
    $detailStr = if ($Details) { " - $Details" } else { "" }

    Write-Host "[" -NoNewline
    Write-Host "update" -ForegroundColor Blue -NoNewline
    Write-Host "] " -NoNewline
    Write-Host "$Manager" -ForegroundColor Magenta -NoNewline
    Write-Host ": " -NoNewline
    Write-Host $symbol -ForegroundColor $color -NoNewline
    Write-Host " $Package" -ForegroundColor Gray -NoNewline
    Write-Host $detailStr -ForegroundColor DarkGray
}

function Get-AppList {
    $jsonPath = Join-Path $script:ScriptRoot "appList.json"
    if (!(Test-Path $jsonPath)) {
        Write-Host "Error: appList.json not found at: $jsonPath" -ForegroundColor Red
        exit 1
    }

    $jsonContent = Get-Content $jsonPath -Raw

    # Strip comments line by line for reliable parsing
    $lines = $jsonContent -split "`r?`n"
    $cleanLines = @()
    foreach ($line in $lines) {
        # Skip lines that are only comments (starting with //)
        if ($line -match '^\s*//') { continue }

        # For lines with actual JSON content, only strip trailing comments
        # that come AFTER the closing } or ] or " and are not part of a URL
        $cleanLine = $line

        # Find trailing comment that's outside of strings
        # Look for // that's preceded by }, ], ", or whitespace (not :)
        if ($line -match '^(.*[}\]",])\s*//.*$') {
            $cleanLine = $matches[1]
        }

        $cleanLines += $cleanLine
    }
    $jsonContent = $cleanLines -join "`n"

    try {
        return $jsonContent | ConvertFrom-Json
    }
    catch {
        Write-Host "Error parsing appList.json: $_" -ForegroundColor Red
        Write-Host "Debug: Check appList.json for invalid JSON syntax" -ForegroundColor Yellow
        exit 1
    }
}

#endregion

#region Package Manager Functions

function Test-WingetInstalled {
    param([string]$PackageId)

    if (!(Get-Command winget -ErrorAction SilentlyContinue)) { return $false }

    $result = winget list --exact --id $PackageId 2>&1 | Out-String
    return ($LASTEXITCODE -eq 0 -and $result -match [regex]::Escape($PackageId))
}

function Test-ChocoInstalled {
    param([string]$PackageName)

    if (!(Get-Command choco -ErrorAction SilentlyContinue)) { return $false }

    $chocoLibPath = "C:\ProgramData\chocolatey\lib\$PackageName"
    if (Test-Path $chocoLibPath) { return $true }

    $result = choco list $PackageName --local-only --limit-output 2>&1 | Out-String
    return ($LASTEXITCODE -eq 0 -and $result -match "^$([regex]::Escape($PackageName))\|")
}

function Test-ScoopInstalled {
    param([string]$PackageName)

    if (!(Get-Command scoop -ErrorAction SilentlyContinue)) { return $false }

    # Check scoop apps directory directly - most reliable method
    $scoopDir = if ($env:SCOOP) { $env:SCOOP } else { Join-Path $env:USERPROFILE "scoop" }
    $appPath = Join-Path $scoopDir "apps\$PackageName"
    return (Test-Path $appPath)
}

function Update-WingetPackage {
    param([string]$PackageId)

    Write-Status -Manager "winget" -Package $PackageId -Status "Updating"

    try {
        $output = winget upgrade --id $PackageId --silent --accept-package-agreements --accept-source-agreements 2>&1 | Out-String
        $exitCode = $LASTEXITCODE

        $upToDatePatterns = @(
            'No available upgrade found',
            'No newer package versions are available',
            'No applicable update found'
        )

        $isUpToDate = $false
        foreach ($pattern in $upToDatePatterns) {
            if ($output -imatch $pattern) {
                $isUpToDate = $true
                break
            }
        }

        if ($exitCode -eq 0 -or $isUpToDate) {
            if ($isUpToDate) {
                Write-Status -Manager "winget" -Package $PackageId -Status "UpToDate"
                $script:Summary.Updated += "winget: $PackageId (up to date)"
            }
            else {
                Write-Status -Manager "winget" -Package $PackageId -Status "Success"
                $script:Summary.Updated += "winget: $PackageId"
            }
            Write-Log -Message "SUCCESS: winget | $PackageId" -Type Success
            return $true
        }
        else {
            Write-Status -Manager "winget" -Package $PackageId -Status "Failed"
            $script:Summary.Failed += "winget: $PackageId"
            Write-Log -Message "FAILED: winget | $PackageId | Exit: $exitCode`n$output" -Type Error
            return $false
        }
    }
    catch {
        Write-Status -Manager "winget" -Package $PackageId -Status "Error" -Details $_.Exception.Message
        $script:Summary.Failed += "winget: $PackageId"
        Write-Log -Message "ERROR: winget | $PackageId | $($_.Exception.Message)" -Type Error
        return $false
    }
}

function Update-ChocoPackage {
    param([string]$PackageName)

    Write-Status -Manager "choco" -Package $PackageName -Status "Updating"

    try {
        $output = choco upgrade $PackageName -y -r --no-progress 2>&1 | Out-String
        $exitCode = $LASTEXITCODE

        $upToDatePatterns = @(
            'already installed',
            'is already the latest version',
            'Chocolatey upgraded 0/',
            '0 packages upgraded'
        )

        $isUpToDate = $false
        foreach ($pattern in $upToDatePatterns) {
            if ($output -imatch $pattern) {
                $isUpToDate = $true
                break
            }
        }

        if ($exitCode -eq 0) {
            if ($isUpToDate) {
                Write-Status -Manager "choco" -Package $PackageName -Status "UpToDate"
                $script:Summary.Updated += "choco: $PackageName (up to date)"
            }
            else {
                Write-Status -Manager "choco" -Package $PackageName -Status "Success"
                $script:Summary.Updated += "choco: $PackageName"
            }
            Write-Log -Message "SUCCESS: choco | $PackageName" -Type Success
            return $true
        }
        else {
            Write-Status -Manager "choco" -Package $PackageName -Status "Failed"
            $script:Summary.Failed += "choco: $PackageName"
            Write-Log -Message "FAILED: choco | $PackageName | Exit: $exitCode`n$output" -Type Error
            return $false
        }
    }
    catch {
        Write-Status -Manager "choco" -Package $PackageName -Status "Error" -Details $_.Exception.Message
        $script:Summary.Failed += "choco: $PackageName"
        Write-Log -Message "ERROR: choco | $PackageName | $($_.Exception.Message)" -Type Error
        return $false
    }
}

function Update-ScoopPackage {
    param([string]$PackageName)

    Write-Status -Manager "scoop" -Package $PackageName -Status "Updating"

    try {
        $output = scoop update $PackageName 2>&1 | Out-String
        $exitCode = $LASTEXITCODE

        $upToDatePatterns = @(
            'Latest version',
            '\(latest version\)',
            'is already up to date'
        )

        $isUpToDate = $false
        foreach ($pattern in $upToDatePatterns) {
            if ($output -imatch $pattern) {
                $isUpToDate = $true
                break
            }
        }

        if ($exitCode -eq 0 -or $isUpToDate) {
            if ($isUpToDate) {
                Write-Status -Manager "scoop" -Package $PackageName -Status "UpToDate"
                $script:Summary.Updated += "scoop: $PackageName (up to date)"
            }
            else {
                Write-Status -Manager "scoop" -Package $PackageName -Status "Success"
                $script:Summary.Updated += "scoop: $PackageName"
            }
            Write-Log -Message "SUCCESS: scoop | $PackageName" -Type Success
            return $true
        }
        else {
            Write-Status -Manager "scoop" -Package $PackageName -Status "Failed"
            $script:Summary.Failed += "scoop: $PackageName"
            Write-Log -Message "FAILED: scoop | $PackageName | Exit: $exitCode`n$output" -Type Error
            return $false
        }
    }
    catch {
        Write-Status -Manager "scoop" -Package $PackageName -Status "Error" -Details $_.Exception.Message
        $script:Summary.Failed += "scoop: $PackageName"
        Write-Log -Message "ERROR: scoop | $PackageName | $($_.Exception.Message)" -Type Error
        return $false
    }
}

#endregion

#region Process Functions

function Invoke-WingetUpdates {
    param([array]$Packages)

    if (!(Get-Command winget -ErrorAction SilentlyContinue)) {
        Write-Host "`nWinget is not installed. Skipping Winget packages." -ForegroundColor Yellow
        $script:Summary.Skipped += "winget: all packages (not installed)"
        return
    }

    Write-Host "`n--- Processing Winget Packages ---" -ForegroundColor Cyan

    foreach ($pkg in $Packages) {
        $packageId = $pkg.packageId
        if ([string]::IsNullOrWhiteSpace($packageId)) { continue }

        if (Test-WingetInstalled -PackageId $packageId) {
            Update-WingetPackage -PackageId $packageId | Out-Null
        }
        else {
            Write-Status -Manager "winget" -Package $packageId -Status "Skipped" -Details "not installed"
            $script:Summary.Skipped += "winget: $packageId (not installed)"
        }
    }
}

function Invoke-ChocoUpdates {
    param([array]$Packages)

    if (!(Get-Command choco -ErrorAction SilentlyContinue)) {
        Write-Host "`nChocolatey is not installed. Skipping Choco packages." -ForegroundColor Yellow
        $script:Summary.Skipped += "choco: all packages (not installed)"
        return
    }

    Write-Host "`n--- Processing Chocolatey Packages ---" -ForegroundColor Cyan

    foreach ($pkg in $Packages) {
        $packageName = $pkg.packageName
        if ([string]::IsNullOrWhiteSpace($packageName)) { continue }

        if (Test-ChocoInstalled -PackageName $packageName) {
            Update-ChocoPackage -PackageName $packageName | Out-Null
        }
        else {
            Write-Status -Manager "choco" -Package $packageName -Status "Skipped" -Details "not installed"
            $script:Summary.Skipped += "choco: $packageName (not installed)"
        }
    }
}

function Invoke-ScoopUpdates {
    param([array]$Packages)

    if (!(Get-Command scoop -ErrorAction SilentlyContinue)) {
        Write-Host "`nScoop is not installed. Skipping Scoop packages." -ForegroundColor Yellow
        $script:Summary.Skipped += "scoop: all packages (not installed)"
        return
    }

    Write-Host "`n--- Processing Scoop Packages ---" -ForegroundColor Cyan

    foreach ($pkg in $Packages) {
        $packageName = $pkg.packageName
        if ([string]::IsNullOrWhiteSpace($packageName)) { continue }

        if (Test-ScoopInstalled -PackageName $packageName) {
            Update-ScoopPackage -PackageName $packageName | Out-Null
        }
        else {
            Write-Status -Manager "scoop" -Package $packageName -Status "Skipped" -Details "not installed"
            $script:Summary.Skipped += "scoop: $packageName (not installed)"
        }
    }
}

function Invoke-ScoopInNonAdmin {
    param([array]$Packages)

    Write-Host "`n--- Processing Scoop Packages (spawning non-admin) ---" -ForegroundColor Cyan

    $packageNames = ($Packages | Where-Object { $_.packageName } | ForEach-Object { $_.packageName }) -join ","

    $tempScript = Join-Path $env:TEMP "scoop_update_$($script:Timestamp).ps1"

    $scriptContent = @'
$ErrorActionPreference = 'Continue'
$packages = $args[0] -split ','

foreach ($name in $packages) {
    if ([string]::IsNullOrWhiteSpace($name)) { continue }

    $result = scoop list $name 2>&1 | Out-String
    $result = $result -replace "Installed apps matching.*?:`r?`n", ""
    if ($result -notmatch [regex]::Escape($name)) {
        Write-Host "[update] scoop: (skipped) $name - not installed" -ForegroundColor Yellow
        continue
    }

    Write-Host "[update] scoop: ... $name" -ForegroundColor Gray
    $output = scoop update $name 2>&1 | Out-String

    if ($output -imatch 'Latest version' -or $output -imatch '\(latest version\)') {
        Write-Host "[update] scoop: (up to date) $name" -ForegroundColor Green
    }
    elseif ($LASTEXITCODE -eq 0) {
        Write-Host "[update] scoop: (success) $name" -ForegroundColor Green
    }
    else {
        Write-Host "[update] scoop: (failed) $name" -ForegroundColor Red
    }
}
Write-Host "`nPress any key to close..." -ForegroundColor Gray
$null = $Host.UI.RawUI.ReadKey("NoEcho,IncludeKeyDown")
'@

    $scriptContent | Out-File $tempScript -Encoding utf8

    try {
        Start-Process -FilePath "runas" -ArgumentList "/trustlevel:0x20000 `"pwsh -NoProfile -ExecutionPolicy Bypass -File `"$tempScript`" `"$packageNames`"`"" -Wait

        $script:Summary.Updated += "scoop: packages processed in non-admin context"
    }
    catch {
        Write-Host "Failed to spawn non-admin process for Scoop: $_" -ForegroundColor Red
        $script:Summary.Failed += "scoop: failed to spawn non-admin process"
    }
    finally {
        Start-Sleep -Seconds 1
        Remove-Item $tempScript -Force -ErrorAction SilentlyContinue
    }
}

function Invoke-ElevatedUpdate {
    param(
        [bool]$ProcessWinget,
        [bool]$ProcessChoco
    )

    $managers = @()
    if ($ProcessWinget) { $managers += "-Winget" }
    if ($ProcessChoco) { $managers += "-Choco" }

    if ($managers.Count -eq 0) { return }

    $scriptPath = Join-Path $script:ScriptRoot "updateApps.ps1"
    $arguments = $managers -join " "

    Write-Host "`nElevating to admin for Winget/Choco updates..." -ForegroundColor Yellow

    try {
        Start-Process -FilePath "pwsh" `
            -ArgumentList "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", "`"$scriptPath`"", $arguments `
            -Verb RunAs -Wait
    }
    catch {
        Write-Host "Failed to elevate: $_" -ForegroundColor Red
        $script:Summary.Failed += "elevation: failed to run as admin"
    }
}

#endregion

#region Display Functions

function Show-Summary {
    $footer = "`n========================================`nUpdate Completed: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')`n========================================"
    Write-Log -Message $footer -Type Success
    Write-Log -Message $footer -Type Error

    Write-Host "`n========================================" -ForegroundColor Cyan
    Write-Host "Update Summary" -ForegroundColor Cyan
    Write-Host "========================================" -ForegroundColor Cyan

    $updatedCount = $script:Summary.Updated.Count
    $failedCount = $script:Summary.Failed.Count
    $skippedCount = $script:Summary.Skipped.Count

    Write-Host "Updated: $updatedCount" -ForegroundColor Green
    Write-Host "Failed:  $failedCount" -ForegroundColor Red
    Write-Host "Skipped: $skippedCount" -ForegroundColor Yellow

    if ($skippedCount -gt 0 -and $skippedCount -le 20) {
        Write-Host "`nSkipped packages:" -ForegroundColor Yellow
        $script:Summary.Skipped | ForEach-Object {
            Write-Host "  - $_" -ForegroundColor Gray
        }
    }

    Write-Host "`nLogs:" -ForegroundColor Cyan
    Write-Host "  Success: $($script:SuccessLog)" -ForegroundColor Gray
    Write-Host "  Errors:  $($script:ErrorLog)" -ForegroundColor Gray
    Write-Host "========================================`n" -ForegroundColor Cyan
}

#endregion

#region Main Execution

$noSwitchSpecified = -not ($Scoop -or $Winget -or $Choco -or $All)
$processAll = $All -or $noSwitchSpecified
$processWinget = $processAll -or $Winget
$processChoco = $processAll -or $Choco
$processScoop = $processAll -or $Scoop

Initialize-Logging
Write-Host "`nStarting application updates..." -ForegroundColor Green

$appList = Get-AppList
$wingetPackages = $appList.installSource.winget.packageList
$chocoPackages = $appList.installSource.choco.packageList
$scoopPackages = $appList.installSource.scoop.packageList

$isAdmin = Test-Administrator

if ($isAdmin) {
    Write-Host "Running as Administrator" -ForegroundColor Cyan

    if ($processWinget -and $appList.installSource.winget.autoInstall) {
        Invoke-WingetUpdates -Packages $wingetPackages
    }

    if ($processChoco -and $appList.installSource.choco.autoInstall) {
        Invoke-ChocoUpdates -Packages $chocoPackages
    }

    if ($processScoop -and $appList.installSource.scoop.autoInstall) {
        Invoke-ScoopInNonAdmin -Packages $scoopPackages
    }
}
else {
    Write-Host "Running as Non-Administrator" -ForegroundColor Cyan

    if ($processScoop -and $appList.installSource.scoop.autoInstall) {
        Invoke-ScoopUpdates -Packages $scoopPackages
    }

    $needsElevation = ($processWinget -and $appList.installSource.winget.autoInstall) -or
                      ($processChoco -and $appList.installSource.choco.autoInstall)

    if ($needsElevation) {
        Invoke-ElevatedUpdate -ProcessWinget ($processWinget -and $appList.installSource.winget.autoInstall) `
                              -ProcessChoco ($processChoco -and $appList.installSource.choco.autoInstall)
    }
}

Show-Summary

$exitCode = if ($script:Summary.Failed.Count -gt 0) { 1 } else { 0 }
exit $exitCode

#endregion
