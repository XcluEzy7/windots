
<#PSScriptInfo

.VERSION 1.3.2

.GUID ccb5be4c-ea07-4c45-a5b4-6310df24e2bc

.AUTHOR eagarcia@techforexcellence.org

.COMPANYNAME

.COPYRIGHT 2025 Jacquin Moon. All rights reserved. (Original Author: jacquindev@outlook.com)

.TAGS windots dotfiles

.LICENSEURI https://github.com/XcluEzy7/windots/blob/main/LICENSE

.PROJECTURI https://github.com/XcluEzy7/windots

.ICONURI

.EXTERNALMODULEDEPENDENCIES

.REQUIREDSCRIPTS

.EXTERNALSCRIPTDEPENDENCIES

.RELEASENOTES
Version 1.3.2 - Updated by XcluEzy7
- Enhanced selective installation features
- Improved environment variable expansion
- Added global access and tab completion
- Automatic privilege escalation with gsudo
- Original script by Jacquin Moon (jacquindev@outlook.com)

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
	Write-ColorText "{Blue}[prerequisite] {Magenta}pwsh: {Gray}Initializing PowerShell 5.1 prerequisites..."

	# All prerequisites must be initialized in PowerShell 5.1 (Windows PowerShell)
	# Build a comprehensive script to run in PowerShell 5.1
	$prereqScript = @"
# Enforce TLS 1.2 for secure connections to PowerShell Gallery
try {
	[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
	Write-Output 'TLS12:SUCCESS'
} catch {
	Write-Output "TLS12:ERROR:`$(`$_.Exception.Message)"
}

# Register and trust PSGallery repository
`$psGalleryRegistered = `$false
try {
	`$psGallery = Get-PSRepository -Name PSGallery -ErrorAction SilentlyContinue
	if (!`$psGallery) {
		# Try to register PSGallery
		try {
			Register-PSRepository -Default -ErrorAction Stop
			`$psGalleryRegistered = `$true
			Write-Output 'PSGALLERY:REGISTERED'
		} catch {
			try {
				Register-PSRepository -Name PSGallery -SourceLocation 'https://www.powershellgallery.com/api/v2' -InstallationPolicy Trusted -ErrorAction Stop
				`$psGalleryRegistered = `$true
				Write-Output 'PSGALLERY:REGISTERED'
			} catch {
				Write-Output "PSGALLERY:DEFERRED:`$(`$_.Exception.Message)"
			}
		}
	} else {
		`$psGalleryRegistered = `$true
		Write-Output 'PSGALLERY:EXISTS'
		
		# Check if PSGallery is properly configured
		if (!`$psGallery.SourceLocation -or `$psGallery.SourceLocation -eq '') {
			try {
				Unregister-PSRepository -Name PSGallery -ErrorAction SilentlyContinue
				Register-PSRepository -Name PSGallery -SourceLocation 'https://www.powershellgallery.com/api/v2' -InstallationPolicy Trusted -ErrorAction Stop
				Write-Output 'PSGALLERY:REREGISTERED'
			} catch {
				Write-Output "PSGALLERY:REREGISTER_FAILED:`$(`$_.Exception.Message)"
			}
		}
	}

	# Set PSGallery as trusted
	if (`$psGalleryRegistered) {
		`$psGallery = Get-PSRepository -Name PSGallery -ErrorAction SilentlyContinue
		if (`$psGallery -and `$psGallery.InstallationPolicy -ne 'Trusted') {
			Set-PSRepository -Name PSGallery -InstallationPolicy Trusted -ErrorAction Stop
			Write-Output 'PSGALLERY:TRUSTED'
		}
	}
} catch {
	Write-Output "PSGALLERY:ERROR:`$(`$_.Exception.Message)"
}
"@

	# Execute prerequisites script in PowerShell 5.1
	$prereqResults = & powershell.exe -NoProfile -Command $prereqScript
	
	# Parse results
	foreach ($result in $prereqResults) {
		if ($result -match '^TLS12:') {
			if ($result -eq 'TLS12:SUCCESS') {
				Write-ColorText "{Blue}[prerequisite] {Magenta}pwsh: {Green}(success) {Gray}TLS 1.2 enforced (PowerShell 5.1)"
			} else {
				Write-ColorText "{Blue}[prerequisite] {Magenta}pwsh: {Yellow}(warning) {Gray}Could not enforce TLS 1.2: $($result -replace 'TLS12:ERROR:', '')"
			}
		} elseif ($result -match '^PSGALLERY:') {
			if ($result -eq 'PSGALLERY:REGISTERED') {
				Write-ColorText "{Blue}[prerequisite] {Magenta}pwsh: {Green}(success) {Gray}PSGallery repository registered (PowerShell 5.1)"
			} elseif ($result -eq 'PSGALLERY:EXISTS') {
				Write-ColorText "{Blue}[prerequisite] {Magenta}pwsh: {Yellow}(exists) {Gray}PSGallery repository (PowerShell 5.1)"
			} elseif ($result -eq 'PSGALLERY:REREGISTERED') {
				Write-ColorText "{Blue}[prerequisite] {Magenta}pwsh: {Green}(success) {Gray}PSGallery repository re-registered (PowerShell 5.1)"
			} elseif ($result -eq 'PSGALLERY:TRUSTED') {
				Write-ColorText "{Blue}[prerequisite] {Magenta}pwsh: {Green}(success) {Gray}PSGallery set as trusted (PowerShell 5.1)"
			} elseif ($result -match '^PSGALLERY:DEFERRED:') {
				Write-ColorText "{Blue}[prerequisite] {Magenta}pwsh: {Yellow}(warning) {Gray}PSGallery registration deferred (NuGet provider required first): $($result -replace 'PSGALLERY:DEFERRED:', '')"
			} elseif ($result -match '^PSGALLERY:') {
				Write-ColorText "{Blue}[prerequisite] {Magenta}pwsh: {Yellow}(warning) {Gray}PSGallery configuration: $($result -replace 'PSGALLERY:', '')"
			}
		}
	}

	# Install/Update NuGet provider in PowerShell 5.1 (required for module installation)
	# Use manual bootstrap method since PowerShellGet may be broken
	try {
		# Check NuGet provider in PowerShell 5.1
		$nugetCheckScript = @"
`$provider = Get-PackageProvider -Name NuGet -ListAvailable -ErrorAction SilentlyContinue | 
	Where-Object { [version]`$_.Version -ge [version]'2.8.5.201' } | 
	Sort-Object Version -Descending | 
	Select-Object -First 1
