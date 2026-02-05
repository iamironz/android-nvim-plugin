# Getting Started

## Purpose

Get to a successful first run quickly, then branch into the right workflow guide.

## Prerequisites

| Area | Requirement |
| --- | --- |
| Neovim | 0.9+ with Lua support |
| Android | Android SDK tools and `adb` |
| iOS (optional) | Xcode tools |
| Picker UI | Telescope optional, `vim.ui` fallback is supported |

## Setup

1. Install the plugin. See [install.md](install.md).
1. Add setup in your Neovim config:

```lua
require("android").setup()
```

1. Restart Neovim.

Minimal lazy.nvim example:

```lua
{
  "iamironz/android-nvim-plugin",
  lazy = false,
  config = function()
    require("android").setup()
  end,
}
```

## First Successful Run

1. Open a project root.
1. Run `:AndroidMenu`.
1. Select a section using `[1]`, `[2]`, or `<CR>`.
1. Use `/` for search, `<Left>` to go back, and `<Right>` to open selection.

## Validate Environment

If setup fails, run `:checkhealth android` first.

Common issue path: [support/troubleshooting.md#sdk-not-found](support/troubleshooting.md#sdk-not-found)

## Next Steps

- Build and deploy: [guides/build-and-deploy.md](guides/build-and-deploy.md)
- Logcat: [guides/logcat.md](guides/logcat.md)
- Devices and ADB: [guides/devices-and-adb.md](guides/devices-and-adb.md)
- Run configs: [guides/run-configs.md](guides/run-configs.md)
- Configuration reference: [reference/configuration.md](reference/configuration.md)
