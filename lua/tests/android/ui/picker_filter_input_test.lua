local M = {}

local assert = require("tests.helpers.assert")
local stubs_helper = require("tests.helpers.stubs")

local function run_filter_input_without_telescope()
  local flags = { on_change = false, on_accept = false, on_cancel = false }
  local captured = { prompt = nil, default = nil }
  local original_input = vim.ui and vim.ui.input
  local original_preload = package.preload["telescope.pickers"]
  local original_loaded = package.loaded["telescope.pickers"]

  package.preload["telescope.pickers"] = function()
    error("missing telescope.pickers")
  end
  package.loaded["telescope.pickers"] = nil

  vim.ui = vim.ui or {}
  vim.ui.input = function(opts, cb)
    captured.prompt = opts.prompt
    captured.default = opts.default
    cb("typed")
  end

  package.loaded["android.ui.picker"] = nil
  local picker = require("android.ui.picker")
  picker.filter_input({
    items = { "one" },
    prompt_title = "Filter",
    default = "old",
    on_change = function(value) flags.on_change = value end,
    on_accept = function(value) flags.on_accept = value end,
    on_cancel = function() flags.on_cancel = true end,
  })

  vim.ui.input = original_input
  package.preload["telescope.pickers"] = original_preload
  package.loaded["telescope.pickers"] = original_loaded

  return { captured = captured, flags = flags }
end

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

local function filter_input_fallback_sets_prompt()
  local result = run_filter_input_without_telescope()
  assert.eq(result.captured.prompt, "Filter", "input prompt")
end

local function filter_input_fallback_sets_default()
  local result = run_filter_input_without_telescope()
  assert.eq(result.captured.default, "old", "input default")
end

local function filter_input_fallback_calls_on_change()
  local result = run_filter_input_without_telescope()
  assert.eq(result.flags.on_change, "typed", "on_change called")
end

local function filter_input_fallback_calls_on_accept()
  local result = run_filter_input_without_telescope()
  assert.eq(result.flags.on_accept, "typed", "on_accept called")
end

local function filter_input_fallback_does_not_call_on_cancel()
  local result = run_filter_input_without_telescope()
  assert.eq(result.flags.on_cancel, false, "on_cancel not called")
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

local function run_select_from_list_without_telescope()
  local flags = { on_select = nil }
  local captured = { title = nil }
  local original_select = vim.ui and vim.ui.select
  local original_preload = package.preload["telescope.pickers"]
  local original_loaded = package.loaded["telescope.pickers"]

  package.preload["telescope.pickers"] = function()
    error("missing telescope.pickers")
  end
  package.loaded["telescope.pickers"] = nil

  vim.ui = vim.ui or {}
  vim.ui.select = function(items, opts, cb)
    captured.title = opts.prompt
    cb(items[1])
  end

  package.loaded["android.ui.picker"] = nil
  local picker = require("android.ui.picker")
  picker.select_from_list({
    title = "Devices",
    items = { { label = "One", value = "one" } },
    on_select = function(value) flags.on_select = value end,
  })

  vim.ui.select = original_select
  package.preload["telescope.pickers"] = original_preload
  package.loaded["telescope.pickers"] = original_loaded

  return { captured = captured, flags = flags }
end

local function run_select_from_list_empty()
  local notify_args = {}
  local flags = { on_select = false }
  local picker_created = false
  local original_notify = vim.notify

  local stubs = {
    ["telescope.pickers"] = {
      new = function()
        picker_created = true
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
    },
  }

  vim.notify = function(message, level)
    notify_args.message = message
    notify_args.level = level
  end

  stubs_helper.with_stubs(stubs, function()
    package.loaded["android.ui.picker"] = nil
    local picker = require("android.ui.picker")
    picker.select_from_list({
      items = {},
      on_select = function() flags.on_select = true end,
    })
  end)

  vim.notify = original_notify

  return {
    notify_args = notify_args,
    flags = flags,
    picker_created = picker_created,
  }
end

local function select_from_list_fallback_sets_title()
  local result = run_select_from_list_without_telescope()
  assert.eq(result.captured.title, "Devices", "select title")
end

local function select_from_list_fallback_calls_on_select()
  local result = run_select_from_list_without_telescope()
  assert.eq(result.flags.on_select, "one", "on_select called")
end

local function select_from_list_notifies_when_empty()
  local result = run_select_from_list_empty()
  assert.eq(result.notify_args.message, "No entries to select", "notify message")
end

local function select_from_list_warns_when_empty()
  local result = run_select_from_list_empty()
  assert.eq(result.notify_args.level, vim.log.levels.WARN, "notify level")
end

local function select_from_list_does_not_select_when_empty()
  local result = run_select_from_list_empty()
  assert.eq(result.flags.on_select, false, "on_select not called")
end

local function select_from_list_does_not_create_picker_when_empty()
  local result = run_select_from_list_empty()
  assert.eq(result.picker_created, false, "picker not created")
end

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

function M.run()
  filter_input_fallback_sets_prompt()
  filter_input_fallback_sets_default()
  filter_input_fallback_calls_on_change()
  filter_input_fallback_calls_on_accept()
  filter_input_fallback_does_not_call_on_cancel()
  filter_input_calls_on_change()
  filter_input_does_not_accept_on_change()
  filter_input_accepts_selection()
  select_from_list_fallback_sets_title()
  select_from_list_fallback_calls_on_select()
  select_from_list_notifies_when_empty()
  select_from_list_warns_when_empty()
  select_from_list_does_not_select_when_empty()
  select_from_list_does_not_create_picker_when_empty()
  select_from_list_calls_on_cancel_on_escape()
  select_from_list_calls_on_cancel_when_selection_nil()
end

return M
