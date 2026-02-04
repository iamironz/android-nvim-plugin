local M = {}

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

function M.build_defaults(state)
  local build = state and state.build or {}
  return {
    module = build.module,
    variant = build.variant,
  }
end

function M.build_is_complete(state)
  local build = M.build_defaults(state)
  return build.variant ~= nil and build.variant ~= ""
end

function M.apply_build_defaults(state, module, variant)
  local next_state = shallow_copy(state)
  next_state.build = { module = module, variant = variant }
  return next_state
end

function M.device_defaults(state)
  local device = state and state.device or {}
  return { serial = device.serial }
end

function M.apply_device_defaults(state, serial)
  local next_state = shallow_copy(state)
  next_state.device = { serial = serial }
  return next_state
end

function M.avd_defaults(state)
  local avd = state and state.avd or {}
  return { name = avd.name }
end

function M.apply_avd_defaults(state, name)
  local next_state = shallow_copy(state)
  next_state.avd = { name = name }
  return next_state
end

return M
