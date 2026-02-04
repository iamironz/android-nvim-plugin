local M = {}

local apk = require("android.build.apk")
local deploy = require("android.build.deploy")
local defaults = require("android.actions.defaults")

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

local function manifest_path(root, module)
  if not root or root == "" then
    return nil
  end

  local module_dir = normalize_module_path(module)
  if not module_dir or module_dir == "" then
    return nil
  end

  return root .. "/" .. module_dir .. "/src/main/AndroidManifest.xml"
end

local function build_gradle_paths(root, module)
  if not root or root == "" then
    return {}
  end
  local module_dir = normalize_module_path(module)
  if not module_dir or module_dir == "" then
    return {}
  end
  local base = root .. "/" .. module_dir
  return { base .. "/build.gradle.kts", base .. "/build.gradle" }
end

local function default_exists(path)
  local stat = vim.loop.fs_stat(path)
  return stat ~= nil and stat.type == "file"
end

local function default_readfile(path)
  local ok, lines = pcall(vim.fn.readfile, path)
  if not ok then
    return nil
  end
  return lines
end

local function latest_apk_path(entries)
  local entry = entries and entries[1]
  if type(entry) == "table" then
    return entry.path
  end
  if type(entry) == "string" then
    return entry
  end
  return nil
end

local function resolve_apk_package(root, modules, options)
  if not root or root == "" then
    return nil
  end

  local list_apks = options.list_apks or apk.list_workspace_apks
  local result = list_apks(root, modules)
  if not result or not result.ok then
    return nil
  end

  local apk_path = latest_apk_path(result.apks or {})
  if not apk_path or apk_path == "" then
    return nil
  end

  local resolve_app_id = options.resolve_app_id or deploy.resolve_app_id
  local resolved = resolve_app_id(apk_path, options.aapt2_path, options.runner)
  if not resolved or not resolved.ok then
    return nil
  end

  local app_id = resolved.app_id
  if not app_id or app_id == "" then
    return nil
  end

  return app_id
end

local function parse_manifest_package(lines)
  for _, line in ipairs(lines or {}) do
    local package_name = line:match("package%s*=%s*\"([^\"]+)\"")
    if package_name and package_name ~= "" then
      return package_name
    end
  end
  return nil
end

local function parse_namespace(lines)
  for _, line in ipairs(lines or {}) do
    local namespace = line:match("namespace%s*=%s*\"([^\"]+)\"")
      or line:match("namespace%s*=%s*'([^']+)'")
      or line:match("namespace%s+\"([^\"]+)\"")
      or line:match("namespace%s+'([^']+)'")
    if namespace and namespace ~= "" then
      return namespace
    end
  end
  return nil
end

local function parse_application_id(lines)
  for _, line in ipairs(lines or {}) do
    local app_id = line:match("applicationId%s*%(%s*\"([^\"]+)\"%s*%)")
      or line:match("applicationId%s*%(%s*'([^']+)'%s*%)")
      or line:match("applicationId%s*=%s*\"([^\"]+)\"")
      or line:match("applicationId%s*=%s*'([^']+)'")
      or line:match("applicationId%s+\"([^\"]+)\"")
      or line:match("applicationId%s+'([^']+)'")
    if app_id and app_id ~= "" then
      return app_id
    end
  end
  return nil
end

local function read_first(candidates, exists, readfile)
  local check = exists or default_exists
  local reader = readfile or default_readfile
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

local function default_module(modules)
  return defaults.select_module(modules)
end

function M.resolve_default_package(opts)
  local options = opts or {}
  local saved = options.saved_package
  if saved and saved ~= "" then
    return saved
  end

  local workspace = options.workspace or {}
  local root = options.root or workspace.root
  if not root or root == "" then
    return nil
  end

  local app_id = resolve_apk_package(root, workspace.modules, options)
  if app_id then
    return app_id
  end

  local module = options.module or default_module(workspace.modules)
  if not module or module == "" then
    return nil
  end

  local exists = options.exists or default_exists
  local readfile = options.readfile or default_readfile

  local manifest = manifest_path(root, module)
  if manifest and exists(manifest) then
    local lines = readfile(manifest)
    if lines then
      local package_name = parse_manifest_package(lines)
      if package_name then
        return package_name
      end
    end
  end

  local gradle_lines = read_first(build_gradle_paths(root, module), exists, readfile)
  if not gradle_lines then
    return nil
  end

  local app_id = parse_application_id(gradle_lines)
  if app_id then
    return app_id
  end

  return parse_namespace(gradle_lines)
end

return M
