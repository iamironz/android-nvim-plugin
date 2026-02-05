local M = {}

local assert = require("tests.helpers.assert")
local stubs_helper = require("tests.helpers.stubs")

local function with_devices_stubs(stubs, fn)
  stubs_helper.with_stubs(stubs, function()
    package.loaded["android.actions.devices"] = nil
    fn(require("android.actions.devices"))
  end)
end

local function build_context_stubs()
  return {
    workspace = function()
      return { root = "/workspace" }
    end,
    load_state = function()
      return {}
    end,
    save_state = function()
      return true
    end,
  }
end

local function build_discovery_stubs(tools, packages)
  return {
    new = function()
      return {
        tools = function()
          return tools
        end,
        packages = function()
          return packages or {}
        end,
      }
    end,
  }
end

local function build_runner_stubs()
  return {
    new = function()
      return {
        run = function()
          return { ok = true, stdout = "", stderr = "" }
        end,
      }
    end,
  }
end

local function with_input_value(value, fn)
  local original_input = vim.fn.input
  vim.fn.input = function()
    return value
  end

  local ok, err = pcall(fn)

  vim.fn.input = original_input

  if not ok then
    error(err, 0)
  end
end

local function select_device_forwards_on_cancel()
  local canceled = false
  local captured = nil

  local stubs = {
    ["android.actions.context"] = build_context_stubs(),
    ["android.sdk.discovery"] = build_discovery_stubs({ adb = "/sdk/adb" }),
    ["android.command.runner"] = build_runner_stubs(),
    ["android.devices.adb"] = {
      list = function()
        return { { serial = "device-1", state = "device" } }
      end,
    },
    ["android.ui.picker"] = {
      select_from_list = function(opts)
        captured = opts
        if opts.on_cancel then
          opts.on_cancel()
        end
      end,
    },
  }

  with_devices_stubs(stubs, function(devices)
    devices.select_device({
      on_cancel = function()
        canceled = true
      end,
    })

    assert.is_true(captured ~= nil, "picker called")
    assert.eq(type(captured.on_cancel), "function", "on_cancel forwarded")
    assert.eq(canceled, true, "on_cancel called")
  end)
end

local function create_avd_system_image_cancel_reopens_device_profiles()
  local picker_titles = {}

  local stubs = {
    ["android.actions.context"] = build_context_stubs(),
    ["android.sdk.discovery"] = build_discovery_stubs({ avdmanager = "/sdk/avdmanager" }, {
      "system-images;android-34;google_apis;x86_64",
    }),
    ["android.command.runner"] = build_runner_stubs(),
    ["android.devices.avd"] = {
      list_devices = function()
        return { { id = "pixel", name = "Pixel", oem = "Google" } }
      end,
    },
    ["android.sdk.packages"] = {
      list_system_images = function()
        return { "system-images;android-34;google_apis;x86_64" }
      end,
    },
    ["android.ui.picker"] = {
      select_from_list = function(opts)
        table.insert(picker_titles, opts.title)
        if #picker_titles == 1 then
          opts.on_select("pixel")
          return
        end
        if #picker_titles == 2 and opts.on_cancel then
          opts.on_cancel()
        end
      end,
    },
  }

  with_input_value("TestAvd", function()
    with_devices_stubs(stubs, function(devices)
      devices.create_avd()

      assert.eq(picker_titles[1], "AVD device profiles", "profiles picker first")
      assert.eq(picker_titles[2], "System images", "system images picker second")
      assert.eq(picker_titles[3], "AVD device profiles", "profiles picker reopened")
    end)
  end)
end

function M.run()
  select_device_forwards_on_cancel()
  create_avd_system_image_cancel_reopens_device_profiles()
end

return M
