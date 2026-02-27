local M = {}

local function trim(value)
  return (value or ""):match("^%s*(.-)%s*$") or ""
end

local function parse_included_build_name(line)
  if type(line) ~= "string" then
    return nil
  end
  local name = line:match("Included build%s+['\"]:?([^'\"]+)['\"]")
  if name and name ~= "" then
    return trim(name)
  end
  return nil
end

function M.parse_included_builds(lines)
  local names = {}
  local seen = {}

  for _, line in ipairs(lines or {}) do
    local name = parse_included_build_name(line)
    if name and name ~= "" and not seen[name] then
      seen[name] = true
      names[#names + 1] = name
    end
  end

  table.sort(names)
  return names
end

return M
