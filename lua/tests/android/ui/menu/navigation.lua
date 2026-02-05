local M = {}

local assert = require("tests.helpers.assert")
local fixtures = require("tests.android.ui.menu.fixtures")
local stubs_helper = require("tests.helpers.stubs")

local function run_targets_submenu_from_main()
  local hub_calls = {}
  local run_block = { title = "Run", items = { { id = "run_current" } } }
  local build_block = fixtures.build_block()
  local stubs = {
    ["android.ui.menu_items"] = {
      top_level_blocks = function()
        return { run_block }
      end,
      block_by_title = function(title)
        if title == "Build Variants" then
          return build_block
        end
        return nil
      end,
    },
    ["android.ui.summary"] = {
      lines = function()
        return { "Summary" }
      end,
    },
    ["android.ui.hub"] = {
      open = function(opts)
        table.insert(hub_calls, opts)
      end,
    },
    ["android.ui.actions"] = { open = function() end },
    ["android.actions.context"] = {
      workspace = function()
        return { root = "/workspace", gradle = { root = "/workspace" } }
      end,
    },
    ["android.state.menu_prefetch"] = {
      status = function()
        return nil
      end,
      start = function()
        return {
          status = { items = {}, run_snapshot = { list = {}, current = nil } },
          cancel = function() end,
        }
      end,
    },
  }

  stubs_helper.with_stubs(stubs, function()
    package.loaded["android.ui.menu"] = nil
    local menu = require("android.ui.menu")
    menu.show_main_menu()
    menu.show_targets_menu({ from_action = true })
  end)

  if hub_calls[2] and hub_calls[2].on_cancel then
    hub_calls[2].on_cancel()
  end

  return hub_calls
end

local function targets_submenu_reopens_parent_hub()
  local hub_calls = run_targets_submenu_from_main()
  assert.eq(#hub_calls, 3, "targets back hub")
end

local function targets_submenu_returns_menu_title()
  local hub_calls = run_targets_submenu_from_main()
  assert.eq(hub_calls[3] and hub_calls[3].title, "Android Menu", "targets back menu")
end

local function main_menu_restores_block_index()
  local hub_calls = {}
  local blocks = {
    { title = "Quick Access", items = { { id = "open_targets_menu" } } },
    { title = "Build Variants", items = { { id = "build_default" } } },
  }
  local stubs = {
    ["android.ui.menu_items"] = {
      top_level_blocks = function()
        return blocks
      end,
    },
    ["android.ui.summary"] = {
      lines = function()
        return { "Summary" }
      end,
    },
    ["android.ui.hub"] = {
      open = function(opts)
        table.insert(hub_calls, opts)
      end,
    },
    ["android.ui.actions"] = {
      open = function(opts)
        if opts.on_cancel then
          opts.on_cancel()
        end
      end,
    },
    ["android.actions.context"] = {
      workspace = function()
        return { root = "/workspace", gradle = { root = "/workspace" } }
      end,
    },
    ["android.state.menu_prefetch"] = {
      status = function()
        return nil
      end,
      start = function()
        return {
          status = { items = {}, run_snapshot = { list = {}, current = nil } },
          cancel = function() end,
        }
      end,
    },
  }

  stubs_helper.with_stubs(stubs, function()
    package.loaded["android.ui.menu"] = nil
    local menu = require("android.ui.menu")
    menu.show_main_menu()
  end)

  if hub_calls[1] and hub_calls[1].on_select then
    hub_calls[1].on_select(blocks[2])
  end

  assert.eq(hub_calls[2] and hub_calls[2].initial_index, 2, "hub index")
end

local function run_tools_submenu_from_main()
  local hub_calls = {}
  local run_block = { title = "Run", items = { { id = "run_current" } } }
  local tools_block = fixtures.tools_block()
  local stubs = {
    ["android.ui.menu_items"] = {
      top_level_blocks = function()
        return { run_block }
      end,
      block_by_title = function(title)
        if title == "Tools" then
          return tools_block
        end
        return nil
      end,
    },
    ["android.ui.summary"] = {
      lines = function()
        return { "Summary" }
      end,
    },
    ["android.ui.hub"] = {
      open = function(opts)
        table.insert(hub_calls, opts)
      end,
    },
    ["android.ui.actions"] = { open = function() end },
    ["android.actions.context"] = {
      workspace = function()
        return { root = "/workspace", gradle = { root = "/workspace" } }
      end,
    },
    ["android.state.menu_prefetch"] = {
      status = function()
        return nil
      end,
      start = function()
        return {
          status = { items = {}, run_snapshot = { list = {}, current = nil } },
          cancel = function() end,
        }
      end,
    },
  }

  stubs_helper.with_stubs(stubs, function()
    package.loaded["android.ui.menu"] = nil
    local menu = require("android.ui.menu")
    menu.show_main_menu()
    menu.show_tools_menu({ from_action = true })
  end)

  if hub_calls[2] and hub_calls[2].on_cancel then
    hub_calls[2].on_cancel()
  end

  return hub_calls
end

local function tools_submenu_reopens_parent_hub()
  local hub_calls = run_tools_submenu_from_main()
  assert.eq(#hub_calls, 3, "tools back hub")
end

local function tools_submenu_returns_menu_title()
  local hub_calls = run_tools_submenu_from_main()
  assert.eq(hub_calls[3] and hub_calls[3].title, "Android Menu", "tools back menu")
end

function M.run()
  main_menu_restores_block_index()
  targets_submenu_reopens_parent_hub()
  targets_submenu_returns_menu_title()
  tools_submenu_reopens_parent_hub()
  tools_submenu_returns_menu_title()
end

return M
