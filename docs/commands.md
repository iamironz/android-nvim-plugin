# Commands

| Command | Description | Default shortcut |
| --- | --- | --- |
| `:AndroidMenu` | Open the main menu. | `<leader>am` |
| `:AndroidTargets` | Open the Build Variants menu. | `<leader>at` |
| `:AndroidTools` | Open the Device Manager and ADB menu. | `<leader>ao` |
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
| Quick Access | Open Build Variants menu | Opens `:AndroidTargets` (build items). |
| Quick Access | Open Device Manager menu | Opens `:AndroidTools` (Device Manager and ADB). |
| Run | Run current | Runs the selected run config. |
| Run | Stop run | Stops active run jobs. |
| Build Variants | Build default | Build and deploy using saved module and variant. |
| Build Variants | Build assemble only | Build without deploy. |
| Build Variants | Build with prompts | Pick module and variant before building. |
| Build Variants | iOS build | Requires iOS workspace. |
| Build Variants | iOS deploy | Requires iOS workspace and simulator. |
| Build Variants | Gradle tasks | Browse and run Gradle tasks. |
| Build Variants | Select module | Set the default Gradle module. |
| Build Variants | Select variant | Set the default build variant. |
| Build Variants | Output APKs | List APKs and copy paths. |
| Build Variants | Gradle clean | Run `clean` in the workspace. |
| Device Manager | Select device | Pick the default adb device. |
| Device Manager | Select emulator AVD | Pick the default emulator profile. |
| Device Manager | Start emulator | Launch the default emulator. |
| Device Manager | Create AVD | Create a new emulator profile. |
| Device Manager | Stop emulator | Stop a running emulator. |
| ADB | ADB install | Install APK to a device. |
| ADB | Clear app data | Clear app data on a device. |
| ADB | Uninstall app | Remove the app from a device. |
| Logcat | Logcat | Open logcat panel. |
| Logcat | Health check | Run `:checkhealth android`. |
| Logcat | Show build errors | Open the build quickfix list. |

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
