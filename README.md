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

1. Install the plugin. See [docs/install.md](docs/install.md).
1. Configure setup in your Neovim config:

```lua
require("android").setup()
```

1. Open a project and run `:AndroidMenu`.
1. Use `[1]`, `[2]`, and `<CR>` to enter sections. Use `/` to search.

Full first-run walkthrough: [docs/getting-started.md](docs/getting-started.md)

## What You Can Do

- Navigate hub menus with explicit section shortcuts and summary context.
- Build and deploy with saved defaults or prompt-driven selections.
- Inspect logcat in a docked panel with fixed controls and stack trace jumps.
- Manage devices, emulators, and app install/clear/uninstall actions.
- Run Android/iOS/JVM/Gradle/shell run configs, including `Run All` orchestration.

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
