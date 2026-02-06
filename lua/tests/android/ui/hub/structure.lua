local M = {}

local assert = require("tests.helpers.assert")
local source = require("tests.helpers.source")

local function hub_open_function_respects_hard_limit()
  local length, err = source.function_length("lua/android/ui/hub.lua", "^function%s+M%.open%(")
  if not length then
    error(err)
  end
  assert.eq(length <= 80, true, "M.open length <= 80")
end

function M.run()
  hub_open_function_respects_hard_limit()
end

return M
