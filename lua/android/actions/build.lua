local M = {}

local stream = require("android.build.stream")
local build_helpers = require("android.actions.build_helpers")
local runner_module = require("android.command.runner")
local picker = require("android.ui.picker")
local panel = require("android.ui.panel")
local defaults = require("android.state.selection_defaults")
local context = require("android.actions.context")
local action_defaults = require("android.actions.defaults")
local logcat = require("android.actions.logcat")
local apk = require("android.build.apk")
local deploy = require("android.build.deploy")
local adb = require("android.devices.adb")
local emulator = require("android.devices.emulator")
local discovery = require("android.sdk.discovery")
local wait = require("android.actions.wait")

local function prompt_for_variant(root, runner, default_variant, on_selected, opts)
  local variants = build_helpers.fetch_variants(root, runner)
  if #variants == 0 then
    vim.notify("No Gradle variants found", vim.log.levels.WARN)
    return
  end
  local options = opts or {}

  local default = nil
  if type(default_variant) == "string" and default_variant ~= "" then
    for _, variant in ipairs(variants) do
      if variant == default_variant then
        default = default_variant
        break
      end
    end
  end
  picker.select_from_list({
    title = "Build Variants",
    items = variants,
    default = default,
    on_select = on_selected,
    on_cancel = options.on_cancel,
  })
end

local function module_default_text(entries, default_module)
  if type(default_module) ~= "string" then
    return nil
  end

  local match = nil
  for _, entry in ipairs(entries or {}) do
    if entry and entry.value == default_module then
      match = entry
      break
    end
  end

  if not match then
    return nil
  end

  if default_module == "" then
    return match.label
  end
  return default_module
end

local function prompt_for_module(workspace, default_module, on_selected, opts)
  local entries = build_helpers.module_entries(workspace.modules)
  local options = opts or {}
  picker.select_from_list({
    title = "Gradle modules",
    items = entries,
    format = function(entry) return entry.label end,
    default = module_default_text(entries, default_module),
    on_select = on_selected,
    on_cancel = options.on_cancel,
  })
end

function M.select_module(opts)
  local workspace = context.workspace()
  if not workspace then
    return
  end

  local state = context.load_state(workspace.root)
  local build = defaults.build_defaults(state)

  prompt_for_module(workspace, build.module, function(module)
    local state = context.load_state(workspace.root)
    local build = defaults.build_defaults(state)
    local next_state = defaults.apply_build_defaults(state, module, build.variant)
    context.save_state(workspace.root, next_state)
    local label = module
    if label == "" or label == nil then
      label = "Root project"
    end
    vim.notify("Default module set to " .. label, vim.log.levels.INFO)
  end, opts)
end

function M.select_variant(opts)
  local workspace = context.workspace()
  if not workspace then
    return
  end

  local runner = runner_module.new()
  local state = context.load_state(workspace.root)
  local build = defaults.build_defaults(state)

  prompt_for_variant(workspace.root, runner, build.variant, function(variant)
    local state = context.load_state(workspace.root)
    local build = defaults.build_defaults(state)
    local next_state = defaults.apply_build_defaults(state, build.module, variant)
    context.save_state(workspace.root, next_state)
    vim.notify("Default variant set to " .. variant, vim.log.levels.INFO)
  end, opts)
end

local build_and_deploy

function M.build_prompt(opts)
  local workspace = context.workspace()
  if not workspace then
    return
  end

  local runner = runner_module.new()
  local options = opts or {}
  local state = context.load_state(workspace.root)
  local build = defaults.build_defaults(state)

  local open_module_picker
  local function open_variant_picker(module)
    prompt_for_variant(workspace.root, runner, build.variant, function(variant)
      local state = context.load_state(workspace.root)
      build_and_deploy(workspace, module, variant, runner, state)
    end, {
      on_cancel = function()
        open_module_picker()
      end,
    })
  end

  open_module_picker = function()
    prompt_for_module(workspace, build.module, function(module)
      open_variant_picker(module)
    end, {
      on_cancel = options.on_cancel,
    })
  end

  open_module_picker()
end

local function resolve_module(workspace, state)
  local build = defaults.build_defaults(state)
  if build.module and build.module ~= "" then
    return build.module
  end
  return action_defaults.select_module(workspace.modules)
end

