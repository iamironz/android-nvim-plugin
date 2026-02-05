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
  local in_include = false
  local in_parens = false
  for _, line in ipairs(lines or {}) do
    local trimmed = line:match("^%s*(.-)%s*$") or ""
    local inspected = trimmed:gsub("%s*//.*$", ""):gsub("%s*#.*$", "")
    if trimmed:match("^//") or trimmed:match("^#") then
      goto continue
    end
    if inspected:match("^%s*includeBuild%s*") then
      goto continue
    end

    local include_line = inspected:match("^%s*include%s*") ~= nil
    if include_line then
      in_include = true
      if inspected:find("%(") and not inspected:find("%)") then
        in_parens = true
      end
    end

    if in_include then
      for module in inspected:gmatch("['\"](:[^'\"]+)['\"]") do
        modules[module] = true
      end
    end

    if in_include then
      if in_parens then
        if inspected:find("%)") then
          in_parens = false
          in_include = false
        end
      elseif not inspected:match(",%s*$") then
        in_include = false
      end
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
