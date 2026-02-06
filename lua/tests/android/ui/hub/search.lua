local M = {}

local assert = require("tests.helpers.assert")

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

function M.run()
  hub_search_uses_updated_summary_lines()
  hub_slash_opens_search_without_default_text()
  hub_q_key_keeps_close_behavior_when_search_enabled()
end

return M
