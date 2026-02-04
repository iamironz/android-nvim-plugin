local M = {}

local state_cache = require("android.state.cache")

local default_cache = state_cache.new()
local module_stamp_limit = 200

local function normalize_module_path(module)
  if not module or module == "" then
    return nil
  end
  local normalized = module
  if normalized:sub(1, 1) == ":" then
    normalized = normalized:sub(2)
  end
  if normalized == "" then
    return nil
  end
  return normalized:gsub(":", "/")
end

local function settings_paths(root)
  return { root .. "/settings.gradle", root .. "/settings.gradle.kts" }
end

local function root_build_paths(root)
  return { root .. "/build.gradle", root .. "/build.gradle.kts" }
end

local function module_build_paths(root, modules)
  local paths = {}
  for _, module in ipairs(modules or {}) do
    local module_path = normalize_module_path(module)
    if module_path then
      table.insert(paths, root .. "/" .. module_path .. "/build.gradle")
      table.insert(paths, root .. "/" .. module_path .. "/build.gradle.kts")
    end
  end
  return paths
end

local function workspace_paths(root, modules)
  local paths = {}
  for _, path in ipairs(settings_paths(root)) do
    table.insert(paths, path)
  end
  for _, path in ipairs(root_build_paths(root)) do
    table.insert(paths, path)
  end
  for _, path in ipairs(module_build_paths(root, modules)) do
    table.insert(paths, path)
  end
  return paths
end

local function stamp_paths(root, modules)
  if modules and #modules > module_stamp_limit then
    return workspace_paths(root, nil)
  end
  if modules and #modules > 0 then
    return workspace_paths(root, modules)
  end
  return workspace_paths(root, nil)
end

function M.persistent(opts)
  local options = opts or {}
  local store = state_cache.workspace_store(options)
  local cache = state_cache.new({ store = store })
  return M.new({ cache = cache, stat = options.stat })
end

function M.new(opts)
  local cache = opts and opts.cache or default_cache
  local stat = opts and opts.stat or nil
  local api = {}

  function api.modules(root, loader)
    if not root or root == "" then
      return loader()
    end
    local stamp = state_cache.files_stamp(stamp_paths(root, nil), stat)
    return cache.fetch(root, "modules", stamp, loader)
  end

  function api.tasks(root, modules, loader)
    if not root or root == "" then
      return loader()
    end
    local stamp = state_cache.files_stamp(stamp_paths(root, modules), stat)
    return cache.fetch(root, "tasks", stamp, loader)
  end

  function api.variants(root, modules, loader)
    if not root or root == "" then
      return loader()
    end
    local stamp = state_cache.files_stamp(stamp_paths(root, modules), stat)
    return cache.fetch(root, "variants", stamp, loader)
  end

  function api.android_modules(root, modules, loader)
    if not root or root == "" then
      return loader()
    end
    local stamp = state_cache.files_stamp(stamp_paths(root, modules), stat)
    return cache.fetch(root, "android_modules", stamp, loader)
  end

  return api
end

return M
