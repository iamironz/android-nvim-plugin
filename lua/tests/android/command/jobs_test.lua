local M = {}
local assert = require("tests.helpers.assert")

local function make_spawn_stub(result)
  local state = {
    calls = 0,
    cmd = nil,
    opts = nil,
    stop_calls = 0,
  }

  local spawn = function(cmd, opts)
    state.calls = state.calls + 1
    state.cmd = cmd
    state.opts = opts or {}

    local ok = true
    local id = 1
    if result then
      if result.ok ~= nil then
        ok = result.ok
      end
      if result.id ~= nil then
        id = result.id
      end
    end

    return {
      id = id,
      ok = ok,
      stop = function()
        state.stop_calls = state.stop_calls + 1
      end,
    }
  end

  return spawn, state
end

local function start_registers_job()
  local spawn = make_spawn_stub()
  local manager = require("android.command.jobs").new({ spawn = spawn })
  local entry = manager.start("echo hello", {})

  assert.eq(manager.list()[1], entry, "start registers job")
end

local function start_sets_status_running()
  local spawn = make_spawn_stub()
  local manager = require("android.command.jobs").new({ spawn = spawn })
  local entry = manager.start("echo hello", {})

  assert.eq(entry.status, "running", "start status")
end

local function list_reports_length()
  local spawn = make_spawn_stub()
  local manager = require("android.command.jobs").new({ spawn = spawn })
  manager.start("echo hello", {})

  assert.eq(#manager.list(), 1, "list length")
end

local function stop_calls_stop()
  local spawn, state = make_spawn_stub()
  local manager = require("android.command.jobs").new({ spawn = spawn })
  local entry = manager.start("echo hello", {})

  manager.stop(entry)

  assert.eq(state.stop_calls, 1, "stop called")
end

local function stop_sets_status()
  local spawn = make_spawn_stub()
  local manager = require("android.command.jobs").new({ spawn = spawn })
  local entry = manager.start("echo hello", {})

  manager.stop(entry)

  assert.eq(entry.status, "stopped", "stop status")
end

local function stop_by_id_sets_status()
  local spawn = make_spawn_stub()
  local manager = require("android.command.jobs").new({ spawn = spawn })
  local entry = manager.start("echo hello", {})

  manager.stop(entry.id)

  assert.eq(entry.status, "stopped", "stop by id")
end

local function on_exit_marks_success()
  local spawn, state = make_spawn_stub()
  local manager = require("android.command.jobs").new({ spawn = spawn })
  local entry = manager.start("echo hello", { on_exit = function() end })

  state.opts.on_exit(0)

  assert.eq(entry.status, "success", "exit success")
end

local function on_exit_sets_exit_code()
  local spawn, state = make_spawn_stub()
  local manager = require("android.command.jobs").new({ spawn = spawn })
  local entry = manager.start("echo hello", { on_exit = function() end })

  state.opts.on_exit(0)

  assert.eq(entry.exit_code, 0, "exit code")
end

local function on_exit_sets_ok_true()
  local spawn, state = make_spawn_stub()
  local manager = require("android.command.jobs").new({ spawn = spawn })
  local entry = manager.start("echo hello", { on_exit = function() end })

  state.opts.on_exit(0)

  assert.eq(entry.ok, true, "ok true")
end

local function on_exit_calls_after_status()
  local spawn, state = make_spawn_stub()
  local manager = require("android.command.jobs").new({ spawn = spawn })
  local observed = nil
  local entry

  entry = manager.start("echo hello", {
    on_exit = function()
      observed = entry.status
    end,
  })

  state.opts.on_exit(0)

  assert.eq(observed, "success", "exit order")
end

local function on_exit_marks_failure()
  local spawn, state = make_spawn_stub()
  local manager = require("android.command.jobs").new({ spawn = spawn })
  local entry = manager.start("echo hello", { on_exit = function() end })

  state.opts.on_exit(1)

  assert.eq(entry.status, "failed", "exit failed")
end

local function start_failure_not_listed()
  local spawn = make_spawn_stub({ ok = false, id = -1 })
  local manager = require("android.command.jobs").new({ spawn = spawn })
  manager.start("echo hello", {})

  assert.eq(#manager.list(), 0, "failed not listed")
end

local function start_failure_status_failed()
  local spawn = make_spawn_stub({ ok = false, id = -1 })
  local manager = require("android.command.jobs").new({ spawn = spawn })
  local entry = manager.start("echo hello", {})

  assert.eq(entry.status, "failed", "failed status")
end

function M.run()
  start_registers_job()
  start_sets_status_running()
  list_reports_length()
  stop_calls_stop()
  stop_sets_status()
  stop_by_id_sets_status()
  on_exit_marks_success()
  on_exit_sets_exit_code()
  on_exit_sets_ok_true()
  on_exit_calls_after_status()
  on_exit_marks_failure()
  start_failure_not_listed()
  start_failure_status_failed()
end

return M
