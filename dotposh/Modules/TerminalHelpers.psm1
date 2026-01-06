
function Show-WezTermHelp {
    <#
    .SYNOPSIS
        Displays a cheat sheet for WezTerm shortcuts (GlazeWM Optimized).
    #>
    [CmdletBinding()]
    param()

    Write-Host "`n⚡ WezTerm Cheat Sheet (GlazeWM Optimized)" -ForegroundColor Magenta
    Write-Host "=========================================" -ForegroundColor Magenta
    Write-Host "Modifier: CTRL + SHIFT (avoids GlazeWM's Alt/Win bindings)" -ForegroundColor DarkGray

    Write-Host "`n[Tabs]" -ForegroundColor Cyan
    Write-Host "  Ctrl + Shift + T      " -NoNewline -ForegroundColor Green; Write-Host "New Tab"
    Write-Host "  Ctrl + Shift + W      " -NoNewline -ForegroundColor Green; Write-Host "Close Tab"
    Write-Host "  Ctrl + Tab            " -NoNewline -ForegroundColor Green; Write-Host "Next Tab"
    Write-Host "  Ctrl + Shift + Tab    " -NoNewline -ForegroundColor Green; Write-Host "Previous Tab"
    Write-Host "  Ctrl + Shift + [      " -NoNewline -ForegroundColor Green; Write-Host "Previous Tab (Alternative)"
    Write-Host "  Ctrl + Shift + ]      " -NoNewline -ForegroundColor Green; Write-Host "Next Tab (Alternative)"

    Write-Host "`n[Panes]" -ForegroundColor Cyan
    Write-Host "  Ctrl + Shift + %      " -NoNewline -ForegroundColor Green; Write-Host "Split Horizontal (Side-by-Side)"
    Write-Host "  Ctrl + Shift + ""      " -NoNewline -ForegroundColor Green; Write-Host "Split Vertical (Top-Bottom)"
    Write-Host "  Ctrl + Shift + Arrow  " -NoNewline -ForegroundColor Green; Write-Host "Navigate Panes"
    
    Write-Host "`n[Edit]" -ForegroundColor Cyan
    Write-Host "  Ctrl + Shift + C      " -NoNewline -ForegroundColor Green; Write-Host "Copy"
    Write-Host "  Ctrl + Shift + V      " -NoNewline -ForegroundColor Green; Write-Host "Paste"
    
    Write-Host "`n[View]" -ForegroundColor Cyan
    Write-Host "  Ctrl + + / -          " -NoNewline -ForegroundColor Green; Write-Host "Zoom In/Out"
    Write-Host "  Ctrl + 0              " -NoNewline -ForegroundColor Green; Write-Host "Reset Zoom"
    
    Write-Host ""
}

function Show-WTHelp {
    <#
    .SYNOPSIS
        Displays a cheat sheet for Windows Terminal shortcuts (GlazeWM Safe Recommendations).
    #>
    [CmdletBinding()]
    param()

    Write-Host "`n📺 Windows Terminal Cheat Sheet (GlazeWM Safe)" -ForegroundColor Cyan
    Write-Host "============================================" -ForegroundColor Cyan
    Write-Host "Recommended: Use CTRL+SHIFT to avoid GlazeWM conflicts." -ForegroundColor DarkGray

    Write-Host "`n[Tabs]" -ForegroundColor Magenta
    Write-Host "  Ctrl + Shift + T      " -NoNewline -ForegroundColor Green; Write-Host "New Tab"
    Write-Host "  Ctrl + Shift + W      " -NoNewline -ForegroundColor Green; Write-Host "Close Tab"
    Write-Host "  Ctrl + Tab            " -NoNewline -ForegroundColor Green; Write-Host "Next Tab"
    Write-Host "  Ctrl + Shift + Tab    " -NoNewline -ForegroundColor Green; Write-Host "Previous Tab"

    Write-Host "`n[Panes (Default Keys)]" -ForegroundColor Magenta
    Write-Host "  Alt + Shift + +       " -NoNewline -ForegroundColor Yellow; Write-Host "Split Vertical (May conflict w/ GlazeWM Move)"
    Write-Host "  Alt + Shift + -       " -NoNewline -ForegroundColor Yellow; Write-Host "Split Horizontal"
    Write-Host "  Tip: " -NoNewline -ForegroundColor Cyan; Write-Host "Rebind these to " -NoNewline; Write-Host "Ctrl+Shift+Plus/Minus" -ForegroundColor Green; Write-Host " in Settings."

    Write-Host "`n[Edit]" -ForegroundColor Magenta
    Write-Host "  Ctrl + C              " -NoNewline -ForegroundColor Green; Write-Host "Copy (if selected)"
    Write-Host "  Ctrl + Shift + V      " -NoNewline -ForegroundColor Green; Write-Host "Paste"

    Write-Host "`n[GlazeWM Interaction]" -ForegroundColor Magenta
    Write-Host "  LWin + Enter          " -NoNewline -ForegroundColor Green; Write-Host "Launch Terminal (GlazeWM Bind)"
    Write-Host "  LWin + F              " -NoNewline -ForegroundColor Green; Write-Host "Fullscreen Window"
    
    Write-Host ""
}

# Export functions
Export-ModuleMember -Function Show-WezTermHelp, Show-WTHelp

# Set Aliases
Set-Alias -Name wezhelp -Value Show-WezTermHelp -Scope Global
Set-Alias -Name wthelp -Value Show-WTHelp -Scope Global
