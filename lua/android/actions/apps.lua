local M = {}

local runner_module = require("android.command.runner")
local adb = require("android.devices.adb")
local discovery = require("android.sdk.discovery")
local action_defaults = require("android.actions.defaults")
local state_defaults = require("android.state.selection_defaults")
local build_helpers = require("android.actions.build_helpers")
local apk = require("android.build.apk")
local deploy = require("android.build.deploy")
local package_resolver = require("android.logcat.package")
local context = require("android.actions.context")

local function shallow_copy(source)
  local out = {}
  for key, value in pairs(source or {}) do
    if type(value) == "table" then
      local nested = {}
      for nested_key, nested_value in pairs(value) do
        nested[nested_key] = nested_value
      end
      out[key] = nested
    else
      out[key] = value
    end
  end
  return out
end

local function notify_missing_modules()
  vim.notify("No Gradle modules found", vim.log.levels.WARN)
end

local function notify_missing_variants()
  vim.notify("No Gradle variants found", vim.log.levels.WARN)
end

local function resolve_tools(root)
  local sdk = discovery.new({ root = root })
  return sdk, sdk.tools()
end

local function ensure_adb(tools)
  if not tools or not tools.adb then
    vim.notify("adb not found in Android SDK", vim.log.levels.WARN)
    return nil
  end
  return tools.adb
end

local function resolve_device_serial(runner, adb_path, state)
  local devices = adb.list(runner, adb_path)
  local saved_serial = state_defaults.device_defaults(state).serial
  local serial = action_defaults.select_device_serial(devices, saved_serial)
  if not serial then
    vim.notify("No adb devices found", vim.log.levels.WARN)
    return nil, state
  end
  if serial == saved_serial then
    return serial, state
  end
  return serial, state_defaults.apply_device_defaults(state, serial)
end

local function resolve_module(workspace, state)
  local build = state_defaults.build_defaults(state)
  if build.module and build.module ~= "" then
    return build.module
  end
  return action_defaults.select_module(workspace.modules)
end

local function resolve_variant(root, state, runner, module)
  local build = state_defaults.build_defaults(state)
  if build.variant and build.variant ~= "" then
    return build.variant
  end
  local variants = build_helpers.fetch_variants(root, runner, { module = module })
  return action_defaults.select_variant(variants)
end

local function apply_build_defaults(state, module, variant)
  local build = state_defaults.build_defaults(state)
  if build.module == module and build.variant == variant then
    return state, false
  end
  return state_defaults.apply_build_defaults(state, module, variant), true
end

local function resolve_build_selection(workspace, state, runner)
  local module = resolve_module(workspace, state)
  if not module or module == "" then
    return nil, nil, state
  end

  local variant = resolve_variant(workspace.root, state, runner, module)
  if not variant or variant == "" then
    return module, nil, state
  end

  local next_state, changed = apply_build_defaults(state, module, variant)
  if changed then
    return module, variant, next_state
  end
  return module, variant, state
end

local function persist_state(root, state, next_state)
  if next_state ~= state then
    context.save_state(root, next_state)
  end
  return next_state
end

local function resolve_package(workspace, state, sdk, runner)
  local saved_package = state and state.app and state.app.package or nil
  local package_name = package_resolver.resolve_default_package({
    workspace = workspace,
    saved_package = saved_package,
    aapt2_path = sdk.aapt2(),
    runner = runner,
  })

  if not package_name or package_name == "" then
    package_name = vim.fn.input("Package name: ")
    if package_name == "" then
      vim.notify("Package name required", vim.log.levels.WARN)
      return nil, state, false
    end
  end

  local next_state = shallow_copy(state)
  next_state.app = next_state.app or {}
  if next_state.app.package == package_name then
    return package_name, state, false
  end
  next_state.app.package = package_name
  return package_name, next_state, true
end

local function resolve_apk_path(workspace, state, runner)
  local module
  local variant
  local next_state
  module, variant, next_state = resolve_build_selection(workspace, state, runner)
  if not module then
    notify_missing_modules()
    return nil, state
  end
  if not variant then
    notify_missing_variants()
    return nil, state
  end

  if next_state ~= state then
    state = persist_state(workspace.root, state, next_state)
  end

  local apk_result = apk.resolve_apk_path(workspace.root, module, variant)
  if not apk_result.ok then
    vim.notify(apk_result.error or "APK not found", vim.log.levels.WARN)
    return nil, state
  end
  return apk_result.path, state
end

local function setup_device_action()
  local workspace = context.workspace()
  if not workspace then
    return nil
  end

  local sdk, tools = resolve_tools(workspace.root)
  local adb_path = ensure_adb(tools)
  if not adb_path then
    return nil
  end

  local runner = runner_module.new()
  local state = context.load_state(workspace.root)
  local serial, next_state = resolve_device_serial(runner, adb_path, state)
  if not serial then
    return nil
  end
  state = persist_state(workspace.root, state, next_state)

  return {
    workspace = workspace,
    sdk = sdk,
    adb_path = adb_path,
    runner = runner,
    state = state,
    serial = serial,
  }
end

local function resolve_package_for_action(action)
  local package_name
  local next_state
  local changed
  package_name, next_state, changed = resolve_package(
    action.workspace,
    action.state,
    action.sdk,
    action.runner
  )
  if not package_name then
    return nil
  end
  if changed then
    action.state = persist_state(action.workspace.root, action.state, next_state)
  end
  return package_name
end

function M.install()
  local action = setup_device_action()
  if not action then
    return
  end

  local apk_path
  apk_path, action.state = resolve_apk_path(
    action.workspace,
    action.state,
    action.runner
  )
  if not apk_path then
    return
  end

  local install = deploy.build_install_command(
    action.adb_path,
    action.serial,
    apk_path
  )
  if not install.ok then
    vim.notify(install.error or "ADB install failed", vim.log.levels.ERROR)
    return
  end

  local result = action.runner.run(install.cmd)
  if result.ok then
    vim.notify("ADB install completed", vim.log.levels.INFO)
  else
    vim.notify("ADB install failed", vim.log.levels.ERROR)
  end
end

function M.clear_data()
  local action = setup_device_action()
  if not action then
    return
  end

  local package_name = resolve_package_for_action(action)
  if not package_name then
    return
  end

  local result = action.runner.run({
    action.adb_path,
    "-s",
    action.serial,
    "shell",
    "pm",
    "clear",
    package_name,
  })
  if result.ok then
    vim.notify("App data cleared", vim.log.levels.INFO)
  else
    vim.notify("Clear data failed", vim.log.levels.ERROR)
  end
end

function M.uninstall()
  local action = setup_device_action()
  if not action then
    return
  end

  local package_name = resolve_package_for_action(action)
  if not package_name then
    return
  end

  local result = action.runner.run({
    action.adb_path,
    "-s",
    action.serial,
    "uninstall",
    package_name,
  })
  if result.ok then
    vim.notify("App uninstalled", vim.log.levels.INFO)
  else
    vim.notify("Uninstall failed", vim.log.levels.ERROR)
  end
end

return M
