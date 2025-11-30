#Requires -Version 7

<#
.SYNOPSIS
    Updates installed applications from appList.json using appropriate package managers.

.DESCRIPTION
    This script updates all installed packages listed in appList.json using the correct
    package manager (Winget, Chocolatey, or Scoop) based on priority order.
    Scoop updates run in a non-admin process to prevent package corruption.

.PARAMETER Winget
    Only update packages installed via Winget.

.PARAMETER Choco
    Only update packages installed via Chocolatey.

.PARAMETER Scoop
    Only update packages installed via Scoop.

.EXAMPLE
    .\updateApps.ps1
    Updates all packages from all package managers.

.EXAMPLE
    .\updateApps.ps1 -Winget
    Updates only Winget packages.

.EXAMPLE
    .\updateApps.ps1 -Choco -Scoop
    Updates Chocolatey and Scoop packages only.

.NOTES
    Author: eagarcia@techforexcellence.org
    Version: 1.0.0
#>

Param(
	[switch]$Winget,
	[switch]$Choco,
	[switch]$Scoop
)

$ErrorActionPreference = "Continue"
$VerbosePreference = "SilentlyContinue"

# Determine which package managers to process
# If no switches specified, process all (default behavior)
$processWinget = if ($Winget -or $Choco -or $Scoop) { $Winget } else { $true }
$processChoco = if ($Winget -or $Choco -or $Scoop) { $Choco } else { $true }
$processScoop = if ($Winget -or $Choco -or $Scoop) { $Scoop } else { $true }

# Set script root
$scriptRoot = $PSScriptRoot
if (!$scriptRoot) {
	$scriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
}

# Initialize logging
$logDir = Join-Path $env:USERPROFILE "w11dot_logs\apps"
$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$successLog = Join-Path $logDir "appUpdate_${timestamp}_success.log"
$errorLog = Join-Path $logDir "appUpdate_${timestamp}_error.log"

# Create log directory if it doesn't exist
if (!(Test-Path $logDir)) {
	New-Item -ItemType Directory -Path $logDir -Force | Out-Null
}

# Initialize log files
"========================================`n" | Out-File $successLog -Encoding utf8
"Update Started: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')`n" | Out-File $successLog -Append -Encoding utf8
"========================================`n`n" | Out-File $successLog -Append -Encoding utf8

"========================================`n" | Out-File $errorLog -Encoding utf8
"Update Started: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')`n" | Out-File $errorLog -Append -Encoding utf8
"========================================`n`n" | Out-File $errorLog -Append -Encoding utf8

# Tracking variables
$script:updateSummary = @{
	Updated = @()
	Skipped = @()
	Failed  = @()
}

# Helper function to write colored output
function Write-ColorText {
	param ([string]$Text, [switch]$NoNewLine)
	$hostColor = $Host.UI.RawUI.ForegroundColor
	$Text.Split( [char]"{", [char]"}" ) | ForEach-Object { $i = 0; } {
		if ($i % 2 -eq 0) { Write-Host $_ -NoNewline }
		else {
			if ($_ -in [enum]::GetNames("ConsoleColor")) {
				$Host.UI.RawUI.ForegroundColor = ($_ -as [System.ConsoleColor])
			}
		}
		$i++
	}
	if (!$NoNewLine) { Write-Host }
	$Host.UI.RawUI.ForegroundColor = $hostColor
}

# Check if running as admin
function Test-Administrator {
	$currentUser = [System.Security.Principal.WindowsIdentity]::GetCurrent()
	$principal = New-Object System.Security.Principal.WindowsPrincipal($currentUser)
	return $principal.IsInRole([System.Security.Principal.WindowsBuiltInRole]::Administrator)
}

# Check if package is installed via Winget
function Test-WinGetInstalled {
	param ([string]$PackageID)
	if (!(Get-Command winget -ErrorAction SilentlyContinue)) { return $false }
	$result = winget list --exact -q $PackageID 2>&1
	return ($LASTEXITCODE -eq 0)
}

# Check if package is installed via Chocolatey
function Test-ChocoInstalled {
	param ([string]$PackageName)
	if (!(Get-Command choco -ErrorAction SilentlyContinue)) { return $false }

	# Method 1: Check Chocolatey lib directory (most reliable)
	$chocoLibPath = "C:\ProgramData\chocolatey\lib\$PackageName"
	if (Test-Path $chocoLibPath) {
		return $true
	}

	# Method 2: Use choco list with --limit-output for machine-readable format
	$tempOut = [System.IO.Path]::GetTempFileName()
	$tempErr = [System.IO.Path]::GetTempFileName()

	try {
		$process = Start-Process -FilePath "choco" `
			-ArgumentList "list", $PackageName, "--local-only", "--limit-output" `
			-Wait -PassThru -WindowStyle Hidden `
			-RedirectStandardOutput $tempOut `
			-RedirectStandardError $tempErr

		# Wait a moment for files to be written
		Start-Sleep -Milliseconds 100

		$output = Get-Content $tempOut -Raw -ErrorAction SilentlyContinue
		$errorOutput = Get-Content $tempErr -Raw -ErrorAction SilentlyContinue
		$combinedOutput = if ($output) { $output } else { "" }
		$combinedOutput += if ($errorOutput) { $errorOutput } else { "" }

		# Check if package is in the output (case-insensitive)
		# Format is typically: PackageName|Version or just PackageName in the list
		$isInstalled = ($process.ExitCode -eq 0 -and $combinedOutput -match [regex]::Escape($PackageName))

		Remove-Item $tempOut -Force -ErrorAction SilentlyContinue
		Remove-Item $tempErr -Force -ErrorAction SilentlyContinue

		return $isInstalled
	} catch {
		Remove-Item $tempOut -Force -ErrorAction SilentlyContinue
		Remove-Item $tempErr -Force -ErrorAction SilentlyContinue
		# Fallback: Check lib directory again
		return (Test-Path $chocoLibPath)
	}
}

