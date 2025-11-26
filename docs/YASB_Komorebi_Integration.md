# YASB and Komorebi Integration Guide

## Overview

This document details the integration between YASB (Yet Another Status Bar) and Komorebi (Windows Tiling Window Manager), including common issues, research findings, and the working solution.

## Problem Description

Windows were tiling over the YASB status bar, causing content to be obscured. The status bar was not being respected by Komorebi's tiling system.

## Research Findings

### Common Issue

- **GitHub Issue Reference**: [yasb/issues/42](https://github.com/amnweb/yasb/issues/42)
- Komorebi does not automatically account for YASB bar height
- Windows overlap the status bar when tiling
- This is a known compatibility issue between Komorebi and YASB

### Configuration Approaches

#### Approach 1: `windows_app_bar: true` (YASB)

- Registers the bar with Windows Shell as an AppBar
- Should automatically reserve screen space
- **Issue**: May not work reliably with Komorebi's manual tiling system

#### Approach 2: Manual `work_area_offset` (Komorebi)

- Most users set `work_area_offset.top` to match YASB bar height
- Example: If bar height is 35px, set `work_area_offset.top: 35`
- **Status**: Recommended approach when using Komorebi

### Configuration Details

#### YASB Configuration (`config/config/yasb/config.yaml`)

```yaml
bars:
  status-bar:
    enabled: true
    screens: ['primary']
    dimensions:
      height: 35
    window_flags:
      windows_app_bar: true  # Registers with Windows Shell
      always_on_top: false
  
  status-bar-secondary:
    enabled: true
    screens: ['*']  # All screens
    dimensions:
      height: 35
    window_flags:
      windows_app_bar: true
      always_on_top: false
```

#### Komorebi Configuration (`config/config/komorebi/komorebi.json`)

```json
{
  "monitors": [
    {
      "work_area_offset": {
        "top": 0,      // Should match YASB bar height (35)
        "bottom": 0,
        "left": 0,
        "right": 0
      }
    }
  ]
}
```

### The Conflict

**Problem**: 
- YASB has `windows_app_bar: true` (expects Windows to reserve space)
- Komorebi has `work_area_offset.top: 0` (overrides Windows' automatic reservation)
- Result: Windows tile over the YASB bar

**Why it might have worked before**:
1. `work_area_offset` wasn't present in config (Komorebi respected Windows' automatic reservation)
2. `windows_app_bar` was `false` (no conflict)
3. Komorebi update changed how `work_area_offset` is handled
4. Windows update changed AppBar behavior

## ✅ Working Solution

**The actual fix was NOT a configuration change**, but rather a startup order and permissions issue:

### Steps to Fix

1. **Completely shut down YASB**
   - Close YASB completely (not just minimize)
   - Ensure no YASB processes are running

2. **Run YASB as Administrator**
   - Right-click YASB executable
   - Select "Run as administrator"
   - This ensures proper Windows AppBar registration

3. **Manually start Komorebi from YASB tray icon**
   - After YASB is running as admin, use the YASB tray icon context menu
   - Select the option to start Komorebi
   - This ensures proper startup order and integration

### Why This Works

- **Administrator privileges**: Ensures YASB can properly register with Windows Shell as an AppBar
- **Startup order**: Starting Komorebi after YASB ensures Komorebi recognizes the reserved space
- **Tray menu integration**: Using YASB's tray menu ensures proper initialization sequence

## Alternative Configuration-Based Solutions

If the startup order fix doesn't work, consider these configuration changes:

### Option 1: Set `work_area_offset.top` (Recommended)

Set `work_area_offset.top: 35` on all monitors in `komorebi.json`:

```json
{
  "monitors": [
    {
      "work_area_offset": {
        "top": 35,    // Match YASB bar height
        "bottom": 0,
        "left": 0,
        "right": 0
      }
    },
    {
      "work_area_offset": {
        "top": 35,    // Also needed for secondary monitors
        "bottom": 0,
        "left": 0,
        "right": 0
      }
    }
  ]
}
```

**Pros**: Explicit control, works reliably with Komorebi  
**Cons**: Manual configuration per monitor

### Option 2: Remove `work_area_offset` and rely on `windows_app_bar`

Remove `work_area_offset` from Komorebi config entirely:

```json
{
  "monitors": [
    {
      // No work_area_offset - rely on Windows AppBar
      "workspaces": [...]
    }
  ]
}
```

**Pros**: Automatic, less configuration  
**Cons**: May not work reliably with Komorebi's tiling

## Troubleshooting

### Windows Still Overlapping Bar

1. Verify YASB is running as Administrator
2. Check startup order (YASB before Komorebi)
3. Verify `windows_app_bar: true` in YASB config
4. Check `work_area_offset.top` matches bar height (if using manual offset)
5. Restart both services after configuration changes

### Bar Not Appearing

1. Check YASB is enabled in config
2. Verify screen configuration (`screens: ['primary']` or `screens: ['*']`)
3. Check YASB process is running
4. Verify class name matches (`yasb-bar` or `yasb-bar-secondary`)

### Komorebi Not Starting

1. Check YASB tray menu for Komorebi start option
2. Verify Komorebi executable path
3. Check Windows Event Viewer for errors
4. Try starting Komorebi manually first, then integrate with YASB

## Configuration Files Reference

- **YASB Config**: `config/config/yasb/config.yaml`
- **Komorebi Config**: `config/config/komorebi/komorebi.json`
- **Komorebi Apps Config**: `config/config/komorebi/applications.json`

## Related Resources

- [YASB GitHub Repository](https://github.com/amnweb/yasb)
- [YASB Documentation - Bar Configuration](https://deepwiki.com/amnweb/yasb/4.2-bar-configuration)
- [Komorebi GitHub Repository](https://github.com/LGUG2Z/komorebi)
- [Komorebi Documentation](https://lgug2z.github.io/komorebi/)

## Notes

- The bar height is **35 pixels** in this configuration
- Secondary bar is enabled on all screens (`screens: ['*']`)
- Both bars use `windows_app_bar: true` for Windows Shell integration
- Komorebi's `work_area_offset.top: 0` was causing the conflict

## Last Updated

Document created: 2024
Issue resolved: Startup order and administrator privileges

