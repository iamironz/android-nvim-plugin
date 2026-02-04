local M = {}

local actions = require("tests.android.ui.menu.actions")
local main = require("tests.android.ui.menu.main")
local navigation = require("tests.android.ui.menu.navigation")
local targets = require("tests.android.ui.menu.targets")
local tools = require("tests.android.ui.menu.tools")

function M.run()
  main.run()
  navigation.run()
  targets.run()
  tools.run()
  actions.run()
end

return M
