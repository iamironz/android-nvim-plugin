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
    "Build Variants (2) | Builds and variants",
    "Device Manager | Devices and emulators",
  }, "|")
  assert.eq(text, expected, "hub lines")
end

local function search_keys_include_letters_and_digits()
  package.loaded["android.ui.hub"] = nil
  local hub = require("android.ui.hub")
  local keys = hub._search_keys()
  assert.table_eq(
    keys,
    {
      "0",
      "1",
      "2",
      "3",
      "4",
      "5",
      "6",
      "7",
      "8",
      "9",
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
      "q",
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
  assert.eq(line, 5, "initial line")
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
    return { 4, 0 }
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
    return { 4, 0 }
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

function M.run()
  build_lines_include_summary_and_blocks()
  search_keys_include_letters_and_digits()
  hub_calls_on_cancel_on_escape()
  hub_calls_on_close_with_cancel_reason()
  initial_line_uses_block_index()
  hub_select_uses_updated_summary_lines()
  hub_search_uses_updated_summary_lines()
end

return M
