# 🛡️ Profile Execution Guard
# -----------------------------------------------------------------------------------------
# Prevent profile from executing multiple times if loaded from multiple profile paths
# (e.g., both CurrentUserAllHosts and CurrentUserCurrentHost pointing to the same file)
if ($global:ProfileExecuted) {
    return  # Profile already executed in this session, exit early
}
$global:ProfileExecuted = $true

# 👾 Encoding UTF8
$OutputEncoding = [System.Text.Encoding]::UTF8
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8

# 🔆 Tls12
[Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12

$debug = $false


function Debug-Message {
    # If function "Debug-Message_Override" is defined in profile.ps1 file
    # then call it instead.
    if (Get-Command -Name "Debug-Message_Override" -ErrorAction SilentlyContinue) {
        Debug-Message_Override
    } else {
        Write-Host "#######################################" -ForegroundColor Red
        Write-Host "#           Debug mode enabled        #" -ForegroundColor Red
        Write-Host "#          ONLY FOR DEVELOPMENT       #" -ForegroundColor Red
        Write-Host "#                                     #" -ForegroundColor Red
        Write-Host "#       IF YOU ARE NOT DEVELOPING     #" -ForegroundColor Red
        Write-Host "#       JUST RUN \`Update-Profile\`     #" -ForegroundColor Red
        Write-Host "#        to discard all changes       #" -ForegroundColor Red
        Write-Host "#   and update to the latest profile  #" -ForegroundColor Red
        Write-Host "#               version               #" -ForegroundColor Red
        Write-Host "#######################################" -ForegroundColor Red
    }
}

if ($debug) {
    Debug-Message
}


#opt-out of telemetry before doing anything, only if PowerShell is run as admin
if ([bool]([System.Security.Principal.WindowsIdentity]::GetCurrent()).IsSystem) {
    [System.Environment]::SetEnvironmentVariable('POWERSHELL_TELEMETRY_OPTOUT', 'true', [System.EnvironmentVariableTarget]::Machine)
}

# Initial GitHub.com connectivity check (PowerShell 5.1 compatible - no TimeoutSeconds)
$global:canConnectToGitHub = Test-Connection github.com -Count 1 -Quiet

# 🌏 Environment Variables (Windots Enhancement)
# -----------------------------------------------------------------------------------------
# DOTFILES and DOTPOSH are set by Setup.ps1 as system environment variables
# Load them into the current session if they exist
if ([System.Environment]::GetEnvironmentVariable("DOTFILES", "User")) {
    $Env:DOTFILES = [System.Environment]::GetEnvironmentVariable("DOTFILES", "User")
}
if ([System.Environment]::GetEnvironmentVariable("DOTPOSH", "User")) {
    $Env:DOTPOSH = [System.Environment]::GetEnvironmentVariable("DOTPOSH", "User")
}

# 🧩 FastFetch (Windots Enhancement)
# -----------------------------------------------------------------------------------------
# Only run fastfetch on initial profile load, not on reloads
# Use a session variable to track if fastfetch has already run
if (-not $global:FastFetchExecuted) {
    if (Get-Command fastfetch -ErrorAction SilentlyContinue) {
        if (-not [Environment]::GetCommandLineArgs().Contains("-NonInteractive")) {
            fastfetch
            $global:FastFetchExecuted = $true
        }
    }
}
# 🦊 VFox (SDKs Version Manager) (Windots Enhancement)
# -----------------------------------------------------------------------------------------
#if (Get-Command vfox -ErrorAction SilentlyContinue) {
#    Invoke-Expression "$(vfox activate pwsh)"
#}

# Import Modules and External Profiles
# Ensure Terminal-Icons module is installed before importing
if (-not (Get-Module -ListAvailable -Name Terminal-Icons -ErrorAction SilentlyContinue)) {
    try {
        Install-Module -Name Terminal-Icons -Scope CurrentUser -Force -SkipPublisherCheck -ErrorAction Stop
    } catch {
        Write-Warning "Failed to install Terminal-Icons module: $_"
    }
}
Import-Module -Name Terminal-Icons -ErrorAction SilentlyContinue
$ChocolateyProfile = "$env:ChocolateyInstall\helpers\chocolateyProfile.psm1"
if (Test-Path($ChocolateyProfile)) {
    Import-Module "$ChocolateyProfile"
}

# 🎲 DOTPOSH Configuration + Custom Modules + Completion (Windots Enhancement)
# -----------------------------------------------------------------------------------------
if ($Env:DOTPOSH -and (Test-Path $Env:DOTPOSH)) {
    # Load custom modules
    # Exclude modules that require missing dependencies
    $excludedModules = @(
        "Get-IPAddress.psm1",      # Requires: BurntToast
        "Get-OrCreateSecret.psm1"   # Requires: Microsoft.PowerShell.SecretManagement
    )
    foreach ($module in $((Get-ChildItem -Path "$env:DOTPOSH\Modules\*" -Include *.psm1 -ErrorAction SilentlyContinue).FullName)) {
        $moduleName = Split-Path $module -Leaf
        if ($moduleName -notin $excludedModules) {
            Import-Module "$module" -Global -ErrorAction SilentlyContinue
        }
    }
    # Load config scripts
    # Exclude scripts that require missing dependencies
    $excludedScripts = @(
        "posh-aliases.ps1",    # Requires: PSScriptTools
        "posh-readline.ps1"    # Requires: PSFzf, CompletionPredictor, and Catppuccin module
    )
    foreach ($file in $((Get-ChildItem -Path "$env:DOTPOSH\Config\*" -Include *.ps1 -ErrorAction SilentlyContinue).FullName)) {
        $scriptName = Split-Path $file -Leaf
        if ($scriptName -notin $excludedScripts) {
            . "$file" -ErrorAction SilentlyContinue
        }
    }
    # Load completions
    # Exclude completion scripts that require missing dependencies or are not needed
    $global:ExcludedCompletions = @(
        "npm.ps1"  # Exclude npm completions
        #"docker.ps1",    # Exclude docker completions
    )
    if (Test-Path "$env:DOTPOSH\Config\powershell-completions-collection\exec.ps1" -PathType Leaf) {
        . "$env:DOTPOSH\Config\powershell-completions-collection\exec.ps1" -ErrorAction SilentlyContinue
    }
    # Clean up the global variable after use
    Remove-Variable -Name ExcludedCompletions -Scope Global -ErrorAction SilentlyContinue
}

# 🔧 Setup.ps1 Wrapper Function (Windots Enhancement)
# -----------------------------------------------------------------------------------------
# Makes Setup.ps1 callable from anywhere and ensures completions work
# Try multiple methods to find Setup.ps1
$setupScriptPath = $null

# Method 1: Use DOTFILES environment variable (session or user)
if ($Env:DOTFILES -and (Test-Path "$Env:DOTFILES\Setup.ps1")) {
    $setupScriptPath = "$Env:DOTFILES\Setup.ps1"
} elseif ([System.Environment]::GetEnvironmentVariable("DOTFILES", "User") -and (Test-Path "$([System.Environment]::GetEnvironmentVariable('DOTFILES', 'User'))\Setup.ps1")) {
    $dotfilesFromUser = [System.Environment]::GetEnvironmentVariable("DOTFILES", "User")
    $Env:DOTFILES = $dotfilesFromUser
    $setupScriptPath = "$dotfilesFromUser\Setup.ps1"
} elseif (Get-Command Setup.ps1 -ErrorAction SilentlyContinue) {
    # Method 2: Find Setup.ps1 in PATH
    $setupScriptPath = (Get-Command Setup.ps1).Source
} else {
    # Method 3: Search common locations
    $commonPaths = @(
        "$env:USERPROFILE\.dotfiles",
        "$env:USERPROFILE\.repo\windots",
        "$env:USERPROFILE\.repo\Projects\windots"
    )
    foreach ($path in $commonPaths) {
        if (Test-Path "$path\Setup.ps1") {
            $setupScriptPath = "$path\Setup.ps1"
            break
        }
    }
}

# Always create the function (with fallback logic to find Setup.ps1 at runtime)
# Store the path if found for performance, but function will search again if needed
# Use global variable instead of script-scoped so it's accessible from global function
if ($setupScriptPath) {
    $global:W11dotSetupPath = $setupScriptPath
}

# Define function in Global scope so alias can resolve it
function global:W11dot-Setup {
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
        [switch]$WSL,
        [switch]$Updates
    )
    # Try global variable first (set during profile load)
    $scriptPath = $global:W11dotSetupPath

    # If not found, search for Setup.ps1
    if (-not $scriptPath -or -not (Test-Path $scriptPath)) {
        if ($Env:DOTFILES -and (Test-Path "$Env:DOTFILES\Setup.ps1")) {
            $scriptPath = "$Env:DOTFILES\Setup.ps1"
            $global:W11dotSetupPath = $scriptPath  # Cache it
        } elseif ([System.Environment]::GetEnvironmentVariable("DOTFILES", "User") -and (Test-Path "$([System.Environment]::GetEnvironmentVariable('DOTFILES', 'User'))\Setup.ps1")) {
            $scriptPath = "$([System.Environment]::GetEnvironmentVariable('DOTFILES', 'User'))\Setup.ps1"
            $Env:DOTFILES = [System.Environment]::GetEnvironmentVariable("DOTFILES", "User")
            $global:W11dotSetupPath = $scriptPath  # Cache it
        } elseif (Get-Command Setup.ps1 -ErrorAction SilentlyContinue) {
            $scriptPath = (Get-Command Setup.ps1).Source
            $global:W11dotSetupPath = $scriptPath  # Cache it
        } else {
            # Last resort: search common locations
            $commonPaths = @(
                "$env:USERPROFILE\.dotfiles",
                "$env:USERPROFILE\dotfiles",
                "$env:USERPROFILE\Documents\dotfiles",
                "$env:USERPROFILE\Projects\windots"
            )
            foreach ($path in $commonPaths) {
                if (Test-Path "$path\Setup.ps1") {
                    $scriptPath = "$path\Setup.ps1"
                    $global:W11dotSetupPath = $scriptPath  # Cache it
                    break
                }
            }
        }
    }

    if ($scriptPath -and (Test-Path $scriptPath)) {
        & $scriptPath @PSBoundParameters
    } else {
        Write-Error "Setup.ps1 not found. Please run Setup.ps1 first to configure your environment, or set the DOTFILES environment variable."
        return
    }
}

