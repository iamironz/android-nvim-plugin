# Keymap Reference

## Scope

This page defines default command mappings and panel-local controls.

## Default Command Mappings

Defaults apply when `keymaps.enabled = true`.
Only these five commands receive default leader mappings.

| Mapping | Command | Plug Mapping |
| --- | --- | --- |
| `<leader>am` | `:AndroidMenu` | `<Plug>(AndroidMenu)` |
| `<leader>at` | `:AndroidTargets` | `<Plug>(AndroidTargets)` |
| `<leader>ao` | `:AndroidTools` | `<Plug>(AndroidTools)` |
| `<leader>aa` | `:AndroidActions` | `<Plug>(AndroidActions)` |
| `<leader>ab` | `:AndroidBuild` | `<Plug>(AndroidBuild)` |

## Additional Command Plug Mappings

These commands have no default leader mapping.

| Command | Plug Mapping |
| --- | --- |
| `:AndroidRun` | `<Plug>(AndroidRun)` |
| `:AndroidRunStop` | `<Plug>(AndroidRunStop)` |
| `:AndroidLogcat` | `<Plug>(AndroidLogcat)` |
| `:AndroidBuildPrompt` | `<Plug>(AndroidBuildPrompt)` |
| `:AndroidBuildAssemble` | `<Plug>(AndroidBuildAssemble)` |
| `:AndroidGradleTasks` | `<Plug>(AndroidGradleTasks)` |
| `:AndroidIOSBuild` | `<Plug>(AndroidIOSBuild)` |
| `:AndroidIOSDeploy` | `<Plug>(AndroidIOSDeploy)` |

Disable defaults:

```lua
require("android").setup({
  keymaps = {
    enabled = false,
  },
})
```

Override selected mappings:

```lua
require("android").setup({
  keymaps = {
    mappings = {
      menu = "<leader>mm",
      actions = false,
    },
  },
})
```

Map a direct command manually:

```lua
vim.keymap.set("n", "<leader>ar", "<Plug>(AndroidRun)", { remap = true, silent = true })
```

## Logcat Dock Controls

| Key | Action |
| --- | --- |
| `q` | Close panel |
| `c` | Clear output |
| `C` | Clear output and reset pause |
| `p` | Pause or resume stream |
| `r` | Restart logcat |
| `gp` | Select package |
| `gf` | Edit text filter |
| `gl` | Select level |
| `gs` | Switch run config |
| `<CR>` | Header: edit field. Body: stack trace jump |

## Build Output Dock Controls

| Key | Action |
| --- | --- |
| `f` | Edit build filter |
| `<CR>` | On control strip row, open filter edit |

Dock controls are available from both control strip and output body buffers.

## Related Docs

- Command inventory: [commands.md](commands.md)
- Navigation model: [../guides/navigation.md](../guides/navigation.md)
