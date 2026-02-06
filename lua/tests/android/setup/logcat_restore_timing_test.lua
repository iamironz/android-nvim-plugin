local M = {}

local assert = require("tests.helpers.assert")
local stubs = require("tests.helpers.stubs")

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

local function selection_store_stub(state)
  local current = state or {}
  return {
    load = function()
      return current
    end,
    save = function(_, next_state)
      current = next_state or {}
      return true
    end,
  }
end

local function setup_stubs(calls)
  return {
    ["android.project.detect"] = {
      detect = function()
        return { root = "/workspace", gradle = { root = "/workspace" } }
      end,
    },
    ["android.ui.autosave"] = {
      setup = function() end,
    },
    ["android.ui.file_watcher"] = {
      setup = function() end,
    },
    ["android.ui.menu"] = {
      show_main_menu = function() end,
      show_targets_menu = function() end,
      show_tools_menu = function() end,
      show_actions_menu = function() end,
    },
    ["android.actions.build"] = {
      build_default = function() end,
      build_prompt = function() end,
      build_pure = function() end,
    },
    ["android.run.executor"] = {
      execute_default = function() end,
      stop_active = function() end,
    },
    ["android.actions.logcat"] = {
      open = function() end,
    },
    ["android.actions.gradle_tasks"] = {
      open = function() end,
    },
    ["android.actions.ios.build"] = {
      build = function() end,
      deploy = function() end,
    },
    ["android.state.selection_store"] = selection_store_stub({
      logcat = { restore_on_startup = true },
    }),
    ["android.logcat.manager"] = {
      restore_on_startup = function(workspace_root)
        calls.restore = calls.restore + 1
        calls.restore_root = workspace_root
      end,
    },
  }
end

local function setup_defers_logcat_restore_until_vimenter()
  local calls = {
    restore = 0,
    restore_root = nil,
    schedule = 0,
    autocmd_event = nil,
    autocmd_opts = nil,
  }
  local save, restore = create_saver()

  save(vim.api, "nvim_create_user_command")
  save(vim.keymap, "set")
  save(vim.api, "nvim_create_autocmd")

  vim.api.nvim_create_user_command = function()
    return nil
  end
  vim.keymap.set = function() end
  vim.api.nvim_create_autocmd = function(event, opts)
    calls.autocmd_event = event
    calls.autocmd_opts = opts
    return 1
  end

  stubs.with_stubs(setup_stubs(calls), function()
    package.loaded["android"] = nil
    local android = require("android")
    android._did_enter = function()
      return false
    end
    android._schedule = function(fn)
      calls.schedule = calls.schedule + 1
      fn()
    end

    android.setup()

    assert.eq(calls.restore, 0, "restore deferred before VimEnter")
    assert.eq(calls.autocmd_event, "VimEnter", "restore hooks VimEnter")
    assert.eq(calls.autocmd_opts and calls.autocmd_opts.once, true, "restore hook once")
    assert.is_true(type(calls.autocmd_opts.callback) == "function", "restore callback")

    calls.autocmd_opts.callback()

    assert.eq(calls.schedule, 1, "restore scheduled after VimEnter")
    assert.eq(calls.restore, 1, "restore after VimEnter")
    assert.eq(calls.restore_root, "/workspace", "restore workspace root")
  end)

  restore()
end

function M.run()
  setup_defers_logcat_restore_until_vimenter()
end

return M
