local M = {}

local assert = require("tests.helpers.assert")
local filters = require("android.logcat.filters")

local function normalizes_short_log_levels()
  local cases = {
    { input = "v", expected = "V", label = "lowercase v" },
    { input = "d", expected = "D", label = "lowercase d" },
    { input = "i", expected = "I", label = "lowercase i" },
    { input = "w", expected = "W", label = "lowercase w" },
    { input = "e", expected = "E", label = "lowercase e" },
  }

  for _, case in ipairs(cases) do
    assert.eq(filters.normalize_level(case.input), case.expected, case.label)
  end
end

local function normalizes_long_log_levels()
  local cases = {
    { input = "verbose", expected = "V", label = "verbose" },
    { input = "debug", expected = "D", label = "debug" },
    { input = "info", expected = "I", label = "info" },
    { input = "warn", expected = "W", label = "warn" },
    { input = "warning", expected = "W", label = "warning" },
    { input = "error", expected = "E", label = "error" },
  }

  for _, case in ipairs(cases) do
    assert.eq(filters.normalize_level(case.input), case.expected, case.label)
  end
end

local function applies_fallback_for_unknown_level()
  assert.eq(filters.normalize_level("nope", "I"), "I", "fallback")
end

local function applies_fallback_for_nil_level()
  assert.eq(filters.normalize_level(nil, "D"), "D", "nil fallback")
end

local function builds_filter_spec()
  local spec = filters.build({
    level = "w",
    package = " com.app ",
    tag = " Ui ",
    default_level = "I",
  })

  assert.eq(spec.level, "W", "spec level")
  assert.eq(spec.package, "com.app", "spec package")
  assert.eq(spec.tag, "Ui", "spec tag")
end

local function drops_empty_values()
  local spec = filters.build({
    level = "",
    package = "  ",
    tag = "",
    default_level = "E",
  })

  assert.eq(spec.level, "E", "spec default level")
  assert.eq(spec.package, nil, "spec package")
  assert.eq(spec.tag, nil, "spec tag")
end

local function parses_terms_as_lowercased_words()
  local terms = filters.parse_terms("  Foo\tBAR\nBaz  ")

  assert.table_eq(terms, { "foo", "bar", "baz" }, "terms")
end

local function ignores_empty_terms()
  assert.table_eq(filters.parse_terms(""), {}, "empty string")
  assert.table_eq(filters.parse_terms("   \n\t  "), {}, "whitespace")
  assert.table_eq(filters.parse_terms(nil), {}, "nil text")
end

local function matches_all_terms_case_insensitive()
  local matches = filters.matches_terms("Hello World", { "hello", "world" })

  assert.is_true(matches, "matches all terms")
end

local function rejects_missing_terms()
  local matches = filters.matches_terms("Hello World", { "hello", "planet" })

  assert.eq(matches, false, "missing term")
end

local function accepts_empty_terms()
  local matches = filters.matches_terms("Hello World", {})

  assert.is_true(matches, "empty terms")
end

local function filters_lines_by_terms()
  local lines = {
    "One Two",
    "Two Three",
    "one three",
    "four",
  }

  local filtered = filters.filter_lines(lines, "one")

  assert.table_eq(filtered, { "One Two", "one three" }, "one term")
end

local function returns_empty_when_lines_nil()
  local filtered = filters.filter_lines(nil, "one")

  assert.table_eq(filtered, {}, "nil lines")
end

local function preserves_order_of_filtered_lines()
  local lines = {
    "alpha beta",
    "beta alpha",
    "alpha",
  }

  local filtered = filters.filter_lines(lines, "alpha beta")

  assert.table_eq(filtered, { "alpha beta", "beta alpha" }, "order")
end

function M.run()
  normalizes_short_log_levels()
  normalizes_long_log_levels()
  applies_fallback_for_unknown_level()
  applies_fallback_for_nil_level()
  builds_filter_spec()
  drops_empty_values()
  parses_terms_as_lowercased_words()
  ignores_empty_terms()
  matches_all_terms_case_insensitive()
  rejects_missing_terms()
  accepts_empty_terms()
  filters_lines_by_terms()
  returns_empty_when_lines_nil()
  preserves_order_of_filtered_lines()
end

return M
