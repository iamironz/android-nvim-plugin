local M = {}

local context = require("android.actions.context")
local runner_module = require("android.command.runner")
local adb = require("android.devices.adb")
local sdk_discovery = require("android.sdk.discovery")
local selection_defaults = require("android.state.selection_defaults")
local run_registry = require("android.run.registry")

local adb_cache = {}

local function now_ms()
  return vim.loop.hrtime() / 1000000
end

local function cached_adb_state(root, ttl_ms)
  if not root or root == "" then
    return nil
  end
  local entry = adb_cache[root]
  if not entry then
    return nil
  end
  local age = now_ms() - (entry.at_ms or 0)
  if age < 0 or age > (ttl_ms or 0) then
    return nil
  end
  return { devices = entry.devices or {}, emulator_status = entry.emulator_status }
end

local function store_cached_adb_state(root, adb_state)
  if not root or root == "" or not adb_state then
    return
  end
  adb_cache[root] = {
    at_ms = now_ms(),
    devices = adb_state.devices or {},
    emulator_status = adb_state.emulator_status,
  }
end

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
    if device.state == "device" and device.serial and device.serial:match("^emulator%-") then
      emulator_status = "running"
      break
    end
  end

  local state = { devices = devices, emulator_status = emulator_status }
  store_cached_adb_state(root, state)
  return state
end

local function format_devices(devices, adb_state)
  if adb_state and adb_state.loading then
    return "loading..."
  end
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

local function build_lines(workspace, state, adb_state)
  local build = selection_defaults.build_defaults(state)
  local device = selection_defaults.device_defaults(state)
  local avd = selection_defaults.avd_defaults(state)
  local run_config = run_registry.resolve(workspace)
  local logcat_package = state and state.logcat and state.logcat.package or nil
  local resolved_adb_state = adb_state or resolve_adb_state(workspace.root)
  local emulator_status = resolved_adb_state.emulator_status

  local lines = { "Summary" }

  push_section(lines, "Workspace")
  push_item(lines, "Root", normalize(workspace.root))
  push_item(lines, "Targets", format_targets(workspace))

  push_section(lines, "Run")
  push_item(lines, "Run", normalize(run_config and run_config.label))
  append_run_meta(lines, run_config)

  push_section(lines, "Build Variants")
  push_item(lines, "Module", normalize(build.module))
  push_item(lines, "Variant", normalize(build.variant))

  push_section(lines, "Device Manager")
  push_item(lines, "Device", normalize(device.serial))
  push_item(lines, "Devices", format_devices(resolved_adb_state.devices, resolved_adb_state))
  push_item(lines, "AVD", normalize(avd.name))
  if emulator_status ~= nil then
    push_item(lines, "Emulator", normalize(emulator_status))
  end

  push_section(lines, "Logcat")
  push_item(lines, "Logcat", normalize(logcat_package))
  return lines
end

local function build_lines_fast(workspace, state, adb_state)
  local build = selection_defaults.build_defaults(state)
  local device = selection_defaults.device_defaults(state)
  local avd = selection_defaults.avd_defaults(state)
  local logcat_package = state and state.logcat and state.logcat.package or nil
  local resolved_adb_state = adb_state or { devices = {}, emulator_status = nil }
  local emulator_status = resolved_adb_state.emulator_status

  local lines = { "Summary" }

  push_section(lines, "Workspace")
  push_item(lines, "Root", normalize(workspace.root))
  push_item(lines, "Targets", format_targets(workspace))

  push_section(lines, "Run")
  push_item(lines, "Run", "loading...")

  push_section(lines, "Build")
  push_item(lines, "Module", normalize(build.module))
  push_item(lines, "Variant", normalize(build.variant))

  push_section(lines, "Devices")
  push_item(lines, "Device", normalize(device.serial))
  push_item(lines, "Devices", format_devices(resolved_adb_state.devices, resolved_adb_state))
  push_item(lines, "AVD", normalize(avd.name))
  if emulator_status ~= nil then
    push_item(lines, "Emulator", normalize(emulator_status))
  end

  push_section(lines, "Logcat")
  push_item(lines, "Logcat", normalize(logcat_package))
  return lines
end

local function run_async(cmd, on_exit)
  if vim.system then
    vim.system(cmd, { text = true }, function(result)
      on_exit({
        code = result and result.code or 0,
        stdout = result and result.stdout or "",
        stderr = result and result.stderr or "",
      })
    end)
    return
  end

  local stdout_chunks = {}
  local stderr_chunks = {}
  vim.fn.jobstart(cmd, {
    stdout_buffered = true,
    stderr_buffered = true,
    on_stdout = function(_, data)
      if data then
        stdout_chunks = data
      end
    end,
    on_stderr = function(_, data)
      if data then
        stderr_chunks = data
      end
    end,
    on_exit = function(_, code)
      on_exit({
        code = tonumber(code) or 0,
        stdout = table.concat(stdout_chunks or {}, "\n"),
        stderr = table.concat(stderr_chunks or {}, "\n"),
      })
    end,
  })
end

local function resolve_adb_state_async(root, adb_path, callback)
  if not adb_path or adb_path == "" then
    return
  end

  run_async({ adb_path, "devices", "-l" }, function(result)
    local stdout = result and result.stdout or ""
    local lines = vim.split(stdout, "\n", { plain = true })
    local devices = adb.parse_devices(lines)
    local emulator_status = "none"
    for _, device in ipairs(devices) do
      if device.state == "device" and device.serial and device.serial:match("^emulator%-") then
        emulator_status = "running"
        break
      end
    end
    local adb_state = { devices = devices, emulator_status = emulator_status }
    store_cached_adb_state(root, adb_state)
    vim.schedule(function()
      callback(adb_state)
    end)
  end)
end

local function is_fast_mode(opts)
  return opts and opts.mode == "fast"
end

function M.lines(opts)
  local workspace = context.workspace()
  if not workspace then
    return { "Summary", "", "Workspace", "  Root: not found" }
  end
  local state = context.load_state(workspace.root)

  if opts and opts.include_adb == false then
    if is_fast_mode(opts) then
      local lines = build_lines_fast(workspace, state, { devices = {}, emulator_status = nil })
      local function refresh(callback)
        vim.schedule(function()
          callback(build_lines(workspace, state, { devices = {}, emulator_status = nil }))
        end)
      end
      return lines, refresh
    end
    return build_lines(workspace, state, { devices = {}, emulator_status = nil })
  end

  if not is_fast_mode(opts) then
    return build_lines(workspace, state)
  end

  local cached = cached_adb_state(workspace.root, (opts and opts.adb_cache_ttl_ms) or 2000)
  if cached then
    local lines = build_lines_fast(workspace, state, cached)
    local function refresh(callback)
      vim.schedule(function()
        callback(build_lines(workspace, state, cached))
      end)
    end
    return lines, refresh
  end

  local tools = sdk_discovery.new({ root = workspace.root }).tools()
  if not tools.adb then
    local lines = build_lines_fast(workspace, state, { devices = {}, emulator_status = nil })
    local function refresh(callback)
      vim.schedule(function()
        callback(build_lines(workspace, state, { devices = {}, emulator_status = nil }))
      end)
    end
    return lines, refresh
  end

  local placeholder = { devices = nil, emulator_status = "checking", loading = true }
  local lines = build_lines_fast(workspace, state, placeholder)
  local function refresh(callback)
    resolve_adb_state_async(workspace.root, tools.adb, function(adb_state)
      callback(build_lines(workspace, state, adb_state))
    end)
  end
  return lines, refresh
end

return M
