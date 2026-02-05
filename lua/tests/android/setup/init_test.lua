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

local function build_setup_counter(calls, key)
  return function()
    calls[key] = calls[key] + 1
  end
end

local function find_map(calls, lhs)
  for _, call in ipairs(calls or {}) do
    if call.lhs == lhs then
      return call
    end
  end
  return nil
end

local function setup_calls_autosave_and_file_watcher()
  local calls = { autosave = 0, file_watcher = 0 }
  local save, restore = create_saver()

  save(vim.api, "nvim_create_user_command")
  save(vim.keymap, "set")
  vim.api.nvim_create_user_command = function()
    return nil
  end
  vim.keymap.set = function() end

  stubs.with_stubs({
    ["android.project.detect"] = {
      detect = function()
        return { gradle = { root = "/workspace" } }
      end,
    },
    ["android.ui.autosave"] = {
      setup = build_setup_counter(calls, "autosave"),
    },
    ["android.ui.file_watcher"] = {
      setup = build_setup_counter(calls, "file_watcher"),
    },
    ["android.ui.menu"] = {
      show_main_menu = function() end,
      show_targets_menu = function() end,
      show_tools_menu = function() end,
    },
    ["android.ui.actions"] = {
      open = function() end,
    },
    ["android.actions.build"] = {
      build_default = function() end,
    },
  }, function()
    package.loaded["android"] = nil
    require("android").setup()
  end)

  restore()

  assert.eq(calls.autosave, 1, "autosave setup called")
  assert.eq(calls.file_watcher, 1, "file watcher setup called")
end

local function setup_passes_workspace_root_to_file_watcher()
  local calls = { autosave = 0, file_watcher = 0 }
  local args = {}
  local save, restore = create_saver()

  save(vim.api, "nvim_create_user_command")
  save(vim.keymap, "set")
  vim.api.nvim_create_user_command = function()
    return nil
  end
  vim.keymap.set = function() end

  stubs.with_stubs({
    ["android.project.detect"] = {
      detect = function()
        return { root = "/workspace", gradle = { root = "/workspace" } }
      end,
    },
    ["android.ui.autosave"] = {
      setup = build_setup_counter(calls, "autosave"),
    },
    ["android.ui.file_watcher"] = {
      setup = function(opts)
        calls.file_watcher = calls.file_watcher + 1
        args.file_watcher = opts
      end,
    },
    ["android.ui.menu"] = {
      show_main_menu = function() end,
      show_targets_menu = function() end,
      show_tools_menu = function() end,
    },
    ["android.ui.actions"] = {
      open = function() end,
    },
    ["android.actions.build"] = {
      build_default = function() end,
    },
  }, function()
    package.loaded["android"] = nil
    require("android").setup()
  end)

  restore()

  assert.eq(args.file_watcher.workspace_root, "/workspace", "workspace root passed")
end

local function setup_skips_autosave_when_disabled()
  local calls = { autosave = 0, file_watcher = 0 }
  local save, restore = create_saver()

  save(vim.api, "nvim_create_user_command")
  save(vim.keymap, "set")
  vim.api.nvim_create_user_command = function()
    return nil
  end
  vim.keymap.set = function() end

  stubs.with_stubs({
    ["android.project.detect"] = {
      detect = function()
        return { gradle = { root = "/workspace" } }
      end,
    },
    ["android.ui.autosave"] = {
      setup = build_setup_counter(calls, "autosave"),
    },
    ["android.ui.file_watcher"] = {
      setup = build_setup_counter(calls, "file_watcher"),
    },
    ["android.ui.menu"] = {
      show_main_menu = function() end,
      show_targets_menu = function() end,
      show_tools_menu = function() end,
    },
    ["android.ui.actions"] = {
      open = function() end,
    },
    ["android.actions.build"] = {
      build_default = function() end,
    },
  }, function()
    package.loaded["android"] = nil
    require("android").setup({ ui = { autosave = false } })
  end)

  restore()

  assert.eq(calls.autosave, 0, "autosave setup skipped")
  assert.eq(calls.file_watcher, 1, "file watcher setup called")
end

local function setup_handles_non_table_ui_config()
  local calls = { autosave = 0, file_watcher = 0 }
  local save, restore = create_saver()

  save(vim.api, "nvim_create_user_command")
  save(vim.keymap, "set")
  vim.api.nvim_create_user_command = function()
    return nil
  end
  vim.keymap.set = function() end

  stubs.with_stubs({
    ["android.project.detect"] = {
      detect = function()
        return { gradle = { root = "/workspace" } }
      end,
    },
    ["android.ui.autosave"] = {
      setup = build_setup_counter(calls, "autosave"),
    },
    ["android.ui.file_watcher"] = {
      setup = build_setup_counter(calls, "file_watcher"),
    },
    ["android.ui.menu"] = {
      show_main_menu = function() end,
      show_targets_menu = function() end,
      show_tools_menu = function() end,
    },
    ["android.ui.actions"] = {
      open = function() end,
    },
    ["android.actions.build"] = {
      build_default = function() end,
    },
  }, function()
    package.loaded["android"] = nil
    require("android").setup({ ui = false })
  end)

  restore()

  assert.eq(calls.autosave, 1, "autosave setup called")
  assert.eq(calls.file_watcher, 1, "file watcher setup called")
end

