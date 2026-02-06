local M = {}

local assert = require("tests.helpers.assert")
local stubs_helper = require("tests.helpers.stubs")

local function select_from_list_calls_on_cancel_on_escape()
  local canceled = false
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
      select_default = { replace = function() end },
    },
    ["telescope.actions.state"] = {
      get_selected_entry = function() return { value = "one" } end,
    },
  }

  stubs_helper.with_stubs(stubs, function()
    package.loaded["android.ui.picker"] = nil
    local picker = require("android.ui.picker")
    picker.select_from_list({
      items = { { label = "One", value = "one" } },
      on_select = function() end,
      on_cancel = function() canceled = true end,
    })
  end)

  captured.opts.attach_mappings(1, function(mode, lhs, rhs)
    if mode == "i" and lhs == "<esc>" then
      rhs()
    end
  end)

  assert.eq(canceled, true, "on_cancel called")
end

local function select_from_list_calls_on_cancel_when_selection_nil()
  local canceled = false
  local original_select = vim.ui and vim.ui.select
  local original_preload = package.preload["telescope.pickers"]
  local original_loaded = package.loaded["telescope.pickers"]

  package.preload["telescope.pickers"] = function()
    error("missing telescope.pickers")
  end
  package.loaded["telescope.pickers"] = nil

  vim.ui = vim.ui or {}
  vim.ui.select = function(_, _, cb)
    cb(nil)
  end

  package.loaded["android.ui.picker"] = nil
  local picker = require("android.ui.picker")
  picker.select_from_list({
    items = { { label = "One", value = "one" } },
    on_cancel = function() canceled = true end,
  })

  vim.ui.select = original_select
  package.preload["telescope.pickers"] = original_preload
  package.loaded["telescope.pickers"] = original_loaded

  assert.eq(canceled, true, "on_cancel fallback")
end

local function select_from_list_fallback_filters_by_default_query()
  local captured = { items = nil }
  local original_select = vim.ui and vim.ui.select
  local original_preload = package.preload["telescope.pickers"]
  local original_loaded = package.loaded["telescope.pickers"]

  package.preload["telescope.pickers"] = function()
    error("missing telescope.pickers")
  end
  package.loaded["telescope.pickers"] = nil

  vim.ui = vim.ui or {}
  vim.ui.select = function(items, _, cb)
    captured.items = items
    cb(items[1])
  end

  package.loaded["android.ui.picker"] = nil
  local picker = require("android.ui.picker")
  picker.select_from_list({
    items = {
      { label = "Run current", value = "run_current" },
      { label = "Build default", value = "build_default" },
    },
    default = "run",
  })

  vim.ui.select = original_select
  package.preload["telescope.pickers"] = original_preload
  package.loaded["telescope.pickers"] = original_loaded

  assert.eq(#(captured.items or {}), 1, "filtered count")
  assert.eq(captured.items[1] and captured.items[1].value, "run_current", "filtered value")
end

local function select_from_list_fallback_keeps_items_when_no_query_match()
  local captured = { items = nil }
  local original_select = vim.ui and vim.ui.select
  local original_preload = package.preload["telescope.pickers"]
  local original_loaded = package.loaded["telescope.pickers"]

  package.preload["telescope.pickers"] = function()
    error("missing telescope.pickers")
  end
  package.loaded["telescope.pickers"] = nil

  vim.ui = vim.ui or {}
  vim.ui.select = function(items, _, cb)
    captured.items = items
    cb(items[1])
  end

  package.loaded["android.ui.picker"] = nil
  local picker = require("android.ui.picker")
  picker.select_from_list({
    items = {
      { label = "Run current", value = "run_current" },
      { label = "Build default", value = "build_default" },
    },
    default = "missing",
  })

  vim.ui.select = original_select
  package.preload["telescope.pickers"] = original_preload
  package.loaded["telescope.pickers"] = original_loaded

  assert.eq(#(captured.items or {}), 2, "kept item count")
end

function M.run()
  select_from_list_calls_on_cancel_on_escape()
  select_from_list_calls_on_cancel_when_selection_nil()
  select_from_list_fallback_filters_by_default_query()
  select_from_list_fallback_keeps_items_when_no_query_match()
end

return M
