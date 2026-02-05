local M = {}

local assert = require("tests.helpers.assert")
local stubs_helper = require("tests.helpers.stubs")
local registry_helper = require("tests.helpers.run_registry")

local function select_returns_selected_id()
  local picker_opts = nil
  local selected = nil
  local stubs = {
    ["android.actions.context"] = {
      workspace = function()
        return registry_helper.build_workspace()
      end,
    },
    ["android.run.registry"] = {
      list = function()
        return {
          { id = "android", label = "Android" },
          { id = "ios", label = "iOS" },
        }
      end,
      select = function(_, config_id)
        selected = config_id
        return config_id
      end,
    },
    ["android.ui.picker"] = {
      select_from_list = function(opts)
        picker_opts = opts
        if opts.on_select then
          opts.on_select("ios")
        end
      end,
    },
  }

  stubs_helper.with_stubs(stubs, function()
    package.loaded["android.run.ui"] = nil
    local ui = require("android.run.ui")
    local result = ui.select()
    assert.eq(result, "ios", "run select return")
  end)

  local title = picker_opts.title
  local label = picker_opts.items[1].label
  assert.eq(title, "Run Config", "run picker title")
  assert.eq(label, "Android", "run picker label")
  assert.eq(selected, "ios", "run picker selected")
end

local function select_passes_on_cancel()
  local canceled = false
  local stubs = {
    ["android.actions.context"] = {
      workspace = function()
        return registry_helper.build_workspace()
      end,
    },
    ["android.run.registry"] = {
      list = function()
        return { { id = "android", label = "Android" } }
      end,
      select = function()
        return "android"
      end,
    },
    ["android.ui.picker"] = {
      select_from_list = function(opts)
        if opts.on_cancel then
          opts.on_cancel()
        end
      end,
    },
  }

  stubs_helper.with_stubs(stubs, function()
    package.loaded["android.run.ui"] = nil
    local ui = require("android.run.ui")
    ui.select({ on_cancel = function() canceled = true end })
  end)

  assert.eq(canceled, true, "run select cancel")
end

function M.run()
  select_returns_selected_id()
  select_passes_on_cancel()
end

return M