# Check if package is installed via Scoop
function Test-ScoopInstalled {
	param ([string]$PackageName)
	if (!(Get-Command scoop -ErrorAction SilentlyContinue)) { return $false }

	# Check if running as admin - if so, spawn non-admin process
	$isAdmin = Test-Administrator

	if ($isAdmin) {
		# Spawn non-admin PowerShell process for Scoop
		$tempScript = [System.IO.Path]::GetTempFileName() -replace '\.tmp$', '.ps1'
		$resultFile = "$tempScript.result"

		$scriptContent = @"
`$ErrorActionPreference = 'Continue'
try {
	`$result = scoop list '$PackageName' 2>&1
	`$output = `$result | Out-String
	`$exitCode = `$LASTEXITCODE
	@{ ExitCode = `$exitCode; Output = `$output } | ConvertTo-Json -Compress | Out-File '$resultFile' -Encoding utf8
} catch {
	@{ ExitCode = 1; Output = `$_.Exception.Message } | ConvertTo-Json -Compress | Out-File '$resultFile' -Encoding utf8
}
"@
		$scriptContent | Out-File $tempScript -Encoding utf8

		try {
			$process = Start-Process -FilePath "powershell.exe" `
				-ArgumentList "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", "`"$tempScript`"" `
				-Wait -PassThru -WindowStyle Hidden

			# Wait for result file
			$maxWait = 5
			$waited = 0
			while (!(Test-Path $resultFile) -and $waited -lt $maxWait) {
				Start-Sleep -Milliseconds 200
				$waited += 0.2
			}

			if (Test-Path $resultFile) {
				$resultJson = Get-Content $resultFile -Raw | ConvertFrom-Json
				$exitCode = $resultJson.ExitCode
				$output = $resultJson.Output
				if ($output -is [System.Array]) { $output = $output -join "`n" }
				if ($output -isnot [string]) { $output = $output.ToString() }

				# Filter out "Installed apps matching" line
				$output = $output -replace "Installed apps matching.*?:`r?`n", ""
				$isInstalled = ($exitCode -eq 0 -and $output -match [regex]::Escape($PackageName))

				Remove-Item $resultFile -Force -ErrorAction SilentlyContinue
				Remove-Item $tempScript -Force -ErrorAction SilentlyContinue
				return $isInstalled
			} else {
				Remove-Item $tempScript -Force -ErrorAction SilentlyContinue
				return $false
			}
		} catch {
			Remove-Item $tempScript -Force -ErrorAction SilentlyContinue
			Remove-Item $resultFile -Force -ErrorAction SilentlyContinue
			return $false
		}
	} else {
		# Run directly if not admin
		try {
			$result = scoop list $PackageName 2>&1 | Out-String
			$output = $result -replace "Installed apps matching.*?:`r?`n", ""
			return ($LASTEXITCODE -eq 0 -and $output -match [regex]::Escape($PackageName))
		} catch {
			return $false
		}
	}
}

# Get package version from Winget
function Get-WinGetVersion {
	param ([string]$PackageID)
	if (!(Get-Command winget -ErrorAction SilentlyContinue)) { return $null }
	try {
		# Use winget list to get installed version (more reliable than show)
		$info = winget list --exact -q $PackageID 2>&1 | Out-String
		# Parse version from list output (format: PackageID  Version  Available)
		# Improved regex to handle various version formats: x.y.z, x.y.z-beta, x.y.z.0, etc.
		# Match pattern: PackageID followed by whitespace, then version number
		if ($info -match "$([regex]::Escape($PackageID))\s+([\d.]+(?:[\-\.][\w]+)?)") {
			return $matches[1].Trim()
		}
		# Alternative: try to match version pattern anywhere in the line
		if ($info -match "(\d+\.\d+(?:\.\d+)?(?:[\-\.][\w]+)?)") {
			return $matches[1].Trim()
		}
	} catch {
		# Ignore errors
	}
	return $null
}

# Get package version from Chocolatey
function Get-ChocoVersion {
	param ([string]$PackageName)
	if (!(Get-Command choco -ErrorAction SilentlyContinue)) { return $null }
	try {
		$info = choco list $PackageName --local-only --exact 2>&1 | Out-String
		# Parse version from list output - improved regex for various version formats
		if ($info -match "$([regex]::Escape($PackageName))\s+([\d.]+(?:[\-\.][\w]+)?)") {
			return $matches[1].Trim()
		}
	} catch {
		# Ignore errors
	}
	return $null
}

