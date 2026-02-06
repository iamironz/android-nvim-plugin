local M = {}

local assert = require("tests.helpers.assert")
local stubs_helper = require("tests.helpers.stubs")

local function stub_table(target, replacements)
  local saved = {}
  for key, value in pairs(replacements or {}) do
    saved[key] = target[key]
    target[key] = value
  end
  return function()
    for key, value in pairs(saved) do
      target[key] = value
    end
  end
end

local function with_stack_trace_context(options, callback)
  local opts = options or {}
  local current_win = opts.current_win or 10
  local previous_win = opts.previous_win
  local valid_windows = opts.valid_windows or { [current_win] = true }
  local win_buffers = opts.win_buffers or {}
  local buffer_line_counts = opts.buffer_line_counts or {}
  local calls = {
    commands = {},
    set_current = {},
    set_cursor = {},
  }

  local restore_api = stub_table(vim.api, {
    nvim_get_current_line = function()
      return opts.current_line or "at com.foo.Bar.baz(Foo.kt:12)"
    end,
    nvim_win_is_valid = function(win)
      return valid_windows[win] == true
    end,
    nvim_get_current_win = function()
      return current_win
    end,
    nvim_set_current_win = function(win)
      current_win = win
      calls.set_current[#calls.set_current + 1] = win
    end,
    nvim_win_get_buf = function(win)
      return win_buffers[win] or 1
    end,
    nvim_buf_line_count = function(buf)
      return buffer_line_counts[buf] or 200
    end,
    nvim_win_set_cursor = function(win, pos)
      calls.set_cursor[#calls.set_cursor + 1] = {
        win = win,
        line = pos[1],
        col = pos[2],
      }
    end,
  })
  local restore_fn = stub_table(vim.fn, {
    findfile = function()
      return opts.findfile_result or "/workspace/src/Foo.kt"
    end,
    fnameescape = function(path)
      return path
    end,
  })
  local restore_vim = stub_table(vim, {
    cmd = function(command)
      calls.commands[#calls.commands + 1] = command
      if command == "wincmd p" then
        if previous_win then
          current_win = previous_win
          return
        end
        error("No previous window")
      end
    end,
    notify = function() end,
  })

  local ok, err = pcall(function()
    stubs_helper.with_stubs({
      ["android.logcat.parser"] = {
        parse_stack_line = function()
          return opts.parsed or { file = "Foo.kt", line = 12 }
        end,
      },
    }, function()
      package.loaded["android.logcat.stack_trace"] = nil
      local stack_trace = require("android.logcat.stack_trace")
      callback(stack_trace, calls)
    end)
  end)

  restore_api()
  restore_fn()
  restore_vim()

  if not ok then
    error(err)
  end
end

local function stack_trace_falls_back_to_current_window_when_previous_missing()
  with_stack_trace_context({
    current_win = 10,
    valid_windows = { [10] = true },
    parsed = { file = "Foo.kt", line = 12 },
  }, function(stack_trace, calls)
    local ok = pcall(function()
      stack_trace.open_stack_trace("/workspace", 55)
    end)
    assert.eq(ok, true, "stack trace fallback should not crash")
    assert.eq(calls.commands[1], "wincmd p", "tries previous window")
    assert.contains(calls.commands[2] or "", "edit /workspace/src/Foo.kt", "opens file")
    assert.eq(calls.set_cursor[1] and calls.set_cursor[1].win, 10, "cursor window")
    assert.eq(calls.set_cursor[1] and calls.set_cursor[1].line, 12, "cursor line")
  end)
end

local function stack_trace_clamps_cursor_line_to_buffer_size()
  with_stack_trace_context({
    current_win = 10,
    valid_windows = { [10] = true, [5] = true },
    parsed = { file = "Foo.kt", line = 500 },
    win_buffers = { [5] = 2 },
    buffer_line_counts = { [2] = 120 },
  }, function(stack_trace, calls)
    stack_trace.open_stack_trace("/workspace", 5)
    assert.eq(calls.set_current[1], 5, "uses origin window")
    assert.eq(calls.set_cursor[1] and calls.set_cursor[1].line, 120, "cursor clamped")
  end)
end

function M.run()
  stack_trace_falls_back_to_current_window_when_previous_missing()
  stack_trace_clamps_cursor_line_to_buffer_size()
end

return M
