local M = {}

local strings = require("android.utils.strings")

function M.parse_devices(lines)
  local devices = {}

  for _, line in ipairs(lines or {}) do
    local trimmed = strings.trim(line)
    if trimmed == "" or trimmed:match("^List of devices attached") then
      goto continue
    end

    local serial, state, rest = trimmed:match("^(%S+)%s+(%S+)%s*(.*)$")
    if not serial or not state then
      goto continue
    end

    local entry = { serial = serial, state = state }
    for token in rest:gmatch("%S+") do
      local key, value = token:match("([^:]+):(.+)")
      if key and value then
        entry[key] = value
      end
    end

    table.insert(devices, entry)
    ::continue::
  end

  return devices
end

function M.list(runner, adb_path)
  if not runner or not adb_path then
    return {}
  end

  local result = runner.run({ adb_path, "devices", "-l" })
  local stdout = result and result.stdout or ""
  local lines = vim.split(stdout, "\n", { plain = true })
  return M.parse_devices(lines)
end

return M
