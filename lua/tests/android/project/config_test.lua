local M = {}

local assert = require("tests.helpers.assert")

local function reset_modules()
  package.loaded["android.project.config"] = nil
  package.loaded["android.config"] = nil
end

local function capture_notifies(fn)
  local notifications = {}
  fn(function(message, level)
    notifications[#notifications + 1] = { message = message, level = level }
  end)
  return notifications
end

local function uses_relative_config_path_from_global_config()
  reset_modules()
  local config = require("android.config")
  config.setup({
    run = {
      config_path = "configs/android.json",
    },
  })

  local observed = { path = nil }
  local project_config = require("android.project.config")
  project_config.load({ root = "/repo" }, {
    read = function(path)
      observed.path = path
      return "{}"
    end,
  })

  assert.eq(observed.path, "/repo/configs/android.json", "relative config path")
end

local function uses_absolute_config_path_override()
  reset_modules()
  local config = require("android.config")
  config.setup({
    run = {
      config_path = "configs/android.json",
    },
  })

  local observed = { path = nil }
  local project_config = require("android.project.config")
  project_config.load({ root = "/repo" }, {
    config_path = "/override.json",
    read = function(path)
      observed.path = path
      return "{}"
    end,
  })

  assert.eq(observed.path, "/override.json", "absolute config path")
end

local function loads_shared_build_and_app_sections()
  reset_modules()
  local project_config = require("android.project.config")
  local data = project_config.load({ root = "/repo" }, {
    read = function()
      return [[{"build":{"apk_overrides":[{"module":":app","variant":"debug","path":"artifacts/app.apk"}]},"app":{"package":"com.example.app"}}]]
    end,
  })

  assert.eq(data.app.package, "com.example.app", "app package")
  assert.eq(data.build.apk_overrides[1].module, ":app", "override module")
  assert.eq(data.build.apk_overrides[1].variant, "debug", "override variant")
  assert.eq(data.build.apk_overrides[1].path, "artifacts/app.apk", "override path")
end

local function warns_once_for_malformed_shared_config_json()
  reset_modules()
  local project_config = require("android.project.config")
  local notifications = capture_notifies(function(notify)
    project_config.load({ root = "/repo" }, {
      notify = notify,
      read = function()
        return [[{"run":]]
      end,
    })
    project_config.load({ root = "/repo" }, {
      notify = notify,
      read = function()
        return [[{"run":]]
      end,
    })
  end)

  assert.eq(#notifications, 1, "warn once")
  assert.eq(notifications[1].level, vim.log.levels.WARN, "warn level")
  assert.contains(notifications[1].message, "/repo/.android.nvim.json", "warn path")
  assert.contains(notifications[1].message, "Check JSON syntax", "warn action")
end

local function warns_again_after_config_recovers_then_breaks()
  reset_modules()
  local project_config = require("android.project.config")
  local notifications = capture_notifies(function(notify)
    project_config.load({ root = "/repo" }, {
      notify = notify,
      read = function()
        return [[{"run":]]
      end,
    })
    project_config.load({ root = "/repo" }, {
      notify = notify,
      read = function()
        return [[{"run":{}}]]
      end,
    })
    project_config.load({ root = "/repo" }, {
      notify = notify,
      read = function()
        return [[{"run":]]
      end,
    })
  end)

  assert.eq(#notifications, 2, "warn after recovery")
end

function M.run()
  uses_relative_config_path_from_global_config()
  uses_absolute_config_path_override()
  loads_shared_build_and_app_sections()
  warns_once_for_malformed_shared_config_json()
  warns_again_after_config_recovers_then_breaks()
end

return M
