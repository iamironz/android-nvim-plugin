# Configuration

This plugin exposes a single `require("android").setup` entry point. All
options are optional; defaults are shown below.

## Example

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

- `root` (string or nil) Optional SDK root override.
- `root_env_keys` (list) Env var precedence order for SDK root.
- `local_properties` (boolean) Use `local.properties` when true.
- `local_properties_paths` (list) Relative or absolute paths to local.properties.
- `root_candidates` (list) Fallback SDK locations by OS if env vars missing.

### run

- `config_path` (string) Run config JSON path. Absolute or workspace-relative.
- `default_module` (string) Force default module selection.
- `module_preference` (list) Preferred modules when multiple are available.
- `run_all.order` (list) Target ordering for run-all.
- `run_all.target_modules` (table) Target module overrides per target.

### build

- `gradle_command` (string or list) Override gradle command or args.
- `scan_all_apk_outputs` (boolean) Fallback to recursive APK scan.

### ui

- `file_watcher` (boolean) Enable file watcher for project changes; default true,
  set to false to opt out.
- `autosave` (boolean) Auto-save files before running; default true, set to false
  to opt out.

### keymaps

- `enabled` (boolean) Enable default mappings when true.
- `mappings` (table) Override individual mappings; set a value to false or "" to disable.
