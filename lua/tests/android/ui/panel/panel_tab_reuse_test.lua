local M = {}

local assert = require("tests.helpers.assert")
local panel_vim = require("tests.helpers.panel_vim")

local function open_dock_in_new_tab_creates_new_windows_in_that_tab()
  panel_vim.with_panel_module({ on_cmd = panel_vim.on_split_create_window }, function(panel, state)
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
end

function M.run()
  open_dock_in_new_tab_creates_new_windows_in_that_tab()
end

return M
