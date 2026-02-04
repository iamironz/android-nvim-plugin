local M = {}

local assert = require("tests.helpers.assert")

local function build_runner(response)
  local received = { cmd = nil, opts = nil }
  local exec = function(cmd, opts)
    received.cmd = cmd
    received.opts = opts
    return response
  end
  local runner = require("android.command.runner").new(exec)
  return runner, received
end

local function returns_success_result_for_zero_exit()
  local runner, received = build_runner({ code = 0, stdout = "ok", stderr = "" })
  local result = runner.run("./gradlew tasks")

  assert.is_true(result.ok, "run ok")
  assert.eq(result.code, 0, "run code")
  assert.eq(result.stdout, "ok", "run stdout")
  assert.eq(result.stderr, "", "run stderr")
  assert.eq(received.cmd, "./gradlew tasks", "run cmd")
end

local function returns_failure_result_for_nonzero_exit()
  local runner = build_runner({ code = 1, stdout = "", stderr = "nope" })
  local result = runner.run("./gradlew missing")

  assert.eq(result.ok, false, "run failed ok")
  assert.eq(result.code, 1, "run failed code")
  assert.eq(result.stderr, "nope", "run failed stderr")
end

local function rejects_nil_command()
  local runner = build_runner({ code = 0, stdout = "", stderr = "" })
  local result = runner.run(nil)

  assert.eq(result.ok, false, "invalid ok")
  assert.eq(result.code, 1, "invalid code")
  assert.contains(result.stderr, "invalid", "invalid stderr")
end

local function passes_cwd_to_exec()
  local runner, received = build_runner({ code = 0, stdout = "", stderr = "" })
  runner.run({ "./gradlew", "tasks" }, { cwd = "/repo" })

  assert.eq(received.opts and received.opts.cwd, "/repo", "cwd passed")
end

function M.run()
  returns_success_result_for_zero_exit()
  returns_failure_result_for_nonzero_exit()
  rejects_nil_command()
  passes_cwd_to_exec()
end

return M
