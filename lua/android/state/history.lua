local strings = require("android.utils.strings")

local M = {}

local function normalize(value)
  return strings.trim(tostring(value or ""))
end

function M.push(list, value, opts)
  local options = opts or {}
  local limit = options.limit or 20
  local next_value = normalize(value)
  local result = {}
  local seen = {}

  if next_value ~= "" then
    result[#result + 1] = next_value
    seen[next_value] = true
  end

  for _, entry in ipairs(list or {}) do
    local normalized = normalize(entry)
    if normalized ~= "" and not seen[normalized] then
      result[#result + 1] = normalized
      seen[normalized] = true
    end
  end

  while #result > limit do
    table.remove(result)
  end
  return result
end

return M
