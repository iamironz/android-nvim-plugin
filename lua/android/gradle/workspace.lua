local M = {}

local function strip_trailing_slash(path)
  if not path then
    return nil
  end
  return (path:gsub("/+$", ""))
end

local function parent_dir(path)
  if not path then
    return nil
  end

  local normalized = strip_trailing_slash(path)
  local parent = normalized:match("^(.*)/[^/]+$")
  if parent == "" then
    return nil
  end
  return parent
end

local function default_exists(path)
  local stat = vim.loop.fs_stat(path)
  return stat ~= nil and stat.type == "file"
end

local function default_read(path)
  local ok, lines = pcall(vim.fn.readfile, path)
  if not ok then
    return nil
  end
  return lines
end

local function has_settings(path, exists)
  return exists(path .. "/settings.gradle") or exists(path .. "/settings.gradle.kts")
end

function M.find_root(start_path, exists)
  local current = strip_trailing_slash(start_path)
  local check = exists or default_exists

  while current do
    if has_settings(current, check) then
      return current
    end

    local parent = parent_dir(current)
    if not parent or parent == current then
      return nil
    end
    current = parent
  end

  return nil
end

function M.parse_settings(lines)
  local modules = {}
  for _, line in ipairs(lines or {}) do
    local trimmed = line:match("^%s*(.-)%s*$") or ""
    if trimmed:match("^//") or trimmed:match("^#") then
      goto continue
    end
    if not trimmed:match("^%s*include%s*") then
      goto continue
    end
    if trimmed:match("^%s*includeBuild%s*") then
      goto continue
    end

    for module in trimmed:gmatch("['\"](:[^'\"]+)['\"]") do
      modules[module] = true
    end

    ::continue::
  end

  local result = {}
  for module in pairs(modules) do
    table.insert(result, module)
  end
  table.sort(result)
  return result
end

function M.load_modules(root, read)
  local reader = read or default_read
  local lines = reader(root .. "/settings.gradle")
  if not lines then
    lines = reader(root .. "/settings.gradle.kts")
  end
  if not lines then
    return {}
  end
  return M.parse_settings(lines)
end

function M.detect(start_path, opts)
  local exists = opts and opts.exists or nil
  local read = opts and opts.read or nil
  local root = M.find_root(start_path, exists)
  if not root then
    return nil
  end

  local modules = M.load_modules(root, read)
  return { root = root, modules = modules }
end

return M
