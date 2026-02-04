local M = {}

local function normalize_module_name(module)
  if not module or module == "" then
    return nil
  end
  if module:sub(1, 1) ~= ":" then
    return ":" .. module
  end
  return module
end

local function capitalize(value)
  if not value or value == "" then
    return nil
  end
  return value:sub(1, 1):upper() .. value:sub(2)
end

function M.assemble_task(module, variant)
  local suffix = capitalize(variant)
  if not suffix then
    return nil
  end

  local task = "assemble" .. suffix
  local normalized = normalize_module_name(module)
  if normalized then
    return normalized .. ":" .. task
  end
  return task
end

local function append_task(command, task)
  if type(command) == "table" then
    local result = {}
    for _, part in ipairs(command) do
      table.insert(result, part)
    end
    table.insert(result, task)
    return result
  end
  if type(command) == "string" then
    return { command, task }
  end
  return nil
end

function M.assemble_command(gradle_command, module, variant)
  local task = M.assemble_task(module, variant)
  if not task then
    return nil
  end
  return append_task(gradle_command, task)
end

return M
