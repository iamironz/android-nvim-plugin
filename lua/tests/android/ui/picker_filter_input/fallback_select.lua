local M = {}

local assert = require("tests.helpers.assert")
local stubs_helper = require("tests.helpers.stubs")

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
  assert.eq(result.notify_args.message, "No entries to select for Select", "notify message")
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

function M.run()
  select_from_list_fallback_sets_title()
  select_from_list_fallback_calls_on_select()
  select_from_list_notifies_when_empty()
  select_from_list_warns_when_empty()
  select_from_list_does_not_select_when_empty()
  select_from_list_does_not_create_picker_when_empty()
end

return M
