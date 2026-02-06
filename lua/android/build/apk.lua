local M = {}

local config = require("android.config")

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

local function is_dir(path)
  local stat = vim.loop.fs_stat(path)
  return stat ~= nil and stat.type == "directory"
end

local function is_file(path)
  local stat = vim.loop.fs_stat(path)
  return stat ~= nil and stat.type == "file"
end

local function is_android_test_apk(path)
  if not path or path == "" then
    return false
  end
  if path:find("/androidTest/", 1, true) then
    return true
  end
  return path:match("%-androidTest%.apk$") ~= nil
end

local function collect_deployable_apks(paths)
  local filtered = {}
  for _, path in ipairs(paths or {}) do
    if not is_android_test_apk(path) then
      filtered[#filtered + 1] = path
    end
  end
  return filtered
end

local function list_apks(path)
  local handle = vim.loop.fs_scandir(path)
  if not handle then
    return {}
  end

  local files = {}
  while true do
    local name, entry_type = vim.loop.fs_scandir_next(handle)
    if not name then
      break
    end
    if entry_type == "file" and name:match("%.apk$") then
      table.insert(files, path .. "/" .. name)
    end
  end
  return files
end

local function collect_apks_recursive(path, out)
  local handle = vim.loop.fs_scandir(path)
  if not handle then
    return
  end

  while true do
    local name, entry_type = vim.loop.fs_scandir_next(handle)
    if not name then
      break
    end

    local entry = path .. "/" .. name
    if entry_type == "file" then
      if name:match("%.apk$") then
        table.insert(out, entry)
      end
    elseif entry_type == "directory" then
      collect_apks_recursive(entry, out)
    end
  end
end

local function mtime_value(stat)
  if not stat or not stat.mtime then
    return 0
  end
  local seconds = stat.mtime.sec or 0
  local nanos = stat.mtime.nsec or 0
  return seconds * 1000000000 + nanos
end

local function sort_by_mtime(paths)
  local times = {}
  for _, path in ipairs(paths or {}) do
    times[path] = mtime_value(vim.loop.fs_stat(path))
  end
  table.sort(paths, function(a, b)
    return (times[a] or 0) > (times[b] or 0)
  end)
  return paths
end

local function scan_flavor_dirs(base, build_type)
  local handle = vim.loop.fs_scandir(base)
  if not handle then
    return {}
  end
  local dirs = {}
  while true do
    local name, entry_type = vim.loop.fs_scandir_next(handle)
    if not name then
      break
    end
    if entry_type == "directory" and name ~= build_type and name ~= "androidTest" then
      local candidate = base .. "/" .. name .. "/" .. build_type
      if is_dir(candidate) then
        dirs[#dirs + 1] = candidate
      end
    end
  end
  return dirs
end

local function variant_dirs(base, variant)
  if not variant or variant == "" then
    return {}
  end

  local dirs = { base .. "/" .. variant }
  local flavor, build_type = variant:match("^(.*)(%u[%w]+)$")
  if flavor and flavor ~= "" and build_type and build_type ~= "" then
    local path = string.format(
      "%s/%s/%s",
      base,
      flavor:lower(),
      build_type:lower()
    )
    table.insert(dirs, path)
  end

  -- bare build type (e.g. "debug") with product flavors:
  -- APKs live in <base>/<flavor>/<buildType>/ instead of <base>/<buildType>/
  if not flavor or flavor == "" then
    local flavor_candidates = scan_flavor_dirs(base, variant)
    for _, dir in ipairs(flavor_candidates) do
      dirs[#dirs + 1] = dir
    end
  end

  return dirs
end

local function normalize_module_name(module)
  if not module or module == "" then
    return nil
  end
  if module:sub(1, 1) ~= ":" then
    return ":" .. module
  end
  return module
end

local function is_absolute_path(path)
  if not path or path == "" then
    return false
  end
  if path:sub(1, 1) == "/" then
    return true
  end
  if path:match("^%a:[\\/]") then
    return true
  end
  return false
end

local function resolve_override_path(root, path)
  if not path or path == "" then
    return nil
  end
  if is_absolute_path(path) then
    return path
  end
  if not root or root == "" then
    return path
  end
  return root .. "/" .. path
end

local function resolve_override(opts, module, variant)
  local overrides = opts and opts.overrides or nil
  if not overrides then
    return nil
  end

  local normalized_module = normalize_module_name(module)
  for _, entry in ipairs(overrides or {}) do
    if entry and entry.path and entry.path ~= "" then
      local entry_module = normalize_module_name(entry.module or module)
      if entry_module == normalized_module and entry.variant == variant then
        return entry.path
      end
    end
  end
  return nil
end

function M.resolve_apk_path(root, module, variant, opts)
  local result = M.list_apk_paths(root, module, variant, opts)
  if not result.ok then
    return result
  end
  return { ok = true, path = result.apks[1] }
end

function M.list_apk_paths(root, module, variant, opts)
  if not root or root == "" then
    return { ok = false, error = "root path required" }
  end
  if not module or module == "" then
    return { ok = false, error = "module required" }
  end
  if not variant or variant == "" then
    return { ok = false, error = "variant required" }
  end

  local override_path = resolve_override_path(root, resolve_override(opts, module, variant))
  if override_path then
    if not is_file(override_path) then
      return { ok = false, error = "override apk not found" }
    end
    return { ok = true, apks = { override_path } }
  end

  local module_dir = normalize_module_path(module)
  if not module_dir or module_dir == "" then
    return { ok = false, error = "module required" }
  end

  local base = root .. "/" .. module_dir .. "/build/outputs/apk"
  local apks = {}
  for _, dir in ipairs(variant_dirs(base, variant)) do
    if is_dir(dir) then
      for _, path in ipairs(list_apks(dir)) do
        if not is_android_test_apk(path) then
          table.insert(apks, path)
        end
      end
    end
  end

  if #apks == 0 then
    local scan_all = opts and opts.scan_all_apk_outputs
    if scan_all == nil then
      scan_all = config.get().build.scan_all_apk_outputs
    end

    if scan_all then
      local fallback = M.list_module_apks(root, module)
      if fallback.ok then
        local fallback_apks = collect_deployable_apks(fallback.apks)
        if #fallback_apks > 0 then
          return { ok = true, apks = fallback_apks }
        end
      end
    end
    return { ok = false, error = "no apk found for variant " .. variant }
  end

  return { ok = true, apks = sort_by_mtime(apks) }
end

function M.list_module_apks(root, module)
  if not root or root == "" then
    return { ok = false, error = "root path required" }
  end
  if not module or module == "" then
    return { ok = false, error = "module required" }
  end

  local module_dir = normalize_module_path(module)
  if not module_dir or module_dir == "" then
    return { ok = false, error = "module required" }
  end

  local base = root .. "/" .. module_dir .. "/build/outputs/apk"
  if not is_dir(base) then
    return { ok = false, error = "apk output not found" }
  end

  local apks = {}
  collect_apks_recursive(base, apks)
  if #apks == 0 then
    return { ok = false, error = "no apk found for module " .. module }
  end

  return { ok = true, apks = sort_by_mtime(apks) }
end

function M.list_workspace_apks(root, modules)
  if not root or root == "" then
    return { ok = false, error = "root path required" }
  end

  local entries = {}
  for _, module in ipairs(modules or {}) do
    local result = M.list_module_apks(root, module)
    if result.ok then
      for _, path in ipairs(result.apks or {}) do
        table.insert(entries, { module = module, path = path })
      end
    end
  end

  if #entries == 0 then
    return { ok = false, error = "no apk found in workspace" }
  end

  local times = {}
  for _, entry in ipairs(entries) do
    times[entry.path] = mtime_value(vim.loop.fs_stat(entry.path))
  end

  table.sort(entries, function(a, b)
    return (times[a.path] or 0) > (times[b.path] or 0)
  end)

  return { ok = true, apks = entries }
end

return M
