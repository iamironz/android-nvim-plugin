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

local function initial_line_uses_block_index()
  package.loaded["android.ui.hub"] = nil
  local hub = require("android.ui.hub")
  local line = hub._initial_line({ "Summary", "" }, 3, 2)
  assert.eq(line, 8, "initial line")
end

function M.run()
  build_lines_include_summary_and_blocks()
  search_keys_include_letters_without_navigation()
  initial_line_uses_block_index()
end

return M
