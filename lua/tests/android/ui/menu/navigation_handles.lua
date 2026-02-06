local M = {}

local assert = require("tests.helpers.assert")
local fixtures = require("tests.android.ui.menu.fixtures")
local stubs_helper = require("tests.helpers.stubs")

local function back_navigation_rebinds_parent_hub_handle()
  local hub_calls = {}
  local update_calls = {}
  local prefetch_on_update = nil
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
        local handle = { id = #hub_calls + 1 }
        table.insert(hub_calls, { opts = opts, handle = handle })
        return handle
      end,
      update = function(handle, opts)
        table.insert(update_calls, { handle = handle, opts = opts })
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
      start = function(_, opts)
        prefetch_on_update = opts and opts.on_update
        return {
          status = { items = {}, run_snapshot = { list = {}, current = nil } },
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
      fn()
    end
    menu.show_main_menu()
    menu.show_targets_menu({ from_action = true })
  end)

  local child_hub = hub_calls[2] and hub_calls[2].opts
  assert.eq(type(child_hub and child_hub.on_cancel), "function", "child back handler")
  child_hub.on_cancel()

  assert.eq(#hub_calls, 3, "parent hub reopened")
  local reopened_parent_handle = hub_calls[3] and hub_calls[3].handle
  local parent_opts = hub_calls[1] and hub_calls[1].opts
  assert.eq(
    parent_opts and parent_opts._hub_handle,
    reopened_parent_handle,
    "parent handle rebound"
  )

  assert.eq(type(prefetch_on_update), "function", "prefetch update callback")
  prefetch_on_update({ items = { { label = "Gradle tasks", value = "ready" } } })

  local last_update = update_calls[#update_calls]
  assert.eq(
    last_update and last_update.handle,
    reopened_parent_handle,
    "summary update targets reopened parent"
  )
end

local function action_fallback_cancel_clears_prefetch()
  local hub_calls = {}
  local canceled_prefetch = 0
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
        table.insert(hub_calls, { opts = opts })
        return { id = #hub_calls }
      end,
      update = function() end,
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
          run_snapshot = { list = {}, current = nil },
          cancel = function()
            canceled_prefetch = canceled_prefetch + 1
          end,
        }
      end,
    },
  }

  stubs_helper.with_stubs(stubs, function()
    package.loaded["android.ui.menu"] = nil
    local menu = require("android.ui.menu")
    menu._schedule = function(fn)
      fn()
    end
    menu.show_main_menu()
    menu.show_targets_menu({
      from_action = true,
      on_cancel = function() end,
    })
  end)

  local child_hub = hub_calls[2] and hub_calls[2].opts
  assert.eq(type(child_hub and child_hub.on_cancel), "function", "child fallback handler")
  child_hub.on_cancel()

  assert.eq(canceled_prefetch, 1, "prefetch canceled on action fallback")
end

function M.run()
  back_navigation_rebinds_parent_hub_handle()
  action_fallback_cancel_clears_prefetch()
end

return M
