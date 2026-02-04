local M = {}

local assert = require("tests.helpers.assert")

local function detects_jvm_run_tasks()
  local provider = require("android.run.providers.jvm")
  local workspace = { root = "/workspace", gradle = { root = "/workspace" } }
  local tasks = {
    ":server:run - Runs",
    ":androidApp:assembleDebug - Builds",
  }

  local list = provider.detect(workspace, {}, { tasks = tasks })
  assert.eq(#list, 1, "one jvm config")
  assert.eq(list[1].target, "jvm", "jvm target")
  assert.eq(list[1].meta.module, ":server", "module")
  assert.eq(list[1].meta.task, ":server:run", "task")
end

function M.run()
  detects_jvm_run_tasks()
end

return M
