local M = {}

local assert = require("tests.helpers.assert")
local stubs_helper = require("tests.helpers.stubs")

local function execute_default_runs_handler()
  local called = 0
  local stubs = {
    ["android.actions.context"] = {
      workspace = function()
        return { root = "/workspace" }
      end,
      load_state = function()
        return {}
      end,
    },
    ["android.run.registry"] = {
      resolve = function()
        return {
          id = "android:app",
          target = "android",
          type = "android",
          meta = { module = ":app" },
        }
      end,
    },
    ["android.run.executor_handlers"] = {
      run = function()
        called = called + 1
      end,
    },
  }

  stubs_helper.with_stubs(stubs, function()
    package.loaded["android.run.executor"] = nil
    local executor = require("android.run.executor")
    executor.execute_default()
  end)

  assert.eq(called, 1, "handler called")
end

local function execute_selects_config_and_runs()
  local selected = nil
  local called = 0
  local stubs = {
    ["android.actions.context"] = {
      workspace = function()
        return { root = "/workspace" }
      end,
      load_state = function()
        return {}
      end,
    },
    ["android.run.registry"] = {
      list = function()
        return { { id = "ios", target = "ios", type = "ios" } }
      end,
      select = function(_, id)
        selected = id
        return id
      end,
    },
    ["android.run.executor_handlers"] = {
      run = function()
        called = called + 1
      end,
    },
  }

  stubs_helper.with_stubs(stubs, function()
    package.loaded["android.run.executor"] = nil
    local executor = require("android.run.executor")
    executor.execute("ios")
  end)

  assert.eq(selected, "ios", "select id")
  assert.eq(called, 1, "run called")
end

local function execute_run_all_runs_targets()
  local calls = {}
  local stubs = {
    ["android.actions.context"] = {
      workspace = function()
        return { root = "/workspace" }
      end,
      load_state = function()
        return {}
      end,
    },
    ["android.run.registry"] = {
      resolve = function()
        return { id = "run_all", target = "multi", targets = { "jvm:server", "android:app" } }
      end,
      list = function()
        return {
          { id = "jvm:server", target = "jvm", type = "jvm", meta = { task = ":server:run" } },
          { id = "android:app", target = "android", type = "android", meta = { module = ":app" } },
          { id = "run_all", target = "multi", type = "multi", targets = { "jvm:server", "android:app" } },
        }
      end,
    },
    ["android.run.executor_handlers"] = {
      run = function(_, config)
        table.insert(calls, config.id)
        return { stop = function() end }
      end,
    },
  }

  stubs_helper.with_stubs(stubs, function()
    package.loaded["android.run.executor"] = nil
    local executor = require("android.run.executor")
    local handle = executor.execute_default()
    assert.is_true(handle and handle.stop ~= nil, "handle returned")
  end)

  assert.table_eq(calls, { "jvm:server", "android:app" }, "run all order")
end

function M.run()
  execute_default_runs_handler()
  execute_selects_config_and_runs()
  execute_run_all_runs_targets()
end

return M
