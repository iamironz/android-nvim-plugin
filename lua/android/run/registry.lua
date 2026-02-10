local M = {}

local selection_store = require("android.state.selection_store")
local configs = require("android.run.configs")

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

local function selected_id(state)
  local run = state and state.run or nil
  return run and run.config_id or nil
end

local function apply_selected_id(state, config_id)
  local next_state = shallow_copy(state)
  next_state.run = next_state.run or {}
  next_state.run.config_id = config_id
  return next_state
end

local function build_config_options(state, opts)
  local options = opts or {}
  local config_opts = { state = state }
  if options.providers then
    config_opts.providers = options.providers
  end
  if options.detect_opts then
    config_opts.detect_opts = options.detect_opts
  end
  return config_opts
end

local function should_persist(opts)
  return not (opts and opts.persist == false)
end

local function is_selectable_config(config)
  return config and config.type ~= "gradle_task"
end

local function default_selectable(list)
  for _, entry in ipairs(list or {}) do
    if is_selectable_config(entry) then
      return entry
    end
  end
  return configs.default(list)
end

local function build_registry(store)
  local registry = {}

  local function load_state(workspace)
    return store.load({ workspace_root = workspace.root })
  end

  local function save_state(workspace, state)
    return store.save({ workspace_root = workspace.root }, state)
  end

  function registry.list(workspace, opts)
    local state = load_state(workspace)
    return configs.from_workspace(workspace, build_config_options(state, opts))
  end

  function registry.snapshot(workspace, opts)
    local state = load_state(workspace)
    local list = configs.from_workspace(workspace, build_config_options(state, opts))
    local current_id = selected_id(state)
    local selected = configs.find(list, current_id)
    if not is_selectable_config(selected) then
      selected = nil
    end
    local resolved = selected or default_selectable(list)
    if should_persist(opts) and resolved and resolved.id and resolved.id ~= current_id then
      local next_state = apply_selected_id(state, resolved.id)
      save_state(workspace, next_state)
    end
    return { list = list, current = resolved }
  end

  function registry.resolve(workspace, opts)
    local state = load_state(workspace)
    local list = configs.from_workspace(workspace, build_config_options(state, opts))
    local current_id = selected_id(state)
    local selected = configs.find(list, current_id)
    if not is_selectable_config(selected) then
      selected = nil
    end
    local resolved = selected or default_selectable(list)
    if should_persist(opts) and resolved and resolved.id and resolved.id ~= current_id then
      local next_state = apply_selected_id(state, resolved.id)
      save_state(workspace, next_state)
    end
    return resolved
  end

  function registry.select(workspace, config_id)
    local state = load_state(workspace)
    local next_state = apply_selected_id(state, config_id)
    save_state(workspace, next_state)
    return config_id
  end

  return registry
end

function M.new(opts)
  local options = opts or {}
  local store = options.store or selection_store
  return build_registry(store)
end

local default_registry = M.new()

function M.list(workspace, opts)
  return default_registry.list(workspace, opts)
end

function M.resolve(workspace, opts)
  return default_registry.resolve(workspace, opts)
end

function M.select(workspace, config_id)
  return default_registry.select(workspace, config_id)
end

function M.snapshot(workspace, opts)
  return default_registry.snapshot(workspace, opts)
end

return M