local function resolve_variant(root, state, runner)
  local build = defaults.build_defaults(state)
  if build.variant and build.variant ~= "" then
    return build.variant
  end
  local variants = build_helpers.fetch_variants(root, runner)
  return action_defaults.select_variant(variants)
end

local function apply_build_defaults(state, module, variant)
  local build = defaults.build_defaults(state)
  if build.module == module and build.variant == variant then
    return state, false
  end
  return defaults.apply_build_defaults(state, module, variant), true
end

local function resolve_device_serial(devices, saved_serial)
  return action_defaults.select_device_serial(devices, saved_serial)
end

local function resolve_avd_name(avds, saved_name)
  return action_defaults.select_avd_name(avds, saved_name)
end

local function notify_missing_variants()
  vim.notify("No Gradle variants found", vim.log.levels.WARN)
end

local function notify_missing_modules()
  vim.notify("No Gradle modules found", vim.log.levels.WARN)
end

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

local function apply_logcat_package(state, package)
  if not package or package == "" then
    return state, false
  end
  local current = state and state.logcat and state.logcat.package or nil
  if current == package then
    return state, false
  end
  local next_state = shallow_copy(state)
  next_state.logcat = next_state.logcat or {}
  next_state.logcat.package = package
  return next_state, true
end

local function resolve_device_for_deploy(runner, tools, state)
  if not tools.adb then
    vim.notify("adb not found in Android SDK", vim.log.levels.WARN)
    return nil, state
  end

  local devices = adb.list(runner, tools.adb)
  local saved_serial = defaults.device_defaults(state).serial
  local serial = resolve_device_serial(devices, saved_serial)
  if serial then
    local next_state = defaults.apply_device_defaults(state, serial)
    return serial, next_state
  end

  if not tools.emulator then
    vim.notify("emulator not found in Android SDK", vim.log.levels.WARN)
    return nil, state
  end

  local avds = emulator.list(runner, tools.emulator)
  local saved_avd = defaults.avd_defaults(state).name
  local avd_name = resolve_avd_name(avds, saved_avd)
  if not avd_name then
    vim.notify("No emulator AVDs found", vim.log.levels.WARN)
    return nil, state
  end

  local boot_result = emulator.boot({
    runner = runner,
    adb_path = tools.adb,
    emulator_path = tools.emulator,
    avd_name = avd_name,
  })
  if not boot_result.ok then
    local message = boot_result.error or "Failed to start emulator"
    local level = vim.log.levels.WARN
    if message == "Failed to start emulator" or message == "Emulator failed to start" then
      level = vim.log.levels.ERROR
    end
    vim.notify(message, level)
    return nil, state
  end

  serial = boot_result.serial
  if not serial then
    vim.notify("No adb devices found", vim.log.levels.WARN)
    return nil, state
  end

  local next_state = defaults.apply_device_defaults(state, serial)
  next_state = defaults.apply_avd_defaults(next_state, avd_name)
  return serial, next_state
end

local function resolve_build_selection(workspace, state, runner)
  local module = resolve_module(workspace, state)
  if not module or module == "" then
    return nil, nil, state
  end

  local variant = resolve_variant(workspace.root, state, runner)
  if not variant or variant == "" then
    return module, nil, state
  end

  local next_state, changed = apply_build_defaults(state, module, variant)
  if changed then
    return module, variant, next_state
  end
  return module, variant, state
end

local function deploy_after_build(workspace, module, variant, runner, state)
  local sdk = discovery.new({ root = workspace.root })
  local tools = sdk.tools()
  local device, device_state = resolve_device_for_deploy(runner, tools, state)
  if not device then
    return state
  end

  if device_state ~= state then
    context.save_state(workspace.root, device_state)
    state = device_state
  end

  local boot_result = wait.wait_for_boot(runner, tools.adb, device)
  if not boot_result.ok then
    vim.notify("Timed out waiting for device boot completion", vim.log.levels.WARN)
    return state
  end

  local apk_result = apk.resolve_apk_path(workspace.root, module, variant)
  if not apk_result.ok then
    vim.notify(apk_result.error or "APK not found", vim.log.levels.WARN)
    return state
  end

  local deploy_result = deploy.deploy({
    adb_path = tools.adb,
    aapt2_path = sdk.aapt2(),
    device = device,
    apk_path = apk_result.path,
    runner = runner,
  })

  if deploy_result.ok then
    local next_state, changed = apply_logcat_package(state, deploy_result.app_id)
    if changed then
      context.save_state(workspace.root, next_state)
      state = next_state
    end
    panel.close()
    logcat.open()
    vim.notify("Android deploy completed", vim.log.levels.INFO)
  else
    local message = deploy_result.error or "Android deploy failed"
    vim.notify(message, vim.log.levels.ERROR)
  end

  return state
