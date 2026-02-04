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

function M.run()
  trims_whitespace()
  returns_empty_for_non_string()
end

return M
