local M = {}

local assert = require("tests.helpers.assert")

local function trim_uses_shared_helper()
  local ok, strings = pcall(require, "android.utils.strings")
  assert.eq(ok, true, "strings module available")

  local utils = require("android.devices.utils")
  assert.eq(utils.trim, strings.trim, "shared trim")
end

local function runner_stdout_lines_splits_output()
  local utils = require("android.devices.utils")
  local runner = {
    run = function()
      return { stdout = "line1\nline2\n" }
    end,
  }

  local lines = utils.runner_stdout_lines(runner, { "cmd" })
  assert.table_eq(lines, { "line1", "line2", "" }, "stdout lines")
end

function M.run()
  trim_uses_shared_helper()
  runner_stdout_lines_splits_output()
end

return M
