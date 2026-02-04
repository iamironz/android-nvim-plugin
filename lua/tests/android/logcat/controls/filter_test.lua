local M = {}
local filter_input = require("tests.android.logcat.controls.filter_input_test")
local filter_level = require("tests.android.logcat.controls.filter_level_test")
local filter_output = require("tests.android.logcat.controls.filter_output_test")
local filter_navigation = require("tests.android.logcat.controls.filter_navigation_test")

function M.run()
  filter_input.run()
  filter_level.run()
  filter_output.run()
  filter_navigation.run()
end

return M
