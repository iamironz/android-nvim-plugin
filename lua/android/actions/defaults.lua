local M = {}

local config = require("android.config")

local function contains(list, value)
  for _, entry in ipairs(list or {}) do
    if entry == value then
      return true
    end
  end
  return false
end

function M.select_module(modules)
  if not modules or #modules == 0 then
    return nil
  end
  local run_config = config.get().run or {}
  local default_module = run_config.default_module
  if default_module and default_module ~= "" and contains(modules, default_module) then
    return default_module
  end
  for _, preferred in ipairs(run_config.module_preference or {}) do
    if contains(modules, preferred) then
      return preferred
    end
  end
  return modules[1]
end

function M.select_variant(variants)
  if not variants or #variants == 0 then
    return nil
  end
  if contains(variants, "debug") then
    return "debug"
  end
  return variants[1]
end

local function is_connected(device)
  return device and device.state == "device"
end

function M.select_device_serial(devices, saved_serial)
  if saved_serial and saved_serial ~= "" then
    for _, device in ipairs(devices or {}) do
      if device.serial == saved_serial and is_connected(device) then
        return saved_serial
      end
    end
  end

  for _, device in ipairs(devices or {}) do
    if is_connected(device) then
      return device.serial
    end
  end
  return nil
end

function M.select_avd_name(avds, saved_name)
  if saved_name and saved_name ~= "" then
    for _, name in ipairs(avds or {}) do
      if name == saved_name then
        return saved_name
      end
    end
  end
  return (avds or {})[1]
end

return M