# Get package version from Scoop
function Get-ScoopVersion {
	param ([string]$PackageName)
	if (!(Get-Command scoop -ErrorAction SilentlyContinue)) { return $null }

	# Check if running as admin - if so, spawn non-admin process
	$isAdmin = Test-Administrator

	if ($isAdmin) {
		# Spawn non-admin PowerShell process for Scoop
		$tempScript = [System.IO.Path]::GetTempFileName() -replace '\.tmp$', '.ps1'
		$resultFile = "$tempScript.result"

		$scriptContent = @"
`$ErrorActionPreference = 'Continue'
try {
	# Try scoop info first (cleaner output)
	`$info = scoop info '$PackageName' 2>&1 | Out-String
	if (`$info -match 'Version:\s+([\d.]+(?:[\-\.][\w]+)?)') {
		@{ Success = `$true; Version = `$matches[1].Trim() } | ConvertTo-Json -Compress | Out-File '$resultFile' -Encoding utf8
		exit
	}

	# Fallback to scoop list
	`$list = scoop list '$PackageName' 2>&1 | Out-String
	`$list = `$list -replace 'Installed apps matching.*?:`r?`n', ''
	if (`$list -match '$([regex]::Escape($PackageName))\s+([\d.]+(?:[\-\.][\w]+)?)') {
		@{ Success = `$true; Version = `$matches[1].Trim() } | ConvertTo-Json -Compress | Out-File '$resultFile' -Encoding utf8
	} else {
		@{ Success = `$false; Version = `$null } | ConvertTo-Json -Compress | Out-File '$resultFile' -Encoding utf8
	}
} catch {
	@{ Success = `$false; Version = `$null } | ConvertTo-Json -Compress | Out-File '$resultFile' -Encoding utf8
}
"@
		$scriptContent | Out-File $tempScript -Encoding utf8

		try {
			$process = Start-Process -FilePath "powershell.exe" `
				-ArgumentList "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", "`"$tempScript`"" `
				-Wait -PassThru -WindowStyle Hidden

			# Wait for result file
			$maxWait = 5
			$waited = 0
			while (!(Test-Path $resultFile) -and $waited -lt $maxWait) {
				Start-Sleep -Milliseconds 200
				$waited += 0.2
			}

			if (Test-Path $resultFile) {
				$resultJson = Get-Content $resultFile -Raw | ConvertFrom-Json
				$version = if ($resultJson.Success) { $resultJson.Version } else { $null }
				Remove-Item $resultFile -Force -ErrorAction SilentlyContinue
				Remove-Item $tempScript -Force -ErrorAction SilentlyContinue
				return $version
			} else {
				Remove-Item $tempScript -Force -ErrorAction SilentlyContinue
				return $null
			}
		} catch {
			Remove-Item $tempScript -Force -ErrorAction SilentlyContinue
			Remove-Item $resultFile -Force -ErrorAction SilentlyContinue
			return $null
		}
	} else {
		# Run directly if not admin
		try {
			# Try scoop info first
			$info = scoop info $PackageName 2>&1 | Out-String
			if ($info -match "Version:\s+([\d.]+(?:[\-\.][\w]+)?)") {
				return $matches[1].Trim()
			}

			# Fallback to scoop list
			$list = scoop list $PackageName 2>&1 | Out-String
			$list = $list -replace "Installed apps matching.*?:`r?`n", ""
			if ($list -match "$([regex]::Escape($PackageName))\s+([\d.]+(?:[\-\.][\w]+)?)") {
				return $matches[1].Trim()
			}
		} catch {
			# Ignore errors
		}
		return $null
	}
}

# Update package via Winget
function Update-WinGetPackage {
	param ([string]$PackageID, [array]$AdditionalArgs)

	if (!(Get-Command winget -ErrorAction SilentlyContinue)) {
		Write-ColorText "{Blue}[update] {Magenta}winget: {Red}(skipped) {Gray}$PackageID {DarkGray}(winget not installed)"
		$script:updateSummary.Skipped += "winget: $PackageID (winget not installed)"
		return $false
	}

	try {
		$oldVersion = Get-WinGetVersion -PackageID $PackageID

		# First, check if package needs updating using winget list
		# winget list shows "Installed Version" and "Available Version" columns
		$listOutput = winget list --exact -q $PackageID 2>&1 | Out-String
		$needsUpdate = $false

		# Check if there's an available version different from installed
		# Format: PackageID  InstalledVersion  AvailableVersion
		if ($listOutput -match "$([regex]::Escape($PackageID))\s+([\d.]+(?:[\-\.][\w]+)?)\s+([\d.]+(?:[\-\.][\w]+)?)") {
			$installedVer = $matches[1].Trim()
			$availableVer = $matches[2].Trim()
			if ($installedVer -ne $availableVer) {
				$needsUpdate = $true
			}
		} elseif ($listOutput -match "$([regex]::Escape($PackageID))\s+([\d.]+(?:[\-\.][\w]+)?)") {
			# Only one version shown (installed) - check if it matches oldVersion
			$installedVer = $matches[1].Trim()
			if ($oldVersion -and $installedVer -ne $oldVersion) {
				$needsUpdate = $true
			}
		}

		# If we know it doesn't need updating, skip the upgrade
		if (!$needsUpdate -and $oldVersion) {
			$versionInfo = $oldVersion
			$entry = "✅ winget | $PackageID | $versionInfo (already up to date)"
			$entry | Out-File $successLog -Append -Encoding utf8
			$script:updateSummary.Updated += "winget: $PackageID ($versionInfo - already up to date)"
			Write-ColorText "{Blue}[update] {Magenta}winget: {Green}(up to date) {Gray}$PackageID {DarkGray}($versionInfo)"
			return $true
		}

		# Use --silent to suppress UI prompts
		$updateCmd = "winget upgrade `"$PackageID`" --accept-package-agreements --accept-source-agreements --silent"

		if ($AdditionalArgs.Count -ge 1) {
			$updateCmd += " $($AdditionalArgs -join ' ')"
		}

		Write-ColorText "{Blue}[update] {Magenta}winget: {Gray}Updating $PackageID..."
		$output = Invoke-Expression "$updateCmd 2>&1" | Out-String
		$exitCode = $LASTEXITCODE

		# Check if package is already up to date
		# Primary method: Check output for "already up to date" messages (case-insensitive)
		$isAlreadyUpToDate = $false
		$upToDatePatterns = @(
			'No available upgrade found',
			'No newer package versions are available',
			'No newer package versions are available from the configured sources',
			'No applicable update found',
			'already installed',
			'is already up to date',
			'No upgrade available',
			'No updates available'
		)
		foreach ($pattern in $upToDatePatterns) {
			# Case-insensitive match
			if ($output -imatch $pattern) {
				$isAlreadyUpToDate = $true
				break
			}
		}

		# Secondary method: If exit code is 0, check if version changed
		# Winget returns exit code 0 when no upgrade is available
		if ($exitCode -eq 0 -and !$isAlreadyUpToDate) {
			Start-Sleep -Milliseconds 500  # Brief delay to ensure version info is updated
			$newVersion = Get-WinGetVersion -PackageID $PackageID
			# If versions are the same (or both exist and match), it's up to date
			if ($oldVersion -and $newVersion) {
				if ($oldVersion -eq $newVersion) {
					$isAlreadyUpToDate = $true
				}
			} elseif ($oldVersion -and !$newVersion) {
				# Old version exists but new doesn't - might be an error, don't assume up to date
			} elseif (!$oldVersion -and $newVersion) {
				# Couldn't get old version but got new version - if exit code is 0, likely up to date
				# This handles cases where initial version detection failed
				$isAlreadyUpToDate = $true
			} elseif (!$oldVersion -and !$newVersion) {
				# Can't determine version - if exit code is 0, assume up to date (better than failing)
				$isAlreadyUpToDate = $true
			}
		}

		if ($exitCode -eq 0 -or $isAlreadyUpToDate) {
			# Success or already up to date
			# Try to parse version from output first - improved regex patterns
			$parsedVersion = $null
			if ($output -match 'Version[:\s]+([\d.]+(?:[\-\.][\w]+)?)') {
				$parsedVersion = $matches[1].Trim()
			} elseif ($output -match 'Upgraded to[:\s]+([\d.]+(?:[\-\.][\w]+)?)') {
				$parsedVersion = $matches[1].Trim()
			} elseif ($output -match '(\d+\.\d+(?:\.\d+)?(?:[\-\.][\w]+)?)') {
				$parsedVersion = $matches[1].Trim()
			}

			# Fall back to querying if parsing failed
			$newVersion = if ($parsedVersion) { $parsedVersion } else { Get-WinGetVersion -PackageID $PackageID }

			if ($isAlreadyUpToDate) {
				# Already up to date - show current version
				$versionInfo = if ($newVersion) { $newVersion } else { if ($oldVersion) { $oldVersion } else { "current" } }
				$entry = "✅ winget | $PackageID | $versionInfo (already up to date)"
				$entry | Out-File $successLog -Append -Encoding utf8
				$script:updateSummary.Updated += "winget: $PackageID ($versionInfo - already up to date)"
				Write-ColorText "{Blue}[update] {Magenta}winget: {Green}(up to date) {Gray}$PackageID {DarkGray}($versionInfo)"
			} else {
				# Successfully updated
				$versionInfo = if ($oldVersion -and $newVersion -and $oldVersion -ne $newVersion) {
					"$oldVersion -> $newVersion"
				} elseif ($newVersion) {
					"$newVersion"
				} else {
					"updated"
				}
				$entry = "✅ winget | $PackageID | $versionInfo"
				$entry | Out-File $successLog -Append -Encoding utf8
				$script:updateSummary.Updated += "winget: $PackageID ($versionInfo)"
				Write-ColorText "{Blue}[update] {Magenta}winget: {Green}(success) {Gray}$PackageID {DarkGray}($versionInfo)"
			}
			return $true
		} else {
			$errorEntry = "❌ winget | $PackageID | Exit Code: $exitCode`n$output"
			$errorEntry | Out-File $errorLog -Append -Encoding utf8
			$script:updateSummary.Failed += "winget: $PackageID"
			Write-ColorText "{Blue}[update] {Magenta}winget: {Red}(failed) {Gray}$PackageID"
			return $false
		}
	} catch {
		$errorMsg = $_.Exception.Message
		$errorEntry = "❌ winget | $PackageID | Exception: $errorMsg`n$($_.ScriptStackTrace)"
		$errorEntry | Out-File $errorLog -Append -Encoding utf8
		$script:updateSummary.Failed += "winget: $PackageID"
		Write-ColorText "{Blue}[update] {Magenta}winget: {Red}(error) {Gray}$PackageID {DarkGray}($errorMsg)"
		return $false
	}
}

