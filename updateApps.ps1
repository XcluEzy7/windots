<#
.SYNOPSIS
    Updates installed applications from appList.json using appropriate package managers.
    OPTIMIZED VERSION: Batch updates, Scope handling, PS5.1 Compat, Gum UI.

.DESCRIPTION
    This script updates packages listed in appList.json using Winget, Chocolatey, or Scoop.
    - Scoop User Apps: Runs in non-admin context (batches updates).
    - Scoop Global Apps: Runs in admin context (batches updates).
    - Winget/Choco: Require admin context.

.PARAMETER Scoop
    Update only Scoop packages. Alias: -scp

.PARAMETER Winget
    Update only Winget packages. Alias: -win

.PARAMETER Choco
    Update only Chocolatey packages. Alias: -cho

.PARAMETER All
    Update all packages from all managers. Alias: -a (default if no switch specified)

.NOTES
    Optimized for batch processing and global scope support.
    Compatible with PowerShell 5.1 and 7+.
#>

[CmdletBinding()]
Param(
    [Alias('scp')][switch]$Scoop,
    [Alias('win')][switch]$Winget,
    [Alias('cho')][switch]$Choco,
    [Alias('a')][switch]$All,
    [Alias('c')][switch]$Check,
    [ValidateSet('System', 'User')][string]$Target
)

$ErrorActionPreference = "Continue"

#region Configuration
$script:ScriptRoot = $PSScriptRoot
if (!$script:ScriptRoot) {
    $script:ScriptRoot = Split-Path -Parent $MyInvocation.MyCommand.Path
}

# Dynamic Shell Detection for PS 5.1 / 7 compatibility
$script:CurrentShell = (Get-Process -Id $PID).Path
if (-not $script:CurrentShell) {
    # Fallback if detection fails
    $script:CurrentShell = if ($PSVersionTable.PSVersion.Major -ge 7) { "pwsh" } else { "powershell" }
}

