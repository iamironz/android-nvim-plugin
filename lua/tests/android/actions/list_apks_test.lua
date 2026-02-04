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
    local build = require("android.actions.build")
    build.list_apks()

    assert.is_true(captured ~= nil, "picker called")
    assert.eq(#captured.items, 1, "picker items")
    assert.eq(type(captured.file_ignore_patterns), "table", "ignore type")
    assert.eq(#captured.file_ignore_patterns, 0, "ignore empty")
  end)
end

function M.run()
  passes_ignore_patterns_override()
end

return M
