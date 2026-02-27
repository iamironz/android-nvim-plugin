local M = {}

local assert = require("tests.helpers.assert")
local stubs_helper = require("tests.helpers.stubs")

local function run_configs_value(status)
  for _, item in ipairs(status and status.items or {}) do
    if item.key == "run_configs" then
      return item.value
    end
  end
  return nil
end

local function cancel_stops_gradle_job()
  local stopped = 0
  local snapshot_opts = {}
  local stubs = {
    ["android.actions.build_helpers"] = {
      fetch_task_lines_async = function()
        return {
          ok = true,
          stop = function()
            stopped = stopped + 1
          end,
        }
      end,
    },
    ["android.gradle.workspace"] = {
      load_modules = function()
        return {}
      end,
    },
    ["android.run.providers"] = {
      defaults = function()
        return {}
      end,
    },
    ["android.run.registry"] = {
      snapshot = function(_, opts)
        snapshot_opts[#snapshot_opts + 1] = opts or {}
        return { list = {}, current = nil }
      end,
    },
  }

  stubs_helper.with_stubs(stubs, function()
    package.loaded["android.state.menu_prefetch"] = nil
    local prefetch = require("android.state.menu_prefetch")
    local session = prefetch.start({ root = "/workspace", gradle = { root = "/workspace" } })
    session.cancel()
  end)

  assert.eq(stopped, 1, "prefetch cancel stops job")
  assert.eq(snapshot_opts[1] and snapshot_opts[1].persist, false, "prefetch snapshot does not persist")
end

local function reuses_cached_task_lines_for_subsequent_starts()
  local callback = nil
  local stubs = {
    ["android.actions.build_helpers"] = {
      fetch_task_lines_async = function(_, _, on_complete)
        callback = on_complete
        return { ok = true, stop = function() end }
      end,
    },
    ["android.gradle.workspace"] = {
      load_modules = function()
        return {}
      end,
    },
    ["android.gradle.tasks"] = {
      parse = function()
        return { { name = ":app:assembleDebug", description = "" } }
      end,
    },
    ["android.gradle.variants"] = {
      parse = function()
        return { "debug" }
      end,
    },
    ["android.run.providers"] = {
      defaults = function()
        return {}
      end,
    },
    ["android.run.registry"] = {
      snapshot = function(_, opts)
        local detect_opts = opts and opts.detect_opts or {}
        if detect_opts.tasks then
          return {
            list = {
              { id = "android:app", type = "android", target = "android" },
              { id = "gradle_tasks", type = "gradle_task", target = "gradle" },
            },
            current = { id = "android:app", type = "android", target = "android" },
          }
        end
        return {
          list = {
            { id = "gradle_tasks", type = "gradle_task", target = "gradle" },
          },
          current = { id = "gradle_tasks", type = "gradle_task", target = "gradle" },
        }
      end,
    },
  }

  stubs_helper.with_stubs(stubs, function()
    package.loaded["android.state.menu_prefetch"] = nil
    local prefetch = require("android.state.menu_prefetch")
    local workspace = { root = "/workspace", gradle = { root = "/workspace" } }

    local first = prefetch.start(workspace)
    assert.eq(#(first.run_snapshot and first.run_snapshot.list or {}), 1, "first start fast snapshot")
    assert.eq(type(callback), "function", "async callback captured")

    callback({
      ok = true,
      lines = { ":app:assembleDebug - Assembles" },
    })

    local second = prefetch.start(workspace)
    assert.eq(#(second.run_snapshot and second.run_snapshot.list or {}), 2, "second start uses cached task lines")
    local status = prefetch.status("/workspace")
    local run_count = nil
    for _, item in ipairs(status and status.items or {}) do
      if item.key == "run_configs" then
        run_count = item.value
        break
      end
    end
    assert.eq(run_count, "1", "run configs count excludes gradle task entry")
  end)
end

local function keeps_loading_status_when_second_start_happens_during_active_job()
  local callback = nil
  local stubs = {
    ["android.actions.build_helpers"] = {
      fetch_task_lines_async = function(_, _, on_complete)
        callback = on_complete
        return { ok = true, stop = function() end }
      end,
    },
    ["android.gradle.workspace"] = {
      load_modules = function()
        return {}
      end,
    },
    ["android.gradle.tasks"] = {
      parse = function()
        return {}
      end,
    },
    ["android.gradle.variants"] = {
      parse = function()
        return {}
      end,
    },
    ["android.run.providers"] = {
      defaults = function()
        return {}
      end,
    },
    ["android.run.registry"] = {
      snapshot = function(_, opts)
        local detect_opts = opts and opts.detect_opts or {}
        if detect_opts.tasks then
          return {
            list = {
              { id = "android:app", type = "android", target = "android" },
            },
            current = { id = "android:app", type = "android", target = "android" },
          }
        end
        return {
          list = {
            { id = "gradle_tasks", type = "gradle_task", target = "gradle" },
          },
          current = { id = "gradle_tasks", type = "gradle_task", target = "gradle" },
        }
      end,
    },
  }

  stubs_helper.with_stubs(stubs, function()
    package.loaded["android.state.menu_prefetch"] = nil
    local prefetch = require("android.state.menu_prefetch")
    local workspace = { root = "/workspace-loading", gradle = { root = "/workspace-loading" } }

    local first = prefetch.start(workspace)
    assert.eq(run_configs_value(first.status), "loading...", "first start loading")

    local second = prefetch.start(workspace)
    assert.eq(run_configs_value(second.status), "loading...", "second start still loading")

    assert.eq(type(callback), "function", "async callback captured")
    callback({
      ok = true,
      lines = { ":app:assembleDebug - Assembles" },
    })

    local status = prefetch.status("/workspace-loading")
    assert.eq(run_configs_value(status), "1", "status updated after job completion")
  end)
end

local function gradle_error_sets_status_and_notifies()
  local callback = nil
  local notified = {}
  local original_notify = vim.notify
  vim.notify = function(msg, level)
    notified[#notified + 1] = { msg = msg, level = level }
  end

  local stubs = {
    ["android.actions.build_helpers"] = {
      fetch_task_lines_async = function(_, _, on_complete)
        callback = on_complete
        return { ok = true, stop = function() end }
      end,
    },
    ["android.gradle.workspace"] = {
      load_modules = function()
        return {}
      end,
    },
    ["android.run.providers"] = {
      defaults = function()
        return {}
      end,
    },
    ["android.run.registry"] = {
      snapshot = function()
        return { list = {}, current = nil }
      end,
    },
  }

  stubs_helper.with_stubs(stubs, function()
    package.loaded["android.state.menu_prefetch"] = nil
    local prefetch = require("android.state.menu_prefetch")
    local workspace = { root = "/workspace-err", gradle = { root = "/workspace-err" } }

    prefetch.start(workspace)
    assert.eq(type(callback), "function", "async callback captured")

    callback({
      ok = false,
      code = 1,
      stdout = "",
      stderr = "Could not determine java version\n",
      lines = {},
    })

    local status = prefetch.status("/workspace-err")
    local tasks_value = nil
    local variants_value = nil
    for _, item in ipairs(status and status.items or {}) do
      if item.key == "gradle_tasks" then
        tasks_value = item.value
      end
      if item.key == "variants" then
        variants_value = item.value
      end
    end
    assert.eq(tasks_value, "error", "gradle_tasks status is error")
    assert.eq(variants_value, "error", "variants status is error")
    assert.eq(#notified, 1, "one notification sent")
    assert.eq(
      notified[1].msg:find("Could not determine java version") ~= nil,
      true,
      "notification contains stderr detail"
    )
    assert.eq(notified[1].level, vim.log.levels.WARN, "notification level is WARN")
  end)

  vim.notify = original_notify
end

function M.run()
  cancel_stops_gradle_job()
  reuses_cached_task_lines_for_subsequent_starts()
  keeps_loading_status_when_second_start_happens_during_active_job()
  gradle_error_sets_status_and_notifies()
end

return M
