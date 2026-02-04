local M = {}

local assert = require("tests.helpers.assert")
local fixtures = require("tests.android.ui.menu.fixtures")

local function actions_menu_sets_title()
  local result = fixtures.run_actions_menu({ fixtures.build_block() })
  assert.eq(result.captured and result.captured.title, "Android Actions", "actions title")
end

local function actions_menu_includes_blocks()
  local result = fixtures.run_actions_menu({ fixtures.build_block() })
  local blocks = result.captured and result.captured.blocks or {}
  assert.eq(blocks[1] and blocks[1].title, "Build", "actions blocks")
end

local function actions_menu_has_no_summary()
  local result = fixtures.run_actions_menu({ fixtures.build_block() })
  assert.eq(result.captured and result.captured.summary_lines, nil, "actions summary")
end

local function actions_menu_on_select_actions_opts()
  local block = fixtures.build_block()
  local result = fixtures.run_actions_menu({ block })
  result.captured.on_select(block)
  return result.actions_state.opts or {}
end

local function actions_menu_on_select_sets_title()
  local actions_opts = actions_menu_on_select_actions_opts()
  assert.eq(actions_opts.title, "Android Build", "actions select title")
end

local function actions_menu_on_select_sets_block()
  local actions_opts = actions_menu_on_select_actions_opts()
  local blocks = actions_opts.blocks or {}
  assert.eq(blocks[1] and blocks[1].title, "Build", "actions select block")
end

local function actions_menu_on_search_opens_actions()
  local result = fixtures.run_actions_menu({ fixtures.build_block() })
  local blocks = result.captured and result.captured.blocks or {}
  result.captured.on_search("b")
  assert.table_eq(
    result.actions_state.opts,
    {
      title = "Android Actions",
      blocks = blocks,
      default_query = "b",
    },
    "actions search"
  )
end

local function actions_menu_on_cancel_reopens_hub()
  local hub_calls = {}
  local block = fixtures.build_block()
  local stubs = {
    ["android.ui.menu_items"] = {
      top_level_blocks = function()
        return { block }
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
    menu.show_actions_menu()
  end)

  if hub_calls[1] and hub_calls[1].on_select then
    hub_calls[1].on_select(block)
  end

  assert.eq(#hub_calls, 2, "actions hub reopened")
end

function M.run()
  actions_menu_sets_title()
  actions_menu_includes_blocks()
  actions_menu_has_no_summary()
  actions_menu_on_select_sets_title()
  actions_menu_on_select_sets_block()
  actions_menu_on_search_opens_actions()
  actions_menu_on_cancel_reopens_hub()
end

return M