# --- ORCHESTRATOR LOGIC (Split Pane) ---
# Only run orchestration if no specific target is set, AND not in Check mode, AND not selecting specific managers
if (-not $Target -and -not $Check -and -not ($Scoop -or $Winget -or $Choco)) {

    # We want to run System (Winget+Choco) and User (Scoop) in parallel split panes.
    # Logic:
    # 1. Detect Terminal (WT or WezTerm).
    # 2. Launch Split View calling this script with -Target System and -Target User.

    $scriptPath = $MyInvocation.MyCommand.Path

    # Command to run this script in a specific target mode
    # We use -NoExit so the pane stays open for review if it fails, or we handle pause internally
    # actually better to handle pause internally.
    $cmdSystem = "`"$script:CurrentShell`" -NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`" -Target System"
    $cmdUser = "`"$script:CurrentShell`" -NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`" -Target User"

    # CASE A: Windows Terminal
    if ($env:WT_SESSION) {
        Write-Host "Detected Windows Terminal. Splitting panes..." -ForegroundColor Cyan
        # Split: Current pane runs System, New pane (split) runs User.
        # w = 0 (current window), split-pane -V (Vertical), command...
        # Note: We need to launch the NEW pane first, then replace the CURRENT pane or run in current.
        # Actually simpler: Launch a whole new layout in the current tab?
        # wt split-pane -V command ; move-focus left ; command

        # Approach:
        # 1. Run 'wt -w 0 split-pane -V $cmdUser' (Opens right pane with User)
        # 2. Run '$cmdSystem' in current process (Left pane)

        Start-Process "wt.exe" -ArgumentList "-w", "0", "split-pane", "-V", "pwsh", "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", "`"$scriptPath`"", "-Target", "User"

        # Run System in current pane
        & $script:CurrentShell -NoProfile -ExecutionPolicy Bypass -File "$scriptPath" -Target System
        exit
    }

    # CASE B: WezTerm
    elseif ($env:WEZTERM_PANE) {
        Write-Host "Detected WezTerm. Splitting panes..." -ForegroundColor Cyan
        # Split right
        # wezterm cli split-pane --right -- percent 50 -- program...

        # Launch User (Right)
        $argsUser = @("cli", "split-pane", "--right", "--percent", "50", "--")
        if ($script:CurrentShell -match "pwsh") { $argsUser += "pwsh" } else { $argsUser += "powershell" }
        $argsUser += @("-NoProfile", "-ExecutionPolicy", "Bypass", "-File", "$scriptPath", "-Target", "User")

        Start-Process "wezterm" -ArgumentList $argsUser -Wait

        # Run System in current pane (Left)
        & $script:CurrentShell -NoProfile -ExecutionPolicy Bypass -File "$scriptPath" -Target System
        exit
    }

    # CASE C: Fallback (Launch new WT window)
    else {
        if (Get-Command wt.exe -ErrorAction SilentlyContinue) {
            Write-Host "Launching Windows Terminal split-view..." -ForegroundColor Cyan
            # Launch new window with 2 panes
            # wt -w new pwsh ... -Target System ; split-pane -V pwsh ... -Target User
            $argList = "-w new pwsh -NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`" -Target System `; split-pane -V pwsh -NoProfile -ExecutionPolicy Bypass -File `"$scriptPath`" -Target User"

            # Need to be careful with semicolon parsing in PowerShell Start-Process args
            # We pass the whole string to cmd /c or similar, or just try direct wt syntax
            # The semicolon is a WT delimiter.

            Start-Process "wt.exe" -ArgumentList $argList
            exit
        } else {
            Write-Host "Windows Terminal not found. Running sequentially." -ForegroundColor Yellow
            # Fallthrough to normal sequential run (Target = null)
        }
    }
}

$script:LogDir = Join-Path $env:USERPROFILE "w11dot_logs\apps"
$script:Timestamp = Get-Date -Format "yyyyMMdd_HHmmss"
$script:SuccessLog = Join-Path $script:LogDir "appUpdate_optimized_$($script:Timestamp)_success.log"
$script:ErrorLog = Join-Path $script:LogDir "appUpdate_optimized_$($script:Timestamp)_error.log"

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

function Test-GsudoAvailable {
    return Get-Command gsudo -ErrorAction SilentlyContinue
}

function Initialize-Logging {
    if (!(Test-Path $script:LogDir)) {
        New-Item -ItemType Directory -Path $script:LogDir -Force | Out-Null
    }

    $header = "========================================`nUpdate Started: $(Get-Date -Format 'yyyy-MM-dd HH:mm:ss')`n========================================"
    $header | Out-File $script:SuccessLog -Encoding utf8
    $header | Out-File $script:ErrorLog -Encoding utf8
}

function Select-UpdatesWithGum {
    param($Updates)

    # Use gum style for a nice header instructions
    gum style --foreground 212 --border-foreground 212 --border double --align center --width 50 --margin "1 1" --padding "0 2" "SELECT UPDATES TO INSTALL" "Type to Filter | Space: Toggle | Enter: Confirm"

    # Format for Gum: "Manager  | Name                      | Version Upgrade"
    # We map back by index or strict string matching to avoid showing ugly IDs if possible,
    # but ID is safest. We'll make it subtle.
    $gumList = $Updates | ForEach-Object {
        $verStr = "$($_.Current) -> $($_.Available)"
        "{0,-8} | {1,-25} | {2,-20} {3}" -f $_.Manager, $_.Name, $verStr, "[$($_.Id)]"
    }

    $selectedStrings = $gumList | gum filter --no-limit --height 15 --placeholder "Search updates..."

    if (!$selectedStrings) { return @() }

    # Parse back the IDs from the strings
    $selectedIds = @()
    foreach ($str in $selectedStrings) {
        if ($str -match '\[(.*?)\]$') {
            $id = $matches[1]
            $original = $Updates | Where-Object { $_.Id -eq $id } | Select-Object -First 1
            if ($original) { $selectedIds += $original }
        }
    }
    return $selectedIds
}

function Get-PendingUpdates {
    param(
        $WingetList,
        $ChocoList,
        $ScoopList,
        [bool]$CheckWinget,
        [bool]$CheckChoco,
        [bool]$CheckScoop
    )

    $updates = @()

    # --- Winget ---
    if ($CheckWinget) {
        Write-Host "Checking Winget updates..." -ForegroundColor Gray
        if (Get-Command winget -ErrorAction SilentlyContinue) {
            # 'winget list --upgrade-available' output is hard to parse reliably across locales/versions.
            # Using `winget upgrade` (no install) to list is sometimes cleaner, but `list` is standard.
            # We will use a regex strategy on the table output.
            $output = winget list --upgrade-available 2>&1 | Out-String
            $lines = $output -split "`r?`n"

            # Skip header lines until we find the separator (usually starts with Name or Id, followed by ----)
            $startParsing = $false
            foreach ($line in $lines) {
                if ($line -match '^-+') { $startParsing = $true; continue }
                if (!$startParsing -or [string]::IsNullOrWhiteSpace($line)) { continue }

                # Winget columns are fixed width-ish but dynamic.
                # Strategy: Split by multiple spaces.
                # Name | Id | Version | Available | Source
                $parts = $line -split '\s{2,}'
                if ($parts.Count -ge 4) {
                    $id = $parts[1]
                    $current = $parts[2]
                    $avail = $parts[3]

                    # Filter against our appList.json
                    if ($WingetList.packageId -contains $id) {
                        $updates += [PSCustomObject]@{
                            Manager   = "Winget"
                            Name      = $parts[0]
                            Id        = $id
                            Current   = $current
                            Available = $avail
                        }
                    }
                }
            }
        }
    }

    # --- Chocolatey ---
    if ($CheckChoco) {
        Write-Host "Checking Chocolatey updates..." -ForegroundColor Gray
        if (Get-Command choco -ErrorAction SilentlyContinue) {
            # choco outdated -r (parsable format: name|current|available|pinned)
            $output = choco outdated -r --ignore-pinned 2>&1
            foreach ($line in $output) {
                if ([string]::IsNullOrWhiteSpace($line)) { continue }
                $parts = $line -split '\|'
                if ($parts.Count -ge 3) {
                    $name = $parts[0]
                    $current = $parts[1]
                    $avail = $parts[2]

                    if ($ChocoList.packageName -contains $name) {
                        $updates += [PSCustomObject]@{
                            Manager   = "Choco"
                            Name      = $name
                            Id        = $name
                            Current   = $current
                            Available = $avail
                        }
                    }
                }
            }
        }
    }

    # --- Scoop ---
    if ($CheckScoop) {
        Write-Host "Checking Scoop updates..." -ForegroundColor Gray
        if (Get-Command scoop -ErrorAction SilentlyContinue) {
            # scoop status output:
            # Name    Current Version  Latest Version  Missing Dependencies
            # ----    ---------------  --------------  --------------------
            # app1    1.0              1.1

            $output = scoop status 2>&1 | Out-String
            $lines = $output -split "`r?`n"
            $startParsing = $false
            foreach ($line in $lines) {
                if ($line -match '^-+') { $startParsing = $true; continue }
                if (!$startParsing -or [string]::IsNullOrWhiteSpace($line)) { continue }
                if ($line -match '^Scoop is up to date') { break }

                $parts = $line -split '\s{2,}'
                if ($parts.Count -ge 3) {
                    $name = $parts[0]
                    $current = $parts[1]
                    $avail = $parts[2]

                    # Scoop status lists ALL outdated scoop apps.
                    # We check if it's in our managed list.
                    if ($ScoopList.packageName -contains $name) {
                        $updates += [PSCustomObject]@{
                            Manager   = "Scoop"
                            Name      = $name
                            Id        = $name
                            Current   = $current
                            Available = $avail
                        }
                    }
                }
            }
        }
    }

    return $updates
}

function Write-Log {
    param(
        [string]$Message,
        [ValidateSet('Success', 'Error')][string]$Type = 'Success'
    )

    $logFile = if ($Type -eq 'Success') { $script:SuccessLog } else { $script:ErrorLog }
    $Message | Out-File $logFile -Append -Encoding utf8
}

function Get-ShortError {
    param([string]$Output)

    if ([string]::IsNullOrWhiteSpace($Output)) { return "Unknown error" }

    # Common patterns
    $patterns = @(
        "hash check failed",
        "checksum mismatch",
        "download failed",
        "access is denied",
        "requires elevation",
        "0x[0-9A-Fa-f]+", # Hex error codes
        "Error: .+"       # Winget errors
    )

    foreach ($p in $patterns) {
        if ($Output -match $p) {
            $match = $matches[0]
            # Clean up
            $match = $match -replace "Error: ", ""
            return $match.Trim()
        }
    }

    # Fallback: First non-empty line
    $lines = $Output -split "`r?`n" | Where-Object { ![string]::IsNullOrWhiteSpace($_) }
    if ($lines) {
        $first = $lines[0]
        if ($first.Length -gt 40) { return $first.Substring(0, 37) + "..." }
        return $first
    }

    return "Check logs"
}

function Write-Status {
    param(
        [string]$Manager,
        [string]$Package,
        [ValidateSet('Updating', 'Success', 'UpToDate', 'Skipped', 'Failed', 'Error')][string]$Status,
        [string]$Details = ""
    )

    if (Get-Command gum -ErrorAction SilentlyContinue) {
        # Gum Styling
        $statusColor = switch ($Status) {
            'Updating' { "240" } # Gray
            'Success' { "2" }   # Green
            'Current' { "2" }   # Green
            'Skipped' { "3" }   # Yellow
            'Failed' { "1" }   # Red
            'Error' { "1" }   # Red
        }

        $statusText = switch ($Status) {
            'UpToDate' { "CURRENT" }
            default { $Status.ToUpper() }
        }

        # [ MANAGER ]
        $p1 = gum style --foreground 5 --width 10 --align center --bold "[$Manager]"
        # Package
        $p2 = gum style --foreground 245 --width 35 "$Package"
        # [ STATUS ]
        $p3 = gum style --foreground 255 --background $statusColor --padding "0 1" "$statusText"

        # Details (only for failed/skipped, not for success/current)
        $p4 = ""
        if ($Status -in "Failed", "Error", "Skipped") {
            $detailColor = if ($Status -in "Failed", "Error") { "1" } else { "240" } # Red for error, gray for skipped
            if ($Details) { $p4 = gum style --foreground $detailColor --italic "$Details" }
        }

        Write-Host "$p1 $p2 $p3 $p4"
    } else {
        # Fallback Legacy Styling
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
            UpToDate = "(current)"
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
        if ($line -match '^\s*//') { continue }
        $cleanLine = $line
        if ($line -match '^(.*[}\]",])\s*//.*$') {
            $cleanLine = $matches[1]
        }
        $cleanLines += $cleanLine
    }
    $jsonContent = $cleanLines -join "`n"

    try {
        return $jsonContent | ConvertFrom-Json
    } catch {
        Write-Host "Error parsing appList.json: $_" -ForegroundColor Red
        exit 1
    }
}

#endregion

#region Package Manager Functions

function Refresh-ScoopBuckets {
    if (!(Get-Command scoop -ErrorAction SilentlyContinue)) { return }

    if (Test-Administrator) {
        if (Get-Command gum -ErrorAction SilentlyContinue) {
            gum style --foreground 212 "Refreshing Scoop buckets (De-elevating)..."
        } else {
            Write-Host "`nRefreshing Scoop buckets..." -ForegroundColor Cyan
        }

        # De-elevate to run scoop update to avoid warnings and ensure user scope
        $tempScript = Join-Path $env:TEMP "scoop_refresh_$($script:Timestamp).ps1"
        "scoop update" | Out-File $tempScript -Encoding utf8

        try {
            Start-Process -FilePath "runas" -ArgumentList "/trustlevel:0x20000 `"$script:CurrentShell -NoProfile -ExecutionPolicy Bypass -File `\"$tempScript`\"`"" -Wait
        } catch {
            Write-Host "Warning: Failed to refresh Scoop buckets (elevation issue): $_" -ForegroundColor Yellow
        } finally {
            Remove-Item $tempScript -Force -ErrorAction SilentlyContinue
        }
    } else {
        # Run directly
        try {
            if (Get-Command gum -ErrorAction SilentlyContinue) {
                # Use spinner
                gum spin --spinner dot --title "Refreshing Scoop buckets..." -- scoop update | Out-Null
            } else {
                Write-Host "`nRefreshing Scoop buckets..." -ForegroundColor Cyan
                scoop update | Out-Null
            }
        } catch {
            Write-Host "Warning: Failed to refresh Scoop buckets: $_" -ForegroundColor Yellow
        }
    }
}

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
    param(
        [string]$PackageName,
        [bool]$Global = $false
    )

    if (!(Get-Command scoop -ErrorAction SilentlyContinue)) { return $false }

    if ($Global) {
        $scoopGlobalDir = if ($env:SCOOP_GLOBAL) { $env:SCOOP_GLOBAL } else { "C:\ProgramData\scoop" }
        $appPath = Join-Path $scoopGlobalDir "apps\$PackageName"
        return (Test-Path $appPath)
    } else {
        $scoopDir = if ($env:SCOOP) { $env:SCOOP } else { Join-Path $env:USERPROFILE "scoop" }
        $appPath = Join-Path $scoopDir "apps\$PackageName"
        return (Test-Path $appPath)
    }
}

