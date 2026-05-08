local M = {}

local assert = require("tests.helpers.assert")
local stubs_helper = require("tests.helpers.stubs")
local build_stream_helper = require("tests.helpers.build_stream")

local function builds_command_without_shell_wrapper()
  -- Arrange
  local stubs = {
    ["android.command.jobs"] = {},
    ["android.ui.panel"] = {},
  }

  -- Act
  build_stream_helper.with_vim_stubs(function()
    stubs_helper.with_stubs(stubs, function()
      local stream = build_stream_helper.reset_stream_module()
      local cmd = stream.build_shell_command("/root path", { "gradle", "task" })

      -- Assert
      assert.table_eq(cmd, { "gradle", "task" }, "command args")
    end)
  end)
end

local function start_build_job_opens_panel()
  -- Act
  local outcome = build_stream_helper.run_default_build()

  -- Assert
  assert.is_true(outcome.panel.opened, "panel opened")
end

local function start_build_job_clears_panel()
  -- Act
  local outcome = build_stream_helper.run_default_build()

  -- Assert
  assert.is_true(outcome.panel.cleared, "panel cleared")
end

local function start_build_job_uses_dock_layout()
  local outcome = build_stream_helper.run_default_build()

  assert.eq(outcome.panel.open_opts and outcome.panel.open_opts.layout, "dock", "panel layout")
  assert.eq(
    outcome.panel.open_opts and outcome.panel.open_opts.control_height,
    1,
    "panel control height"
  )
end

local function start_build_job_appends_output_lines()
  -- Act
  local outcome = build_stream_helper.run_default_build()

  -- Assert
  assert.table_eq(
    outcome.panel.lines,
    { "line 1", "err 1", "err 2" },
    "panel lines"
  )
end

local function start_build_job_uses_cwd()
  -- Act
  local outcome = build_stream_helper.run_default_build()

  -- Assert
  assert.table_eq(outcome.spawn_cmd, { "gradle" }, "spawn command")
  assert.eq(outcome.spawn_opts and outcome.spawn_opts.cwd, "/root", "spawn cwd")
end

local function start_build_job_reports_failed_result()
  -- Act
  local outcome = build_stream_helper.run_default_build()

  -- Assert
  assert.is_true(
    outcome.result and outcome.result.ok == false,
    "result ok"
  )
end

local function start_build_job_reports_stdout()
  -- Act
  local outcome = build_stream_helper.run_default_build()

  -- Assert
  assert.eq(outcome.result.stdout, "line 1", "stdout")
end

local function start_build_job_reports_stderr()
  -- Act
  local outcome = build_stream_helper.run_default_build()

  -- Assert
  assert.eq(outcome.result.stderr, "err 1\nerr 2", "stderr")
end

local function start_build_job_reports_lines()
  -- Act
  local outcome = build_stream_helper.run_default_build()

  -- Assert
  assert.table_eq(
    outcome.result.lines,
    { "line 1", "err 1", "err 2" },
    "lines"
  )
end

local function start_build_job_sets_header()
  -- Act
  local outcome = build_stream_helper.run_filter_build()

  -- Assert
  assert.table_eq(
    outcome.panel.header_history[1],
    { "Filter: " },
    "header line"
  )
end

local function start_build_job_registers_filter_keymap()
  -- Act
  local outcome = build_stream_helper.run_filter_build()

  -- Assert
  assert.is_true(
    outcome.keymaps and outcome.keymaps["n"]["f"],
    "filter keymap"
  )
end

local function start_build_job_registers_close_keymaps()
  local outcome = build_stream_helper.run_filter_build()

  assert.is_true(
    outcome.keymaps and outcome.keymaps["n"]["q"],
    "q close keymap"
  )
  assert.is_true(
    outcome.keymaps and outcome.keymaps["n"]["<Esc>"],
    "esc close keymap"
  )
end

local function close_keymap_closes_panel(lhs)
  local outcome = build_stream_helper.run_filter_build({
    after_start = function(state)
      state.keymaps["n"][lhs]()
    end,
  })

  assert.eq(outcome.panel.closed, true, lhs .. " closes panel")
end

local function q_keymap_closes_panel()
  close_keymap_closes_panel("q")
end

local function esc_keymap_closes_panel()
  close_keymap_closes_panel("<Esc>")
end

local function run_filter_input(options)
  local opts = options or {}
  local state = opts.state
  if state == nil then
    state = { build = {} }
  end
  return build_stream_helper.run_filter_build({
    state = state,
    input = {
      value = opts.value,
      change_value = opts.change_value,
      before_accept = opts.before_accept,
      cancel = opts.cancel,
      calls = {},
    },
    after_start = function(state)
      if opts.start_from_enter then
        build_stream_helper.start_filter_input_from_enter(state)
      else
        build_stream_helper.start_filter_input(state)
      end
    end,
  })
end

