local buffer = require("tests.helpers.build_stream.buffer")

local M = {}

function M.make_panel_state()
  return {
    opened = false,
    cleared = false,
    lines = {},
    header_history = {},
    replaced_body = nil,
    replaced_body_history = {},
  }
end

function M.make_panel_stub(panel_state, vim_state)
  return {
    open = function()
      panel_state.opened = true
    end,
    clear = function()
      panel_state.cleared = true
      vim_state.header_count = 0
      buffer.buffer_set_lines(vim_state, vim_state.current_buf, 0, -1, {})
    end,
    append = function(lines)
      buffer.append_lines(panel_state.lines, lines)
      buffer.append_body_lines_in_buffer(vim_state, lines)
    end,
    set_header_lines = function(lines)
      local snapshot = {}
      buffer.append_lines(snapshot, lines)
      table.insert(panel_state.header_history, snapshot)
      buffer.set_header_lines_in_buffer(vim_state, lines)
    end,
    replace_body = function(lines)
      panel_state.replaced_body = lines
      panel_state.replaced_body_history[#panel_state.replaced_body_history + 1] = lines
      buffer.set_body_lines_in_buffer(vim_state, lines)
    end,
    trim_body = function(max_lines)
      local trimmed = buffer.trim_body_lines_in_buffer(vim_state, max_lines)
      if trimmed then
        panel_state.lines = trimmed
      end
    end,
  }
end

return M
