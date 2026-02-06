local M = {}

local assert = require("tests.helpers.assert")

local function run_filter_input_without_telescope()
  local flags = { on_change = false, on_accept = false, on_cancel = false }
  local captured = { prompt = nil, default = nil }
  local original_input = vim.ui and vim.ui.input
  local original_preload = package.preload["telescope.pickers"]
  local original_loaded = package.loaded["telescope.pickers"]

  package.preload["telescope.pickers"] = function()
    error("missing telescope.pickers")
  end
  package.loaded["telescope.pickers"] = nil

  vim.ui = vim.ui or {}
  vim.ui.input = function(opts, cb)
    captured.prompt = opts.prompt
    captured.default = opts.default
    cb("typed")
  end

  package.loaded["android.ui.picker"] = nil
  local picker = require("android.ui.picker")
  picker.filter_input({
    items = { "one" },
    prompt_title = "Filter",
    default = "old",
    on_change = function(value) flags.on_change = value end,
    on_accept = function(value) flags.on_accept = value end,
    on_cancel = function() flags.on_cancel = true end,
  })

  vim.ui.input = original_input
  package.preload["telescope.pickers"] = original_preload
  package.loaded["telescope.pickers"] = original_loaded

  return { captured = captured, flags = flags }
end

local function filter_input_fallback_sets_prompt()
  local result = run_filter_input_without_telescope()
  assert.eq(result.captured.prompt, "Filter", "input prompt")
end

local function filter_input_fallback_sets_default()
  local result = run_filter_input_without_telescope()
  assert.eq(result.captured.default, "old", "input default")
end

local function filter_input_fallback_calls_on_change()
  local result = run_filter_input_without_telescope()
  assert.eq(result.flags.on_change, "typed", "on_change called")
end

local function filter_input_fallback_calls_on_accept()
  local result = run_filter_input_without_telescope()
  assert.eq(result.flags.on_accept, "typed", "on_accept called")
end

local function filter_input_fallback_does_not_call_on_cancel()
  local result = run_filter_input_without_telescope()
  assert.eq(result.flags.on_cancel, false, "on_cancel not called")
end

function M.run()
  filter_input_fallback_sets_prompt()
  filter_input_fallback_sets_default()
  filter_input_fallback_calls_on_change()
  filter_input_fallback_calls_on_accept()
  filter_input_fallback_does_not_call_on_cancel()
end

return M
