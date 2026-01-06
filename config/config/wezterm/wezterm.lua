local wezterm = require 'wezterm'
local act = wezterm.action

local config = {}

if wezterm.config_builder then
  config = wezterm.config_builder()
end

-- Appearance
config.color_scheme = 'Catppuccin Mocha'
config.font = wezterm.font_with_fallback {
  'JetBrainsMono Nerd Font',
  'Cascadia Code',
  'Consolas',
}
config.font_size = 11.0
config.line_height = 1.1

-- Window
config.window_background_opacity = 0.90
config.win32_system_backdrop = 'Acrylic'
config.window_decorations = "RESIZE" -- Integrated titlebar, resizable
config.window_padding = {
  left = 20,
  right = 20,
  top = 20,
  bottom = 20,
}

-- Tabs
config.use_fancy_tab_bar = false
config.hide_tab_bar_if_only_one_tab = true
config.tab_bar_at_bottom = true

-- Keys
config.keys = {
  -- Turn off default Alt-Enter fullscreen to avoid conflicts
  {
    key = 'Enter',
    mods = 'ALT',
    action = act.DisableDefaultAssignment,
  },
  -- Ctrl+Shift+T to open new tab (standard)
  {
    key = 't',
    mods = 'CTRL|SHIFT',
    action = act.SpawnTab 'CurrentPaneDomain',
  },
  -- Ctrl+Shift+W to close tab
  {
    key = 'w',
    mods = 'CTRL|SHIFT',
    action = act.CloseCurrentTab{ confirm = true },
  },
}

-- Shell (Default to PowerShell Core if available, else Windows PowerShell)
-- Since this is a windots repo, we assume pwsh is preferred
config.default_prog = { 'pwsh.exe', '-NoLogo' }

return config
