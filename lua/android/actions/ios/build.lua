local M = {}

local runner_module = require("android.command.runner")
local ios_build = require("android.build.ios")
local context = require("android.actions.context")

local function resolve_ios_workspace()
  local workspace = context.workspace()
  if not workspace or not workspace.ios then
    vim.notify("iOS workspace not found", vim.log.levels.WARN)
    return nil
  end
  return workspace.ios
end

function M.build()
  local ios = resolve_ios_workspace()
  if not ios then
    return
  end
  local runner = runner_module.new()
  ios_build.build(ios, runner)
end

function M.deploy()
  local ios = resolve_ios_workspace()
  if not ios then
    return
  end
  local runner = runner_module.new()
  ios_build.deploy(ios, runner)
end

return M
