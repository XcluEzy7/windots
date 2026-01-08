<h3>
<div align="center">
<img src="./.github/assets/title.png" alt="title">

<br>

A Windows 11 Dotfiles Repo infused with <a href="https://catppuccin.com/">Catppuccin</a> Theme
<a href="https://twitter.com/intent/tweet?text=Windows%2011%20Dotfiles%20Infused%20With%20Catppuccin%20Theme&url=https://github.com/jacquindev/windots"><img src="https://img.shields.io/badge/Tweet-share-8AADF4?style=social&logo=x&logoColor=8AADF4&labelColor=302D41&color=8AADF4" alt="TWITTER"></a>&nbsp;&nbsp;

</div>

<br>

</h3>

<div align="center">
<p>
  <a href="https://github.com/XcluEzy7/windots/commits/main"><img alt="Last Commit" src="https://img.shields.io/github/last-commit/XcluEzy7/windots?style=for-the-badge&logo=github&logoColor=EBA0AC&label=Last%20Commit&labelColor=302D41&color=EBA0AC"></a>&nbsp;&nbsp;
  <a href="https://github.com/XcluEzy7/windots/"><img src="https://img.shields.io/github/repo-size/XcluEzy7/windots?style=for-the-badge&logo=hyprland&logoColor=F9E2AF&label=Size&labelColor=302D41&color=F9E2AF" alt="REPO SIZE"></a>&nbsp;&nbsp;
  <a href="https://github.com/XcluEzy7/windots/blob/main/LICENSE"><img src="https://img.shields.io/github/license/XcluEzy7/windots?style=for-the-badge&logo=&color=CBA6F7&logoColor=CBA6F7&labelColor=302D41" alt="LICENSE"></a>&nbsp;&nbsp;
  <a href="https://github.com/XcluEzy7/windots/stargazers"><img alt="Stargazers" src="https://img.shields.io/github/stars/XcluEzy7/windots?style=for-the-badge&logo=starship&color=B7BDF8&logoColor=B7BDF8&labelColor=302D41"></a>&nbsp;&nbsp;
</p>
</div>

<hr>

> [!IMPORTANT]
> The below **screenshots** are taken on my main monitor, which has the **resolution of 3440x1440**.
> Configurations in this repository are compatible with wide screen monitors and have been tested on sizes ranging from **1920x1080** to **3440x1440**, but should work for any monitor size.
> 
> **Note:** The glassit VSCode extension was present in the original repository but has been removed from this fork as it did not work properly with my setup.

<br>

<div align="center">
  <a href="#preview"><kbd> <br> 🌆 Preview <br> </kbd></a>&ensp;&ensp;
  <a href="#install"><kbd> <br> 🌷 Install <br> </kbd></a>&ensp;&ensp;
  <a href="#extras"><kbd> <br> 🧱 Extras <br> </kbd></a>&ensp;&ensp;
  <a href="#features"><kbd> <br> ✨ Features <br> </kbd></a>&ensp;&ensp;
  <a href="#credits"><kbd> <br> 🎉 Credits <br> </kbd></a>&ensp;&ensp;
  <a href="#author"><kbd> <br> 👤 Author <br> </kbd></a>&ensp;&ensp;
</div>

<hr>

## ⚠️ Disclaimer