function Update-WingetPackage {
    param([string]$PackageId)

    # Using gum spin to hide the operation, so we don't print "Updating" beforehand
    if (!(Get-Command gum -ErrorAction SilentlyContinue)) {
        Write-Status -Manager "winget" -Package $PackageId -Status "Updating"
    }

    $isAdmin = Test-Administrator
    $gsudoAvail = Test-GsudoAvailable
    $useGsudo = (!$isAdmin -and $gsudoAvail)

    try {
        $output = ""
        $exitCode = 0

        $cmdStr = if ($useGsudo) {
            "gsudo winget upgrade --id $PackageId --silent --accept-package-agreements --accept-source-agreements"
        } else {
            "winget upgrade --id $PackageId --silent --accept-package-agreements --accept-source-agreements"
        }

        if (Get-Command gum -ErrorAction SilentlyContinue) {
            $tempFile = [System.IO.Path]::GetTempFileName()
            # Wrap in spinner, capturing output to temp file
            gum spin --spinner dot --title "Winget: $PackageId" -- pwsh -c "$cmdStr > `"$tempFile`" 2>&1"
            $output = Get-Content $tempFile -Raw
            $exitCode = $LASTEXITCODE # This captures pwsh exit code, which captures winget's
            Remove-Item $tempFile -Force -ErrorAction SilentlyContinue
        } else {
            $output = Invoke-Expression "$cmdStr 2>&1" | Out-String
            $exitCode = $LASTEXITCODE
        }

        $isUpToDate = $output -match 'No available upgrade found' -or $output -match 'No newer package versions' -or $output -match 'No applicable update'

        if ($exitCode -eq 0 -or $isUpToDate) {
            if ($isUpToDate) {
                Write-Status -Manager "winget" -Package $PackageId -Status "UpToDate"
                $script:Summary.Updated += "winget: $PackageId (current)"
            } else {
                Write-Status -Manager "winget" -Package $PackageId -Status "Success"
                $script:Summary.Updated += "winget: $PackageId"
            }
            Write-Log -Message "SUCCESS: winget | $PackageId" -Type Success
            return $true
        } else {
            $errSummary = Get-ShortError $output
            Write-Status -Manager "winget" -Package $PackageId -Status "Failed" -Details $errSummary
            $script:Summary.Failed += "winget: $PackageId"
            Write-Log -Message "FAILED: winget | $PackageId | Exit: $exitCode`n$output" -Type Error
            return $false
        }
    } catch {
        Write-Status -Manager "winget" -Package $PackageId -Status "Error" -Details $_.Exception.Message
        $script:Summary.Failed += "winget: $PackageId"
        Write-Log -Message "ERROR: winget | $PackageId | $($_.Exception.Message)" -Type Error
        return $false
    }
}

