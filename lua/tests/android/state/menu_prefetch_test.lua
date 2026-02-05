local M = {}

local assert = require("tests.helpers.assert")
local stubs_helper = require("tests.helpers.stubs")

local function cancel_stops_gradle_job()
  local stopped = 0
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
      snapshot = function()
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
end

function M.run()
  cancel_stops_gradle_job()
end

return M
