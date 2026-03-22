local gradle_tasks = require("android.gradle.tasks")

local M = {}

local function lower_first(value)
  if not value or value == "" then
    return value
  end
  return value:sub(1, 1):lower() .. value:sub(2)
end

local function parse_module_task(task)
  if not task or task == "" then
    return nil, nil
  end

  local module, name = task:match("^:?(.-):([^:]+)$")
  if not module or module == "" or not name then
    return nil, nil
  end

  return ":" .. module, name
end

local function variant_from_task_name(name)
  if not name or name == "" then
    return nil
  end
  if name:match("AndroidTest$") or name:match("UnitTest$") then
    return nil
  end

  local raw = name:match("^assemble(%u[%w]+)$")
    or name:match("^bundle(%u[%w]+)$")
    or name:match("^install(%u[%w]+)$")
  if not raw then
    return nil
  end

  return lower_first(raw)
end

local function sorted_keys(map)
  local result = {}
  for key in pairs(map or {}) do
    result[#result + 1] = key
  end
  table.sort(result)
  return result
end

function M.parse(lines)
  local by_module = {}

  for _, entry in ipairs(gradle_tasks.parse(lines)) do
    local module, name = parse_module_task(entry.name)
    local variant = variant_from_task_name(name)
    if module and variant then
      local module_entry = by_module[module]
      if not module_entry then
        module_entry = {
          module = module,
          variants = {},
          _variants = {},
        }
        by_module[module] = module_entry
      end
      module_entry._variants[variant] = true
    end
  end

  local modules = sorted_keys(by_module)
  for _, module in ipairs(modules) do
    local module_entry = by_module[module]
    module_entry.variants = sorted_keys(module_entry._variants)
    module_entry._variants = nil
  end

  return {
    android = {
      modules = modules,
      by_module = by_module,
    },
  }
end

return M
