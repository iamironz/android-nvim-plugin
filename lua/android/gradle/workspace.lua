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

local function read_settings_lines(root, read)
  local reader = read or default_read
  local lines = reader(root .. "/settings.gradle")
  if lines then
    return lines
  end
  return reader(root .. "/settings.gradle.kts")
end

local function has_settings(path, exists)
  return exists(path .. "/settings.gradle") or exists(path .. "/settings.gradle.kts")
end

local function normalize_path(path)
  if not path or path == "" then
    return nil
  end
  local absolute = path:sub(1, 1) == "/"
  local parts = {}
  for segment in path:gmatch("[^/]+") do
    if segment == "." or segment == "" then
      goto continue
    end
    if segment == ".." then
      if #parts > 0 and parts[#parts] ~= ".." then
        table.remove(parts)
      elseif not absolute then
        parts[#parts + 1] = segment
      end
      goto continue
    end
    parts[#parts + 1] = segment
    ::continue::
  end

  local joined = table.concat(parts, "/")
  if absolute then
    joined = "/" .. joined
  end
  if joined == "" then
    return absolute and "/" or "."
  end
  return joined
end

local function resolve_path(base, value)
  if not value or value == "" then
    return nil
  end
  if value:sub(1, 1) == "/" then
    return strip_trailing_slash(normalize_path(value))
  end
  return strip_trailing_slash(normalize_path(base .. "/" .. value))
end

local function path_basename(path)
  if not path or path == "" then
    return nil
  end
  local normalized = strip_trailing_slash(path)
  return normalized:match("([^/]+)$")
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

function M.parse_include_builds(lines)
  local builds = {}
  local seen = {}
  for _, line in ipairs(lines or {}) do
    local inspected = line:gsub("%s*//.*$", ""):gsub("%s*#.*$", "")
    local rel = inspected:match('includeBuild%s*%(%s*["\']([^"\']+)["\']%s*%)')
      or inspected:match('includeBuild%s+["\']([^"\']+)["\']')
    if rel and rel ~= "" and not seen[rel] then
      seen[rel] = true
      builds[#builds + 1] = rel
    end
  end
  table.sort(builds)
  return builds
end

function M.load_included_builds(root, read)
  local lines = read_settings_lines(root, read)
  if not lines then
    return {}
  end

  local result = {}
  local seen = {}
  for _, rel_path in ipairs(M.parse_include_builds(lines)) do
    local name = path_basename(rel_path)
    local resolved_root = resolve_path(root, rel_path)
    if name and name ~= "" and resolved_root and not seen[name] then
      seen[name] = true
      result[#result + 1] = {
        name = name,
        root = resolved_root,
        path = rel_path,
      }
    end
  end

  table.sort(result, function(a, b)
    return a.name < b.name
  end)
  return result
end

local function collect_modules_recursive(root, read, prefix, visited, modules, seen_modules)
  local build_root = strip_trailing_slash(root)
  if not build_root or build_root == "" or visited[build_root] then
    return
  end
  visited[build_root] = true

  local lines = read_settings_lines(build_root, read)
  if not lines then
    return
  end

  for _, module in ipairs(M.parse_settings(lines)) do
    local qualified = module
    if prefix and prefix ~= "" then
      qualified = prefix .. module
    end
    if not seen_modules[qualified] then
      seen_modules[qualified] = true
      modules[#modules + 1] = qualified
    end
  end

  for _, rel_path in ipairs(M.parse_include_builds(lines)) do
    local include_name = path_basename(rel_path)
    local include_root = resolve_path(build_root, rel_path)
    if include_name and include_root then
      local include_prefix = ":" .. include_name
      if prefix and prefix ~= "" then
        include_prefix = prefix .. ":" .. include_name
      end
      collect_modules_recursive(
        include_root,
        read,
        include_prefix,
        visited,
        modules,
        seen_modules
      )
    end
  end
end

function M.load_modules(root, read)
  local reader = read or default_read
  local modules = {}
  local seen_modules = {}
  local visited = {}
  collect_modules_recursive(root, reader, nil, visited, modules, seen_modules)
  table.sort(modules)
  return modules
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
