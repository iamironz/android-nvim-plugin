local M = {}

local adb = require("android.devices.adb")
local wait = require("android.actions.wait")
local utils = require("android.devices.utils")

local function is_windows(os_name)
  return os_name == "Windows_NT"
end

local function escape_regex(value)
  if not value or value == "" then
    return value
  end
  return value:gsub("([%^%$%(%)%%%.%[%]%*%+%-%?%\\|])", "\\%1")
end

local function wait_delay(wait_fn, delay)
  if not delay or delay <= 0 then
    return
  end
  local fn = wait_fn or vim.wait
  fn(delay, function()
    return false
  end, 10)
end

local function is_running(runner, avd_name)
  if not runner or not avd_name or avd_name == "" then
    return false
  end

  local escaped = escape_regex(avd_name)
  local patterns = {
    "qemu.*" .. escaped,
    "emulator.*" .. escaped,
  }
  for _, pattern in ipairs(patterns) do
    local result = runner.run({ "pgrep", "-f", pattern })
    local stdout = utils.trim(result and result.stdout or "")
    if result and result.ok and stdout ~= "" then
      return true
    end
  end
  return false
end

local function list_emulator_serials(devices)
  local serials = {}
  for _, device in ipairs(devices or {}) do
    if device.state == "device" and device.serial and device.serial:match("^emulator%-") then
      serials[#serials + 1] = device.serial
    end
  end
  return serials
end

local function select_emulator_serial(before, after)
  local before_set = {}
  for _, serial in ipairs(list_emulator_serials(before)) do
    before_set[serial] = true
  end

  local after_list = list_emulator_serials(after)
  for _, serial in ipairs(after_list) do
    if not before_set[serial] then
      return serial
    end
  end
  return after_list[#after_list]
end

function M.parse_emulator_avd_list(lines)
  local avds = {}
  for _, line in ipairs(lines or {}) do
    local trimmed = utils.trim(line)
    if trimmed ~= "" then
      table.insert(avds, trimmed)
    end
  end
  return avds
end

function M.build_command(emulator_path, avd_name, opts)
  local cmd = { emulator_path, "-avd", avd_name }
  local options = opts or {}

  if options.no_window then
    table.insert(cmd, "-no-window")
  end

  if options.wipe_data then
    table.insert(cmd, "-wipe-data")
  end

  if options.no_snapshot then
    table.insert(cmd, "-no-snapshot")
  end

  if options.port then
    table.insert(cmd, "-port")
    table.insert(cmd, tostring(options.port))
  end

  if options.gpu then
    table.insert(cmd, "-gpu")
    table.insert(cmd, options.gpu)
  end

  for _, arg in ipairs(options.args or {}) do
    table.insert(cmd, arg)
  end

  return cmd
end

function M.list(runner, emulator_path)
  if not runner or not emulator_path then
    return {}
  end

  local lines = utils.runner_stdout_lines(runner, { emulator_path, "-list-avds" })
  return M.parse_emulator_avd_list(lines)
end

function M.boot(opts)
  local options = opts or {}
  local runner = options.runner
  local adb_path = options.adb_path
  local emulator_path = options.emulator_path
  local avd_name = options.avd_name
  if not runner or not adb_path or not emulator_path or not avd_name or avd_name == "" then
    return { ok = false, error = "Emulator launch requires adb, emulator, and avd" }
  end

  local os_name = options.os_name or vim.loop.os_uname().sysname
  local before = adb.list(runner, adb_path)
  local cmd = M.build_command(emulator_path, avd_name, options.emulator_opts)
  local jobstart = options.jobstart or vim.fn.jobstart
  local job_id = jobstart(cmd, { detach = true, cwd = options.cwd or vim.loop.os_homedir() })
  if not job_id or job_id <= 0 then
    return { ok = false, error = "Failed to start emulator" }
  end

  wait_delay(options.wait_fn, options.start_delay or 3000)
  if options.verify_running ~= false and not is_windows(os_name) then
    if not is_running(runner, avd_name) then
      return { ok = false, error = "Emulator failed to start" }
    end
  end

  local wait_module = options.wait_module or wait
  local wait_result = wait_module.wait_for_device(runner, adb_path, options.wait_device)
  if not wait_result.ok then
    return { ok = false, error = "Timed out waiting for adb device", devices = wait_result.devices }
  end

  local serial = select_emulator_serial(before, wait_result.devices)
  if not serial then
    return { ok = false, error = "No adb devices found", devices = wait_result.devices }
  end

  local boot_result = wait_module.wait_for_boot(runner, adb_path, serial, options.wait_boot)
  if not boot_result.ok then
    return { ok = false, error = "Timed out waiting for device boot completion", serial = serial }
  end

  return { ok = true, serial = serial, devices = wait_result.devices }
end

return M
