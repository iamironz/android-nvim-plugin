local M = {}

local assert = require("tests.helpers.assert")
local stubs_helper = require("tests.helpers.stubs")

local function run_filter_input_with_on_change()
  local change_values = {}
  local accepted = nil
  local captured = { opts = nil }

  local stubs = {
    ["telescope.pickers"] = {
      new = function(_, opts)
        captured.opts = opts
        return { find = function() end }
      end,
    },
    ["telescope.finders"] = { new_table = function() return {} end },
    ["telescope.config"] = { values = { generic_sorter = function() return {} end } },
    ["telescope.themes"] = { get_dropdown = function() return {} end },
    ["telescope.actions"] = {
      close = function() end,
      select_default = {
        replace = function() end,
      },
    },
    ["telescope.actions.state"] = {
      get_selected_entry = function() return nil end,
      get_current_line = function() return "typed" end,
    },
  }

  stubs_helper.with_stubs(stubs, function()
    package.loaded["android.ui.picker"] = nil
    local picker = require("android.ui.picker")
    picker.filter_input({
      items = { "one" },
      prompt_title = "Filter",
      default = "",
      on_change = function(value)
        table.insert(change_values, value)
      end,
      on_accept = function(value) accepted = value end,
    })
  end)

  return {
    change_values = change_values,
    accepted = accepted,
    on_input = captured.opts and captured.opts.on_input_filter_cb,
  }
end

local function filter_input_calls_on_change()
  local result = run_filter_input_with_on_change()
  if result.on_input then
    result.on_input("live")
  end
  assert.eq(result.change_values[1], "live", "on_change value")
end

local function filter_input_does_not_accept_on_change()
  local result = run_filter_input_with_on_change()
  if result.on_input then
    result.on_input("live")
  end
  assert.eq(result.accepted, nil, "on_accept not called")
end

local function filter_input_accepts_selection()
  local accepted = nil
  local captured = { select_fn = nil }

  local stubs = {
    ["telescope.pickers"] = {
      new = function(_, opts)
        captured.opts = opts
        return { find = function() end }
      end,
    },
    ["telescope.finders"] = { new_table = function() return {} end },
    ["telescope.config"] = { values = { generic_sorter = function() return {} end } },
    ["telescope.themes"] = { get_dropdown = function() return {} end },
    ["telescope.actions"] = {
      close = function() end,
      select_default = {
        replace = function(_, fn) captured.select_fn = fn end,
      },
    },
    ["telescope.actions.state"] = {
      get_selected_entry = function()
        return { value = "from-history" }
      end,
      get_current_line = function() return "typed" end,
    },
  }

  stubs_helper.with_stubs(stubs, function()
    package.loaded["android.ui.picker"] = nil
    local picker = require("android.ui.picker")
    picker.filter_input({
      items = { "one" },
      prompt_title = "Filter",
      default = "",
      on_accept = function(value)
        accepted = value
      end,
    })
  end)

  if captured.select_fn then
    captured.select_fn(1)
  end

  assert.eq(accepted, "from-history", "accepted value")
end

function M.run()
  filter_input_calls_on_change()
  filter_input_does_not_accept_on_change()
  filter_input_accepts_selection()
end

return M