> [!NOTE]
> **This is a fork** of the original [windots](https://github.com/jacquindev/windots) repository by [@jacquindev](https://github.com/jacquindev). This fork has been customized for personal use and may differ from the original repository.
> 
> - **Original Repository**: Created by [@jacquindev](https://github.com/jacquindev) (Jacquin Moon) - [View Original Repo](https://github.com/jacquindev/windots)
> - **Original Author's Last Contribution** (to original repo): ~7 months ago (approximately May 2025)
> - **Fork Maintained By**: [@XcluEzy7](https://github.com/XcluEzy7) (Erik Garcia) - Independent changes began November 21, 2025

This repository contains configurations and dotfiles that have been adapted to fit personal preferences. Some apps or packages may have been **added** / **removed** / **reconfigured** from the original setup.

<br>

## ✨ Prerequisites

- **[Git for Windows](https://gitforwindows.org/)**
- **[PowerShell 7](https://github.com/PowerShell/PowerShell)**

***Highly Recommended:***

- **[Windows Terminal](https://aka.ms/terminal)** or **[Windows Terminal Preview](https://aka.ms/terminal-preview)**

<br>

<h2 id="preview">🌆 Preview</h2>

- 2 status bar options: [Rainmeter](https://github.com/modkavartini/catppuccin/tree/main) / [Yasb](./config/config/yasb)

### Yasb's Catppuccin Statusbar

![yasb1](./.github/assets/yasb1.png)<br/><br/>
![lazygit](./.github/assets/lazygit.png)<br/><br/>
![preview](./.github/assets/preview.png)<br/><br/>
![yasb3](./.github/assets/yasb3.png)<br/><br/>

### Rainmeter's Catppuccin Statusbar

![rainmeter1](./.github/assets/rainmeter1.png)<br/><br/>
![rainmeter2](./.github/assets/rainmeter2.png)<br/><br/>
![rainmeter3](./.github/assets/rainmeter3.png)<br/><br/>

- Transparent File Explorer

### [ExplorerBlurMica](https://github.com/Maplespe/ExplorerBlurMica) + [Catppuccin Themes](https://www.deviantart.com/niivu/art/Catppuccin-for-Windows-11-1076249390)

![fileexplorer](./.github/assets/fileexplorer.png)

<hr>

<h2 id="install">🌷 Install</h2>

- Simply clone this repo to `your_location`

```bash
git clone https://github.com/XcluEzy7/windots.git your_location
cd `your_location`
```

- In your **elevated** PowerShell Terminal, run: `.\Setup.ps1`

```pwsh
. .\Setup.ps1
```

<h4>🔧 Selective Installation & Reinstallation <small><i>(v0.02)</i></small></h4>
<h4>🌍 Dynamic Environment Variable Expansion <small><i>(v0.03)</i></small></h4>
<h4>🚀 Global Access & Tab Completion <small><i>(v0.04)</i></small></h4>
<h4>⚡ Quick re-install Command with w11dot-setup <small><i>(v0.05)</i></small></h4>
<h4>🔬 Improved PowerShell Experimental Features Support <small><i>(v0.06)</i></small></h4>
<h4>⚙️ PowerShell 5.1 Module Installation Support <small><i>(v0.07)</i></small></h4>
<h4>🔑 YASB GitHub Token Configuration <small><i>(v0.08)</i></small></h4>
<h4>🐧 WSL Configuration Setup with Terminal Editor Support <small><i>(v0.09)</i></small></h4>
<h4>🔄 Application Update Management <small><i>(v0.10)</i></small></h4>
<h4>⌨️ Terminal Shortcuts Cheatsheet Module <small><i>(v0.11)</i></small></h4>

> [!IMPORTANT]
> **PowerShell Module Installation**: PowerShell modules from the PowerShell Gallery must be installed in **PowerShell 5.1** (Windows PowerShell), not PowerShell 7.x. The `Setup.ps1` script automatically handles this by delegating module installation to PowerShell 5.1 (`powershell.exe`) even when the script itself runs in PowerShell 7.x. This ensures modules are installed in the correct location and are available to both PowerShell versions.

After the initial setup, `Setup.ps1` is automatically added to your PATH, allowing you to run it from anywhere in your terminal. The script also includes:
- **Function wrapper**: Call `w11dot-setup` from anywhere (e.g., `w11dot-setup -Environment -Force`)
- **Tab completion**: Press Tab after `w11dot-setup -` to see all available parameters with descriptions
- **Case-insensitive parameters**: `-Environment`, `-environment`, and `-ENVIRONMENT` all work the same
- **Always available**: Once the initial setup completes, the `w11dot-setup` command and `Setup.ps1` script are permanently available from any directory, allowing you to run specific installation sections whenever needed
- **Selective execution**: Run individual sections of the installer independently (e.g., `w11dot-setup -Packages`, `w11dot-setup -Git`) without running the full installation process
- **Automatic privilege escalation**: When running `w11dot-setup` commands, the function automatically uses `gsudo` to elevate privileges. A UAC prompt will appear - simply click "Yes" and the script will run with admin privileges. No need to manually open an elevated terminal!

Environment variables in `appList.json` now automatically expand to user-specific paths. No need to manually edit hardcoded paths - use placeholders like `%USERPROFILE%` or `%ProgramFiles%` and they will be automatically resolved to the correct paths for each user during setup.

PowerShell experimental features are now properly enabled with improved error handling and validation. The script correctly identifies feature names (e.g., `PSSubsystemPluginModel`), validates their existence before enabling, and provides clear warnings about PowerShell restart requirements. When `PSSubsystemPluginModel` is enabled, the script automatically attempts to install the `CompletionPredictor` module, with helpful guidance if a restart is required first.

The WSL setup section now includes interactive `.wslconfig` file configuration. When running `w11dot-setup -Wsl`, the script will:
- Copy the `.wslconfig` template from `config/home/.wslconfig` to your user profile
- Prompt you to configure the file with your system's resources (memory, processors, swap size, etc.)
- Open the file in a terminal editor (nvim or micro, if available) for editing before copying to the destination
- Wait for you to save and exit the editor, then automatically copy the configured file to `$env:USERPROFILE\.wslconfig`
- Allow you to skip configuration if you prefer to configure it later

The setup script supports skip parameters to run only specific sections of the installation. This is useful for:
- Reinstalling missing packages after issues
- Updating specific configurations
- Testing individual sections
- Force overwriting existing configurations

**Available Skip Parameters:**
- `-Packages` - Install/reinstall WinGet, Chocolatey, and Scoop packages
- `-PowerShell` - Setup PowerShell modules and experimental features
- `-Git` - Configure Git settings
- `-Symlinks` - Create symbolic links for dotfiles
- `-Environment` - Set environment variables
- `-Addons` - Install package addons/plugins
- `-VSCode` - Install VSCode extensions
- `-Themes` - Install Catppuccin themes
- `-Miscellaneous` - Run miscellaneous tasks (yazi plugins, bat themes)
- `-Komorebi` - Setup Komorebi & YASB engines
- `-NerdFonts` - Install Nerd Fonts
- `-WSL` - Install Windows Subsystem for Linux
- `-Updates` - Update all installed applications from appList.json

**Force Mode:**
Use the `-Force` parameter with any skip parameter to overwrite existing configurations or force reinstall packages.

**Examples:**
```pwsh
# From the repository directory (first time setup)
. .\Setup.ps1 -Packages

# From anywhere after initial setup (Setup.ps1 is in PATH)
w11dot-setup -Packages -Force
Setup.ps1 -Environment -Force
w11dot-setup -Git

# Force reinstall all packages even if already installed
w11dot-setup -Packages -Force

# Only setup environment variables, overwrite existing
w11dot-setup -Environment -Force

# Only setup symlinks, overwrite existing files
w11dot-setup -Symlinks -Force

# Only install VSCode extensions, reinstall even if exists
w11dot-setup -VSCode -Force

# Update all installed applications from appList.json
w11dot-setup -Updates
```

> [!NOTE]
> - Only one skip parameter can be used at a time. If no skip parameter is provided, the script runs the full installation as normal.
> - After the initial setup, `Setup.ps1` is added to PATH automatically. You may need to restart PowerShell or reload your profile for PATH changes to take effect.
> - Use `w11dot-setup` (function) or `Setup.ps1` (script) - both work from anywhere once PATH is configured.
> - Tab completion works for all parameter names - just type `w11dot-setup -` and press Tab to see available options.

> [!TIP]
> **Privilege Escalation**: The `w11dot-setup` function automatically uses `gsudo` to elevate privileges when needed. If `gsudo` is not installed, you'll see a warning and can install it with `winget install gerardog.gsudo`. The function will attempt to run without elevation as a fallback, but most setup operations require admin privileges.

<details>
<summary><b>🔄 Application Update Management <small><i>(v0.10)</i></small></b></summary>

<br>

The `-Updates` parameter allows you to update all installed applications listed in `appList.json` using their respective package managers. This feature intelligently manages updates across **Winget**, **Chocolatey**, and **Scoop** packages.

**Usage:**
```pwsh
# Update all installed applications
w11dot-setup -Updates

# Update only specific package managers (for testing)
.\updateApps.ps1 -Winget
.\updateApps.ps1 -Choco
.\updateApps.ps1 -Scoop
.\updateApps.ps1 -Choco -Scoop  # Multiple managers
```

**How It Works:**

1. **Smart Detection**: The script checks which package manager installed each application and uses the correct update command for that manager.

2. **Pre-Update Checks**: Before attempting to update, the script verifies if an update is actually available:
   - **Winget**: Compares installed version with available version using `winget list`
   - **Chocolatey**: Uses `choco outdated` to check for available updates
   - **Scoop**: Parses `scoop update` output to detect "latest version" status

3. **Privilege Management**: 
   - **Winget & Chocolatey**: Can run with admin privileges (automatically elevated if needed)
   - **Scoop**: **MUST** run as non-privileged user to prevent package corruption. The script automatically spawns a non-admin process when running as admin.

4. **PowerShell Module Packages**: Packages ending in `*psmodule` (e.g., `burnttoast-psmodule`) are automatically handled in PowerShell 5.1 context with `PowerShellGet` module imported, as required by Chocolatey's module installation process.

5. **Output & Logging**:
   - **Success Logs**: Saved to `%USERPROFILE%\w11dot_logs\apps\appUpdate_{timestamp}_success.log`
     - Concise entries showing package manager, package name, and version changes
     - Format: `✅ manager | package | version (or old -> new)`
   - **Error Logs**: Saved to `%USERPROFILE%\w11dot_logs\apps\appUpdate_{timestamp}_error.log`
     - Verbose error details for troubleshooting failed updates
   - **Console Output**: Clean, color-coded status messages:
     - `(up to date)` - Package is already at the latest version
     - `(success)` - Package was successfully updated
     - `(failed)` - Update encountered an error
     - `(skipped)` - Package is not installed

6. **Update Status Detection**:
   - Packages are marked as "up to date" if:
     - No newer version is available
     - Installed version matches available version
     - Package manager reports "already up to date" or "latest version"
   - Only packages that actually need updating will show "Updating..." message

**Best Practices:**
- Run `w11dot-setup -Updates` regularly to keep your applications current
- Check the success log to see which packages were updated and their version changes
- Review error logs if any packages fail to update
- Use individual package manager switches (`-Winget`, `-Choco`, `-Scoop`) for testing or selective updates

**Note**: The update process respects the `autoInstall` setting in `appList.json`. Only packages from package managers with `autoInstall: true` will be processed.

</details>

<details>
<summary><b>⌨️ Terminal Shortcuts Cheatsheet Module <small><i>(v0.11)</i></small></b></summary>

<br>

The `TerminalHelpers.psm1` module provides comprehensive cheat sheets for terminal shortcuts with unified keybindings across Windows Terminal and WezTerm.

**Usage:**
```pwsh
# Display WezTerm shortcuts
wezhelp
Show-WezTermHelp

# Display Windows Terminal shortcuts
wthelp
Show-WTHelp
```

**Features:**
- **Unified Shortcuts**: Common shortcuts are identical across both terminals for consistency
- **Color-Coded Display**: Uses PowerShell native colors (Green for common, Yellow for terminal-specific)
- **Organized Categories**: Shortcuts grouped by function (Tabs, Panes, Edit, Scrolling, etc.)
- **Justifications**: Explains why 3-modifier-key shortcuts are used for advanced features
- **GlazeWM Compatible**: All shortcuts use `Ctrl+Shift` to avoid conflicts with GlazeWM window manager
- **Auto-Loaded**: Module is automatically loaded via PowerShell profiles, available globally

**Shortcut Categories:**
- **Tabs**: New/close tabs, navigation between tabs
- **Panes**: Split (vertical/horizontal), navigation, management, advanced features
- **Edit**: Copy/paste, find/search, mark mode
- **Font Size**: Increase/decrease/reset font size
- **Scrolling**: Scroll up/down, jump to top/bottom
- **Settings**: Open settings, command palette, reload configuration
- **Special Features**: Terminal-specific features (WezTerm: copy mode, launcher menu, etc.)

**Key Design Principles:**
- Avoid 3-modifier keys (`Ctrl+Shift+Alt`) unless justified for advanced features
- Prefer `Ctrl + action key` or `Ctrl + Shift + action key` for common operations
- Visual shortcuts: `Ctrl+|` for vertical split, `Ctrl+\` for horizontal split
- Terminal-specific features clearly marked (e.g., "WT Only", "WezTerm Only")

**Module Location:**
- `dotposh/Modules/TerminalHelpers.psm1`
- Automatically loaded via PowerShell profiles (`Profile.ps1`, `WindowsProfile.ps1`)

</details>

<h4>⁉️ Overriding Defaults</h4>

> [!IMPORTANT]
> Before running the `Setup.ps1` script, please check the **[appList.json](./appList.json)** file to **ADD/REMOVE** the apps you would like to install.<br/>
>
> <b><i><ins>VSCode Extensions:</ins></i></b><br/>
> Edit the **[VSCode's extensions list](./extensions.list)** to **ADD/REMOVE** the extensions you would like to install.
>
> <b><i><ins>PowerShell Profile:</ins></i></b><br/>
> The `Profile.ps1` is symbolically linked to this repository. Be sure to overwrite the `Profile.ps1` if you do not want its settings and configuration, as these settings are specifically tailored for my workflow.

<br>

<details open>
<summary><b>😎 Clink Setup</b></summary>

- In your **`Command Prompt`** console, type:

  ```cmd
  clink installscripts "your_location\clink\clink-custom"
  clink installscripts "your_location\clink\clink-completions"
  clink installscripts "your_location\clink\clink-gizmos"
  clink installscripts "your_location\clink\more-clink-completions"
  ```

- Replace _`your_location`_ with full path to where you cloned this repository.

</details>

> [!NOTE]
> The [`clink-custom`](./clink/clink-custom/) directory contains Lua scripts to [extend `clink`](https://chrisant996.github.io/clink/clink.html#extending-clink) based on the programs you use. If you do not have the programs define in the scripts, they will not be activated.
>
> - custom prompt ➝ [`clink/clink-custom/prompt.lua`](./clink/clink-custom/prompt.lua).
>   (Only one of the following should be set to `true`, otherwise `false`)
>   - **`oh-my-posh`**: to enable, set *`local ohmyposh_enabled = true`*.
>   - **`starship`**: to enable, set *`local starship_enabled = true`*.
> - `vfox` ➝ [`clink/clink-custom/vfox.lua`](./clink/clink-custom/vfox.lua)
> - `zoxide` ➝ [`clink/clink-custom/zoxide.lua`](./clink/clink-custom/zoxide.lua)

<br>

<details>
<summary><b>🤦 Note to Self(Git-Noob): The Submodule That Lives Its Own Life</b></summary>

<br>

> [!WARNING]
> **Dear Future Me (and anyone else who stumbles upon this):**
>
> Yes, that `dotposh/Config/powershell-completions-collection` thing is a **submodule**. No, it's not broken. Yes, it will show as "modified content" in `git status` when it's in detached HEAD state (which is like 90% of the time because submodules are drama queens).
>
> **The Prayer Point to Fix Your Sanity:**
> ```powershell
> git submodule update --remote dotposh/Config/powershell-completions-collection
> ```
>
> This updates the submodule to the latest commit from its remote repository. Think of it as giving the submodule a reality check and telling it "hey, you should probably sync with your remote friends."
>
> **When Things Go Sideways (Because They Will):**
>
> 1. **Submodule is in detached HEAD?** (You'll know because `git status` will yell at you)
>   ```powershell
>   cd dotposh/Config/powershell-completions-collection
>   git checkout main  # or master, whatever branch it uses
>   cd ../../..
>   git add dotposh/Config/powershell-completions-collection
>   git commit -m "update submodule because it was being difficult again"
>   ```
>
> 2. **Want to update it to the latest?**
>   ```powershell
>   git submodule update --remote dotposh/Config/powershell-completions-collection
>   git add dotposh/Config/powershell-completions-collection
>   git commit -m "update powershell-completions-collection submodule"
>   ```
>
> 3. **Cloned the repo and submodule is empty?**
>   ```powershell
>   git submodule update --init --recursive
>   ```
>
> **Remember:** Submodules track specific commits, not branches. They're like that friend who always shows up at the exact commit you told them to, even if the world has moved on. You have to explicitly tell them to update. They won't do it themselves because they're too busy being... submodules.
>
> **TL;DR:** If `git status` shows the submodule as modified and you didn't change anything, just run `git submodule update --remote dotposh/Config/powershell-completions-collection` and commit the update. Your future self will thank you. Probably.

</details>

<br>

<details open>
<summary><b>⛏ Setup Development Tools with MISE <i>(mise-en-place)</i></b></summary>
<br>

Ensure that `mise` command available on your system (using `scoop install mise`)

```bash
# Enable experimental features:
mise settings experimental true
```

The below command with install latest LTS version of NodeJS, and also automatically install NPM global packages define in [`.default-npm-packages`](./config/home/.default-npm-packages)

```bash
# Install latest NodeJS LTS
mise use -g node@lts
```

For further information please visit: https://mise.jdx.dev.

<br>

<details open>
<summary><b>🌟 Bootstrap WSL</b></summary>
<br>

WSL setup can be done automatically by using [Ansible](https://docs.ansible.com/ansible/latest/index.html). Any details can be found here: https://github.com/jacquindev/automated-wsl2-setup.

➝ WSL dotfiles are maintained in [this](https://github.com/jacquindev/dotfiles) repository: https://github.com/jacquindev/dotfiles.

</details>
<br>

<h3 id="extras">⛏🧱 Extra Setup (optional)</h3>

Follow the below links to download and learn to how to setup:

<details>
<summary><b>🌈 Catppuccin Themes 🎨</b></summary>
<br>
<div align="center">
<table>
<tr>
  <td><a href="https://www.deviantart.com/niivu/art/Catppuccin-Cursors-921387705">Cursors</a></td>
  <td><img src="./.github/assets/cursors.png" alt="cursors"></td>
</tr>
<tr>
  <td><a href="https://www.deviantart.com/niivu/art/Catppuccin-for-Windows-11-1076249390">Themes</a></td>
  <td><img src="./.github/assets/themes.png" alt="themes"></td>
</tr>
</table>
</div>
</details>

<details>
<summary><b>🎸 Spicetify Setup 🎧</b></summary>
<br>

> [!NOTE]
> I do not use Spicetify personally. For setup and configuration details, please refer to the [original repository](https://github.com/jacquindev/windots).

</details>

<br>

<h2 id="features">✨ Features</h2>

- 💫 All packages to install are listed in **[appList.json file](./appList.json)** - Easy to maintain!
- 🔧 **Selective installation** - Run only specific sections with skip parameters (e.g., `-Packages`, `-Environment`, `-Symlinks`) for targeted updates and troubleshooting
- 🚀 **Global access** - `Setup.ps1` is added to PATH automatically, call `w11dot-setup` or `Setup.ps1` from anywhere with full tab completion support
- 🎨 Main theme [Catppuccin](https://github.com/catppuccin/catppuccin) for everything!
- 🎀 Minimal [Yasb](https://github.com/amnweb/yasb) status bar
- 💖 Beautiful **_[wallpapers](https://github.com/jacquindev/windots/tree/main/windows/walls#readme)_**, and [live wallpapers](./windows/walls/live-walls/) for [Lively Wallpapers](https://www.rocksdanister.com/lively/)
- 🪟 [Komorebi](./config/komorebi) config
- 🌸 All-In-One VSCode setup (**_[extensions list](./extensions.list)_**)
- ⚙️ [Rainmeter](./windows/rainmeter/) setup
- \>\_ Sleek [Windows Terminal config](./config/AppData/Local/Packages/Microsoft.WindowsTerminal_8wekyb3d8bbwe/LocalState/settings.json)
- 🌈 Oh-My-Posh [minimal theme](./dotposh/posh-zen.toml)
- 🦄 **Super fast** PowerShell startup time _(load asynchronously)_ + [custom configurations & modules](./dotposh/)
- ⌨️ **Terminal Shortcuts Cheatsheet** - Unified shortcuts for Windows Terminal and WezTerm with `wezhelp` and `wthelp` commands
- 🍄 Simple fastfetch configuration, which I copied from [scottmckendry's config](https://github.com/scottmckendry/Windots/tree/main/fastfetch)
- 🥂 Many [addons](#git-addons) for Git!
- 🐱 Use [MISE](https://mise.jdx.dev/) *(mise-en-place)* to manage [development tools](https://mise.jdx.dev/dev-tools/). Learn more about `mise` here: https://mise.jdx.dev/

<details open>
<br>
<summary><b>🖥️ CLI/TUI Apps</b></summary>

| Entry                 | App                                                                                           |
| --------------------- | --------------------------------------------------------------------------------------------- |
| **Terminal Emulator** | [Windows Terminal](https://github.com/microsoft/terminal) [⚙️](./config/AppData/Local/Packages/Microsoft.WindowsTerminal_8wekyb3d8bbwe/LocalState/settings.json)       |
| **File Explorer**     | [yazi](https://github.com/sxyazi/yazi) [⚙️](./config/config/yazi/)                                   |
| **Fuzzy File Finder** | [fzf](https://github.com/junegunn/fzf)                                                        |
| **System Monitor**    | [btop](https://github.com/aristocratos/btop)                                                  |
| **System Fetch**      | [fastfetch](https://github.com/fastfetch-cli/fastfetch) [⚙️](./config/AppData/Local/fastfetch/config.jsonc) |
| **Git TUI**           | [lazygit](https://github.com/jesseduffield/lazygit) [⚙️](./config/AppData/Local/lazygit/config.yml)         |

</details>

<br>

<details open>
<br>
<summary><b>🌎 Replacement</b></summary>

| Entry | App                                                                      |
| ----- | ------------------------------------------------------------------------- |
| cat   | [bat](https://github.com/sharkdp/bat) [⚙️](./config/AppData/Roaming/bat/config) |
| cd    | [zoxide](https://github.com/ajeetdsouza/zoxide) |
| ls    | [eza](https://github.com/eza-community/eza) [⚙️](./config/eza/theme.yml) |
| find  | [fd](https://github.com/sharkdp/fd) |
| grep  | [ripgrep](https://github.com/sharkdp/ripgrep) |

</details>

<br>

<details open>
<br>
<summary><b>🖱️ GUI Apps</b></summary>

| Entry | App |
| ----- | --- |
| **App Launcher** | [PowerToys Run](https://learn.microsoft.com/en-us/windows/powertoys/run) (PowerToys) |
| **Git Clients** | [GitHub Desktop](https://desktop.github.com/), [GitKraken](https://www.gitkraken.com/) |
| **IDEs** | [IntelliJ IDEA Community](https://www.jetbrains.com/idea/), [Visual Studio Code](https://code.visualstudio.com/) |
| **Text Editors** | [Notepad++](https://notepad-plus-plus.org/), [Obsidian](https://obsidian.md/) |
| **Development** | [DevPod](https://devpod.sh/) (Client-Only Codespaces), [Postman](https://www.postman.com/) |
| **Containerization** | [Podman Desktop](https://podman-desktop.io/), [VirtualBox](https://www.virtualbox.org/) |
| **Security** | [Kleopatra](https://www.gpg4win.org/about.html) (GPG Key Manager) |
| **System Tools** | [PowerToys](https://github.com/microsoft/PowerToys), [Start11](https://www.stardock.com/products/start11/) |
| **Networking** | [ProtonVPN](https://protonvpn.com/), [Synergy](https://symless.com/synergy) |
| **Customization** | [Rainmeter](https://www.rainmeter.net/), [Lively Wallpaper](https://www.rocksdanister.com/lively/) |

</details>

<br>

<details open>
<br>
<summary id="git-addons"><b>📌 Git Addons</b></summary>

| Installer | Link | Description |
| --- | --- | --- |
| winget | **[GitHub Desktop](https://github.com/apps/desktop)** | Simple collaboration from your desktop.|
| winget | **[GitKraken Desktop](https://www.gitkraken.com/)** | Dev Tools that simplify & supercharge Git. |
| scoop | **[gh](https://github.com/cli/cli)** | Bring GitHub to the command line. |
| scoop | **[git-aliases](https://github.com/AGWA/git-crypt)** | Oh My Zsh's Git aliases for PowerShell. |
| scoop | **[git-crypt](https://github.com/AGWA/git-crypt)** | Transparent file encryption in Git. |
| scoop | **[git-filter-repo](https://github.com/newren/git-filter-repo)** | Quickly rewrite git repository history (filter-branch replacement). |
| scoop | **[git-lfs](https://git-lfs.com/)** | Improve then handling of large files. |
| scoop | **[git-sizer](https://github.com/github/git-sizer)** | Compute various size metrics for a Git repository. |
| scoop | **[gitleaks](https://github.com/gitleaks/gitleaks)** | Detect secrets like passwords, API keys, and tokens. |
| npm | **[commitizen](https://github.com/commitizen/cz-cli)** + **[cz-git](https://cz-git.qbb.sh/)** | Write better Git commits. |
| npm | **[git-open](https://github.com/paulirish/git-open)** | Open the GitHub page or website for a repository in your browser. |
| npm | **[git-recent](https://github.com/paulirish/git-recent)** | See your latest local git branches, formatted real fancy. |
| | **[git aliases](https://github.com/GitAlias/gitalias/blob/main/gitalias.txt)** | Include [git aliases](./config/config/gitaliases) for `git` command for faster version control. |

</details>

<details open>
<br>
<summary><b>📝 Text Editor / Note Taking</b></summary>

- [Notepad++](https://notepad-plus-plus.org/)
- [Obsidian](https://obsidian.md/)
- [Visual Studio Code](https://code.visualstudio.com/) [⚙️](./config/AppData/Roaming/Code/User/settings.json)

</details>

<br>

<h2 id="credits">🎉 Credits</h2>

Big thanks for those inspirations:

- [scottmckendry's Windots](https://github.com/scottmckendry/Windots)
- [ashish0kumar's windots](https://github.com/ashish0kumar/windots)
- [MattFTW's Dotfiles](https://github.com/Matt-FTW/dotfiles) - Most of my wallpapers are from here.
- [DevDrive PowerShell's Scripts](https://github.com/ran-dall/Dev-Drive) - I copied most of DevDrive's functions for PowerShell here.

<br>

<h2 id="author">👤 Author</h2>

### Original Author

- Name: **Jacquin Moon**
- Github: [@jacquindev](https://github.com/jacquindev)
- Email: jacquindev@outlook.com
- **Original Repository**: [jacquindev/windots](https://github.com/jacquindev/windots)
- **Last Contribution** (to original repo): ~7 months ago (approximately May 2025)

### Current Maintainer

- Name: **Erik Garcia**
- Github: [@XcluEzy7](https://github.com/XcluEzy7)
- Email: eagarcia@techforexcellence.org
- **Fork Repository**: [XcluEzy7/windots](https://github.com/XcluEzy7/windots)
- **Independent Changes Began**: November 21, 2025

<br>

<h2 id="license">📜 License</h2>

This repository is released under the [MIT License](https://github.com/XcluEzy7/windots/blob/main/LICENSE).

Feel free to use and modify these dotfiles to suit your needs.

<br>

## Show your support

Please give a ⭐️ if this project helped you!

<a href="https://www.buymeacoffee.com/jacquindev" target="_blank"><img src="https://cdn.buymeacoffee.com/buttons/default-orange.png" alt="Buy Me A Coffee" height="43" width="176"></a>
