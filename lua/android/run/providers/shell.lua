local user_configs = require("android.run.user_configs")

local M = {}

function M.detect(workspace, _, opts)
  local configs = user_configs.shell_configs(workspace, opts)
  local list = {}
  for _, entry in ipairs(configs or {}) do
    local has_command = entry and entry.command and entry.command ~= ""
    local has_args = entry and type(entry.args) == "table" and #entry.args > 0
    if entry and entry.id and (has_command or has_args) then
      list[#list + 1] = {
        id = "shell:" .. entry.id,
        label = entry.label or entry.id,
        target = "shell",
        type = "shell",
        meta = {
          command = entry.command,
          args = entry.args,
        },
      }
    end
  end
  return list
end

return M