# Update package via Chocolatey
function Update-ChocoPackage {
	param ([string]$PackageName, [array]$AdditionalArgs)

	if (!(Get-Command choco -ErrorAction SilentlyContinue)) {
		Write-ColorText "{Blue}[update] {Magenta}choco: {Red}(skipped) {Gray}$PackageName {DarkGray}(chocolatey not installed)"
		$script:updateSummary.Skipped += "choco: $PackageName (chocolatey not installed)"
		return $false
	}

	try {
		$oldVersion = Get-ChocoVersion -PackageName $PackageName

		# First, check if package is outdated using choco outdated
		# This is more reliable than parsing upgrade output
		$isOutdated = $false
		$tempOutdated = [System.IO.Path]::GetTempFileName()
		$tempErrOutdated = [System.IO.Path]::GetTempFileName()

		try {
			$outdatedProcess = Start-Process -FilePath "choco" `
				-ArgumentList "outdated", $PackageName, "--limit-output" `
				-Wait -PassThru -WindowStyle Hidden `
				-RedirectStandardOutput $tempOutdated `
				-RedirectStandardError $tempErrOutdated

			Start-Sleep -Milliseconds 100

			$outdatedOutput = Get-Content $tempOutdated -Raw -ErrorAction SilentlyContinue
			$outdatedError = Get-Content $tempErrOutdated -Raw -ErrorAction SilentlyContinue
			$combinedOutdated = if ($outdatedOutput) { $outdatedOutput } else { "" }
			$combinedOutdated += if ($outdatedError) { $outdatedError } else { "" }

			# If package appears in outdated list, it needs updating
			# Format: PackageName|InstalledVersion|AvailableVersion
			if ($combinedOutdated -match "^$([regex]::Escape($PackageName))\|") {
				$isOutdated = $true
			}

			Remove-Item $tempOutdated -Force -ErrorAction SilentlyContinue
			Remove-Item $tempErrOutdated -Force -ErrorAction SilentlyContinue
		} catch {
			Remove-Item $tempOutdated -Force -ErrorAction SilentlyContinue
			Remove-Item $tempErrOutdated -Force -ErrorAction SilentlyContinue
			# If outdated check fails, assume we need to check via upgrade
			$isOutdated = $null  # Unknown - will check via upgrade output
		}

		# If we know it's not outdated, skip the upgrade
		if ($isOutdated -eq $false) {
			$versionInfo = if ($oldVersion) { $oldVersion } else { "current" }
			$entry = "✅ choco | $PackageName | $versionInfo (already up to date)"
			$entry | Out-File $successLog -Append -Encoding utf8
			$script:updateSummary.Updated += "choco: $PackageName ($versionInfo - already up to date)"
			Write-ColorText "{Blue}[update] {Magenta}choco: {Green}(up to date) {Gray}$PackageName {DarkGray}($versionInfo)"
			return $true
		}

		# Check if this is a psmodule package - these need PowerShell 5.1
		$isPsModule = $PackageName -like "*psmodule"

		if ($isPsModule) {
			# For psmodule packages, run in PowerShell 5.1 context
			Write-ColorText "{Blue}[update] {Magenta}choco: {Gray}Updating $PackageName (PowerShell module - using PowerShell 5.1)..."

			$tempScript = [System.IO.Path]::GetTempFileName() -replace '\.tmp$', '.ps1'
			$resultFile = "$tempScript.result"

			$updateCmd = "choco upgrade $PackageName -y -r --no-progress"
			if ($AdditionalArgs.Count -ge 1) {
				$updateCmd += " $($AdditionalArgs -join ' ')"
			}

			# Create script that imports PowerShellGet and runs choco upgrade
			$scriptContent = @"
`$ErrorActionPreference = 'Continue'
try {
	# Import PowerShellGet module (required for Update-Module in psmodule packages)
	Import-Module PowerShellGet -ErrorAction SilentlyContinue

	# Run choco upgrade
	`$result = Invoke-Expression '$updateCmd 2>&1'
	`$output = `$result | Out-String
	`$exitCode = `$LASTEXITCODE

	@{ ExitCode = `$exitCode; Output = `$output } | ConvertTo-Json -Compress | Out-File '$resultFile' -Encoding utf8
} catch {
	@{ ExitCode = 1; Output = `$_.Exception.Message } | ConvertTo-Json -Compress | Out-File '$resultFile' -Encoding utf8
}
"@
			$scriptContent | Out-File $tempScript -Encoding utf8

			try {
				# Run in PowerShell 5.1 (powershell.exe, not pwsh.exe)
				$process = Start-Process -FilePath "powershell.exe" `
					-ArgumentList "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", "`"$tempScript`"" `
					-Wait -PassThru -WindowStyle Hidden

				# Wait for result file with timeout
				$maxWait = 30  # psmodule packages can take longer
				$waited = 0
				while (!(Test-Path $resultFile) -and $waited -lt $maxWait) {
					Start-Sleep -Milliseconds 500
					$waited += 0.5
				}

				# Read result
				if (Test-Path $resultFile) {
					$resultJson = Get-Content $resultFile -Raw | ConvertFrom-Json
					$exitCode = $resultJson.ExitCode
					$output = $resultJson.Output
					# Ensure output is a string (JSON might return it as an array or object)
					if ($output -is [System.Array]) {
						$output = $output -join "`n"
					}
					if ($output -isnot [string]) {
						$output = $output.ToString()
					}
					Remove-Item $resultFile -Force -ErrorAction SilentlyContinue
				} else {
					$exitCode = if ($process.ExitCode) { $process.ExitCode } else { 1 }
					$output = "Process completed but result file not found. Exit code: $exitCode"
				}

				Remove-Item $tempScript -Force -ErrorAction SilentlyContinue
			} catch {
				$exitCode = 1
				$output = "Failed to run in PowerShell 5.1: $($_.Exception.Message)"
				Remove-Item $tempScript -Force -ErrorAction SilentlyContinue
				Remove-Item $resultFile -Force -ErrorAction SilentlyContinue
			}
		} else {
			# Regular package - run normally
			$updateCmd = "choco upgrade $PackageName -y -r --no-progress"
			if ($AdditionalArgs.Count -ge 1) {
				$updateCmd += " $($AdditionalArgs -join ' ')"
			}

			Write-ColorText "{Blue}[update] {Magenta}choco: {Gray}Updating $PackageName..."
			$output = Invoke-Expression "$updateCmd 2>&1" | Out-String
			$exitCode = $LASTEXITCODE
		}

		# Check if package is already up to date
		# Chocolatey can return exit code 0 or non-zero when no upgrade is available
		# Check output for "already up to date" messages regardless of exit code
		$isAlreadyUpToDate = $false
		$upToDatePatterns = @(
			'already installed',
			'is already the latest version',
			'is the latest version available',
			'Nothing to change',
			'No packages to upgrade',
			'up to date',
			'Chocolatey upgraded 0/',
			'upgraded 0/',
			'0 packages upgraded',
			'0 of 1 packages upgraded'
		)
		foreach ($pattern in $upToDatePatterns) {
			# Case-insensitive match
			if ($output -imatch $pattern) {
				$isAlreadyUpToDate = $true
				break
			}
		}

		# Also check: if exit code is 0 and version didn't change, treat as up to date
		# This is the most reliable check
		if ($exitCode -eq 0 -and !$isAlreadyUpToDate) {
			Start-Sleep -Milliseconds 500  # Brief delay to ensure version info is updated
			$newVersion = Get-ChocoVersion -PackageName $PackageName
			if ($oldVersion -and $newVersion) {
				if ($oldVersion -eq $newVersion) {
					$isAlreadyUpToDate = $true
				}
			} elseif (!$oldVersion -and $newVersion) {
				# Couldn't get old version but got new version
				# Check output more carefully - if it says "upgraded 0/", it's up to date
				if ($output -imatch 'upgraded\s+0/') {
					$isAlreadyUpToDate = $true
				}
			}
		}

		if ($exitCode -eq 0 -or $isAlreadyUpToDate) {
			# Success or already up to date
			# Try to parse version from output first - improved regex patterns
			$parsedVersion = $null
			if ($output -match 'upgraded to[:\s]+([\d.]+(?:[\-\.][\w]+)?)') {
				$parsedVersion = $matches[1].Trim()
			} elseif ($output -match "$([regex]::Escape($PackageName))\s+([\d.]+(?:[\-\.][\w]+)?)") {
				$parsedVersion = $matches[1].Trim()
			} elseif ($output -match '(\d+\.\d+(?:\.\d+)?(?:[\-\.][\w]+)?)') {
				$parsedVersion = $matches[1].Trim()
			}

			# Fall back to querying if parsing failed
			$newVersion = if ($parsedVersion) { $parsedVersion } else { Get-ChocoVersion -PackageName $PackageName }

			if ($isAlreadyUpToDate) {
				# Already up to date - show current version
				$versionInfo = if ($newVersion) { $newVersion } else { if ($oldVersion) { $oldVersion } else { "current" } }
				$entry = "✅ choco | $PackageName | $versionInfo (already up to date)"
				$entry | Out-File $successLog -Append -Encoding utf8
				$script:updateSummary.Updated += "choco: $PackageName ($versionInfo - already up to date)"
				Write-ColorText "{Blue}[update] {Magenta}choco: {Green}(up to date) {Gray}$PackageName {DarkGray}($versionInfo)"
			} else {
				# Successfully updated
				$versionInfo = if ($oldVersion -and $newVersion -and $oldVersion -ne $newVersion) {
					"$oldVersion -> $newVersion"
				} elseif ($newVersion) {
					"$newVersion"
				} else {
					"updated"
				}
				$entry = "✅ choco | $PackageName | $versionInfo"
				$entry | Out-File $successLog -Append -Encoding utf8
				$script:updateSummary.Updated += "choco: $PackageName ($versionInfo)"
				Write-ColorText "{Blue}[update] {Magenta}choco: {Green}(success) {Gray}$PackageName {DarkGray}($versionInfo)"
			}
			return $true
		} else {
			$errorEntry = "❌ choco | $PackageName | Exit Code: $exitCode`n$output"
			$errorEntry | Out-File $errorLog -Append -Encoding utf8
			$script:updateSummary.Failed += "choco: $PackageName"
			Write-ColorText "{Blue}[update] {Magenta}choco: {Red}(failed) {Gray}$PackageName"
			return $false
		}
	} catch {
		$errorMsg = $_.Exception.Message
		$errorEntry = "❌ choco | $PackageName | Exception: $errorMsg`n$($_.ScriptStackTrace)"
		$errorEntry | Out-File $errorLog -Append -Encoding utf8
		$script:updateSummary.Failed += "choco: $PackageName"
		Write-ColorText "{Blue}[update] {Magenta}choco: {Red}(error) {Gray}$PackageName {DarkGray}($errorMsg)"
		return $false
	}
}

