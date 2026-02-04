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

local function build_registry(store)
  local registry = {}

  local function load_state(workspace)
    return store.load({ workspace_root = workspace.root })
  end

  local function save_state(workspace, state)
    return store.save({ workspace_root = workspace.root }, state)
  end

  function registry.list(workspace)
    local state = load_state(workspace)
    return configs.from_workspace(workspace, { state = state })
  end

  function registry.resolve(workspace)
    local state = load_state(workspace)
    local list = configs.from_workspace(workspace, { state = state })
    local current_id = selected_id(state)
    local selected = configs.find(list, current_id)
    local resolved = selected or configs.default(list)
    if resolved and resolved.id and resolved.id ~= current_id then
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

function M.list(workspace)
  return default_registry.list(workspace)
end

function M.resolve(workspace)
  return default_registry.resolve(workspace)
end

function M.select(workspace, config_id)
  return default_registry.select(workspace, config_id)
end

return M
