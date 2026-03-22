local M = {}

local assert = require("tests.helpers.assert")
local stubs_helper = require("tests.helpers.stubs")

local function passes_ignore_patterns_override()
  local captured = nil

  local stubs = {
    ["android.actions.context"] = {
      workspace = function()
        return { root = "/workspace", modules = { ":app" } }
      end,
      load_state = function()
        return { build = { module = ":app", variant = "debug" } }
      end,
      save_state = function()
        return true
      end,
    },
    ["android.ui.picker"] = {
      select_from_list = function(opts)
        captured = opts
      end,
    },
    ["android.build.apk"] = {
      list_apk_paths = function()
        return {
          ok = true,
          apks = { "/workspace/app/build/outputs/apk/debug/app-debug.apk" },
        }
      end,
      list_workspace_apks = function()
        return { ok = false, error = "no apks" }
      end,
    },
  }

  stubs_helper.with_stubs(stubs, function()
    package.loaded["android.actions.build"] = nil
    package.loaded["android.actions.build_selection"] = nil
    local build = require("android.actions.build")
    build.list_apks()

    assert.is_true(captured ~= nil, "picker called")
    assert.eq(#captured.items, 1, "picker items")
    assert.eq(type(captured.file_ignore_patterns), "table", "ignore type")
    assert.eq(#captured.file_ignore_patterns, 0, "ignore empty")
  end)
end

local function list_apks_calls_on_cancel_when_picker_cancels()
  local canceled = false
  local captured = nil

  local stubs = {
    ["android.actions.context"] = {
      workspace = function()
        return { root = "/workspace", modules = { ":app" } }
      end,
      load_state = function()
        return { build = { module = ":app", variant = "debug" } }
      end,
      save_state = function()
        return true
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
    ["android.build.apk"] = {
      list_apk_paths = function()
        return {
          ok = true,
          apks = { "/workspace/app/build/outputs/apk/debug/app-debug.apk" },
        }
      end,
      list_workspace_apks = function()
        return { ok = false, error = "no apks" }
      end,
    },
  }

  stubs_helper.with_stubs(stubs, function()
    package.loaded["android.actions.build"] = nil
    package.loaded["android.actions.build_selection"] = nil
    local build = require("android.actions.build")
    build.list_apks({
      on_cancel = function()
        canceled = true
      end,
    })

    assert.is_true(captured ~= nil, "picker called")
    assert.eq(type(captured.on_cancel), "function", "on_cancel forwarded")
    assert.eq(canceled, true, "on_cancel called")
  end)
end

local function forwards_file_ignore_patterns_override()
  local captured = nil
  local ignore_patterns = { "**/node_modules/**", "**/build/**" }

  local stubs = {
    ["android.actions.context"] = {
      workspace = function()
        return { root = "/workspace", modules = { ":app" } }
      end,
      load_state = function()
        return { build = { module = ":app", variant = "debug" } }
      end,
      save_state = function()
        return true
      end,
    },
    ["android.ui.picker"] = {
      select_from_list = function(opts)
        captured = opts
      end,
    },
    ["android.build.apk"] = {
      list_apk_paths = function()
        return {
          ok = true,
          apks = { "/workspace/app/build/outputs/apk/debug/app-debug.apk" },
        }
      end,
      list_workspace_apks = function()
        return { ok = false, error = "no apks" }
      end,
    },
  }

  stubs_helper.with_stubs(stubs, function()
    package.loaded["android.actions.build"] = nil
    package.loaded["android.actions.build_selection"] = nil
    local build = require("android.actions.build")
    build.list_apks({ file_ignore_patterns = ignore_patterns })

    assert.is_true(captured ~= nil, "picker called")
    assert.eq(captured.file_ignore_patterns, ignore_patterns, "ignore forwarded")
  end)
end

function M.run()
  passes_ignore_patterns_override()
  list_apks_calls_on_cancel_when_picker_cancels()
  forwards_file_ignore_patterns_override()
end

return M