# Update package via Scoop (must run as non-admin)
function Update-ScoopPackage {
	param ([string]$PackageName, [array]$AdditionalArgs)

	if (!(Get-Command scoop -ErrorAction SilentlyContinue)) {
		Write-ColorText "{Blue}[update] {Magenta}scoop: {Red}(skipped) {Gray}$PackageName {DarkGray}(scoop not installed)"
		$script:updateSummary.Skipped += "scoop: $PackageName (scoop not installed)"
		return $false
	}

	try {
		$oldVersion = Get-ScoopVersion -PackageName $PackageName
		$updateCmd = "scoop update $PackageName"

		if ($AdditionalArgs.Count -ge 1) {
			$updateCmd += " $($AdditionalArgs -join ' ')"
		}

		# Check if running as admin - if so, spawn non-admin process
		$isAdmin = Test-Administrator

		# First, check if update is available (dry run or check)
		# Scoop update will show status in output, so we'll parse it
		if ($isAdmin) {
			# Spawn non-admin PowerShell process for Scoop
			# Use timestamp + random to prevent conflicts
			$timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
			$random = Get-Random
			$tempScript = Join-Path $env:TEMP "scoop_update_${timestamp}_${random}.ps1"
			$resultFile = "$tempScript.result"

			$scriptContent = @"
`$ErrorActionPreference = 'Continue'
try {
	`$result = Invoke-Expression '$updateCmd 2>&1'
	`$output = `$result | Out-String
	`$exitCode = `$LASTEXITCODE
	@{
		ExitCode = `$exitCode
		Output = `$output
	} | ConvertTo-Json -Compress | Out-File '$resultFile' -Encoding utf8
} catch {
	@{
		ExitCode = 1
		Output = `$_.Exception.Message
	} | ConvertTo-Json -Compress | Out-File '$resultFile' -Encoding utf8
}
"@
			$scriptContent | Out-File $tempScript -Encoding utf8

			try {
				# Spawn non-admin process (use WindowStyle Hidden, not NoNewWindow)
				$process = Start-Process -FilePath "powershell.exe" `
					-ArgumentList "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", "`"$tempScript`"" `
					-Wait -PassThru -WindowStyle Hidden

				# Wait for result file with timeout (max 5 seconds)
				$maxWait = 5
				$waited = 0
				while (!(Test-Path $resultFile) -and $waited -lt $maxWait) {
					Start-Sleep -Milliseconds 200
					$waited += 0.2
				}

				# Read result
				if (Test-Path $resultFile) {
					$resultJson = Get-Content $resultFile -Raw | ConvertFrom-Json
					$exitCode = $resultJson.ExitCode
					$output = $resultJson.Output
					# Ensure output is a string (JSON might return it as an array or object)
					if ($output -is [System.Array]) {
						$output = $output -join "`n"
					}
					if ($output -isnot [string]) {
						$output = $output.ToString()
					}
					Remove-Item $resultFile -Force -ErrorAction SilentlyContinue
				} else {
					$exitCode = if ($process.ExitCode) { $process.ExitCode } else { 1 }
					$output = "Process completed but result file not found. Exit code: $exitCode"
				}

				# Cleanup
				Remove-Item $tempScript -Force -ErrorAction SilentlyContinue
			} catch {
				$exitCode = 1
				$output = "Failed to spawn non-admin process: $($_.Exception.Message)"
				Remove-Item $tempScript -Force -ErrorAction SilentlyContinue
				Remove-Item $resultFile -Force -ErrorAction SilentlyContinue
			}
		} else {
			# Run directly if not admin
			try {
				$output = Invoke-Expression "$updateCmd 2>&1" | Out-String
				$exitCode = $LASTEXITCODE
			} catch {
				$output = $_.Exception.Message
				$exitCode = 1
			}
		}

		# Check if package is already up to date
		# Scoop can return exit code 0 or non-zero when no update is available
		# Check output for "already up to date" messages regardless of exit code
		$isAlreadyUpToDate = $false

		# First, check for the specific pattern: "PackageName: Version (latest version)"
		# This is the most reliable indicator - check this FIRST before other patterns
		if ($output -and $output -imatch "$([regex]::Escape($PackageName)):.*\(latest version\)") {
			$isAlreadyUpToDate = $true
		}

		# Also check for other "up to date" patterns
		if (!$isAlreadyUpToDate -and $output) {
			$upToDatePatterns = @(
				'already installed',
				'is already up to date',
				'Latest version installed',
				'No updates available',
				'is the latest version',
				'is up to date',
				'is already the latest version',
				'\(latest version\)',
				'latest version\)',
				'Latest versions for all apps are installed',
				'Latest versions for all apps are installed!'
			)
			foreach ($pattern in $upToDatePatterns) {
				# Case-insensitive match
				if ($output -imatch $pattern) {
					$isAlreadyUpToDate = $true
					break
				}
			}
		}

		# Also check: if exit code is 0 and version didn't change, treat as up to date
		# This is the most reliable check as a fallback
		if ($exitCode -eq 0 -and !$isAlreadyUpToDate) {
			Start-Sleep -Milliseconds 500  # Brief delay to ensure version info is updated
			$newVersion = Get-ScoopVersion -PackageName $PackageName
			if ($oldVersion -and $newVersion) {
				if ($oldVersion -eq $newVersion) {
					$isAlreadyUpToDate = $true
				}
			} elseif (!$oldVersion -and $newVersion) {
				# Couldn't get old version but got new version
				# Check output for "latest version" message as final check
				if ($output -and $output -imatch 'latest version') {
					$isAlreadyUpToDate = $true
				}
			} elseif ($oldVersion -and !$newVersion) {
				# Got old version but couldn't get new version
				# If output says "latest version", assume up to date
				if ($output -and $output -imatch 'latest version') {
					$isAlreadyUpToDate = $true
				}
			}
		}

		if ($exitCode -eq 0 -or $isAlreadyUpToDate) {
			# Success or already up to date
			# Try to parse version from output first - improved regex patterns
			$parsedVersion = $null
			if ($output -match 'Updated\s+.*?to\s+([\d.]+(?:[\-\.][\w]+)?)') {
				$parsedVersion = $matches[1].Trim()
			} elseif ($output -match "$([regex]::Escape($PackageName)):?\s+([\d.]+(?:[\-\.][\w]+)?)") {
				$parsedVersion = $matches[1].Trim()
			} elseif ($output -match '(\d+\.\d+(?:\.\d+)?(?:[\-\.][\w]+)?)') {
				$parsedVersion = $matches[1].Trim()
			}

			# Fall back to querying if parsing failed
			$newVersion = if ($parsedVersion) { $parsedVersion } else { Get-ScoopVersion -PackageName $PackageName }

			if ($isAlreadyUpToDate) {
				# Already up to date - show current version
				# Get version info for display
				$displayVersion = if ($newVersion) { $newVersion } else { if ($oldVersion) { $oldVersion } else { Get-ScoopVersion -PackageName $PackageName } }
				$versionInfo = if ($displayVersion) { $displayVersion } else { "current" }
				$entry = "✅ scoop | $PackageName | $versionInfo (already up to date)"
				$entry | Out-File $successLog -Append -Encoding utf8
				$script:updateSummary.Updated += "scoop: $PackageName ($versionInfo - already up to date)"
				Write-ColorText "{Blue}[update] {Magenta}scoop: {Green}(up to date) {Gray}$PackageName {DarkGray}($versionInfo)"
			} else {
				# Successfully updated - only show this if version actually changed
				$versionInfo = if ($oldVersion -and $newVersion -and $oldVersion -ne $newVersion) {
					"$oldVersion -> $newVersion"
				} elseif ($newVersion) {
					"$newVersion"
				} else {
					"updated"
				}
				$entry = "✅ scoop | $PackageName | $versionInfo"
				$entry | Out-File $successLog -Append -Encoding utf8
				$script:updateSummary.Updated += "scoop: $PackageName ($versionInfo)"
				Write-ColorText "{Blue}[update] {Magenta}scoop: {Green}(success) {Gray}$PackageName {DarkGray}($versionInfo)"
			}
			$null = return $true  # Suppress return value output
		} else {
			$errorEntry = "❌ scoop | $PackageName | Exit Code: $exitCode`n$output"
			$errorEntry | Out-File $errorLog -Append -Encoding utf8
			$script:updateSummary.Failed += "scoop: $PackageName"
			Write-ColorText "{Blue}[update] {Magenta}scoop: {Red}(failed) {Gray}$PackageName"
			$null = return $false  # Suppress return value output
		}
	} catch {
		$errorMsg = $_.Exception.Message
		$errorEntry = "❌ scoop | $PackageName | Exception: $errorMsg`n$($_.ScriptStackTrace)"
		$errorEntry | Out-File $errorLog -Append -Encoding utf8
		$script:updateSummary.Failed += "scoop: $PackageName"
		Write-ColorText "{Blue}[update] {Magenta}scoop: {Red}(error) {Gray}$PackageName {DarkGray}($errorMsg)"
		return $false
	}
}

