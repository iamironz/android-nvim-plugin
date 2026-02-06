# Navigation Guide

## Purpose

Explain the hub interaction model so users can move quickly without guessing controls.

## Mental Model

Menus are hub-based:

- `AndroidMenu` is the full hub with summary plus sections.
- `AndroidTargets`, `AndroidTools`, and `AndroidActions` are focused hub entries.
- Section rows are explicit and selectable (`[1] Run Configurations`, `[2] Run`,
  `[3] Build Variants`, and so on).

## Command Entry Points

Use hub commands when you want discoverability.
Use direct commands when you know the exact action.

| Entry Point | Default Shortcut | Use It For |
| --- | --- | --- |
| `:AndroidMenu` | `<leader>am` | Full hub workflow |
| `:AndroidTargets` | `<leader>at` | Build Variants hub |
| `:AndroidTools` | `<leader>ao` | Device Manager and ADB hub |
| `:AndroidActions` | `<leader>aa` | Actions hub |
| `:AndroidBuild` | `<leader>ab` | Default build and deploy |
| `:AndroidRun` | None | Run current config directly |
| `:AndroidRunStop` | None | Stop active run jobs |
| `:AndroidLogcat` | None | Open logcat directly |
| `:AndroidBuildPrompt` | None | Build with module/variant prompts |
| `:AndroidBuildAssemble` | None | Build artifacts without deploy |
| `:AndroidGradleTasks` | None | Open Gradle task picker |
| `:AndroidIOSBuild` | None | Build iOS project |
| `:AndroidIOSDeploy` | None | Deploy iOS project |

## Core Controls

| Key | Behavior |
| --- | --- |
| `<CR>` | Open selected section or item |
| `1..9` | Open matching section shortcut |
| `<Right>` | Open current selection |
| `<Left>` | Go back to previous hub |
| `/` | Open search input |
| `Esc` | Return to previous hub from submenu picker |
| `q` | Close picker or panel |

Type-to-search is supported directly in hub pickers.

## Section Guide

| Section | Use It For |
| --- | --- |
| Run Configurations | Select active run configuration for run actions |
| Run | Run current config or stop active jobs |
| Build Variants | Build/deploy flows, module/variant selection, Gradle tasks |
| Device Manager | Device/emulator selection and lifecycle actions |
| ADB | App install, clear data, uninstall |
| Logcat | Logcat panel, health check, build-error quickfix |

Complete item list:
[reference/commands.md#androidmenu-items](../reference/commands.md#androidmenu-items)

## Recommended Flow

1. Start at `:AndroidMenu`.
1. Select section by number for speed.
1. Use `/` only when list scope is large.
1. Use `<Left>` to back out one level instead of closing and reopening.
1. Use direct commands to skip hub navigation for repeat actions.

## Related Docs

- Build and deploy: [build-and-deploy.md](build-and-deploy.md)
- Logcat: [logcat.md](logcat.md)
- Command reference: [../reference/commands.md](../reference/commands.md)
