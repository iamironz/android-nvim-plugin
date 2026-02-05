local M = {}

local assert = require("tests.helpers.assert")
local stubs_helper = require("tests.helpers.stubs")

local function summary_lines_for(stubs)
  local lines = nil
  stubs_helper.with_stubs(stubs, function()
    package.loaded["android.ui.summary"] = nil
    local summary = require("android.ui.summary")
    lines = summary.lines({ include_adb = false })
  end)
  return lines
end

local function build_selection_defaults()
  return {
    build_defaults = function(state)
      return { module = state.build.module, variant = state.build.variant }
    end,
    device_defaults = function(state)
      local device = state.device or {}
      return { serial = device.serial }
    end,
    avd_defaults = function(state)
      local avd = state.avd or {}
      return { name = avd.name }
    end,
  }
end

local function build_summary_stubs(opts)
  return {
    ["android.actions.context"] = {
      workspace = function()
        return opts.workspace
      end,
      load_state = function()
        return opts.state
      end,
    },
    ["android.state.selection_defaults"] = build_selection_defaults(),
    ["android.run.registry"] = {
      resolve = function()
        return opts.run
      end,
    },
    ["android.command.runner"] = {
      new = function()
        return {}
      end,
    },
    ["android.sdk.discovery"] = {
      new = function()
        return {
          tools = function()
            return { adb = opts.adb }
          end,
        }
      end,
    },
    ["android.devices.adb"] = {
      list = function()
        return opts.devices or {}
      end,
      parse_devices = function()
        return {}
      end,
    },
  }
end

local function summary_lines_with(opts)
  return summary_lines_for(build_summary_stubs(opts))
end

local function summary_text_with(opts)
  local lines = summary_lines_with(opts)
  return table.concat(lines, "|")
end

local function base_workspace()
  return { root = "/workspace", modules = { ":app" } }
end

local function full_workspace()
  return {
    root = "/workspace",
    modules = { ":app" },
    android = { root = "/workspace", modules = { ":app" } },
    kmp = { root = "/workspace" },
    ios = { root = "/workspace/ios" },
  }
end

local function full_state()
  return {
    build = { module = ":app", variant = "debug" },
    device = { serial = "device-1" },
    avd = { name = "Pixel_5" },
    logcat = { package = "com.example" },
  }
end

local function run_meta_opts()
  return {
    workspace = base_workspace(),
    state = { build = { module = ":app", variant = "debug" } },
    run = { label = "Server", type = "jvm", meta = { task = ":server:run" } },
    adb = nil,
    devices = {},
  }
end

local function summary_lines_include_state()
  local lines = summary_lines_with({
    workspace = full_workspace(),
    state = full_state(),
    run = { label = "Android" },
    adb = "/sdk/adb",
    devices = { { serial = "emulator-5554", state = "device" } },
  })
  local expected = {
    "Summary",
    "",
    "Workspace",
    "  Root: /workspace",
    "  Targets: android, kmp, ios",
    "",
    "Run",
    "  Run: Android",
    "",
    "Build",
    "  Module: :app",
    "  Variant: debug",
    "",
    "Devices",
    "  Device: device-1",
    "  Devices: none",
    "  AVD: Pixel_5",
    "",
    "Logcat",
    "  Logcat: com.example",
  }
  assert.table_eq(lines, expected, "summary lines")
end

local function summary_includes_run_task()
  local text = summary_text_with(run_meta_opts())
  assert.contains(text, "Run Task: :server:run", "run meta task")
end

local function summary_includes_devices_none()
  local text = summary_text_with(run_meta_opts())
  assert.contains(text, "Devices: none", "devices none")
end

local function summary_lines_workspace_missing_sectioned()
  local lines = summary_lines_with({
    workspace = nil,
    state = nil,
    run = nil,
    adb = nil,
    devices = {},
  })
  local expected = { "Summary", "", "Workspace", "  Root: not found" }
  assert.table_eq(lines, expected, "summary fallback lines")
end

function M.run()
  summary_lines_include_state()
  summary_includes_run_task()
  summary_includes_devices_none()
  summary_lines_workspace_missing_sectioned()
end

return M
