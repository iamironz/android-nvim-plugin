local M = {}

local assert = require("tests.helpers.assert")
local stubs_helper = require("tests.helpers.stubs")

local function run_action(action, module_name, fn_name, label)
  local called = false

  local stubs = {
    [module_name] = {
      [fn_name] = function()
        called = true
      end,
    },
  }

  stubs_helper.with_stubs(stubs, function()
    package.loaded["android.actions.registry"] = nil
    local registry = require("android.actions.registry")
    registry.run(action)
  end)

  assert.is_true(called, label)
end

local function registry_cases()
  return {
    {
      action = "logcat",
      module_name = "android.actions.logcat",
      fn_name = "open",
      label = "logcat action",
    },
    {
      action = "show_build_errors",
      module_name = "android.actions.build",
      fn_name = "show_build_errors",
      label = "build errors action",
    },
    {
      action = "gradle_tasks",
      module_name = "android.actions.gradle_tasks",
      fn_name = "open",
      label = "gradle tasks action",
    },
    {
      action = "build_pure",
      module_name = "android.actions.build",
      fn_name = "build_pure",
      label = "build pure action",
    },
    {
      action = "gradle_clean",
      module_name = "android.actions.build",
      fn_name = "clean",
      label = "gradle clean action",
    },
    {
      action = "adb_install",
      module_name = "android.actions.apps",
      fn_name = "install",
      label = "adb install action",
    },
    {
      action = "clear_data",
      module_name = "android.actions.apps",
      fn_name = "clear_data",
      label = "clear data action",
    },
    {
      action = "uninstall",
      module_name = "android.actions.apps",
      fn_name = "uninstall",
      label = "uninstall action",
    },
    {
      action = "ios_build",
      module_name = "android.actions.ios.build",
      fn_name = "build",
      label = "ios build action",
    },
    {
      action = "ios_deploy",
      module_name = "android.actions.ios.build",
      fn_name = "deploy",
      label = "ios deploy action",
    },
    {
      action = "run_select",
      module_name = "android.run.ui",
      fn_name = "select",
      label = "run select action",
    },
    {
      action = "run_current",
      module_name = "android.run.executor",
      fn_name = "execute_default",
      label = "run current action",
    },
    {
      action = "run_stop",
      module_name = "android.run.executor",
      fn_name = "stop_active",
      label = "run stop action",
    },
  }
end

local function runs_health_check_action()
  local captured = nil
  local original_cmd = vim.cmd
  vim.cmd = function(cmd)
    captured = cmd
  end

  local ok, err = pcall(function()
    package.loaded["android.actions.registry"] = nil
    local registry = require("android.actions.registry")
    registry.run("health_check")
  end)

  vim.cmd = original_cmd
  if not ok then
    error(err)
  end

  assert.eq(captured, "checkhealth android", "health check command")
end

local function run_menu_action(action, fn_name, label)
  local called = false

  local stubs = {
    ["android.ui.menu"] = {
      [fn_name] = function()
        called = true
      end,
    },
  }

  stubs_helper.with_stubs(stubs, function()
    package.loaded["android.actions.registry"] = nil
    local registry = require("android.actions.registry")
    registry.run(action)
  end)

  assert.is_true(called, label)
end

local function run_menu_action_from_action(action, fn_name, label)
  local received = nil

  local stubs = {
    ["android.ui.menu"] = {
      [fn_name] = function(opts)
        received = opts
      end,
    },
  }

  stubs_helper.with_stubs(stubs, function()
    package.loaded["android.actions.registry"] = nil
    local registry = require("android.actions.registry")
    registry.run(action)
  end)

  assert.eq(received and received.from_action, true, label)
end

local function run_menu_action_passes_on_cancel(action, fn_name, label)
  local received = nil
  local on_cancel = function() end

  local stubs = {
    ["android.ui.menu"] = {
      [fn_name] = function(opts)
        received = opts
      end,
    },
  }

  stubs_helper.with_stubs(stubs, function()
    package.loaded["android.actions.registry"] = nil
    local registry = require("android.actions.registry")
    registry.run(action, { on_cancel = on_cancel })
  end)

  assert.eq(received and received.on_cancel, on_cancel, label)
end

function M.run()
  for _, case in ipairs(registry_cases()) do
    run_action(case.action, case.module_name, case.fn_name, case.label)
  end
  runs_health_check_action()
  run_menu_action("open_targets_menu", "show_targets_menu", "open targets menu")
  run_menu_action("open_tools_menu", "show_tools_menu", "open tools menu")
  run_menu_action_from_action(
    "open_targets_menu",
    "show_targets_menu",
    "open targets menu opts"
  )
  run_menu_action_from_action(
    "open_tools_menu",
    "show_tools_menu",
    "open tools menu opts"
  )
  run_menu_action_passes_on_cancel(
    "open_targets_menu",
    "show_targets_menu",
    "open targets menu on_cancel"
  )
  run_menu_action_passes_on_cancel(
    "open_tools_menu",
    "show_tools_menu",
    "open tools menu on_cancel"
  )
end

return M
