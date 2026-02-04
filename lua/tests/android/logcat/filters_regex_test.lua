local M = {}

local assert = require("tests.helpers.assert")
local filters = require("android.logcat.filters")

local function matches_regex_filter_terms()
  local lines = {
    "One Two",
    "oneXtwo",
    "other",
  }

  local filtered = filters.filter_lines(lines, "/one.*two/")

  assert.table_eq(filtered, { "One Two", "oneXtwo" }, "regex match")
end

local function invalid_regex_falls_back_to_substring()
  local lines = {
    "value [test]",
    "no match",
  }

  local filtered = filters.filter_lines(lines, "/[/")

  assert.table_eq(filtered, { "value [test]" }, "invalid regex fallback")
end

local function plain_string_behavior_is_unchanged()
  local lines = {
    "Alpha Beta",
    "gamma",
  }

  local filtered = filters.filter_lines(lines, "alpha")

  assert.table_eq(filtered, { "Alpha Beta" }, "plain string match")
end

function M.run()
  matches_regex_filter_terms()
  invalid_regex_falls_back_to_substring()
  plain_string_behavior_is_unchanged()
end

return M