if (`$provider) {
	Write-Output "EXISTS:`$(`$provider.Version)"
} else {
	Write-Output 'NOT_FOUND'
}
"@
		
		$nugetCheckResult = & powershell.exe -NoProfile -Command $nugetCheckScript
		$nugetProvider = $null
		if ($nugetCheckResult -match '^EXISTS:') {
			$nugetVersion = $nugetCheckResult -replace 'EXISTS:', ''
			$nugetProvider = @{ Version = $nugetVersion }
		}

		if (!$nugetProvider) {
			Write-ColorText "{Blue}[prerequisite] {Magenta}pwsh: {Gray}Installing NuGet provider (minimum 2.8.5.201) in PowerShell 5.1 via manual bootstrap..."
			
			$nugetInstalled = $false
			
			# Method 1: Try standard installation in PowerShell 5.1 (may fail if PowerShellGet is broken)
			$nugetInstallScript1 = @"
try {
	[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
	Install-PackageProvider -Name NuGet -MinimumVersion 2.8.5.201 -Force -Scope CurrentUser -ErrorAction Stop | Out-Null
	`$verify = Get-PackageProvider -Name NuGet -ListAvailable -ErrorAction SilentlyContinue | 
		Where-Object { [version]`$_.Version -ge [version]'2.8.5.201' } | 
		Select-Object -First 1
	if (`$verify) {
		Write-Output "SUCCESS:`$(`$verify.Version)"
	} else {
		Write-Output 'VERIFY_FAILED'
	}
} catch {
	Write-Output "ERROR:`$(`$_.Exception.Message)"
}
"@
			
			try {
				$installResult1 = & powershell.exe -NoProfile -Command $nugetInstallScript1
				if ($installResult1 -match '^SUCCESS:') {
					$nugetInstalled = $true
					$installedVersion = $installResult1 -replace 'SUCCESS:', ''
					Write-ColorText "{Blue}[prerequisite] {Magenta}pwsh: {Green}(success) {Gray}NuGet provider $installedVersion installed via standard method (PowerShell 5.1)"
				} elseif ($installResult1 -eq 'VERIFY_FAILED') {
					throw "Installation completed but verification failed"
				} else {
					$errorMsg = $installResult1 -replace 'ERROR:', ''
					Write-ColorText "{Blue}[prerequisite] {Magenta}pwsh: {Yellow}(warning) {Gray}Standard installation failed, using manual bootstrap: $errorMsg"
					throw $errorMsg
				}
			} catch {
				
				# Method 2: Manual bootstrap - download and install NuGet provider directly
				# This runs in the current PowerShell 7.x context to download files, then installs in PowerShell 5.1
				try {
					# Primary method: Download and run the official NuGet provider installer
					# This is the most reliable method when PowerShellGet is broken
					Write-ColorText "{Blue}[prerequisite] {Magenta}pwsh: {Gray}Downloading NuGet provider installer..."
					$nugetUrl = "https://oneget.org/nuget-2.8.5.201.exe"
					$nugetInstaller = "$env:TEMP\nuget-installer.exe"
					
					Invoke-WebRequest -Uri $nugetUrl -OutFile $nugetInstaller -UseBasicParsing -ErrorAction Stop
					
					Write-ColorText "{Blue}[prerequisite] {Magenta}pwsh: {Gray}Installing NuGet provider in PowerShell 5.1 (this may take a moment)..."
					$installProcess = Start-Process -FilePath $nugetInstaller -ArgumentList "/quiet" -Wait -NoNewWindow -PassThru
					
					if ($installProcess.ExitCode -eq 0 -or $installProcess.ExitCode -eq $null) {
						# Give it a moment to register
						Start-Sleep -Seconds 2
						
						# Verify installation in PowerShell 5.1
						$verifyScript = @"
`$verify = Get-PackageProvider -Name NuGet -ListAvailable -ErrorAction SilentlyContinue | 
	Where-Object { [version]`$_.Version -ge [version]'2.8.5.201' } | 
	Select-Object -First 1
if (`$verify) {
	Write-Output "SUCCESS:`$(`$verify.Version)"
} else {
	Write-Output 'VERIFY_FAILED'
}
"@
						
						$verifyResult = & powershell.exe -NoProfile -Command $verifyScript
						if ($verifyResult -match '^SUCCESS:') {
							$nugetInstalled = $true
							$installedVersion = $verifyResult -replace 'SUCCESS:', ''
							Write-ColorText "{Blue}[prerequisite] {Magenta}pwsh: {Green}(success) {Gray}NuGet provider $installedVersion installed (PowerShell 5.1)"
						} else {
							# Provider may need a PowerShell restart, but continue anyway
							Write-ColorText "{Blue}[prerequisite] {Magenta}pwsh: {Yellow}(warning) {Gray}NuGet provider installed but may require PowerShell 5.1 restart to be fully available"
							$nugetInstalled = $true
						}
					} else {
						throw "Installer exited with code $($installProcess.ExitCode)"
					}
					
					# Clean up
					Remove-Item $nugetInstaller -Force -ErrorAction SilentlyContinue
				} catch {
					# Fallback: Try downloading from PowerShell Gallery API directly
					Write-ColorText "{Blue}[prerequisite] {Magenta}pwsh: {Yellow}(warning) {Gray}Installer method failed, trying package download: $_"
					try {
						# Determine provider assemblies directory (shared location for both PS versions)
						$providerPath = "$env:USERPROFILE\AppData\Local\PackageManagement\ProviderAssemblies"
						$nugetProviderPath = Join-Path $providerPath "nuget"
						
						# Create directory if it doesn't exist
						if (!(Test-Path $providerPath)) {
							New-Item -ItemType Directory -Path $providerPath -Force | Out-Null
						}
						if (!(Test-Path $nugetProviderPath)) {
							New-Item -ItemType Directory -Path $nugetProviderPath -Force | Out-Null
						}
						
						# Download NuGet provider package
						$nugetPackageUrl = "https://www.powershellgallery.com/api/v2/package/NuGet/2.8.5.201"
						$nugetPackageZip = "$env:TEMP\nuget-provider.zip"
						
						Invoke-WebRequest -Uri $nugetPackageUrl -OutFile $nugetPackageZip -UseBasicParsing -ErrorAction Stop
						Expand-Archive -Path $nugetPackageZip -DestinationPath "$env:TEMP\nuget-provider" -Force
						
						# Copy provider DLL
						$extractedPath = "$env:TEMP\nuget-provider"
						$providerDll = Get-ChildItem -Path $extractedPath -Recurse -Filter "Microsoft.PackageManagement.NuGetProvider.dll" -ErrorAction SilentlyContinue | Select-Object -First 1
						
						if ($providerDll) {
							Copy-Item -Path $providerDll.FullName -Destination $nugetProviderPath -Force
							
							# Verify in PowerShell 5.1
							$verifyScript2 = @"
Import-PackageProvider -Name NuGet -Force -ErrorAction SilentlyContinue | Out-Null
`$verify = Get-PackageProvider -Name NuGet -ListAvailable -ErrorAction SilentlyContinue | 
	Where-Object { [version]`$_.Version -ge [version]'2.8.5.201' } | 
	Select-Object -First 1
if (`$verify) {
	Write-Output "SUCCESS:`$(`$verify.Version)"
} else {
	Write-Output 'VERIFY_FAILED'
}
"@
							$verifyResult2 = & powershell.exe -NoProfile -Command $verifyScript2
							if ($verifyResult2 -match '^SUCCESS:') {
								$nugetInstalled = $true
								$installedVersion2 = $verifyResult2 -replace 'SUCCESS:', ''
								Write-ColorText "{Blue}[prerequisite] {Magenta}pwsh: {Green}(success) {Gray}NuGet provider $installedVersion2 installed via package download (PowerShell 5.1)"
							}
						}
						
						# Clean up
						Remove-Item $nugetPackageZip -Force -ErrorAction SilentlyContinue
						Remove-Item $extractedPath -Recurse -Force -ErrorAction SilentlyContinue
					} catch {
						throw "All bootstrap methods failed: $_"
					}
				}
			}
			
			if ($nugetInstalled) {
				# Retry PSGallery registration in PowerShell 5.1 now that NuGet is available
				$retryPSGalleryScript = @"
try {
	`$psGallery = Get-PSRepository -Name PSGallery -ErrorAction SilentlyContinue
	if (!`$psGallery) {
		Register-PSRepository -Default -ErrorAction Stop
		Set-PSRepository -Name PSGallery -InstallationPolicy Trusted -ErrorAction Stop
		Write-Output 'PSGALLERY:REGISTERED'
	} else {
		Set-PSRepository -Name PSGallery -InstallationPolicy Trusted -ErrorAction Stop
		Write-Output 'PSGALLERY:TRUSTED'
	}
} catch {
	Write-Output "PSGALLERY:ERROR:`$(`$_.Exception.Message)"
}
"@
				$retryResult = & powershell.exe -NoProfile -Command $retryPSGalleryScript
				if ($retryResult -eq 'PSGALLERY:REGISTERED') {
					Write-ColorText "{Blue}[prerequisite] {Magenta}pwsh: {Green}(success) {Gray}PSGallery repository registered (after NuGet installation, PowerShell 5.1)"
				} elseif ($retryResult -eq 'PSGALLERY:TRUSTED') {
					Write-ColorText "{Blue}[prerequisite] {Magenta}pwsh: {Green}(success) {Gray}PSGallery set as trusted (PowerShell 5.1)"
				} elseif ($retryResult -match '^PSGALLERY:ERROR:') {
					$errorMsg = $retryResult -replace 'PSGALLERY:ERROR:', ''
					Write-ColorText "{Blue}[prerequisite] {Magenta}pwsh: {Yellow}(warning) {Gray}PSGallery registration still failed: $errorMsg"
				}
			} else {
				throw "NuGet provider installation failed with all methods"
			}
		} else {
			Write-ColorText "{Blue}[prerequisite] {Magenta}pwsh: {Yellow}(exists) {Gray}NuGet provider $($nugetProvider.Version) (PowerShell 5.1)"
		}
	} catch {
		Write-ColorText "{Blue}[prerequisite] {Magenta}pwsh: {Red}(failed) {Gray}NuGet provider installation: $_"
		$script:setupSummary.Failed += "PowerShell Prerequisite: NuGet provider"
	}

	# Note: PackageManagement and PowerShellGet are built into PowerShell 5.1
	# We don't need to install them separately - they're already available
	Write-ColorText "{Blue}[prerequisite] {Magenta}pwsh: {Yellow}(info) {Gray}PackageManagement and PowerShellGet are built into PowerShell 5.1"

	''
}

