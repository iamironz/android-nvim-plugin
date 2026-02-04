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

local function build_state()
  return {
    buffers = {
      [1] = {
        modified = true,
        buftype = "",
        name = "/tmp/file.txt",
      },
    },
    commands = {},
    confirm_calls = {},
  }
end

local function with_vim_state(run)
  local state = build_state()
  local save, restore = create_saver()

  save(vim.api, "nvim_buf_is_valid")
  vim.api.nvim_buf_is_valid = function(buf)
    return state.buffers[buf] ~= nil
  end

  save(vim.api, "nvim_buf_get_option")
  vim.api.nvim_buf_get_option = function(buf, name)
    local buffer = state.buffers[buf]
    if not buffer then
      return nil
    end
    if name == "modified" then
      return buffer.modified
    end
    if name == "buftype" then
      return buffer.buftype
    end
    return nil
  end

  save(vim.api, "nvim_buf_get_name")
  vim.api.nvim_buf_get_name = function(buf)
    local buffer = state.buffers[buf]
    return buffer and buffer.name or ""
  end

  save(vim.api, "nvim_buf_call")
  vim.api.nvim_buf_call = function(_, fn)
    fn()
  end

  save(vim.fn, "confirm")
  vim.fn.confirm = function(message, options, default)
    table.insert(state.confirm_calls, {
      message = message,
      options = options,
      default = default,
    })
    return state.confirm_choice or 0
  end

  save(vim.fn, "fnameescape")
  vim.fn.fnameescape = function(path)
    return "escaped:" .. path
  end

  save(vim, "cmd")
  vim.cmd = function(command)
    table.insert(state.commands, command)
  end

  local ok, err = pcall(run, state)
  restore()
  if not ok then
    error(err)
  end
end

local function prompts_and_reloads_on_modified_buffer()
  with_vim_state(function(state)
    state.confirm_choice = 1
    local watcher = require("android.ui.file_watcher").new()

    watcher.on_change(1)

    assert.eq(#state.confirm_calls, 1, "confirm called")
    assert.contains(state.confirm_calls[1].options, "Reload", "reload option")
    assert.contains(state.confirm_calls[1].options, "Keep", "keep option")
    assert.contains(state.confirm_calls[1].options, "Diff", "diff option")
    assert.contains(state.confirm_calls[1].options, "Force Save", "force save option")
    assert.contains(state.commands[1], "edit!", "reload command")
  end)
end

local function keep_does_not_run_commands()
  with_vim_state(function(state)
    state.confirm_choice = 2
    local watcher = require("android.ui.file_watcher").new()

    watcher.on_change(1)

    assert.eq(#state.commands, 0, "no command for keep")
  end)
end

local function diff_opens_split()
  with_vim_state(function(state)
    state.confirm_choice = 3
    local watcher = require("android.ui.file_watcher").new()

    watcher.on_change(1)

    assert.contains(state.commands[1], "vert diffsplit", "diffsplit command")
    assert.contains(state.commands[1], "escaped:/tmp/file.txt", "diff path")
  end)
end

local function force_save_writes_buffer()
  with_vim_state(function(state)
    state.confirm_choice = 4
    local watcher = require("android.ui.file_watcher").new()

    watcher.on_change(1)

    assert.contains(state.commands[1], "write", "write command")
  end)
end

local function skips_unmodified_buffer()
  with_vim_state(function(state)
    state.buffers[1].modified = false
    local watcher = require("android.ui.file_watcher").new()

    watcher.on_change(1)

    assert.eq(#state.confirm_calls, 0, "no prompt for unmodified")
  end)
end

function M.run()
  prompts_and_reloads_on_modified_buffer()
  keep_does_not_run_commands()
  diff_opens_split()
  force_save_writes_buffer()
  skips_unmodified_buffer()
end

return M
