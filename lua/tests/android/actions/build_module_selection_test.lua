local M = {}

local assert = require("tests.helpers.assert")
local stubs_helper = require("tests.helpers.stubs")

local function with_vim_notify_stubs(fn)
  local original_notify = vim.notify
  vim.notify = function() end

  local ok, err = pcall(fn)

  vim.notify = original_notify

  if not ok then
    error(err)
  end
end

local function select_module_syncs_matching_android_run_config()
  local state = {
    build = { module = ":app", variant = "debug" },
    run = { config_id = "android:app" },
  }
  local detect_opts = nil

  local stubs = {
    ["android.actions.context"] = {
      workspace = function()
        return { root = "/workspace", modules = { ":app", ":mesh_service_example" } }
      end,
      load_state = function()
        return state
      end,
      save_state = function(_, next_state)
        state = next_state
        return true
      end,
    },
    ["android.ui.picker"] = {
      select_from_list = function(opts)
        opts.on_select(":mesh_service_example")
      end,
    },
    ["android.state.menu_prefetch"] = {
      cached_task_lines = function()
        return { ":mesh_service_example:assembleDebug - Assembles" }
      end,
      cached_snapshot = function()
        return {
          android = {
            modules = { ":app", ":mesh_service_example" },
          },
        }
      end,
      cached_variant_fetch_opts = function(_, module)
        return { module = module }
      end,
    },
    ["android.run.registry"] = {
      snapshot = function(_, opts)
        detect_opts = opts and opts.detect_opts or nil
        return {
          list = {
            { id = "android:app", type = "android", target = "android", meta = { module = ":app" } },
            {
              id = "android:mesh_service_example",
              type = "android",
              target = "android",
              meta = { module = ":mesh_service_example" },
            },
          },
          current = { id = "android:app", type = "android", target = "android" },
        }
      end,
    },
  }

  with_vim_notify_stubs(function()
    stubs_helper.with_stubs(stubs, function()
      package.loaded["android.actions.build"] = nil
      package.loaded["android.actions.build_selection"] = nil
      package.loaded["android.actions.build_run_sync"] = nil
      local build = require("android.actions.build")
      build.select_module()
    end)
  end)

  assert.eq(state.build.module, ":mesh_service_example", "build module updated")
  assert.eq(state.run.config_id, "android:mesh_service_example", "android run config synced")
  assert.eq(detect_opts.tasks[1], ":mesh_service_example:assembleDebug - Assembles", "cached tasks reused")
  assert.eq(detect_opts.snapshot.android.modules[2], ":mesh_service_example", "cached snapshot reused")
end

local function select_module_keeps_explicit_non_android_run_config()
  local state = {
    build = { module = ":app", variant = "debug" },
    run = { config_id = "ios" },
  }

  local stubs = {
    ["android.actions.context"] = {
      workspace = function()
        return { root = "/workspace", modules = { ":app", ":mesh_service_example" } }
      end,
      load_state = function()
        return state
      end,
      save_state = function(_, next_state)
        state = next_state
        return true
      end,
    },
    ["android.ui.picker"] = {
      select_from_list = function(opts)
        opts.on_select(":mesh_service_example")
      end,
    },
    ["android.run.registry"] = {
      snapshot = function()
        return {
          list = {
            { id = "ios", type = "ios", target = "ios" },
            {
              id = "android:mesh_service_example",
              type = "android",
              target = "android",
              meta = { module = ":mesh_service_example" },
            },
          },
          current = { id = "ios", type = "ios", target = "ios" },
        }
      end,
    },
  }

  with_vim_notify_stubs(function()
    stubs_helper.with_stubs(stubs, function()
      package.loaded["android.actions.build"] = nil
      package.loaded["android.actions.build_selection"] = nil
      package.loaded["android.actions.build_run_sync"] = nil
      local build = require("android.actions.build")
      build.select_module()
    end)
  end)

  assert.eq(state.build.module, ":mesh_service_example", "build module updated")
  assert.eq(state.run.config_id, "ios", "non-android run config preserved")
end

local function select_module_falls_back_when_fast_run_snapshot_misses_module()
  local state = {
    build = { module = ":app", variant = "debug" },
    run = { config_id = "android:app" },
  }
  local snapshot_calls = {}

  local stubs = {
    ["android.actions.context"] = {
      workspace = function()
        return { root = "/workspace", modules = { ":app", ":mesh_service_example" } }
      end,
      load_state = function()
        return state
      end,
      save_state = function(_, next_state)
        state = next_state
        return true
      end,
    },
    ["android.ui.picker"] = {
      select_from_list = function(opts)
        opts.on_select(":mesh_service_example")
      end,
    },
    ["android.state.menu_prefetch"] = {
      cached_variant_fetch_opts = function(_, module)
        return { module = module }
      end,
    },
    ["android.run.registry"] = {
      snapshot = function(_, opts)
        snapshot_calls[#snapshot_calls + 1] = opts and opts.detect_opts or nil
        if opts and opts.detect_opts and opts.detect_opts.fast then
          return {
            list = {
              { id = "android:app", type = "android", target = "android", meta = { module = ":app" } },
            },
            current = { id = "android:app", type = "android", target = "android" },
          }
        end
        return {
          list = {
            { id = "android:app", type = "android", target = "android", meta = { module = ":app" } },
            {
              id = "android:mesh_service_example",
              type = "android",
              target = "android",
              meta = { module = ":mesh_service_example" },
            },
          },
          current = { id = "android:app", type = "android", target = "android" },
        }
      end,
    },
  }

  with_vim_notify_stubs(function()
    stubs_helper.with_stubs(stubs, function()
      package.loaded["android.actions.build"] = nil
      package.loaded["android.actions.build_selection"] = nil
      package.loaded["android.actions.build_run_sync"] = nil
      local build = require("android.actions.build")
      build.select_module()
    end)
  end)

  assert.eq(state.run.config_id, "android:mesh_service_example", "fallback run config synced")
  assert.eq(snapshot_calls[1].fast, true, "fast lookup attempted first")
  assert.eq(snapshot_calls[2].use_gradle_tasks, true, "full lookup retries with gradle tasks")
end

function M.run()
  select_module_syncs_matching_android_run_config()
  select_module_keeps_explicit_non_android_run_config()
  select_module_falls_back_when_fast_run_snapshot_misses_module()
end

return M
