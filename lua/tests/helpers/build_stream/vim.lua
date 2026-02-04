local buffer = require("tests.helpers.build_stream.buffer")

local M = {}

function M.capture_vim_originals()
  return {
    shellescape = vim.fn.shellescape,
    notify = vim.notify,
    input = vim.fn.input,
    keymap_set = vim.keymap.set,
    cmd = vim.cmd,
    api = {
      nvim_buf_attach = vim.api.nvim_buf_attach,
      nvim_buf_detach = vim.api.nvim_buf_detach,
      nvim_buf_get_lines = vim.api.nvim_buf_get_lines,
      nvim_buf_is_valid = vim.api.nvim_buf_is_valid,
      nvim_buf_line_count = vim.api.nvim_buf_line_count,
      nvim_buf_set_lines = vim.api.nvim_buf_set_lines,
      nvim_get_current_buf = vim.api.nvim_get_current_buf,
      nvim_get_current_win = vim.api.nvim_get_current_win,
      nvim_win_get_cursor = vim.api.nvim_win_get_cursor,
      nvim_win_set_cursor = vim.api.nvim_win_set_cursor,
    },
  }
end

function M.make_vim_state()
  return {
    notify_message = nil,
    notify_level = nil,
    input_values = {},
    keymaps = {},
    commands = {},
    buffers = {},
    attached = {},
    current_buf = 1,
    current_win = 10,
    cursor_line = 1,
    header_count = 0,
  }
end

function M.apply_vim_basic_stubs(state)
  vim.fn.shellescape = function(value)
    return "ESC(" .. value .. ")"
  end

  vim.notify = function(message, level)
    state.notify_message = message
    state.notify_level = level
  end

  vim.fn.input = function(_, default)
    if #state.input_values > 0 then
      return table.remove(state.input_values, 1)
    end
    return default or ""
  end

  vim.keymap.set = function(mode, lhs, rhs)
    state.keymaps[mode] = state.keymaps[mode] or {}
    state.keymaps[mode][lhs] = rhs
  end

  vim.cmd = function(cmd)
    state.commands[#state.commands + 1] = cmd
  end
end

function M.apply_vim_api_stubs(state)
  vim.api.nvim_get_current_buf = function()
    return state.current_buf
  end

  vim.api.nvim_get_current_win = function()
    return state.current_win
  end

  vim.api.nvim_win_get_cursor = function()
    return { state.cursor_line, 0 }
  end

  vim.api.nvim_win_set_cursor = function(_, pos)
    state.cursor_line = pos[1]
  end

  vim.api.nvim_buf_is_valid = function(buf)
    return state.buffers[buf] ~= nil
  end

  vim.api.nvim_buf_attach = function(buf, _, opts)
    state.attached[buf] = opts or {}
    return true
  end

  vim.api.nvim_buf_detach = function(buf)
    state.attached[buf] = nil
    return true
  end

  vim.api.nvim_buf_get_lines = function(buf, start, end_)
    return buffer.buffer_get_lines(state, buf, start, end_)
  end

  vim.api.nvim_buf_set_lines = function(buf, start, end_, _, lines)
    buffer.buffer_set_lines(state, buf, start, end_, lines)
  end

  vim.api.nvim_buf_line_count = function(buf)
    local buffer_state = state.buffers[buf]
    return buffer_state and #buffer_state.lines or 0
  end
end

function M.restore_vim(originals)
  vim.fn.shellescape = originals.shellescape
  vim.notify = originals.notify
  vim.fn.input = originals.input
  vim.keymap.set = originals.keymap_set
  vim.cmd = originals.cmd
  for name, original in pairs(originals.api) do
    vim.api[name] = original
  end
end

function M.with_temp_cursor(cursor, fn)
  local original_cursor = vim.api.nvim_win_get_cursor
  vim.api.nvim_win_get_cursor = function()
    return cursor
  end
  local ok, err = pcall(fn)
  vim.api.nvim_win_get_cursor = original_cursor
  if not ok then
    error(err)
  end
end

function M.with_vim_stubs(fn)
  local originals = M.capture_vim_originals()
  local state = M.make_vim_state()

  M.apply_vim_basic_stubs(state)
  M.apply_vim_api_stubs(state)

  local ok, err = pcall(function()
    fn(state)
  end)

  M.restore_vim(originals)

  if not ok then
    error(err)
  end
end

return M
