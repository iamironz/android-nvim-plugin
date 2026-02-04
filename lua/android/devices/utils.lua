local M = {}

local strings = require("android.utils.strings")

M.trim = strings.trim

function M.runner_stdout_lines(runner, cmd)
  if not runner or not cmd then
    return {}
  end

  local result = runner.run(cmd)
  local stdout = result and result.stdout or ""
  return vim.split(stdout, "\n", { plain = true })
end

return M
