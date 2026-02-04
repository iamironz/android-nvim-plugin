local M = {}

local assert = require("tests.helpers.assert")

local function exposes_gradle_task_config()
  local provider = require("android.run.providers.gradle_task")
  local workspace = { root = "/workspace", gradle = { root = "/workspace" } }
  local list = provider.detect(workspace, {})

  assert.eq(#list, 1, "one task config")
  assert.eq(list[1].target, "gradle", "gradle target")
  assert.eq(list[1].type, "gradle_task", "task type")
end

function M.run()
  exposes_gradle_task_config()
end

return M
