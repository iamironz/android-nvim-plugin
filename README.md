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

### Navigation and UX

- **Hub menus that explain themselves.** Summary panel, explicit section shortcuts
  (`[1]`, `[2]`, ...), visible controls, search-first flow, and back navigation.
  See [docs/guides/navigation.md](docs/guides/navigation.md).
- **Picker flexibility.** Telescope support with automatic `vim.ui` fallback when
  Telescope is unavailable.
  See [docs/support/troubleshooting.md#telescope-missing](docs/support/troubleshooting.md#telescope-missing).

### Build, Deploy, and Logs

- **Build and deploy workflows.** Saved module/variant defaults, prompt-driven builds,
  assemble-only mode, and Gradle task execution.
  See [docs/guides/build-and-deploy.md](docs/guides/build-and-deploy.md).
- **Build output that is actually usable.** Two-layer bottom dock with fixed filter
  strip and quickfix integration for Kotlin/Java errors.
  See [docs/guides/build-and-deploy.md](docs/guides/build-and-deploy.md).
- **Logcat that stays in flow.** Package/filter/level controls, term and regex
  filtering, pause/resume/restart, reconnect behavior, and stack trace jumps.
  See [docs/guides/logcat.md](docs/guides/logcat.md).

### Devices, Targets, and Workspace Context

- **Device Manager and ADB actions.** Select device/AVD, start/stop emulator, install APK,
  clear app data, and uninstall apps.
  See [docs/guides/devices-and-adb.md](docs/guides/devices-and-adb.md).
- **Run configs across targets.** Android, iOS, JVM, Gradle task, and JSON shell configs,
  plus `Run All` orchestration via `run.run_all`.
  See [docs/guides/run-configs.md](docs/guides/run-configs.md).
- **Workspace-aware defaults and health checks.** Gradle/KMP/iOS detection, SDK discovery,
  persistent selections, and `:checkhealth android`.
  See [docs/reference/configuration.md](docs/reference/configuration.md) and
  [docs/support/troubleshooting.md](docs/support/troubleshooting.md).
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
