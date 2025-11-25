
<#PSScriptInfo

.VERSION 1.1.0

.GUID ccb5be4c-ea07-4c45-a5b4-6310df24e2bc

.AUTHOR jacquindev@outlook.com

.COMPANYNAME

.COPYRIGHT 2024 Jacquin Moon. All rights reserved.

.TAGS windots dotfiles

.LICENSEURI https://github.com/jacquindev/windots/blob/main/LICENSE

.PROJECTURI https://github.com/jacquindev/windots

.ICONURI

.EXTERNALMODULEDEPENDENCIES

.REQUIREDSCRIPTS

.EXTERNALSCRIPTDEPENDENCIES

.RELEASENOTES


.PRIVATEDATA

#>

#Requires -Version 7
#Requires -RunAsAdministrator

<#

.DESCRIPTION
	Setup script for Windows 11 Machine.

#>
Param(
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

$VerbosePreference = "SilentlyContinue"

# Validate skip parameters - only one can be used at a time
$skipParams = @($Packages, $PowerShell, $Git, $Symlinks, $Environment, $Addons, $VSCode, $Themes, $Miscellaneous, $Komorebi, $NerdFonts, $WSL)
$skipCount = ($skipParams | Where-Object { $_ -eq $true }).Count
if ($skipCount -gt 1) {
	Write-Error "Only one skip parameter can be used at a time. Please specify only one section to run."
	exit 1
}

# Determine which section to run (if any)
$runSection = $null
if ($Packages) { $runSection = "Packages" }
elseif ($PowerShell) { $runSection = "PowerShell" }
elseif ($Git) { $runSection = "Git" }
elseif ($Symlinks) { $runSection = "Symlinks" }
elseif ($Environment) { $runSection = "Environment" }
elseif ($Addons) { $runSection = "Addons" }
elseif ($VSCode) { $runSection = "VSCode" }
elseif ($Themes) { $runSection = "Themes" }
elseif ($Miscellaneous) { $runSection = "Miscellaneous" }
elseif ($Komorebi) { $runSection = "Komorebi" }
elseif ($NerdFonts) { $runSection = "NerdFonts" }
elseif ($WSL) { $runSection = "WSL" }

# Helper function to check if a section should run
function Should-RunSection {
	param([string]$SectionName)
	if ($null -eq $runSection) { return $true } # Full install
	return ($runSection -eq $SectionName)
}

# Tracking variables for summary
$script:setupSummary = @{
	Created = @()
	Updated = @()
	Exists  = @()
	Failed  = @()
	Skipped = @()
}

########################################################################################################################
###												  	HELPER FUNCTIONS												 ###
########################################################################################################################
function Write-TitleBox {
	param ([string]$Title, [string]$BorderChar = "*", [int]$Padding = 10)

	$Title = $Title.ToUpper()
	$titleLength = $Title.Length
	$boxWidth = $titleLength + ($Padding * 2) + 2

	$borderLine = $BorderChar * $boxWidth
	$paddingLine = $BorderChar + (" " * ($boxWidth - 2)) + $BorderChar
	$titleLine = $BorderChar + (" " * $Padding) + $Title + (" " * $Padding) + $BorderChar

	''
	Write-Host $borderLine -ForegroundColor Cyan
	Write-Host $paddingLine -ForegroundColor Cyan
	Write-Host $titleLine -ForegroundColor Cyan
	Write-Host $paddingLine -ForegroundColor Cyan
	Write-Host $borderLine -ForegroundColor Cyan
	''
}

# Source:
# - https://stackoverflow.com/questions/2688547/multiple-foreground-colors-in-powershell-in-one-command
function Write-ColorText {
	param ([string]$Text, [switch]$NoNewLine)

	$hostColor = $Host.UI.RawUI.ForegroundColor

	$Text.Split( [char]"{", [char]"}" ) | ForEach-Object { $i = 0; } {
		if ($i % 2 -eq 0) {	Write-Host $_ -NoNewline }
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

function Add-ScoopBucket {
	param ([string]$BucketName, [string]$BucketRepo)

	$scoopDir = (Get-Command scoop.ps1 -ErrorAction SilentlyContinue).Source | Split-Path | Split-Path
	if (!(Test-Path "$scoopDir\buckets\$BucketName" -PathType Container)) {
		if ($BucketRepo) {
			scoop bucket add $BucketName $BucketRepo
		} else {
			scoop bucket add $BucketName
		}
	} else {
		Write-ColorText "{Blue}[bucket] {Magenta}scoop: {Yellow}(exists) {Gray}$BucketName"
	}
}

function Install-ScoopApp {
	param ([string]$Package, [switch]$Global, [array]$AdditionalArgs)
	$scoopInfo = scoop info $Package
	$isInstalled = $scoopInfo.Installed
	if (!$isInstalled) {
		$scoopCmd = "scoop install $Package"
		if ($Global) { $scoopCmd += " -g" }
		if ($AdditionalArgs.Count -ge 1) {
			$AdditionalArgs = $AdditionalArgs -join ' '
			$scoopCmd += " $AdditionalArgs"
		}
		''; Invoke-Expression "$scoopCmd"; ''
	} elseif ($Force) {
		# Force reinstall
		$scoopCmd = "scoop uninstall $Package"
		if ($Global) { $scoopCmd += " -g" }
		Invoke-Expression "$scoopCmd >`$null 2>&1"
		$scoopCmd = "scoop install $Package"
		if ($Global) { $scoopCmd += " -g" }
		if ($AdditionalArgs.Count -ge 1) {
			$AdditionalArgs = $AdditionalArgs -join ' '
			$scoopCmd += " $AdditionalArgs"
		}
		''; Invoke-Expression "$scoopCmd"; ''
		Write-ColorText "{Blue}[package] {Magenta}scoop: {Green}(reinstalled) {Gray}$Package"
	} else {
		Write-ColorText "{Blue}[package] {Magenta}scoop: {Yellow}(exists) {Gray}$Package"
	}
}

function Install-WinGetApp {
	param ([string]$PackageID, [array]$AdditionalArgs, [string]$Source)

	winget list --exact -q $PackageID | Out-Null
	$isInstalled = $?
	if (!$isInstalled) {
		$wingetCmd = "winget install $PackageID"
		if ($AdditionalArgs.Count -ge 1) {
			$AdditionalArgs = $AdditionalArgs -join ' '
			$wingetCmd += " $AdditionalArgs"
		}
		if ($Source -eq "msstore") { $wingetCmd += " --source msstore" }
		else { $wingetCmd += " --source winget" }
		Invoke-Expression "$wingetCmd >`$null 2>&1"
		if ($LASTEXITCODE -eq 0) {
			Write-ColorText "{Blue}[package] {Magenta}winget: {Green}(success) {Gray}$PackageID"
		} else {
			Write-ColorText "{Blue}[package] {Magenta}winget: {Red}(failed) {Gray}$PackageID"
		}
	} elseif ($Force) {
		# Force reinstall
		$wingetCmd = "winget install $PackageID --force"
		if ($AdditionalArgs.Count -ge 1) {
			$AdditionalArgs = $AdditionalArgs -join ' '
			$wingetCmd += " $AdditionalArgs"
		}
		if ($Source -eq "msstore") { $wingetCmd += " --source msstore" }
		else { $wingetCmd += " --source winget" }
		Invoke-Expression "$wingetCmd >`$null 2>&1"
		if ($LASTEXITCODE -eq 0) {
			Write-ColorText "{Blue}[package] {Magenta}winget: {Green}(reinstalled) {Gray}$PackageID"
		} else {
			Write-ColorText "{Blue}[package] {Magenta}winget: {Red}(failed) {Gray}$PackageID"
		}
	} else {
		Write-ColorText "{Blue}[package] {Magenta}winget: {Yellow}(exists) {Gray}$PackageID"
	}
}

function Install-ChocoApp {
	param ([string]$Package, [string]$Version, [array]$AdditionalArgs)

	$chocoList = choco list $Package
	$isInstalled = $chocoList -notlike "0 packages installed."
	if (!$isInstalled) {
		$chocoCmd = "choco install $Package"
		if ($Version) {
			$pkgVer = "--version=$Version"
			$chocoCmd += " $pkgVer"
		}
		if ($AdditionalArgs.Count -ge 1) {
			$AdditionalArgs = $AdditionalArgs -join ' '
			$chocoCmd += " $AdditionalArgs"
		}
		Invoke-Expression "$chocoCmd >`$null 2>&1"
		if ($LASTEXITCODE -eq 0) {
			Write-ColorText "{Blue}[package] {Magenta}choco: {Green}(success) {Gray}$Package"
		} else {
			Write-ColorText "{Blue}[package] {Magenta}choco: {Red}(failed) {Gray}$Package"
		}
	} elseif ($Force) {
		# Force reinstall
		$chocoCmd = "choco install $Package --force"
		if ($Version) {
			$pkgVer = "--version=$Version"
			$chocoCmd += " $pkgVer"
		}
		if ($AdditionalArgs.Count -ge 1) {
			$AdditionalArgs = $AdditionalArgs -join ' '
			$chocoCmd += " $AdditionalArgs"
		}
		Invoke-Expression "$chocoCmd >`$null 2>&1"
		if ($LASTEXITCODE -eq 0) {
			Write-ColorText "{Blue}[package] {Magenta}choco: {Green}(reinstalled) {Gray}$Package"
		} else {
			Write-ColorText "{Blue}[package] {Magenta}choco: {Red}(failed) {Gray}$Package"
		}
	} else {
		Write-ColorText "{Blue}[package] {Magenta}choco: {Yellow}(exists) {Gray}$Package"
	}
}

function Initialize-PowerShellPrerequisites {
	Write-ColorText "{Blue}[prerequisite] {Magenta}pwsh: {Gray}Initializing PowerShell prerequisites..."

	# Enforce TLS 1.2 for secure connections to PowerShell Gallery
	try {
		[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
		Write-ColorText "{Blue}[prerequisite] {Magenta}pwsh: {Green}(success) {Gray}TLS 1.2 enforced"
	} catch {
		Write-ColorText "{Blue}[prerequisite] {Magenta}pwsh: {Yellow}(warning) {Gray}Could not enforce TLS 1.2: $_"
	}

	# Register and trust PSGallery repository
	try {
		$psGallery = Get-PSRepository -Name PSGallery -ErrorAction SilentlyContinue
		if (!$psGallery) {
			Register-PSRepository -Default -ErrorAction Stop
			Write-ColorText "{Blue}[prerequisite] {Magenta}pwsh: {Green}(success) {Gray}PSGallery repository registered"
		} else {
			Write-ColorText "{Blue}[prerequisite] {Magenta}pwsh: {Yellow}(exists) {Gray}PSGallery repository"
		}

		# Set PSGallery as trusted
		if ($psGallery.InstallationPolicy -ne 'Trusted') {
			Set-PSRepository -Name PSGallery -InstallationPolicy Trusted -ErrorAction Stop
			Write-ColorText "{Blue}[prerequisite] {Magenta}pwsh: {Green}(success) {Gray}PSGallery set as trusted"
		}
	} catch {
		Write-ColorText "{Blue}[prerequisite] {Magenta}pwsh: {Red}(failed) {Gray}PSGallery configuration: $_"
		$script:setupSummary.Failed += "PowerShell Prerequisite: PSGallery configuration"
	}

	# Install/Update NuGet provider (required for module installation)
	try {
		$nugetProvider = Get-PackageProvider -Name NuGet -ListAvailable -ErrorAction SilentlyContinue | 
			Where-Object { [version]$_.Version -ge [version]"2.8.5.201" } | 
			Sort-Object Version -Descending | 
			Select-Object -First 1

		if (!$nugetProvider) {
			Write-ColorText "{Blue}[prerequisite] {Magenta}pwsh: {Gray}Installing NuGet provider (minimum 2.8.5.201)..."
			Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force -Scope CurrentUser -ErrorAction Stop | Out-Null
			Write-ColorText "{Blue}[prerequisite] {Magenta}pwsh: {Green}(success) {Gray}NuGet provider installed"
		} else {
			Write-ColorText "{Blue}[prerequisite] {Magenta}pwsh: {Yellow}(exists) {Gray}NuGet provider $($nugetProvider.Version)"
		}
	} catch {
		Write-ColorText "{Blue}[prerequisite] {Magenta}pwsh: {Red}(failed) {Gray}NuGet provider installation: $_"
		$script:setupSummary.Failed += "PowerShell Prerequisite: NuGet provider"
	}

	# Update PackageManagement and PowerShellGet modules if needed
	try {
		Write-ColorText "{Blue}[prerequisite] {Magenta}pwsh: {Gray}Checking PackageManagement module..."
		$packageMgmt = Get-Module -ListAvailable -Name PackageManagement | Sort-Object Version -Descending | Select-Object -First 1
		if ($packageMgmt) {
			Write-ColorText "{Blue}[prerequisite] {Magenta}pwsh: {Yellow}(exists) {Gray}PackageManagement $($packageMgmt.Version)"
		} else {
			Write-ColorText "{Blue}[prerequisite] {Magenta}pwsh: {Gray}Installing PackageManagement module..."
			Install-Module -Name PackageManagement -Force -Scope CurrentUser -AllowClobber -SkipPublisherCheck -ErrorAction Stop | Out-Null
			Write-ColorText "{Blue}[prerequisite] {Magenta}pwsh: {Green}(success) {Gray}PackageManagement installed"
		}
	} catch {
		Write-ColorText "{Blue}[prerequisite] {Magenta}pwsh: {Yellow}(warning) {Gray}PackageManagement update: $_"
	}

	try {
		Write-ColorText "{Blue}[prerequisite] {Magenta}pwsh: {Gray}Checking PowerShellGet module..."
		$psGet = Get-Module -ListAvailable -Name PowerShellGet | Sort-Object Version -Descending | Select-Object -First 1
		if ($psGet) {
			Write-ColorText "{Blue}[prerequisite] {Magenta}pwsh: {Yellow}(exists) {Gray}PowerShellGet $($psGet.Version)"
		} else {
			Write-ColorText "{Blue}[prerequisite] {Magenta}pwsh: {Gray}Installing PowerShellGet module..."
			Install-Module -Name PowerShellGet -Force -Scope CurrentUser -AllowClobber -SkipPublisherCheck -ErrorAction Stop | Out-Null
			Write-ColorText "{Blue}[prerequisite] {Magenta}pwsh: {Green}(success) {Gray}PowerShellGet installed"
		}
	} catch {
		Write-ColorText "{Blue}[prerequisite] {Magenta}pwsh: {Yellow}(warning) {Gray}PowerShellGet update: $_"
	}

	# Import PackageManagement and PowerShellGet to ensure they're available
	try {
		Import-PackageProvider -Name NuGet -Force -ErrorAction SilentlyContinue | Out-Null
		Import-Module PackageManagement -Force -ErrorAction SilentlyContinue | Out-Null
		Import-Module PowerShellGet -Force -ErrorAction SilentlyContinue | Out-Null
	} catch {
		Write-ColorText "{Blue}[prerequisite] {Magenta}pwsh: {Yellow}(warning) {Gray}Module import: $_"
	}

	''
}

function Install-PowerShellModule {
	param ([string]$Module, [string]$Version, [array]$AdditionalArgs)

	$moduleInstalled = Get-InstalledModule -Name $Module -ErrorAction SilentlyContinue
	if (!$moduleInstalled) {
		try {
			$installParams = @{
				Name = $Module
				Scope = 'CurrentUser'
				Force = $true
				AllowClobber = $true
				SkipPublisherCheck = $true
				ErrorAction = 'Stop'
			}

			if ($null -ne $Version) {
				$installParams['RequiredVersion'] = $Version
			}

			# Add additional arguments if provided
			if ($AdditionalArgs.Count -ge 1) {
				# Parse additional args and add to installParams
				for ($i = 0; $i -lt $AdditionalArgs.Count; $i++) {
					if ($AdditionalArgs[$i] -match '^-') {
						$paramName = $AdditionalArgs[$i].TrimStart('-')
						if ($i + 1 -lt $AdditionalArgs.Count -and $AdditionalArgs[$i + 1] -notmatch '^-') {
							$paramValue = $AdditionalArgs[$i + 1]
							$installParams[$paramName] = $paramValue
							$i++
						} else {
							$installParams[$paramName] = $true
						}
					}
				}
			}

			Install-Module @installParams
			
			# Verify installation
			$verifyModule = Get-InstalledModule -Name $Module -ErrorAction SilentlyContinue
			if ($verifyModule) {
				Write-ColorText "{Blue}[module] {Magenta}pwsh: {Green}(success) {Gray}$Module"
			} else {
				throw "Module installation completed but verification failed"
			}
		} catch {
			Write-ColorText "{Blue}[module] {Magenta}pwsh: {Red}(failed) {Gray}$Module {DarkGray}Error: $_"
			$script:setupSummary.Failed += "PowerShell Module: $Module"
		}
	} elseif ($Force) {
		# Force reinstall
		try {
			$installParams = @{
				Name = $Module
				Scope = 'CurrentUser'
				Force = $true
				AllowClobber = $true
				SkipPublisherCheck = $true
				ErrorAction = 'Stop'
			}

			if ($null -ne $Version) {
				$installParams['RequiredVersion'] = $Version
			}

			# Add additional arguments if provided
			if ($AdditionalArgs.Count -ge 1) {
				for ($i = 0; $i -lt $AdditionalArgs.Count; $i++) {
					if ($AdditionalArgs[$i] -match '^-') {
						$paramName = $AdditionalArgs[$i].TrimStart('-')
						if ($i + 1 -lt $AdditionalArgs.Count -and $AdditionalArgs[$i + 1] -notmatch '^-') {
							$paramValue = $AdditionalArgs[$i + 1]
							$installParams[$paramName] = $paramValue
							$i++
						} else {
							$installParams[$paramName] = $true
						}
					}
				}
			}

			Install-Module @installParams
			
			# Verify installation
			$verifyModule = Get-InstalledModule -Name $Module -ErrorAction SilentlyContinue
			if ($verifyModule) {
				Write-ColorText "{Blue}[module] {Magenta}pwsh: {Green}(reinstalled) {Gray}$Module"
			} else {
				throw "Module reinstallation completed but verification failed"
			}
		} catch {
			Write-ColorText "{Blue}[module] {Magenta}pwsh: {Red}(failed) {Gray}$Module {DarkGray}Error: $_"
			$script:setupSummary.Failed += "PowerShell Module: $Module"
		}
	} else {
		Write-ColorText "{Blue}[module] {Magenta}pwsh: {Yellow}(exists) {Gray}$Module"
	}
}

function Install-AppFromGitHub {
	param ([string]$RepoName, [string]$FileName)

	$release = "https://api.github.com/repos/$RepoName/releases"
	$tag = (Invoke-WebRequest $release | ConvertFrom-Json)[0].tag_name
	$downloadUrl = "https://github.com/$RepoName/releases/download/$tag/$FileName"
	$downloadPath = (New-Object -ComObject Shell.Application).NameSpace('shell:Downloads').Self.Path
	$downloadFile = "$downloadPath\$FileName"
	(New-Object System.Net.WebClient).DownloadFile($downloadUrl, $downloadFile)

	switch ($FileName.Split('.') | Select-Object -Last 1) {
		"exe" {
			Start-Process -FilePath "$downloadFile" -Wait
		}
		"msi" {
			Start-Process -FilePath "$downloadFile" -Wait
		}
		"zip" {
			$dest = "$downloadPath\$($FileName.Split('.'))"
			Expand-Archive -Path "$downloadFile" -DestinationPath "$dest"
		}
		"7z" {
			7z x -o"$downloadPath" -y "$downloadFile" | Out-Null
		}
		Default { break }
	}
	Remove-Item "$downloadFile" -Force -Recurse -ErrorAction SilentlyContinue
}

function Install-OnlineFile {
	param ([string]$OutputDir, [string]$Url)
	Invoke-WebRequest -Uri $Url -OutFile $OutputDir
}

function Refresh ([int]$Time) {
	if (Get-Command choco -ErrorAction SilentlyContinue) {

		switch -regex ($Time.ToString()) {
			'1(1|2|3)$' { $suffix = 'th'; break }
			'.?1$' { $suffix = 'st'; break }
			'.?2$' { $suffix = 'nd'; break }
			'.?3$' { $suffix = 'rd'; break }
			default { $suffix = 'th'; break }
		}

		if (!(Get-Module -ListAvailable -Name "chocoProfile" -ErrorAction SilentlyContinue)) {
			$chocoModule = "C:\ProgramData\chocolatey\helpers\chocolateyProfile.psm1"
			if (Test-Path $chocoModule -PathType Leaf) {
				Import-Module $chocoModule
			}
		}
		Write-Verbose -Message "Refreshing environment variables from registry ($Time$suffix attempt)"
		refreshenv | Out-Null
	}
}

function Write-LockFile {
	param (
		[ValidateSet('winget', 'choco', 'scoop', 'modules')]
		[Alias('s', 'p')][string]$PackageSource,
		[Alias('f')][string]$FileName,
		[Alias('o')][string]$OutputPath = "$PSScriptRoot\out"
	)

	$dest = "$OutputPath\$FileName"

	switch ($PackageSource) {
		"winget" {
			if (!(Get-Command winget -ErrorAction SilentlyContinue)) { return }
			winget export -o $dest | Out-Null
			if ($LASTEXITCODE -eq 0) {
				Write-ColorText "`n✔️  Packages installed by {Green}$PackageSource {Gray}are exported at {Red}$((Resolve-Path $dest).Path)"
			}
			Start-Sleep -Seconds 1
		}
		"choco" {
			if (!(Get-Command choco -ErrorAction SilentlyContinue)) { return }
			choco export $dest | Out-Null
			if ($LASTEXITCODE -eq 0) {
				Write-ColorText "`n✔️  Packages installed by {Green}$PackageSource {Gray}are exported at {Red}$((Resolve-Path $dest).Path)"
			}
			Start-Sleep -Seconds 1
		}
		"scoop" {
			if (!(Get-Command scoop -ErrorAction SilentlyContinue)) { return }
			scoop export -c > $dest
			if ($LASTEXITCODE -eq 0) {
				Write-ColorText "`n✔️  Packages installed by {Green}$PackageSource {Gray}are exported at {Red}$((Resolve-Path $dest).Path)"
			}
			Start-Sleep -Seconds 1
		}
		"modules" {
			Get-InstalledModule | Select-Object -Property Name, Version | ConvertTo-Json -Depth 100 | Out-File $dest
			if ($LASTEXITCODE -eq 0) {
				Write-ColorText "`n✔️  {Green}PowerShell Modules {Gray}installed are exported at {Red}$((Resolve-Path $dest).Path)"
			}
			Start-Sleep -Seconds 1
		}
	}
}

function New-SymbolicLinks {
	param (
		[string]$Source,
		[string]$Destination,
		[switch]$Recurse
	)

	if (!(Test-Path $Source)) {
		Write-ColorText "{Yellow}[symlink] {Gray}Source path does not exist: $Source"
		$script:setupSummary.Skipped += "Symlinks from $Source (source not found)"
		return
	}

	Get-ChildItem $Source -Recurse:$Recurse | Where-Object { !$_.PSIsContainer } | ForEach-Object {
		$destinationPath = $_.FullName -replace [regex]::Escape($Source), $Destination
		$destinationDir = Split-Path $destinationPath

		# Create destination directory if it doesn't exist
		if (!(Test-Path $destinationDir)) {
			New-Item $destinationDir -ItemType Directory -Force -ErrorAction SilentlyContinue | Out-Null
		}

		# Check if destination already exists
		if (Test-Path $destinationPath) {
			$existingItem = Get-Item $destinationPath -ErrorAction SilentlyContinue
			if ($existingItem.LinkType -eq 'SymbolicLink') {
				# Already a symlink, check if it points to the right target
				$targetPath = (Get-Item $destinationPath).Target
				if ($targetPath -ne $_.FullName) {
					# Wrong target, update it
					Remove-Item $destinationPath -Force -ErrorAction SilentlyContinue
					New-Item -ItemType SymbolicLink -Path $destinationPath -Target $($_.FullName) -Force -ErrorAction SilentlyContinue | Out-Null
					$script:setupSummary.Updated += $destinationPath
					Write-ColorText "{Blue}[symlink] {Yellow}(updated) {Green}$($_.FullName) {Yellow}--> {Gray}$destinationPath"
				} else {
					# Correct target, skip
					$script:setupSummary.Exists += $destinationPath
					Write-ColorText "{Blue}[symlink] {Yellow}(exists) {Gray}$destinationPath"
				}
			} else {
				# Existing file/directory that's not a symlink - backup and replace
				if ($Force) {
					$backupPath = "$destinationPath.backup.$(Get-Date -Format 'yyyyMMdd-HHmmss')"
					Write-ColorText "{Yellow}[symlink] {Gray}Backing up existing file: $backupPath"
					Copy-Item $destinationPath $backupPath -Force -ErrorAction SilentlyContinue
					Remove-Item $destinationPath -Force -ErrorAction SilentlyContinue
					New-Item -ItemType SymbolicLink -Path $destinationPath -Target $($_.FullName) -Force -ErrorAction SilentlyContinue | Out-Null
					$script:setupSummary.Updated += $destinationPath
					Write-ColorText "{Blue}[symlink] {Green}(created) {Green}$($_.FullName) {Yellow}--> {Gray}$destinationPath"
				} else {
					$script:setupSummary.Skipped += "$destinationPath (exists as regular file, use -Force to replace)"
					Write-ColorText "{Yellow}[symlink] {Gray}Skipped $destinationPath (exists, use -Force to replace)"
				}
			}
		} else {
			# Destination doesn't exist, create symlink
			New-Item -ItemType SymbolicLink -Path $destinationPath -Target $($_.FullName) -Force -ErrorAction SilentlyContinue | Out-Null
			$script:setupSummary.Created += $destinationPath
			Write-ColorText "{Blue}[symlink] {Green}(created) {Green}$($_.FullName) {Yellow}--> {Gray}$destinationPath"
		}
	}
}

function Copy-ConfigFiles {
	param (
		[string]$Source,
		[string]$Destination,
		[switch]$Recurse
	)

	if (!(Test-Path $Source)) {
		Write-ColorText "{Yellow}[copy] {Gray}Source path does not exist: $Source"
		$script:setupSummary.Skipped += "Copy from $Source (source not found)"
		return
	}

	# Get all items (files and directories) from source
	Get-ChildItem $Source -Recurse:$Recurse | ForEach-Object {
		$destinationPath = $_.FullName -replace [regex]::Escape($Source), $Destination
		$destinationDir = Split-Path $destinationPath

		# Create destination directory if it doesn't exist
		if (!(Test-Path $destinationDir)) {
			New-Item $destinationDir -ItemType Directory -Force -ErrorAction SilentlyContinue | Out-Null
		}

		if ($_.PSIsContainer) {
			# For directories, ensure they exist
			if (!(Test-Path $destinationPath)) {
				New-Item $destinationPath -ItemType Directory -Force -ErrorAction SilentlyContinue | Out-Null
				$script:setupSummary.Created += "$destinationPath\"
			} else {
				$script:setupSummary.Exists += "$destinationPath\"
			}
		} else {
			# For files, check if they need to be copied/updated
			if (Test-Path $destinationPath) {
				# Check if file content differs
				$sourceHash = (Get-FileHash $_.FullName -ErrorAction SilentlyContinue).Hash
				$destHash = (Get-FileHash $destinationPath -ErrorAction SilentlyContinue).Hash

				if ($sourceHash -ne $destHash) {
					# Files differ, backup and update
					if ($Force) {
						$backupPath = "$destinationPath.backup.$(Get-Date -Format 'yyyyMMdd-HHmmss')"
						Copy-Item $destinationPath $backupPath -Force -ErrorAction SilentlyContinue
						Copy-Item $_.FullName $destinationPath -Force -ErrorAction SilentlyContinue
						$script:setupSummary.Updated += $destinationPath
						Write-ColorText "{Blue}[copy] {Yellow}(updated) {Green}$($_.FullName) {Yellow}--> {Gray}$destinationPath"
					} else {
						$script:setupSummary.Skipped += "$destinationPath (exists, use -Force to update)"
						Write-ColorText "{Yellow}[copy] {Gray}Skipped $destinationPath (exists, use -Force to update)"
					}
				} else {
					# Files are identical, skip
					$script:setupSummary.Exists += $destinationPath
					Write-ColorText "{Blue}[copy] {Yellow}(exists) {Gray}$destinationPath"
				}
			} else {
				# Destination doesn't exist, copy file
				Copy-Item $_.FullName $destinationPath -Force -ErrorAction SilentlyContinue
				$script:setupSummary.Created += $destinationPath
				Write-ColorText "{Blue}[copy] {Green}(created) {Green}$($_.FullName) {Yellow}--> {Gray}$destinationPath"
			}
		}
	}
}

########################################################################
###														MAIN SCRIPT 		  					 			 		 ###
########################################################################
# if not internet connection, then we will exit this script immediately
$internetConnection = Test-NetConnection google.com -CommonTCPPort HTTP -InformationLevel Detailed -WarningAction SilentlyContinue
$internetAvailable = $internetConnection.TcpTestSucceeded
if ($internetAvailable -eq $False) {
	Write-Warning "NO INTERNET CONNECTION AVAILABLE!"
	Write-Host "Please check your internet connection and re-run this script.`n"
	for ($countdown = 3; $countdown -ge 0; $countdown--) {
		Write-ColorText "`r{DarkGray}Automatically exit this script in {Blue}$countdown second(s){DarkGray}..." -NoNewLine
		Start-Sleep -Seconds 1
	}
	exit
}

Write-Progress -Completed; Clear-Host

Write-ColorText "`n✅ {Green}Internet Connection available.`n`n{DarkGray}Start running setup process..."
Start-Sleep -Seconds 3

# set current working directory location
$currentLocation = "$($(Get-Location).Path)"

Set-Location $PSScriptRoot
[System.Environment]::CurrentDirectory = $PSScriptRoot

$i = 1

######################################################################
###													NERD FONTS														 ###
######################################################################
if (Should-RunSection "NerdFonts") {
	# install nerd fonts
	Write-TitleBox -Title "Nerd Fonts Installation"
	if ($Force) {
		Write-ColorText "{Yellow}Force mode: Reinstalling Nerd Fonts..."
		& ([scriptblock]::Create((Invoke-WebRequest 'https://to.loredo.me/Install-NerdFont.ps1'))) -Scope AllUsers -Confirm:$False
	} else {
		Write-ColorText "{Green}The following fonts are highly recommended:`n{DarkGray}(Please skip this step if you already installed Nerd Fonts)`n`n  {Gray}● Cascadia Code Nerd Font`n  ● FantasqueSansM Nerd Font`n  ● FiraCode Nerd Font`n  ● JetBrainsMono Nerd Font`n"

		for ($count = 5; $count -ge 0; $count--) {
			Write-ColorText "`r{Magenta}Install Nerd Fonts now? [y/N]: {DarkGray}(Exit in {Blue}$count {DarkGray}seconds) {Gray}" -NoNewLine

			if ([System.Console]::KeyAvailable) {
				$key = [System.Console]::ReadKey($false)
				if ($key.Key -ne 'Y') {
					Write-ColorText "`r{DarkGray}Skipped installing Nerd Fonts...                                                                 "
					break
				} else {
					& ([scriptblock]::Create((Invoke-WebRequest 'https://to.loredo.me/Install-NerdFont.ps1'))) -Scope AllUsers -Confirm:$False
					break
				}
			}
			Start-Sleep -Seconds 1
		}
	}
	Refresh ($i++)
}

Clear-Host

# Retrieve information from json file (needed for multiple sections)
$json = Get-Content "$PSScriptRoot\appList.json" -Raw | ConvertFrom-Json

########################################################################
###													PACKAGES (WINGET, CHOCOLATEY, SCOOP) 			 									 ###
########################################################################
if (Should-RunSection "Packages") {
	# Winget Packages
	Write-TitleBox -Title "WinGet Packages Installation"
$wingetItem = $json.installSource.winget
$wingetPkgs = $wingetItem.packageList
$wingetArgs = $wingetItem.additionalArgs
$wingetInstall = $wingetItem.autoInstall

if ($wingetInstall -eq $True) {
	if (!(Get-Command winget -ErrorAction SilentlyContinue)) {
		# Use external script to install WinGet and all of its requirements
		# Source: - https://github.com/asheroto/winget-install
		Write-Verbose -Message "Installing winget-cli"
		&([ScriptBlock]::Create((Invoke-RestMethod asheroto.com/winget))) -Force
	}

	# Configure winget settings for BETTER PERFORMANCE
	# Check if settings file exists and compare content before overwriting
	$settingsPath = "$env:LOCALAPPDATA\Packages\Microsoft.DesktopAppInstaller_8wekyb3d8bbwe\LocalState\settings.json"
	$settingsJson = @'
{
		"$schema": "https://aka.ms/winget-settings.schema.json",

		// For documentation on these settings, see: https://aka.ms/winget-settings
		// "source": {
		//    "autoUpdateIntervalInMinutes": 5
		// },
		"visual": {
				"enableSixels": true,
				"progressBar": "rainbow"
		},
		"telemetry": {
				"disable": true
		},
		"experimentalFeatures": {
				"configuration03": true,
				"configureExport": true,
				"configureSelfElevate": true,
				"experimentalCMD": true
		},
		"network": {
				"downloader": "wininet"
		}
}
'@
	# Normalize JSON for comparison (remove comments and whitespace differences)
	$normalizeJson = {
		param($json)
		# Remove single-line comments
		$json = $json -replace '//.*', ''
		# Remove multi-line comments (basic)
		$json = $json -replace '/\*.*?\*/', ''
		# Remove extra whitespace
		$json = ($json -split "`n" | Where-Object { $_.Trim() -ne '' }) -join "`n"
		return $json.Trim()
	}

	if ($Force -or !(Test-Path $settingsPath)) {
		# Create directory if it doesn't exist
		$settingsDir = Split-Path $settingsPath
		if (!(Test-Path $settingsDir)) {
			New-Item $settingsDir -ItemType Directory -Force -ErrorAction SilentlyContinue | Out-Null
		}
		$settingsJson | Out-File $settingsPath -Encoding utf8
		$script:setupSummary.Created += "WinGet settings"
		Write-ColorText "{Blue}[config] {Green}(created) {Gray}WinGet settings"
	} else {
		$existingContent = Get-Content $settingsPath -Raw -ErrorAction SilentlyContinue
		$normalizedExisting = & $normalizeJson $existingContent
		$normalizedNew = & $normalizeJson $settingsJson

		if ($normalizedExisting -ne $normalizedNew) {
			# Backup existing settings
			$backupPath = "$settingsPath.backup.$(Get-Date -Format 'yyyyMMdd-HHmmss')"
			Copy-Item $settingsPath $backupPath -Force -ErrorAction SilentlyContinue
			$settingsJson | Out-File $settingsPath -Encoding utf8
			$script:setupSummary.Updated += "WinGet settings"
			Write-ColorText "{Blue}[config] {Yellow}(updated) {Gray}WinGet settings {DarkGray}(backup: $backupPath)"
		} else {
			$script:setupSummary.Exists += "WinGet settings"
			Write-ColorText "{Blue}[config] {Yellow}(exists) {Gray}WinGet settings"
		}
	}

	# Download packages from WinGet
	foreach ($pkg in $wingetPkgs) {
		$pkgId = $pkg.packageId
		$pkgSource = $pkg.packageSource
		if ($null -ne $pkgSource) {
			Install-WinGetApp -PackageID $pkgId -AdditionalArgs $wingetArgs -Source $pkgSource
		} else {
			Install-WinGetApp -PackageID $pkgId -AdditionalArgs $wingetArgs
		}
	}
	Write-LockFile -PackageSource winget -FileName wingetfile.json
	Refresh ($i++)
}

############################################################################
###														CHOCOLATEY PACKAGES 				   						 ###
############################################################################
# Chocolatey Packages
Write-TitleBox -Title "Chocolatey Packages Installation"
$chocoItem = $json.installSource.choco
$chocoPkgs = $chocoItem.packageList
$chocoArgs = $chocoItem.additionalArgs
$chocoInstall = $chocoItem.autoInstall

if ($chocoInstall -eq $True) {
	if (!(Get-Command choco -ErrorAction SilentlyContinue)) {
		# Install chocolatey
		# Source: - https://chocolatey.org/install
		Write-Verbose -Message "Installing chocolatey"
		if ((Get-ExecutionPolicy) -eq "Restricted") { Set-ExecutionPolicy AllSigned }
		Set-ExecutionPolicy Bypass -Scope Process -Force
		[System.Net.ServicePointManager]::SecurityProtocol = [System.Net.ServicePointManager]::SecurityProtocol -bor 3072
		Invoke-Expression ((New-Object System.Net.WebClient).DownloadString('https://community.chocolatey.org/install.ps1'))
	}

	foreach ($pkg in $chocoPkgs) {
		$chocoPkg = $pkg.packageName
		$chocoVer = $pkg.packageVersion
		if ($null -ne $chocoVer) {
			Install-ChocoApp -Package $chocoPkg -Version $chocoVer -AdditionalArgs $chocoArgs
		} else {
			Install-ChocoApp -Package $chocoPkg -AdditionalArgs $chocoArgs
		}
	}
	Write-LockFile -PackageSource choco -FileName chocolatey.config -OutputPath "$PSScriptRoot\out"
	Refresh ($i++)
}

########################################################################
###														SCOOP PACKAGES 	 							 				 ###
########################################################################
# Scoop Packages
Write-TitleBox -Title "Scoop Packages Installation"
$scoopItem = $json.installSource.scoop
$scoopBuckets = $scoopItem.bucketList
$scoopPkgs = $scoopItem.packageList
$scoopArgs = $scoopItem.additionalArgs
$scoopInstall = $scoopItem.autoInstall

if ($scoopInstall -eq $True) {
	if (!(Get-Command scoop -ErrorAction SilentlyContinue)) {
		# `scoop` is recommended to be installed from a non-administrative
		# PowerShell terminal. However, since we are in administrative shell,
		# it is required to invoke the installer with the `-RunAsAdmin` parameter.

		# Source: - https://github.com/ScoopInstaller/Install#for-admin
		Write-Verbose -Message "Installing scoop"
		Invoke-Expression "& {$(Invoke-RestMethod get.scoop.sh)} -RunAsAdmin"
	}

	# Configure aria2
	if (!(Get-Command aria2c -ErrorAction SilentlyContinue)) { scoop install aria2 }
	if (!($(scoop config aria2-enabled) -eq $True)) { scoop config aria2-enabled true }
	if (!($(scoop config aria2-warning-enabled) -eq $False)) { scoop config aria2-warning-enabled false }

	# Create a scheduled task for aria2 so that it will always be active when we logon the machine
	# Idea is from: - https://gist.github.com/mikepruett3/7ca6518051383ee14f9cf8ae63ba18a7
	if (!(Get-ScheduledTaskInfo -TaskName "Aria2RPC" -ErrorAction Ignore)) {
		try {
			$scoopDir = (Get-Command scoop.ps1 -ErrorAction SilentlyContinue).Source | Split-Path | Split-Path
			$Action = New-ScheduledTaskAction -Execute "$scoopDir\apps\aria2\current\aria2c.exe" -Argument "--enable-rpc --rpc-listen-all" -WorkingDirectory "$Env:USERPROFILE\Downloads"
			$Trigger = New-ScheduledTaskTrigger -AtStartup
			$Principal = New-ScheduledTaskPrincipal -UserID "$Env:USERDOMAIN\$Env:USERNAME" -LogonType S4U
			$Settings = New-ScheduledTaskSettingsSet -ExecutionTimeLimit 0 -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries
			Register-ScheduledTask -TaskName "Aria2RPC" -Action $Action -Trigger $Trigger -Principal $Principal -Settings $Settings | Out-Null
		} catch {
			Write-Error "An error occurred: $_"
		}
	}

	# Add scoop buckets
	foreach ($bucket in $scoopBuckets) {
		$bucketName = $bucket.bucketName
		$bucketRepo = $bucket.bucketRepo
		if ($null -ne $bucketRepo) {
			Add-ScoopBucket -BucketName $bucketName -BucketRepo $bucketRepo
		} else {
			Add-ScoopBucket -BucketName $bucketName
		}
	}

	''

	# Install applications from scoop
	foreach ($pkg in $scoopPkgs) {
		$pkgName = $pkg.packageName
		$pkgScope = $pkg.packageScope
		if (($null -ne $pkgScope) -and ($pkgScope -eq "global")) { $Global = $True } else { $Global = $False }
		if ($null -ne $scoopArgs) {
			Install-ScoopApp -Package $pkgName -Global:$Global -AdditionalArgs $scoopArgs
		} else {
			Install-ScoopApp -Package $pkgName -Global:$Global
		}
	}
	Write-LockFile -PackageSource scoop -FileName scoopfile.json
	Refresh ($i++)
}
}

########################################################################
###												 	POWERSHELL SETUP 												 ###
########################################################################
if (Should-RunSection "PowerShell") {
	# Powershell Modules
	Write-TitleBox -Title "PowerShell Modules + Experimental Features"

	# Initialize prerequisites (TLS, PSGallery, NuGet provider, etc.)
	Initialize-PowerShellPrerequisites

# Install modules if not installed yet
$moduleItem = $json.powershell.psmodule
$moduleList = $moduleItem.moduleList
$moduleArgs = $moduleItem.additionalArgs
$moduleInstall = $moduleItem.install
if ($moduleInstall -eq $True) {
	foreach ($module in $moduleList) {
		$mName = $module.moduleName
		$mVersion = $module.moduleVersion
		if ($null -ne $mVersion) {
			Install-PowerShellModule -Module $mName -Version $mVersion -AdditionalArgs $moduleArgs
		} else {
			Install-PowerShellModule -Module $mName -AdditionalArgs $moduleArgs
		}
	}
	Write-LockFile -PackageSource modules -FileName modules.json
	Refresh ($i++)
}

# Install PowerShell modules required by Profile.ps1
Write-ColorText "{Blue}[module] {Magenta}pwsh: {Gray}Installing profile-required modules..."
$profileRequiredModules = @(
	"BurntToast",
	"Microsoft.PowerShell.SecretManagement",
	"Microsoft.PowerShell.SecretStore",
	"PSScriptTools",
	"PSFzf",
	"CompletionPredictor"
)

foreach ($module in $profileRequiredModules) {
	$moduleInstalled = Get-Module -ListAvailable -Name $module -ErrorAction SilentlyContinue
	if ($Force -or !$moduleInstalled) {
		try {
			Install-Module -Name $module -Scope CurrentUser -Force -AllowClobber -SkipPublisherCheck -ErrorAction Stop
			Write-ColorText "{Blue}[module] {Magenta}pwsh: {Green}(success) {Gray}$module"
		} catch {
			Write-ColorText "{Blue}[module] {Magenta}pwsh: {Red}(failed) {Gray}$module {DarkGray}Error: $_"
			$script:setupSummary.Failed += "PowerShell Module: $module"
		}
	} else {
		Write-ColorText "{Blue}[module] {Magenta}pwsh: {Yellow}(exists) {Gray}$module"
	}
}
Refresh ($i++)

# Enable powershell experimental features
$feature = $json.powershell.psexperimentalfeature
$featureEnable = $feature.enable
$featureList = $feature.featureList

if ($featureEnable -eq $True) {
	if (!(Get-Command Get-ExperimentalFeature -ErrorAction SilentlyContinue)) { return }

	''
	foreach ($f in $featureList) {
		$featureExists = Get-ExperimentalFeature -Name $f -ErrorAction SilentlyContinue
		if ($Force -or ($featureExists -and ($featureExists.Enabled -eq $False))) {
			Enable-ExperimentalFeature -Name $f -Scope CurrentUser -ErrorAction SilentlyContinue
			if ($LASTEXITCODE -eq 0) {
				Write-ColorText "{Blue}[experimental feature] {Magenta}pwsh: {Green}(success) {Gray}$f"
			} else {
				Write-ColorText "{Blue}[experimental feature] {Magenta}pwsh: {Red}(failed) {Gray}$f"
			}
		} else {
			Write-ColorText "{Blue}[experimental feature] {Magenta}pwsh: {Yellow}(enabled) {Gray}$f"
		}
	}

	Refresh ($i++)
}
}

######################################################################
###														GIT SETUP											    	 ###
######################################################################
if (Should-RunSection "Git") {
	# Configure git
	Write-TitleBox -Title "SETUP GIT FOR WINDOWS"
	if (Get-Command git -ErrorAction SilentlyContinue) {
		$gitUserName = (git config user.name)
		$gitUserMail = (git config user.email)

		if ($Force -or $null -eq $gitUserName) {
			if ($Force -and $null -ne $gitUserName) {
				Write-ColorText "{Yellow}Force mode: Re-prompting for git name..."
			}
			$gitUserName = $(Write-Host "Input your git name: " -NoNewline -ForegroundColor Magenta; Read-Host)
		} else {
			Write-ColorText "{Blue}[user.name]  {Magenta}git: {Yellow}(already set) {Gray}$gitUserName"
		}
		if ($Force -or $null -eq $gitUserMail) {
			if ($Force -and $null -ne $gitUserMail) {
				Write-ColorText "{Yellow}Force mode: Re-prompting for git email..."
			}
			$gitUserMail = $(Write-Host "Input your git email: " -NoNewline -ForegroundColor Magenta; Read-Host)
		} else {
			Write-ColorText "{Blue}[user.email] {Magenta}git: {Yellow}(already set) {Gray}$gitUserMail"
		}

		git submodule update --init --recursive
	}

	if (Get-Command gh -ErrorAction SilentlyContinue) {
		if ($Force) {
			Write-ColorText "{Yellow}Force mode: Re-authenticating GitHub CLI..."
			gh auth login
		} elseif (!(gh auth status)) { 
			gh auth login 
		}
	}
}

####################################################################
###															SYMLINKS 												 ###
####################################################################
if (Should-RunSection "Symlinks") {
	# symlinks
	Write-TitleBox -Title "Add symbolic links for dotfiles"

# Create PowerShell profile directory if it doesn't exist
$powershellProfilePath = $PROFILE.CurrentUserAllHosts
$powershellProfileDir = Split-Path $powershellProfilePath
if (!(Test-Path $powershellProfileDir)) {
	New-Item $powershellProfileDir -ItemType Directory -Force -ErrorAction SilentlyContinue | Out-Null
	Write-ColorText "{Blue}[directory] {Green}(created) {Gray}$powershellProfileDir"
}

# Create symlink for PowerShell Profile.ps1
if (Test-Path "$PSScriptRoot\Profile.ps1") {
	if (Test-Path $powershellProfilePath) {
		$existingProfile = Get-Item $powershellProfilePath -ErrorAction SilentlyContinue
		if ($existingProfile.LinkType -eq 'SymbolicLink') {
			$targetPath = $existingProfile.Target
			if ($targetPath -ne "$PSScriptRoot\Profile.ps1") {
				# Wrong target, update it
				Remove-Item $powershellProfilePath -Force -ErrorAction SilentlyContinue
				New-Item -ItemType SymbolicLink -Path $powershellProfilePath -Target "$PSScriptRoot\Profile.ps1" -Force -ErrorAction SilentlyContinue | Out-Null
				$script:setupSummary.Updated += "PowerShell Profile"
				Write-ColorText "{Blue}[symlink] {Yellow}(updated) {Green}$PSScriptRoot\Profile.ps1 {Yellow}--> {Gray}$powershellProfilePath"
			} else {
				# Correct target, skip
				$script:setupSummary.Exists += "PowerShell Profile"
				Write-ColorText "{Blue}[symlink] {Yellow}(exists) {Gray}$powershellProfilePath"
			}
		} else {
			# Backup existing profile
			if ($Force) {
				$backupPath = "$powershellProfilePath.backup.$(Get-Date -Format 'yyyyMMdd-HHmmss')"
				Write-ColorText "{Yellow}[symlink] {Gray}Backing up existing profile: $backupPath"
				Copy-Item $powershellProfilePath $backupPath -Force -ErrorAction SilentlyContinue
				Remove-Item $powershellProfilePath -Force -ErrorAction SilentlyContinue
				New-Item -ItemType SymbolicLink -Path $powershellProfilePath -Target "$PSScriptRoot\Profile.ps1" -Force -ErrorAction SilentlyContinue | Out-Null
				$script:setupSummary.Updated += "PowerShell Profile"
				Write-ColorText "{Blue}[symlink] {Green}(created) {Green}$PSScriptRoot\Profile.ps1 {Yellow}--> {Gray}$powershellProfilePath"
			} else {
				$script:setupSummary.Skipped += "PowerShell Profile (exists as regular file, use -Force to replace)"
				Write-ColorText "{Yellow}[symlink] {Gray}Skipped PowerShell Profile (exists, use -Force to replace)"
			}
		}
	} else {
		New-Item -ItemType SymbolicLink -Path $powershellProfilePath -Target "$PSScriptRoot\Profile.ps1" -Force -ErrorAction SilentlyContinue | Out-Null
		$script:setupSummary.Created += "PowerShell Profile"
		Write-ColorText "{Blue}[symlink] {Green}(created) {Green}$PSScriptRoot\Profile.ps1 {Yellow}--> {Gray}$powershellProfilePath"
	}
} else {
	$script:setupSummary.Failed += "PowerShell Profile (source not found)"
	Write-ColorText "{Red}[symlink] {Gray}Profile.ps1 not found at: $PSScriptRoot\Profile.ps1"
}

# Copy AppData folder contents (system directories work better with copies)
Write-ColorText "{Blue}[copy] {Gray}Copying AppData configuration files..."
Copy-ConfigFiles -Source "$PSScriptRoot\config\AppData" -Destination "$env:USERPROFILE\AppData" -Recurse

# Copy home folder contents to user root profile (if any files exist)
if (Test-Path "$PSScriptRoot\config\home" -PathType Container) {
	$homeFiles = Get-ChildItem "$PSScriptRoot\config\home" -Recurse -File -ErrorAction SilentlyContinue
	if ($homeFiles.Count -gt 0) {
		Write-ColorText "{Blue}[copy] {Gray}Copying home folder files to user profile..."
		Copy-ConfigFiles -Source "$PSScriptRoot\config\home" -Destination "$env:USERPROFILE" -Recurse
	} else {
		Write-ColorText "{Blue}[copy] {Yellow}(skipped) {Gray}Home folder is empty, nothing to copy"
	}
}

# Create symlink for config directory (this works well as a symlink)
New-SymbolicLinks -Source "$PSScriptRoot\config\config" -Destination "$env:USERPROFILE\.config" -Recurse

# Copy windows folder contents to Pictures directory
if (Test-Path "$PSScriptRoot\windows" -PathType Container) {
	Write-ColorText "{Blue}[copy] {Gray}Copying windows folder contents to Pictures..."
	$picturesPath = [Environment]::GetFolderPath("MyPictures")
	if (Test-Path $picturesPath) {
		Copy-ConfigFiles -Source "$PSScriptRoot\windows" -Destination $picturesPath -Recurse
	} else {
		Write-ColorText "{Yellow}[copy] {Gray}Pictures folder not found, skipping windows folder copy"
		$script:setupSummary.Skipped += "Windows folder (Pictures directory not found)"
	}
}

	Refresh ($i++)

	# Set the right git name and email for the user after symlinking
	if (Get-Command git -ErrorAction SilentlyContinue) {
		git config --global user.name $gitUserName
		git config --global user.email $gitUserMail
	}
}

##########################################################################
###													ENVIRONMENT VARIABLES											 ###
##########################################################################
if (Should-RunSection "Environment") {
	Write-TitleBox -Title "Set Environment Variables"

# Set DOTFILES and DOTPOSH environment variables for windots
$dotfilesValue = [System.Environment]::GetEnvironmentVariable("DOTFILES")
if ($Force -or !$dotfilesValue) {
	try {
		[System.Environment]::SetEnvironmentVariable("DOTFILES", "$PSScriptRoot", "User")
		if ($dotfilesValue) {
			$script:setupSummary.Updated += "DOTFILES environment variable"
			Write-ColorText "{Blue}[environment] {Yellow}(updated) {Magenta}DOTFILES {Yellow}--> {Gray}$PSScriptRoot"
		} else {
			$script:setupSummary.Created += "DOTFILES environment variable"
			Write-ColorText "{Blue}[environment] {Green}(added) {Magenta}DOTFILES {Yellow}--> {Gray}$PSScriptRoot"
		}
	} catch {
		$script:setupSummary.Failed += "DOTFILES environment variable"
		Write-Error -ErrorAction Stop "An error occurred setting DOTFILES: $_"
	}
} else {
	$script:setupSummary.Exists += "DOTFILES environment variable"
	Write-ColorText "{Blue}[environment] {Yellow}(exists) {Magenta}DOTFILES {Yellow}--> {Gray}$dotfilesValue"
}

$dotposhValue = [System.Environment]::GetEnvironmentVariable("DOTPOSH")
$dotposhPath = Join-Path -Path "$PSScriptRoot" -ChildPath "dotposh"
if ($Force -or !$dotposhValue) {
	try {
		[System.Environment]::SetEnvironmentVariable("DOTPOSH", "$dotposhPath", "User")
		if ($dotposhValue) {
			$script:setupSummary.Updated += "DOTPOSH environment variable"
			Write-ColorText "{Blue}[environment] {Yellow}(updated) {Magenta}DOTPOSH {Yellow}--> {Gray}$dotposhPath"
		} else {
			$script:setupSummary.Created += "DOTPOSH environment variable"
			Write-ColorText "{Blue}[environment] {Green}(added) {Magenta}DOTPOSH {Yellow}--> {Gray}$dotposhPath"
		}
	} catch {
		$script:setupSummary.Failed += "DOTPOSH environment variable"
		Write-Error -ErrorAction Stop "An error occurred setting DOTPOSH: $_"
	}
} else {
	$script:setupSummary.Exists += "DOTPOSH environment variable"
	Write-ColorText "{Blue}[environment] {Yellow}(exists) {Magenta}DOTPOSH {Yellow}--> {Gray}$dotposhValue"
}

# Add dotposh\Modules to PSModulePath so custom modules are discoverable
# Use the actual DOTPOSH path (either from environment or calculated)
$actualDotposhPath = if ($dotposhValue) { $dotposhValue } else { $dotposhPath }
$dotposhModulesPath = Join-Path -Path "$actualDotposhPath" -ChildPath "Modules"
if (Test-Path $dotposhModulesPath) {
	try {
		$currentPSModulePath = [System.Environment]::GetEnvironmentVariable("PSModulePath", "User")
		if ($currentPSModulePath -notlike "*$([regex]::Escape($dotposhModulesPath))*") {
			if ($currentPSModulePath) {
				$newPSModulePath = "$currentPSModulePath;$dotposhModulesPath"
			} else {
				$newPSModulePath = $dotposhModulesPath
			}
			[System.Environment]::SetEnvironmentVariable("PSModulePath", "$newPSModulePath", "User")
			$script:setupSummary.Created += "PSModulePath (added dotposh\Modules)"
			Write-ColorText "{Blue}[environment] {Green}(added) {Magenta}PSModulePath {Yellow}--> {Gray}$dotposhModulesPath"
		} else {
			$script:setupSummary.Exists += "PSModulePath (dotposh\Modules already included)"
			Write-ColorText "{Blue}[environment] {Yellow}(exists) {Magenta}PSModulePath {Yellow}--> {Gray}dotposh\Modules already included"
		}
	} catch {
		$script:setupSummary.Failed += "PSModulePath configuration"
		Write-ColorText "{Blue}[environment] {Red}(failed) {Magenta}PSModulePath {Gray}Error: $_"
	}
} else {
	Write-ColorText "{Yellow}[environment] {Gray}Warning: dotposh\Modules directory not found at $dotposhModulesPath"
}

# Add Setup.ps1 directory to PATH so it can be run from anywhere
$currentPath = [System.Environment]::GetEnvironmentVariable("Path", "User")
if ($Force -or ($currentPath -notlike "*$([regex]::Escape($PSScriptRoot))*")) {
	try {
		if ($currentPath) {
			$newPath = "$currentPath;$PSScriptRoot"
		} else {
			$newPath = $PSScriptRoot
		}
		[System.Environment]::SetEnvironmentVariable("Path", "$newPath", "User")
		# Also add to current session
		$env:Path = "$env:Path;$PSScriptRoot"
		if ($currentPath -like "*$([regex]::Escape($PSScriptRoot))*") {
			$script:setupSummary.Updated += "PATH (added Setup.ps1 directory)"
			Write-ColorText "{Blue}[environment] {Yellow}(updated) {Magenta}PATH {Yellow}--> {Gray}Added $PSScriptRoot"
		} else {
			$script:setupSummary.Created += "PATH (added Setup.ps1 directory)"
			Write-ColorText "{Blue}[environment] {Green}(added) {Magenta}PATH {Yellow}--> {Gray}Added $PSScriptRoot"
		}
	} catch {
		$script:setupSummary.Failed += "PATH configuration"
		Write-ColorText "{Blue}[environment] {Red}(failed) {Magenta}PATH {Gray}Error: $_"
	}
} else {
	$script:setupSummary.Exists += "PATH (Setup.ps1 directory already included)"
	Write-ColorText "{Blue}[environment] {Yellow}(exists) {Magenta}PATH {Yellow}--> {Gray}Setup.ps1 directory already included"
}

# Set environment variables from JSON config
$envVars = $json.environmentVariable
foreach ($env in $envVars) {
	$envCommand = $env.commandName
	$envKey = $env.environmentKey
	$envValue = $env.environmentValue
	
	# Expand environment variables in the value (e.g., %USERPROFILE% -> C:\Users\username)
	# This allows users to use placeholders like %USERPROFILE% or %ProgramFiles% in appList.json
	$expandedValue = [System.Environment]::ExpandEnvironmentVariables($envValue)
	
	if (Get-Command $envCommand -ErrorAction SilentlyContinue) {
		$existingValue = [System.Environment]::GetEnvironmentVariable("$envKey")
		if ($Force -or !$existingValue) {
			Write-Verbose "Set environment variable of $envCommand`: $envKey -> $expandedValue (expanded from: $envValue)"
			try {
				# Set the expanded value, not the placeholder
				[System.Environment]::SetEnvironmentVariable("$envKey", "$expandedValue", "User")
				if ($existingValue) {
					Write-ColorText "{Blue}[environment] {Yellow}(updated) {Magenta}$envKey {Yellow}--> {Gray}$expandedValue"
				} else {
					Write-ColorText "{Blue}[environment] {Green}(added) {Magenta}$envKey {Yellow}--> {Gray}$expandedValue"
				}
			} catch {
				Write-Error -ErrorAction Stop "An error occurred: $_"
			}
		} else {
			Write-ColorText "{Blue}[environment] {Yellow}(exists) {Magenta}$envKey {Yellow}--> {Gray}$existingValue"
		}
	}
}
if (Get-Command gh -ErrorAction SilentlyContinue) {
	$ghDashAvailable = (& gh.exe extension list | Select-String -Pattern "dlvhdr/gh-dash" -SimpleMatch -CaseSensitive)
	if ($ghDashAvailable) {
		$existingValue = [System.Environment]::GetEnvironmentVariable("GH_DASH_CONFIG")
		if ($Force -or !$existingValue) {
			try {
				[System.Environment]::SetEnvironmentVariable("GH_DASH_CONFIG", "$env:USERPROFILE\.config\gh-dash\config.yml", "User")
				if ($existingValue) {
					Write-ColorText "{Blue}[environment] {Yellow}(updated) {Magenta}GH_DASH_CONFIG {Yellow}--> {Gray}$env:USERPROFILE\.config\gh-dash\config.yml"
				} else {
					Write-ColorText "{Blue}[environment] {Green}(added) {Magenta}GH_DASH_CONFIG {Yellow}--> {Gray}$env:USERPROFILE\.config\gh-dash\config.yml"
				}
			} catch {
				Write-Error -ErrorAction Stop "An error occurred: $_"
			}
		} else {
			Write-ColorText "{Blue}[environment] {Yellow}(exists) {Magenta}GH_DASH_CONFIG {Yellow}--> {Gray}$existingValue"
		}
	}
}
	Refresh ($i++)
}

########################################################################################
###										SETUP NODEJS / INSTALL NVM (Node Version Manager)							 ###
########################################################################################
# if (!(Get-Command nvm -ErrorAction SilentlyContinue)) {
# 	Write-TitleBox -Title "Nvm (Node Version Manager) Installation"
# 	$installNvm = $(Write-Host "Install NVM? (y/N) " -ForegroundColor Magenta -NoNewline; Read-Host)
# 	if ($installNvm.ToUpper() -eq 'Y') {
# 		Write-Verbose "Installing NVM from GitHub Repo"
# 		Install-AppFromGitHub -RepoName "coreybutler/nvm-windows" -FileName "nvm-setup.exe"
# 	}
# 	Refresh ($i++)
# }

# if (Get-Command nvm -ErrorAction SilentlyContinue) {
# 	if (!(Get-Command node -ErrorAction SilentlyContinue)) {
# 		$whichNode = $(Write-Host "Install LTS (y) or latest (N) Node version? " -ForegroundColor Magenta -NoNewline; Read-Host)
# 		if ($whichNode.ToUpper() -eq 'Y') {	nvm install lts } else { nvm install latest }
# 		nvm use newest
# 		npm install -g npm@latest
# 	}
# 	if (!(Get-Command bun -ErrorAction SilentlyContinue)) { npm install -g bun }
# }

########################################################################
###														ADDONS / PLUGINS											 ###
########################################################################
if (Should-RunSection "Addons") {
	# plugins / extensions / addons
	$myAddons = $json.packageAddon
	foreach ($a in $myAddons) {
		$aCommandName = $a.commandName
		$aCommandCheck = $a.commandCheck
		$aCommandInvoke = $a.commandInvoke
		$aList = [array]$a.addonList
		$aInstall = $a.install

		if ($aInstall -eq $True) {
			if (Get-Command $aCommandName -ErrorAction SilentlyContinue) {
				Write-TitleBox -Title "$aCommandName's Addons Installation"
				foreach ($p in $aList) {
					$isInstalled = (Invoke-Expression "$aCommandCheck" | Out-String | Select-String -Pattern "$p" -Quiet)
					if ($Force -or !$isInstalled) {
						Write-Verbose "Executing: $aCommandInvoke $p"
						Invoke-Expression "$aCommandInvoke $p >`$null 2>&1"
						if ($LASTEXITCODE -eq 0) {	Write-ColorText "➕ {Blue}[addon] {Magenta}$aCommandName`: {Green}(success) {Gray}$p" }
						else {	Write-ColorText "➕ {Blue}[addon] {Magenta}$aCommandName`: {Red}(failed) {Gray}$p" }
					} else { Write-ColorText "➕ {Blue}[addon] {Magenta}$aCommandName`: {Yellow}(exists) {Gray}$p" }
				}
			}
		}
	}
	Refresh ($i++)
}

########################################################################
###													VSCODE EXTENSIONS												 ###
########################################################################
if (Should-RunSection "VSCode") {
	# VSCode Extensions
	if (Get-Command code -ErrorAction SilentlyContinue) {
		Write-TitleBox -Title "VSCode Extensions Installation"
		$extensionList = Get-Content "$PSScriptRoot\extensions.list"
		foreach ($ext in $extensionList) {
			$isInstalled = (code --list-extensions | Select-String "$ext" -Quiet)
			if ($Force -or !$isInstalled) {
				if ($Force -and $isInstalled) {
					# Uninstall first, then reinstall
					Invoke-Expression "code --uninstall-extension $ext >`$null 2>&1"
				}
				Write-Verbose -Message "Installing VSCode Extension: $ext"
				Invoke-Expression "code --install-extension $ext >`$null 2>&1"
				if ($LASTEXITCODE -eq 0) {
					Write-ColorText "{Blue}[extension] {Green}(success) {Gray}$ext"
				} else {
					Write-ColorText "{Blue}[extension] {Red}(failed) {Gray}$ext"
				}
			} else {
				Write-ColorText "{Blue}[extension] {Yellow}(exists) {Gray}$ext"
			}
		}
	}
}

##########################################################################
###													CATPPUCCIN THEMES 								 				 ###
##########################################################################
if (Should-RunSection "Themes") {
	Write-TitleBox -Title "Per Application Catppuccin Themes Installation"
	# Catppuccin Themes
	$catppuccinThemes = @('Frappe', 'Latte', 'Macchiato', 'Mocha')

	# FLowlauncher themes
	$flowLauncherDir = "$env:LOCALAPPDATA\FlowLauncher"
	if (Test-Path "$flowLauncherDir" -PathType Container) {
		$flowLauncherThemeDir = Join-Path "$flowLauncherDir" -ChildPath "Themes"
		$catppuccinThemes | ForEach-Object {
			$themeFile = Join-Path "$flowLauncherThemeDir" -ChildPath "Catppuccin ${_}.xaml"
			if ($Force -or !(Test-Path "$themeFile" -PathType Leaf)) {
				if ($Force -and (Test-Path "$themeFile" -PathType Leaf)) {
					Remove-Item "$themeFile" -Force -ErrorAction SilentlyContinue
				}
				Write-Verbose "Adding file: $themeFile to $flowLauncherThemeDir."
				Install-OnlineFile -OutputDir "$themeFile" -Url "https://raw.githubusercontent.com/catppuccin/flow-launcher/refs/heads/main/themes/Catppuccin%20${_}.xaml"
				if ($LASTEXITCODE -eq 0) {
					Write-ColorText "{Blue}[theme] {Magenta}flowlauncher: {Green}(success) {Gray}$themeFile"
				} else {
					Write-ColorText "{Blue}[theme] {Magenta}flowlauncher: {Red}(failed) {Gray}$themeFile"
				}
			} else { Write-ColorText "{Blue}[theme] {Magenta}flowlauncher: {Yellow}(exists) {Gray}$themeFile" }
		}
	}

	$catppuccinThemes = $catppuccinThemes.ToLower()

	# add btop theme
	# since we install btop by scoop, then the application folder would be in scoop directory
	$btopExists = Get-Command btop -ErrorAction SilentlyContinue
	if ($btopExists) {
		if ($btopExists.Source | Select-String -SimpleMatch -CaseSensitive "scoop") {
			$btopThemeDir = Join-Path (scoop prefix btop) -ChildPath "themes"
		} else {
			$btopThemeDir = Join-Path ($btopExists.Source | Split-Path) -ChildPath "themes"
		}
		$catppuccinThemes | ForEach-Object {
			$themeFile = Join-Path "$btopThemeDir" -ChildPath "catppuccin_${_}.theme"
			if ($Force -or !(Test-Path "$themeFile" -PathType Leaf)) {
				if ($Force -and (Test-Path "$themeFile" -PathType Leaf)) {
					Remove-Item "$themeFile" -Force -ErrorAction SilentlyContinue
				}
				Write-Verbose "Adding file: $themeFile to $btopThemeDir."
				Install-OnlineFile -OutputDir "$themeFile" -Url "https://raw.githubusercontent.com/catppuccin/btop/refs/heads/main/themes/catppuccin_${_}.theme"
				if ($LASTEXITCODE -eq 0) {
					Write-ColorText "{Blue}[theme] {Magenta}btop: {Green}(success) {Gray}$themeFile"
				} else {
					Write-ColorText "{Blue}[theme] {Magenta}btop: {Red}(failed) {Gray}$themeFile"
				}
			} else { Write-ColorText "{Blue}[theme] {Magenta}btop: {Yellow}(exists) {Gray}$themeFile" }
		}
	}

	if ((Test-Path "C:\Program Files\Notepad++" -PathType Container) -or (Get-Command 'notepad++.exe' -ErrorAction SilentlyContinue)) {
		$notepadPlusPlusThemeDir = Join-Path "C:\Program Files\Notepad++" -ChildPath "themes"
		$catppuccinThemes | ForEach-Object {
			$themeFile = Join-Path "$notepadPlusPlusThemeDir" -ChildPath "catppuccin-${_}.xml"
			if ($Force -or !(Test-Path "$themeFile" -PathType Leaf)) {
				if ($Force -and (Test-Path "$themeFile" -PathType Leaf)) {
					Remove-Item "$themeFile" -Force -ErrorAction SilentlyContinue
				}
				Write-Verbose "Adding file: $themeFile to $notepadPlusPlusThemeDir."
				Install-OnlineFile -OutputDir "$themeFile" -Url "https://raw.githubusercontent.com/catppuccin/notepad-plus-plus/refs/heads/main/themes/catppuccin-${_}.xml"
				if ($LASTEXITCODE -eq 0) {
					Write-ColorText "{Blue}[theme] {Magenta}notepad++: {Green}(success) {Gray}$themeFile"
				} else {
					Write-ColorText "{Blue}[theme] {Magenta}notepad++: {Red}(failed) {Gray}$themeFile"
				}
			} else { Write-ColorText "{Blue}[theme] {Magenta}notepad++: {Yellow}(exists) {Gray}$themeFile" }
		}
	}
}


######################################################################
###														MISCELLANEOUS		 										 ###
######################################################################
if (Should-RunSection "Miscellaneous") {
	# yazi plugins
	Write-TitleBox "Miscellaneous"
	if (Get-Command ya -ErrorAction SilentlyContinue) {
		Write-Verbose "Installing yazi plugins / themes"
		ya pack -i >$null 2>&1
		ya pack -u >$null 2>&1
	}

	# bat build theme
	if (Get-Command bat -ErrorAction SilentlyContinue) {
		Write-Verbose "Building bat theme"
		if ($Force) {
			bat cache --clear
		}
		bat cache --build
	}
}

##########################################################################
###													START KOMOREBI + YASB											 ###
##########################################################################
if (Should-RunSection "Komorebi") {
	Write-TitleBox "Komorebi & Yasb Engines"

	# yasb
	if (Get-Command yasbc -ErrorAction SilentlyContinue) {
		$yasbRunning = Get-Process -Name yasb -ErrorAction SilentlyContinue
		if ($Force -or !$yasbRunning) {
			if ($Force -and $yasbRunning) {
				Write-ColorText "{Yellow}Force mode: Restarting YASB..."
				& yasbc.exe stop 2>&1 | Out-Null
				Start-Sleep -Seconds 1
			}
			try { & yasbc.exe start } catch { Write-Error "$_" }
		} else {
			Write-Host "✅ YASB Status Bar is already running."
		}
	} else {
		Write-Warning "Command not found: yasbc."
	}

	# komorebi
	if (Get-Command komorebic -ErrorAction SilentlyContinue) {
		$komorebiRunning = Get-Process -Name komorebi -ErrorAction SilentlyContinue
		if ($Force -or !$komorebiRunning) {
			if ($Force -and $komorebiRunning) {
				Write-ColorText "{Yellow}Force mode: Restarting Komorebi..."
				& komorebic.exe stop 2>&1 | Out-Null
				Start-Sleep -Seconds 1
			}
			$whkdExists = Get-Command whkd -ErrorAction SilentlyContinue
			$whkdProcess = Get-Process -Name whkd -ErrorAction SilentlyContinue
			Write-Host "Starting Komorebi in the background..."
			if ($whkdExists -and (!$whkdProcess)) {
				try { Start-Process "powershell.exe" -ArgumentList "komorebic.exe", "start", "--whkd" -WindowStyle Hidden }
				catch { Write-Error "$_" }
			} else {
				try { Start-Process "powershell.exe" -ArgumentList "komorebic.exe", "start" -WindowStyle Hidden }
				catch { Write-Error "$_" }
			}
		} else {
			Write-Host "✅ Komorebi Tiling Window Management is already running."
		}
	} else {
		Write-Warning "Command not found: komorebic."
	}
}


##############################################################################
###												WINDOWS SUBSYSTEMS FOR LINUX										 ###
##############################################################################
if (Should-RunSection "WSL") {
	$wslInstalled = Get-Command wsl -CommandType Application -ErrorAction Ignore
	if ($Force -or !$wslInstalled) {
		if ($Force -and $wslInstalled) {
			Write-ColorText "{Yellow}Force mode: Reinstalling WSL..."
		}
		Write-Verbose -Message "Installing Windows SubSystems for Linux..."
		Start-Process -FilePath "PowerShell" -ArgumentList "wsl", "--install" -Verb RunAs -Wait -WindowStyle Hidden
	} else {
		Write-ColorText "{Blue}[wsl] {Yellow}(already installed)"
	}
}


######################################################################
###													END SCRIPT														 ###
######################################################################
Set-Location $currentLocation

# Display Setup Summary
Write-Host "`n" -NoNewline
Write-TitleBox -Title "Setup Summary"

$totalItems = $script:setupSummary.Created.Count + $script:setupSummary.Updated.Count + $script:setupSummary.Exists.Count + $script:setupSummary.Failed.Count + $script:setupSummary.Skipped.Count

if ($script:setupSummary.Created.Count -gt 0) {
	$createdCount = $script:setupSummary.Created.Count
	Write-ColorText "{Green}✅ Created ($createdCount):"
	$script:setupSummary.Created | ForEach-Object {
		Write-ColorText "   {Gray}  • $_"
	}
	Write-Host ""
}

if ($script:setupSummary.Updated.Count -gt 0) {
	$updatedCount = $script:setupSummary.Updated.Count
	Write-ColorText "{Yellow}🔄 Updated ($updatedCount):"
	$script:setupSummary.Updated | ForEach-Object {
		Write-ColorText "   {Gray}  • $_"
	}
	Write-Host ""
}

if ($script:setupSummary.Exists.Count -gt 0) {
	$existsCount = $script:setupSummary.Exists.Count
	Write-ColorText "{Cyan}✓ Already Exists ($existsCount):"
	$script:setupSummary.Exists | ForEach-Object {
		Write-ColorText "   {Gray}  • $_"
	}
	Write-Host ""
}

if ($script:setupSummary.Skipped.Count -gt 0) {
	$skippedCount = $script:setupSummary.Skipped.Count
	Write-ColorText "{DarkGray}⏭️  Skipped ($skippedCount):"
	$script:setupSummary.Skipped | ForEach-Object {
		Write-ColorText "   {Gray}  • $_"
	}
	Write-Host ""
}

if ($script:setupSummary.Failed.Count -gt 0) {
	$failedCount = $script:setupSummary.Failed.Count
	Write-ColorText "{Red}❌ Failed ($failedCount):"
	$script:setupSummary.Failed | ForEach-Object {
		Write-ColorText "   {Gray}  • $_"
	}
	Write-Host ""
}

if ($totalItems -eq 0) {
	Write-ColorText "{DarkGray}No items processed. This may indicate an issue with the setup."
}

Write-Host "----------------------------------------------------------------------------------" -ForegroundColor DarkGray
Write-Host "┌────────────────────────────────────────────────────────────────────────────────┐" -ForegroundColor "Green"
Write-Host "│                                                                                │" -ForegroundColor "Green"
Write-Host "│        █████╗ ██╗     ██╗         ██████╗  ██████╗ ███╗   ██╗███████╗ ██╗      │" -ForegroundColor "Green"
Write-Host "│       ██╔══██╗██║     ██║         ██╔══██╗██╔═══██╗████╗  ██║██╔════╝ ██║      │" -ForegroundColor "Green"
Write-Host "│       ███████║██║     ██║         ██║  ██║██║   ██║██╔██╗ ██║█████╗   ██║      │" -ForegroundColor "Green"
Write-Host "│       ██╔══██║██║     ██║         ██║  ██║██║   ██║██║╚██╗██║██╔══╝   ╚═╝      │" -ForegroundColor "Green"
Write-Host "│       ██║  ██║███████╗███████╗    ██████╔╝╚██████╔╝██║ ╚████║███████╗ ██╗      │" -ForegroundColor "Green"
Write-Host "│       ╚═╝  ╚═╝╚══════╝╚══════╝    ╚═════╝  ╚═════╝ ╚═╝  ╚═══╝╚══════╝ ╚═╝      │" -ForegroundColor "Green"
Write-Host "│                                                                                │" -ForegroundColor "Green"
Write-Host "└────────────────────────────────────────────────────────────────────────────────┘" -ForegroundColor "Green"

Write-ColorText "`n`n{Grey}For more information, please visit: {Blue}https://github.com/jacquindev/windots`n"
Write-ColorText "🔆 {Gray}Submit an issue via: {Blue}https://github.com/jacquindev/windots/issues/new"
Write-ColorText "🔆 {Gray}Contact me via email: {Cyan}jacquindev@outlook.com"

if ($script:setupSummary.Skipped.Count -gt 0) {
	Write-ColorText "`n{Yellow}💡 Tip: {Gray}Some items were skipped. Use {Cyan}-Force {Gray}parameter to replace existing files."
	Write-ColorText "   {Gray}Example: {Cyan}. .\Setup.ps1 -Force"
}

Start-Sleep -Seconds 3
