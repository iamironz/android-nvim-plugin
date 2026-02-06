local M = {}

local cancel_and_query = require("tests.android.ui.picker_filter_input.cancel_and_query")
local fallback_input = require("tests.android.ui.picker_filter_input.fallback_input")
local fallback_select = require("tests.android.ui.picker_filter_input.fallback_select")
local telescope_input = require("tests.android.ui.picker_filter_input.telescope_input")

function M.run()
  fallback_input.run()
  telescope_input.run()
  fallback_select.run()
  cancel_and_query.run()
end

return M
