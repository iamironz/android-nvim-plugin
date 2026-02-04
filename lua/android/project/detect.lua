local M = {}

local gradle_workspace = require("android.gradle.workspace")

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
  return stat ~= nil
end

local function default_read(path)
  local ok, lines = pcall(vim.fn.readfile, path)
  if not ok then
    return nil
  end
  return lines
end

local function default_scandir(path)
  local handle = vim.loop.fs_scandir(path)
  if not handle then
    return {}
  end

  local entries = {}
  while true do
    local name, entry_type = vim.loop.fs_scandir_next(handle)
    if not name then
      break
    end
    table.insert(entries, { name = name, type = entry_type })
  end
  return entries
end

local function normalize_module_path(module)
  if not module or module == "" then
    return nil
  end
  local normalized = module
  if normalized:sub(1, 1) == ":" then
    normalized = normalized:sub(2)
  end
  return normalized:gsub(":", "/")
end

local function is_comment(line)
  local trimmed = line:match("^%s*(.-)%s*$") or ""
  return trimmed:match("^//") or trimmed:match("^#")
end

local function contains_tokens(lines, tokens)
  for _, line in ipairs(lines or {}) do
    local trimmed = line:match("^%s*(.-)%s*$") or ""
    if not is_comment(trimmed) then
      for _, token in ipairs(tokens or {}) do
        if trimmed:find(token, 1, true) then
          return true
        end
      end
    end
  end
  return false
end

local function build_paths(root, module)
  local base = root
  if module and module ~= "" then
    local module_path = normalize_module_path(module)
    if module_path and module_path ~= "" then
      base = root .. "/" .. module_path
    end
  end
  return { base .. "/build.gradle.kts", base .. "/build.gradle" }
end

local function read_first(candidates, exists, read)
  local check = exists or default_exists
  local reader = read or default_read
  for _, path in ipairs(candidates or {}) do
    if check(path) then
      local lines = reader(path)
      if lines then
        return lines
      end
    end
  end
  return nil
end

local function collect_build_lines(root, modules, exists, read)
  local lines = {}
  local function add(file_lines)
    for _, line in ipairs(file_lines or {}) do
      table.insert(lines, line)
    end
  end

  add(read_first(build_paths(root, nil), exists, read))
  for _, module in ipairs(modules or {}) do
    add(read_first(build_paths(root, module), exists, read))
  end
  return lines
end

local function entry_with_suffix(entries, suffix)
  for _, entry in ipairs(entries or {}) do
    local name = entry.name or entry[1]
    if name and name:sub(-#suffix) == suffix then
      return name
    end
  end
  return nil
end

local function ios_markers(dir, exists, scandir)
  local check = exists or default_exists
  local scan = scandir or default_scandir
  local package = nil
  if check(dir .. "/Package.swift") then
    package = dir .. "/Package.swift"
  end

  local entries = scan(dir) or {}
  local project_name = entry_with_suffix(entries, ".xcodeproj")
  local workspace_name = entry_with_suffix(entries, ".xcworkspace")
  local project = project_name and (dir .. "/" .. project_name) or nil
  local workspace = workspace_name and (dir .. "/" .. workspace_name) or nil

  if package or project or workspace then
    return {
      root = dir,
      package = package,
      project = project,
      workspace = workspace,
    }
  end
  return nil
end

local function find_ios_upwards(start_path, exists, scandir)
  local current = strip_trailing_slash(start_path)
  while current do
    local markers = ios_markers(current, exists, scandir)
    if markers then
      return markers
    end

    local parent = parent_dir(current)
    if not parent or parent == current then
      return nil
    end
    current = parent
  end

  return nil
end

local function detect_ios(start_path, gradle_root, exists, scandir)
  if gradle_root then
    local candidates = {
      gradle_root,
      gradle_root .. "/ios",
      gradle_root .. "/iosApp",
    }
    for _, dir in ipairs(candidates) do
      local markers = ios_markers(dir, exists, scandir)
      if markers then
        return markers
      end
    end
  end

  return find_ios_upwards(start_path, exists, scandir)
end

function M.detect(start_path, opts)
  local options = opts or {}
  local exists = options.exists or default_exists
  local read = options.read or default_read
  local scandir = options.scandir or default_scandir

  local gradle_root = gradle_workspace.find_root(start_path, exists)
  local modules = {}
  if gradle_root then
    modules = gradle_workspace.load_modules(gradle_root, read)
  end

  local gradle = gradle_root and { root = gradle_root, modules = modules } or nil
  local android = nil
  local kmp = nil

  if gradle_root then
    local lines = collect_build_lines(gradle_root, modules, exists, read)
    if contains_tokens(lines, {
      "com.android.application",
      "com.android.library",
      "alias(libs.plugins.android.application)",
      "alias(libs.plugins.android.library)",
      "libs.plugins.android.application",
      "libs.plugins.android.library",
      "libs.plugins.androidApplication",
      "libs.plugins.androidLibrary",
      "androidApplication",
      "androidLibrary",
      "namespace",
    }) then
      android = { root = gradle_root, modules = modules }
    end
    if contains_tokens(lines, {
      "kotlin(\"multiplatform\")",
      "kotlin-multiplatform",
      "org.jetbrains.kotlin.multiplatform",
      "alias(libs.plugins.kotlin.multiplatform)",
      "libs.plugins.kotlin.multiplatform",
      "libs.plugins.kotlinMultiplatform",
      "kotlinMultiplatform",
    }) then
      kmp = { root = gradle_root }
    end
  end

  local ios = detect_ios(start_path, gradle_root, exists, scandir)
  local root = gradle_root or (ios and ios.root) or nil
  if not root then
    return nil
  end

  return {
    root = root,
    modules = modules,
    gradle = gradle,
    android = android,
    kmp = kmp,
    ios = ios,
  }
end

return M
