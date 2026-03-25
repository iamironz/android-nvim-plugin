# Command Reference

## Scope

This page defines the zero-arg command surface, default shortcuts,
`<Plug>` mappings, and AndroidMenu inventory.

For step-by-step usage, see [navigation guide](../guides/navigation.md),
[build and deploy guide](../guides/build-and-deploy.md), and
[logcat guide](../guides/logcat.md).

## Commands With Default Shortcuts

| Command | Description | Default Shortcut | Plug Mapping |
| --- | --- | --- | --- |
| `:AndroidMenu` | Show main hub menu | `<leader>am` | `<Plug>(AndroidMenu)` |
| `:AndroidTargets` | Show Build Variants hub | `<leader>at` | `<Plug>(AndroidTargets)` |
| `:AndroidTools` | Show Device Manager and ADB hub | `<leader>ao` | `<Plug>(AndroidTools)` |
| `:AndroidActions` | Show actions hub | `<leader>aa` | `<Plug>(AndroidActions)` |
| `:AndroidBuild` | Build Android with saved defaults | `<leader>ab` | `<Plug>(AndroidBuild)` |

## Direct Commands (No Default Shortcut)

| Command | Description | Plug Mapping |
| --- | --- | --- |
| `:AndroidRun` | Run current config | `<Plug>(AndroidRun)` |
| `:AndroidRunStop` | Stop active run jobs | `<Plug>(AndroidRunStop)` |
| `:AndroidLogcat` | Open logcat panel | `<Plug>(AndroidLogcat)` |
| `:AndroidBuildPrompt` | Build Android with prompts | `<Plug>(AndroidBuildPrompt)` |
| `:AndroidBuildAssemble` | Build Android assemble only | `<Plug>(AndroidBuildAssemble)` |
| `:AndroidGradleTasks` | Open composite-aware Gradle task picker | `<Plug>(AndroidGradleTasks)` |
| `:AndroidIOSBuild` | Build iOS project | `<Plug>(AndroidIOSBuild)` |
| `:AndroidIOSDeploy` | Deploy iOS project | `<Plug>(AndroidIOSDeploy)` |

## Diagnostics

- `:checkhealth android` validates SDK tools, Gradle command resolution,
  and iOS tooling on macOS.

## AndroidMenu Items

Items appear only when workspace capabilities and current run target context
support them. Android and iOS actions can be hidden when the selected run
target is incompatible.

| Section | Item | Notes |
| --- | --- | --- |
| Run Configurations | Run config entries | Select active run configuration (`*` marks current) |
| Run | Run current | Runs selected run config |
| Run | Stop run | Stops active run jobs |
| Build Variants | Build default | Build and deploy using saved module and variant |
| Build Variants | Build assemble only | Build without deploy |
| Build Variants | Build with prompts | Pick module and variant before building |
| Build Variants | iOS build | Requires iOS workspace |
| Build Variants | iOS deploy | Requires iOS workspace and available simulator/device |
| Build Variants | Gradle tasks | Browse and run composite-aware Gradle tasks |
| Build Variants | Select module | Set default Gradle module and sync matching Android run config when active |
| Build Variants | Select variant | Set default build variant |
| Build Variants | Output APKs | List APKs and copy path |
| Build Variants | Gradle clean | Run `clean` in workspace |
| Device Manager | Select device | Pick default adb device |
| Device Manager | Select emulator AVD | Pick default emulator profile |
| Device Manager | Start emulator | Launch default emulator |
| Device Manager | Create AVD | Create new emulator profile |
| Device Manager | Stop emulator | Stop running emulator |
| ADB | ADB install | Install APK to selected device |
| ADB | Clear app data | Clear app data on selected device |
| ADB | Uninstall app | Remove app from selected device |
| Logcat | Logcat | Open logcat panel |
| Logcat | Health check | Run `:checkhealth android` |
| Logcat | Show build errors | Open build quickfix list |

## Examples

1. Open the full hub: `:AndroidMenu`
1. Run the selected config directly: `:AndroidRun`
1. Build without deploy: `:AndroidBuildAssemble`
1. Select a different Android module from `Build Variants` to keep Android build
   defaults and the active Android run config aligned.
1. Add a custom key for a direct command:

```lua
vim.keymap.set("n", "<leader>ar", "<Plug>(AndroidRun)", { remap = true, silent = true })
```

## Related Docs

- Navigation workflow: [../guides/navigation.md](../guides/navigation.md)
- Keymaps reference: [keymaps.md](keymaps.md)
