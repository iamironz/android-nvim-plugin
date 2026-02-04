local M = {}

local function task_name(line)
  if type(line) ~= "string" then
    return nil
  end
  return line:match("^%s*([^%s]+)")
end

local function last_segment(task)
  if not task then
    return nil
  end
  return task:match("([^:]+)$")
end

local function variant_from_task(task)
  if not task then
    return nil
  end

  local raw = task:match("^assemble(%u[%w]+)$")
    or task:match("^bundle(%u[%w]+)$")
  if not raw then
    return nil
  end

  return raw:sub(1, 1):lower() .. raw:sub(2)
end

function M.parse(lines)
  local variants = {}

  for _, line in ipairs(lines or {}) do
    local task = last_segment(task_name(line))
    local variant = variant_from_task(task)
    if variant then
      variants[variant] = true
    end
  end

  local result = {}
  for variant in pairs(variants) do
    table.insert(result, variant)
  end
  table.sort(result)
  return result
end

return M