function Update-ChocoPackage {
    param([string]$PackageName)

    if (!(Get-Command gum -ErrorAction SilentlyContinue)) {
        Write-Status -Manager "choco" -Package $PackageName -Status "Updating"
    }

    try {
        $output = ""
        $exitCode = 0

        if (Get-Command gum -ErrorAction SilentlyContinue) {
            $tempFile = [System.IO.Path]::GetTempFileName()
            gum spin --spinner dot --title "Choco: $PackageName" -- pwsh -c "choco upgrade $PackageName -y -r --no-progress > `"$tempFile`" 2>&1"
            $output = Get-Content $tempFile -Raw
            $exitCode = $LASTEXITCODE
            Remove-Item $tempFile -Force -ErrorAction SilentlyContinue
        } else {
            $output = choco upgrade $PackageName -y -r --no-progress 2>&1 | Out-String
            $exitCode = $LASTEXITCODE
        }

        $isUpToDate = $output -match 'already installed' -or $output -match 'is already the latest version' -or $output -match 'Chocolatey upgraded 0/'

        if ($exitCode -eq 0) {
            if ($isUpToDate) {
                Write-Status -Manager "choco" -Package $PackageName -Status "UpToDate"
                $script:Summary.Updated += "choco: $PackageName (current)"
            } else {
                Write-Status -Manager "choco" -Package $PackageName -Status "Success"
                $script:Summary.Updated += "choco: $PackageName"
            }
            Write-Log -Message "SUCCESS: choco | $PackageName" -Type Success
            return $true
        } else {
            $errSummary = Get-ShortError $output
            Write-Status -Manager "choco" -Package $PackageName -Status "Failed" -Details $errSummary
            $script:Summary.Failed += "choco: $PackageName"
            Write-Log -Message "FAILED: choco | $PackageName | Exit: $exitCode`n$output" -Type Error
            return $false
        }
    } catch {
        Write-Status -Manager "choco" -Package $PackageName -Status "Error" -Details $_.Exception.Message
        $script:Summary.Failed += "choco: $PackageName"
        Write-Log -Message "ERROR: choco | $PackageName | $($_.Exception.Message)" -Type Error
        return $false
    }
}

