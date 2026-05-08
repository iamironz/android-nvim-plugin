local M = {}

local assert = require("tests.helpers.assert")

local function run_filter_input_without_telescope(opts)
  local options = opts or {}
  local flags = { on_change = false, on_accept = false, on_cancel = false }
  local captured = { title = nil, prompt = nil, default = nil }
  local original_input = vim.ui and vim.ui.input
  local original_preload = package.preload["telescope.pickers"]
  local original_loaded = package.loaded["telescope.pickers"]
  local original_android_preload = package.preload["android.ui.input"]
  local original_android_input = package.loaded["android.ui.input"]

  package.preload["telescope.pickers"] = function()
    error("missing telescope.pickers")
  end
  package.loaded["telescope.pickers"] = nil

  package.loaded["android.ui.input"] = {
    prompt = function(input_opts)
      captured.title = input_opts.title
      captured.prompt = input_opts.prompt
      captured.default = input_opts.default
      if options.cancel then
        input_opts.on_cancel()
        return
      end
      if input_opts.on_change then
        input_opts.on_change("live")
      end
      input_opts.on_submit("typed")
    end,
  }

  vim.ui = vim.ui or {}
  vim.ui.input = function()
    error("vim.ui.input should not be used when floating input is available")
  end

  package.loaded["android.ui.picker"] = nil
  local picker = require("android.ui.picker")
  picker.filter_input({
    items = { "one" },
    prompt_title = options.prompt_title or "Filter",
    default = "old",
    on_change = function(value) flags.on_change = value end,
    on_accept = function(value) flags.on_accept = value end,
    on_cancel = function() flags.on_cancel = true end,
  })

  vim.ui.input = original_input
  package.preload["telescope.pickers"] = original_preload
  package.loaded["telescope.pickers"] = original_loaded
  package.preload["android.ui.input"] = original_android_preload
  package.loaded["android.ui.input"] = original_android_input

  return { captured = captured, flags = flags }
end

local function run_filter_input_without_floating_input()
  local flags = { on_change = false, on_accept = false, on_cancel = false }
  local captured = { prompt = nil, default = nil }
  local original_input = vim.ui and vim.ui.input
  local original_preload = package.preload["telescope.pickers"]
  local original_loaded = package.loaded["telescope.pickers"]
  local original_android_preload = package.preload["android.ui.input"]
  local original_android_input = package.loaded["android.ui.input"]

  package.preload["telescope.pickers"] = function()
    error("missing telescope.pickers")
  end
  package.loaded["telescope.pickers"] = nil
  package.preload["android.ui.input"] = function()
    error("missing android.ui.input")
  end
  package.loaded["android.ui.input"] = nil

  vim.ui = vim.ui or {}
  vim.ui.input = function(input_opts, cb)
    captured.prompt = input_opts.prompt
    captured.default = input_opts.default
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
  package.preload["android.ui.input"] = original_android_preload
  package.loaded["android.ui.input"] = original_android_input

  return { captured = captured, flags = flags }
end

local function filter_input_fallback_sets_title()
  local result = run_filter_input_without_telescope()
  assert.eq(result.captured.title, "Filter:", "input title")
end

local function filter_input_fallback_keeps_prompt_empty()
  local result = run_filter_input_without_telescope()
  assert.eq(result.captured.prompt, "", "input prompt")
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

local function filter_input_fallback_calls_on_cancel()
  local result = run_filter_input_without_telescope({ cancel = true })
  assert.eq(result.flags.on_cancel, true, "on_cancel called")
end

local function filter_input_falls_back_to_vim_ui_input()
  local result = run_filter_input_without_floating_input()
  assert.eq(result.captured.prompt, "Filter: ", "vim.ui.input prompt")
  assert.eq(result.flags.on_accept, "typed", "vim.ui.input accept")
end

function M.run()
  filter_input_fallback_sets_title()
  filter_input_fallback_keeps_prompt_empty()
  filter_input_fallback_sets_default()
  filter_input_fallback_calls_on_change()
  filter_input_fallback_calls_on_accept()
  filter_input_fallback_calls_on_cancel()
  filter_input_falls_back_to_vim_ui_input()
end

return M
