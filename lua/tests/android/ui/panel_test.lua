local M = {}
local assert = require("tests.helpers.assert")

local function create_vim_state()
  return {
    commands = {},
    buffers = {},
    windows = {},
    next_buf_id = 1,
    buf_options = {},
    win_options = {},
    win_option_calls = {},
  }
end

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
      for key, val in pairs(keys) do
        tbl[key] = val
      end
    end
  end

  return save, restore
end

local function create_mock_api(save)
  return function(name, fn)
    save(vim.api, name)
    vim.api[name] = fn
  end
end

local function mock_vim_cmd(state, save)
  save(vim, "cmd")
  vim.cmd = function(cmd)
    table.insert(state.commands, cmd)
  end
end

local function mock_api_commands(state, mock_api)
  mock_api("nvim_command", function(cmd)
    table.insert(state.commands, cmd)
  end)
end

local function mock_api_buffers(state, mock_api)
  mock_api("nvim_create_buf", function(listed, scratch)
    local id = state.next_buf_id
    state.next_buf_id = state.next_buf_id + 1
    state.buffers[id] = { listed = listed, scratch = scratch, lines = {} }
    return id
  end)

  mock_api("nvim_buf_set_lines", function(buf, start, end_, ...)
    local _, lines = ...
    local b = state.buffers[buf]
    if not b then
      return
    end

    if start == -1 and end_ == -1 then
      for _, line in ipairs(lines) do
        table.insert(b.lines, line)
      end
    elseif end_ == -1 then
      local new_lines = {}
      local start_index = start + 1
      for i = 1, start_index - 1 do
        new_lines[#new_lines + 1] = b.lines[i]
      end
      for _, line in ipairs(lines) do
        new_lines[#new_lines + 1] = line
      end
      b.lines = new_lines
    end
  end)

  mock_api("nvim_buf_get_lines", function(buf, start, end_, strict)
    local b = state.buffers[buf]
    if not b then
      return {}
    end

    local start_index = start + 1
    local end_index = end_ == -1 and #b.lines or end_
    local result = {}
    for i = start_index, end_index do
      result[#result + 1] = b.lines[i]
    end
    return result
  end)

  mock_api("nvim_buf_set_option", function(buf, name, value)
    if not state.buf_options[buf] then
      state.buf_options[buf] = {}
    end
    state.buf_options[buf][name] = value
  end)

  mock_api("nvim_buf_is_valid", function(buf)
    return state.buffers[buf] ~= nil
  end)

  mock_api("nvim_buf_line_count", function(buf)
    local b = state.buffers[buf]
    return b and #b.lines or 0
  end)
end

local function mock_api_windows(state, mock_api)
  mock_api("nvim_win_set_buf", function(win, buf)
    state.windows[win] = buf
  end)

  mock_api("nvim_get_current_win", function()
    return 1000
  end)

  mock_api("nvim_win_set_cursor", function(win, pos)
  end)

  mock_api("nvim_win_close", function(win, force)
    state.windows[win] = nil
  end)

  mock_api("nvim_win_is_valid", function(win)
    return state.windows[win] ~= nil or win == 1000
  end)

  mock_api("nvim_win_set_option", function(win, name, value)
    if not state.win_options[win] then
      state.win_options[win] = {}
    end
    state.win_options[win][name] = value
    state.win_option_calls[#state.win_option_calls + 1] = {
      win = win,
      name = name,
      value = value,
    }
  end)
end

local function mock_vim_api()
  local state = create_vim_state()
  local save, restore = create_saver()

  mock_vim_cmd(state, save)

  local mock_api = create_mock_api(save)
  mock_api_commands(state, mock_api)
  mock_api_buffers(state, mock_api)
  mock_api_windows(state, mock_api)

  return state, restore
end

local function load_panel()
  package.loaded["android.ui.panel"] = nil
  local ok, panel = pcall(require, "android.ui.panel")
  assert.is_true(ok, "panel module loads")
  return panel
end

local function with_panel_api(run)
  local api_state, restore = mock_vim_api()
  local ok, panel = pcall(load_panel)
  if not ok then
    restore()
    error(panel)
  end

  local ok_run, err = pcall(run, panel, api_state)
  restore()
  if not ok_run then error(err) end
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
    -- Arrange
    local expected_buftype = "nofile"
    local expected_filetype = "android-log"

    -- Act
    panel.open()

    -- Assert
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

local function close_returns_true_and_closes_window_after_open()
  with_panel_api(function(panel, api_state)
    -- Arrange
    with_open_panel(panel, api_state)

    -- Act
    local closed = panel.close()

    -- Assert
    assert.eq(closed, true, "close returns true")
    assert.eq(api_state.windows[1000], nil, "window closed")
  end)
end

local function close_returns_false_when_panel_never_opened()
  with_panel_api(function(panel, _)
    -- Arrange
    local expected = false

    -- Act
    local closed = panel.close()

    -- Assert
    assert.eq(closed, expected, "close returns false")
  end)
end

local function append_adds_lines_to_open_buffer()
  with_panel_api(function(panel, api_state)
    -- Arrange
    local buf_id = with_open_panel(panel, api_state)
    local appended = { "line1", "line2" }

    -- Act
    panel.append(appended)

    -- Assert
    assert_buffer_lines(api_state, buf_id, appended, "append")
  end)
end

local function clear_removes_all_lines_from_open_buffer()
  with_panel_api(function(panel, api_state)
    -- Arrange
    local buf_id = with_open_panel(panel, api_state)
    panel.append({ "line1" })

    -- Act
    panel.clear()

    -- Assert
    assert_buffer_lines(api_state, buf_id, {}, "clear")
  end)
end

local function set_header_lines_prepends_header_to_existing_body()
  with_panel_api(function(panel, api_state)
    -- Arrange
    local buf_id = with_open_panel(panel, api_state)
    panel.append({ "body1", "body2" })
    local header_lines = { "Header A", "Header B" }

    -- Act
    panel.set_header_lines(header_lines)

    -- Assert
    local expected = { "Header A", "Header B", "body1", "body2" }
    assert_buffer_lines(api_state, buf_id, expected, "set header")
  end)
end

local function clear_body_removes_only_body_lines()
  with_panel_api(function(panel, api_state)
    -- Arrange
    local buf_id = with_open_panel(panel, api_state)
    panel.set_header_lines({ "Header" })
    panel.append({ "body" })

    -- Act
    panel.clear_body()

    -- Assert
    assert_buffer_lines(api_state, buf_id, { "Header" }, "clear body")
  end)
end

local function replace_body_overwrites_body_and_preserves_header()
  with_panel_api(function(panel, api_state)
    -- Arrange
    local buf_id = with_open_panel(panel, api_state)
    panel.set_header_lines({ "Header" })
    panel.append({ "old" })
    local new_body = { "new1", "new2" }

    -- Act
    panel.replace_body(new_body)

    -- Assert
    local expected = { "Header", new_body[1], new_body[2] }
    assert_buffer_lines(api_state, buf_id, expected, "replace body")
  end)
end

function M.run()
  open_creates_split_window_and_configures_buffer()
  open_sets_winfixbuf_for_inline_window()
  open_dock_sets_winfixbuf_for_body_and_control_windows()
  append_adds_lines_to_open_buffer()
  clear_removes_all_lines_from_open_buffer()
  set_header_lines_prepends_header_to_existing_body()
  clear_body_removes_only_body_lines()
  replace_body_overwrites_body_and_preserves_header()
  close_returns_true_and_closes_window_after_open()
  close_returns_false_when_panel_never_opened()
end

return M
