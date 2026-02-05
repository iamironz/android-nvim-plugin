# Configuration Reference

## Scope

This page documents `require("android").setup(opts)` options and defaults.

## Default Config Example

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

## Options

### sdk

- `root` (string or nil): SDK root override.
- `root_env_keys` (list): environment variable precedence for SDK discovery.
- `local_properties` (boolean): enable lookup in `local.properties`.
- `local_properties_paths` (list): lookup paths for local properties.
- `root_candidates` (list): fallback SDK paths when env vars are missing.

### run

- `config_path` (string): run config JSON path (absolute or workspace-relative).
- `default_module` (string): force default module selection.
- `module_preference` (list): preferred modules when multiple are available.
- `run_all.order` (list): run-all target execution order.
- `run_all.target_modules` (table): preferred modules per run-all target.

### build

- `gradle_command` (string or list): override gradle command or args.
- `scan_all_apk_outputs` (boolean): enable recursive APK scan fallback.

### ui

- `file_watcher` (boolean): enable workspace file watcher.
- `autosave` (boolean): auto-save files before actions.

### keymaps

- `enabled` (boolean): enable default command mappings.
- `mappings` (table): override mappings by key.
  Set value to `false` or `""` to disable mapping.

## Related Docs

- Keymaps: [keymaps.md](keymaps.md)
- Run config behavior: [../guides/run-configs.md](../guides/run-configs.md)
