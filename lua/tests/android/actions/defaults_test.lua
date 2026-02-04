local M = {}

local assert = require("tests.helpers.assert")
local config = require("android.config")
local defaults = require("android.actions.defaults")

local function reset_config()
  config.reset()
end

local function selects_preferred_android_app_module()
  reset_config()
  local module = defaults.select_module({ ":lib", ":androidApp", ":app" })
  assert.eq(module, ":androidApp", "prefer androidApp")
end

local function selects_app_module_when_android_app_missing()
  reset_config()
  local module = defaults.select_module({ ":lib", ":app" })
  assert.eq(module, ":app", "prefer app")
end

local function selects_first_module_when_no_preferred()
  reset_config()
  local module = defaults.select_module({ ":lib", ":feature" })
  assert.eq(module, ":lib", "fallback module")
end

local function selects_configured_default_module()
  reset_config()
  config.setup({
    run = {
      default_module = ":custom",
    },
  })
  local module = defaults.select_module({ ":app", ":custom" })
  assert.eq(module, ":custom", "configured default module")
end

local function selects_module_preference_from_config()
  reset_config()
  config.setup({
    run = {
      module_preference = { ":lib", ":app" },
    },
  })
  local module = defaults.select_module({ ":app", ":lib" })
  assert.eq(module, ":lib", "configured module preference")
end

local function selects_debug_variant_when_available()
  reset_config()
  local variant = defaults.select_variant({ "release", "debug" })
  assert.eq(variant, "debug", "prefer debug")
end

local function selects_first_variant_when_no_debug()
  reset_config()
  local variant = defaults.select_variant({ "release", "staging" })
  assert.eq(variant, "release", "fallback variant")
end

local function selects_saved_device_when_connected()
  reset_config()
  local devices = {
    { serial = "abc", state = "device" },
    { serial = "def", state = "offline" },
  }
  local serial = defaults.select_device_serial(devices, "abc")
  assert.eq(serial, "abc", "saved device")
end

local function selects_first_connected_device_when_saved_missing()
  reset_config()
  local devices = {
    { serial = "abc", state = "offline" },
    { serial = "def", state = "device" },
  }
  local serial = defaults.select_device_serial(devices, "missing")
  assert.eq(serial, "def", "first connected")
end

local function returns_nil_when_no_connected_device()
  reset_config()
  local devices = {
    { serial = "abc", state = "offline" },
  }
  local serial = defaults.select_device_serial(devices, "abc")
  assert.eq(serial, nil, "no connected")
end

local function selects_saved_avd_when_present()
  reset_config()
  local avd = defaults.select_avd_name({ "Pixel", "Wear" }, "Wear")
  assert.eq(avd, "Wear", "saved avd")
end

local function selects_first_avd_when_saved_missing()
  reset_config()
  local avd = defaults.select_avd_name({ "Pixel", "Wear" }, "Missing")
  assert.eq(avd, "Pixel", "first avd")
end

local function returns_nil_when_no_avds()
  reset_config()
  local avd = defaults.select_avd_name({}, "Missing")
  assert.eq(avd, nil, "no avds")
end

function M.run()
  selects_preferred_android_app_module()
  selects_app_module_when_android_app_missing()
  selects_first_module_when_no_preferred()
  selects_configured_default_module()
  selects_module_preference_from_config()
  selects_debug_variant_when_available()
  selects_first_variant_when_no_debug()
  selects_saved_device_when_connected()
  selects_first_connected_device_when_saved_missing()
  returns_nil_when_no_connected_device()
  selects_saved_avd_when_present()
  selects_first_avd_when_saved_missing()
  returns_nil_when_no_avds()
end

return M
