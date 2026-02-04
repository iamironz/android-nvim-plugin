local M = {}

local assert = require("tests.helpers.assert")
local processes = require("android.logcat.processes")

local function parses_dotted_names_and_sorts_unique()
  local result = processes.parse({
    "USER PID PPID VSZ RSS WCHAN ADDR S NAME",
    "u0_a123 123 456 0 0 0 0 0 0 com.beta.app",
    "u0_a124 124 456 0 0 0 0 0 0 com.alpha.app",
    "u0_a125 125 456 0 0 0 0 0 0 com.alpha.app",
    "root 1 0 0 0 0 0 0 0 0 zygote",
    "",
  })

  assert.table_eq(result, { "com.alpha.app", "com.beta.app" }, "sorted unique packages")
end

local function list_packages_runs_adb_shell_ps()
  local received = { cmd = nil }
  local runner = {
    run = function(cmd)
      received.cmd = cmd
      return {
        ok = true,
        stdout = "u0_a123 123 456 0 0 0 0 0 0 com.beta.app\n"
          .. "u0_a124 124 456 0 0 0 0 0 0 com.alpha.app\n",
        stderr = "",
      }
    end,
  }

  local result = processes.list_packages(runner, "/sdk/adb", "device-1")

  assert.table_eq(result, { "com.alpha.app", "com.beta.app" }, "list packages")
  assert.table_eq(received.cmd, { "/sdk/adb", "-s", "device-1", "shell", "ps" }, "adb cmd")
end

local function list_packages_returns_empty_on_failure()
  local runner = {
    run = function()
      return { ok = false, stdout = "u0_a123 123 456 com.example.app", stderr = "" }
    end,
  }

  local result = processes.list_packages(runner, "/sdk/adb", "device-1")

  assert.table_eq(result, {}, "failure returns empty")
end

function M.run()
  parses_dotted_names_and_sorts_unique()
  list_packages_runs_adb_shell_ps()
  list_packages_returns_empty_on_failure()
end

return M
