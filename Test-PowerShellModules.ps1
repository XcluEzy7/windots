# Test script to verify PowerShell module installation
# This script tests the remaining modules that need to be installed via PowerShell Gallery

param(
    [switch]$TestAll,
    [string[]]$ModuleNames
)

# Color output function
function Write-ColorText {
    param([string]$Text)
    Write-Host $Text -NoNewline
}

# Test NuGet provider in PowerShell 5.1 (modules must be installed in PowerShell 5.1, not PowerShell 7.x)
Write-ColorText "`n{Blue}=== Testing NuGet Provider (PowerShell 5.1) ==={Gray}`n"
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
if ($nugetCheckResult -match '^EXISTS:') {
    $nugetVersion = $nugetCheckResult -replace 'EXISTS:', ''
    Write-ColorText "{Green}✓ NuGet provider found: {Yellow}$nugetVersion {Gray}(PowerShell 5.1)`n"
} else {
    Write-ColorText "{Red}✗ NuGet provider not found or version too old {Gray}(PowerShell 5.1)`n"
    Write-ColorText "{Yellow}  The Setup.ps1 script should install this automatically{Gray}`n"
}

# Test PSGallery in PowerShell 5.1
Write-ColorText "`n{Blue}=== Testing PowerShell Gallery (PowerShell 5.1) ==={Gray}`n"
$psGalleryCheckScript = @"
`$psGallery = Get-PSRepository -Name PSGallery -ErrorAction SilentlyContinue
if (`$psGallery) {
    Write-Output "EXISTS:`$(`$psGallery.SourceLocation)|`$(`$psGallery.InstallationPolicy)"
} else {
    Write-Output 'NOT_FOUND'
}
"@

$psGalleryCheckResult = & powershell.exe -NoProfile -Command $psGalleryCheckScript
if ($psGalleryCheckResult -match '^EXISTS:') {
    $galleryInfo = $psGalleryCheckResult -replace 'EXISTS:', ''
    $parts = $galleryInfo -split '\|'
    Write-ColorText "{Green}✓ PSGallery registered: {Yellow}$($parts[0]){Gray}`n"
    Write-ColorText "  Installation Policy: {Yellow}$($parts[1]){Gray}`n"
} else {
    Write-ColorText "{Red}✗ PSGallery not registered {Gray}(PowerShell 5.1)`n"
}

# List of remaining modules to test
$remainingModules = @(
    "CompletionPredictor",
    "DotNetVersionLister",
    "Microsoft.PowerShell.SecretManagement",
    "Microsoft.PowerShell.SecretStore",
    "npm-completion",
    "posh-git",
    "powershell-yaml",
    "PSFzf",
    "PSParseHTML",
    "PSScriptAnalyzer",
    "PSScriptTools",
    "PSToml"
)

# Determine which modules to test
$modulesToTest = if ($ModuleNames) {
    $ModuleNames
} elseif ($TestAll) {
    $remainingModules
} else {
    # Interactive selection
    Write-ColorText "`n{Blue}=== Select Modules to Test ==={Gray}`n"
    for ($i = 0; $i -lt $remainingModules.Count; $i++) {
        Write-ColorText "{Cyan}[$($i+1)]{Gray} $($remainingModules[$i])`n"
    }
    Write-ColorText "{Cyan}[A]{Gray} Test All`n"
    Write-ColorText "{Cyan}[Q]{Gray} Quit`n`n"
    $selection = Read-Host "Enter selection (comma-separated numbers, A for all, or Q to quit)"
    
    if ($selection -eq 'Q' -or $selection -eq 'q') {
        Write-ColorText "{Yellow}Exiting...{Gray}`n"
        return
    } elseif ($selection -eq 'A' -or $selection -eq 'a') {
        $remainingModules
    } else {
        $indices = $selection -split ',' | ForEach-Object { [int]$_.Trim() - 1 }
        $indices | ForEach-Object { $remainingModules[$_] }
    }
}

if (-not $modulesToTest) {
    Write-ColorText "{Yellow}No modules selected for testing{Gray}`n"
    return
}

# Test each module
Write-ColorText "`n{Blue}=== Testing Module Availability ==={Gray}`n"
$results = @()

