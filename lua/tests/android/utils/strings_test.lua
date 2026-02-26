local M = {}

local assert = require("tests.helpers.assert")

local function trims_whitespace()
  local ok, strings = pcall(require, "android.utils.strings")
  assert.eq(ok, true, "strings module available")
  assert.eq(strings.trim("  hello  "), "hello", "trim whitespace")
end

local function returns_empty_for_non_string()
  local ok, strings = pcall(require, "android.utils.strings")
  assert.eq(ok, true, "strings module available")
  assert.eq(strings.trim(nil), "", "trim non-string")
end

local function picks_first_nonempty_line()
  local ok, strings = pcall(require, "android.utils.strings")
  assert.eq(ok, true, "strings module available")
  assert.eq(
    strings.first_nonempty_line("\n   \n  hello world  \nsecond"),
    "hello world",
    "first nonempty line is trimmed"
  )
end

local function returns_nil_when_no_nonempty_lines()
  local ok, strings = pcall(require, "android.utils.strings")
  assert.eq(ok, true, "strings module available")
  assert.eq(strings.first_nonempty_line(" \n\t\n"), nil, "no nonempty line")
end

function M.run()
  trims_whitespace()
  returns_empty_for_non_string()
  picks_first_nonempty_line()
  returns_nil_when_no_nonempty_lines()
end

return M