# Main update logic
Write-ColorText "`n{Green}Starting application updates...`n"

# Load appList.json
$jsonPath = Join-Path $scriptRoot "appList.json"
if (!(Test-Path $jsonPath)) {
	Write-Error "appList.json not found at: $jsonPath"
	exit 1
}

$json = Get-Content $jsonPath -Raw | ConvertFrom-Json

# Process packages by manager (priority order: Winget > Choco > Scoop)
$managersToProcess = @()
if ($processWinget) { $managersToProcess += "Winget" }
if ($processChoco) { $managersToProcess += "Chocolatey" }
if ($processScoop) { $managersToProcess += "Scoop" }

if ($managersToProcess.Count -eq 0) {
	Write-ColorText "`n{Red}No package managers selected. Use -Winget, -Choco, or -Scoop to specify.`n"
	exit 1
}

Write-ColorText "`n{ Cyan}Processing packages by manager: $($managersToProcess -join ', ')...`n"

# Process Winget packages first (highest priority)
if ($processWinget -and $json.installSource.winget.autoInstall -eq $true) {
	# Check if Winget is installed
	if (Get-Command winget -ErrorAction SilentlyContinue) {
		Write-ColorText "`n{ Cyan}Processing Winget packages...`n"
		$wingetPkgs = $json.installSource.winget.packageList
		$wingetArgs = $json.installSource.winget.additionalArgs

		foreach ($pkg in $wingetPkgs) {
			$pkgId = $pkg.packageId
			$isInstalled = Test-WinGetInstalled -PackageID $pkgId
			if ($isInstalled) {
				$null = Update-WinGetPackage -PackageID $pkgId -AdditionalArgs $wingetArgs
			} else {
				$script:updateSummary.Skipped += "winget: $pkgId (not installed)"
			}
		}
	} else {
		Write-ColorText "`n{Yellow}[update] {Magenta}winget: {Gray}Winget is not installed. Skipping Winget packages.`n"
		$script:updateSummary.Skipped += "winget: all packages (winget not installed)"
	}
}

