local M = {}
local project_config = require("android.project.config")

function M.load(workspace, opts)
  return project_config.load(workspace, opts)
end

function M.shell_configs(workspace, opts)
  if opts and opts.configs then
    return opts.configs
  end
  local data = M.load(workspace, opts)
  local run = data.run or {}
  local shell = run.shell
  if type(shell) ~= "table" then
    return {}
  end
  return shell
end

return M
