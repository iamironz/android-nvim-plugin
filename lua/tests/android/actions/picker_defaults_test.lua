local M = {}

local assert = require("tests.helpers.assert")
local stubs_helper = require("tests.helpers.stubs")

local function build_select_module_passes_default()
  local last_opts = nil
  local state = { build = { module = ":app", variant = "debug" } }

  local stubs = {
    ["android.actions.context"] = {
      workspace = function()
        return { root = "/workspace", modules = { ":app", ":lib" } }
      end,
      load_state = function()
        return state
      end,
      save_state = function(_, next_state)
        state = next_state
        return true
      end,
    },
    ["android.ui.picker"] = {
      select_from_list = function(opts)
        last_opts = opts
      end,
    },
  }

  stubs_helper.with_stubs(stubs, function()
    package.loaded["android.actions.build"] = nil
    local build = require("android.actions.build")
    build.select_module()

    assert.is_true(last_opts ~= nil, "picker called")
    assert.eq(last_opts.title, "Gradle modules", "module picker title")
    assert.eq(last_opts.default, ":app", "module picker default")
  end)
end

local function build_select_variant_passes_default()
  local last_opts = nil
  local state = { build = { module = ":app", variant = "release" } }

  local stubs = {
    ["android.actions.context"] = {
      workspace = function()
        return { root = "/workspace", modules = { ":app" } }
      end,
      load_state = function()
        return state
      end,
      save_state = function(_, next_state)
        state = next_state
        return true
      end,
    },
    ["android.actions.build_helpers"] = {
      fetch_variants = function()
        return { "debug", "release" }
      end,
    },
    ["android.command.runner"] = {
      new = function()
        return {}
      end,
    },
    ["android.ui.picker"] = {
      select_from_list = function(opts)
        last_opts = opts
      end,
    },
  }

  stubs_helper.with_stubs(stubs, function()
    package.loaded["android.actions.build"] = nil
    local build = require("android.actions.build")
    build.select_variant()

    assert.is_true(last_opts ~= nil, "picker called")
    assert.eq(last_opts.title, "Build variants", "variant picker title")
    assert.eq(last_opts.default, "release", "variant picker default")
  end)
end

local function devices_select_device_passes_default_label()
  local last_opts = nil
  local state = { device = { serial = "device-1" } }

  local stubs = {
    ["android.actions.context"] = {
      workspace = function()
        return { root = "/workspace", modules = {} }
      end,
      load_state = function()
        return state
      end,
      save_state = function(_, next_state)
        state = next_state
        return true
      end,
    },
    ["android.sdk.discovery"] = {
      new = function()
        return {
          tools = function()
            return { adb = "/bin/adb" }
          end,
        }
      end,
    },
    ["android.command.runner"] = {
      new = function()
        return {}
      end,
    },
    ["android.devices.adb"] = {
      list = function()
        return {
          { serial = "device-1", state = "device" },
          { serial = "device-2", state = "offline" },
        }
      end,
    },
    ["android.ui.picker"] = {
      select_from_list = function(opts)
        last_opts = opts
      end,
    },
  }

  stubs_helper.with_stubs(stubs, function()
    package.loaded["android.actions.devices"] = nil
    local devices = require("android.actions.devices")
    devices.select_device()

    assert.is_true(last_opts ~= nil, "picker called")
    assert.eq(last_opts.title, "Devices", "device picker title")
    assert.eq(last_opts.default, "device-1 (device)", "device picker default")
  end)
end

local function devices_select_avd_passes_default()
  local last_opts = nil
  local state = { avd = { name = "CI_UI_test" } }

  local stubs = {
    ["android.actions.context"] = {
      workspace = function()
        return { root = "/workspace", modules = {} }
      end,
      load_state = function()
        return state
      end,
      save_state = function(_, next_state)
        state = next_state
        return true
      end,
    },
    ["android.sdk.discovery"] = {
      new = function()
        return {
          tools = function()
            return { emulator = "/bin/emulator" }
          end,
        }
      end,
    },
    ["android.command.runner"] = {
      new = function()
        return {}
      end,
    },
    ["android.devices.emulator"] = {
      list = function()
        return { "CI_UI_test", "OtherAVD" }
      end,
    },
    ["android.ui.picker"] = {
      select_from_list = function(opts)
        last_opts = opts
      end,
    },
  }

  stubs_helper.with_stubs(stubs, function()
    package.loaded["android.actions.devices"] = nil
    local devices = require("android.actions.devices")
    devices.select_avd()

    assert.is_true(last_opts ~= nil, "picker called")
    assert.eq(last_opts.title, "Emulator AVDs", "avd picker title")
    assert.eq(last_opts.default, "CI_UI_test", "avd picker default")
  end)
end

function M.run()
  build_select_module_passes_default()
  build_select_variant_passes_default()
  devices_select_device_passes_default_label()
  devices_select_avd_passes_default()
end

return M