#endregion

#region Process Functions

function Invoke-WingetUpdates {
    param([array]$Packages)
    if (!(Get-Command winget -ErrorAction SilentlyContinue)) {
        Write-Host "`nWinget is not installed. Skipping." -ForegroundColor Yellow
        return
    }

    if (Get-Command gum -ErrorAction SilentlyContinue) {
        gum style --border normal --margin "1 0" --padding "0 1" --border-foreground 212 "WINGET PACKAGES"
    } else {
        Write-Host "`n--- Processing Winget Packages ---" -ForegroundColor Cyan
    }

    foreach ($pkg in $Packages) {
        if ([string]::IsNullOrWhiteSpace($pkg.packageId)) { continue }
        if (Test-WingetInstalled -PackageId $pkg.packageId) {
            Update-WingetPackage -PackageId $pkg.packageId | Out-Null
        } else {
            Write-Status -Manager "winget" -Package $pkg.packageId -Status "Skipped" -Details "not installed"
            $script:Summary.Skipped += "winget: $($pkg.packageId) (not installed)"
        }
    }
}

function Invoke-ChocoUpdates {
    param([array]$Packages)
    if (!(Get-Command choco -ErrorAction SilentlyContinue)) {
        Write-Host "`nChocolatey is not installed. Skipping." -ForegroundColor Yellow
        return
    }

    if (Get-Command gum -ErrorAction SilentlyContinue) {
        gum style --border normal --margin "1 0" --padding "0 1" --border-foreground 212 "CHOCOLATEY PACKAGES"
    } else {
        Write-Host "`n--- Processing Chocolatey Packages ---" -ForegroundColor Cyan
    }

    foreach ($pkg in $Packages) {
        if ([string]::IsNullOrWhiteSpace($pkg.packageName)) { continue }
        if (Test-ChocoInstalled -PackageName $pkg.packageName) {
            Update-ChocoPackage -PackageName $pkg.packageName | Out-Null
        } else {
            Write-Status -Manager "choco" -Package $pkg.packageName -Status "Skipped" -Details "not installed"
            $script:Summary.Skipped += "choco: $($pkg.packageName) (not installed)"
        }
    }
}

