local M = {}

local menu_prefetch = require("android.state.menu_prefetch")
local run_configs = require("android.run.configs")
local run_registry = require("android.run.registry")

local function shallow_copy(source)
  local out = {}
  for key, value in pairs(source or {}) do
    if type(value) == "table" then
      local nested = {}
      for nested_key, nested_value in pairs(value) do
        nested[nested_key] = nested_value
      end
      out[key] = nested
    else
      out[key] = value
    end
  end
  return out
end

local function cached_detect_opts(root)
  local opts = { fast = true }
  local task_lines = menu_prefetch.cached_task_lines and menu_prefetch.cached_task_lines(root) or nil
  local snapshot = menu_prefetch.cached_snapshot and menu_prefetch.cached_snapshot(root) or nil
  if task_lines and #task_lines > 0 then
    opts.tasks = task_lines
    opts.fast = nil
  end
  if snapshot then
    opts.snapshot = snapshot
    opts.fast = nil
  end
  return opts
end

local function matching_android_config(list, module)
  for _, config in ipairs(list or {}) do
    if config and config.type == "android" and config.meta and config.meta.module == module then
      return config
    end
  end
  return nil
end

local function load_snapshot(workspace, detect_opts)
  return run_registry.snapshot(workspace, {
    detect_opts = detect_opts,
    persist = false,
  })
end

local function fallback_detect_opts()
  return { use_gradle_tasks = true }
end

function M.apply(workspace, state, module)
  if not workspace or not workspace.root or not module or module == "" then
    return state
  end

  local detect_opts = cached_detect_opts(workspace.root)
  local snapshot = load_snapshot(workspace, detect_opts)
  local matching = matching_android_config(snapshot and snapshot.list, module)
  local fallback_opts = fallback_detect_opts()
  if not matching and fallback_opts then
    snapshot = load_snapshot(workspace, fallback_opts)
    matching = matching_android_config(snapshot and snapshot.list, module)
  end
  if not matching or not matching.id then
    return state
  end

  local list = snapshot and snapshot.list or {}
  local current_id = state and state.run and state.run.config_id or nil
  local current = current_id and run_configs.find(list, current_id) or snapshot.current
  if current_id and not current then
    return state
  end
  if current and current.type ~= "android" then
    return state
  end
  if current_id == matching.id then
    return state
  end

  local next_state = shallow_copy(state)
  next_state.run = next_state.run or {}
  next_state.run.config_id = matching.id
  return next_state
end

return M
