# WinUtil Setup Proposals

## Current State Analysis

### ✅ What's Working
- **Profile.ps1** has two functions:
  - `winutil` - Downloads and executes WinUtil from `https://christitus.com/win`
  - `winutildev` - Downloads and executes WinUtil dev from `https://christitus.com/windev`
- Functions are already available in PowerShell sessions
- Functions are documented in the help system

### ❌ What's Missing
- **Setup.ps1** does NOT install or configure WinUtil
- No local installation option (always downloads on-the-fly)
- No verification that the functions work correctly

---

## Proposed Solutions

### Option 1: Keep Current Approach (Recommended for Simplicity)
**Pros:**
- Already working
- Always gets latest version
- No maintenance needed

**Cons:**
- Requires internet connection every time
- No offline capability

**Action Required:** None - already implemented

---

### Option 2: Add Local Installation to Setup.ps1
Download WinUtil script once and store it locally, then create a function that uses the local copy.

**Implementation:**
1. Add a section in Setup.ps1 to download WinUtil scripts
2. Store them in `$Env:DOTFILES\scripts\winutil\` or similar
3. Update Profile.ps1 functions to use local copy with fallback to online

**Pros:**
- Works offline after initial download
- Faster execution (no download delay)
- Version control possible

**Cons:**
- Requires manual updates
- Takes up disk space

---

### Option 3: Enhanced Functions with Caching
Keep current approach but add local caching for offline use.

**Implementation:**
1. Check if local cached copy exists
2. If exists and less than X days old, use it
3. Otherwise, download fresh copy and cache it
4. Fallback to online if cache fails

**Pros:**
- Best of both worlds
- Automatic updates
- Offline capability

**Cons:**
- More complex implementation

---

### Option 4: Create Standalone Script
Create a dedicated WinUtil script file that can be called directly.

**Implementation:**
1. Create `$Env:DOTPOSH\Scripts\winutil.ps1`
2. Add to PATH or create alias
3. Can be called as `winutil` command

**Pros:**
- More traditional approach
- Can be version controlled
- Easy to customize

**Cons:**
- Still need to download/update manually

---

## Recommended Implementation: Option 2 + Option 3 Hybrid

Combine local installation with smart caching:

1. **Setup.ps1**: Download WinUtil scripts during setup
2. **Profile.ps1**: Use cached version with auto-update check
3. **Fallback**: Always fallback to online if local fails

---

## Next Steps

Choose an option and I can implement it for you!

