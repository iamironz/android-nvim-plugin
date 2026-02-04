local M = {}

local assert = require("tests.helpers.assert")
local build_helpers = require("android.actions.build_helpers")
local config = require("android.config")

local function reset_config()
  config.reset()
end

local function with_fs_stat(value, fn)
  local saved = vim.loop.fs_stat
  vim.loop.fs_stat = function()
    return value
  end
  local ok, err = pcall(fn)
  vim.loop.fs_stat = saved
  if not ok then
    error(err)
  end
end

local function uses_configured_gradle_command_string()
  reset_config()
  config.setup({
    build = {
      gradle_command = "/opt/gradle/bin/gradle",
    },
  })
  with_fs_stat(nil, function()
    local cmd = build_helpers.resolve_gradle_command("/workspace")
    assert.table_eq(cmd, { "/opt/gradle/bin/gradle" }, "configured gradle command")
  end)
end

local function uses_configured_gradle_command_table()
  reset_config()
  config.setup({
    build = {
      gradle_command = { "gradle", "--quiet" },
    },
  })
  with_fs_stat(nil, function()
    local cmd = build_helpers.resolve_gradle_command("/workspace")
    assert.table_eq(cmd, { "gradle", "--quiet" }, "configured gradle command table")
  end)
end

local function uses_wrapper_when_present()
  reset_config()
  with_fs_stat({ type = "file" }, function()
    local cmd = build_helpers.resolve_gradle_command("/workspace")
    assert.table_eq(cmd, { "/workspace/gradlew" }, "wrapper command")
  end)
end

local function uses_windows_wrapper_when_present()
  reset_config()
  local original_uname = vim.loop.os_uname
  vim.loop.os_uname = function()
    return { sysname = "Windows_NT" }
  end

  with_fs_stat({ type = "file" }, function()
    local cmd = build_helpers.resolve_gradle_command("C:/workspace")
    assert.table_eq(cmd, { "C:/workspace/gradlew.bat" }, "wrapper windows")
  end)

  vim.loop.os_uname = original_uname
end

function M.run()
  uses_configured_gradle_command_string()
  uses_configured_gradle_command_table()
  uses_wrapper_when_present()
  uses_windows_wrapper_when_present()
end

return M
