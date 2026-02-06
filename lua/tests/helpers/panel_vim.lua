local M = {}

local function create_state(opts)
  local options = opts or {}
  local current_win = options.current_win or 1000
  local current_tab = options.current_tab or 1

  return {
    commands = {},
    buffers = {},
    windows = {},
    next_buf_id = 1,
    next_win = options.next_win or 100,
    current_win = current_win,
    current_tab = current_tab,
    valid_wins = { [current_win] = true },
    win_tabs = { [current_win] = current_tab },
    buf_options = {},
    buf_names = {},
    win_options = {},
    win_option_calls = {},
  }
end

local function create_restore()
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

local function ensure_buffer(state, buf)
  if not state.buffers[buf] then
    state.buffers[buf] = { lines = {} }
  end
  return state.buffers[buf]
end

local function set_buffer_lines(state, buf, start, finish, lines)
  local buffer = ensure_buffer(state, buf)
  local start_index = start
  local finish_index = finish

  if start_index < 0 then
    start_index = #buffer.lines
  end
  if finish_index < 0 then
    finish_index = #buffer.lines
  end

  local next_lines = {}
  for i = 1, start_index do
    next_lines[#next_lines + 1] = buffer.lines[i]
  end
  for _, line in ipairs(lines or {}) do
    next_lines[#next_lines + 1] = line
  end
  for i = finish_index + 1, #buffer.lines do
    next_lines[#next_lines + 1] = buffer.lines[i]
  end
  buffer.lines = next_lines
end

local function get_buffer_lines(state, buf, start, finish)
  local buffer = ensure_buffer(state, buf)
  local start_index = start + 1
  local finish_index = finish == -1 and #buffer.lines or finish
  local result = {}

  for i = start_index, finish_index do
    result[#result + 1] = buffer.lines[i]
  end
  return result
end

local function create_mock_api(save)
  return function(name, fn)
    save(vim.api, name)
    vim.api[name] = fn
  end
end

local function add_command_api(state, mock_api)
  mock_api("nvim_command", function(cmd)
    state.commands[#state.commands + 1] = cmd
  end)
end

local function add_buffer_api(state, mock_api)
  mock_api("nvim_create_buf", function(listed, scratch)
    local id = state.next_buf_id
    state.next_buf_id = state.next_buf_id + 1
    state.buffers[id] = { listed = listed, scratch = scratch, lines = {} }
    return id
  end)

  mock_api("nvim_buf_set_lines", function(buf, start, finish, _, lines)
    set_buffer_lines(state, buf, start, finish, lines)
  end)

  mock_api("nvim_buf_get_lines", function(buf, start, finish)
    return get_buffer_lines(state, buf, start, finish)
  end)

  mock_api("nvim_buf_set_option", function(buf, name, value)
    state.buf_options[buf] = state.buf_options[buf] or {}
    state.buf_options[buf][name] = value
  end)

  mock_api("nvim_buf_get_option", function(buf, name)
    local opts = state.buf_options[buf] or {}
    if opts[name] ~= nil then
      return opts[name]
    end
    if name == "modifiable" then
      return true
    end
    return nil
  end)

  mock_api("nvim_buf_set_name", function(buf, name)
    state.buf_names[buf] = name
  end)

  mock_api("nvim_buf_is_valid", function(buf)
    return state.buffers[buf] ~= nil
  end)

  mock_api("nvim_buf_line_count", function(buf)
    local buffer = state.buffers[buf]
    return buffer and #buffer.lines or 0
  end)
end

local function add_window_api(state, mock_api)
  mock_api("nvim_get_current_win", function()
    return state.current_win
  end)

  mock_api("nvim_set_current_win", function(win)
    state.current_win = win
    if state.win_tabs[win] then
      state.current_tab = state.win_tabs[win]
    end
  end)

  mock_api("nvim_win_set_buf", function(win, buf)
    state.windows[win] = buf
    state.valid_wins[win] = true
    state.win_tabs[win] = state.win_tabs[win] or state.current_tab
  end)

  mock_api("nvim_win_close", function(win)
    state.windows[win] = nil
    state.valid_wins[win] = nil
  end)

  mock_api("nvim_win_is_valid", function(win)
    return state.valid_wins[win] == true
  end)

  mock_api("nvim_win_set_cursor", function() end)
  mock_api("nvim_win_set_height", function() end)

  mock_api("nvim_win_set_option", function(win, name, value)
    state.win_options[win] = state.win_options[win] or {}
    state.win_options[win][name] = value
    state.win_option_calls[#state.win_option_calls + 1] = {
      win = win,
      name = name,
      value = value,
    }
  end)
end

local function add_tab_and_group_api(state, mock_api)
  mock_api("nvim_get_current_tabpage", function()
    return state.current_tab
  end)

  mock_api("nvim_win_get_tabpage", function(win)
    return state.win_tabs[win] or state.current_tab
  end)

  mock_api("nvim_create_augroup", function()
    return 1
  end)
  mock_api("nvim_create_autocmd", function() end)
  mock_api("nvim_del_augroup_by_id", function() end)
end

local function add_api_stubs(state, save)
  local mock_api = create_mock_api(save)
  add_command_api(state, mock_api)
  add_buffer_api(state, mock_api)
  add_window_api(state, mock_api)
  add_tab_and_group_api(state, mock_api)
end

function M.on_split_create_window(state, cmd)
  if cmd ~= "botright split" and cmd ~= "aboveleft split" then
    return
  end

  local win = state.next_win
  state.next_win = state.next_win + 1
  state.valid_wins[win] = true
  state.win_tabs[win] = state.current_tab
  state.current_win = win
end

function M.with_mock(opts, run)
  local options = opts or {}
  local state = create_state(options)
  local save, restore = create_restore()

  save(vim, "cmd")
  vim.cmd = function(cmd)
    state.commands[#state.commands + 1] = cmd
    if options.on_cmd then
      options.on_cmd(state, cmd)
    end
  end

  add_api_stubs(state, save)

  local ok, err = pcall(run, state)
  restore()
  if not ok then
    error(err)
  end
end

function M.with_panel_module(opts, run)
  M.with_mock(opts, function(state)
    package.loaded["android.ui.panel"] = nil
    local ok, panel = pcall(require, "android.ui.panel")
    if not ok then
      error(panel)
    end
    run(panel, state)
  end)
end

return M