# Remove old alias if it exists and create new one
# Try to use the wrapper script first (more reliable than function)
$wrapperScript = $null
if ($Env:DOTFILES -and (Test-Path "$Env:DOTFILES\w11dot-setup.ps1")) {
    $wrapperScript = "$Env:DOTFILES\w11dot-setup.ps1"
} elseif ([System.Environment]::GetEnvironmentVariable("DOTFILES", "User") -and (Test-Path "$([System.Environment]::GetEnvironmentVariable('DOTFILES', 'User'))\w11dot-setup.ps1")) {
    $wrapperScript = "$([System.Environment]::GetEnvironmentVariable('DOTFILES', 'User'))\w11dot-setup.ps1"
} elseif (Get-Command w11dot-setup.ps1 -ErrorAction SilentlyContinue) {
    $wrapperScript = (Get-Command w11dot-setup.ps1).Source
} elseif ($setupScriptPath -and (Test-Path (Join-Path (Split-Path $setupScriptPath) "w11dot-setup.ps1"))) {
    $wrapperScript = Join-Path (Split-Path $setupScriptPath) "w11dot-setup.ps1"
}

# Create function that calls wrapper script or falls back to Setup.ps1 directly
# Store wrapper script path in global variable for function access
$global:W11dotSetupWrapperPath = $wrapperScript

