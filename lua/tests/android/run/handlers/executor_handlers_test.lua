local M = {}

local assert = require("tests.helpers.assert")
local stubs_helper = require("tests.helpers.stubs")

local function run_shell_prefers_args_list()
  local called = { root = nil, args = nil }
  local stubs = {
    ["android.actions.build"] = { build_default = function() end },
    ["android.actions.context"] = { save_state = function() end },
    ["android.actions.gradle_tasks"] = { open = function() end },
    ["android.actions.ios.build"] = { deploy = function() end },
    ["android.actions.build_helpers"] = { build_command = function() return {} end },
    ["android.build.stream"] = {
      start_build_job = function(root, args)
        called.root = root
        called.args = args
        return { stop = function() end }
      end,
    },
    ["android.state.selection_defaults"] = {
      apply_build_defaults = function(state)
        return state
      end,
    },
  }

  stubs_helper.with_stubs(stubs, function()
    package.loaded["android.run.executor_handlers"] = nil
    local handlers = require("android.run.executor_handlers")
    handlers.run(
      { root = "/workspace" },
      { type = "shell", meta = { args = { "pnpm", "dev", "--port", "3000" } } },
      {}
    )
  end)

  assert.eq(called.root, "/workspace", "root passed")
  assert.table_eq(called.args, { "pnpm", "dev", "--port", "3000" }, "args passed")
end

function M.run()
  run_shell_prefers_args_list()
end

return M
