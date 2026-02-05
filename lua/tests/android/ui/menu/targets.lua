local M = {}

local assert = require("tests.helpers.assert")
local fixtures = require("tests.android.ui.menu.fixtures")

local function targets_menu_on_cancel_reopens_hub()
  local hub_calls = {}
  local block = fixtures.build_block()
  local stubs = {
    ["android.ui.menu_items"] = {
      block_by_title = function(title)
        if title ~= "Build Variants" then
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
    ["android.ui.summary"] = {
      lines = function()
        return { "Summary" }
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

  local stubs_helper = require("tests.helpers.stubs")
  stubs_helper.with_stubs(stubs, function()
    package.loaded["android.ui.menu"] = nil
    local menu = require("android.ui.menu")
    menu.show_targets_menu()
  end)

  if hub_calls[1] and hub_calls[1].on_select then
    hub_calls[1].on_select(block)
  end

  assert.eq(#hub_calls, 2, "targets hub reopened")
end

local function targets_menu_sets_title()
  local result = fixtures.run_targets_menu(fixtures.build_block())
  assert.eq(result.captured and result.captured.title, "Android Build Variants", "targets title")
end

local function targets_menu_sets_build_block()
  local result = fixtures.run_targets_menu(fixtures.build_block())
  local blocks = result.captured and result.captured.blocks or {}
  assert.eq(blocks[1] and blocks[1].title, "Build Variants", "targets block")
end

local function targets_menu_has_summary()
  local result = fixtures.run_targets_menu(fixtures.build_block())
  assert.table_eq(
    result.captured and result.captured.summary_lines or {},
    { "Summary" },
    "targets summary"
  )
end

local function targets_menu_missing_build_does_not_open()
  local result = fixtures.run_targets_menu(nil)
  assert.eq(result.captured, nil, "targets missing build")
end

local function targets_menu_on_select_actions_opts()
  local block = fixtures.build_block()
  local result = fixtures.run_targets_menu(block)
  result.captured.on_select(block)
  return result.actions_state.opts or {}
end

local function targets_menu_on_select_sets_title()
  local actions_opts = targets_menu_on_select_actions_opts()
  assert.eq(actions_opts.title, "Android Build Variants", "targets select title")
end

local function targets_menu_on_select_sets_block()
  local actions_opts = targets_menu_on_select_actions_opts()
  local blocks = actions_opts.blocks or {}
  assert.eq(blocks[1] and blocks[1].title, "Build Variants", "targets select block")
end

local function targets_menu_on_search_opens_actions()
  local block = fixtures.build_block()
  local result = fixtures.run_targets_menu(block)
  result.captured.on_search("b")
  assert.table_eq(
    result.actions_state.opts,
    {
      title = "Android Build Variants",
      blocks = { block },
      default_query = "b",
    },
    "targets search"
  )
end

function M.run()
  targets_menu_sets_title()
  targets_menu_sets_build_block()
  targets_menu_has_summary()
  targets_menu_missing_build_does_not_open()
  targets_menu_on_select_sets_title()
  targets_menu_on_select_sets_block()
  targets_menu_on_search_opens_actions()
  targets_menu_on_cancel_reopens_hub()
end

return M
