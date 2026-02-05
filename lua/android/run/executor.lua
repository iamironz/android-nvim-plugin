local context = require("android.actions.context")
local run_registry = require("android.run.registry")
local run_configs = require("android.run.configs")
local handlers = require("android.run.executor_handlers")

local M = {}

local active_run = nil

local function resolve_workspace(workspace)
  if workspace and workspace.root then
    return workspace
  end
  return context.workspace()
end

local function stop_handles(handles)
  for _, handle in ipairs(handles or {}) do
    if handle and handle.stop then
      handle.stop()
    end
  end
end

local function run_all(workspace, state, config)
  local list = run_registry.list(workspace)
  local handles = {}
  for _, target_id in ipairs(config.targets or {}) do
    local target = run_configs.find(list, target_id)
    if target then
      local handle = handlers.run(workspace, target, state)
      if handle then
        handles[#handles + 1] = handle
      end
    end
  end

  return {
    stop = function()
      stop_handles(handles)
    end,
  }
end

local function execute_config(workspace, state, config)
  if not config then
    return nil
  end

  if config.target == "multi" then
    active_run = run_all(workspace, state, config)
    return active_run
  end

  active_run = nil
  return handlers.run(workspace, config, state)
end

function M.stop_active()
  if not active_run or not active_run.stop then
    return false
  end
  active_run.stop()
  active_run = nil
  return true
end

function M.execute_default(workspace)
  local target_workspace = resolve_workspace(workspace)
  if not target_workspace then
    return nil
  end
  local state = context.load_state(target_workspace.root)
  local config = run_registry.resolve(target_workspace)
  return execute_config(target_workspace, state, config)
end

function M.execute(config_id, workspace)
  local target_workspace = resolve_workspace(workspace)
  if not target_workspace then
    return nil
  end
  if not config_id or config_id == "" then
    return M.execute_default(target_workspace)
  end

  local list = run_registry.list(target_workspace)
  local config = run_configs.find(list, config_id)
  if not config then
    return nil
  end

  run_registry.select(target_workspace, config_id)
  local state = context.load_state(target_workspace.root)
  return execute_config(target_workspace, state, config)
end

return M