function Update-ScoopPackage {
    param(
        [string]$PackageName,
        [bool]$Global = $false,
        [bool]$DeElevate = $false
    )

    if (!(Get-Command gum -ErrorAction SilentlyContinue)) {
        Write-Status -Manager "scoop" -Package $PackageName -Status "Updating"
    }

    $tempOutput = [System.IO.Path]::GetTempFileName()
    $exitCode = 0
    $output = ""

    try {
        # Define the command to run
        $cmdBlock = {
            param($name, $g, $out)
            $argsList = @("update", $name)
            if ($g) { $argsList += "--global" }

            # Run scoop and capture output
            $res = & scoop @argsList 2>&1 | Out-String
            $res | Out-File $out -Encoding utf8
            if ($LASTEXITCODE -ne 0) { exit $LASTEXITCODE }
        }

        if ($DeElevate) {
            # De-elevation requires a physical script file to pass to runas
            $shimScript = Join-Path $env:TEMP "scoop_shim_$($PackageName).ps1"
            # Script content: Run scoop update and redirect output to the temp file we are watching
            # Note: We can't easily write to the parent's $tempOutput from a runas child (permissions).
            # So we let the child write to its own temp, then copy/read it?
            # Simpler: The child prints to stdout, we capture that? runas doesn't stream stdout well.
            # We will tell the child to write to a temp file that EVERYONE can read.

            $childTemp = [System.IO.Path]::GetTempFileName()

            $scriptContent = "scoop update $PackageName | Out-File '$childTemp' -Encoding utf8; exit `$LASTEXITCODE"
            $scriptContent | Out-File $shimScript -Encoding utf8

            $execCmd = {
                Start-Process -FilePath "runas" -ArgumentList "/trustlevel:0x20000 `"$script:CurrentShell -NoProfile -ExecutionPolicy Bypass -File `\"$shimScript`\"`"" -Wait
            }

            if (Get-Command gum -ErrorAction SilentlyContinue) {
                gum spin --spinner dot --title "Scoop: $PackageName" -- pwsh -c $execCmd
            } else {
                & $execCmd
            }

            # Read result
            if (Test-Path $childTemp) {
                $output = Get-Content $childTemp -Raw
                Remove-Item $childTemp -Force -ErrorAction SilentlyContinue
            }
            Remove-Item $shimScript -Force -ErrorAction SilentlyContinue
        } else {
            # Normal Admin or User execution
            $scoopArgs = @("update", $PackageName)
            if ($Global) { $scoopArgs += "--global" }
            $argStr = $scoopArgs -join " "

            # Resolve scoop path for reliable execution inside spin
            $scoopCmd = Get-Command scoop -ErrorAction Stop
            $scoopPath = $scoopCmd.Source

            $runCmd = ""
            if ($scoopPath.EndsWith(".ps1")) {
                $runCmd = "& `"$script:CurrentShell`" -NoProfile -ExecutionPolicy Bypass -File `"$scoopPath`" $argStr"
            } elseif ($scoopPath.EndsWith(".cmd") -or $scoopPath.EndsWith(".bat")) {
                $runCmd = "cmd /c `"$scoopPath`" $argStr"
            } else {
                $runCmd = "& `"$scoopPath`" $argStr"
            }

            if (Get-Command gum -ErrorAction SilentlyContinue) {
                gum spin --spinner dot --title "Scoop: $PackageName" -- pwsh -c "$runCmd > `"$tempOutput`" 2>&1"
                $output = Get-Content $tempOutput -Raw
                $exitCode = $LASTEXITCODE
            } else {
                # Direct execution
                # We need to invoke via Invoke-Expression or & to handle the path/args correctly if manual
                # Simpler to just run command if no gum
                $output = & scoop @scoopArgs 2>&1 | Out-String
                $exitCode = $LASTEXITCODE
            }
        }

        # --- Parse Results ---
        # Scoop output examples:
        # "Latest version for 'app' is already installed."
        # "Updating 'app' (1.0 -> 1.1)..."
        # "Scoop was updated successfully!"

        $isUpToDate = $output -match "Latest version" -or $output -match "is already installed" -or $output -match "is up to date"

        # If output is empty but exit code 0, usually means up to date or no op
        if ([string]::IsNullOrWhiteSpace($output) -and $exitCode -eq 0) { $isUpToDate = $true }

        if ($exitCode -eq 0) {
            if ($isUpToDate) {
                Write-Status -Manager "scoop" -Package $PackageName -Status "Current"
                $script:Summary.Updated += "scoop: $PackageName (current)"
            } else {
                Write-Status -Manager "scoop" -Package $PackageName -Status "Success"
                $script:Summary.Updated += "scoop: $PackageName"
            }
            Write-Log -Message "SUCCESS: scoop | $PackageName" -Type Success
            return $true
        } else {
            $errSummary = Get-ShortError $output
            Write-Status -Manager "scoop" -Package $PackageName -Status "Failed" -Details $errSummary
            $script:Summary.Failed += "scoop: $PackageName"
            Write-Log -Message "FAILED: scoop | $PackageName | Exit: $exitCode`n$output" -Type Error
            return $false
        }

    } catch {
        Write-Status -Manager "scoop" -Package $PackageName -Status "Error" -Details $_.Exception.Message
        $script:Summary.Failed += "scoop: $PackageName"
        Write-Log -Message "ERROR: scoop | $PackageName | $($_.Exception.Message)" -Type Error
        return $false
    } finally {
        if (Test-Path $tempOutput) { Remove-Item $tempOutput -Force -ErrorAction SilentlyContinue }
    }
}

function Invoke-ScoopUpdates {
    param(
        [array]$Packages,
        [bool]$Global = $false,
        [bool]$DeElevate = $false
    )

    if (!$Packages -or $Packages.Count -eq 0) { return }

    $scopeStr = if ($Global) { "GLOBAL" } else { "USER" }

    if (Get-Command gum -ErrorAction SilentlyContinue) {
        gum style --border normal --margin "1 0" --padding "0 1" --border-foreground 212 "SCOOP PACKAGES ($scopeStr)"
    } else {
        Write-Host "`n--- Processing Scoop Packages ($scopeStr) ---" -ForegroundColor Cyan
    }

    foreach ($pkg in $Packages) {
        $name = $pkg.packageName
        if ([string]::IsNullOrWhiteSpace($name)) { continue }

        if (Test-ScoopInstalled -PackageName $name -Global:$Global) {
            Update-ScoopPackage -PackageName $name -Global:$Global -DeElevate:$DeElevate
        } else {
            Write-Status -Manager "scoop" -Package "$name" -Status "Skipped" -Details "not installed in $scopeStr"
            $script:Summary.Skipped += "scoop: $name"
        }
    }
}

function Invoke-ElevatedUpdate {
    param(
        [bool]$ProcessWinget,
        [bool]$ProcessChoco,
        [bool]$ProcessGlobalScoop
    )

    $managers = @()
    if ($ProcessWinget) { $managers += "-Winget" }
    if ($ProcessChoco) { $managers += "-Choco" }
    # Use -Scoop to trigger scoop processing, the admin block in main will filter for Global
    if ($ProcessGlobalScoop) { $managers += "-Scoop" }

    if ($managers.Count -eq 0) { return }

    # Point to THIS script
    $scriptPath = $MyInvocation.MyCommand.Path
    $arguments = $managers -join " "

    Write-Host "`nElevating to admin for Global/System updates..." -ForegroundColor Yellow
    Write-Host "Will process: Winget=$ProcessWinget, Choco=$ProcessChoco, ScoopGlobal=$ProcessGlobalScoop" -ForegroundColor Gray
    Write-Host "Script path: $scriptPath" -ForegroundColor Gray
    Write-Host "Arguments: $arguments" -ForegroundColor Gray
    Write-Host "Current shell: $script:CurrentShell" -ForegroundColor Gray

    try {
        Write-Host "Starting elevated process..." -ForegroundColor Gray

        $processInfo = Start-Process -FilePath $script:CurrentShell `
            -ArgumentList "-NoProfile", "-ExecutionPolicy", "Bypass", "-File", "`"$scriptPath`"", $arguments `
            -Verb RunAs -Wait -PassThru -RedirectStandardOutput "elevated_output.txt" -RedirectStandardError "elevated_error.txt"

        Write-Host "Elevated process completed with exit code $($processInfo.ExitCode)" -ForegroundColor Gray

        if ($processInfo.ExitCode -ne 0) {
            Write-Host "Elevated process failed with exit code $($processInfo.ExitCode)" -ForegroundColor Red
            $script:Summary.Failed += "elevation: admin process failed"

            # Try to read error output
            if (Test-Path "elevated_error.txt") {
                $errorContent = Get-Content "elevated_error.txt" -ErrorAction SilentlyContinue
                if ($errorContent) {
                    Write-Host "Error output: $errorContent" -ForegroundColor Red
                }
            }
            if (Test-Path "elevated_output.txt") {
                $outputContent = Get-Content "elevated_output.txt" -ErrorAction SilentlyContinue
                if ($outputContent) {
                    Write-Host "Standard output: $outputContent" -ForegroundColor Red
                }
            }
        } else {
            Write-Host "Elevated process completed successfully" -ForegroundColor Green
        }
    } catch {
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

    Write-Host "`n"
    if (Get-Command gum -ErrorAction SilentlyContinue) {
        gum style --foreground 212 --border-foreground 212 --border double --align center --width 50 --margin "0 0" --padding "0 2" "UPDATE SUMMARY"
    } else {
        Write-Host "========================================" -ForegroundColor Cyan
        Write-Host "Update Summary" -ForegroundColor Cyan
        Write-Host "========================================" -ForegroundColor Cyan
    }

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

if ($Target -eq 'System') {
    $processWinget = $true
    $processChoco = $true
    $processScoop = $false
    Write-Host "Target mode: System (Winget+Choco only)" -ForegroundColor Gray
} elseif ($Target -eq 'User') {
    $processWinget = $false
    $processChoco = $false
    $processScoop = $true
    Write-Host "Target mode: User (Scoop only)" -ForegroundColor Gray
} else {
    # Normal Orchestration/Sequential Mode
    $noSwitchSpecified = -not ($Scoop -or $Winget -or $Choco -or $All)
    $processAll = $All -or $noSwitchSpecified
    $processWinget = $processAll -or $Winget
    $processChoco = $processAll -or $Choco
    $processScoop = $processAll -or $Scoop
    Write-Host "Normal mode: processAll=$processAll, Winget=$processWinget, Choco=$processChoco, Scoop=$processScoop" -ForegroundColor Gray
}

Initialize-Logging
Write-Host "`nStarting application updates (Optimized)..." -ForegroundColor Green

# Debug: Show current parameters
Write-Host "Parameters: Scoop=$Scoop, Winget=$Winget, Choco=$Choco, All=$All, Check=$Check, Target=$Target" -ForegroundColor Gray

$appList = Get-AppList
$wingetPackages = $appList.installSource.winget.packageList
$chocoPackages = $appList.installSource.choco.packageList
$scoopPackages = $appList.installSource.scoop.packageList

Write-Host "Package counts: Winget=$($wingetPackages.Count), Choco=$($chocoPackages.Count), Scoop=$($scoopPackages.Count)" -ForegroundColor Gray

# Refresh Scoop Buckets if we are processing Scoop
if ($processScoop) {
    Refresh-ScoopBuckets
}

# --- Check / Interactive Mode ---
if ($Check) {
    Write-Host "`n[Check Mode] Scanning for available updates..." -ForegroundColor Cyan

    $pendingUpdates = Get-PendingUpdates `
        -WingetList $wingetPackages `
        -ChocoList $chocoPackages `
        -ScoopList $scoopPackages `
        -CheckWinget ($processWinget -and $appList.installSource.winget.autoInstall) `
        -CheckChoco ($processChoco -and $appList.installSource.choco.autoInstall) `
        -CheckScoop ($processScoop -and $appList.installSource.scoop.autoInstall)

    if ($pendingUpdates.Count -eq 0) {
        Write-Host "All managed applications are up to date!" -ForegroundColor Green
        exit 0
    }

    # Show GUI for selection
    Write-Host "Found $($pendingUpdates.Count) pending updates. Opening selection window..." -ForegroundColor Yellow

    $selected = $null

    if (Get-Command gum -ErrorAction SilentlyContinue) {
        # Use Gum TUI if available
        $selected = Select-UpdatesWithGum -Updates $pendingUpdates
    } else {
        # Fallback to native GridView
        $selected = $pendingUpdates | Out-GridView -PassThru -Title "Select Updates to Install (Ctrl+Click to select multiple)"
    }

    if (!$selected -or $selected.Count -eq 0) {
        Write-Host "No updates selected. Exiting." -ForegroundColor Yellow
        exit 0
    }

    if (Get-Command gum -ErrorAction SilentlyContinue) {
        # Confirm action
        gum confirm "Proceed with $($selected.Count) updates?"
        if ($LASTEXITCODE -ne 0) {
            Write-Host "Update cancelled." -ForegroundColor Yellow
            exit 0
        }
    }

    Write-Host "Proceeding with $($selected.Count) selected updates..." -ForegroundColor Green

    # Filter the main package lists based on selection
    # We use the 'Id' property we stored in the custom object
    $selectedWingetIds = ($selected | Where-Object { $_.Manager -eq 'Winget' }).Id
    $selectedChocoIds = ($selected | Where-Object { $_.Manager -eq 'Choco' }).Id
    $selectedScoopIds = ($selected | Where-Object { $_.Manager -eq 'Scoop' }).Id

    if ($selectedWingetIds) {
        $wingetPackages = $wingetPackages | Where-Object { $selectedWingetIds -contains $_.packageId }
    } else {
        $wingetPackages = @()
    }

    if ($selectedChocoIds) {
        $chocoPackages = $chocoPackages | Where-Object { $selectedChocoIds -contains $_.packageName }
    } else {
        $chocoPackages = @()
    }

    if ($selectedScoopIds) {
        $scoopPackages = $scoopPackages | Where-Object { $selectedScoopIds -contains $_.packageName }
    } else {
        $scoopPackages = @()
    }
}

# Separation of Scoop Packages
$scoopGlobal = @()
$scoopUser = @()
if ($processScoop) {
    foreach ($pkg in $scoopPackages) {
        if ($pkg.packageScope -eq "global") {
            $scoopGlobal += $pkg
        } else {
            $scoopUser += $pkg
        }
    }
}

$isAdmin = Test-Administrator

if ($isAdmin) {
    Write-Host "Running as Administrator" -ForegroundColor Cyan

    # 1. Winget (Admin)
    if ($processWinget -and $appList.installSource.winget.autoInstall) {
        Write-Host "Processing $($wingetPackages.Count) Winget packages..." -ForegroundColor Gray
        Invoke-WingetUpdates -Packages $wingetPackages
    } else {
        Write-Host "Skipping Winget updates (processWinget=$processWinget, autoInstall=$($appList.installSource.winget.autoInstall))" -ForegroundColor DarkGray
    }

    # 2. Choco (Admin)
    if ($processChoco -and $appList.installSource.choco.autoInstall) {
        Write-Host "Processing $($chocoPackages.Count) Chocolatey packages..." -ForegroundColor Gray
        Invoke-ChocoUpdates -Packages $chocoPackages
    } else {
        Write-Host "Skipping Chocolatey updates (processChoco=$processChoco, autoInstall=$($appList.installSource.choco.autoInstall))" -ForegroundColor DarkGray
    }

    # 3. Scoop Global (Admin)
    if ($scoopGlobal.Count -gt 0 -and $appList.installSource.scoop.autoInstall) {
        Invoke-ScoopUpdates -Packages $scoopGlobal -Global $true -DeElevate $false
    }

    # 4. Scoop User (De-elevate)
    if ($scoopUser.Count -gt 0 -and $appList.installSource.scoop.autoInstall) {
        Invoke-ScoopUpdates -Packages $scoopUser -Global $false -DeElevate $true
    }
} else {
    Write-Host "Running as Non-Administrator" -ForegroundColor Cyan

    # 1. Scoop User (Direct)
    if ($scoopUser.Count -gt 0 -and $appList.installSource.scoop.autoInstall) {
        Invoke-ScoopUpdates -Packages $scoopUser -Global $false -DeElevate $false
    }

    # 2. Winget (Direct, with gsudo if available)
    if ($processWinget -and $appList.installSource.winget.autoInstall) {
        Invoke-WingetUpdates -Packages $wingetPackages
    }

    # 3. Check for Elevation Requirements
    $needsElevation = ($processChoco -and $appList.installSource.choco.autoInstall) -or
    ($scoopGlobal.Count -gt 0 -and $appList.installSource.scoop.autoInstall)

    Write-Host "Elevation needed: $needsElevation (Choco=$($processChoco -and $appList.installSource.choco.autoInstall), ScoopGlobal=$($scoopGlobal.Count -gt 0 -and $appList.installSource.scoop.autoInstall))" -ForegroundColor Gray

    if ($needsElevation) {
        Write-Host "Elevating to process Chocolatey updates..." -ForegroundColor Yellow
        Invoke-ElevatedUpdate -ProcessWinget $false `
            -ProcessChoco ($processChoco -and $appList.installSource.choco.autoInstall) `
            -ProcessGlobalScoop ($scoopGlobal.Count -gt 0 -and $appList.installSource.scoop.autoInstall)
    } else {
        Write-Host "No elevation needed - all required updates can run in current context" -ForegroundColor DarkGray
    }
}

Show-Summary

if ($Target) {
    if (Get-Command gum -ErrorAction SilentlyContinue) {
        gum confirm "Close pane?"
    } else {
        Read-Host "Press Enter to close pane..."
    }
}

$exitCode = if ($script:Summary.Failed.Count -gt 0) { 1 } else { 0 }
exit $exitCode

#endregion
exit $exitCode

#endregion


if ($Target) {
    if (Get-Command gum -ErrorAction SilentlyContinue) {
        gum confirm "Close pane?"
    } else {
        Read-Host "Press Enter to close pane..."
    }
}

$exitCode = if ($script:Summary.Failed.Count -gt 0) { 1 } else { 0 }
exit $exitCode

#endregion
exit $exitCode

#endregion


    }
}

Show-Summary

if ($Target) {
    if (Get-Command gum -ErrorAction SilentlyContinue) {
        gum confirm "Close pane?"
    } else {
        Read-Host "Press Enter to close pane..."
    }
}

$exitCode = if ($script:Summary.Failed.Count -gt 0) { 1 } else { 0 }
exit $exitCode

#endregion
exit $exitCode

#endregion


if ($Target) {
    if (Get-Command gum -ErrorAction SilentlyContinue) {
        gum confirm "Close pane?"
    } else {
        Read-Host "Press Enter to close pane..."
    }
}

$exitCode = if ($script:Summary.Failed.Count -gt 0) { 1 } else { 0 }
exit $exitCode

#endregion
exit $exitCode

#endregion



