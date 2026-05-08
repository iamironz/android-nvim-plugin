local buffer = require("tests.helpers.build_stream.buffer")

local M = {}

function M.make_panel_state()
  return {
    opened = false,
    open_opts = nil,
    handle = nil,
    cleared = false,
    lines = {},
    header_history = {},
    replaced_body = nil,
    replaced_body_history = {},
    names = nil,
    name_history = {},
    closed = false,
  }
end

function M.make_panel_stub(panel_state, vim_state)
  local body_buf = vim_state.current_buf
  local body_win = vim_state.current_win
  local control_buf = body_buf + 1
  local control_win = body_win + 1

  return {
    open = function(opts)
      panel_state.opened = true
      panel_state.open_opts = opts or {}
      panel_state.handle = {
        buf = body_buf,
        win = body_win,
        control_buf = control_buf,
        control_win = control_win,
      }
      vim_state.body_buf = body_buf
      vim_state.body_win = body_win
      vim_state.control_buf = control_buf
      vim_state.control_win = control_win
      buffer.ensure_buffer(vim_state, body_buf)
      if panel_state.open_opts.layout == "dock" then
        buffer.ensure_buffer(vim_state, control_buf)
      end
      return panel_state.handle
    end,
    clear = function()
      panel_state.cleared = true
      vim_state.header_count = panel_state.open_opts.layout == "dock" and 0 or vim_state.header_count
      buffer.buffer_set_lines(vim_state, body_buf, 0, -1, {})
      if panel_state.open_opts.layout == "dock" then
        buffer.buffer_set_lines(vim_state, control_buf, 0, -1, {})
      end
    end,
    append = function(lines)
      buffer.append_lines(panel_state.lines, lines)
      local previous = vim_state.current_buf
      vim_state.current_buf = body_buf
      buffer.append_body_lines_in_buffer(vim_state, lines)
      vim_state.current_buf = previous
    end,
    set_header_lines = function(lines)
      local snapshot = {}
      buffer.append_lines(snapshot, lines)
      table.insert(panel_state.header_history, snapshot)
      if panel_state.open_opts.layout == "dock" then
        vim_state.header_count = 0
        buffer.buffer_set_lines(vim_state, control_buf, 0, -1, lines or {})
      else
        buffer.set_header_lines_in_buffer(vim_state, lines)
      end
    end,
    replace_body = function(lines)
      panel_state.replaced_body = lines
      panel_state.replaced_body_history[#panel_state.replaced_body_history + 1] = lines
      local previous = vim_state.current_buf
      vim_state.current_buf = body_buf
      buffer.set_body_lines_in_buffer(vim_state, lines)
      vim_state.current_buf = previous
    end,
    trim_body = function(max_lines)
      local previous = vim_state.current_buf
      vim_state.current_buf = body_buf
      local trimmed = buffer.trim_body_lines_in_buffer(vim_state, max_lines)
      vim_state.current_buf = previous
      if trimmed then
        panel_state.lines = trimmed
      end
    end,
    set_names = function(names)
      local snapshot = {
        body = names and names.body or nil,
        control = names and names.control or nil,
      }
      panel_state.names = snapshot
      panel_state.name_history[#panel_state.name_history + 1] = snapshot
    end,
    close = function()
      panel_state.closed = true
      return true
    end,
  }
end

return M
