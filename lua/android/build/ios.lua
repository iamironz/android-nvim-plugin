local M = {}

local runner_module = require("android.command.runner")
local stream = require("android.build.stream")
local strings = require("android.utils.strings")

local function normalize_target(ios)
  if ios.workspace and ios.workspace ~= "" then
    return { "-workspace", ios.workspace }
  end
  if ios.project and ios.project ~= "" then
    return { "-project", ios.project }
  end
  return nil
end

local function parse_schemes(output)
  local schemes = {}
  local in_schemes = false
  for line in (output or ""):gmatch("[^\n]+") do
    local trimmed = strings.trim(line)
    if trimmed == "Schemes:" then
      in_schemes = true
    elseif in_schemes then
      if trimmed == "" then
        -- keep reading
      elseif line:match("^%s") then
        if trimmed:find(":") then
          in_schemes = false
        else
          schemes[#schemes + 1] = trimmed
        end
      else
        in_schemes = false
      end
    end
  end
  return schemes
end

local function base_name(path, suffix)
  if not path or path == "" then
    return nil
  end
  local name = path:match("([^/]+)$") or path
  if suffix and name:sub(-#suffix) == suffix then
    return name:sub(1, #name - #suffix)
  end
  return name
end

local function preferred_scheme(ios, schemes)
  local base = base_name(ios.workspace, ".xcworkspace") or base_name(ios.project, ".xcodeproj")
  if base then
    for _, scheme in ipairs(schemes or {}) do
      if scheme == base then
        return scheme
      end
    end
  end
  for _, scheme in ipairs(schemes or {}) do
    if type(scheme) == "string" and scheme:lower() == "ios" then
      return scheme
    end
  end
  return (schemes or {})[1]
end

local function resolve_scheme(ios, runner)
  local target_args = normalize_target(ios)
  if not target_args then
    return nil, "iOS workspace or project required"
  end
  local args = { "xcodebuild" }
  for _, arg in ipairs(target_args) do
    args[#args + 1] = arg
  end
  args[#args + 1] = "-list"
  local result = runner.run(args)
  if not result or not result.ok then
    return nil, "xcodebuild -list failed"
  end
  local schemes = parse_schemes(result.stdout or "")
  if #schemes == 0 then
    return nil, "No Xcode schemes found"
  end
  return preferred_scheme(ios, schemes)
end

local function build_args(ios, scheme, destination, configuration)
  local target_args = normalize_target(ios) or {}
  local args = { "xcodebuild" }
  for _, arg in ipairs(target_args) do
    args[#args + 1] = arg
  end
  if scheme and scheme ~= "" then
    args[#args + 1] = "-scheme"
    args[#args + 1] = scheme
  end
  args[#args + 1] = "-configuration"
  args[#args + 1] = configuration or "Debug"
  if destination and destination ~= "" then
    args[#args + 1] = "-destination"
    args[#args + 1] = destination
  else
    args[#args + 1] = "-sdk"
    args[#args + 1] = "iphonesimulator"
  end
  args[#args + 1] = "build"
  return args
end

local function settings_args(ios, scheme, destination, configuration)
  local args = build_args(ios, scheme, destination, configuration)
  args[#args] = "-showBuildSettings"
  return args
end

local function parse_setting(output, key)
  for line in (output or ""):gmatch("[^\n]+") do
    local value = line:match("^%s*" .. key .. "%s*=%s*(.+)$")
    if value then
      return strings.trim(value)
    end
  end
  return nil
end

local function resolve_build_settings(ios, scheme, destination, runner)
  local args = settings_args(ios, scheme, destination)
  local result = runner.run(args)
  if not result or not result.ok then
    return { ok = false, error = "xcodebuild settings failed" }
  end
  local stdout = result.stdout or ""
  local target_dir = parse_setting(stdout, "TARGET_BUILD_DIR")
    or parse_setting(stdout, "CONFIGURATION_BUILD_DIR")
    or parse_setting(stdout, "BUILT_PRODUCTS_DIR")
  local product_name = parse_setting(stdout, "FULL_PRODUCT_NAME")
  local bundle_id = parse_setting(stdout, "PRODUCT_BUNDLE_IDENTIFIER")
  if not target_dir or not product_name then
    return { ok = false, error = "iOS app path not found" }
  end
  return {
    ok = true,
    app_path = target_dir .. "/" .. product_name,
    bundle_id = bundle_id,
  }
end

local function resolve_booted_simulator(runner)
  local result = runner.run({ "xcrun", "simctl", "list", "devices", "booted", "--json" })
  if not result or not result.ok then
    return nil, "simctl list failed"
  end
  local ok, decoded = pcall(vim.fn.json_decode, result.stdout or "")
  if not ok then
    return nil, "simctl output unreadable"
  end
  for _, list in pairs(decoded.devices or {}) do
    for _, device in ipairs(list or {}) do
      if device.state == "Booted" then
        return device
      end
    end
  end
  return nil, "No booted iOS simulators found"
end

local function parse_paired_device(result)
  local devices = result and result.result and result.result.devices or {}
  for _, device in ipairs(devices or {}) do
    local connection = device.connectionProperties or {}
    local hardware = device.hardwareProperties or {}
    if connection.pairingState == "paired" and hardware.reality == "physical" then
      local identifier = device.identifier or hardware.udid
      if identifier and identifier ~= "" then
        local name = device.deviceProperties and device.deviceProperties.name
        return { udid = identifier, name = name }
      end
    end
  end
  return nil
end

local function decode_json(path)
  local ok, lines = pcall(vim.fn.readfile, path)
  if not ok or not lines then
    return nil
  end
  local json = table.concat(lines, "\n")
  local decoded_ok, decoded = pcall(vim.fn.json_decode, json)
  if not decoded_ok then
    return nil
  end
  return decoded
end

local function resolve_paired_device(runner)
  local json_path = vim.fn.tempname()
  local result = runner.run({
    "xcrun",
    "devicectl",
    "list",
    "devices",
    "--json-output",
    json_path,
  })
  if not result or not result.ok then
    return nil, "devicectl list devices failed"
  end
  local decoded = decode_json(json_path)
  pcall(os.remove, json_path)
  if not decoded then
    return nil, "devicectl json unreadable"
  end
  local device = parse_paired_device(decoded)
  if not device then
    return nil, "No paired iOS devices found"
  end
  return device
end

local function resolve_deploy_target(runner)
  local simulator, sim_err = resolve_booted_simulator(runner)
  if simulator then
    return { kind = "simulator", udid = simulator.udid, name = simulator.name }
  end
  local device, device_err = resolve_paired_device(runner)
  if device then
    return { kind = "device", udid = device.udid }
  end
  local no_simulator = sim_err == "No booted iOS simulators found"
  local no_device = device_err == "No paired iOS devices found"
  if no_simulator and no_device then
    return nil,
      "No booted iOS simulators or paired physical devices found. "
        .. "Boot a simulator or pair a device in Xcode."
  end
  return nil, device_err or sim_err or "No iOS devices available"
end

local function install_simulator_app(runner, device_id, app_path)
  local result = runner.run({ "xcrun", "simctl", "install", device_id, app_path })
  if not result or not result.ok then
    return { ok = false, error = "simctl install failed", result = result }
  end
  return { ok = true }
end

local function launch_simulator_app(runner, device_id, bundle_id)
  if not bundle_id or bundle_id == "" then
    return { ok = false, error = "bundle id required" }
  end
  local result = runner.run({ "xcrun", "simctl", "launch", device_id, bundle_id })
  if not result or not result.ok then
    return { ok = false, error = "simctl launch failed", result = result }
  end
  return { ok = true }
end

local function install_device_app(runner, device_id, app_path)
  local result = runner.run({
    "xcrun",
    "devicectl",
    "device",
    "install",
    "app",
    "--device",
    device_id,
    app_path,
  })
  if not result or not result.ok then
    return { ok = false, error = "devicectl install failed", result = result }
  end
  return { ok = true }
end

local function launch_device_app(runner, device_id, bundle_id)
  if not bundle_id or bundle_id == "" then
    return { ok = false, error = "bundle id required" }
  end
  local result = runner.run({
    "xcrun",
    "devicectl",
    "device",
    "process",
    "launch",
    "--device",
    device_id,
    bundle_id,
  })
  if not result or not result.ok then
    return { ok = false, error = "devicectl launch failed", result = result }
  end
  return { ok = true }
end

function M.build(ios, runner, opts)
  local options = opts or {}
  if not ios or not ios.root then
    vim.notify("iOS workspace not found", vim.log.levels.WARN)
    return nil
  end
  local exec = runner or runner_module.new()
  local scheme, err = resolve_scheme(ios, exec)
  if not scheme then
    vim.notify(err or "iOS scheme not found", vim.log.levels.WARN)
    return nil
  end
  local args = build_args(ios, scheme, nil, options.configuration)
  return stream.start_build_job(ios.root, args, options.on_complete, {
    panel = {
      module = "ios",
      variant = options.configuration or "Debug",
      task = scheme and ("scheme:" .. scheme) or "xcodebuild",
    },
  })
end

function M.deploy(ios, runner, opts)
  local options = opts or {}
  if not ios or not ios.root then
    vim.notify("iOS workspace not found", vim.log.levels.WARN)
    return nil
  end
  local exec = runner or runner_module.new()
  local target, device_err = resolve_deploy_target(exec)
  if not target then
    vim.notify(device_err or "No iOS devices available", vim.log.levels.WARN)
    return nil
  end
  local scheme, err = resolve_scheme(ios, exec)
  if not scheme then
    vim.notify(err or "iOS scheme not found", vim.log.levels.WARN)
    return nil
  end
  local destination = "id=" .. target.udid
  local args = build_args(ios, scheme, destination, options.configuration)
  return stream.start_build_job(ios.root, args, function(result)
    if not result or not result.ok then
      return
    end
    local settings = resolve_build_settings(ios, scheme, destination, exec)
    if not settings.ok then
      vim.notify(settings.error or "iOS app path not found", vim.log.levels.WARN)
      return
    end
    if target.kind == "simulator" then
      local install = install_simulator_app(exec, target.udid, settings.app_path)
      if not install.ok then
        vim.notify(install.error or "iOS install failed", vim.log.levels.ERROR)
        return
      end
      local launch = launch_simulator_app(exec, target.udid, settings.bundle_id)
      if not launch.ok then
        vim.notify(launch.error or "iOS launch failed", vim.log.levels.ERROR)
        return
      end
    else
      local install = install_device_app(exec, target.udid, settings.app_path)
      if not install.ok then
        vim.notify(install.error or "iOS install failed", vim.log.levels.ERROR)
        return
      end
      local launch = launch_device_app(exec, target.udid, settings.bundle_id)
      if not launch.ok then
        vim.notify(launch.error or "iOS launch failed", vim.log.levels.ERROR)
        return
      end
    end
    vim.notify("iOS deploy completed", vim.log.levels.INFO)
  end, {
    panel = {
      module = "ios",
      variant = options.configuration or "Debug",
      task = scheme and ("scheme:" .. scheme) or "xcodebuild",
    },
  })
end

return M
