local M = {}

local assert = require("tests.helpers.assert")

local function build_lines_include_summary_and_blocks()
  package.loaded["android.ui.hub"] = nil
  local hub = require("android.ui.hub")
  local lines = hub._build_lines({ "Summary", "Workspace: /app" }, {
    { title = "Build Variants", desc = "Builds and variants", items = { 1, 2 } },
    { title = "Device Manager", desc = "Devices and emulators", items = {} },
  })

  local text = table.concat(lines, "|")
  local expected = table.concat({
    "Summary",
    "Workspace: /app",
    "",
    "Sections (select with <CR> or [1-2])",
    "  j/k or arrows move | <CR>/<Right> open | / search | Esc/<Left> back | q close",
    "",
    "[1] Build Variants (2) | Builds and variants",
    "[2] Device Manager | Devices and emulators",
  }, "|")
  assert.eq(text, expected, "hub lines")
end

local function search_keys_include_letters_without_navigation()
  package.loaded["android.ui.hub"] = nil
  local hub = require("android.ui.hub")
  local keys = hub._search_keys()
  assert.table_eq(
    keys,
    {
      "a",
      "b",
      "c",
      "d",
      "e",
      "f",
      "g",
      "h",
      "i",
      "l",
      "m",
      "n",
      "o",
      "p",
      "r",
      "s",
      "t",
      "u",
      "v",
      "w",
      "x",
      "y",
      "z",
    },
    "search keys"
  )
end

local function hub_calls_on_cancel_on_escape()
  local called = false
  local captured = { esc = nil }
  local original_keymap_set = vim.keymap.set

  vim.keymap.set = function(_, lhs, rhs)
    if lhs == "<Esc>" then
      captured.esc = rhs
    end
  end

  package.loaded["android.ui.hub"] = nil
  local hub = require("android.ui.hub")
  hub.open({
    blocks = { { title = "Build Variants", desc = "Builds and variants", items = { 1 } } },
    on_cancel = function()
      called = true
    end,
  })

  if captured.esc then
    captured.esc()
  end

  vim.keymap.set = original_keymap_set

  assert.eq(called, true, "on_cancel called")
end

local function hub_calls_on_close_with_cancel_reason()
  local reason = nil
  local captured = { esc = nil }
  local original_keymap_set = vim.keymap.set

  vim.keymap.set = function(_, lhs, rhs)
    if lhs == "<Esc>" then
      captured.esc = rhs
    end
  end

  package.loaded["android.ui.hub"] = nil
  local hub = require("android.ui.hub")
  hub.open({
    blocks = { { title = "Build Variants", desc = "Builds", items = { 1 } } },
    on_close = function(value)
      reason = value
    end,
  })

  if captured.esc then
    captured.esc()
  end

  vim.keymap.set = original_keymap_set

  assert.eq(reason, "cancel", "on_close reason")
end

local function initial_line_uses_block_index()
  package.loaded["android.ui.hub"] = nil
  local hub = require("android.ui.hub")
  local line = hub._initial_line({ "Summary", "" }, 3, 2)
  assert.eq(line, 8, "initial line")
end

local function hub_select_uses_updated_summary_lines()
  local selected = nil
  local captured = {}
  local blocks = {
    { title = "Run", desc = "Runs", items = { 1 } },
    { title = "ADB", desc = "Android Debug Bridge", items = { 1 } },
  }
  local original_keymap_set = vim.keymap.set
  local original_cursor = vim.api.nvim_win_get_cursor

  vim.keymap.set = function(_, lhs, rhs)
    if lhs == "<CR>" then
      captured.enter = rhs
    end
  end
  vim.api.nvim_win_get_cursor = function()
    return { 7, 0 }
  end

  local ok, err = pcall(function()
    package.loaded["android.ui.hub"] = nil
    local hub = require("android.ui.hub")
    local handle = hub.open({
      summary_lines = { "Summary" },
      blocks = blocks,
      on_select = function(block)
        selected = block and block.title or nil
      end,
    })
    hub.update(handle, { summary_lines = { "Summary", "Menu Data" }, blocks = blocks })
    if captured.enter then
      captured.enter()
    end
  end)

  vim.keymap.set = original_keymap_set
  vim.api.nvim_win_get_cursor = original_cursor

  if not ok then
    error(err)
  end

  assert.eq(selected, "Run", "select uses updated summary")
