local M = {}

local assert = require("tests.helpers.assert")
local build_stream_helper = require("tests.helpers.build_stream")

local function start_build_sets_panel_names_from_task_params()
  local outcome = build_stream_helper.run_build_job({
    args = { "./gradlew", ":app:assembleDebug" },
    stdout_lines = {},
    stderr_lines = {},
    exit_code = 0,
  })

  local names = outcome.panel.names or {}
  assert.eq(
    names.body,
    "android://build module=:app variant=debug task=assembleDebug filter=-",
    "body name"
  )
  assert.eq(
    names.control,
    "android://build-controls module=:app variant=debug task=assembleDebug filter=-",
    "control name"
  )
end

local function filter_changes_update_panel_names()
  local outcome = build_stream_helper.run_build_job({
    args = { "./gradlew", ":app:assembleDebug" },
    stdout_lines = { "Error line" },
    stderr_lines = {},
    exit_code = 0,
    input = {
      change_value = "warn",
      value = "warn",
      calls = {},
    },
    after_start = function(state)
      build_stream_helper.start_filter_input(state)
    end,
  })

  local names = outcome.panel.names or {}
  assert.eq(
    names.body,
    "android://build module=:app variant=debug task=assembleDebug filter=warn",
    "body name after filter"
  )
  assert.eq(
    names.control,
    "android://build-controls module=:app variant=debug task=assembleDebug filter=warn",
    "control name after filter"
  )
end

function M.run()
  start_build_sets_panel_names_from_task_params()
  filter_changes_update_panel_names()
end

return M
