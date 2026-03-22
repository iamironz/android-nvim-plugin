local M = {}

local assert = require("tests.helpers.assert")
local stubs_helper = require("tests.helpers.stubs")

local function retries_with_gradle_tasks_when_cached_prefetch_misses_module()
  local snapshot_calls = {}

  stubs_helper.with_stubs({
    ["android.state.menu_prefetch"] = {
      cached_task_lines = function()
        return { ":app:assembleDebug - Assembles a debug build" }
      end,
      cached_snapshot = function()
        return {
          android = {
            modules = { ":app" },
            by_module = {
              [":app"] = { variants = { "debug" } },
            },
          },
        }
      end,
    },
    ["android.run.registry"] = {
      snapshot = function(_, opts)
        snapshot_calls[#snapshot_calls + 1] = opts and opts.detect_opts or nil
        if opts and opts.detect_opts and opts.detect_opts.use_gradle_tasks then
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
        end
        return {
          list = {
            { id = "android:app", type = "android", target = "android", meta = { module = ":app" } },
          },
          current = { id = "android:app", type = "android", target = "android" },
        }
      end,
    },
  }, function()
    package.loaded["android.actions.build_run_sync"] = nil
    local build_run_sync = require("android.actions.build_run_sync")
    local next_state = build_run_sync.apply(
      { root = "/workspace" },
      { run = { config_id = "android:app" } },
      ":mesh_service_example"
    )

    assert.eq(next_state.run.config_id, "android:mesh_service_example", "fresh gradle lookup finds module")
    assert.eq(snapshot_calls[1].tasks[1], ":app:assembleDebug - Assembles a debug build", "cached tasks used first")
    assert.eq(snapshot_calls[2].use_gradle_tasks, true, "gradle tasks retry used when cache misses")
  end)
end

function M.run()
  retries_with_gradle_tasks_when_cached_prefetch_misses_module()
end

return M
