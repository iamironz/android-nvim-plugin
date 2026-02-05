local M = {}

local assert = require("tests.helpers.assert")
local fixtures = require("tests.android.ui.menu.fixtures")

local function tools_menu_sets_title_with_fallback()
  local result = fixtures.run_tools_menu({
    ["Device Manager"] = fixtures.devices_block(),
    ADB = fixtures.apps_block(),
  })
  assert.eq(result.captured and result.captured.title, "Android Device Manager & ADB", "tools title")
end

local function tools_menu_includes_devices_block()
  local result = fixtures.run_tools_menu({
    ["Device Manager"] = fixtures.devices_block(),
    ADB = fixtures.apps_block(),
  })
  local blocks = result.captured and result.captured.blocks or {}
  assert.eq(blocks[1] and blocks[1].title, "Device Manager", "tools devices")
end

local function tools_menu_includes_apps_block()
  local result = fixtures.run_tools_menu({
    ["Device Manager"] = fixtures.devices_block(),
    ADB = fixtures.apps_block(),
  })
  local blocks = result.captured and result.captured.blocks or {}
  assert.eq(blocks[2] and blocks[2].title, "ADB", "tools apps")
end

local function tools_menu_sets_title_with_tools_block()
  local result = fixtures.run_tools_menu({ Tools = fixtures.tools_block() })
  assert.eq(result.captured and result.captured.title, "Android Tools", "tools title")
end

local function tools_menu_includes_tools_block()
  local result = fixtures.run_tools_menu({ Tools = fixtures.tools_block() })
  local blocks = result.captured and result.captured.blocks or {}
  assert.eq(blocks[1] and blocks[1].title, "Tools", "tools block")
end

local function tools_menu_on_select_actions_opts()
  local block = fixtures.devices_block()
  local result = fixtures.run_tools_menu({ ["Device Manager"] = block })
  result.captured.on_select(block)
  return result.actions_state.opts or {}
end

local function tools_menu_on_select_sets_title()
  local actions_opts = tools_menu_on_select_actions_opts()
  assert.eq(actions_opts.title, "Android Device Manager", "tools select title")
end

local function tools_menu_on_select_sets_block()
  local actions_opts = tools_menu_on_select_actions_opts()
  local blocks = actions_opts.blocks or {}
  assert.eq(blocks[1] and blocks[1].title, "Device Manager", "tools select block")
end

local function tools_menu_on_search_opens_actions()
  local result = fixtures.run_tools_menu({
    ["Device Manager"] = fixtures.devices_block(),
    ADB = fixtures.apps_block(),
  })
  local blocks = result.captured and result.captured.blocks or {}
  result.captured.on_search("d")
  assert.table_eq(
    result.actions_state.opts,
    {
      title = "Android Device Manager & ADB",
      blocks = blocks,
      default_query = "d",
    },
    "tools search"
  )
end

local function tools_menu_on_cancel_reopens_hub()
  local hub_calls = {}
  local block = fixtures.devices_block()
  local stubs = {
    ["android.ui.menu_items"] = {
      block_by_title = function(title)
        if title ~= "Device Manager" then
          return nil
        end
        return block
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
  }

  local stubs_helper = require("tests.helpers.stubs")
  stubs_helper.with_stubs(stubs, function()
    package.loaded["android.ui.menu"] = nil
    local menu = require("android.ui.menu")
    menu.show_tools_menu()
  end)

  if hub_calls[1] and hub_calls[1].on_select then
    hub_calls[1].on_select(block)
  end

  assert.eq(#hub_calls, 2, "tools hub reopened")
end

function M.run()
  tools_menu_sets_title_with_fallback()
  tools_menu_includes_devices_block()
  tools_menu_includes_apps_block()
  tools_menu_sets_title_with_tools_block()
  tools_menu_includes_tools_block()
  tools_menu_on_select_sets_title()
  tools_menu_on_select_sets_block()
  tools_menu_on_search_opens_actions()
  tools_menu_on_cancel_reopens_hub()
end

return M
