local M = {}

local assert = require("tests.helpers.assert")

local function exposes_shell_configs()
  local provider = require("android.run.providers.shell")
  local workspace = { root = "/workspace" }
  local list = provider.detect(workspace, {}, {
    configs = {
      { id = "web", label = "Web", command = "pnpm dev" },
    },
  })

  assert.eq(#list, 1, "one shell config")
  assert.eq(list[1].target, "shell", "shell target")
  assert.eq(list[1].meta.command, "pnpm dev", "shell command")
end

local function exposes_shell_args()
  local provider = require("android.run.providers.shell")
  local workspace = { root = "/workspace" }
  local list = provider.detect(workspace, {}, {
    configs = {
      { id = "api", label = "API", args = { "pnpm", "dev", "--port", "3000" } },
    },
  })

  assert.eq(#list, 1, "one shell config")
  assert.table_eq(list[1].meta.args, { "pnpm", "dev", "--port", "3000" }, "shell args")
end

function M.run()
  exposes_shell_configs()
  exposes_shell_args()
end

return M
