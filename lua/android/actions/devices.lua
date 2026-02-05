local M = {}

local runner_module = require("android.command.runner")
local adb = require("android.devices.adb")
local avd = require("android.devices.avd")
local emulator = require("android.devices.emulator")
local discovery = require("android.sdk.discovery")
local sdk_packages = require("android.sdk.packages")
local picker = require("android.ui.picker")
local defaults = require("android.state.selection_defaults")
local context = require("android.actions.context")

local function resolve_tools(root)
  local sdk = discovery.new({ root = root })
  return sdk.tools()
end

local function resolve_workspace_tools(required)
  local workspace = context.workspace()
  if not workspace then
    return nil, nil
  end

  local tools = resolve_tools(workspace.root)
  for _, key in ipairs(required or {}) do
    if not tools[key] then
      vim.notify(key .. " not found in Android SDK", vim.log.levels.WARN)
      return nil, nil
    end
  end
  return workspace, tools
end

local function device_entries(devices)
  local entries = {}
  for _, device in ipairs(devices or {}) do
    local label = device.serial .. " (" .. device.state .. ")"
    if device.model and device.model ~= "" then
      label = label .. " " .. device.model
    end
    table.insert(entries, { label = label, value = device.serial })
  end
  return entries
end

local function list_devices(runner, adb_path)
  local devices = adb.list(runner, adb_path)
  if #devices == 0 then
    vim.notify("No adb devices found", vim.log.levels.WARN)
  end
  return devices
end

function M.select_device(opts)
  local workspace, tools = resolve_workspace_tools({ "adb" })
  if not workspace then
    return
  end

  local options = opts or {}
  local runner = runner_module.new()
  local devices = list_devices(runner, tools.adb)
  local entries = device_entries(devices)
  if #entries == 0 then
    return
  end

  picker.select_from_list({
    title = "Devices",
    items = entries,
    format = function(entry) return entry.label end,
    on_select = function(serial)
      local state = context.load_state(workspace.root)
      local next_state = defaults.apply_device_defaults(state, serial)
      context.save_state(workspace.root, next_state)
      vim.notify("Default device set to " .. serial, vim.log.levels.INFO)
    end,
    on_cancel = options.on_cancel,
  })
end

function M.select_avd(on_selected, opts)
  local workspace, tools = resolve_workspace_tools({ "emulator" })
  if not workspace then
    return
  end

  local selected = on_selected
  local options = opts
  if type(on_selected) == "table" and opts == nil then
    options = on_selected
    selected = nil
  end
  options = options or {}

  local runner = runner_module.new()
  local avds = emulator.list(runner, tools.emulator)
  if #avds == 0 then
    vim.notify("No emulator AVDs found", vim.log.levels.WARN)
    return
  end

  picker.select_from_list({
    title = "Emulator AVDs",
    items = avds,
    on_select = function(name)
      local state = context.load_state(workspace.root)
      local next_state = defaults.apply_avd_defaults(state, name)
      context.save_state(workspace.root, next_state)
      if selected then
        selected(name)
      else
        vim.notify("Default AVD set to " .. name, vim.log.levels.INFO)
      end
    end,
    on_cancel = options.on_cancel,
  })
end

function M.start_emulator()
  local workspace, tools = resolve_workspace_tools({ "emulator" })
  if not workspace then
    return
  end

  local state = context.load_state(workspace.root)
  local avd_name = defaults.avd_defaults(state).name

  local function launch(name)
    if not name or name == "" then
      vim.notify("AVD name required", vim.log.levels.WARN)
      return
    end
    local cmd = emulator.build_command(tools.emulator, name, {})
    local job_id = vim.fn.jobstart(cmd, { detach = true })
    if job_id <= 0 then
      vim.notify("Failed to start emulator", vim.log.levels.ERROR)
      return
    end
    vim.notify("Emulator started: " .. name, vim.log.levels.INFO)
  end

  if avd_name and avd_name ~= "" then
    launch(avd_name)
    return
  end

  M.select_avd(launch)
end

function M.create_avd(opts)
  local workspace, tools = resolve_workspace_tools({ "avdmanager" })
  if not workspace then
    return
  end

  local options = opts or {}
  local runner = runner_module.new()
  local devices = avd.list_devices(runner, tools.avdmanager)
  if #devices == 0 then
    vim.notify("No AVD device profiles found", vim.log.levels.WARN)
    return
  end

  local entries = {}
  for _, entry in ipairs(devices) do
    local label = entry.name or entry.id
    if entry.oem then
      label = label .. " (" .. entry.oem .. ")"
    end
    table.insert(entries, { label = label, value = entry.id })
  end

  local reopen_device_profiles

  local function open_system_images(device_id)
    local name = vim.fn.input("AVD name: ")
    if name == "" then
      vim.notify("AVD name required", vim.log.levels.WARN)
      return
    end
    local system_images = sdk_packages.list_system_images(
      discovery.new({ root = workspace.root }).packages()
    )
    if #system_images == 0 then
      vim.notify("No system images installed", vim.log.levels.WARN)
      return
    end

    picker.select_from_list({
      title = "System images",
      items = system_images,
      on_select = function(system_image)
        local result = avd.build_create_command(
          tools.avdmanager,
          name,
          system_image,
          device_id,
          { force = true }
        )
        if not result.ok then
          vim.notify(result.error or "Failed to create AVD", vim.log.levels.ERROR)
          return
        end

        local created = runner.run(result.cmd)
        if not created.ok then
          vim.notify("AVD create failed", vim.log.levels.ERROR)
          return
        end

        local state = context.load_state(workspace.root)
        local next_state = defaults.apply_avd_defaults(state, name)
        context.save_state(workspace.root, next_state)
        vim.notify("AVD created: " .. name, vim.log.levels.INFO)
      end,
      on_cancel = function()
        if reopen_device_profiles then
          reopen_device_profiles()
        end
      end,
    })
  end

  reopen_device_profiles = function()
    picker.select_from_list({
      title = "AVD device profiles",
      items = entries,
      format = function(entry) return entry.label end,
      on_select = open_system_images,
      on_cancel = options.on_cancel,
    })
  end

  reopen_device_profiles()
end

function M.stop_emulator(opts)
  local workspace, tools = resolve_workspace_tools({ "adb" })
  if not workspace then
    return
  end

  local options = opts or {}
  local runner = runner_module.new()
  local devices = list_devices(runner, tools.adb)
  local entries = {}
  for _, device in ipairs(devices) do
    if device.serial:match("^emulator%-") then
      table.insert(entries, {
        label = device.serial,
        value = device.serial,
      })
    end
  end

  if #entries == 0 then
    vim.notify("No running emulators found", vim.log.levels.WARN)
    return
  end

  picker.select_from_list({
    title = "Running emulators",
    items = entries,
    format = function(entry) return entry.label end,
    on_select = function(serial)
      local cmd = { tools.adb, "-s", serial, "emu", "kill" }
      local result = runner.run(cmd)
      if result.ok then
        vim.notify("Emulator stopped: " .. serial, vim.log.levels.INFO)
      else
        vim.notify("Failed to stop emulator", vim.log.levels.ERROR)
      end
    end,
    on_cancel = options.on_cancel,
  })
end

return M
