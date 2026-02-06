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

- **Five commands** cover the full workflow: `:AndroidMenu`, `:AndroidTargets`,
  `:AndroidTools`, `:AndroidActions`, and `:AndroidBuild`.
- **Default keymaps** (`<leader>am`, `<leader>at`, `<leader>ao`, `<leader>aa`,
  `<leader>ab`) with `<Plug>` mappings for custom bindings.
  Keymaps are fully configurable or can be disabled entirely.
  See [docs/reference/keymaps.md](docs/reference/keymaps.md).

### Navigation and UX

- **Hub menus with summary panel.** Section shortcuts (`[1]`, `[2]`, ...),
  search-first flow (`/` or any letter), and back navigation.
  The menu adapts to the project type: Android-only, iOS, KMP, and JVM items
  appear or hide based on detected workspace capabilities.
  See [docs/guides/navigation.md](docs/guides/navigation.md).
- **Picker flexibility.** Telescope integration with automatic `vim.ui` fallback
  when Telescope is unavailable.
  See [docs/support/troubleshooting.md#telescope-missing](docs/support/troubleshooting.md#telescope-missing).

### Build and Deploy

- **One-key build and deploy.** `:AndroidBuild` resolves module and variant from
  saved defaults, builds, installs the APK, launches the app, and opens logcat.
- **Prompt-driven builds.** Interactive module and variant selection when you need
  to override defaults.
- **Assemble-only mode.** Build without deploying.
- **Default variant detection.** Reads `isDefault true` / `isDefault = true` /
  `isDefault.set(true)` markers from `buildTypes` and `productFlavors` in
  build.gradle to auto-select the right variant in multi-flavor projects.
- **APK discovery.** Finds APKs by variant, scans flavor subdirectories for
  multi-flavor builds, supports explicit path overrides, and optional full-scan
  fallback via `build.scan_all_apk_outputs`.
- **Gradle task browser.** Browse and run any Gradle task via Telescope
  (`:Telescope android tasks`).
- **Build output dock.** Two-layer bottom panel with fixed header strip.
  Real-time streaming, text filter with history, and auto-scroll.
  Read-only buffer prevents accidental edits.
- **Quickfix integration.** Kotlin (`e: file:(line, col)`) and Java
  (`file:line: error:`) errors are parsed from build output and loaded into
  the quickfix list automatically on failure.
  See [docs/guides/build-and-deploy.md](docs/guides/build-and-deploy.md).

### iOS Build and Deploy

- **xcodebuild integration.** Builds using workspace or project with auto-discovered
  schemes. Preferred scheme matches the workspace base name, then `ios`, then first
  available.
- **Simulator deploy.** Discovers booted simulator, installs and launches the app.
- **Physical device deploy.** Discovers paired devices via `xcrun devicectl`, installs
  and launches.

### Logcat

- **Dock panel.** Split layout with a fixed control header (package, filter, level)
  and a scrolling body. Closing either window closes both.
- **Package filtering.** Filter by app package name. Auto-detects package from APK,
  manifest, or build.gradle. PID-based filtering when the process is running.
- **Text and regex filtering.** Space-separated terms with AND logic. Wrap a term
  in `/pattern/` for Lua regex matching. Filter history (up to 20 entries) with
  Telescope completion.
- **Log level filtering.** V, D, I, W, E levels applied as logcat filter arguments.
- **Pause and resume.** Pauses display output with backlog buffering. Resume flushes
  the backlog.
- **Restart, clear, and reset.** Restart the logcat process, clear visible output,
  or reset (unpause + clear) with single keybinds.
- **Stack trace navigation.** Press `<CR>` on a `(File.kt:42)` line to jump to
  the source file at that line in your editor.
- **Auto-reconnect.** Exponential backoff (1s base, 8s max, up to 5 retries)
  reconnects automatically when the logcat process dies.
- **Syntax highlighting.** Color-coded output by log level.
- **Multi-session support.** One logcat session per run config with independent
  package, filter, level, and history state.
- **Interactive header.** Press `<CR>` on header lines to edit package (line 1),
  filter (line 2), or level (line 3) inline.
  See [docs/guides/logcat.md](docs/guides/logcat.md).

### Device Manager

- **Device selection.** Pick the target ADB device. Auto-selects the first connected
  device when none is saved.
- **AVD selection and creation.** Pick an existing AVD or create a new one with
  interactive device profile and system image selection.
- **Emulator start and stop.** Launch an emulator by AVD name, wait for boot
  completion, or stop a running emulator.
  See [docs/guides/devices-and-adb.md](docs/guides/devices-and-adb.md).

### ADB Actions

- **Install APK.** Install a discovered or overridden APK on the selected device.
- **Clear app data.** Clear the app's data on the device.
- **Uninstall app.** Remove the app from the device.
  See [docs/guides/devices-and-adb.md](docs/guides/devices-and-adb.md).

### Run Configurations

- **Multi-target support.** Android, iOS, JVM, Gradle task, and user-defined
  shell configs are auto-discovered and selectable from a single menu.
- **Run All orchestration.** When multiple target types exist, a virtual
  `Run All` config runs them in parallel. Target ordering and preferred modules
  are configurable via `run.run_all`.
- **JSON shell configs.** Define custom commands in `.android.nvim.json` with
  `id`, `label`, `command`, and `args`. Runs in the build output panel with
  real-time streaming.
- **Stop running jobs.** Stop all active run processes from the menu.
  See [docs/guides/run-configs.md](docs/guides/run-configs.md).

### Workspace and SDK

- **Project detection.** Auto-detects Gradle root, Android modules, KMP targets,
  and iOS workspaces/projects. Workspace is cached and invalidated on settings
  file changes.
- **SDK root discovery.** Resolution chain: plugin config, `local.properties`,
  environment variables (`ANDROID_SDK_ROOT`, `ANDROID_HOME`), OS-specific
  default paths. Tool paths (adb, aapt2, emulator, avdmanager, sdkmanager) are
  resolved from the SDK root.
- **Gradle caching.** Task lists, variants, and module lists are cached with
  file-stamp-based invalidation. Background prefetch runs Gradle task discovery
  when the menu opens so subsequent actions are instant.
- **Persistent selections.** Module, variant, device, AVD, run config, logcat
  package, filter, level, and filter history are saved per workspace and restored
  across Neovim sessions.
- **Health checks.** `:checkhealth android` validates SDK root, Android tools,
  Gradle setup, and iOS tools.
  See [docs/reference/configuration.md](docs/reference/configuration.md) and
  [docs/support/troubleshooting.md](docs/support/troubleshooting.md).

### Editor Integration

- **Auto-save.** Modified buffers are saved on `InsertLeave` and `FocusLost`
  with 200ms debounce. Configurable via `ui.autosave`.
- **File watcher.** Detects external file changes on `FocusGained` and
  `BufEnter`, prompts with Reload / Keep / Diff / Force Save options.
  Configurable via `ui.file_watcher`.
- **Read-only output buffers.** Logcat and build output buffers are non-editable
  to prevent accidental modifications. Plugin writes still work through the
  internal API.
- **Transparent roadmap.** Current support and planned gaps are tracked in
  [docs/roadmap.md](docs/roadmap.md).

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
