local M = {}

local assert = require("tests.helpers.assert")

local function setup_overrides_sdk_root()
  package.loaded["android.config"] = nil
  local config = require("android.config")

  config.setup({
    sdk = {
      root = "/custom-sdk",
    },
  })

  assert.eq(config.get().sdk.root, "/custom-sdk", "sdk root override")
end

local function setup_keeps_default_env_keys()
  package.loaded["android.config"] = nil
  local config = require("android.config")

  config.setup({
    sdk = {
      root = "/custom-sdk",
    },
  })

  assert.table_eq(
    config.get().sdk.root_env_keys,
    { "ANDROID_SDK_ROOT", "ANDROID_HOME" },
    "env keys default"
  )
end

local function setup_defaults_file_watcher_enabled()
  package.loaded["android.config"] = nil
  local config = require("android.config")

  config.setup({})

  assert.eq(config.get().ui.file_watcher, true, "file watcher default")
end

local function setup_defaults_autosave_enabled()
  package.loaded["android.config"] = nil
  local config = require("android.config")

  config.setup({})

  assert.eq(config.get().ui.autosave, true, "autosave default")
end

function M.run()
  setup_overrides_sdk_root()
  setup_keeps_default_env_keys()
  setup_defaults_file_watcher_enabled()
  setup_defaults_autosave_enabled()
end

return M