local function setup_skips_file_watcher_when_disabled()
  local calls = { autosave = 0, file_watcher = 0 }
  local save, restore = create_saver()

  save(vim.api, "nvim_create_user_command")
  save(vim.keymap, "set")
  vim.api.nvim_create_user_command = function()
    return nil
  end
  vim.keymap.set = function() end

  stubs.with_stubs({
    ["android.project.detect"] = {
      detect = function()
        return { gradle = { root = "/workspace" } }
      end,
    },
    ["android.ui.autosave"] = {
      setup = build_setup_counter(calls, "autosave"),
    },
    ["android.ui.file_watcher"] = {
      setup = build_setup_counter(calls, "file_watcher"),
    },
    ["android.ui.menu"] = {
      show_main_menu = function() end,
      show_targets_menu = function() end,
      show_tools_menu = function() end,
    },
    ["android.ui.actions"] = {
      open = function() end,
    },
    ["android.actions.build"] = {
      build_default = function() end,
    },
  }, function()
    package.loaded["android"] = nil
    require("android").setup({ ui = { file_watcher = false } })
  end)

  restore()

  assert.eq(calls.autosave, 1, "autosave setup called")
  assert.eq(calls.file_watcher, 0, "file watcher setup skipped")
end

local function setup_skips_autosave_when_no_workspace()
  local calls = { autosave = 0, file_watcher = 0 }
  local save, restore = create_saver()

  save(vim.api, "nvim_create_user_command")
  save(vim.keymap, "set")
  vim.api.nvim_create_user_command = function()
    return nil
  end
  vim.keymap.set = function() end

  stubs.with_stubs({
    ["android.project.detect"] = {
      detect = function()
        return nil
      end,
    },
    ["android.ui.autosave"] = {
      setup = build_setup_counter(calls, "autosave"),
    },
    ["android.ui.file_watcher"] = {
      setup = build_setup_counter(calls, "file_watcher"),
    },
    ["android.ui.menu"] = {
      show_main_menu = function() end,
      show_targets_menu = function() end,
      show_tools_menu = function() end,
    },
    ["android.ui.actions"] = {
      open = function() end,
    },
    ["android.actions.build"] = {
      build_default = function() end,
    },
  }, function()
    package.loaded["android"] = nil
    require("android").setup()
  end)

  restore()

  assert.eq(calls.autosave, 0, "autosave setup skipped")
  assert.eq(calls.file_watcher, 0, "file watcher setup skipped")
end

local function setup_registers_keymaps()
  local calls = {}
  local save, restore = create_saver()

  save(vim.api, "nvim_create_user_command")
  save(vim.keymap, "set")
  vim.api.nvim_create_user_command = function()
    return nil
  end
  vim.keymap.set = function(mode, lhs, rhs, opts)
    table.insert(calls, { mode = mode, lhs = lhs, rhs = rhs, opts = opts or {} })
  end

  stubs.with_stubs({
    ["android.project.detect"] = {
      detect = function()
        return nil
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
    },
    ["android.ui.actions"] = {
      open = function() end,
    },
    ["android.actions.build"] = {
      build_default = function() end,
    },
  }, function()
    package.loaded["android"] = nil
    require("android").setup()
  end)

  restore()

  local plug_menu = find_map(calls, "<Plug>(AndroidMenu)")
  assert.eq(plug_menu.rhs, "<Cmd>AndroidMenu<CR>", "plug menu mapping")

  local plug_targets = find_map(calls, "<Plug>(AndroidTargets)")
  assert.eq(plug_targets.rhs, "<Cmd>AndroidTargets<CR>", "plug targets mapping")

  local plug_tools = find_map(calls, "<Plug>(AndroidTools)")
  assert.eq(plug_tools.rhs, "<Cmd>AndroidTools<CR>", "plug tools mapping")

  local plug_actions = find_map(calls, "<Plug>(AndroidActions)")
  assert.eq(plug_actions.rhs, "<Cmd>AndroidActions<CR>", "plug actions mapping")

  local plug_build = find_map(calls, "<Plug>(AndroidBuild)")
  assert.eq(plug_build.rhs, "<Cmd>AndroidBuild<CR>", "plug build mapping")

  local menu_map = find_map(calls, "<leader>am")
  assert.eq(menu_map.rhs, "<Plug>(AndroidMenu)", "menu default mapping")
  assert.eq(menu_map.opts.remap, true, "menu remap")

  local targets_map = find_map(calls, "<leader>at")
  assert.eq(targets_map.rhs, "<Plug>(AndroidTargets)", "targets default mapping")

  local tools_map = find_map(calls, "<leader>ao")
  assert.eq(tools_map.rhs, "<Plug>(AndroidTools)", "tools default mapping")

  local actions_map = find_map(calls, "<leader>aa")
  assert.eq(actions_map.rhs, "<Plug>(AndroidActions)", "actions default mapping")

  local build_map = find_map(calls, "<leader>ab")
  assert.eq(build_map.rhs, "<Plug>(AndroidBuild)", "build default mapping")
end

function M.run()
  setup_calls_autosave_and_file_watcher()
  setup_passes_workspace_root_to_file_watcher()
  setup_skips_autosave_when_disabled()
  setup_handles_non_table_ui_config()
  setup_skips_file_watcher_when_disabled()
  setup_registers_keymaps()
  setup_skips_autosave_when_no_workspace()
end

return M
