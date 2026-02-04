local M = {}

local stubs_helper = require("tests.helpers.stubs")

local function build_block()
  return {
    title = "Build",
    items = {
      { id = "build_default", label = "Build default", desc = "Build using defaults" },
    },
  }
end

local function devices_block()
  return {
    title = "Devices",
    items = {
      { id = "select_device", label = "Select device", desc = "Pick device" },
    },
  }
end

local function apps_block()
  return {
    title = "Apps",
    items = {
      { id = "adb_install", label = "ADB install", desc = "Install app" },
    },
  }
end

local function tools_block()
  return {
    title = "Tools",
    items = {
      { id = "open_tools", label = "Open tools", desc = "Tools" },
    },
  }
end

local function run_main_menu()
  local captured = nil
  local actions_called = false
  local actions_state = { opts = nil }
  local stubs = {
    ["android.ui.menu_items"] = {
      top_level_blocks = function()
        return { { title = "Run", items = { { id = "run_current" } } } }
      end,
    },
    ["android.ui.summary"] = {
      lines = function()
        return { "Summary", "Run: Android" }
      end,
    },
    ["android.ui.hub"] = {
      open = function(opts)
        captured = opts
      end,
    },
    ["android.ui.actions"] = {
      open = function(opts)
        actions_called = true
        actions_state.opts = opts
      end,
    },
  }

  stubs_helper.with_stubs(stubs, function()
    package.loaded["android.ui.menu"] = nil
    local menu = require("android.ui.menu")
    menu.show_main_menu()
  end)

  return {
    captured = captured,
    actions_called = actions_called,
    actions_state = actions_state,
  }
end

local function run_targets_menu(menu_block)
  local captured = nil
  local actions_state = { opts = nil }
  local stubs = {
    ["android.ui.menu_items"] = {
      block_by_title = function(title)
        if title ~= "Build" then
          return nil
        end
        return menu_block
      end,
    },
    ["android.ui.hub"] = {
      open = function(opts)
        captured = opts
      end,
    },
    ["android.ui.actions"] = {
      open = function(opts)
        actions_state.opts = opts
      end,
    },
  }

  stubs_helper.with_stubs(stubs, function()
    package.loaded["android.ui.menu"] = nil
    local menu = require("android.ui.menu")
    menu.show_targets_menu()
  end)

  return { captured = captured, actions_state = actions_state }
end

local function run_tools_menu(blocks)
  local captured = nil
  local actions_state = { opts = nil }
  local stubs = {
    ["android.ui.menu_items"] = {
      block_by_title = function(title)
        return blocks[title]
      end,
    },
    ["android.ui.hub"] = {
      open = function(opts)
        captured = opts
      end,
    },
    ["android.ui.actions"] = {
      open = function(opts)
        actions_state.opts = opts
      end,
    },
  }

  stubs_helper.with_stubs(stubs, function()
    package.loaded["android.ui.menu"] = nil
    local menu = require("android.ui.menu")
    menu.show_tools_menu()
  end)

  return { captured = captured, actions_state = actions_state }
end

local function run_actions_menu(blocks)
  local captured = nil
  local actions_state = { opts = nil }
  local stubs = {
    ["android.ui.menu_items"] = {
      top_level_blocks = function()
        return blocks
      end,
    },
    ["android.ui.hub"] = {
      open = function(opts)
        captured = opts
      end,
    },
    ["android.ui.actions"] = {
      open = function(opts)
        actions_state.opts = opts
      end,
    },
  }

  stubs_helper.with_stubs(stubs, function()
    package.loaded["android.ui.menu"] = nil
    local menu = require("android.ui.menu")
    menu.show_actions_menu()
  end)

  return { captured = captured, actions_state = actions_state }
end

M.build_block = build_block
M.devices_block = devices_block
M.apps_block = apps_block
M.tools_block = tools_block
M.run_main_menu = run_main_menu
M.run_targets_menu = run_targets_menu
M.run_tools_menu = run_tools_menu
M.run_actions_menu = run_actions_menu

return M