# Process Chocolatey packages
if ($processChoco -and $json.installSource.choco.autoInstall -eq $true) {
	# Check if Chocolatey is installed
	if (Get-Command choco -ErrorAction SilentlyContinue) {
		Write-ColorText "`n{ Cyan}Processing Chocolatey packages...`n"
		$chocoPkgs = $json.installSource.choco.packageList
		$chocoArgs = $json.installSource.choco.additionalArgs

		foreach ($pkg in $chocoPkgs) {
			$pkgName = $pkg.packageName
			$isInstalled = Test-ChocoInstalled -PackageName $pkgName
			if ($isInstalled) {
				$null = Update-ChocoPackage -PackageName $pkgName -AdditionalArgs $chocoArgs
			} else {
				$script:updateSummary.Skipped += "choco: $pkgName (not installed)"
				Write-ColorText "{Blue}[update] {Magenta}choco: {Yellow}(skipped) {Gray}$pkgName {DarkGray}(not installed)"
			}
		}
	} else {
		Write-ColorText "`n{Yellow}[update] {Magenta}choco: {Gray}Chocolatey is not installed. Skipping Chocolatey packages.`n"
		$script:updateSummary.Skipped += "choco: all packages (chocolatey not installed)"
	}
}

# Process Scoop packages
if ($processScoop -and $json.installSource.scoop.autoInstall -eq $true) {
	# Check if Scoop is installed
	if (Get-Command scoop -ErrorAction SilentlyContinue) {
		Write-ColorText "`n{ Cyan}Processing Scoop packages...`n"
		$scoopPkgs = $json.installSource.scoop.packageList
		$scoopArgs = $json.installSource.scoop.additionalArgs

		foreach ($pkg in $scoopPkgs) {
			$pkgName = $pkg.packageName
			$isInstalled = Test-ScoopInstalled -PackageName $pkgName
			if ($isInstalled) {
				$null = Update-ScoopPackage -PackageName $pkgName -AdditionalArgs $scoopArgs
			} else {
				$script:updateSummary.Skipped += "scoop: $pkgName (not installed)"
			}
		}
	} else {
		Write-ColorText "`n{Yellow}[update] {Magenta}scoop: {Gray}Scoop is not installed. Skipping Scoop packages.`n"
		$script:updateSummary.Skipped += "scoop: all packages (scoop not installed)"
	}
}

