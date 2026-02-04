local M = {}

local function default_schedule(delay_ms, fn)
  if vim.defer_fn then
    vim.defer_fn(fn, delay_ms)
    return
  end
  fn()
end

local function default_random()
  return math.random()
end

local function build_config(opts)
  local options = opts or {}
  return {
    base_delay = options.base_delay or 1000,
    max_delay = options.max_delay or 8000,
    jitter = options.jitter or 0.2,
    max_attempts = options.max_attempts or 5,
    random = options.random or default_random,
    schedule = options.schedule or default_schedule,
  }
end

local function compute_delay(config, attempt)
  local delay = math.min(config.max_delay, config.base_delay * (2 ^ (attempt - 1)))
  local jitter = config.jitter or 0
  if jitter > 0 then
    local range = delay * jitter
    delay = delay - range / 2 + config.random() * range
  end
  return math.floor(delay)
end

function M.new(opts)
  return { config = build_config(opts), attempts = 0, pending = false }
end

function M.reset(state)
  if not state then
    return
  end
  state.attempts = 0
  state.pending = false
end

function M.schedule(state, fn)
  if not state or state.pending then
    return false
  end
  state.attempts = state.attempts + 1
  if state.attempts > state.config.max_attempts then
    return false, "max_attempts"
  end
  local delay = compute_delay(state.config, state.attempts)
  state.pending = true
  state.config.schedule(delay, function()
    state.pending = false
    fn()
  end)
  return true, delay
end

return M
