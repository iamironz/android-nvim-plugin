local M = {}

local assert = require("tests.helpers.assert")
local stubs_helper = require("tests.helpers.stubs")

local function detects_jvm_run_tasks()
  local provider = require("android.run.providers.jvm")
  local workspace = { root = "/workspace", gradle = { root = "/workspace" } }
  local tasks = {
    ":server:run - Runs",
    ":androidApp:assembleDebug - Builds",
  }

  local list = provider.detect(workspace, {}, { tasks = tasks })
  assert.eq(#list, 1, "one jvm config")
  assert.eq(list[1].target, "jvm", "jvm target")
  assert.eq(list[1].meta.module, ":server", "module")
  assert.eq(list[1].meta.task, ":server:run", "task")
end

local function fast_mode_skips_sync_gradle_discovery()
  local run_gradle_calls = 0
  local stubs = {
    ["android.actions.build_helpers"] = {
      run_gradle = function()
        run_gradle_calls = run_gradle_calls + 1
        return { ok = true, stdout = "" }
      end,
    },
    ["android.gradle.cache"] = {
      persistent = function()
        return {
          modules = function(_, loader)
            return loader()
          end,
          tasks = function(_, _, loader)
            return loader()
          end,
          jvm_run_modules = function(_, _, loader)
            return loader()
          end,
        }
      end,
    },
    ["android.gradle.workspace"] = {
      load_modules = function()
        return { ":server" }
      end,
    },
    ["android.command.runner"] = {
      new = function()
        return {}
      end,
    },
    ["android.gradle.tasks"] = {
      parse = function()
        return {}
      end,
    },
  }

  stubs_helper.with_stubs(stubs, function()
    package.loaded["android.run.providers.jvm"] = nil
    local provider = require("android.run.providers.jvm")
    local workspace = { root = "/workspace", gradle = { root = "/workspace" } }
    local list = provider.detect(workspace, {}, { fast = true })
    assert.eq(#list, 0, "fast mode returns no jvm configs without tasks")
  end)

  assert.eq(run_gradle_calls, 0, "fast mode should not run gradle tasks")
end

function M.run()
  detects_jvm_run_tasks()
  fast_mode_skips_sync_gradle_discovery()
end

return M
