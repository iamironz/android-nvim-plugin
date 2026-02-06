local M = {}

local assert = require("tests.helpers.assert")
local fixtures = require("tests.android.ui.menu.fixtures")
local stubs_helper = require("tests.helpers.stubs")

local function main_menu_uses_hub()
  local result = fixtures.run_main_menu()
  assert.eq(result.actions_called, false, "menu actions not used")
end

local function main_menu_sets_title()
  local result = fixtures.run_main_menu()
  assert.eq(result.captured and result.captured.title, "Android Menu", "menu title")
end

local function main_menu_sets_summary_lines()
  local result = fixtures.run_main_menu()
  assert.table_eq(
    result.captured and result.captured.summary_lines or {},
    { "Summary", "Run: Android" },
    "menu summary"
  )
end

local function main_menu_includes_run_block()
  local result = fixtures.run_main_menu()
  local blocks = result.captured and result.captured.blocks or {}
  assert.eq(blocks[1] and blocks[1].title, "Run", "menu blocks")
end

local function main_menu_on_search_opens_actions()
  local result = fixtures.run_main_menu()
  local blocks = result.captured and result.captured.blocks or {}
  result.captured.on_search("r")
  assert.table_eq(
    result.actions_state.opts,
    {
      title = "Android Menu",
      blocks = blocks,
      default_query = "r",
    },
    "menu search"
  )
end

local function main_menu_on_cancel_reopens_hub()
  local hub_calls = {}
  local run_block = { title = "Run", items = { { id = "run_current" } } }
  local stubs = {
    ["android.ui.menu_items"] = {
      top_level_blocks = function()
        return { run_block }
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

  local stubs_helper = require("tests.helpers.stubs")
  stubs_helper.with_stubs(stubs, function()
    package.loaded["android.ui.menu"] = nil
    local menu = require("android.ui.menu")
    menu.show_main_menu()
  end)

  if hub_calls[1] and hub_calls[1].on_select then
    hub_calls[1].on_select(run_block)
  end

  assert.eq(#hub_calls, 2, "hub reopened")
end

local function main_menu_passes_menu_status_to_summary()
  local received_calls = {}
  local scheduled_fn = nil
  local updated_opts = nil
  local prefetch_status = {
    items = { { label = "Gradle tasks", value = "loading..." } },
    run_snapshot = { list = {}, current = nil },
  }
  local stubs = {
    ["android.ui.menu_items"] = {
      top_level_blocks_fast = function()
        return { { title = "Run", items = { { id = "run_current" } } } }
      end,
      top_level_blocks = function()
        return { { title = "Run", items = { { id = "run_current" } } } }
      end,
    },
    ["android.ui.summary"] = {
      lines = function(opts)
        table.insert(received_calls, opts and opts.menu_status or false)
        return { "Summary" }
      end,
    },
    ["android.ui.hub"] = {
      open = function()
        return "handle"
      end,
      update = function(_, opts)
        updated_opts = opts
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
          status = prefetch_status,
          run_snapshot = { list = {}, current = nil },
          cancel = function() end,
        }
      end,
    },
  }

  stubs_helper.with_stubs(stubs, function()
    package.loaded["android.ui.menu"] = nil
    local menu = require("android.ui.menu")
    menu._schedule = function(fn)
      scheduled_fn = fn
    end
    menu.show_main_menu()
  end)

  -- initial call uses cached status (nil on cold start)
  assert.eq(received_calls[1], false, "initial menu_status is nil")

  -- run the deferred callback to simulate vim.schedule firing
  stubs_helper.with_stubs(stubs, function()
    if scheduled_fn then
      scheduled_fn()
    end
  end)

  -- deferred call passes real prefetch status to summary
  local deferred = received_calls[2]
  assert.eq(
    deferred and deferred.items and deferred.items[1] and deferred.items[1].label,
    "Gradle tasks",
    "deferred menu_status"
  )
end

function M.run()
  main_menu_uses_hub()
  main_menu_sets_title()
  main_menu_sets_summary_lines()
  main_menu_includes_run_block()
  main_menu_on_search_opens_actions()
  main_menu_on_cancel_reopens_hub()
  main_menu_passes_menu_status_to_summary()
end

return M