end

build_and_deploy = function(workspace, module, variant, runner, state)
  build_helpers.run_build(workspace.root, module, variant, function(result)
    if not result or not result.ok then
      return
    end
    state = deploy_after_build(workspace, module, variant, runner, state)
  end)
end

function M.build_default()
  local workspace = context.workspace()
  if not workspace then
    return
  end

  local runner = runner_module.new()
  local state = context.load_state(workspace.root)
  local module, variant, next_state = resolve_build_selection(workspace, state, runner)
  if not module then
    notify_missing_modules()
    return
  end
  if not variant then
    notify_missing_variants()
    return
  end

  if next_state ~= state then
    context.save_state(workspace.root, next_state)
    state = next_state
  end

  build_helpers.run_build(workspace.root, module, variant, function(result)
    if not result or not result.ok then
      return
    end
    state = deploy_after_build(workspace, module, variant, runner, state)
  end)
end

function M.build_pure()
  local workspace = context.workspace()
  if not workspace then
    return
  end

  local runner = runner_module.new()
  local state = context.load_state(workspace.root)
  local module, variant, next_state = resolve_build_selection(workspace, state, runner)
  if not module then
    notify_missing_modules()
    return
  end
  if not variant then
    notify_missing_variants()
    return
  end

  if next_state ~= state then
    context.save_state(workspace.root, next_state)
  end

  build_helpers.run_build(workspace.root, module, variant)
end

function M.show_build_errors()
  vim.cmd("copen")
end

function M.list_apks(opts)
  local workspace = context.workspace()
  if not workspace then
    return
  end

  local runner = runner_module.new()
  local state = context.load_state(workspace.root)
  local module, variant, next_state = resolve_build_selection(workspace, state, runner)
  if not module then
    notify_missing_modules()
  end
  if not variant then
    notify_missing_variants()
  end

  if module and variant and next_state ~= state then
    context.save_state(workspace.root, next_state)
  end

  local items = {}
  local title = "APKs in workspace"
  local result = nil

  if module and variant then
    result = apk.list_apk_paths(workspace.root, module, variant)
    if result.ok then
      for _, path in ipairs(result.apks or {}) do
        table.insert(items, {
          label = vim.fn.fnamemodify(path, ":t"),
          value = path,
        })
      end
      title = string.format("APKs %s %s", module, variant)
    end
  end

  if #items == 0 then
    local fallback = apk.list_workspace_apks(workspace.root, workspace.modules)
    if not fallback.ok then
      local message = fallback.error or (result and result.error) or "APK not found"
      vim.notify(message, vim.log.levels.WARN)
      return
    end

    for _, entry in ipairs(fallback.apks or {}) do
      local filename = vim.fn.fnamemodify(entry.path, ":t")
      local label = filename
      if entry.module and entry.module ~= "" then
        label = string.format("%s %s", entry.module, filename)
      end
      table.insert(items, { label = label, value = entry.path })
    end
  end
  local options = opts or {}
  picker.select_from_list({
    title = title,
    items = items,
    file_ignore_patterns = options.file_ignore_patterns or {},
    format = function(entry)
      return string.format("%s (%s)", entry.label, entry.value)
    end,
    on_select = function(path)
      vim.fn.setreg("+", path)
      vim.notify("APK path copied: " .. path, vim.log.levels.INFO)
    end,
    on_cancel = options.on_cancel,
  })
end

function M.clean()
  local workspace = context.workspace()
  if not workspace then
    return
  end

  local args = build_helpers.build_command(workspace.root, { "clean" })
  stream.start_build_job(workspace.root, args, function(result)
    if result and result.ok then
      vim.notify("Gradle clean completed", vim.log.levels.INFO)
      return
    end
    vim.notify("Gradle clean failed", vim.log.levels.ERROR)
  end)
end

return M
