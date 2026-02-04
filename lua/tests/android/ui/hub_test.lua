local M = {}

local assert = require("tests.helpers.assert")

local function build_lines_include_summary_and_blocks()
  package.loaded["android.ui.hub"] = nil
  local hub = require("android.ui.hub")
  local lines = hub._build_lines({ "Summary", "Workspace: /app" }, {
    { title = "Build", items = { 1, 2 } },
    { title = "Devices", items = {} },
  })

  local text = table.concat(lines, "|")
  local expected = table.concat({
    "Summary",
    "Workspace: /app",
    "",
    "Build (2)",
    "Devices",
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
    blocks = { { title = "Build", items = { 1 } } },
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

local function initial_line_uses_block_index()
  package.loaded["android.ui.hub"] = nil
  local hub = require("android.ui.hub")
  local line = hub._initial_line({ "Summary", "" }, 3, 2)
  assert.eq(line, 5, "initial line")
end

function M.run()
  build_lines_include_summary_and_blocks()
  search_keys_include_letters_and_digits()
  hub_calls_on_cancel_on_escape()
  initial_line_uses_block_index()
end

return M
