local M = {}
local assert = require("tests.helpers.assert")
local output = require("android.logcat.session.output")

local function new_session(options)
  local opts = options or {}
  return {
    filter = opts.filter or "",
    max_lines = opts.max_lines or 3,
    raw_lines = {},
    body_lines = {},
    status_message = nil,
    active = false,
  }
end

local function append_raw_lines_trims_with_filter()
  local session = new_session({ filter = "error", max_lines = 3 })

  output.append_raw_lines(session, { "l1", "l2", "l3", "l4", "l5" })

  assert.table_eq(session.raw_lines, { "l3", "l4", "l5" }, "raw lines trimmed")
end

local function append_body_lines_trims_with_filter()
  local session = new_session({ filter = "error", max_lines = 2 })

  output.append_lines(session, { "a", "b", "c" })

  assert.table_eq(session.body_lines, { "b", "c" }, "body lines trimmed")
end

function M.run()
  append_raw_lines_trims_with_filter()
  append_body_lines_trims_with_filter()
end

return M
