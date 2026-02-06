# android-nvim-plugin

[![Tests](https://github.com/iamironz/android-nvim-plugin/actions/workflows/tests.yml/badge.svg)](https://github.com/iamironz/android-nvim-plugin/actions/workflows/tests.yml)
[![License: MIT](https://img.shields.io/badge/license-MIT-2ea043.svg)](LICENSE)
[![Neovim](https://img.shields.io/badge/neovim-0.9%2B-57A143?logo=neovim&logoColor=white)](https://neovim.io)

Neovim plugin for Android and mobile development workflows: build, run, logcat,
device management, and Gradle tasks.

I built this after one too many Android Studio updates traded stability for a
fresh pile of features I did not ask for. Open a few projects and the laptop
turns into a space heater while memory keeps climbing. Every release ships more
panels and more prompts while the basics keep wobbling. Big tech loves the
feature treadmill, even when it makes the IDE heavier than the app.

Now that AI coding is everywhere, a full featured IDE feels like a spaceship
for a grocery run, so I wanted something smaller and mine. This plugin keeps
the essentials close and the workflow honest inside Neovim. It is also buggy
and probably leaks memory in its own charming way. Think of it as a lighter
bag of problems with a better keyboard.

![Android Neovim workflow demo](docs/images/android-nvim-plugin-demo.png)

## Compatibility

| Area | Support | Notes |
| --- | --- | --- |
| Neovim | 0.9+ | Lua support required |
| Android | Android SDK tools and `adb` | Required for Android actions |
| iOS | Xcode tools | Required for iOS actions |
| KMP | Kotlin Multiplatform plugin | Enables KMP target detection |
| UI picker | Telescope or `vim.ui` | Telescope is optional |

## Quick Start

1. Add this `lazy.nvim` plugin spec:

```lua
{
  "iamironz/android-nvim-plugin",
  lazy = false,
  config = function()
    require("android").setup()
  end,
}
```

1. Run `:Lazy sync`.
1. Open a project and run `:AndroidMenu`.
1. Use `[1]`, `[2]`, and `<CR>` to enter sections. Use `/` to search.

If you use another plugin manager, see [docs/install.md](docs/install.md).

Full first-run walkthrough: [docs/getting-started.md](docs/getting-started.md)

## Features

### Commands and Keymaps

- **Five commands:** `:AndroidMenu`, `:AndroidTargets`, `:AndroidTools`,
  `:AndroidActions`, `:AndroidBuild`.
- **Default keymaps** (`<leader>am/at/ao/aa/ab`) with `<Plug>` mappings.
  Configurable or can be disabled.
  See [docs/reference/keymaps.md](docs/reference/keymaps.md).

### Navigation and UX

- **Hub menus with summary panel.** Section shortcuts (`[1]`...`[9]`),
  search (`/` or any letter), back navigation. Menu adapts to project type:
  Android, iOS, KMP, and JVM items show or hide automatically.
  See [docs/guides/navigation.md](docs/guides/navigation.md).
- **Picker flexibility.** Telescope with automatic `vim.ui` fallback.

### Build and Deploy

- **One-key build and deploy.** `:AndroidBuild` resolves module/variant from
  saved defaults, builds, installs, launches, and opens logcat.
- **Prompt-driven builds.** Interactive module/variant selection to override defaults.
- **Assemble-only mode.** Build without deploying.
- **Default variant detection.** Reads `isDefault` markers from `buildTypes` and
  `productFlavors` in build.gradle to auto-select the right variant.
- **APK discovery.** Resolves by variant, scans flavor subdirectories, supports
  path overrides and full-scan fallback (`build.scan_all_apk_outputs`).
- **Gradle task browser.** Browse and run any task via `:Telescope android tasks`.
- **Build output dock.** Bottom panel with header strip, real-time streaming,
  text filter with history, auto-scroll, read-only buffer.
- **Quickfix integration.** Kotlin and Java errors parsed into quickfix list on
  build failure.
  See [docs/guides/build-and-deploy.md](docs/guides/build-and-deploy.md).

### iOS Build and Deploy

- **xcodebuild integration.** Builds with auto-discovered schemes.
- **Simulator and physical device deploy.** Discovers booted simulator or paired
  device, installs and launches.

### Logcat

- **Dock panel.** Fixed control header (package/filter/level) and scrolling body.
  Closing either window closes both.
- **Package filtering.** Auto-detects from APK, manifest, or build.gradle.
  PID-based when the process is running.
- **Text and regex filtering.** Space-separated terms (AND logic), `/pattern/`
  for regex. Filter history with Telescope completion.
- **Log level filtering.** V, D, I, W, E applied as logcat arguments.
- **Pause/resume.** Buffers output while paused, flushes on resume.
- **Restart, clear, reset.** Single-key controls for each.
- **Stack trace navigation.** `<CR>` on `(File.kt:42)` jumps to source.
- **Auto-reconnect.** Exponential backoff, up to 5 retries.
- **Syntax highlighting.** Color-coded by log level.
- **Multi-session.** Independent state per run config.
- **Interactive header.** `<CR>` on header lines opens the relevant picker.
  See [docs/guides/logcat.md](docs/guides/logcat.md).

### Device Manager and ADB

- **Device selection.** Pick target device, auto-selects first connected.
- **AVD selection and creation.** Pick or create AVDs with device profile and
  system image selection.
- **Emulator start/stop.** Launch by AVD name with boot wait, or stop running.
- **ADB actions.** Install APK, clear app data, uninstall.
  See [docs/guides/devices-and-adb.md](docs/guides/devices-and-adb.md).

### Run Configurations

- **Multi-target.** Android, iOS, JVM, Gradle task, and shell configs
  auto-discovered from a single menu.
- **Run All.** Parallel execution across target types. Ordering and preferred
  modules configurable via `run.run_all`.
- **JSON shell configs.** Custom commands in `.android.nvim.json` with real-time
  output.
- **Stop running jobs** from the menu.
  See [docs/guides/run-configs.md](docs/guides/run-configs.md).

### Workspace and SDK

- **Project detection.** Gradle root, Android modules, KMP targets, iOS
  workspaces. Cached with settings-file invalidation.
- **SDK discovery.** Plugin config -> `local.properties` -> env vars
  (`ANDROID_SDK_ROOT`, `ANDROID_HOME`) -> OS defaults. Tools resolved from root.
- **Gradle caching.** Tasks, variants, modules cached with mtime invalidation.
  Background prefetch on menu open.
- **Persistent selections.** Module, variant, device, AVD, run config, logcat
  state saved per workspace across sessions.
- **Health checks.** `:checkhealth android` validates SDK, tools, Gradle, iOS.
  See [docs/reference/configuration.md](docs/reference/configuration.md) and
  [docs/support/troubleshooting.md](docs/support/troubleshooting.md).

### Editor Integration

- **Auto-save.** Saves on `InsertLeave`/`FocusLost` with debounce.
  Configurable via `ui.autosave`.
- **File watcher.** Detects external changes, prompts Reload / Keep / Diff /
  Force Save. Configurable via `ui.file_watcher`.
- **Read-only output buffers.** Logcat and build panels are non-editable.
- **Transparent roadmap.** Tracked in [docs/roadmap.md](docs/roadmap.md).

## Documentation

Docs home: [docs/README.md](docs/README.md)

| Goal | Doc |
| --- | --- |
| Install and first run | [docs/getting-started.md](docs/getting-started.md), [docs/install.md](docs/install.md) |
| Menu navigation and workflows | [docs/guides/navigation.md](docs/guides/navigation.md) |
| Build and deploy | [docs/guides/build-and-deploy.md](docs/guides/build-and-deploy.md) |
| Logcat usage | [docs/guides/logcat.md](docs/guides/logcat.md) |
| Devices and ADB | [docs/guides/devices-and-adb.md](docs/guides/devices-and-adb.md) |
| Run configuration model | [docs/guides/run-configs.md](docs/guides/run-configs.md) |
| Command/config/keymap reference | [docs/reference/commands.md](docs/reference/commands.md), [docs/reference/configuration.md](docs/reference/configuration.md), [docs/reference/keymaps.md](docs/reference/keymaps.md) |
| Troubleshooting | [docs/support/troubleshooting.md](docs/support/troubleshooting.md) |
| Maintainer workflows | [docs/maintainers/development.md](docs/maintainers/development.md), [docs/maintainers/release.md](docs/maintainers/release.md), [docs/maintainers/triage.md](docs/maintainers/triage.md) |
| Roadmap and change log | [docs/roadmap.md](docs/roadmap.md), [CHANGELOG.md](CHANGELOG.md) |

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md).

## License

MIT