foreach ($moduleName in $modulesToTest) {
    Write-ColorText "`n{Blue}Testing: {Magenta}$moduleName{Gray}`n"
    
    # Check if module exists in PSGallery (check in PowerShell 5.1)
    $checkModuleScript = @"
try {
	`$moduleInfo = Find-Module -Name '$moduleName' -ErrorAction Stop
	if (`$moduleInfo) {
		Write-Output "FOUND:`$(`$moduleInfo.Version)|`$(`$moduleInfo.Author)"
		
		# Check if already installed
		`$installed = Get-InstalledModule -Name '$moduleName' -ErrorAction SilentlyContinue
		if (`$installed) {
			Write-Output "INSTALLED:`$(`$installed.Version)"
		} else {
			Write-Output "NOT_INSTALLED"
		}
	}
} catch {
	Write-Output "NOT_FOUND:`$(`$_.Exception.Message)"
}
"@
    
    try {
        $moduleCheckResult = & powershell.exe -NoProfile -Command $checkModuleScript
        $found = $false
        $installed = $false
        $moduleVersion = ""
        $moduleAuthor = ""
        $installedVersion = ""
        
        foreach ($line in $moduleCheckResult) {
            if ($line -match '^FOUND:') {
                $found = $true
                $info = $line -replace 'FOUND:', ''
                $parts = $info -split '\|'
                $moduleVersion = $parts[0]
                $moduleAuthor = $parts[1]
            } elseif ($line -match '^INSTALLED:') {
                $installed = $true
                $installedVersion = $line -replace 'INSTALLED:', ''
            } elseif ($line -eq 'NOT_INSTALLED') {
                $installed = $false
            } elseif ($line -match '^NOT_FOUND:') {
                $errorMsg = $line -replace 'NOT_FOUND:', ''
                Write-ColorText "  {Red}✗ Not found in PSGallery: {DarkGray}$errorMsg{Gray}`n"
                $results += [PSCustomObject]@{
                    Module = $moduleName
                    Status = "Not Found"
                    Version = "N/A"
                    CanInstall = $false
                }
            }
        }
        
        if ($found) {
            Write-ColorText "  {Green}✓ Found in PSGallery{Gray}`n"
            Write-ColorText "    Version: {Yellow}$moduleVersion{Gray}`n"
            Write-ColorText "    Author: {Yellow}$moduleAuthor{Gray}`n"
            
            if ($installed) {
                Write-ColorText "    {Cyan}→ Already installed: {Yellow}$installedVersion {Gray}(PowerShell 5.1)`n"
                $results += [PSCustomObject]@{
                    Module = $moduleName
                    Status = "Already Installed"
                    Version = $installedVersion
                    CanInstall = $true
                }
            } else {
                Write-ColorText "    {Yellow}→ Not installed (can be installed in PowerShell 5.1){Gray}`n"
                $results += [PSCustomObject]@{
                    Module = $moduleName
                    Status = "Available"
                    Version = $moduleVersion
                    CanInstall = $true
                }
            }
        }
    } catch {
        Write-ColorText "  {Red}✗ Error checking module: {DarkGray}$($_.Exception.Message){Gray}`n"
        $results += [PSCustomObject]@{
            Module = $moduleName
            Status = "Error"
            Version = "N/A"
            CanInstall = $false
        }
    }
}

# Summary
Write-ColorText "`n{Blue}=== Test Summary ==={Gray}`n"
$results | Format-Table -AutoSize

# Offer to install available modules
$availableModules = $results | Where-Object { $_.CanInstall -and $_.Status -eq "Available" }
if ($availableModules) {
    Write-ColorText "`n{Blue}=== Installation Test ==={Gray}`n"
    $installChoice = Read-Host "Would you like to test installing one module? (Y/N)"
    if ($installChoice -eq 'Y' -or $installChoice -eq 'y') {
        Write-ColorText "`n{Cyan}Available modules:{Gray}`n"
        for ($i = 0; $i -lt $availableModules.Count; $i++) {
            Write-ColorText "{Cyan}[$($i+1)]{Gray} $($availableModules[$i].Module) (v$($availableModules[$i].Version))`n"
        }
        $moduleIndex = Read-Host "Enter module number to test install"
        $selectedModule = $availableModules[[int]$moduleIndex - 1]
        
        if ($selectedModule) {
            Write-ColorText "`n{Yellow}Attempting to install: {Magenta}$($selectedModule.Module) {Gray}(in PowerShell 5.1)`n"
            try {
                $installTestScript = @"
try {
	[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
	Install-Module -Name '$($selectedModule.Module)' -Scope CurrentUser -Force -AllowClobber -SkipPublisherCheck -ErrorAction Stop
	`$verify = Get-InstalledModule -Name '$($selectedModule.Module)' -ErrorAction SilentlyContinue
	if (`$verify) {
		Write-Output "SUCCESS:`$(`$verify.Name)|`$(`$verify.Version)|`$(`$verify.InstalledLocation)"
	} else {
		Write-Output 'VERIFY_FAILED'
	}
} catch {
	Write-Output "ERROR:`$(`$_.Exception.Message)"
}
"@
                $installTestResult = & powershell.exe -NoProfile -Command $installTestScript
                
                if ($installTestResult -match '^SUCCESS:') {
                    $successInfo = $installTestResult -replace 'SUCCESS:', ''
                    $parts = $successInfo -split '\|'
                    Write-ColorText "{Green}✓ Successfully installed: {Yellow}$($parts[0]) v$($parts[1]) {Gray}(PowerShell 5.1)`n"
                    Write-ColorText "{Cyan}  Location: {Yellow}$($parts[2]){Gray}`n"
                } elseif ($installTestResult -eq 'VERIFY_FAILED') {
                    Write-ColorText "{Red}✗ Installation completed but module not found{Gray}`n"
                } else {
                    $errorMsg = $installTestResult -replace 'ERROR:', ''
                    Write-ColorText "{Red}✗ Installation failed: {DarkGray}$errorMsg{Gray}`n"
                    Write-ColorText "{Yellow}  This is the error that needs to be resolved{Gray}`n"
                }
            } catch {
                Write-ColorText "{Red}✗ Installation failed: {DarkGray}$($_.Exception.Message){Gray}`n"
                Write-ColorText "{Yellow}  This is the error that needs to be resolved{Gray}`n"
            }
        }
    }
}

Write-ColorText "`n{Blue}=== Next Steps ==={Gray}`n"
Write-ColorText "1. If NuGet provider test failed, run Setup.ps1 to install it in PowerShell 5.1{Gray}`n"
Write-ColorText "2. If modules are available but installation fails, check the error message above{Gray}`n"
Write-ColorText "3. Remember: Modules are installed in PowerShell 5.1, not PowerShell 7.x{Gray}`n"
Write-ColorText "4. Once working, you can uncomment modules in appList.json{Gray}`n"
Write-ColorText "`n"

