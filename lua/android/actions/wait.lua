local M = {}

local adb = require("android.devices.adb")
local strings = require("android.utils.strings")

local function has_connected_device(devices)
  for _, device in ipairs(devices or {}) do
    if device.state == "device" then
      return true
    end
  end
  return false
end

function M.wait_for_device(runner, adb_path, opts)
  if not runner or not adb_path then
    return { ok = false, devices = {} }
  end

  local options = opts or {}
  local timeout = options.timeout or 120000
  local interval = options.interval or 1000
  local last_devices = {}

  local ok = vim.wait(timeout, function()
    last_devices = adb.list(runner, adb_path)
    return has_connected_device(last_devices)
  end, interval)

  return { ok = ok, devices = last_devices }
end

function M.wait_for_boot(runner, adb_path, serial, opts)
  if not runner or not adb_path or not serial or serial == "" then
    return { ok = false, booted = false, value = "" }
  end

  local options = opts or {}
  local timeout = options.timeout or 120000
  local interval = options.interval or 1000
  local wait_fn = options.wait_fn or vim.wait
  local last_value = ""

  local ok = wait_fn(timeout, function()
    local result = runner.run({
      adb_path,
      "-s",
      serial,
      "shell",
      "getprop",
      "sys.boot_completed",
    })
    last_value = strings.trim(result and result.stdout or "")
    return last_value == "1"
  end, interval)

  return { ok = ok, booted = ok, value = last_value }
end

return M
