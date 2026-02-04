local M = {}

local configs = require("tests.android.run.registry_configs_test")
local registry = require("tests.android.run.registry_registry_test")

function M.run()
  configs.run()
  registry.run()
end

return M
