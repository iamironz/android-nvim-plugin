local M = {}

local assert = require("tests.helpers.assert")
local parser = require("android.logcat.parser")

local function parses_kotlin_stack_line()
  local result = parser.parse_stack_line("at com.foo.Bar.baz(Bar.kt:123)")

  assert.eq(result.file, "Bar.kt", "kotlin file")
  assert.eq(result.line, 123, "kotlin line")
end

local function parses_java_stack_line()
  local result = parser.parse_stack_line("at com.foo.Bar.baz(Bar.java:45)")

  assert.eq(result.file, "Bar.java", "java file")
  assert.eq(result.line, 45, "java line")
end

local function returns_nil_for_non_stack_lines()
  local result = parser.parse_stack_line("Caused by: java.lang.IllegalStateException")

  assert.eq(result, nil, "non stack")
end

local function returns_nil_for_native_method()
  local result = parser.parse_stack_line("at com.foo.Bar.baz(Native Method)")

  assert.eq(result, nil, "native method")
end

function M.run()
  parses_kotlin_stack_line()
  parses_java_stack_line()
  returns_nil_for_non_stack_lines()
  returns_nil_for_native_method()
end

return M