local function filter_history_persist_keeps_external_run_selection()
  local state = {
    build = { filter_history = { "old" } },
    run = { config_id = "android" },
  }
  local outcome = run_filter_input({
    state = state,
    change_value = "new",
    value = "new",
    before_accept = function()
      local action_context = require("android.actions.context")
      action_context.save_state("/root", {
        build = { filter_history = { "old" } },
        run = { config_id = "ios" },
      })
    end,
  })

  local run_config = outcome.saved_state and outcome.saved_state.run and outcome.saved_state.run.config_id
  assert.eq(run_config, "ios", "run config preserved")
end

local function filter_keymap_opens_modal()
  local outcome = run_filter_input({ value = "error" })
  local call = outcome.input_calls[1] or {}
  local summary = string.format("%d|%s", #outcome.input_calls, call.prompt_title or "")
  assert.eq(summary, "1|Build filter", "input prompt")
end

local function filter_input_updates_header()
  local outcome = run_filter_input({ change_value = "warn", value = "warn" })
  assert.table_eq(
    outcome.panel.header_history[#outcome.panel.header_history],
    { "Filter: warn" },
    "updated header"
  )
end

local function filter_input_tracks_body_updates()
  local outcome = run_filter_input({ change_value = "error", value = "error" })
  assert.eq(
    #outcome.panel.replaced_body_history,
    1,
    "body updates"
  )
end

local function filter_input_filters_body()
  local outcome = run_filter_input({ change_value = "error", value = "error" })
  assert.table_eq(
    outcome.panel.replaced_body_history[1],
    { "Error line" },
    "filtered body"
  )
end

local function filter_input_does_not_restart_build()
  local outcome = run_filter_input({ change_value = "error", value = "error" })
  assert.eq(outcome.spawn_calls, 1, "no build restart")
end

local function filter_input_cancel_keeps_header()
  local outcome = run_filter_input({ change_value = "error", cancel = true })
  assert.table_eq(
    outcome.panel.header_history[#outcome.panel.header_history],
    { "Filter: error" },
    "header kept"
  )
end

local function filter_picker_receives_history()
  local state = { build = { filter_history = { "warn", "error" } } }
  local outcome = run_filter_input({
    state = state,
    change_value = "error",
    value = "error",
  })
  local items = outcome.input_calls[1] and outcome.input_calls[1].items or {}
  assert.table_eq(items, { "warn", "error" }, "history items")
end

local function filter_history_persists()
  local state = { build = { filter_history = { "old" } } }
  local outcome = run_filter_input({
    state = state,
    change_value = "new",
    value = "new",
  })
  local history = outcome.saved_state and outcome.saved_state.build and outcome.saved_state.build.filter_history
  assert.table_eq(history, { "new", "old" }, "history saved")
end

local function filter_history_persists_on_cancel()
  local state = { build = { filter_history = { "old" } } }
  local outcome = run_filter_input({
    state = state,
    change_value = "temp",
    cancel = true,
  })
  local history = outcome.saved_state and outcome.saved_state.build and outcome.saved_state.build.filter_history
  assert.table_eq(history, { "temp", "old" }, "history saved")
end

local function header_enter_starts_input()
  local outcome = run_filter_input({ change_value = "warn", value = "warn", start_from_enter = true })
  assert.table_eq(
    outcome.panel.header_history[#outcome.panel.header_history],
    { "Filter: warn" },
    "header enter update"
  )
end

local function build_output_caps_lines()
  local lines = {}
  for i = 1, 2001 do
    lines[#lines + 1] = "line-" .. i
  end

  local outcome = build_stream_helper.run_build_job({
    stdout_lines = lines,
    stderr_lines = {},
    exit_code = 0,
  })

  assert.eq(#outcome.result.lines, 2000, "result lines capped")
  assert.eq(outcome.result.lines[1], "line-2", "result drop oldest")
  assert.eq(outcome.result.lines[#outcome.result.lines], "line-2001", "result keeps latest")
  assert.eq(#outcome.panel.lines, 2000, "panel lines capped")
  assert.eq(outcome.panel.lines[1], "line-2", "panel drop oldest")
  assert.eq(outcome.panel.lines[#outcome.panel.lines], "line-2001", "panel keeps latest")
end

function M.run()
  builds_command_without_shell_wrapper()
  start_build_job_opens_panel()
  start_build_job_clears_panel()
  start_build_job_uses_dock_layout()
  start_build_job_appends_output_lines()
  start_build_job_uses_cwd()
  start_build_job_reports_failed_result()
  start_build_job_reports_stdout()
  start_build_job_reports_stderr()
  start_build_job_reports_lines()
  start_build_job_sets_header()
  start_build_job_registers_filter_keymap()
  start_build_job_registers_close_keymaps()
  q_keymap_closes_panel()
  esc_keymap_closes_panel()
  filter_keymap_opens_modal()
  filter_input_updates_header()
  filter_input_tracks_body_updates()
  filter_input_filters_body()
  filter_input_does_not_restart_build()
  filter_input_cancel_keeps_header()
  header_enter_starts_input()
  filter_picker_receives_history()
  filter_history_persists()
  filter_history_persists_on_cancel()
  filter_history_persist_keeps_external_run_selection()
  build_output_caps_lines()
end

return M
