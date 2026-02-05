local M = {}

local build_helpers = require("android.actions.build_helpers")
local gradle_tasks = require("android.gradle.tasks")
local gradle_variants = require("android.gradle.variants")
local gradle_workspace = require("android.gradle.workspace")
local run_providers = require("android.run.providers")
local run_registry = require("android.run.registry")

local state_by_root = {}
local token_seed = 0

local function next_token()
  token_seed = token_seed + 1
  return token_seed
end

local function count_value(list)
  if not list or #list == 0 then
    return "none"
  end
  return tostring(#list)
end

local function build_status_items()
  local items = {
    { key = "run_configs", label = "Run configs", value = "loading..." },
    { key = "gradle_tasks", label = "Gradle tasks", value = "loading..." },
    { key = "variants", label = "Variants", value = "loading..." },
  }
  local lookup = {}
  for _, item in ipairs(items) do
    lookup[item.key] = item
  end
  return { items = items, lookup = lookup }
end

local function set_status_value(status, key, value)
  if not status or not status.lookup then
    return
  end
  local item = status.lookup[key]
  if item then
    item.value = value
  end
end

local function build_run_snapshot(state, workspace, detect_opts)
  local providers = state.providers or run_providers.defaults()
  return run_registry.snapshot(workspace, { providers = providers, detect_opts = detect_opts })
end

local function notify_update(state, token, on_update)
  if not on_update then
    return
  end
  vim.schedule(function()
    if state.token ~= token then
      return
    end
    on_update(state.status, state)
  end)
end

local function ensure_state(root, providers)
  local state = state_by_root[root]
  if state then
    if providers then
      state.providers = providers
    end
    return state
  end
  state = {
    data = {},
    jobs = {},
    providers = providers,
    status = build_status_items(),
  }
  state_by_root[root] = state
  return state
end

local function load_modules(root)
  if not root or root == "" then
    return {}
  end
  return gradle_workspace.load_modules(root)
end

local function start_gradle_tasks_job(state, workspace, on_update, token)
  local root = workspace and workspace.root or nil
  local job = build_helpers.fetch_task_lines_async(root, nil, function(result)
    if state.token ~= token then
      return
    end
    state.jobs.gradle_tasks = nil
    if not result or not result.ok then
      set_status_value(state.status, "gradle_tasks", "error")
      set_status_value(state.status, "variants", "error")
      notify_update(state, token, on_update)
      return
    end
    local lines = result.lines or {}
    local tasks = gradle_tasks.parse(lines)
    local variants = gradle_variants.parse(lines)
    state.data.task_lines = lines
    state.data.tasks = tasks
    state.data.variants = variants
    state.run_snapshot = build_run_snapshot(state, workspace, { tasks = lines })
    set_status_value(state.status, "run_configs", count_value(state.run_snapshot.list))
    set_status_value(state.status, "gradle_tasks", count_value(tasks))
    set_status_value(state.status, "variants", count_value(variants))
    notify_update(state, token, on_update)
  end)
  state.jobs.gradle_tasks = job
end

function M.start(workspace, opts)
  if not workspace or not workspace.root then
    return nil
  end
  local options = opts or {}
  local root = workspace.root
  local state = ensure_state(root, options.providers)
  local token = next_token()
  state.token = token

  state.run_snapshot = build_run_snapshot(state, workspace, { fast = true })
  set_status_value(state.status, "run_configs", "loading...")

  if state.data.tasks then
    set_status_value(state.status, "gradle_tasks", count_value(state.data.tasks))
  end
  if state.data.variants then
    set_status_value(state.status, "variants", count_value(state.data.variants))
  end

  if workspace.gradle then
    if not state.data.tasks and not state.jobs.gradle_tasks then
      start_gradle_tasks_job(state, workspace, options.on_update, token)
    elseif state.run_snapshot and state.run_snapshot.list then
      set_status_value(state.status, "run_configs", count_value(state.run_snapshot.list))
    end
  else
    set_status_value(state.status, "gradle_tasks", "unavailable")
    set_status_value(state.status, "variants", "unavailable")
    set_status_value(state.status, "run_configs", count_value(state.run_snapshot.list))
  end

  return {
    status = state.status,
    run_snapshot = state.run_snapshot,
    modules = load_modules(root),
    cancel = function()
      if state.token ~= token then
        return
      end
      for _, job in pairs(state.jobs or {}) do
        if job and job.stop then
          job.stop()
        end
      end
    end,
  }
end

function M.cached_tasks(root)
  local state = root and state_by_root[root] or nil
  return state and state.data and state.data.tasks or nil
end

function M.cached_variants(root)
  local state = root and state_by_root[root] or nil
  return state and state.data and state.data.variants or nil
end

function M.cached_run_snapshot(root)
  local state = root and state_by_root[root] or nil
  return state and state.run_snapshot or nil
end

function M.status(root)
  local state = root and state_by_root[root] or nil
  return state and state.status or nil
end

return M
