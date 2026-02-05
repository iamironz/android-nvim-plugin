# Navigation Guide

## Purpose

Explain the hub interaction model so users can move quickly without guessing controls.

## Mental Model

Menus are hub-based:

- `AndroidMenu` is the full hub with summary plus sections.
- `AndroidTargets`, `AndroidTools`, and `AndroidActions` are focused hub entries.
- Section rows are explicit and selectable (`[1] Run`, `[2] Build Variants`, and so on).

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
| Run | Run current config or stop active jobs |
| Build Variants | Build/deploy flows, module/variant selection, Gradle tasks |
| Device Manager | Device/emulator selection and lifecycle actions |
| ADB | App install, clear data, uninstall |
| Logcat | Logcat panel, health check, build-error quickfix |

Complete item list:
[reference/commands.md#androidmenu-items](../reference/commands.md#androidmenu-items)

## Practical Workflow

1. Start at `:AndroidMenu`.
1. Select section by number for speed.
1. Use `/` only when list scope is large.
1. Use `<Left>` to back out one level instead of closing and reopening.

## Related Docs

- Build and deploy: [build-and-deploy.md](build-and-deploy.md)
- Logcat: [logcat.md](logcat.md)
- Command reference: [../reference/commands.md](../reference/commands.md)