end

local function hub_search_uses_updated_summary_lines()
  local searched_index = nil
  local captured = {}
  local blocks = {
    { title = "Run", desc = "Runs", items = { 1 } },
    { title = "ADB", desc = "Android Debug Bridge", items = { 1 } },
  }
  local original_keymap_set = vim.keymap.set
  local original_cursor = vim.api.nvim_win_get_cursor

  vim.keymap.set = function(_, lhs, rhs)
    if lhs == "r" then
      captured.search = rhs
    end
  end
  vim.api.nvim_win_get_cursor = function()
    return { 7, 0 }
  end

  local ok, err = pcall(function()
    package.loaded["android.ui.hub"] = nil
    local hub = require("android.ui.hub")
    local handle = hub.open({
      summary_lines = { "Summary" },
      blocks = blocks,
      on_search = function(_, index)
        searched_index = index
      end,
    })
    hub.update(handle, { summary_lines = { "Summary", "Menu Data" }, blocks = blocks })
    if captured.search then
      captured.search()
    end
  end)

  vim.keymap.set = original_keymap_set
  vim.api.nvim_win_get_cursor = original_cursor

  if not ok then
    error(err)
  end

  assert.eq(searched_index, 1, "search uses updated summary")
end

local function hub_enter_on_summary_line_does_not_close()
  local selected = false
  local reason = nil
  local captured = {}
  local original_keymap_set = vim.keymap.set
  local original_cursor = vim.api.nvim_win_get_cursor
  local original_set_cursor = vim.api.nvim_win_set_cursor
  local cursor_set_calls = {}

  vim.keymap.set = function(_, lhs, rhs)
    if lhs == "<CR>" then
      captured.enter = rhs
    end
  end
  vim.api.nvim_win_get_cursor = function()
    return { 1, 0 }
  end
  vim.api.nvim_win_set_cursor = function(_, pos)
    table.insert(cursor_set_calls, { pos[1], pos[2] })
  end

  local ok, err = pcall(function()
    package.loaded["android.ui.hub"] = nil
    local hub = require("android.ui.hub")
    local handle = hub.open({
      summary_lines = { "Summary" },
      blocks = {
        { title = "Run", desc = "Runs", items = { 1 } },
      },
      on_select = function()
        selected = true
      end,
      on_close = function(value)
        reason = value
      end,
    })
    if captured.enter then
      captured.enter()
    end
    if handle and handle.close then
      handle.close()
    end
  end)

  vim.keymap.set = original_keymap_set
  vim.api.nvim_win_get_cursor = original_cursor
  vim.api.nvim_win_set_cursor = original_set_cursor

  if not ok then
    error(err)
  end

  assert.eq(selected, false, "summary line not selectable")
  assert.eq(reason, nil, "summary line does not close")
  local last = cursor_set_calls[#cursor_set_calls] or {}
  assert.eq(last[1], 6, "summary enter moves to first section")
end

local function hub_number_shortcut_selects_block()
  local selected = nil
  local captured = {}
  local original_keymap_set = vim.keymap.set

  vim.keymap.set = function(_, lhs, rhs)
    captured[lhs] = rhs
  end

  local ok, err = pcall(function()
    package.loaded["android.ui.hub"] = nil
    local hub = require("android.ui.hub")
    hub.open({
      blocks = {
        { title = "Run", items = { 1 } },
        { title = "ADB", items = { 1 } },
      },
      on_select = function(block)
        selected = block and block.title or nil
      end,
    })
    if captured["2"] then
      captured["2"]()
    end
  end)

  vim.keymap.set = original_keymap_set

  if not ok then
    error(err)
  end

  assert.eq(selected, "ADB", "number shortcut select")
end

local function hub_slash_opens_search_without_default_text()
  local search_char = nil
  local search_index = nil
  local captured = {}
  local original_keymap_set = vim.keymap.set
  local original_cursor = vim.api.nvim_win_get_cursor

  vim.keymap.set = function(_, lhs, rhs)
    captured[lhs] = rhs
  end
  vim.api.nvim_win_get_cursor = function()
    return { 4, 0 }
  end

  local ok, err = pcall(function()
    package.loaded["android.ui.hub"] = nil
    local hub = require("android.ui.hub")
    hub.open({
      blocks = {
        { title = "Run", items = { 1 } },
        { title = "ADB", items = { 1 } },
      },
      on_search = function(char, index)
        search_char = char
        search_index = index
      end,
    })
    if captured["/"] then
      captured["/"]()
    end
  end)

  vim.keymap.set = original_keymap_set
  vim.api.nvim_win_get_cursor = original_cursor

  if not ok then
    error(err)
  end

  assert.eq(search_char, "", "slash search query")
  assert.eq(search_index, 1, "slash search index")
end

local function hub_q_key_keeps_close_behavior_when_search_enabled()
  local reason = nil
  local captured = {}
  local original_keymap_set = vim.keymap.set

  vim.keymap.set = function(_, lhs, rhs)
    captured[lhs] = rhs
  end

  local ok, err = pcall(function()
    package.loaded["android.ui.hub"] = nil
    local hub = require("android.ui.hub")
    hub.open({
      blocks = {
        { title = "Run", items = { 1 } },
      },
      on_search = function() end,
      on_close = function(value)
        reason = value
      end,
    })
    if captured.q then
      captured.q()
    end
  end)

  vim.keymap.set = original_keymap_set

  if not ok then
    error(err)
  end

  assert.eq(reason, "close", "q closes hub")
end

local function hub_right_key_opens_selection()
  local selected = nil
  local captured = {}
  local original_keymap_set = vim.keymap.set
  local original_cursor = vim.api.nvim_win_get_cursor

  vim.keymap.set = function(_, lhs, rhs)
    captured[lhs] = rhs
  end
  vim.api.nvim_win_get_cursor = function()
    return { 4, 0 }
  end

  local ok, err = pcall(function()
    package.loaded["android.ui.hub"] = nil
    local hub = require("android.ui.hub")
    hub.open({
      blocks = {
        { title = "Run", items = { 1 } },
      },
      on_select = function(block)
        selected = block and block.title or nil
      end,
    })
    if captured["<Right>"] then
      captured["<Right>"]()
    end
  end)

  vim.keymap.set = original_keymap_set
  vim.api.nvim_win_get_cursor = original_cursor

  if not ok then
    error(err)
  end

  assert.eq(selected, "Run", "right opens section")
end

local function hub_left_key_triggers_cancel()
  local canceled = false
  local captured = {}
  local original_keymap_set = vim.keymap.set

  vim.keymap.set = function(_, lhs, rhs)
    captured[lhs] = rhs
  end

  local ok, err = pcall(function()
    package.loaded["android.ui.hub"] = nil
    local hub = require("android.ui.hub")
    hub.open({
      blocks = {
        { title = "Run", items = { 1 } },
      },
      on_cancel = function()
        canceled = true
      end,
    })
    if captured["<Left>"] then
      captured["<Left>"]()
    end
  end)

  vim.keymap.set = original_keymap_set

  if not ok then
    error(err)
  end

  assert.eq(canceled, true, "left triggers cancel")
end

function M.run()
  build_lines_include_summary_and_blocks()
  search_keys_include_letters_without_navigation()
  hub_calls_on_cancel_on_escape()
  hub_calls_on_close_with_cancel_reason()
  initial_line_uses_block_index()
  hub_select_uses_updated_summary_lines()
  hub_search_uses_updated_summary_lines()
  hub_enter_on_summary_line_does_not_close()
  hub_number_shortcut_selects_block()
  hub_slash_opens_search_without_default_text()
  hub_q_key_keeps_close_behavior_when_search_enabled()
  hub_right_key_opens_selection()
  hub_left_key_triggers_cancel()
end

return M
