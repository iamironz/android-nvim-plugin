local M = {}

local cancel = require("tests.android.ui.hub.cancel")
local layout = require("tests.android.ui.hub.layout")
local search = require("tests.android.ui.hub.search")
local selection = require("tests.android.ui.hub.selection")
local structure = require("tests.android.ui.hub.structure")

function M.run()
  layout.run()
  cancel.run()
  selection.run()
  search.run()
  structure.run()
end

return M
