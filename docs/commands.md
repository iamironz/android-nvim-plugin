# Commands

| Command | Description | Default shortcut |
| --- | --- | --- |
| `:AndroidMenu` | Open the main menu. | `<leader>am` |
| `:AndroidTargets` | Open the build menu. | `<leader>at` |
| `:AndroidTools` | Open the tools menu. | `<leader>ao` |
| `:AndroidActions` | Open the actions hub. | `<leader>aa` |
| `:AndroidBuild` | Build, deploy, and open logcat using saved defaults. | `<leader>ab` |

## Hub navigation

- Menus open a hub list of sections, and AndroidMenu shows a summary panel at the top.
- Typing in the hub opens the search overlay with your text, and search is available only after typing.
- AndroidTargets, AndroidTools, and AndroidActions use the hub list with type-to-search.
- Press Esc to return to the hub from the actions picker, and `q` closes it.
- When a submenu opens from the hub shortcuts, Esc returns to the previous hub.

## Build behavior

- `:AndroidBuild` runs a Gradle build for the saved module and variant, deploys to a
  device or emulator, updates the logcat package, and opens logcat on success.
- Use the Build assemble only menu item to skip deploy.

## Diagnostics

- `:checkhealth android` validates SDK tools, Gradle command resolution, and iOS
  tooling on macOS.

## Keymap notes

- Default shortcuts are enabled by default. Set `keymaps.enabled = false` to disable.
- Override individual entries in `keymaps.mappings` (set to false or "" to disable).

## Plug mappings

- `<Plug>(AndroidMenu)`
- `<Plug>(AndroidTargets)`
- `<Plug>(AndroidTools)`
- `<Plug>(AndroidActions)`
- `<Plug>(AndroidBuild)`

## AndroidMenu items

AndroidMenu shows a summary panel at the top of the hub list.
Items appear only when the workspace supports the required targets.

| Section | Item | Notes |
| --- | --- | --- |
| Shortcuts | Open build menu | Opens `:AndroidTargets` (build items). |
| Shortcuts | Open tools menu | Opens `:AndroidTools` (devices and apps). |
| Run | Run current | Runs the selected run config. |
| Run | Stop run | Stops active run jobs. |
| Build | Build default | Build and deploy using saved module and variant. |
| Build | Build assemble only | Build without deploy. |
| Build | Build with prompts | Pick module and variant before building. |
| Build | iOS build | Requires iOS workspace. |
| Build | iOS deploy | Requires iOS workspace and simulator. |
| Build | Gradle tasks | Browse and run Gradle tasks. |
| Build | Select module | Set the default Gradle module. |
| Build | Select variant | Set the default build variant. |
| Build | Output APKs | List APKs and copy paths. |
| Build | Gradle clean | Run `clean` in the workspace. |
| Devices | Select device | Pick the default adb device. |
| Devices | Select emulator AVD | Pick the default emulator profile. |
| Devices | Start emulator | Launch the default emulator. |
| Devices | Create AVD | Create a new emulator profile. |
| Devices | Stop emulator | Stop a running emulator. |
| Apps | ADB install | Install APK to a device. |
| Apps | Clear app data | Clear app data on a device. |
| Apps | Uninstall app | Remove the app from a device. |
| Logs | Logcat | Open logcat panel. |
| Logs | Health check | Run `:checkhealth android`. |
| Logs | Show build errors | Open the build quickfix list. |

## Logcat controls

| Key | Action |
| --- | --- |
| `q` | Close logcat panel. |
| `c` | Clear the panel output. |
| `C` | Clear output and reset pause state. |
| `p` | Pause or resume output. |
| `r` | Restart logcat. |
| `gp` | Pick the package filter. |
| `gf` | Edit the filter text. |
| `gl` | Pick the logcat level. |
| `gs` | Switch run config. |
| `<CR>` | On header lines, edit package, filter, or level. Else jump to stack trace. |

Filter text supports space separated terms and `/regex/` patterns.
