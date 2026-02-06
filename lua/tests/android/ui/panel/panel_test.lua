local M = {}

local assert = require("tests.helpers.assert")
local panel_vim = require("tests.helpers.panel_vim")

local function with_panel_api(run)
  panel_vim.with_panel_module({}, run)
end

local function last_buffer_id(api_state)
  return api_state.next_buf_id - 1
end

local function with_open_panel(panel, api_state)
  panel.open()
  return last_buffer_id(api_state)
end

local function buffer_lines(api_state, buf_id)
  local id = buf_id or last_buffer_id(api_state)
  local buf = api_state.buffers[id]
  return buf and buf.lines or {}
end

local function assert_buffer_lines(api_state, buf_id, expected, label)
  local lines = buffer_lines(api_state, buf_id)
  local prefix = label and (label .. " ") or ""
  assert.eq(#lines, #expected, prefix .. "line count")
  for i, line in ipairs(expected) do
    assert.eq(lines[i], line, prefix .. "line " .. i)
  end
end

local function count_win_option_calls(api_state, name, value)
  local total = 0
  for _, call in ipairs(api_state.win_option_calls or {}) do
    if call.name == name and call.value == value then
      total = total + 1
    end
  end
  return total
end

local function open_creates_split_window_and_configures_buffer()
  with_panel_api(function(panel, api_state)
    local expected_buftype = "nofile"
    local expected_filetype = "android-log"

    panel.open()

    local commands = table.concat(api_state.commands, " ")
    assert.contains(commands, "botright split", "should split window")
    assert.eq(api_state.next_buf_id > 1, true, "should create buffer")

    local buf_id = last_buffer_id(api_state)
    local opts = api_state.buf_options[buf_id]
    assert.eq(opts.buftype, expected_buftype, "buftype")
    assert.eq(opts.swapfile, false, "swapfile")
    assert.eq(opts.filetype, expected_filetype, "filetype")
  end)
end

local function open_sets_winfixbuf_for_inline_window()
  with_panel_api(function(panel, api_state)
    panel.open()

    local pinned = count_win_option_calls(api_state, "winfixbuf", true)
    assert.eq(pinned, 1, "inline winfixbuf")
  end)
end

local function open_dock_sets_winfixbuf_for_body_and_control_windows()
  with_panel_api(function(panel, api_state)
    panel.open({ layout = "dock", control_height = 1 })

    local pinned = count_win_option_calls(api_state, "winfixbuf", true)
    assert.eq(pinned >= 2, true, "dock winfixbuf")
  end)
end

local function open_dock_preserve_focus_keeps_origin_window_selected()
  panel_vim.with_panel_module(
    { on_cmd = panel_vim.on_split_create_window },
    function(panel, api_state)
      local origin_win = api_state.current_win

      panel.open({
        layout = "dock",
        control_height = 1,
        preserve_focus = true,
        origin_win = origin_win,
      })

      assert.eq(api_state.current_win, origin_win, "preserve focus")
    end
  )
end

local function close_returns_true_and_closes_window_after_open()
  with_panel_api(function(panel, api_state)
    with_open_panel(panel, api_state)

    local closed = panel.close()

    assert.eq(closed, true, "close returns true")
    assert.eq(api_state.windows[api_state.current_win], nil, "window closed")
  end)
end

local function close_returns_false_when_panel_never_opened()
  with_panel_api(function(panel)
    local closed = panel.close()
    assert.eq(closed, false, "close returns false")
  end)
end

local function append_adds_lines_to_open_buffer()
  with_panel_api(function(panel, api_state)
    local buf_id = with_open_panel(panel, api_state)
    local appended = { "line1", "line2" }

    panel.append(appended)

    assert_buffer_lines(api_state, buf_id, appended, "append")
  end)
end

local function clear_removes_all_lines_from_open_buffer()
  with_panel_api(function(panel, api_state)
    local buf_id = with_open_panel(panel, api_state)
    panel.append({ "line1" })

    panel.clear()

    assert_buffer_lines(api_state, buf_id, {}, "clear")
  end)
end

local function set_header_lines_prepends_header_to_existing_body()
  with_panel_api(function(panel, api_state)
    local buf_id = with_open_panel(panel, api_state)
    panel.append({ "body1", "body2" })
    local header_lines = { "Header A", "Header B" }

    panel.set_header_lines(header_lines)

    local expected = { "Header A", "Header B", "body1", "body2" }
    assert_buffer_lines(api_state, buf_id, expected, "set header")
  end)
end

local function clear_body_removes_only_body_lines()
  with_panel_api(function(panel, api_state)
    local buf_id = with_open_panel(panel, api_state)
    panel.set_header_lines({ "Header" })
    panel.append({ "body" })

    panel.clear_body()

    assert_buffer_lines(api_state, buf_id, { "Header" }, "clear body")
  end)
end

local function replace_body_overwrites_body_and_preserves_header()
  with_panel_api(function(panel, api_state)
    local buf_id = with_open_panel(panel, api_state)
    panel.set_header_lines({ "Header" })
    panel.append({ "old" })
    local new_body = { "new1", "new2" }

    panel.replace_body(new_body)

    local expected = { "Header", new_body[1], new_body[2] }
    assert_buffer_lines(api_state, buf_id, expected, "replace body")
  end)
end

function M.run()
  open_creates_split_window_and_configures_buffer()
  open_sets_winfixbuf_for_inline_window()
  open_dock_sets_winfixbuf_for_body_and_control_windows()
  open_dock_preserve_focus_keeps_origin_window_selected()
  append_adds_lines_to_open_buffer()
  clear_removes_all_lines_from_open_buffer()
  set_header_lines_prepends_header_to_existing_body()
  clear_body_removes_only_body_lines()
  replace_body_overwrites_body_and_preserves_header()
  close_returns_true_and_closes_window_after_open()
  close_returns_false_when_panel_never_opened()
end

return M
