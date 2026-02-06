local M = {}

local assert = require("tests.helpers.assert")

local function setup_mock()
  local state = {
    commands = {},
    next_buf = 1,
    next_win = 100,
    current_tab = 1,
    current_win = 1,
    valid_wins = { [1] = true },
    win_tabs = { [1] = 1 },
    win_bufs = {},
    valid_bufs = {},
    buf_opts = {},
  }

  local saved = {}
  local function save(tbl, key)
    saved[tbl] = saved[tbl] or {}
    if saved[tbl][key] == nil then
      saved[tbl][key] = tbl[key]
    end
  end

  local function mock(name, fn)
    save(vim.api, name)
    vim.api[name] = fn
  end

  save(vim, "cmd")
  vim.cmd = function(cmd)
    state.commands[#state.commands + 1] = cmd
    if cmd == "botright split" or cmd == "aboveleft split" then
      local win = state.next_win
      state.next_win = state.next_win + 1
      state.valid_wins[win] = true
      state.win_tabs[win] = state.current_tab
      state.current_win = win
    end
  end

  mock("nvim_create_buf", function()
    local buf = state.next_buf
    state.next_buf = state.next_buf + 1
    state.valid_bufs[buf] = true
    return buf
  end)

  mock("nvim_buf_is_valid", function(buf)
    return state.valid_bufs[buf] == true
  end)

  mock("nvim_buf_set_option", function(buf, name, value)
    state.buf_opts[buf] = state.buf_opts[buf] or {}
    state.buf_opts[buf][name] = value
  end)

  mock("nvim_buf_get_option", function(buf, name)
    local opts = state.buf_opts[buf] or {}
    if opts[name] == nil then
      if name == "modifiable" then
        return true
      end
      return nil
    end
    return opts[name]
  end)

  mock("nvim_buf_set_lines", function() end)

  mock("nvim_win_set_buf", function(win, buf)
    state.win_bufs[win] = buf
    if not state.win_tabs[win] then
      state.win_tabs[win] = state.current_tab
    end
    state.valid_wins[win] = true
  end)

  mock("nvim_get_current_win", function()
    return state.current_win
  end)

  mock("nvim_set_current_win", function(win)
    state.current_win = win
    if state.win_tabs[win] then
      state.current_tab = state.win_tabs[win]
    end
  end)

  mock("nvim_win_is_valid", function(win)
    return state.valid_wins[win] == true
  end)

  mock("nvim_win_close", function(win)
    state.valid_wins[win] = nil
    state.win_bufs[win] = nil
  end)

  mock("nvim_win_set_option", function() end)
  mock("nvim_win_set_height", function() end)
  mock("nvim_win_set_cursor", function() end)
  mock("nvim_buf_line_count", function() return 0 end)

  mock("nvim_get_current_tabpage", function()
    return state.current_tab
  end)

  mock("nvim_win_get_tabpage", function(win)
    return state.win_tabs[win]
  end)

  mock("nvim_create_augroup", function()
    return 1
  end)

  mock("nvim_create_autocmd", function() end)
  mock("nvim_del_augroup_by_id", function() end)

  local function restore()
    for tbl, keys in pairs(saved) do
      for key, value in pairs(keys) do
        tbl[key] = value
      end
    end
  end

  return state, restore
end

local function open_dock_in_new_tab_creates_new_windows_in_that_tab()
  local state, restore = setup_mock()
  package.loaded["android.ui.panel"] = nil

  local ok, err = pcall(function()
    local panel = require("android.ui.panel")

    panel.open({ layout = "dock", control_height = 1 })
    local first = panel.handle()

    state.commands = {}
    state.current_tab = 2
    state.current_win = 2
    state.valid_wins[2] = true
    state.win_tabs[2] = 2

    panel.open({ layout = "dock", control_height = 1 })
    local second = panel.handle()

    assert.eq(state.commands[1], "botright split", "reopen split body")
    assert.eq(state.commands[2], "aboveleft split", "reopen split control")
    assert.eq(state.win_tabs[second.win], 2, "body window in active tab")
    assert.eq(state.win_tabs[second.control_win], 2, "control window in active tab")
    assert.eq(first.win == second.win, false, "new body window id")
  end)

  restore()
  if not ok then
    error(err)
  end
end

function M.run()
  open_dock_in_new_tab_creates_new_windows_in_that_tab()
end

return M
