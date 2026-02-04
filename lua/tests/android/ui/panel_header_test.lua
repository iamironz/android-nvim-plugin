local M = {}
local assert = require("tests.helpers.assert")

local function load_header()
  package.loaded["android.ui.panel_header"] = nil
  local ok, header = pcall(require, "android.ui.panel_header")
  assert.is_true(ok, "panel header module loads")
  return header
end

local function logcat_header_returns_package_and_filter_lines()
  local header = load_header()

  local lines = header.logcat_lines({
    package = "com.example.app",
    filter = "Activity",
  })

  assert.eq(#lines, 3, "logcat line count")
  assert.eq(lines[1], "Package: com.example.app", "package line")
  assert.eq(lines[2], "Filter: Activity", "filter line")
  assert.eq(lines[3], "Level: ", "level line")
end

local function logcat_header_defaults_to_empty_values()
  local header = load_header()

  local lines = header.logcat_lines()
  assert.table_eq(lines, { "Package: ", "Filter: ", "Level: " }, "logcat defaults")
end

local function build_header_returns_filter_line()
  local header = load_header()

  local lines = header.build_lines({ filter = "warning" })
  assert.table_eq(lines, { "Filter: warning" }, "build line")
end

local function build_header_defaults_to_empty_filter()
  local header = load_header()

  local lines = header.build_lines()
  assert.table_eq(lines, { "Filter: " }, "build defaults")
end

function M.run()
  logcat_header_returns_package_and_filter_lines()
  logcat_header_defaults_to_empty_values()
  build_header_returns_filter_line()
  build_header_defaults_to_empty_filter()
end

return M
