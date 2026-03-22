local M = {}

local assert = require("tests.helpers.assert")

local function reset_modules()
  package.loaded["android.project.config"] = nil
  package.loaded["android.run.user_configs"] = nil
  package.loaded["android.config"] = nil
end

local function uses_relative_config_path_from_config()
  reset_modules()
  local config = require("android.config")
  config.reset()
  config.setup({
    run = {
      config_path = "configs/android.json",
    },
  })

  local observed = { path = nil }
  local user_configs = require("android.run.user_configs")
  user_configs.load({ root = "/repo" }, {
    read = function(path)
      observed.path = path
      return "{}"
    end,
  })

  assert.eq(observed.path, "/repo/configs/android.json", "relative config path")
end

local function uses_absolute_config_path_from_config()
  reset_modules()
  local config = require("android.config")
  config.reset()
  config.setup({
    run = {
      config_path = "/tmp/android.json",
    },
  })

  local observed = { path = nil }
  local user_configs = require("android.run.user_configs")
  user_configs.load({ root = "/repo" }, {
    read = function(path)
      observed.path = path
      return "{}"
    end,
  })

  assert.eq(observed.path, "/tmp/android.json", "absolute config path")
end

local function opts_config_path_overrides_config()
  reset_modules()
  local config = require("android.config")
  config.reset()
  config.setup({
    run = {
      config_path = "configs/android.json",
    },
  })

  local observed = { path = nil }
  local user_configs = require("android.run.user_configs")
  user_configs.load({ root = "/repo" }, {
    config_path = "/override.json",
    read = function(path)
      observed.path = path
      return "{}"
    end,
  })

  assert.eq(observed.path, "/override.json", "opts config path")
end

local function shell_configs_stay_compatible_with_shared_loader()
  reset_modules()
  local user_configs = require("android.run.user_configs")
  local configs = user_configs.shell_configs({ root = "/repo" }, {
    read = function()
      return [[{"run":{"shell":[{"id":"serve","args":["./gradlew","installDebug"]}]}}]]
    end,
  })

  assert.eq(configs[1].id, "serve", "shell config id")
  assert.eq(configs[1].args[1], "./gradlew", "shell config args")
end

function M.run()
  uses_relative_config_path_from_config()
  uses_absolute_config_path_from_config()
  opts_config_path_overrides_config()
  shell_configs_stay_compatible_with_shared_loader()
end

return M
