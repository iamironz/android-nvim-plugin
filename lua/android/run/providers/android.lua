local build_helpers = require("android.actions.build_helpers")
local gradle_cache = require("android.gradle.cache")
local gradle_markers = require("android.gradle.markers")
local gradle_tasks = require("android.gradle.tasks")
local gradle_workspace = require("android.gradle.workspace")
local selection_defaults = require("android.state.selection_defaults")

local M = {}

local cache = gradle_cache.persistent()

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

local function build_paths(root, module)
  local module_path = normalize_module_path(module)
  if not module_path then
    return {}
  end
  return {
    root .. "/" .. module_path .. "/build.gradle.kts",
    root .. "/" .. module_path .. "/build.gradle",
  }
end

local function default_read(path)
  local ok, lines = pcall(vim.fn.readfile, path)
  if not ok then
    return nil
  end
  return lines
end

local function read_first(paths, read)
  local reader = read or default_read
  for _, path in ipairs(paths or {}) do
    local lines = reader(path)
    if lines then
      return lines
    end
  end
  return nil
end

local function detect_modules(workspace, opts)
  if not workspace or not workspace.root then
    return {}
  end
  local options = opts or {}
  local modules = options.modules or cache.modules(workspace.root, function()
    return gradle_workspace.load_modules(workspace.root)
  end)
  local read_file = options.read or default_read
  local use_gradle_tasks = options.use_gradle_tasks
  local is_fast = options.fast == true

  local function scan_modules(module_list)
    local scan = {}
    for _, module in ipairs(module_list or {}) do
      local lines = read_first(build_paths(workspace.root, module), read_file)
      if gradle_markers.has_android_app(lines) then
        scan[#scan + 1] = module
      end
    end
    table.sort(scan)
    return scan
  end

  local function modules_from_tasks()
    local task_lines = options.tasks
    if not task_lines then
      if is_fast then
        return nil
      end
      local task_result = build_helpers.fetch_task_lines(workspace.root, options.runner)
      if not task_result or not task_result.ok then
        return nil
      end
      task_lines = task_result.lines
    end
    return gradle_tasks.android_modules(task_lines)
  end

  return cache.android_modules(workspace.root, modules, function()
    if use_gradle_tasks then
      local task_modules = modules_from_tasks()
      if not task_modules then
        return {}
      end
      return task_modules
    end

    if options.tasks then
      local task_modules = modules_from_tasks()
      if task_modules and #task_modules > 0 then
        return task_modules
      end
    end

    local scan = scan_modules(modules)
    if #scan > 0 then
      return scan
    end

    local task_modules = modules_from_tasks()
    if task_modules then
      return task_modules
    end
    return scan
  end)
end

function M.detect(workspace, state, opts)
  if not workspace or not workspace.android then
    return {}
  end

  local modules = detect_modules(workspace, opts)
  local build_state = selection_defaults.build_defaults(state)
  local variant = build_state.variant

  local configs = {}
  for _, module in ipairs(modules or {}) do
    configs[#configs + 1] = {
      id = "android" .. module,
      label = "Android " .. module,
      target = "android",
      type = "android",
      meta = { module = module, variant = variant },
    }
  end

  return configs
end

return M