# PowerShell 5.1 compatible: Use Remove-Item instead of Remove-Alias
if (Get-Alias -Name w11dot-setup -ErrorAction SilentlyContinue) {
    Remove-Item Alias:w11dot-setup -ErrorAction SilentlyContinue -Force
}
# Use internal function name to avoid circular reference
function global:Invoke-W11dotSetup {
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
        [switch]$WSL,
        [switch]$Updates
    )

    # Find Setup.ps1 path
    $setupPath = $null
    if ($global:W11dotSetupWrapperPath -and (Test-Path $global:W11dotSetupWrapperPath)) {
        $setupPath = $global:W11dotSetupWrapperPath
    } elseif ($Env:DOTFILES -and (Test-Path "$Env:DOTFILES\Setup.ps1")) {
        $setupPath = "$Env:DOTFILES\Setup.ps1"
    } elseif (Get-Command Setup.ps1 -ErrorAction SilentlyContinue) {
        $setupPath = (Get-Command Setup.ps1).Source
    } elseif (Get-Command W11dot-Setup -ErrorAction SilentlyContinue) {
        # Fallback to W11dot-Setup function (but it will need gsudo too)
        Write-Warning "Using W11dot-Setup function. Note: Setup.ps1 requires admin privileges."
        W11dot-Setup @PSBoundParameters
        return
    }

    if (-not $setupPath) {
        Write-Error "Setup.ps1 not found. Please run Setup.ps1 first to configure your environment."
        return
    }

    # Updates mode doesn't require admin (Scoop must run as non-admin)
    if ($Updates) {
        # Run Setup.ps1 directly without admin elevation for Updates
        & $setupPath @PSBoundParameters
        return
    }

    # Check if gsudo is available
    $gsudoAvailable = $false
    if (Get-Command gsudo -ErrorAction SilentlyContinue) {
        $gsudoAvailable = $true
    } elseif (Get-Command gsudo.exe -ErrorAction SilentlyContinue) {
        $gsudoAvailable = $true
    }

    # Use gsudo to elevate privileges if available
    if ($gsudoAvailable) {
        Write-Host "Elevating privileges with gsudo (UAC prompt will appear)..." -ForegroundColor Cyan
        # Use gsudo to run Setup.ps1 with admin privileges
        # gsudo will prompt for UAC if needed
        # Build parameter array for PowerShell
        $psArgs = @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", $setupPath)
        if ($Force) { $psArgs += "-Force" }
        if ($Packages) { $psArgs += "-Packages" }
        if ($PowerShell) { $psArgs += "-PowerShell" }
        if ($Git) { $psArgs += "-Git" }
        if ($Symlinks) { $psArgs += "-Symlinks" }
        if ($Environment) { $psArgs += "-Environment" }
        if ($Addons) { $psArgs += "-Addons" }
        if ($VSCode) { $psArgs += "-VSCode" }
        if ($Themes) { $psArgs += "-Themes" }
        if ($Miscellaneous) { $psArgs += "-Miscellaneous" }
        if ($Komorebi) { $psArgs += "-Komorebi" }
        if ($NerdFonts) { $psArgs += "-NerdFonts" }
        if ($WSL) { $psArgs += "-WSL" }
        if ($Updates) { $psArgs += "-Updates" }

        # Use gsudo to run PowerShell with the script and parameters
        # gsudo supports PowerShell script blocks or commands
        $gsudoCmd = if (Get-Command gsudo -ErrorAction SilentlyContinue) { "gsudo" } else { "gsudo.exe" }

        # Run with gsudo - it will handle UAC prompt (PowerShell 5.1 compatible)
        & $gsudoCmd powershell.exe @psArgs
    } else {
        # Fallback: try to run directly (will fail if admin is required)
        Write-Warning "gsudo not found. Attempting to run Setup.ps1 directly (may require admin privileges)."
        Write-Warning "Install gsudo with: winget install gerardog.gsudo"
        & $setupPath @PSBoundParameters
    }
}
# Create alias pointing to the internal function
Set-Alias -Name w11dot-setup -Value Invoke-W11dotSetup -Scope Global -ErrorAction SilentlyContinue

# Load completions for w11dot-setup
$completionFile = $null
if ($Env:DOTPOSH -and (Test-Path "$Env:DOTPOSH\Config\powershell-completions-collection\completions\Setup.ps1")) {
    $completionFile = "$Env:DOTPOSH\Config\powershell-completions-collection\completions\Setup.ps1"
} elseif ($setupScriptPath -and (Test-Path (Join-Path (Split-Path $setupScriptPath) "dotposh\Config\powershell-completions-collection\completions\Setup.ps1"))) {
    $completionFile = Join-Path (Split-Path $setupScriptPath) "dotposh\Config\powershell-completions-collection\completions\Setup.ps1"
} elseif ($Env:DOTFILES -and (Test-Path "$Env:DOTFILES\dotposh\Config\powershell-completions-collection\completions\Setup.ps1")) {
    $completionFile = "$Env:DOTFILES\dotposh\Config\powershell-completions-collection\completions\Setup.ps1"
}
if ($completionFile) {
    . $completionFile -ErrorAction SilentlyContinue
}

# Check for Profile Updates
function Update-Profile {
    # If function "Update-Profile_Override" is defined in profile.ps1 file
    # then call it instead.
    if (Get-Command -Name "Update-Profile_Override" -ErrorAction SilentlyContinue) {
        Update-Profile_Override
    } else {
        try {
            $url = "$repo_root/powershell-profile/main/Microsoft.PowerShell_profile.ps1"
            $oldhash = Get-FileHash $PROFILE
            Invoke-RestMethod $url -OutFile "$env:temp/Microsoft.PowerShell_profile.ps1"
            $newhash = Get-FileHash "$env:temp/Microsoft.PowerShell_profile.ps1"
            if ($newhash.Hash -ne $oldhash.Hash) {
                Copy-Item -Path "$env:temp/Microsoft.PowerShell_profile.ps1" -Destination $PROFILE -Force
                Write-Host "Profile has been updated. Please restart your shell to reflect changes" -ForegroundColor Magenta
            } else {
                Write-Host "Profile is up to date." -ForegroundColor Green
            }
        } catch {
            Write-Error "Unable to check for `$profile updates: $_"
        } finally {
            Remove-Item "$env:temp/Microsoft.PowerShell_profile.ps1" -ErrorAction SilentlyContinue
        }
    }
}


function Update-PowerShell {
    # If function "Update-PowerShell_Override" is defined in profile.ps1 file
    # then call it instead.
    if (Get-Command -Name "Update-PowerShell_Override" -ErrorAction SilentlyContinue) {
        Update-PowerShell_Override
    } else {
        try {
            Write-Host "Checking for PowerShell updates..." -ForegroundColor Cyan
            $updateNeeded = $false
            $currentVersion = $PSVersionTable.PSVersion.ToString()
            $gitHubApiUrl = "https://api.github.com/repos/PowerShell/PowerShell/releases/latest"
            $latestReleaseInfo = Invoke-RestMethod -Uri $gitHubApiUrl
            $latestVersion = $latestReleaseInfo.tag_name.Trim('v')
            if ($currentVersion -lt $latestVersion) {
                $updateNeeded = $true
            }

            if ($updateNeeded) {
                Write-Host "Updating PowerShell..." -ForegroundColor Yellow
                Start-Process powershell.exe -ArgumentList "-NoProfile -Command winget upgrade Microsoft.PowerShell --accept-source-agreements --accept-package-agreements" -Wait -NoNewWindow
                Write-Host "PowerShell has been updated. Please restart your shell to reflect changes" -ForegroundColor Magenta
            } else {
                Write-Host "Your PowerShell is up to date." -ForegroundColor Green
            }
        } catch {
            Write-Error "Failed to update PowerShell. Error: $_"
        }
    }
}


