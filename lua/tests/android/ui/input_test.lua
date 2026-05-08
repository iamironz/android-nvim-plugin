local M = {}

local assert = require("tests.helpers.assert")

local function create_saver()
  local saved = {}
  local function save(tbl, key)
    saved[tbl] = saved[tbl] or {}
    if saved[tbl][key] == nil then
      saved[tbl][key] = tbl[key]
    end
  end

  local function restore()
    for tbl, keys in pairs(saved) do
      for key, value in pairs(keys) do
        tbl[key] = value
      end
    end
  end

  return save, restore
end

local function with_input(lines, run)
  local save, restore = create_saver()
  local state = {
    autocmd = nil,
    callbacks = {},
    commands = {},
    open_opts = nil,
  }

  save(vim, "o")
  vim.o = vim.o or {}
  vim.o.columns = 120
  vim.o.lines = 40

  save(vim, "bo")
  local bo_state = {}
  vim.bo = setmetatable({}, {
    __index = function(_, key)
      bo_state[key] = bo_state[key] or {}
      return bo_state[key]
    end,
  })

  save(vim, "cmd")
  vim.cmd = function(cmd)
    state.commands[#state.commands + 1] = cmd
  end

  save(vim, "keymap")
  vim.keymap = vim.keymap or {}
  save(vim.keymap, "set")
  vim.keymap.set = function() end

  save(vim.fn, "prompt_setprompt")
  vim.fn.prompt_setprompt = function(_, prompt)
    state.prompt = prompt
  end

  save(vim.fn, "prompt_setcallback")
  vim.fn.prompt_setcallback = function(_, cb)
    state.callbacks.submit = cb
  end

  save(vim.api, "nvim_create_buf")
  vim.api.nvim_create_buf = function() return 1 end

  save(vim.api, "nvim_open_win")
  vim.api.nvim_open_win = function(_, _, opts)
    state.open_opts = opts
    return 2
  end

  save(vim.api, "nvim_win_is_valid")
  vim.api.nvim_win_is_valid = function() return true end

  save(vim.api, "nvim_win_close")
  vim.api.nvim_win_close = function() end

  save(vim.api, "nvim_buf_get_lines")
  vim.api.nvim_buf_get_lines = function()
    return lines
  end

  save(vim.api, "nvim_buf_set_lines")
  vim.api.nvim_buf_set_lines = function() end

  save(vim.api, "nvim_create_autocmd")
  vim.api.nvim_create_autocmd = function(_, opts)
    state.autocmd = opts.callback
  end

  local ok, err = pcall(function()
    package.loaded["android.ui.input"] = nil
    local input = require("android.ui.input")
    run(input, state)
  end)

  restore()

  if not ok then
    error(err)
  end
end

local function on_change_strips_prompt_prefix()
  with_input({ "Filter: foo" }, function(input, state)
    local captured = nil
    input.prompt({
      prompt = "Filter: ",
      on_change = function(value)
        captured = value
      end,
    })

    state.autocmd()
    assert.eq(captured, "foo", "on change strips prompt")
  end)
end

local function on_change_skips_empty_prompt()
  with_input({ "Filter: " }, function(input, state)
    local captured = nil
    input.prompt({
      prompt = "Filter: ",
      on_change = function(value)
        captured = value
      end,
    })

    state.autocmd()
    assert.eq(captured, nil, "on change skipped")
  end)
end

local function startinsert_uses_append_mode()
  with_input({ "old" }, function(input, state)
    input.prompt({
      default = "old",
    })

    assert.eq(state.commands[#state.commands], "startinsert!", "appends at end")
  end)
end

local function uses_wider_default_width()
  with_input({ "" }, function(input, state)
    input.prompt({
      title = "Logcat filter:",
    })

    assert.eq(state.open_opts.width, 56, "default width")
  end)
end

local function clamps_width_to_editor()
  with_input({ "" }, function(input, state)
    vim.o.columns = 40

    input.prompt({
      title = "Logcat filter:",
    })

    assert.eq(state.open_opts.width, 36, "clamped width")
  end)
end

function M.run()
  on_change_strips_prompt_prefix()
  on_change_skips_empty_prompt()
  startinsert_uses_append_mode()
  uses_wider_default_width()
  clamps_width_to_editor()
end

return M
