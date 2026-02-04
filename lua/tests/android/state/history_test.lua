local M = {}

local assert = require("tests.helpers.assert")

local function push_adds_new_value()
  local history = require("android.state.history")
  local list = history.push({ "old" }, "new", { limit = 5 })
  assert.table_eq(list, { "new", "old" }, "adds new value")
end

local function push_dedupes_existing()
  local history = require("android.state.history")
  local list = history.push({ "one", "two" }, "two", { limit = 5 })
  assert.table_eq(list, { "two", "one" }, "dedupes")
end

local function push_ignores_empty()
  local history = require("android.state.history")
  local list = history.push({ "one" }, "   ", { limit = 5 })
  assert.table_eq(list, { "one" }, "ignores empty")
end

local function push_respects_limit()
  local history = require("android.state.history")
  local list = history.push({ "a", "b", "c" }, "d", { limit = 3 })
  assert.table_eq(list, { "d", "a", "b" }, "limit")
end

function M.run()
  push_adds_new_value()
  push_dedupes_existing()
  push_ignores_empty()
  push_respects_limit()
end

return M