function Clear-Cache {
    # If function "Clear-Cache_Override" is defined in profile.ps1 file
    # then call it instead.
    # -----------------------------------------------------------------
    # If you do override this function, you should should probably duplicate
    # the following calls in your override function, just don't call this
    # function from your override function, otherwise you'll be in an infinate loop.
    if (Get-Command -Name "Clear-Cache_Override" -ErrorAction SilentlyContinue) {
        Clear-Cache_Override
    } else {
        # add clear cache logic here
        Write-Host "Clearing cache..." -ForegroundColor Cyan

        # Clear Windows Prefetch
        Write-Host "Clearing Windows Prefetch..." -ForegroundColor Yellow
        Remove-Item -Path "$env:SystemRoot\Prefetch\*" -Force -ErrorAction SilentlyContinue

        # Clear Windows Temp
        Write-Host "Clearing Windows Temp..." -ForegroundColor Yellow
        Remove-Item -Path "$env:SystemRoot\Temp\*" -Recurse -Force -ErrorAction SilentlyContinue

        # Clear User Temp
        Write-Host "Clearing User Temp..." -ForegroundColor Yellow
        Remove-Item -Path "$env:TEMP\*" -Recurse -Force -ErrorAction SilentlyContinue

        # Clear Internet Explorer Cache
        Write-Host "Clearing Internet Explorer Cache..." -ForegroundColor Yellow
        Remove-Item -Path "$env:LOCALAPPDATA\Microsoft\Windows\INetCache\*" -Recurse -Force -ErrorAction SilentlyContinue

        Write-Host "Cache clearing completed." -ForegroundColor Green
    }
}