function Install-PowerShellModule {
	param ([string]$Module, [string]$Version, [array]$AdditionalArgs)

	# Check if module is installed in PowerShell 5.1 (Windows PowerShell)
	# Modules must be installed in PowerShell 5.1, not PowerShell 7.x
	$ps51CheckScript = @"
`$module = Get-InstalledModule -Name '$Module' -ErrorAction SilentlyContinue
if (`$module) { Write-Output 'INSTALLED' } else { Write-Output 'NOT_INSTALLED' }
"@
	
	$checkResult = & powershell.exe -NoProfile -Command $ps51CheckScript
	$moduleInstalled = ($checkResult -eq 'INSTALLED')

	if (!$moduleInstalled) {
		try {
			# Build Install-Module command for PowerShell 5.1
			$installCmd = "Install-Module -Name '$Module' -Scope CurrentUser -Force -AllowClobber -SkipPublisherCheck -ErrorAction Stop"
			
			if ($null -ne $Version) {
				$installCmd += " -RequiredVersion '$Version'"
			}

			# Add additional arguments if provided
			if ($AdditionalArgs.Count -ge 1) {
				for ($i = 0; $i -lt $AdditionalArgs.Count; $i++) {
					if ($AdditionalArgs[$i] -match '^-') {
						$paramName = $AdditionalArgs[$i].TrimStart('-')
						if ($i + 1 -lt $AdditionalArgs.Count -and $AdditionalArgs[$i + 1] -notmatch '^-') {
							$paramValue = $AdditionalArgs[$i + 1]
							$installCmd += " -$paramName '$paramValue'"
							$i++
						} else {
							$installCmd += " -$paramName"
						}
					}
				}
			}

			# Execute installation in PowerShell 5.1
			$installScript = @"
try {
	[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
	$installCmd
	`$verify = Get-InstalledModule -Name '$Module' -ErrorAction SilentlyContinue
	if (`$verify) { Write-Output 'SUCCESS' } else { Write-Output 'VERIFY_FAILED' }
} catch {
	Write-Output "ERROR: `$(`$_.Exception.Message)"
}
"@
			
			$installResult = & powershell.exe -NoProfile -Command $installScript
			
			if ($installResult -eq 'SUCCESS') {
				Write-ColorText "{Blue}[module] {Magenta}pwsh: {Green}(success) {Gray}$Module {DarkGray}(installed in PowerShell 5.1)"
			} elseif ($installResult -eq 'VERIFY_FAILED') {
				throw "Module installation completed but verification failed"
			} else {
				throw $installResult
			}
		} catch {
			Write-ColorText "{Blue}[module] {Magenta}pwsh: {Red}(failed) {Gray}$Module {DarkGray}Error: $_"
			$script:setupSummary.Failed += "PowerShell Module: $Module"
		}
	} elseif ($Force) {
		# Force reinstall
		try {
			$installCmd = "Install-Module -Name '$Module' -Scope CurrentUser -Force -AllowClobber -SkipPublisherCheck -ErrorAction Stop"
			
			if ($null -ne $Version) {
				$installCmd += " -RequiredVersion '$Version'"
			}

			# Add additional arguments if provided
			if ($AdditionalArgs.Count -ge 1) {
				for ($i = 0; $i -lt $AdditionalArgs.Count; $i++) {
					if ($AdditionalArgs[$i] -match '^-') {
						$paramName = $AdditionalArgs[$i].TrimStart('-')
						if ($i + 1 -lt $AdditionalArgs.Count -and $AdditionalArgs[$i + 1] -notmatch '^-') {
							$paramValue = $AdditionalArgs[$i + 1]
							$installCmd += " -$paramName '$paramValue'"
							$i++
						} else {
							$installCmd += " -$paramName"
						}
					}
				}
			}

			# Execute reinstallation in PowerShell 5.1
			$reinstallScript = @"
try {
	[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
	$installCmd
	`$verify = Get-InstalledModule -Name '$Module' -ErrorAction SilentlyContinue
	if (`$verify) { Write-Output 'SUCCESS' } else { Write-Output 'VERIFY_FAILED' }
} catch {
	Write-Output "ERROR: `$(`$_.Exception.Message)"
}
"@
			
			$reinstallResult = & powershell.exe -NoProfile -Command $reinstallScript
			
			if ($reinstallResult -eq 'SUCCESS') {
				Write-ColorText "{Blue}[module] {Magenta}pwsh: {Green}(reinstalled) {Gray}$Module {DarkGray}(installed in PowerShell 5.1)"
			} elseif ($reinstallResult -eq 'VERIFY_FAILED') {
				throw "Module reinstallation completed but verification failed"
			} else {
				throw $reinstallResult
			}
		} catch {
			Write-ColorText "{Blue}[module] {Magenta}pwsh: {Red}(failed) {Gray}$Module {DarkGray}Error: $_"
			$script:setupSummary.Failed += "PowerShell Module: $Module"
		}
	} else {
		Write-ColorText "{Blue}[module] {Magenta}pwsh: {Yellow}(exists) {Gray}$Module {DarkGray}(in PowerShell 5.1)"
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
# Note: These modules are installed in PowerShell 5.1, not PowerShell 7.x
# Commented out due to installation failures (NuGet provider issue):
Write-ColorText "{Blue}[module] {Magenta}pwsh: {Gray}Installing profile-required modules (PowerShell 5.1)..."
$profileRequiredModules = @(
	# "BurntToast",
	# "Microsoft.PowerShell.SecretManagement",
	# "Microsoft.PowerShell.SecretStore",
	# "PSScriptTools",
	# "PSFzf",
	# "CompletionPredictor"
)

foreach ($module in $profileRequiredModules) {
	# Check if module is installed in PowerShell 5.1
	$checkScript = @"
`$module = Get-InstalledModule -Name '$module' -ErrorAction SilentlyContinue
if (`$module) { Write-Output 'INSTALLED' } else { Write-Output 'NOT_INSTALLED' }
"@
	
	$checkResult = & powershell.exe -NoProfile -Command $checkScript
	$moduleInstalled = ($checkResult -eq 'INSTALLED')
	
	if ($Force -or !$moduleInstalled) {
		try {
			$installScript = @"
try {
	[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
	Install-Module -Name '$module' -Scope CurrentUser -Force -AllowClobber -SkipPublisherCheck -ErrorAction Stop
	`$verify = Get-InstalledModule -Name '$module' -ErrorAction SilentlyContinue
	if (`$verify) { Write-Output 'SUCCESS' } else { Write-Output 'VERIFY_FAILED' }
} catch {
	Write-Output "ERROR:`$(`$_.Exception.Message)"
}
"@
			$installResult = & powershell.exe -NoProfile -Command $installScript
			
			if ($installResult -eq 'SUCCESS') {
				Write-ColorText "{Blue}[module] {Magenta}pwsh: {Green}(success) {Gray}$module {DarkGray}(installed in PowerShell 5.1)"
			} elseif ($installResult -eq 'VERIFY_FAILED') {
				throw "Module installation completed but verification failed"
			} else {
				$errorMsg = $installResult -replace 'ERROR:', ''
				throw $errorMsg
			}
		} catch {
			Write-ColorText "{Blue}[module] {Magenta}pwsh: {Red}(failed) {Gray}$module {DarkGray}Error: $_"
			$script:setupSummary.Failed += "PowerShell Module: $module"
		}
	} else {
		Write-ColorText "{Blue}[module] {Magenta}pwsh: {Yellow}(exists) {Gray}$module {DarkGray}(in PowerShell 5.1)"
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
	$featuresEnabled = @()
	foreach ($f in $featureList) {
		$featureExists = Get-ExperimentalFeature -Name $f -ErrorAction SilentlyContinue
		if ($null -eq $featureExists) {
			Write-ColorText "{Blue}[experimental feature] {Magenta}pwsh: {Red}(not found) {Gray}$f"
			continue
		}
		
		if ($Force -or ($featureExists.Enabled -eq $False)) {
			try {
				$result = Enable-ExperimentalFeature -Name $f -Scope CurrentUser -ErrorAction Stop
				if ($result.Enabled -eq $True) {
					Write-ColorText "{Blue}[experimental feature] {Magenta}pwsh: {Green}(success) {Gray}$f"
					$featuresEnabled += $f
				} else {
					Write-ColorText "{Blue}[experimental feature] {Magenta}pwsh: {Yellow}(pending) {Gray}$f {DarkGray}(restart required)"
					$featuresEnabled += $f
				}
			} catch {
				Write-ColorText "{Blue}[experimental feature] {Magenta}pwsh: {Red}(failed) {Gray}$f {DarkGray}Error: $_"
				$script:setupSummary.Failed += "PowerShell Experimental Feature: $f"
			}
		} else {
			Write-ColorText "{Blue}[experimental feature] {Magenta}pwsh: {Yellow}(enabled) {Gray}$f"
		}
	}

	if ($featuresEnabled.Count -gt 0) {
		Write-ColorText "{Yellow}[!] {Gray}PowerShell restart required for experimental features to take effect: {Cyan}$($featuresEnabled -join ', ')"
		Write-ColorText "{Yellow}[!] {Gray}After restart, you may need to install dependent modules (e.g., CompletionPredictor for PSSubsystemPluginModel)"
		
		# Attempt to install CompletionPredictor if PSSubsystemPluginModel was enabled
		# Note: This may fail until PowerShell is restarted, which is expected
		if ($featuresEnabled -contains "PSSubsystemPluginModel") {
			''
			Write-ColorText "{Blue}[module] {Magenta}pwsh: {Gray}Attempting to install CompletionPredictor (may require restart first)..."
			$completionPredictorInstalled = Get-Module -ListAvailable -Name "CompletionPredictor" -ErrorAction SilentlyContinue
			if ($Force -or !$completionPredictorInstalled) {
				try {
					Install-Module -Name "CompletionPredictor" -Scope CurrentUser -Force -AllowClobber -SkipPublisherCheck -ErrorAction Stop
					Write-ColorText "{Blue}[module] {Magenta}pwsh: {Green}(success) {Gray}CompletionPredictor"
				} catch {
					Write-ColorText "{Blue}[module] {Magenta}pwsh: {Yellow}(skipped) {Gray}CompletionPredictor {DarkGray}(Install after PowerShell restart)"
					Write-ColorText "{DarkGray}   Run: Install-Module -Name CompletionPredictor"
				}
			} else {
				Write-ColorText "{Blue}[module] {Magenta}pwsh: {Yellow}(exists) {Gray}CompletionPredictor"
			}
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
		
		# Original author's information - prompt to change if these are detected
		$originalAuthorName = "Jacquin Moon"
		$originalAuthorEmail = "jacquindev@outlook.com"
		
		# Check if current values match original author's (should be changed by user)
		$isOriginalAuthor = ($gitUserName -eq $originalAuthorName) -or ($gitUserMail -eq $originalAuthorEmail)

		if ($Force -or $null -eq $gitUserName -or $isOriginalAuthor) {
			if ($Force -and $null -ne $gitUserName -and !$isOriginalAuthor) {
				Write-ColorText "{Yellow}Force mode: Re-prompting for git name..."
			} elseif ($isOriginalAuthor) {
				Write-ColorText "{Yellow}[!] {Gray}Detected original author's git configuration. Please set your own git name and email."
			}
			$gitUserName = $(Write-Host "Input your git name: " -NoNewline -ForegroundColor Magenta; Read-Host)
		} else {
			Write-ColorText "{Blue}[user.name]  {Magenta}git: {Yellow}(already set) {Gray}$gitUserName"
		}
		if ($Force -or $null -eq $gitUserMail -or $isOriginalAuthor) {
			if ($Force -and $null -ne $gitUserMail -and !$isOriginalAuthor) {
				Write-ColorText "{Yellow}Force mode: Re-prompting for git email..."
			} elseif ($isOriginalAuthor -and $null -ne $gitUserMail) {
				Write-ColorText "{Yellow}[!] {Gray}Detected original author's git configuration. Please set your own git name and email."
			}
			$gitUserMail = $(Write-Host "Input your git email: " -NoNewline -ForegroundColor Magenta; Read-Host)
		} else {
			Write-ColorText "{Blue}[user.email] {Magenta}git: {Yellow}(already set) {Gray}$gitUserMail"
		}

		# Set git config immediately in Git section
		if ($gitUserName -and $gitUserMail) {
			git config --global user.name $gitUserName
			git config --global user.email $gitUserMail
			Write-ColorText "{Blue}[git] {Green}(configured) {Gray}user.name = $gitUserName"
			Write-ColorText "{Blue}[git] {Green}(configured) {Gray}user.email = $gitUserMail"
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

	# Setup YASB GitHub Token for GitHub widget
	$yasbConfigPath = Join-Path $PSScriptRoot "config\config\yasb"
	$yasbEnvPath = Join-Path $yasbConfigPath ".env"
	$existingToken = [System.Environment]::GetEnvironmentVariable("YASB_GITHUB_TOKEN")
	
	if ($Force -or (!$existingToken -and !(Test-Path $yasbEnvPath))) {
		if ($Force -and ($existingToken -or (Test-Path $yasbEnvPath))) {
			Write-ColorText "{Yellow}Force mode: Re-prompting for YASB GitHub token..."
		}
		Write-ColorText "{Blue}[github] {Magenta}YASB: {Gray}Configure GitHub token for YASB widget..."
		Write-ColorText "{DarkGray}   The GitHub widget requires a Personal Access Token (classic)"
		Write-ColorText "{DarkGray}   Create one at: https://github.com/settings/tokens"
		Write-ColorText "{DarkGray}   Required scopes: notifications (read)"
		Write-ColorText "{DarkGray}   See .env.example in config/config/yasb/ for manual setup instructions"
		Write-ColorText ""
		
		$setupToken = $(Write-Host "Setup YASB_GITHUB_TOKEN? [y/N]: " -NoNewline -ForegroundColor Magenta; Read-Host)
		if ($setupToken.ToUpper() -eq 'Y') {
			$tokenValue = $(Write-Host "Enter your GitHub Personal Access Token: " -NoNewline -ForegroundColor Magenta; Read-Host -AsSecureString)
			$tokenPlainText = [Runtime.InteropServices.Marshal]::PtrToStringAuto(
				[Runtime.InteropServices.Marshal]::SecureStringToBSTR($tokenValue)
			)
			
			if ($tokenPlainText) {
				Write-ColorText ""
				Write-ColorText "{DarkGray}   Choose storage method:"
				Write-ColorText "{DarkGray}   1) Environment variable (recommended, system-wide)"
				Write-ColorText "{DarkGray}   2) .env file (local to yasb folder)"
				$storageChoice = $(Write-Host "Storage method [1/2]: " -NoNewline -ForegroundColor Magenta; Read-Host)
				
				if ($storageChoice -eq "1" -or $storageChoice -eq "") {
					# Set as environment variable
					try {
						[System.Environment]::SetEnvironmentVariable("YASB_GITHUB_TOKEN", $tokenPlainText, "User")
						$Env:YASB_GITHUB_TOKEN = $tokenPlainText
						Write-ColorText "{Blue}[github] {Magenta}YASB: {Green}(success) {Gray}YASB_GITHUB_TOKEN set as environment variable"
					} catch {
						Write-ColorText "{Blue}[github] {Magenta}YASB: {Red}(failed) {Gray}Could not set environment variable: $_"
					}
				} elseif ($storageChoice -eq "2") {
					# Create .env file
					try {
						if (!(Test-Path $yasbConfigPath)) {
							New-Item -ItemType Directory -Path $yasbConfigPath -Force | Out-Null
						}
						"YASB_GITHUB_TOKEN=$tokenPlainText" | Out-File -FilePath $yasbEnvPath -Encoding utf8 -NoNewline
						Write-ColorText "{Blue}[github] {Magenta}YASB: {Green}(success) {Gray}Token saved to .env file at $yasbEnvPath"
						Write-ColorText "{Yellow}[!] {Gray}Note: The .env file format matches .env.example in the same directory"
						Write-ColorText "{DarkGray}   You may need to configure YASB to load from .env file if not already set up"
					} catch {
						Write-ColorText "{Blue}[github] {Magenta}YASB: {Red}(failed) {Gray}Could not create .env file: $_"
					}
				} else {
					Write-ColorText "{Blue}[github] {Magenta}YASB: {Yellow}(skipped) {Gray}Invalid choice, token not saved"
				}
				
				# Clear the plaintext token from memory
				$tokenPlainText = $null
			} else {
				Write-ColorText "{Blue}[github] {Magenta}YASB: {Yellow}(skipped) {Gray}No token provided"
			}
		} else {
			Write-ColorText "{Blue}[github] {Magenta}YASB: {Yellow}(skipped) {Gray}YASB GitHub token setup skipped"
		}
	} else {
		if ($existingToken) {
			Write-ColorText "{Blue}[github] {Magenta}YASB: {Yellow}(exists) {Gray}YASB_GITHUB_TOKEN environment variable already set"
		} elseif (Test-Path $yasbEnvPath) {
			Write-ColorText "{Blue}[github] {Magenta}YASB: {Yellow}(exists) {Gray}.env file found at $yasbEnvPath"
		}
	}

	# Initialize Commitizen if package.json exists and npm is available
	if (Get-Command npm -ErrorAction SilentlyContinue) {
		$packageJsonPath = Join-Path $PSScriptRoot "package.json"
		if (Test-Path $packageJsonPath) {
			try {
				$packageJson = Get-Content $packageJsonPath -Raw | ConvertFrom-Json
				$hasCommitizen = $packageJson.devDependencies.PSObject.Properties.Name -contains "commitizen"
				$hasCzAdapter = $packageJson.devDependencies.PSObject.Properties.Name -contains "cz-conventional-changelog"
				$hasConfig = $packageJson.config -and $packageJson.config.commitizen

				if (!$hasCommitizen -or !$hasCzAdapter -or !$hasConfig) {
					Write-ColorText "{Blue}[git] {Magenta}commitizen: {Gray}Initializing Commitizen for conventional commits..."
					Push-Location $PSScriptRoot
					try {
						# Install commitizen and adapter if not present
						if (!$hasCommitizen) {
							npm install --save-dev commitizen --silent 2>&1 | Out-Null
						}
						if (!$hasCzAdapter) {
							npm install --save-dev cz-conventional-changelog --silent 2>&1 | Out-Null
						}
						# Initialize commitizen config if not present
						if (!$hasConfig) {
							npx commitizen init cz-conventional-changelog --save-dev --save-exact --yes 2>&1 | Out-Null
						}
						Write-ColorText "{Blue}[git] {Magenta}commitizen: {Green}(success) {Gray}Commitizen configured"
					} catch {
						Write-ColorText "{Blue}[git] {Magenta}commitizen: {Yellow}(warning) {Gray}Could not initialize Commitizen: $_"
					} finally {
						Pop-Location
					}
				} else {
					Write-ColorText "{Blue}[git] {Magenta}commitizen: {Yellow}(exists) {Gray}Commitizen already configured"
				}
			} catch {
				Write-ColorText "{Blue}[git] {Magenta}commitizen: {Yellow}(warning) {Gray}Could not check Commitizen configuration: $_"
			}
		}
	}
}

####################################################################
###															SYMLINKS 												 ###
####################################################################
if (Should-RunSection "Symlinks") {
	# symlinks
	Write-TitleBox -Title "Add symbolic links for dotfiles"

# Create PowerShell profile symlinks for all user-specific profiles
# This handles OneDrive redirection automatically since $PROFILE paths reflect the actual location
Write-ColorText "{Blue}[symlink] {Gray}Setting up PowerShell profile symlinks..."

# PowerShell Profile Symlinks - Separate handling for PowerShell 7.x and 5.1
# PowerShell 7.x profiles link to pwsh/Profile.ps1
# PowerShell 5.1 profiles link to powershell/WindowsProfile.ps1

$pwshProfileSource = "$PSScriptRoot\pwsh\Profile.ps1"
$ps51ProfileSource = "$PSScriptRoot\powershell\WindowsProfile.ps1"

$profilePaths = @()

# PowerShell 7+ profiles (pwsh) - Link to pwsh/Profile.ps1
if (Test-Path $pwshProfileSource) {
	try {
		$pwshProfile = $PROFILE
		if ($pwshProfile -and $pwshProfile.CurrentUserAllHosts) {
			$profileDir = Split-Path $pwshProfile.CurrentUserAllHosts
			
			# Current User, All Hosts (PowerShell 7)
			$profilePaths += @{
				Path = $pwshProfile.CurrentUserAllHosts
				Name = "PowerShell 7 - CurrentUserAllHosts"
				Source = $pwshProfileSource
			}
			
			# Explicitly add VSCode profile path (same directory, different filename)
			# This ensures VSCode profile is created even when Setup.ps1 is run from a different host
			$vscodeProfilePath = Join-Path $profileDir "Microsoft.VSCode_profile.ps1"
			$profilePaths += @{
				Path = $vscodeProfilePath
				Name = "PowerShell 7 - Microsoft.VSCode_profile.ps1 (VSCode)"
				Source = $pwshProfileSource
			}
			
			# Current User, Current Host (for the current host running Setup.ps1)
			# Only add if it's different from the profiles we've already added (to avoid duplicates)
			if ($pwshProfile.CurrentUserCurrentHost -and 
				$pwshProfile.CurrentUserCurrentHost -ne $pwshProfile.CurrentUserAllHosts -and
				$pwshProfile.CurrentUserCurrentHost -ne $vscodeProfilePath) {
				$profilePaths += @{
					Path = $pwshProfile.CurrentUserCurrentHost
					Name = "PowerShell 7 - CurrentUserCurrentHost ($($Host.Name))"
					Source = $pwshProfileSource
				}
			}
		}
	} catch {
		Write-ColorText "{Yellow}[symlink] {Gray}PowerShell 7 profiles not available: $_"
	}
} else {
	Write-ColorText "{Yellow}[symlink] {Gray}PowerShell 7 profile source not found: $pwshProfileSource"
}

# Windows PowerShell 5.1 profiles - Link to powershell/WindowsProfile.ps1
if (Test-Path $ps51ProfileSource) {
	try {
		# Check if we're in PowerShell 5.1 or if we need to check Windows PowerShell paths
		$ps51Paths = @(
			"$([Environment]::GetFolderPath('MyDocuments'))\WindowsPowerShell\Microsoft.PowerShell_profile.ps1",
			"$([Environment]::GetFolderPath('MyDocuments'))\WindowsPowerShell\profile.ps1"
		)
		
		foreach ($ps51Path in $ps51Paths) {
			$profileDir = Split-Path $ps51Path
			if (Test-Path $profileDir -PathType Container) {
				$profilePaths += @{
					Path = $ps51Path
					Name = "Windows PowerShell 5.1 - $(Split-Path $ps51Path -Leaf)"
					Source = $ps51ProfileSource
				}
			}
		}
	} catch {
		Write-ColorText "{Yellow}[symlink] {Gray}Windows PowerShell 5.1 profiles check failed: $_"
	}
} else {
	Write-ColorText "{Yellow}[symlink] {Gray}PowerShell 5.1 profile source not found: $ps51ProfileSource"
}

# Create symlinks for each profile path
foreach ($profileInfo in $profilePaths) {
	$profilePath = $profileInfo.Path
	$profileName = $profileInfo.Name
	$sourcePath = $profileInfo.Source
	
	# Ensure the directory exists
	$profileDir = Split-Path $profilePath
	if (!(Test-Path $profileDir)) {
		New-Item $profileDir -ItemType Directory -Force -ErrorAction SilentlyContinue | Out-Null
		Write-ColorText "{Blue}[directory] {Green}(created) {Gray}$profileDir"
	}
	
	# Create or update symlink
	if (Test-Path $profilePath) {
		$existingProfile = Get-Item $profilePath -ErrorAction SilentlyContinue
		if ($existingProfile.LinkType -eq 'SymbolicLink') {
			$targetPath = $existingProfile.Target
			if ($targetPath -ne $sourcePath) {
				# Wrong target, update it
				Remove-Item $profilePath -Force -ErrorAction SilentlyContinue
				New-Item -ItemType SymbolicLink -Path $profilePath -Target $sourcePath -Force -ErrorAction SilentlyContinue | Out-Null
				$script:setupSummary.Updated += $profileName
				Write-ColorText "{Blue}[symlink] {Yellow}(updated) {Green}$sourcePath {Yellow}--> {Gray}$profilePath {DarkGray}[$profileName]"
			} else {
				# Correct target, skip
				$script:setupSummary.Exists += $profileName
				Write-ColorText "{Blue}[symlink] {Yellow}(exists) {Gray}$profilePath {DarkGray}[$profileName]"
			}
		} else {
			# Backup existing profile
			if ($Force) {
				$backupPath = "$profilePath.backup.$(Get-Date -Format 'yyyyMMdd-HHmmss')"
				Write-ColorText "{Yellow}[symlink] {Gray}Backing up existing profile: $backupPath"
				Copy-Item $profilePath $backupPath -Force -ErrorAction SilentlyContinue
				Remove-Item $profilePath -Force -ErrorAction SilentlyContinue
				New-Item -ItemType SymbolicLink -Path $profilePath -Target $sourcePath -Force -ErrorAction SilentlyContinue | Out-Null
				$script:setupSummary.Updated += $profileName
				Write-ColorText "{Blue}[symlink] {Green}(created) {Green}$sourcePath {Yellow}--> {Gray}$profilePath {DarkGray}[$profileName]"
			} else {
				$script:setupSummary.Skipped += "$profileName (exists as regular file, use -Force to replace)"
				Write-ColorText "{Yellow}[symlink] {Gray}Skipped $profileName (exists, use -Force to replace)"
			}
		}
	} else {
		# Create new symlink
		New-Item -ItemType SymbolicLink -Path $profilePath -Target $sourcePath -Force -ErrorAction SilentlyContinue | Out-Null
		$script:setupSummary.Created += $profileName
		Write-ColorText "{Blue}[symlink] {Green}(created) {Green}$sourcePath {Yellow}--> {Gray}$profilePath {DarkGray}[$profileName]"
	}
}

if ($profilePaths.Count -eq 0) {
	Write-ColorText "{Yellow}[symlink] {Gray}No PowerShell profiles found to link"
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

	# Set the right git name and email for the user after symlinking (overwrites template values)
	# This ensures user's git config overrides any values from the .gitconfig template file
	if (Get-Command git -ErrorAction SilentlyContinue) {
		if ($gitUserName -and $gitUserMail) {
			git config --global user.name $gitUserName
			git config --global user.email $gitUserMail
		}
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
		# Also update in current session immediately
		$Env:DOTFILES = $PSScriptRoot
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
		# Also update DOTFILES in current session so function wrapper works immediately
		$Env:DOTFILES = $PSScriptRoot
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


