local M = {}

local assert = require("tests.helpers.assert")

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

function M.run()
  hub_select_uses_updated_summary_lines()
  hub_enter_on_summary_line_does_not_close()
  hub_number_shortcut_selects_block()
  hub_right_key_opens_selection()
end

return M
