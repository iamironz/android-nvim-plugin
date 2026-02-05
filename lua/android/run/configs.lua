local M = {}

local config = require("android.config")
local providers = require("android.run.providers")
local provider_registry = require("android.run.providers.registry")

local function run_all_settings()
  local run_config = config.get().run or {}
  local run_all = run_config.run_all or {}
  return {
    order = run_all.order or {},
    target_modules = run_all.target_modules or {},
  }
end

local function build_run_all(configs)
  local settings = run_all_settings()
  local order = settings.order
  local target_modules = settings.target_modules
  local targets = {}
  local function pick_config(target)
    local matches = {}
    for _, entry in ipairs(configs or {}) do
      if entry.target == target then
        matches[#matches + 1] = entry
      end
    end
    if #matches == 0 then
      return nil
    end
    for _, preferred in ipairs(target_modules[target] or {}) do
      for _, entry in ipairs(matches) do
        if entry.meta and entry.meta.module == preferred then
          return entry
        end
      end
    end
    return matches[1]
  end
  for _, target in ipairs(order) do
    local picked = pick_config(target)
    if picked then
      targets[#targets + 1] = picked.id
    end
  end
  if #targets == 0 then
    return nil
  end
  return {
    id = "run_all",
    label = "Run All",
    target = "multi",
    type = "multi",
    targets = targets,
  }
end

function M.from_workspace(workspace, opts)
  if not workspace then
    return {}
  end

  local options = opts or {}
  local provider_list = options.providers or providers.defaults()
  local list = provider_registry.list(workspace, options.state, {
    providers = provider_list,
    detect_opts = options.detect_opts,
  })
  local run_all = build_run_all(list)
  if run_all then
    list[#list + 1] = run_all
  end
  return list
end

function M.find(list, id)
  if not id then
    return nil
  end
  for _, entry in ipairs(list or {}) do
    if entry.id == id then
      return entry
    end
  end
  return nil
end

function M.default(list)
  if not list or #list == 0 then
    return nil
  end
  for _, entry in ipairs(list) do
    if entry.target == "android" then
      return entry
    end
  end
  return list[1]
end

return M
