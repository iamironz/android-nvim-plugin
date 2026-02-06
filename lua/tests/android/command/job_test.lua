local M = {}
local assert = require("tests.helpers.assert")

local function mock_vim_job()
  local state = {
    jobs = {},
    next_job_id = 1,
    jobstart_return = nil,
    jobstop_calls = 0,
  }

  local saved = {}
  local function save(tbl, key)
    saved[tbl] = saved[tbl] or {}
    if saved[tbl][key] == nil then
      saved[tbl][key] = tbl[key]
    end
  end

  save(vim.fn, "jobstart")
  vim.fn.jobstart = function(cmd, opts)
    if state.jobstart_return ~= nil then
      return state.jobstart_return
    end
    local id = state.next_job_id
    state.next_job_id = state.next_job_id + 1
    state.jobs[id] = { cmd = cmd, opts = opts }
    return id
  end

  save(vim.fn, "jobstop")
  vim.fn.jobstop = function(id)
    state.jobstop_calls = state.jobstop_calls + 1
    if state.jobs[id] then
      state.jobs[id].stopped = true
    end
    return 1
  end

  return state, function()
    for tbl, keys in pairs(saved) do
      for key, val in pairs(keys) do
        tbl[key] = val
      end
    end
  end
end

local function test_spawn_starts_job()
  local state, restore = mock_vim_job()
  package.loaded["android.command.job"] = nil
  local job = require("android.command.job")

  local ok, err = pcall(function()
    local j = job.spawn("echo hello", {})

    assert.eq(state.next_job_id, 2, "job started")
    assert.is_true(type(j.stop) == "function", "has stop method")
    assert.eq(j.ok, true, "ok true")
    
    -- Verify job command
    local job_id = j.id
    assert.eq(state.jobs[job_id].cmd, "echo hello", "command correct")
  end)

  restore()
  if not ok then error(err) end
end

local function test_spawn_returns_failure_for_jobstart_zero()
  local state, restore = mock_vim_job()
  state.jobstart_return = 0
  package.loaded["android.command.job"] = nil
  local job = require("android.command.job")

  local ok, err = pcall(function()
    local j = job.spawn("echo hello", {})

    assert.eq(j.id, 0, "job id is zero")
    assert.eq(j.ok, false, "ok false")
    assert.eq(j.error, "jobstart_failed", "error set")

    j.stop()
    assert.eq(state.jobstop_calls, 0, "jobstop not called")
  end)

  restore()
  if not ok then error(err) end
end

local function test_spawn_returns_failure_for_jobstart_negative()
  local state, restore = mock_vim_job()
  state.jobstart_return = -1
  package.loaded["android.command.job"] = nil
  local job = require("android.command.job")

  local ok, err = pcall(function()
    local j = job.spawn("echo hello", {})

    assert.eq(j.id, -1, "job id is negative")
    assert.eq(j.ok, false, "ok false")
    assert.eq(j.error, "jobstart_failed", "error set")

    j.stop()
    assert.eq(state.jobstop_calls, 0, "jobstop not called")
  end)

  restore()
  if not ok then error(err) end
end

local function test_callbacks_are_triggered()
  local state, restore = mock_vim_job()
  package.loaded["android.command.job"] = nil
  local job = require("android.command.job")

  local ok, err = pcall(function()
    local stdout_data = {}
    local stderr_data = {}
    local exit_code = nil

    local j = job.spawn("echo hello", {
      on_stdout = function(lines)
        table.insert(stdout_data, lines)
      end,
      on_stderr = function(lines)
        table.insert(stderr_data, lines)
      end,
      on_exit = function(code)
        exit_code = code
      end
    })

    local job_id = j.id
    local opts = state.jobs[job_id].opts
    
    -- Simulate stdout with trailing empty string
    -- Standard nvim behavior for newline
    opts.on_stdout(job_id, {"line1", ""}, "stdout")
    -- Simulate stdout chunking
    opts.on_stdout(job_id, {"line2"}, "stdout")

    opts.on_stderr(job_id, {"error1", ""}, "stderr")
    opts.on_exit(job_id, 0, "exit")

    -- Check stdout
    assert.eq(#stdout_data, 2, "stdout called twice")
    assert.eq(stdout_data[1][1], "line1", "stdout 1 line 1")
    -- Should strip trailing empty
    assert.eq(#stdout_data[1], 1, "stdout 1 length")
    assert.eq(stdout_data[2][1], "line2", "stdout 2 line 1")

    -- Check stderr
    assert.eq(#stderr_data, 1, "stderr called")
    assert.eq(stderr_data[1][1], "error1", "stderr line 1")
    assert.eq(#stderr_data[1], 1, "stderr length")

    assert.eq(exit_code, 0, "exit code")
  end)

  restore()
  if not ok then error(err) end
end

local function test_callbacks_merge_partial_chunks()
  local state, restore = mock_vim_job()
  package.loaded["android.command.job"] = nil
  local job = require("android.command.job")

  local ok, err = pcall(function()
    local stdout_data = {}
    local stderr_data = {}

    local j = job.spawn("echo hello", {
      on_stdout = function(lines)
        table.insert(stdout_data, lines)
      end,
      on_stderr = function(lines)
        table.insert(stderr_data, lines)
      end,
    })

    local opts = state.jobs[j.id].opts

    opts.on_stdout(j.id, { "part" }, "stdout")
    assert.eq(#stdout_data, 0, "stdout partial buffered")

    opts.on_stdout(j.id, { "ial", "" }, "stdout")
    assert.eq(#stdout_data, 1, "stdout merged callback")
    assert.table_eq(stdout_data[1], { "partial" }, "stdout merged line")

    opts.on_stderr(j.id, { "err" }, "stderr")
    assert.eq(#stderr_data, 0, "stderr partial buffered")

    opts.on_stderr(j.id, { "or", "" }, "stderr")
    assert.eq(#stderr_data, 1, "stderr merged callback")
    assert.table_eq(stderr_data[1], { "error" }, "stderr merged line")
  end)

  restore()
  if not ok then error(err) end
end

local function test_stop_calls_jobstop()
  local state, restore = mock_vim_job()
  package.loaded["android.command.job"] = nil
  local job = require("android.command.job")

  local ok, err = pcall(function()
    local j = job.spawn("echo hello", {})
    j.stop()
    
    local job_id = j.id
    assert.eq(state.jobs[job_id].stopped, true, "job stopped")
  end)

  restore()
  if not ok then error(err) end
end

function M.run()
  test_spawn_starts_job()
  test_spawn_returns_failure_for_jobstart_zero()
  test_spawn_returns_failure_for_jobstart_negative()
  test_callbacks_are_triggered()
  test_callbacks_merge_partial_chunks()
  test_stop_calls_jobstop()
end

return M
