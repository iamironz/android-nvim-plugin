local M = {}

local build_helpers = require("android.actions.build_helpers")
local gradle_snapshot = require("android.gradle.snapshot")
local gradle_tasks = require("android.gradle.tasks")
local gradle_variants = require("android.gradle.variants")
local gradle_workspace = require("android.gradle.workspace")
local run_providers = require("android.run.providers")
local run_registry = require("android.run.registry")
local strings = require("android.utils.strings")

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

local function count_run_configs(snapshot)
  local count = 0
  for _, config in ipairs(snapshot and snapshot.list or {}) do
    if config and config.type ~= "gradle_task" then
      count = count + 1
    end
  end
  if count == 0 then
    return "none"
  end
  return tostring(count)
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
  return run_registry.snapshot(workspace, {
    providers = providers,
    detect_opts = detect_opts,
    persist = false,
  })
end

local function variants_from_snapshot(snapshot)
  local by_module = snapshot and snapshot.android and snapshot.android.by_module or nil
  if not by_module then
    return {}
  end

  local seen = {}
  for _, entry in pairs(by_module) do
    for _, variant in ipairs(entry and entry.variants or {}) do
      seen[variant] = true
    end
  end

  local variants = {}
  for variant in pairs(seen) do
    variants[#variants + 1] = variant
  end
  table.sort(variants)
  return variants
end

local function cached_detect_opts(state, fast)
  local detect_opts = {}
  local task_lines = state and state.data and state.data.task_lines or nil
  local snapshot = state and state.data and state.data.snapshot or nil

  if task_lines and #task_lines > 0 then
    detect_opts.tasks = task_lines
  end
  if snapshot then
    detect_opts.snapshot = snapshot
  end
  if fast and not detect_opts.tasks then
    detect_opts.fast = true
  end

  return detect_opts
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

local function notify_gradle_error(result)
  local detail = strings.first_nonempty_line(result and result.stderr)
    or strings.first_nonempty_line(result and result.stdout)
  local code = result and result.code or nil
  local parts = { "Gradle tasks failed" }
  if code then
    parts[#parts + 1] = string.format("(exit %s)", tostring(code))
  end
  if detail then
    parts[#parts + 1] = ": " .. detail
  end
  vim.notify(table.concat(parts, " "), vim.log.levels.WARN)
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
      notify_gradle_error(result)
      notify_update(state, token, on_update)
      return
    end
    local lines = result.lines or {}
    local snapshot = gradle_snapshot.parse(lines)
    local tasks = gradle_tasks.parse(lines)
    local variants = variants_from_snapshot(snapshot)
    if #variants == 0 then
      variants = gradle_variants.parse(lines)
    end
    state.data.task_lines = lines
    state.data.snapshot = snapshot
    state.data.tasks = tasks
    state.data.variants = variants
    state.run_snapshot = build_run_snapshot(state, workspace, {
      tasks = lines,
      snapshot = snapshot,
    })
    set_status_value(state.status, "run_configs", count_run_configs(state.run_snapshot))
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
  local keep_token = state.jobs and state.jobs.gradle_tasks ~= nil
  local token = keep_token and (state.token or next_token()) or next_token()
  state.token = token

  local cached_task_lines = state.data.task_lines
  local cached_snapshot = state.data.snapshot
  if cached_task_lines and #cached_task_lines > 0 then
    state.run_snapshot = build_run_snapshot(state, workspace, {
      tasks = cached_task_lines,
      snapshot = cached_snapshot,
    })
  elseif cached_snapshot then
    state.run_snapshot = build_run_snapshot(state, workspace, cached_detect_opts(state, true))
  else
    state.run_snapshot = build_run_snapshot(state, workspace, { fast = true })
  end
  set_status_value(state.status, "run_configs", "loading...")

  if state.data.tasks then
    set_status_value(state.status, "gradle_tasks", count_value(state.data.tasks))
  end
  if state.data.variants then
    set_status_value(state.status, "variants", count_value(state.data.variants))
  end

  if workspace.gradle then
    if cached_task_lines and #cached_task_lines > 0 then
      set_status_value(state.status, "run_configs", count_run_configs(state.run_snapshot))
    elseif state.jobs.gradle_tasks then
      set_status_value(state.status, "run_configs", "loading...")
    elseif not state.data.tasks and not state.jobs.gradle_tasks then
      start_gradle_tasks_job(state, workspace, options.on_update, token)
    end
  else
    set_status_value(state.status, "gradle_tasks", "unavailable")
    set_status_value(state.status, "variants", "unavailable")
    set_status_value(state.status, "run_configs", count_run_configs(state.run_snapshot))
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

function M.cached_task_lines(root)
  local state = root and state_by_root[root] or nil
  return state and state.data and state.data.task_lines or nil
end

function M.cached_snapshot(root)
  local state = root and state_by_root[root] or nil
  return state and state.data and state.data.snapshot or nil
end

function M.cached_variant_fetch_opts(root, module)
  local opts = { module = module }
  local task_lines = M.cached_task_lines(root)
  local snapshot = M.cached_snapshot(root)

  if task_lines and #task_lines > 0 then
    opts.tasks = task_lines
  end
  if snapshot then
    opts.snapshot = snapshot
  end

  return opts
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
