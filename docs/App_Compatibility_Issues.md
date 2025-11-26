# Application Compatibility Issues

This document tracks known compatibility issues between applications and the window management system (Komorebi/YASB).

## Lively Wallpaper (mpv) Click Crash Issue

### Problem Description

When everything is working correctly and you're on an empty workspace viewing the Lively Wallpaper (which uses `mpv.exe` as the wallpaper engine), clicking on the wallpaper causes a crash. After the crash, one of the following issues occurs:

1. **Komorebi window sizing breaks** - Windows no longer tile correctly or respect sizing rules
2. **YASB Windows AppBar registration breaks** - The status bar loses its AppBar registration and windows tile over it

### Current Configuration

The mpv wallpaper instances are configured to be ignored in Komorebi:

**File**: `config/config/komorebi/applications.json`

```json
"mpv": {
  "ignore": [
    {
      "kind": "Title",
      "id": " - mpv",
      "matching_strategy": "EndsWith"
    }
  ],
  "object_name_change": [
    {
      "kind": "Class",
      "id": "mpv",
      "matching_strategy": "Legacy"
    }
  ]
}
```

This rule ignores mpv windows with titles ending in " - mpv" (the wallpaper instances), while allowing regular mpv video player windows to be managed normally.

### Root Cause Analysis

Based on research and analysis, the likely cause is:

1. **Focus Event Conflict**: The mpv wallpaper window is ignored by Komorebi, but when clicked, it sends a focus event
2. **State Corruption**: Komorebi attempts to handle focus for a window it's configured to ignore, causing a crash or state corruption
3. **Cascade Failure**: After the crash:
   - Komorebi's internal state becomes corrupted → window sizing breaks
   - YASB's `windows_app_bar` registration is lost → requires restart to re-register

### Related Issues Found

While no exact duplicate of this specific issue was found, related patterns include:

1. **Phantom Tiles / Ghost Windows**
   - Komorebi can leave invisible windows in its state
   - These can cause focus/state issues
   - Reference: [Komorebi Troubleshooting Guide](https://lgug2z.github.io/komorebi/troubleshooting.html)

2. **Focus Handling on Ignored Windows**
   - Clicking ignored windows can trigger focus events
   - Komorebi may try to process focus for windows it shouldn't manage
   - This can lead to state inconsistencies

3. **State Corruption After Crashes**
   - After a crash, Komorebi's internal state can become inconsistent
   - Window sizing can break
   - YASB's `windows_app_bar` registration can be lost
   - Solution: restart both services

4. **Empty Workspace Focus Issues**
   - Empty workspaces can cause focus anomalies
   - Multiple `komorebic.exe` instances can spawn
   - Reference: [PythonRepo YASB discussion](https://pythonrepo.com/repo/denBot-yasb-python-graphical-user-interface-applications)

### Potential Solutions

#### Solution 1: Prevent Focus on Ignored Windows

**Approach**: Configure mpv wallpaper windows to not accept focus

- May require mpv configuration changes
- Or Lively Wallpaper settings to prevent clicks from reaching mpv
- **Status**: Needs investigation

#### Solution 2: Improve Ignore Rule

**Approach**: Make the ignore rule more specific and comprehensive

Current rule only matches by title. Could enhance with:
- Combined rules (title + exe + class)
- More specific matching to ensure wallpaper instances are fully ignored
- **Status**: Can be tested

**Example Enhanced Rule**:
```json
"mpv": {
  "ignore": [
    [
      {
        "kind": "Exe",
        "id": "mpv.exe",
        "matching_strategy": "Equals"
      },
      {
        "kind": "Title",
        "id": " - mpv",
        "matching_strategy": "EndsWith"
      }
    ]
  ]
}
```

#### Solution 3: Add Crash Recovery

**Approach**: Implement automatic recovery mechanisms

- Auto-restart Komorebi on crash detection
- Re-register YASB app bar after restart
- **Status**: Would require scripting/monitoring

#### Solution 4: Investigate mpv/Lively Configuration

**Approach**: Configure mpv or Lively Wallpaper to prevent focus

- Check if mpv can be configured to not accept focus
- Check if Lively Wallpaper can prevent clicks from reaching mpv
- May need to configure Lively Wallpaper settings
- **Status**: Needs investigation

#### Solution 5: Workaround - Avoid Clicking Wallpaper

**Approach**: User behavior workaround

- Simply avoid clicking on the wallpaper when on empty workspaces
- Use workspace switching or open applications instead
- **Status**: Temporary workaround until fix is found

### Immediate Fix After Crash

When the issue occurs, the following steps restore functionality:

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

### Debugging Steps

To help identify the root cause:

1. **Check Windows Event Viewer**
   - Look for crash logs or error messages
   - Check Application and System logs around the time of the crash

2. **Check Komorebi Logs**
   - If Komorebi has logging enabled, review logs
   - Look for errors related to focus handling or window management

3. **Test Scenarios**
   - Does it happen only on empty workspaces?
   - Does it happen with other windows present?
   - Does it happen with different wallpaper types?

4. **Monitor Processes**
   - Check if multiple `komorebic.exe` instances spawn
   - Monitor mpv process behavior during click

### Related Documentation

- [YASB and Komorebi Integration Guide](./YASB_Komorebi_Integration.md)
- [Komorebi Troubleshooting Guide](https://lgug2z.github.io/komorebi/troubleshooting.html)
- [Komorebi Application Rules Documentation](https://lgug2z.github.io/komorebi/common-workflows/application-rules.html)

### Status

- **Issue**: Confirmed and reproducible
- **Priority**: Medium (workaround available)
- **Resolution**: Pending investigation

### Last Updated

Document created: 2024
Issue first reported: 2024

