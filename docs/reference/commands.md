# Command Reference

## Scope

This page defines command and menu inventory. For step-by-step usage,
see [navigation guide](../guides/navigation.md),
[build and deploy guide](../guides/build-and-deploy.md),
and [logcat guide](../guides/logcat.md).

## User Commands

| Command | Description | Default Shortcut |
| --- | --- | --- |
| `:AndroidMenu` | Open main hub menu | `<leader>am` |
| `:AndroidTargets` | Open Build Variants hub | `<leader>at` |
| `:AndroidTools` | Open Device Manager and ADB hub | `<leader>ao` |
| `:AndroidActions` | Open actions hub | `<leader>aa` |
| `:AndroidBuild` | Build, deploy, and open logcat with saved defaults | `<leader>ab` |

## Plug Mappings

- `<Plug>(AndroidMenu)`
- `<Plug>(AndroidTargets)`
- `<Plug>(AndroidTools)`
- `<Plug>(AndroidActions)`
- `<Plug>(AndroidBuild)`

## Diagnostics

- `:checkhealth android` validates SDK tools, Gradle command resolution,
  and iOS tooling on macOS.

## AndroidMenu Items

Items appear only when workspace capabilities support them.

| Section | Item | Notes |
| --- | --- | --- |
| Run | Run current | Runs selected run config |
| Run | Stop run | Stops active run jobs |
| Build Variants | Build default | Build and deploy using saved module and variant |
| Build Variants | Build assemble only | Build without deploy |
| Build Variants | Build with prompts | Pick module and variant before building |
| Build Variants | iOS build | Requires iOS workspace |
| Build Variants | iOS deploy | Requires iOS workspace and simulator |
| Build Variants | Gradle tasks | Browse and run Gradle tasks |
| Build Variants | Select module | Set default Gradle module |
| Build Variants | Select variant | Set default build variant |
| Build Variants | Output APKs | List APKs and copy paths |
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

## Related Docs

- Navigation workflow: [../guides/navigation.md](../guides/navigation.md)
- Keymaps reference: [keymaps.md](keymaps.md)
