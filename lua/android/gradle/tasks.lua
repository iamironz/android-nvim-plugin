local M = {}

local function trim(value)
  if not value then
    return ""
  end
  return (value:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function parse_line(line)
  if type(line) ~= "string" then
    return nil
  end

  local trimmed = trim(line)
  if trimmed == "" then
    return nil
  end
  if trimmed:match("^%-+$") then
    return nil
  end

  local name, desc = trimmed:match("^([^%s]+)%s+%-%s*(.*)$")
  if name and name ~= "" then
    return { name = name, description = trim(desc) }
  end

  if trimmed:match("%s") then
    return nil
  end

  return { name = trimmed, description = "" }
end

local function task_name(line)
  local entry = parse_line(line)
  return entry and entry.name or nil
end

local function module_from_task(task, patterns)
  if not task or task == "" then
    return nil
  end
  local module, name = task:match("^:?(.-):([^:]+)$")
  if not module or not name then
    return nil
  end
  local lowered = name:lower()
  if lowered:match("androidtest") or lowered:match("unittest") then
    return nil
  end
  for _, pattern in ipairs(patterns or {}) do
    if name:match(pattern) then
      return ":" .. module
    end
  end
  return nil
end

function M.parse(lines)
  local entries = {}
  local seen = {}

  for _, line in ipairs(lines or {}) do
    local entry = parse_line(line)
    if entry and not seen[entry.name] then
      seen[entry.name] = entry
    end
  end

  for _, entry in pairs(seen) do
    table.insert(entries, entry)
  end

  table.sort(entries, function(a, b)
    return a.name < b.name
  end)

  return entries
end

local function collect_modules(lines, patterns)
  local modules = {}
  for _, line in ipairs(lines or {}) do
    local task = task_name(line)
    local module = module_from_task(task, patterns)
    if module then
      modules[module] = true
    end
  end

  local result = {}
  for module in pairs(modules) do
    result[#result + 1] = module
  end
  table.sort(result)
  return result
end

function M.android_modules(lines)
  local install_modules = collect_modules(lines, { "^install%u" })
  if #install_modules > 0 then
    return install_modules
  end
  return collect_modules(lines, { "^assemble%u", "^bundle%u" })
end

return M
