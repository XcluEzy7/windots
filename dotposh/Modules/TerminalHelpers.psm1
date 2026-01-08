# Helper Functions
function Test-CharmTools {
    <#
    .SYNOPSIS
        Checks if Charm tools (glamour, gum) are available.
    #>
    $glamour = Get-Command glamour -ErrorAction SilentlyContinue
    $gum = Get-Command gum -ErrorAction SilentlyContinue
    return [PSCustomObject]@{
        Glamour = $null -ne $glamour
        Gum = $null -ne $gum
        GlamourPath = if ($glamour) { $glamour.Source } else { $null }
        GumPath = if ($gum) { $gum.Source } else { $null }
    }
}

function Write-ColorText {
    <#
    .SYNOPSIS
        Writes colored text using PowerShell native colors.
        Supports color tags like {Green}text{Gray}more text
    #>
    param(
        [Parameter(Mandatory = $true)]
        [string]$Text,
        [switch]$NoNewLine
    )
    
    $hostColor = $Host.UI.RawUI.ForegroundColor
    
    $Text.Split([char]"{", [char]"}") | ForEach-Object -Begin { $i = 0 } -Process {
        if ($i % 2 -eq 0) {
            Write-Host $_ -NoNewline
        } else {
            if ($_ -in [enum]::GetNames("ConsoleColor")) {
                $Host.UI.RawUI.ForegroundColor = ($_ -as [System.ConsoleColor])
            }
        }
        $i++
    }
    
    if (!$NoNewLine) { Write-Host }
    $Host.UI.RawUI.ForegroundColor = $hostColor
}

