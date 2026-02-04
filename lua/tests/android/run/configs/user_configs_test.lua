local M = {}

local assert = require("tests.helpers.assert")

local function uses_relative_config_path_from_config()
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

function M.run()
  uses_relative_config_path_from_config()
  uses_absolute_config_path_from_config()
  opts_config_path_overrides_config()
end

return M
