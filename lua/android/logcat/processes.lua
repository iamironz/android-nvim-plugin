local M = {}

local strings = require("android.utils.strings")

local function last_column(line)
  local trimmed = strings.trim(line)
  if trimmed == "" then
    return nil
  end
  return trimmed:match("(%S+)%s*$")
end

function M.parse(lines)
  local names = {}
  for _, line in ipairs(lines or {}) do
    local name = last_column(line)
    if name and name:find("%.") then
      names[name] = true
    end
  end

  local result = {}
  for name in pairs(names) do
    table.insert(result, name)
  end
  table.sort(result)
  return result
end

function M.list_packages(runner, adb_path, serial)
  if not runner or not adb_path then
    return {}
  end

  local cmd = { adb_path }
  if serial and serial ~= "" then
    table.insert(cmd, "-s")
    table.insert(cmd, serial)
  end
  table.insert(cmd, "shell")
  table.insert(cmd, "ps")

  local result = runner.run(cmd)
  if not result or not result.ok then
    return {}
  end

  local lines = vim.split(result.stdout or "", "\n", { plain = true })
  return M.parse(lines)
end

return M
