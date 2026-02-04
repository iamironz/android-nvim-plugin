local utils = require("android.run.providers.utils")

local M = {}

local function provider_priority(provider, index)
  if provider and provider.priority then
    return provider.priority
  end
  return 100 + index
end

local function apply_provider_defaults(config, provider, index)
  local priority = provider_priority(provider, index)
  if config.priority == nil then
    config.priority = priority
  end
  if provider and provider.id and config.provider_id == nil then
    config.provider_id = provider.id
  end
  return config
end

function M.list(workspace, state, opts)
  local options = opts or {}
  local providers = options.providers or {}
  local configs = {}

  for index, provider in ipairs(providers) do
    if provider and type(provider.detect) == "function" then
      local list = provider.detect(workspace, state) or {}
      for _, config in ipairs(list) do
        configs[#configs + 1] = apply_provider_defaults(config, provider, index)
      end
    end
  end

  return utils.sort_configs(configs)
end

return M
