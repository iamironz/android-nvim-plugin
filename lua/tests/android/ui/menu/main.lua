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

local function main_menu_keeps_loading_configs_while_prefetch_running()
  local scheduled_fn = nil
  local captured_opts = nil
  local loading_status = {
    items = {
      { key = "run_configs", label = "Run configs", value = "loading..." },
    },
  }
  local stubs = {
    ["android.ui.menu_items"] = {
      top_level_blocks_fast = function()
        return {
          {
            title = "Run Configurations",
            items = {
              { id = "_loading", label = "Loading configurations..." },
            },
          },
        }
      end,
      top_level_blocks = function()
        return {
          {
            title = "Run Configurations",
            items = {},
          },
        }
      end,
    },
    ["android.ui.summary"] = {
      lines = function()
        return { "Summary" }
      end,
    },
    ["android.ui.hub"] = {
      open = function(opts)
        captured_opts = opts
        return "handle"
      end,
      update = function(_, opts)
        captured_opts = opts
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
          status = loading_status,
          run_snapshot = {
            list = {
              {
                id = "gradle_tasks",
                type = "gradle_task",
                target = "gradle",
                label = "Gradle tasks",
              },
            },
            current = nil,
          },
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

  stubs_helper.with_stubs(stubs, function()
    if scheduled_fn then
      scheduled_fn()
    end
  end)

  local configs = captured_opts and captured_opts.blocks and captured_opts.blocks[1] or nil
  assert.eq(configs and configs.items and configs.items[1] and configs.items[1].id, "_loading", "loading retained")
end

local function main_menu_refreshes_configs_when_prefetch_ready()
  local scheduled_fn = nil
  local prefetch_on_update = nil
  local captured_opts = nil
  local loading_status = {
    items = {
      { key = "run_configs", label = "Run configs", value = "loading..." },
    },
  }
  local ready_status = {
    items = {
      { key = "run_configs", label = "Run configs", value = "2" },
    },
  }
  local stubs = {
    ["android.ui.menu_items"] = {
      top_level_blocks_fast = function()
        return {
          {
            title = "Run Configurations",
            items = {
              { id = "_loading", label = "Loading configurations..." },
            },
          },
        }
      end,
      top_level_blocks = function(_, opts)
        local list = opts and opts.run_snapshot and opts.run_snapshot.list or {}
        local has_android = false
        for _, entry in ipairs(list) do
          if entry.type == "android" then
            has_android = true
            break
          end
        end
        if has_android then
          return {
            {
              title = "Run Configurations",
              items = {
                { id = "run_select:android:app", label = "Android :app" },
              },
            },
          }
        end
        return {
          {
            title = "Run Configurations",
            items = {},
          },
        }
      end,
    },
    ["android.ui.summary"] = {
      lines = function()
        return { "Summary" }
      end,
    },
    ["android.ui.hub"] = {
      open = function(opts)
        captured_opts = opts
        return "handle"
      end,
      update = function(_, opts)
        captured_opts = opts
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
          status = loading_status,
          run_snapshot = {
            list = {
              {
                id = "gradle_tasks",
                type = "gradle_task",
                target = "gradle",
                label = "Gradle tasks",
              },
            },
            current = nil,
          },
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

  stubs_helper.with_stubs(stubs, function()
    if scheduled_fn then
      scheduled_fn()
    end
    if prefetch_on_update then
      prefetch_on_update(ready_status, {
        run_snapshot = {
          list = {
            {
              id = "android:app",
              type = "android",
              target = "android",
              label = "Android :app",
            },
          },
          current = nil,
        },
      })
    end
  end)

  local configs = captured_opts and captured_opts.blocks and captured_opts.blocks[1] or nil
  assert.eq(
    configs and configs.items and configs.items[1] and configs.items[1].id,
    "run_select:android:app",
    "configs refreshed"
  )
end

local function main_menu_prefers_cached_snapshot_over_stale_session_snapshot()
  local scheduled_fn = nil
  local captured_opts = nil
  local stubs = {
    ["android.ui.menu_items"] = {
      top_level_blocks_fast = function()
        return {
          {
            title = "Run Configurations",
            items = {
              { id = "_loading", label = "Loading configurations..." },
            },
          },
        }
      end,
      top_level_blocks = function(_, opts)
        local run_snapshot = opts and opts.run_snapshot or {}
        local items = {}
        for _, config in ipairs(run_snapshot.list or {}) do
          if config.type ~= "gradle_task" then
            items[#items + 1] = {
              id = "run_select:" .. config.id,
              label = config.label or config.id,
            }
          end
        end
        return {
          {
            title = "Run Configurations",
            items = items,
          },
        }
      end,
    },
    ["android.ui.summary"] = {
      lines = function()
        return { "Summary" }
      end,
    },
    ["android.ui.hub"] = {
      open = function(opts)
        captured_opts = opts
        return "handle"
      end,
      update = function(_, opts)
        captured_opts = opts
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
          status = {
            items = {
              { key = "run_configs", label = "Run configs", value = "5" },
            },
          },
          run_snapshot = {
            list = {
              {
                id = "gradle_tasks",
                type = "gradle_task",
                target = "gradle",
                label = "Gradle tasks",
              },
            },
            current = nil,
          },
          cancel = function() end,
        }
      end,
      cached_run_snapshot = function()
        return {
          list = {
            {
              id = "android:app",
              type = "android",
              target = "android",
              label = "Android :app",
            },
            {
              id = "gradle_tasks",
              type = "gradle_task",
              target = "gradle",
              label = "Gradle tasks",
            },
          },
          current = nil,
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

  stubs_helper.with_stubs(stubs, function()
    if scheduled_fn then
      scheduled_fn()
    end
  end)

  local configs = captured_opts and captured_opts.blocks and captured_opts.blocks[1] or nil
  assert.eq(
    configs and configs.items and configs.items[1] and configs.items[1].id,
    "run_select:android:app",
    "cached snapshot takes precedence"
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
  main_menu_keeps_loading_configs_while_prefetch_running()
  main_menu_refreshes_configs_when_prefetch_ready()
  main_menu_prefers_cached_snapshot_over_stale_session_snapshot()
end

return M