function Show-WezTermHelp {
    <#
    .SYNOPSIS
        Displays a comprehensive cheat sheet for WezTerm shortcuts (Unified with Windows Terminal).
    #>
    [CmdletBinding()]
    param()

    # Check for gum (optional enhancement)
    $charmTools = Test-CharmTools
    $useGum = $charmTools.Gum

    # Build shortcuts array
    $shortcuts = @(
        # Tabs - Common
        [PSCustomObject]@{ Shortcut = "Ctrl + Shift + T"; Description = "New Tab"; Category = "Tabs"; Color = "Green" }
        [PSCustomObject]@{ Shortcut = "Ctrl + Shift + W"; Description = "Close Tab"; Category = "Tabs"; Color = "Green" }
        [PSCustomObject]@{ Shortcut = "Ctrl + Tab"; Description = "Next Tab (1 mod key)"; Category = "Tabs"; Color = "Green" }
        [PSCustomObject]@{ Shortcut = "Ctrl + Shift + Tab"; Description = "Previous Tab"; Category = "Tabs"; Color = "Green" }
        [PSCustomObject]@{ Shortcut = "Ctrl + Shift + ["; Description = "Previous Tab (Alternative)"; Category = "Tabs"; Color = "Green" }
        [PSCustomObject]@{ Shortcut = "Ctrl + Shift + ]"; Description = "Next Tab (Alternative)"; Category = "Tabs"; Color = "Green" }
        
        # Windows - WezTerm Only
        [PSCustomObject]@{ Shortcut = "Ctrl + Shift + N"; Description = "New Window"; Category = "Windows"; Color = "Yellow" }
        [PSCustomObject]@{ Shortcut = "Ctrl + Shift + K"; Description = "Close Window"; Category = "Windows"; Color = "Yellow" }
        
        # Panes - Split (1 mod key)
        [PSCustomObject]@{ Shortcut = "Ctrl + |"; Description = "Split Vertical (Pipe = vertical line)"; Category = "Panes-Split"; Color = "Green" }
        [PSCustomObject]@{ Shortcut = "Ctrl + \"; Description = "Split Horizontal (Backslash = horizontal line)"; Category = "Panes-Split"; Color = "Green" }
        
        # Panes - Navigation (2 mod keys)
        [PSCustomObject]@{ Shortcut = "Ctrl + Shift + Arrow"; Description = "Navigate Between Panes"; Category = "Panes-Navigation"; Color = "Green" }
        
        # Panes - Management (2 mod keys)
        [PSCustomObject]@{ Shortcut = "Ctrl + Shift + X"; Description = "Close Pane"; Category = "Panes-Management"; Color = "Green" }
        
        # Panes - Advanced (2 mod keys, WezTerm Only)
        [PSCustomObject]@{ Shortcut = "Ctrl + Shift + Z"; Description = "Toggle Pane Zoom/Maximize"; Category = "Panes-Advanced"; Color = "Yellow" }
        [PSCustomObject]@{ Shortcut = "Ctrl + Shift + H"; Description = "Toggle Pane Full Screen"; Category = "Panes-Advanced"; Color = "Yellow" }
        [PSCustomObject]@{ Shortcut = "Ctrl + Shift + O"; Description = "Rotate Panes"; Category = "Panes-Advanced"; Color = "Yellow" }
        [PSCustomObject]@{ Shortcut = "Ctrl + Shift + P"; Description = "Pane Selection Mode"; Category = "Panes-Advanced"; Color = "Yellow" }
        
        # Edit - Common (2 mod keys)
        [PSCustomObject]@{ Shortcut = "Ctrl + Shift + C"; Description = "Copy to Clipboard"; Category = "Edit-Common"; Color = "Green" }
        [PSCustomObject]@{ Shortcut = "Ctrl + Shift + V"; Description = "Paste from Clipboard"; Category = "Edit-Common"; Color = "Green" }
        [PSCustomObject]@{ Shortcut = "Ctrl + Shift + F"; Description = "Search/Find"; Category = "Edit-Common"; Color = "Green" }
        
        # Edit - WezTerm Only (2 mod keys)
        [PSCustomObject]@{ Shortcut = "Ctrl + Shift + Insert"; Description = "Paste from Primary Selection"; Category = "Edit-WezTerm"; Color = "Yellow" }
        [PSCustomObject]@{ Shortcut = "Ctrl + Shift + R"; Description = "Reload Configuration"; Category = "Edit-WezTerm"; Color = "Yellow" }
        
        # Font Size - Common (1 mod key)
        [PSCustomObject]@{ Shortcut = "Ctrl + +"; Description = "Increase Font Size"; Category = "FontSize"; Color = "Green" }
        [PSCustomObject]@{ Shortcut = "Ctrl + -"; Description = "Decrease Font Size"; Category = "FontSize"; Color = "Green" }
        [PSCustomObject]@{ Shortcut = "Ctrl + 0"; Description = "Reset Font Size"; Category = "FontSize"; Color = "Green" }
        
        # Scrolling - Common (2 mod keys)
        [PSCustomObject]@{ Shortcut = "Ctrl + Shift + PageUp"; Description = "Scroll Up"; Category = "Scrolling"; Color = "Green" }
        [PSCustomObject]@{ Shortcut = "Ctrl + Shift + PageDown"; Description = "Scroll Down"; Category = "Scrolling"; Color = "Green" }
        [PSCustomObject]@{ Shortcut = "Ctrl + Shift + Home"; Description = "Scroll to Top"; Category = "Scrolling"; Color = "Green" }
        [PSCustomObject]@{ Shortcut = "Ctrl + Shift + End"; Description = "Scroll to Bottom"; Category = "Scrolling"; Color = "Green" }
        
        # Special Features - WezTerm Only (2 mod keys)
        [PSCustomObject]@{ Shortcut = "Ctrl + Shift + E"; Description = "Copy Mode"; Category = "SpecialFeatures"; Color = "Yellow" }
        [PSCustomObject]@{ Shortcut = "Ctrl + Shift + U"; Description = "Quick Select Mode"; Category = "SpecialFeatures"; Color = "Yellow" }
        [PSCustomObject]@{ Shortcut = "Ctrl + Shift + I"; Description = "Debug Overlay"; Category = "SpecialFeatures"; Color = "Yellow" }
        [PSCustomObject]@{ Shortcut = "Ctrl + Shift + M"; Description = "Mouse Mode"; Category = "SpecialFeatures"; Color = "Yellow" }
        [PSCustomObject]@{ Shortcut = "Ctrl + Shift + L"; Description = "Launcher Menu"; Category = "SpecialFeatures"; Color = "Yellow" }
        [PSCustomObject]@{ Shortcut = "Ctrl + Shift + J"; Description = "Pane Selection Mode"; Category = "SpecialFeatures"; Color = "Yellow" }
        [PSCustomObject]@{ Shortcut = "Ctrl + Shift + B"; Description = "Launcher Menu (Alternative)"; Category = "SpecialFeatures"; Color = "Yellow" }
        [PSCustomObject]@{ Shortcut = "Ctrl + Shift + G"; Description = "Tab Navigator"; Category = "SpecialFeatures"; Color = "Yellow" }
        [PSCustomObject]@{ Shortcut = "Ctrl + Shift + Space"; Description = "Tab Navigator (Alternative)"; Category = "SpecialFeatures"; Color = "Yellow" }
        
        # GlazeWM Interaction
        [PSCustomObject]@{ Shortcut = "LWin + Enter"; Description = "Launch Terminal (GlazeWM Bind)"; Category = "GlazeWM"; Color = "Yellow" }
        [PSCustomObject]@{ Shortcut = "LWin + F"; Description = "Fullscreen Window (GlazeWM)"; Category = "GlazeWM"; Color = "Yellow" }
    )

    # Category display order and headers
    $categories = @(
        @{ Name = "Tabs"; Header = "Tabs - Common"; HeaderColor = "Cyan" }
        @{ Name = "Windows"; Header = "Windows - WezTerm Only"; HeaderColor = "Cyan" }
        @{ Name = "Panes-Split"; Header = "Panes - Split (1 mod key)"; HeaderColor = "Cyan" }
        @{ Name = "Panes-Navigation"; Header = "Panes - Navigation (2 mod keys)"; HeaderColor = "Cyan" }
        @{ Name = "Panes-Management"; Header = "Panes - Management (2 mod keys)"; HeaderColor = "Cyan" }
        @{ Name = "Panes-Advanced"; Header = "Panes - Advanced (2 mod keys, WezTerm Only)"; HeaderColor = "Cyan" }
        @{ Name = "Edit-Common"; Header = "Edit - Common (2 mod keys)"; HeaderColor = "Cyan" }
        @{ Name = "Edit-WezTerm"; Header = "Edit - WezTerm Only (2 mod keys)"; HeaderColor = "Cyan" }
        @{ Name = "FontSize"; Header = "Font Size - Common (1 mod key)"; HeaderColor = "Cyan" }
        @{ Name = "Scrolling"; Header = "Scrolling - Common (2 mod keys)"; HeaderColor = "Cyan" }
        @{ Name = "SpecialFeatures"; Header = "Special Features - WezTerm Only (2 mod keys)"; HeaderColor = "Cyan" }
        @{ Name = "GlazeWM"; Header = "GlazeWM Interaction"; HeaderColor = "Cyan" }
    )

    # Header
    Write-Host ""
    if ($useGum) {
        $header = & gum style --foreground 5 --bold "⚡ WezTerm Cheat Sheet (Unified Shortcuts)"
        Write-Host $header
    } else {
        Write-Host "⚡ WezTerm Cheat Sheet (Unified Shortcuts)" -ForegroundColor Magenta
    }
    Write-Host "=========================================" -ForegroundColor Magenta
    Write-Host "Shortcuts aligned with Windows Terminal. Uses CTRL+SHIFT to avoid GlazeWM conflicts." -ForegroundColor DarkGray
    Write-Host ""

    # Display each category
    foreach ($cat in $categories) {
        $categoryShortcuts = $shortcuts | Where-Object { $_.Category -eq $cat.Name }
        if ($categoryShortcuts) {
            Write-Host ""
            Write-Host "[$($cat.Header)]" -ForegroundColor $cat.HeaderColor
            
            # Build table data with colors
            $tableData = $categoryShortcuts | ForEach-Object {
                $color = if ($_.Color -eq "Green") { "Green" } else { "Yellow" }
                [PSCustomObject]@{
                    Shortcut = $_.Shortcut
                    Description = $_.Description
                    Color = $color
                }
            }
            
            # Display using Format-Table with custom formatting
            foreach ($item in $tableData) {
                Write-Host "  " -NoNewline
                Write-Host $item.Shortcut.PadRight(30) -NoNewline -ForegroundColor $item.Color
                Write-Host $item.Description
            }
        }
    }

    # Footer note
    Write-Host ""
    Write-Host "Note: " -NoNewline -ForegroundColor DarkGray
    Write-Host "Alt+Enter is disabled to avoid GlazeWM conflicts" -ForegroundColor DarkGray
    Write-Host ""
}

function Show-WTHelp {
    <#
    .SYNOPSIS
        Displays a comprehensive cheat sheet for Windows Terminal shortcuts (Unified with WezTerm).
    #>
    [CmdletBinding()]
    param()

    # Check for gum (optional enhancement)
    $charmTools = Test-CharmTools
    $useGum = $charmTools.Gum

    # Build shortcuts array with justifications
    $shortcuts = @(
        # Tabs - Common
        [PSCustomObject]@{ Shortcut = "Ctrl + Shift + T"; Description = "New Tab"; Category = "Tabs"; Color = "Green"; Justification = $null }
        [PSCustomObject]@{ Shortcut = "Ctrl + Shift + W"; Description = "Close Tab"; Category = "Tabs"; Color = "Green"; Justification = $null }
        [PSCustomObject]@{ Shortcut = "Ctrl + Tab"; Description = "Next Tab (1 mod key)"; Category = "Tabs"; Color = "Green"; Justification = $null }
        [PSCustomObject]@{ Shortcut = "Ctrl + Shift + Tab"; Description = "Previous Tab"; Category = "Tabs"; Color = "Green"; Justification = $null }
        [PSCustomObject]@{ Shortcut = "Ctrl + Shift + ["; Description = "Previous Tab (Alternative)"; Category = "Tabs"; Color = "Green"; Justification = $null }
        [PSCustomObject]@{ Shortcut = "Ctrl + Shift + ]"; Description = "Next Tab (Alternative)"; Category = "Tabs"; Color = "Green"; Justification = $null }
        [PSCustomObject]@{ Shortcut = "Ctrl + Shift + 1-9"; Description = "Switch to Tab 1-9 (WT Only)"; Category = "Tabs"; Color = "Green"; Justification = $null }
        
        # Panes - Split (1 mod key)
        [PSCustomObject]@{ Shortcut = "Ctrl + |"; Description = "Split Vertical (Pipe = vertical line)"; Category = "Panes-Split"; Color = "Green"; Justification = $null }
        [PSCustomObject]@{ Shortcut = "Ctrl + \"; Description = "Split Horizontal (Backslash = horizontal line)"; Category = "Panes-Split"; Color = "Green"; Justification = $null }
        [PSCustomObject]@{ Shortcut = "Ctrl + Shift + D"; Description = "Split Duplicate (Auto)"; Category = "Panes-Split"; Color = "Green"; Justification = $null }
        
        # Panes - Navigation (2 mod keys)
        [PSCustomObject]@{ Shortcut = "Ctrl + Shift + Arrow"; Description = "Navigate Between Panes"; Category = "Panes-Navigation"; Color = "Green"; Justification = $null }
        
        # Panes - Management (2 mod keys)
        [PSCustomObject]@{ Shortcut = "Ctrl + Shift + X"; Description = "Close Pane"; Category = "Panes-Management"; Color = "Green"; Justification = $null }
        
        # Panes - Advanced (3 mod keys, WT Only)
        [PSCustomObject]@{ Shortcut = "Ctrl + Shift + Alt + Arrow"; Description = "Resize Pane"; Category = "Panes-Advanced"; Color = "Yellow"; Justification = "Advanced, less common than navigation; clearly differentiates from Ctrl+Shift+Arrow" }
        [PSCustomObject]@{ Shortcut = "Ctrl + Shift + Alt + S"; Description = "Toggle Split Orientation"; Category = "Panes-Advanced"; Color = "Yellow"; Justification = "Advanced feature, rarely used" }
        [PSCustomObject]@{ Shortcut = "Ctrl + Shift + Alt + +"; Description = "Maximize Pane"; Category = "Panes-Advanced"; Color = "Yellow"; Justification = "Advanced feature, less common action" }
        [PSCustomObject]@{ Shortcut = "Ctrl + Shift + Alt + -"; Description = "Restore Pane Size"; Category = "Panes-Advanced"; Color = "Yellow"; Justification = "Advanced feature, pairs with maximize" }
        
        # Edit - Common (2 mod keys)
        [PSCustomObject]@{ Shortcut = "Ctrl + Shift + C"; Description = "Copy to Clipboard"; Category = "Edit-Common"; Color = "Green"; Justification = $null }
        [PSCustomObject]@{ Shortcut = "Ctrl + Shift + V"; Description = "Paste from Clipboard"; Category = "Edit-Common"; Color = "Green"; Justification = $null }
        [PSCustomObject]@{ Shortcut = "Ctrl + Shift + F"; Description = "Find/Search"; Category = "Edit-Common"; Color = "Green"; Justification = $null }
        
        # Edit - Advanced (2-3 mod keys, WT Only)
        [PSCustomObject]@{ Shortcut = "Ctrl + Shift + H"; Description = "Find Next (2 mod keys)"; Category = "Edit-Advanced"; Color = "Yellow"; Justification = $null }
        [PSCustomObject]@{ Shortcut = "Ctrl + Shift + Alt + H"; Description = "Find Previous (3 mod keys)"; Category = "Edit-Advanced"; Color = "Yellow"; Justification = "Reverse action of Find Next; logical pairing" }
        [PSCustomObject]@{ Shortcut = "Ctrl + Shift + M"; Description = "Mark Mode/Select Text (2 mod keys)"; Category = "Edit-Advanced"; Color = "Yellow"; Justification = $null }
        [PSCustomObject]@{ Shortcut = "Ctrl + Shift + Alt + M"; Description = "Mark Mode Block Selection (3 mod keys)"; Category = "Edit-Advanced"; Color = "Yellow"; Justification = "Variant of mark mode; different from text selection" }
        
        # Font Size - Common (1 mod key)
        [PSCustomObject]@{ Shortcut = "Ctrl + +"; Description = "Increase Font Size"; Category = "FontSize"; Color = "Green"; Justification = $null }
        [PSCustomObject]@{ Shortcut = "Ctrl + -"; Description = "Decrease Font Size"; Category = "FontSize"; Color = "Green"; Justification = $null }
        [PSCustomObject]@{ Shortcut = "Ctrl + 0"; Description = "Reset Font Size"; Category = "FontSize"; Color = "Green"; Justification = $null }
        
        # View - Display (2-3 mod keys, WT Only)
        [PSCustomObject]@{ Shortcut = "Ctrl + Shift + Enter"; Description = "Toggle Full Screen (2 mod keys)"; Category = "View-Display"; Color = "Yellow"; Justification = $null }
        [PSCustomObject]@{ Shortcut = "Ctrl + Shift + Alt + Enter"; Description = "Toggle Focus Mode (3 mod keys)"; Category = "View-Display"; Color = "Yellow"; Justification = "Advanced mode; different from fullscreen" }
        [PSCustomObject]@{ Shortcut = "Ctrl + Shift + Alt + F"; Description = "Toggle Always on Top (3 mod keys)"; Category = "View-Display"; Color = "Yellow"; Justification = "Window management; advanced feature" }
        
        # Scrolling - Common (2 mod keys)
        [PSCustomObject]@{ Shortcut = "Ctrl + Shift + PgUp"; Description = "Scroll Up"; Category = "Scrolling"; Color = "Green"; Justification = $null }
        [PSCustomObject]@{ Shortcut = "Ctrl + Shift + PgDn"; Description = "Scroll Down"; Category = "Scrolling"; Color = "Green"; Justification = $null }
        [PSCustomObject]@{ Shortcut = "Ctrl + Shift + Home"; Description = "Scroll to Top"; Category = "Scrolling"; Color = "Green"; Justification = $null }
        [PSCustomObject]@{ Shortcut = "Ctrl + Shift + End"; Description = "Scroll to Bottom"; Category = "Scrolling"; Color = "Green"; Justification = $null }
        [PSCustomObject]@{ Shortcut = "Ctrl + Shift + Up"; Description = "Scroll Up One Line (WT Only)"; Category = "Scrolling"; Color = "Green"; Justification = $null }
        [PSCustomObject]@{ Shortcut = "Ctrl + Shift + Down"; Description = "Scroll Down One Line (WT Only)"; Category = "Scrolling"; Color = "Green"; Justification = $null }
        
        # Settings & Profiles (2-3 mod keys, WT Only)
        [PSCustomObject]@{ Shortcut = "Ctrl + Shift + ,"; Description = "Open Settings (2 mod keys)"; Category = "Settings"; Color = "Yellow"; Justification = $null }
        [PSCustomObject]@{ Shortcut = "Ctrl + Shift + Space"; Description = "New Tab Dropdown (2 mod keys)"; Category = "Settings"; Color = "Yellow"; Justification = $null }
        [PSCustomObject]@{ Shortcut = "Ctrl + Shift + Alt + ,"; Description = "Open Settings JSON (3 mod keys)"; Category = "Settings"; Color = "Yellow"; Justification = "Advanced editing mode; different from GUI settings" }
        [PSCustomObject]@{ Shortcut = "Ctrl + Shift + Alt + P"; Description = "Command Palette (3 mod keys)"; Category = "Settings"; Color = "Yellow"; Justification = "Advanced feature; avoids conflicts" }
        [PSCustomObject]@{ Shortcut = "Ctrl + Shift + Alt + R"; Description = "Reload Configuration (3 mod keys)"; Category = "Settings"; Color = "Yellow"; Justification = "System action; should be harder to trigger accidentally" }
        
        # GlazeWM Interaction
        [PSCustomObject]@{ Shortcut = "LWin + Enter"; Description = "Launch Terminal (GlazeWM Bind)"; Category = "GlazeWM"; Color = "Yellow"; Justification = $null }
        [PSCustomObject]@{ Shortcut = "LWin + F"; Description = "Fullscreen Window (GlazeWM)"; Category = "GlazeWM"; Color = "Yellow"; Justification = $null }
        [PSCustomObject]@{ Shortcut = "LWin + Q"; Description = "Close Window (GlazeWM)"; Category = "GlazeWM"; Color = "Yellow"; Justification = $null }
        [PSCustomObject]@{ Shortcut = "LWin + M"; Description = "Minimize Window (GlazeWM)"; Category = "GlazeWM"; Color = "Yellow"; Justification = $null }
    )

    # Category display order and headers
    $categories = @(
        @{ Name = "Tabs"; Header = "Tabs - Common"; HeaderColor = "Magenta" }
        @{ Name = "Panes-Split"; Header = "Panes - Split (1 mod key)"; HeaderColor = "Magenta" }
        @{ Name = "Panes-Navigation"; Header = "Panes - Navigation (2 mod keys)"; HeaderColor = "Magenta" }
        @{ Name = "Panes-Management"; Header = "Panes - Management (2 mod keys)"; HeaderColor = "Magenta" }
        @{ Name = "Panes-Advanced"; Header = "Panes - Advanced (3 mod keys, WT Only)"; HeaderColor = "Magenta" }
        @{ Name = "Edit-Common"; Header = "Edit - Common (2 mod keys)"; HeaderColor = "Magenta" }
        @{ Name = "Edit-Advanced"; Header = "Edit - Advanced (2-3 mod keys, WT Only)"; HeaderColor = "Magenta" }
        @{ Name = "FontSize"; Header = "Font Size - Common (1 mod key)"; HeaderColor = "Magenta" }
        @{ Name = "View-Display"; Header = "View - Display (2-3 mod keys, WT Only)"; HeaderColor = "Magenta" }
        @{ Name = "Scrolling"; Header = "Scrolling - Common (2 mod keys)"; HeaderColor = "Magenta" }
        @{ Name = "Settings"; Header = "Settings & Profiles (2-3 mod keys, WT Only)"; HeaderColor = "Magenta" }
        @{ Name = "GlazeWM"; Header = "GlazeWM Interaction"; HeaderColor = "Magenta" }
    )

    # Header
    Write-Host ""
    if ($useGum) {
        $header = & gum style --foreground 6 --bold "📺 Windows Terminal Cheat Sheet (Unified Shortcuts)"
        Write-Host $header
    } else {
        Write-Host "📺 Windows Terminal Cheat Sheet (Unified Shortcuts)" -ForegroundColor Cyan
    }
    Write-Host "============================================" -ForegroundColor Cyan
    Write-Host "Shortcuts aligned with WezTerm. Uses CTRL+SHIFT to avoid GlazeWM conflicts." -ForegroundColor DarkGray
    Write-Host ""

    # Display each category
    foreach ($cat in $categories) {
        $categoryShortcuts = $shortcuts | Where-Object { $_.Category -eq $cat.Name }
        if ($categoryShortcuts) {
            Write-Host ""
            Write-Host "[$($cat.Header)]" -ForegroundColor $cat.HeaderColor
            
            # Display shortcuts with colors
            foreach ($item in $categoryShortcuts) {
                $color = if ($item.Color -eq "Green") { "Green" } else { "Yellow" }
                Write-Host "  " -NoNewline
                Write-Host $item.Shortcut.PadRight(30) -NoNewline -ForegroundColor $color
                Write-Host $item.Description
                
                # Display justification if present
                if ($item.Justification) {
                    Write-Host "    " -NoNewline
                    Write-Host "Justification: " -NoNewline -ForegroundColor DarkGray
                    Write-Host $item.Justification -ForegroundColor DarkGray
                }
            }
        }
    }

    Write-Host ""
}

# Export functions
Export-ModuleMember -Function Show-WezTermHelp, Show-WTHelp, Test-CharmTools, Write-ColorText

# Set Aliases
Set-Alias -Name wezhelp -Value Show-WezTermHelp -Scope Global
Set-Alias -Name wthelp -Value Show-WTHelp -Scope Global
