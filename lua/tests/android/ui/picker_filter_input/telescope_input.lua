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

local function filter_input_updates_prompt_and_results_buffer_names()
  local captured = { opts = nil }
  local name_calls = {}
  local restore_buf_set_name = vim.api.nvim_buf_set_name
  local restore_buf_is_valid = vim.api.nvim_buf_is_valid

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
      get_current_picker = function()
        return { results_bufnr = 22 }
      end,
    },
  }

  local ok, err = pcall(function()
    vim.api.nvim_buf_is_valid = function(buf)
      return buf == 11 or buf == 22
    end
    vim.api.nvim_buf_set_name = function(buf, name)
      name_calls[#name_calls + 1] = string.format("%d|%s", buf, name)
    end

    stubs_helper.with_stubs(stubs, function()
      package.loaded["android.ui.picker"] = nil
      local picker = require("android.ui.picker")
      picker.filter_input({
        prompt_title = "Filter",
        panel_names = function(query)
          return {
            prompt = "android://filters query=" .. query,
            results = "android://filters-results query=" .. query,
          }
        end,
      })
    end)

    if captured.opts and captured.opts.attach_mappings then
      captured.opts.attach_mappings(11, function() end)
    end
    if captured.opts and captured.opts.on_input_filter_cb then
      captured.opts.on_input_filter_cb("warn")
    end
  end)

  vim.api.nvim_buf_set_name = restore_buf_set_name
  vim.api.nvim_buf_is_valid = restore_buf_is_valid

  if not ok then
    error(err)
  end

  assert.eq(name_calls[#name_calls - 1], "11|android://filters query=warn", "prompt name")
  assert.eq(name_calls[#name_calls], "22|android://filters-results query=warn", "results name")
end

local function filter_input_reports_panel_name_builder_errors()
  local captured = { opts = nil }
  local notifications = {}
  local restore_notify = vim.notify

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
      get_current_picker = function()
        return { results_bufnr = 22 }
      end,
    },
  }

  local ok, err = pcall(function()
    vim.notify = function(message, level)
      notifications[#notifications + 1] = { message = message, level = level }
    end

    stubs_helper.with_stubs(stubs, function()
      package.loaded["android.ui.picker"] = nil
      local picker = require("android.ui.picker")
      picker.filter_input({
        prompt_title = "Filter",
        panel_names = function()
          error("builder failed")
        end,
      })
    end)

    if captured.opts and captured.opts.attach_mappings then
      captured.opts.attach_mappings(11, function() end)
    end
    if captured.opts and captured.opts.on_input_filter_cb then
      captured.opts.on_input_filter_cb("warn")
    end
  end)

  vim.notify = restore_notify

  if not ok then
    error(err)
  end

  local notice = notifications[#notifications]
  assert.eq(type(notice), "table", "error notification")
  assert.eq(notice.level, vim.log.levels.WARN, "error notification level")
  assert.contains(notice.message, "Failed to resolve filter panel names", "error message")
end

function M.run()
  filter_input_calls_on_change()
  filter_input_does_not_accept_on_change()
  filter_input_accepts_selection()
  filter_input_updates_prompt_and_results_buffer_names()
  filter_input_reports_panel_name_builder_errors()
end

return M
