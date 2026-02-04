local M = {}

local context = require("android.actions.context")
local runner_module = require("android.command.runner")
local adb = require("android.devices.adb")
local sdk_discovery = require("android.sdk.discovery")
local selection_defaults = require("android.state.selection_defaults")
local run_registry = require("android.run.registry")

local function normalize(value)
  if value == nil or value == "" then
    return "none"
  end
  return tostring(value)
end

local function format_targets(workspace)
  local targets = {}
  if workspace and workspace.android then
    targets[#targets + 1] = "android"
  end
  if workspace and workspace.kmp then
    targets[#targets + 1] = "kmp"
  end
  if workspace and workspace.ios then
    targets[#targets + 1] = "ios"
  end
  if #targets == 0 then
    return "none"
  end
  return table.concat(targets, ", ")
end

local function push_section(lines, title)
  if #lines >= 1 and lines[#lines] ~= "" then
    table.insert(lines, "")
  end
  table.insert(lines, title)
end

local function push_item(lines, label, value)
  table.insert(lines, string.format("  %s: %s", label, value))
end

local function append_run_meta(lines, run_config)
  if not run_config then
    return
  end
  local meta = run_config.meta or {}
  if run_config.type then
    push_item(lines, "Run Type", normalize(run_config.type))
  end
  if meta.module then
    push_item(lines, "Run Module", normalize(meta.module))
  end
  if meta.variant then
    push_item(lines, "Run Variant", normalize(meta.variant))
  end
  if meta.scheme then
    push_item(lines, "Run Scheme", normalize(meta.scheme))
  end
  if meta.task then
    push_item(lines, "Run Task", normalize(meta.task))
  end
  if meta.command then
    push_item(lines, "Run Command", normalize(meta.command))
  end
end

local function resolve_adb_state(root)
  local tools = sdk_discovery.new({ root = root }).tools()
  if not tools.adb then
    return { devices = {}, emulator_status = nil }
  end

  local runner = runner_module.new()
  local devices = adb.list(runner, tools.adb) or {}
  local emulator_status = "none"
  for _, device in ipairs(devices) do
    if device.serial and device.serial:match("^emulator%-") then
      emulator_status = "running"
      break
    end
  end

  return { devices = devices, emulator_status = emulator_status }
end

local function format_devices(devices)
  local serials = {}
  for _, device in ipairs(devices or {}) do
    if device.serial and device.serial ~= "" then
      serials[#serials + 1] = device.serial
    end
  end
  if #serials == 0 then
    return "none"
  end
  return table.concat(serials, ", ")
end

local function build_lines(workspace, state)
  local build = selection_defaults.build_defaults(state)
  local device = selection_defaults.device_defaults(state)
  local avd = selection_defaults.avd_defaults(state)
  local run_config = run_registry.resolve(workspace)
  local logcat_package = state and state.logcat and state.logcat.package or nil
  local adb_state = resolve_adb_state(workspace.root)
  local emulator_status = adb_state.emulator_status

  local lines = { "Summary" }

  push_section(lines, "Workspace")
  push_item(lines, "Root", normalize(workspace.root))
  push_item(lines, "Targets", format_targets(workspace))

  push_section(lines, "Run")
  push_item(lines, "Run", normalize(run_config and run_config.label))
  append_run_meta(lines, run_config)

  push_section(lines, "Build")
  push_item(lines, "Module", normalize(build.module))
  push_item(lines, "Variant", normalize(build.variant))

  push_section(lines, "Devices")
  push_item(lines, "Device", normalize(device.serial))
  push_item(lines, "Devices", format_devices(adb_state.devices))
  push_item(lines, "AVD", normalize(avd.name))
  if emulator_status ~= nil then
    push_item(lines, "Emulator", normalize(emulator_status))
  end

  push_section(lines, "Logcat")
  push_item(lines, "Logcat", normalize(logcat_package))
  return lines
end

function M.lines()
  local workspace = context.workspace()
  if not workspace then
    return { "Summary", "", "Workspace", "  Root: not found" }
  end
  local state = context.load_state(workspace.root)
  return build_lines(workspace, state)
end

return M
