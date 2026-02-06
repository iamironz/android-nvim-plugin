local M = {}

local defaults = {
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
    restore_logcat = true,
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
}

local config = vim.tbl_deep_extend("force", {}, defaults)

function M.setup(opts)
  config = vim.tbl_deep_extend("force", {}, defaults, opts or {})
  return config
end

function M.reset()
  config = vim.tbl_deep_extend("force", {}, defaults)
  return config
end

function M.get()
  return config
end

return M