# Admin Check and Prompt Customization
$isAdmin = ([Security.Principal.WindowsPrincipal][Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
function prompt {
    if ($isAdmin) { "[" + (Get-Location) + "] # " } else { "[" + (Get-Location) + "] $ " }
}
$adminSuffix = if ($isAdmin) { " [ADMIN]" } else { "" }
$Host.UI.RawUI.WindowTitle = "PowerShell {0}$adminSuffix" -f $PSVersionTable.PSVersion.ToString()

# Utility Functions
function Test-CommandExists {
    param($command)
    $exists = $null -ne (Get-Command $command -ErrorAction SilentlyContinue)
    return $exists
}

# Editor Configuration
if ($EDITOR_Override) {
    $EDITOR = $EDITOR_Override
} else {
    $EDITOR = if (Test-CommandExists nvim) { 'nvim' }
    elseif (Test-CommandExists pvim) { 'pvim' }
    elseif (Test-CommandExists vim) { 'vim' }
    elseif (Test-CommandExists vi) { 'vi' }
    elseif (Test-CommandExists code) { 'code' }
    elseif (Test-CommandExists codium) { 'codium' }
    elseif (Test-CommandExists notepad++) { 'notepad++' }
    elseif (Test-CommandExists sublime_text) { 'sublime_text' }
    else { 'notepad' }
    Set-Alias -Name vim -Value $EDITOR
}
# Quick Access to Editing the Profile
function Edit-Profile {
    # PowerShell 5.1 compatible: $PROFILE is a string, not an object
    vim $PROFILE
}
Set-Alias -Name ep -Value Edit-Profile

function touch($file) { "" | Out-File $file -Encoding ASCII }
function ff($name) {
    Get-ChildItem -recurse -filter "*${name}*" -ErrorAction SilentlyContinue | ForEach-Object {
        Write-Output "$($_.FullName)"
    }
}

# Network Utilities
function Get-PubIP { (Invoke-WebRequest http://ifconfig.me/ip).Content }

# Open WinUtil full-release
function winutil {
    irm https://christitus.com/win | iex
}

# Open WinUtil dev-release
function winutildev {
    # If function "WinUtilDev_Override" is defined in profile.ps1 file
    # then call it instead.
    if (Get-Command -Name "WinUtilDev_Override" -ErrorAction SilentlyContinue) {
        WinUtilDev_Override
    } else {
        irm https://christitus.com/windev | iex
    }
}

# System Utilities
function admin {
    if ($args.Count -gt 0) {
        $argList = $args -join ' '
        Start-Process wt -Verb runAs -ArgumentList "powershell.exe -NoExit -Command $argList"
    } else {
        Start-Process wt -Verb runAs
    }
}

# Set UNIX-like aliases for the admin command, so sudo <command> will run the command with elevated rights.
Set-Alias -Name su -Value admin

# 🔧 Sysinternals Aliases (Windots Enhancement)
# -----------------------------------------------------------------------------------------
# Helper function to find Sysinternals tools in common locations
function Get-SysinternalsPath {
    param([string]$ToolName)

    $commonPaths = @(
        "$env:ProgramFiles\Sysinternals\$ToolName.exe",
        "${env:ProgramFiles(x86)}\Sysinternals\$ToolName.exe",
        "$env:USERPROFILE\Downloads\$ToolName.exe",
        "$env:USERPROFILE\Desktop\$ToolName.exe",
        "$env:LOCALAPPDATA\Microsoft\WindowsApps\$ToolName.exe"
    )

    # Check if tool is in PATH
    $pathTool = Get-Command $ToolName -ErrorAction SilentlyContinue
    if ($pathTool) {
        return $pathTool.Source
    }

    # Check common locations
    foreach ($path in $commonPaths) {
        if (Test-Path $path) {
            return $path
        }
    }

    return $null
}

# Create Sysinternals aliases if tools are found
$sysinternalsTools = @{
    'procexp'       = 'procexp.exe'      # Process Explorer
    'procmon'       = 'procmon.exe'      # Process Monitor
    'autoruns'      = 'autoruns.exe'     # Autoruns
    'tcpview'       = 'tcpview.exe'      # TCPView
    'sysmon'        = 'sysmon.exe'       # Sysmon
    'handle'        = 'handle.exe'       # Handle
    'psexec'        = 'psexec.exe'       # PsExec
    'pslist'        = 'pslist.exe'       # PsList
    'pskill'        = 'pskill.exe'       # PsKill
    'psinfo'        = 'psinfo.exe'       # PsInfo
    'psservice'     = 'psservice.exe'    # PsService
    'psloggedon'    = 'psloggedon.exe'   # PsLoggedOn
    'vmmap'         = 'vmmap.exe'        # VMMap
    'diskmon'       = 'diskmon.exe'      # DiskMon
    'procrun'       = 'procrun.exe'      # ProcRun
    'procdump'      = 'procdump.exe'     # ProcDump
    'strings'       = 'strings.exe'      # Strings
    'sigcheck'      = 'sigcheck.exe'     # Sigcheck
    'accesschk'     = 'accesschk.exe'    # AccessChk
    'accessenum'    = 'accessenum.exe'  # AccessEnum
    'bginfo'        = 'bginfo.exe'       # BGInfo
    'clockres'      = 'clockres.exe'     # ClockRes
    'contig'        = 'contig.exe'       # Contig
    'coreinfo'      = 'coreinfo.exe'     # CoreInfo
    'desktops'      = 'desktops.exe'     # Desktops
    'diskview'      = 'diskview.exe'     # DiskView
    'du'            = 'du.exe'           # Disk Usage
    'efsdump'       = 'efsdump.exe'      # EfsDump
    'findlinks'     = 'findlinks.exe'    # FindLinks
    'logonsessions' = 'logonsessions.exe' # LogonSessions
    'movefile'      = 'movefile.exe'     # MoveFile
    'notmyfault'    = 'notmyfault.exe'    # NotMyFault
    'pendmoves'     = 'pendmoves.exe'    # PendMoves
    'portmon'       = 'portmon.exe'      # PortMon
    'procexp64'     = 'procexp64.exe'     # Process Explorer 64-bit
    'procmon64'     = 'procmon64.exe'    # Process Monitor 64-bit
    'psfile'        = 'psfile.exe'       # PsFile
    'psgetsid'      = 'psgetsid.exe'     # PsGetSid
    'psping'        = 'psping.exe'       # PsPing
    'psshutdown'    = 'psshutdown.exe'    # PsShutdown
    'pssuspend'     = 'pssuspend.exe'    # PsSuspend
    'rammap'        = 'rammap.exe'       # RAMMap
    'regdelnull'    = 'regdelnull.exe'   # RegDelNull
    'ru'            = 'ru.exe'           # Registry Usage
    'sdelete'       = 'sdelete.exe'      # SDelete
    'shareenum'     = 'shareenum.exe'     # ShareEnum
    'shellrunas'    = 'shellrunas.exe'   # ShellRunAs
    'streams'       = 'streams.exe'      # Streams
    'sync'          = 'sync.exe'         # Sync
    'tcpvcon'       = 'tcpvcon.exe'      # TCPView Console
    'vmmap64'       = 'vmmap64.exe'      # VMMap 64-bit
    'whois'         = 'whois.exe'        # Whois
    'winobj'        = 'winobj.exe'       # WinObj
    'zoomit'        = 'zoomit.exe'       # ZoomIt
}

# Store available Sysinternals aliases for tab completion
$global:AvailableSysinternalsAliases = @()

foreach ($alias in $sysinternalsTools.Keys) {
    $toolPath = Get-SysinternalsPath -ToolName $sysinternalsTools[$alias]
    if ($toolPath) {
        Set-Alias -Name $alias -Value $toolPath -Scope Global -ErrorAction SilentlyContinue
        $global:AvailableSysinternalsAliases += $alias
    }
}

# Helper function to list available Sysinternals tools
function Get-SysinternalsTools {
    <#
    .SYNOPSIS
        Lists all available Sysinternals tools that are installed and have aliases configured.
    .DESCRIPTION
        Displays a formatted list of all Sysinternals tools that were found and have aliases created.
        Use this to discover which Sysinternals tools are available on your system.
    .EXAMPLE
        Get-SysinternalsTools
        Lists all available Sysinternals aliases
    #>
    if ($global:AvailableSysinternalsAliases.Count -eq 0) {
        Write-Host "No Sysinternals tools found. Install Sysinternals Suite to enable aliases." -ForegroundColor Yellow
        return
    }

    Write-Host "Available Sysinternals Tools:" -ForegroundColor Cyan
    Write-Host "==============================" -ForegroundColor Cyan
    $global:AvailableSysinternalsAliases | Sort-Object | ForEach-Object {
        $toolName = $sysinternalsTools[$_]
        $description = switch ($_) {
            'procexp' { 'Process Explorer - Advanced task manager' }
            'procmon' { 'Process Monitor - Real-time file/registry/process monitor' }
            'autoruns' { 'Autoruns - Startup program manager' }
            'tcpview' { 'TCPView - Network connection viewer' }
            'sysmon' { 'Sysmon - System activity monitor' }
            'handle' { 'Handle - File handle viewer' }
            'psexec' { 'PsExec - Execute processes remotely' }
            'pslist' { 'PsList - Process list utility' }
            'pskill' { 'PsKill - Process killer' }
            'psinfo' { 'PsInfo - System information' }
            'psservice' { 'PsService - Service viewer/controller' }
            'psloggedon' { 'PsLoggedOn - See who is logged on' }
            'vmmap' { 'VMMap - Virtual memory analyzer' }
            'procdump' { 'ProcDump - Process dump utility' }
            'sigcheck' { 'Sigcheck - File signature verifier' }
            'accesschk' { 'AccessChk - Access permissions checker' }
            default { "Sysinternals $toolName" }
        }
        Write-Host "  $_" -ForegroundColor Green -NoNewline
        Write-Host " - $description" -ForegroundColor Gray
    }
    Write-Host ""
    Write-Host "Tip: Use tab completion when typing these commands!" -ForegroundColor Yellow
}
Set-Alias -Name sysinternals -Value Get-SysinternalsTools
Set-Alias -Name sysint -Value Get-SysinternalsTools

function uptime {
    try {
        # find date/time format
        $dateFormat = [System.Globalization.CultureInfo]::CurrentCulture.DateTimeFormat.ShortDatePattern
        $timeFormat = [System.Globalization.CultureInfo]::CurrentCulture.DateTimeFormat.LongTimePattern

        # check powershell version
        if ($PSVersionTable.PSVersion.Major -eq 5) {
            $lastBoot = (Get-WmiObject win32_operatingsystem).LastBootUpTime
            $bootTime = [System.Management.ManagementDateTimeConverter]::ToDateTime($lastBoot)

            # reformat lastBoot
            $lastBoot = $bootTime.ToString("$dateFormat $timeFormat")
        } else {
            # the Get-Uptime cmdlet was introduced in PowerShell 6.0
            $lastBoot = (Get-Uptime -Since).ToString("$dateFormat $timeFormat")
            $bootTime = [System.DateTime]::ParseExact($lastBoot, "$dateFormat $timeFormat", [System.Globalization.CultureInfo]::InvariantCulture)
        }

        # Format the start time
        $formattedBootTime = $bootTime.ToString("dddd, MMMM dd, yyyy HH:mm:ss", [System.Globalization.CultureInfo]::InvariantCulture) + " [$lastBoot]"
        Write-Host "System started on: $formattedBootTime" -ForegroundColor DarkGray

        # calculate uptime
        $uptime = (Get-Date) - $bootTime

        # Uptime in days, hours, minutes, and seconds
        $days = $uptime.Days
        $hours = $uptime.Hours
        $minutes = $uptime.Minutes
        $seconds = $uptime.Seconds

        # Uptime output
        Write-Host ("Uptime: {0} days, {1} hours, {2} minutes, {3} seconds" -f $days, $hours, $minutes, $seconds) -ForegroundColor Blue

    } catch {
        Write-Error "An error occurred while retrieving system uptime."
    }
}

function reload-profile {
    # Reset the profile execution guard to allow reload
    # Note: FastFetch will NOT run on reload due to the $global:FastFetchExecuted guard
    # This prevents double execution when reloading the profile
    $global:ProfileExecuted = $false
    # Reload the profile
    & $profile
}

# 🗂️ yazi File Manager (Windots Enhancement)
# -----------------------------------------------------------------------------------------
if (Get-Command yazi -ErrorAction SilentlyContinue) {
    function y {
        $tmp = [System.IO.Path]::GetTempFileName()
        yazi $args --cwd-file="$tmp"
        $cwd = Get-Content $tmp -ErrorAction SilentlyContinue
        if (-not [String]::IsNullOrEmpty($cwd) -and $cwd -ne $PWD.Path) {
            Set-Location -LiteralPath $cwd
        }
        Remove-Item -Path $tmp -ErrorAction SilentlyContinue
    }
}

function unzip ($file) {
    Write-Output("Extracting", $file, "to", $pwd)
    $fullFile = Get-ChildItem -Path $pwd -Filter $file | ForEach-Object { $_.FullName }
    Expand-Archive -Path $fullFile -DestinationPath $pwd
}
function hb {
    if ($args.Length -eq 0) {
        Write-Error "No file path specified."
        return
    }

    $FilePath = $args[0]

    if (Test-Path $FilePath) {
        $Content = Get-Content $FilePath -Raw
    } else {
        Write-Error "File path does not exist."
        return
    }

    $uri = "http://bin.christitus.com/documents"
    try {
        $response = Invoke-RestMethod -Uri $uri -Method Post -Body $Content -ErrorAction Stop
        $hasteKey = $response.key
        $url = "http://bin.christitus.com/$hasteKey"
        Set-Clipboard $url
        Write-Output "$url copied to clipboard."
    } catch {
        Write-Error "Failed to upload the document. Error: $_"
    }
}
function grep($regex, $dir) {
    if ( $dir ) {
        Get-ChildItem $dir | select-string $regex
        return
    }
    $input | select-string $regex
}

function df {
    get-volume
}

function sed($file, $find, $replace) {
    (Get-Content $file).replace("$find", $replace) | Set-Content $file
}

function which($name) {
    Get-Command $name | Select-Object -ExpandProperty Definition
}

function export($name, $value) {
    set-item -force -path "env:$name" -value $value
}

function pkill($name) {
    Get-Process $name -ErrorAction SilentlyContinue | Stop-Process
}

function pgrep($name) {
    Get-Process $name
}

function head {
    param($Path, $n = 10)
    Get-Content $Path -Head $n
}

function tail {
    param($Path, $n = 10, [switch]$f = $false)
    Get-Content $Path -Tail $n -Wait:$f
}

# Quick File Creation
function nf { param($name) New-Item -ItemType "file" -Path . -Name $name }

# Directory Management
function mkcd { param($dir) mkdir $dir -Force; Set-Location $dir }

function trash($path) {
    $fullPath = (Resolve-Path -Path $path).Path

    if (Test-Path $fullPath) {
        $item = Get-Item $fullPath

        if ($item.PSIsContainer) {
            # Handle directory
            $parentPath = $item.Parent.FullName
        } else {
            # Handle file
            $parentPath = $item.DirectoryName
        }

        $shell = New-Object -ComObject 'Shell.Application'
        $shellItem = $shell.NameSpace($parentPath).ParseName($item.Name)

        if ($item) {
            $shellItem.InvokeVerb('delete')
            Write-Host "Item '$fullPath' has been moved to the Recycle Bin."
        } else {
            Write-Host "Error: Could not find the item '$fullPath' to trash."
        }
    } else {
        Write-Host "Error: Item '$fullPath' does not exist."
    }
}

### Quality of Life Aliases

# Navigation Shortcuts
function docs {
    $docs = if (([Environment]::GetFolderPath("MyDocuments"))) { ([Environment]::GetFolderPath("MyDocuments")) } else { $HOME + "\Documents" }
    Set-Location -Path $docs
}

function dtop {
    $dtop = if ([Environment]::GetFolderPath("Desktop")) { [Environment]::GetFolderPath("Desktop") } else { $HOME + "\Documents" }
    Set-Location -Path $dtop
}

# Simplified Process Management
function k9 { Stop-Process -Name $args[0] }

# Enhanced Listing
function la { Get-ChildItem | Format-Table -AutoSize }
function ll { Get-ChildItem -Force | Format-Table -AutoSize }

# Git Shortcuts
function gs { git status }

function ga { git add . }

function gc { param($m) git commit -m "$m" }

function gpush { git push }

function gpull { git pull }

function g { __zoxide_z github }

function gcl { git clone "$args" }

function gcom {
    git add .
    git commit -m "$args"
}
function lazyg {
    git add .
    git commit -m "$args"
    git push
}

function git-qc {
    param(
        [Parameter(Position = 0)]
        [string]$CommitMessage
    )

    git aa
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed to add files. Aborting."
        return
    }

    if ([string]::IsNullOrWhiteSpace($CommitMessage)) {
        $CommitMessage = Read-Host "Enter commit message"
        if ([string]::IsNullOrWhiteSpace($CommitMessage)) {
            Write-Warning "Commit message is empty. Aborting."
            return
        }
    }

    git cm "$CommitMessage"
    if ($LASTEXITCODE -ne 0) {
        Write-Error "Failed to commit. Aborting."
        return
    }

    git push
}
Set-Alias -Name qc -Value git-qc
Set-Alias -Name gitqc -Value git-qc

# Quick Access to System Information
function sysinfo { Get-ComputerInfo }

# Networking Utilities
function flushdns {
    Clear-DnsClientCache
    Write-Host "DNS has been flushed"
}

# Clipboard Utilities
function cpy { Set-Clipboard $args[0] }

function pst { Get-Clipboard }

# Enhanced PowerShell Experience
# Enhanced PSReadLine Configuration
$PSReadLineOptions = @{
    EditMode                      = 'Windows'
    HistoryNoDuplicates           = $true
    HistorySearchCursorMovesToEnd = $true
    Colors                        = @{
        Command   = '#87CEEB'  # SkyBlue (pastel)
        Parameter = '#98FB98'  # PaleGreen (pastel)
        Operator  = '#FFB6C1'  # LightPink (pastel)
        Variable  = '#DDA0DD'  # Plum (pastel)
        String    = '#FFDAB9'  # PeachPuff (pastel)
        Number    = '#B0E0E6'  # PowderBlue (pastel)
        Type      = '#F0E68C'  # Khaki (pastel)
        Comment   = '#D3D3D3'  # LightGray (pastel)
        Keyword   = '#8367c7'  # Violet (pastel)
        Error     = '#FF6347'  # Tomato (keeping it close to red for visibility)
    }
    # PredictionSource and PredictionViewStyle not available in PowerShell 5.1
    BellStyle                     = 'None'
}
Set-PSReadLineOption @PSReadLineOptions

# Custom key handlers
Set-PSReadLineKeyHandler -Key UpArrow -Function HistorySearchBackward
Set-PSReadLineKeyHandler -Key DownArrow -Function HistorySearchForward
Set-PSReadLineKeyHandler -Key Tab -Function MenuComplete
Set-PSReadLineKeyHandler -Chord 'Ctrl+d' -Function DeleteChar
Set-PSReadLineKeyHandler -Chord 'Ctrl+w' -Function BackwardDeleteWord
Set-PSReadLineKeyHandler -Chord 'Alt+d' -Function DeleteWord
Set-PSReadLineKeyHandler -Chord 'Ctrl+LeftArrow' -Function BackwardWord
Set-PSReadLineKeyHandler -Chord 'Ctrl+RightArrow' -Function ForwardWord
Set-PSReadLineKeyHandler -Chord 'Ctrl+z' -Function Undo
Set-PSReadLineKeyHandler -Chord 'Ctrl+y' -Function Redo

# Custom functions for PSReadLine
Set-PSReadLineOption -AddToHistoryHandler {
    param($line)
    $sensitive = @('password', 'secret', 'token', 'apikey', 'connectionstring')
    $hasSensitive = $sensitive | Where-Object { $line -match $_ }
    return ($null -eq $hasSensitive)
}

# Set-PredictionSource function removed - PredictionSource not available in PowerShell 5.1
# MaximumHistoryCount is still available
if (Get-Module PSReadLine -ErrorAction SilentlyContinue) {
    Set-PSReadLineOption -MaximumHistoryCount 10000 -ErrorAction SilentlyContinue
}

# Custom completion for common commands
$scriptblock = {
    param($wordToComplete, $commandAst, $cursorPosition)
    $customCompletions = @{
        'git'  = @('status', 'add', 'commit', 'push', 'pull', 'clone', 'checkout', 'aa', 'cm', 'qc', 'gitqc')
        'npm'  = @('install', 'start', 'run', 'test', 'build')
        'deno' = @('run', 'compile', 'bundle', 'test', 'lint', 'fmt', 'cache', 'info', 'doc', 'upgrade')
    }

    $command = $commandAst.CommandElements[0].Value
    if ($customCompletions.ContainsKey($command)) {
        $customCompletions[$command] | Where-Object { $_ -like "$wordToComplete*" } | ForEach-Object {
            [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
        }
    }
}
Register-ArgumentCompleter -Native -CommandName git, npm, deno -ScriptBlock $scriptblock

$scriptblock = {
    param($wordToComplete, $commandAst, $cursorPosition)
    dotnet complete --position $cursorPosition $commandAst.ToString() |
    ForEach-Object {
        [System.Management.Automation.CompletionResult]::new($_, $_, 'ParameterValue', $_)
    }
}
Register-ArgumentCompleter -Native -CommandName dotnet -ScriptBlock $scriptblock

# Note: Sysinternals aliases automatically support tab completion via PowerShell's built-in
# alias completion. Type part of an alias name and press Tab to complete it.
# Use 'Get-SysinternalsTools' or 'sysinternals' to list all available tools.

if (Get-Command -Name "Get-Theme_Override" -ErrorAction SilentlyContinue) {
    Get-Theme_Override
} else {
    # Use dotposh config if available, otherwise fallback to default
    if ($Env:DOTPOSH -and (Test-Path "$Env:DOTPOSH\posh-zen.toml")) {
        oh-my-posh init powershell --config "$Env:DOTPOSH\posh-zen.toml" | Invoke-Expression
        $Env:POSH_GIT_ENABLED = $true
    } else {
        oh-my-posh init powershell --config https://raw.githubusercontent.com/JanDeDobbeleer/oh-my-posh/main/themes/cobalt2.omp.json | Invoke-Expression
    }
}

if (Get-Command zoxide -ErrorAction SilentlyContinue) {
    # Use DOTFILES for zoxide data directory if available (Windots Enhancement)
    if ($Env:DOTFILES) {
        $Env:_ZO_DATA_DIR = "$Env:DOTFILES"
    }
    Invoke-Expression (& { (zoxide init --cmd z powershell | Out-String) })
} else {
    Write-Host "zoxide command not found. Attempting to install via winget..."
    try {
        winget install -e --id ajeetdsouza.zoxide
        Write-Host "zoxide installed successfully. Initializing..."
        if ($Env:DOTFILES) {
            $Env:_ZO_DATA_DIR = "$Env:DOTFILES"
        }
        Invoke-Expression (& { (zoxide init --cmd z powershell | Out-String) })
    } catch {
        Write-Error "Failed to install zoxide. Error: $_"
    }
}

Import-Module PowerShellGet
# Help Function (PowerShell 5.1 compatible - uses Write-Host instead of $PSStyle)
function Show-Help {
    Write-Host "PowerShell Profile Help" -ForegroundColor Cyan
    Write-Host "=======================" -ForegroundColor Yellow
    Write-Host "Update-Profile" -ForegroundColor Green -NoNewline; Write-Host " - Checks for profile updates from a remote repository and updates if necessary."
    Write-Host "Update-PowerShell" -ForegroundColor Green -NoNewline; Write-Host " - Checks for the latest PowerShell release and updates if a new version is available."
    Write-Host "Edit-Profile" -ForegroundColor Green -NoNewline; Write-Host " - Opens the current user's profile for editing using the configured editor."
    Write-Host ""
    Write-Host "Git Shortcuts" -ForegroundColor Cyan
    Write-Host "=======================" -ForegroundColor Yellow
    Write-Host "g" -ForegroundColor Green -NoNewline; Write-Host " - Changes to the GitHub directory."
    Write-Host "ga" -ForegroundColor Green -NoNewline; Write-Host " - Shortcut for 'git add .'."
    Write-Host "gc" -ForegroundColor Green -NoNewline; Write-Host " <message> - Shortcut for 'git commit -m'."
    Write-Host "gcom" -ForegroundColor Green -NoNewline; Write-Host " <message> - Adds all changes and commits with the specified message."
    Write-Host "gp" -ForegroundColor Green -NoNewline; Write-Host " - Shortcut for 'git push'."
    Write-Host "gs" -ForegroundColor Green -NoNewline; Write-Host " - Shortcut for 'git status'."
    Write-Host "lazyg" -ForegroundColor Green -NoNewline; Write-Host " <message> - Adds all changes, commits with the specified message, and pushes to the remote repository."
    Write-Host ""
    Write-Host "Shortcuts" -ForegroundColor Cyan
    Write-Host "=======================" -ForegroundColor Yellow
    Write-Host "cpy" -ForegroundColor Green -NoNewline; Write-Host " <text> - Copies the specified text to the clipboard."
    Write-Host "df" -ForegroundColor Green -NoNewline; Write-Host " - Displays information about volumes."
    Write-Host "docs" -ForegroundColor Green -NoNewline; Write-Host " - Changes the current directory to the user's Documents folder."
    Write-Host "dtop" -ForegroundColor Green -NoNewline; Write-Host " - Changes the current directory to the user's Desktop folder."
    Write-Host "ep" -ForegroundColor Green -NoNewline; Write-Host " - Opens the profile for editing."
    Write-Host "export" -ForegroundColor Green -NoNewline; Write-Host " <name> <value> - Sets an environment variable."
    Write-Host "ff" -ForegroundColor Green -NoNewline; Write-Host " <name> - Finds files recursively with the specified name."
    Write-Host "flushdns" -ForegroundColor Green -NoNewline; Write-Host " - Clears the DNS cache."
    Write-Host "Get-PubIP" -ForegroundColor Green -NoNewline; Write-Host " - Retrieves the public IP address of the machine."
    Write-Host "grep" -ForegroundColor Green -NoNewline; Write-Host " <regex> [dir] - Searches for a regex pattern in files within the specified directory or from the pipeline input."
    Write-Host "hb" -ForegroundColor Green -NoNewline; Write-Host " <file> - Uploads the specified file's content to a hastebin-like service and returns the URL."
    Write-Host "head" -ForegroundColor Green -NoNewline; Write-Host " <path> [n] - Displays the first n lines of a file (default 10)."
    Write-Host "k9" -ForegroundColor Green -NoNewline; Write-Host " <name> - Kills a process by name."
    Write-Host "la" -ForegroundColor Green -NoNewline; Write-Host " - Lists all files in the current directory with detailed formatting."
    Write-Host "ll" -ForegroundColor Green -NoNewline; Write-Host " - Lists all files, including hidden, in the current directory with detailed formatting."
    Write-Host "mkcd" -ForegroundColor Green -NoNewline; Write-Host " <dir> - Creates and changes to a new directory."
    Write-Host "nf" -ForegroundColor Green -NoNewline; Write-Host " <name> - Creates a new file with the specified name."
    Write-Host "pgrep" -ForegroundColor Green -NoNewline; Write-Host " <name> - Lists processes by name."
    Write-Host "pkill" -ForegroundColor Green -NoNewline; Write-Host " <name> - Kills processes by name."
    Write-Host "reload-profile" -ForegroundColor Green -NoNewline; Write-Host " - Reloads the current user's PowerShell profile."
    Write-Host "sed" -ForegroundColor Green -NoNewline; Write-Host " <file> <find> <replace> - Replaces text in a file."
    Write-Host "sysinfo" -ForegroundColor Green -NoNewline; Write-Host " - Displays detailed system information."
    Write-Host "tail" -ForegroundColor Green -NoNewline; Write-Host " <path> [n] - Displays the last n lines of a file (default 10)."
    Write-Host "touch" -ForegroundColor Green -NoNewline; Write-Host " <file> - Creates a new empty file."
    Write-Host "unzip" -ForegroundColor Green -NoNewline; Write-Host " <file> - Extracts a zip file to the current directory."
    Write-Host "uptime" -ForegroundColor Green -NoNewline; Write-Host " - Displays the system uptime."
    Write-Host "which" -ForegroundColor Green -NoNewline; Write-Host " <name> - Shows the path of the command."
    Write-Host "winutil" -ForegroundColor Green -NoNewline; Write-Host " - Runs the latest WinUtil full-release script from Chris Titus Tech."
    Write-Host "winutildev" -ForegroundColor Green -NoNewline; Write-Host " - Runs the latest WinUtil pre-release script from Chris Titus Tech."
    Write-Host "=======================" -ForegroundColor Yellow
    Write-Host ""
    Write-Host "Use " -NoNewline; Write-Host "Show-Help" -ForegroundColor Magenta -NoNewline; Write-Host " to display this help message."
}

if (Test-Path "$PSScriptRoot\CTTcustom.ps1") {
    Invoke-Expression -Command "& `"$PSScriptRoot\CTTcustom.ps1`""
}

Write-Host "Use 'Show-Help' to display help" -ForegroundColor Yellow
