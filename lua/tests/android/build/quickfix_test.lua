local M = {}

local assert = require("tests.helpers.assert")
local quickfix = require("android.build.quickfix")

local function parses_kotlin_error_line()
  local items = quickfix.parse({ "e: /tmp/Foo.kt: (12, 8): Something went wrong" })

  assert.eq(#items, 1, "item count")
  local item = items[1]
  assert.eq(item.filename, "/tmp/Foo.kt", "filename")
  assert.eq(item.lnum, 12, "line")
  assert.eq(item.col, 8, "col")
  assert.eq(item.text, "Something went wrong", "text")
end

local function parses_java_error_line()
  local items = quickfix.parse({ "/tmp/Foo.java:42: error: cannot find symbol" })

  assert.eq(#items, 1, "item count")
  local item = items[1]
  assert.eq(item.filename, "/tmp/Foo.java", "filename")
  assert.eq(item.lnum, 42, "line")
  assert.eq(item.col, 1, "col default")
  assert.eq(item.text, "error: cannot find symbol", "text")
end

local function ignores_empty_input()
  local items = quickfix.parse({})

  assert.eq(#items, 0, "empty")
end

function M.run()
  parses_kotlin_error_line()
  parses_java_error_line()
  ignores_empty_input()
end

return M
