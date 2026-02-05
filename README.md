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
| Android | Android SDK tools and adb | Required for Android actions |
| iOS | Xcode tools | Required for iOS actions |
| KMP | Kotlin Multiplatform plugin | Enables KMP target detection |
| UI picker | Telescope or vim.ui | Telescope optional |

## Quick start

1. **Install with lazy.nvim.**

  ```lua
  {
    "iamironz/android-nvim-plugin",
    lazy = false,
    config = function()
      require("android").setup()
    end,
  }
  ```

2. **Other managers.** See [Install](#install) for packer.nvim, pckr.nvim,
   mini.deps, rocks.nvim, vim-plug, dein.vim, paq-nvim, and vim.pack.
   After installing, call `require("android").setup()`.

3. **Open the menu.** Run `:AndroidMenu` to open the main menu. Defaults should work
   when the Android SDK is discoverable via `ANDROID_SDK_ROOT`, `ANDROID_HOME`, or
   `local.properties`. See [docs/commands.md](docs/commands.md) for navigation and
   keymap details, [docs/configuration.md](docs/configuration.md) for overrides, and
   [docs/troubleshooting.md#sdk-not-found](docs/troubleshooting.md#sdk-not-found) if
   discovery fails.

## Features

- **Hub menus.** Summary panel, explicit section shortcuts (`[1]`, `[2]`, ...),
  visible controls, type-to-search/actions picker, Telescope support
  with vim.ui fallback, and Esc back navigation. See
  [docs/commands.md#hub-navigation](docs/commands.md#hub-navigation) and
  [docs/troubleshooting.md#telescope-missing](docs/troubleshooting.md#telescope-missing).
- **Build and deploy.** Saved module and variant, prompt builds, Gradle tasks, clean,
  and a build output panel with filter plus quickfix integration for Kotlin and Java.
  See [docs/commands.md#build-behavior](docs/commands.md#build-behavior).
- **Device Manager and ADB.** Pick adb device or AVD, start or stop emulator, create
  AVD from system images, install APKs, clear data, uninstall. See
  [docs/commands.md#androidmenu-items](docs/commands.md#androidmenu-items).
- **Logcat panel.** Package, filter, and level controls, regex and term filters,
  fixed bottom control strip, pause and resume, restart, reconnect backoff,
  stack trace navigation, highlights.
  See [docs/commands.md#logcat-controls](docs/commands.md#logcat-controls).
- **Run configs.** Android modules, iOS schemes, JVM run tasks, Gradle task entry,
  and JSON shell configs, plus Run All ordered by `run.run_all` settings. See
  [docs/run-configs.md](docs/run-configs.md) and
  [docs/run-configs.md#run-all](docs/run-configs.md#run-all).
- **Workspace detection.** Gradle, KMP, and iOS, SDK discovery from config, env,
  and local.properties, per workspace saved defaults, and health checks. See
  [docs/configuration.md](docs/configuration.md),
  [docs/commands.md#diagnostics](docs/commands.md#diagnostics), and
  [docs/troubleshooting.md#health-checks](docs/troubleshooting.md#health-checks).
- **Feature parity.** Table below covers logcat, stack traces, build quickfix,
  Gradle tasks, device app management, and planned LSP sync. See
  [Feature parity](#feature-parity-android-studio).

## Install

Use `iamironz/android-nvim-plugin` as the repo.

### lazy.nvim

```lua
{
  "iamironz/android-nvim-plugin",
  lazy = false,
  config = function()
    require("android").setup()
  end,
}
```

<details>
<summary>Other plugin managers</summary>

### packer.nvim

```lua
require("packer").startup(function(use)
  use({
    "iamironz/android-nvim-plugin",
    config = function()
      require("android").setup()
    end,
  })
end)
```

### pckr.nvim

```lua
require("pckr").add({
  {
    "iamironz/android-nvim-plugin",
    config = function()
      require("android").setup()
    end,
  },
})
```

### mini.deps

```lua
local add = MiniDeps.add

add({ source = "iamironz/android-nvim-plugin" })
require("android").setup()
```

### rocks.nvim

Use rocks.nvim with rocks-git.nvim for Git repositories. Add the repo to
`rocks.toml`, then load the plugin and call setup.

### vim-plug

```vim
call plug#begin(stdpath('data') . '/plugged')
Plug 'iamironz/android-nvim-plugin'
call plug#end()
lua require("android").setup()
```

### dein.vim

```vim
call dein#begin(stdpath('data') . '/dein')
call dein#add('iamironz/android-nvim-plugin')
call dein#end()
lua require("android").setup()
```

### paq-nvim

```lua
require("paq")({
  { "iamironz/android-nvim-plugin" },
})
require("android").setup()
```

### vim.pack

```bash
git clone https://github.com/iamironz/android-nvim-plugin \
  ~/.local/share/nvim/site/pack/android/start/android-nvim-plugin
```

```lua
require("android").setup()
```

</details>

## Configuration

```lua
require("android").setup({
  sdk = {
    root = nil,
    root_env_keys = { "ANDROID_SDK_ROOT", "ANDROID_HOME" },
    local_properties = true,
    local_properties_paths = { "local.properties" },
    root_candidates = nil,
  },
  run = {
    config_path = ".android.nvim.json",
    default_module = nil,
    module_preference = { ":androidApp", ":app" },
    run_all = {
      order = { "jvm", "android", "ios" },
      target_modules = {
        jvm = { ":server" },
        android = { ":androidApp", ":app" },
      },
    },
  },
  build = {
    gradle_command = nil,
    scan_all_apk_outputs = false,
  },
  ui = {
    file_watcher = true,
    autosave = true,
  },
  keymaps = {
    enabled = true,
    mappings = {
      menu = "<leader>am",
      targets = "<leader>at",
      tools = "<leader>ao",
      actions = "<leader>aa",
      build = "<leader>ab",
    },
  },
})
```

See [docs/configuration.md](docs/configuration.md) for the full reference.

<details>
<summary>Advanced configuration notes</summary>

- `run.config_path` can be absolute or relative to the workspace root.
- `run.default_module` forces a module selection.
- `run.module_preference` tunes default module selection.
- `run.run_all` controls target ordering and preferred modules.
- `build.gradle_command` can be a string or list.
- `build.scan_all_apk_outputs` enables a full APK scan fallback.

</details>

## Run configs

Run configs are loaded from `run.config_path` in JSON. If the file is missing,
only built-in configs are used. See [docs/configuration.md#run](docs/configuration.md#run)
for overrides.

Built-in providers are detected in this order:

- Android: one entry per Android module using the saved variant.
- iOS: one entry per Xcode scheme in the workspace.
- JVM: a server or JVM run entry when detected.
- Gradle task: task-based entries for quick execution.
- Shell: entries defined in the JSON file.

When at least one target config exists, a `Run All` entry is appended and runs
targets in the order configured by `run.run_all`.

Gradle task configs are hidden from the main run config list and surfaced via
the Gradle tasks menu.

See [docs/run-configs.md](docs/run-configs.md) for schema and examples.

## Commands

- `:AndroidMenu`
- `:AndroidTargets`
- `:AndroidTools`
- `:AndroidActions`
- `:AndroidBuild`

AndroidMenu shows the summary panel and section list.
AndroidBuild builds with the saved module and variant, deploys, updates logcat
package, and opens logcat on success.

AndroidTargets, AndroidTools, and AndroidActions use the hub list with type-to-search.

See [docs/commands.md](docs/commands.md) for details.

## Feature parity (Android Studio)

| Capability | Android Studio | Plugin | Planned |
| --- | --- | --- | --- |
| Logcat filters (pkg/level/text/regex) | Yes | Yes | - |
| Logcat controls (pause/clear/restart) | Yes | Yes | - |
| Logcat auto reconnect + wait for process | Yes | Yes | - |
| Logcat highlight by level | Yes | Yes | - |
| Logcat filter history + saved settings | Yes | Yes | - |
| Logcat package picker from running procs | Yes | Yes | - |
| Package auto-detect for deploy/logcat | Yes | Yes | - |
| Stack trace navigation from logcat | Yes | Yes | - |
| Build output panel + filter + quickfix | Yes | Yes | - |
| Build variants + module selection | Yes | Yes | - |
| Build + deploy (install/launch) | Yes | Yes | - |
| ADB wait for device + boot completion | Yes | Yes | - |
| Assemble-only build | Yes | Yes | - |
| APK list + copy path | Yes | Yes | - |
| Gradle tasks browser + run | Yes | Yes | - |
| Gradle clean | Yes | Yes | - |
| Emulator + AVD management | Yes | Yes | - |
| Advanced emulator controls (snapshots, GPS) | Yes | Yes | - |
| Device select + app management | Yes | Yes | - |
| ADB device discovery (serial/state/model) | Yes | Yes | - |
| Run configs (Android/JVM/Gradle) | Yes | Yes | - |
| Run config selection + persistence | Yes | Yes | - |
| Run control (run current/stop) | Yes | Yes | - |
| Run all multi-target | Yes | Yes | - |
| iOS build + deploy (xcodebuild) | No | Yes | - |
| Workspace defaults (module/variant/device/logcat) | Yes | Yes | - |
| Autosave + external change prompts | Yes | Yes | - |
| Health check (SDK/Gradle tooling) | Yes | Yes | - |
| Project model sync for LSP | Yes | No | Planned |
| Debugger (DAP attach, breakpoints) | Yes | No | Planned |
| Test runner (unit/instrumented) | Yes | No | Planned |
| Test results + coverage | Yes | No | Planned |
| Gradle sync + project model import | Yes | Partial | Planned |
| Build analyzer + task graph | Yes | No | Planned |
| Android Lint integration | Yes | No | Planned |
| Dependency search + insert (Maven) | Yes | No | Planned |
| Resource + manifest helpers | Yes | No | Planned |
| Manifest merge viewer | Yes | No | Planned |
| APK analyzer | Yes | No | Planned |
| SDK manager | Yes | No | Planned |
| Device file explorer + push/pull | Yes | No | Planned |
| ADB shell utilities (screenshot/record) | Yes | No | Planned |
| Layout/Compose preview | Yes | No | Planned |
| App inspectors (DB/network/layout) | Yes | No | Planned |
| ProGuard/R8 mapping tools | Yes | No | Planned |

Planned items are based on the 2026-02-01 feature gaps design notes.

## Docs

- [docs/configuration.md](docs/configuration.md)
- [docs/run-configs.md](docs/run-configs.md)
- [docs/commands.md](docs/commands.md)
- [docs/troubleshooting.md](docs/troubleshooting.md)
- [docs/development.md](docs/development.md)
- [docs/release.md](docs/release.md)
- [docs/triage.md](docs/triage.md)
- [CHANGELOG.md](CHANGELOG.md)

<details>
<summary>Troubleshooting</summary>

See [docs/troubleshooting.md](docs/troubleshooting.md) for common issues and fixes.

</details>

<details>
<summary>Tests</summary>

```bash
./scripts/run-tests.sh
./scripts/run-tests.sh tests.android.build.apk_test
```

</details>

## Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md).

## License

MIT

<details>
<summary>Release checklist</summary>

- Update [CHANGELOG.md](CHANGELOG.md)
- Run `./scripts/run-tests.sh`
- Verify CI is green
- Verify README and docs match current behavior
- Tag and publish the release
- Follow [docs/release.md](docs/release.md) for the full checklist

</details>

<details>
<summary>Doc validation checklist</summary>

- Verify README links resolve
- Confirm setup and config snippets match current API
- Check docs pages for stale option names
- Ensure run config examples match [docs/run-configs.md](docs/run-configs.md)
- Run `./scripts/run-tests.sh` for a quick sanity check

</details>
