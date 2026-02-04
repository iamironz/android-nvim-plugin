local M = {}

function M.new(initial)
  local state = initial or {}
  local store = {}

  function store.get(key, fallback)
    if key == nil then
      return state
    end

    local value = state[key]
    if value == nil then
      return fallback
    end
    return value
  end

  function store.set(key, value)
    state[key] = value
    return value
  end

  function store.update(key, updater, fallback)
    local current = store.get(key, fallback)
    local next_value = updater(current)
    state[key] = next_value
    return next_value
  end

  function store.reset(next_state)
    state = next_state or {}
    return state
  end

  function store.snapshot()
    local copy = {}
    for key, value in pairs(state) do
      copy[key] = value
    end
    return copy
  end

  return store
end

return M
