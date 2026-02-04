local M = {}
local manager = require("android.logcat.manager")

M.default_max_lines = manager.default_max_lines

function M.open()
  manager.open()
end

return M