# Finalize logs
"`n========================================`n" | Out-File $successLog -Append -Encoding utf8
"Update Completed: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')`n" | Out-File $successLog -Append -Encoding utf8
"========================================`n" | Out-File $successLog -Append -Encoding utf8

"`n========================================`n" | Out-File $errorLog -Append -Encoding utf8
"Update Completed: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')`n" | Out-File $errorLog -Append -Encoding utf8
"========================================`n" | Out-File $errorLog -Append -Encoding utf8

# Display minimal summary
Write-ColorText "`n{ Cyan}========================================`n"
Write-ColorText "{ Cyan}Update Summary`n"
Write-ColorText "{ Cyan}========================================`n"

$updatedCount = $script:updateSummary.Updated.Count
$failedCount = $script:updateSummary.Failed.Count
$skippedCount = $script:updateSummary.Skipped.Count

Write-ColorText "{Green}✅ Updated: $updatedCount"
Write-ColorText "{Red}❌ Failed: $failedCount"
Write-ColorText "{Yellow}⏭️  Skipped: $skippedCount"

# Show skipped packages if any
if ($skippedCount -gt 0 -and $script:updateSummary.Skipped.Count -le 20) {
	Write-ColorText "`n{Yellow}Skipped packages:`n"
	$script:updateSummary.Skipped | ForEach-Object {
		Write-ColorText "{Gray}  • $_"
	}
} elseif ($skippedCount -gt 20) {
	Write-ColorText "`n{Yellow}Skipped packages: {Gray}(showing first 20 of $skippedCount)`n"
	$script:updateSummary.Skipped | Select-Object -First 20 | ForEach-Object {
		Write-ColorText "{Gray}  • $_"
	}
}

Write-ColorText "`n{ Cyan}Logs:`n"
Write-ColorText "{Gray}  Success: {Cyan}$successLog"
Write-ColorText "{Gray}  Errors: {Cyan}$errorLog"

Write-ColorText "`n{ Cyan}========================================`n"

# Exit with error code if any failures occurred
if ($failedCount -gt 0) {
	exit 1
} else {
	exit 0
}

