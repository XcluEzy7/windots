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
-- GlazeWM uses Alt and Alt+Shift heavily.
-- WezTerm will use Ctrl+Shift to avoid conflicts.
config.keys = {
  -- Disable Alt-Enter fullscreen to let GlazeWM handle window states
  {
    key = 'Enter',
    mods = 'ALT',
    action = act.DisableDefaultAssignment,
  },
  
  -- Tab Management (Ctrl+Shift)
  {
    key = 't',
    mods = 'CTRL|SHIFT',
    action = act.SpawnTab 'CurrentPaneDomain',
  },
  {
    key = 'w',
    mods = 'CTRL|SHIFT',
    action = act.CloseCurrentTab{ confirm = true },
  },
  -- Ctrl+Tab (Standard)
  {
    key = 'Tab',
    mods = 'CTRL',
    action = act.ActivateTabRelative(1),
  },
  {
    key = 'Tab',
    mods = 'CTRL|SHIFT',
    action = act.ActivateTabRelative(-1),
  },
  -- Ctrl+Shift+[ and Ctrl+Shift+]
  -- Note: Shift+[ produces {, so we bind to {
  {
    key = '{',
    mods = 'CTRL|SHIFT',
    action = act.ActivateTabRelative(-1),
  },
  {
    key = '}',
    mods = 'CTRL|SHIFT',
    action = act.ActivateTabRelative(1),
  },

  -- Pane Management (Split)
  -- Using | and \ (Visual similarity to vertical/horizontal lines)
  -- Aligned with Windows Terminal for consistency
  -- Note: | requires Shift+\ on most keyboards, so we bind to the pipe character
  {
    key = '|',
    mods = 'CTRL',
    action = act.SplitVertical{ domain =  'CurrentPaneDomain' },
  },
  {
    key = '\\',
    mods = 'CTRL',
    action = act.SplitHorizontal{ domain =  'CurrentPaneDomain' },
  },
  
  -- Pane Navigation
  {
    key = 'LeftArrow',
    mods = 'CTRL|SHIFT',
    action = act.ActivatePaneDirection 'Left',
  },
  {
    key = 'RightArrow',
    mods = 'CTRL|SHIFT',
    action = act.ActivatePaneDirection 'Right',
  },
  {
    key = 'UpArrow',
    mods = 'CTRL|SHIFT',
    action = act.ActivatePaneDirection 'Up',
  },
  {
    key = 'DownArrow',
    mods = 'CTRL|SHIFT',
    action = act.ActivatePaneDirection 'Down',
  },
  
  -- Pane Close (Unified with Windows Terminal)
  {
    key = 'x',
    mods = 'CTRL|SHIFT',
    action = act.CloseCurrentPane{ confirm = true },
  },

  -- Copy/Paste
  {
    key = 'c',
    mods = 'CTRL|SHIFT',
    action = act.CopyTo 'Clipboard',
  },
  {
    key = 'v',
    mods = 'CTRL|SHIFT',
    action = act.PasteFrom 'Clipboard',
  },
  
  -- Font Size
  {
    key = '+',
    mods = 'CTRL',
    action = act.IncreaseFontSize,
  },
  {
    key = '-',
    mods = 'CTRL',
    action = act.DecreaseFontSize,
  },
  {
    key = '0',
    mods = 'CTRL',
    action = act.ResetFontSize,
  },
}

-- Shell
config.default_prog = { 'pwsh.exe', '-NoLogo' }

return config
