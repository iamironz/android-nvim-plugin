local M = {}

local assert = require("tests.helpers.assert")
local config = require("android.config")

local function reset_config()
  config.reset()
end

local function build_workspace()
  return { root = "/workspace" }
end

local function stub_providers()
  return {
    {
      id = "android",
      priority = 10,
      detect = function()
        return {
          {
            id = "android:app",
            label = "Android",
            target = "android",
            meta = { module = ":app" },
          },
        }
      end,
    },
    {
      id = "ios",
      priority = 20,
      detect = function()
        return { { id = "ios", label = "iOS", target = "ios" } }
      end,
    },
    {
      id = "jvm",
      priority = 30,
      detect = function()
        return {
          {
            id = "jvm:server",
            label = "JVM",
            target = "jvm",
            meta = { module = ":server" },
          },
        }
      end,
    },
  }
end

local function stub_preference_providers()
  return {
    {
      id = "android",
      priority = 10,
      detect = function()
        return {
          {
            id = "android:app",
            label = "Android App",
            target = "android",
            meta = { module = ":app" },
          },
          {
            id = "android:custom",
            label = "Android Custom",
            target = "android",
            meta = { module = ":custom" },
          },
        }
      end,
    },
    {
      id = "ios",
      priority = 20,
      detect = function()
        return { { id = "ios", label = "iOS", target = "ios" } }
      end,
    },
    {
      id = "jvm",
      priority = 30,
      detect = function()
        return {
          {
            id = "jvm:server",
            label = "JVM Server",
            target = "jvm",
            meta = { module = ":server" },
          },
          {
            id = "jvm:backend",
            label = "JVM Backend",
            target = "jvm",
            meta = { module = ":backend" },
          },
        }
      end,
    },
  }
end

local function list_with_providers(provider_list)
  local configs = require("android.run.configs")
  return configs.from_workspace(build_workspace(), { providers = provider_list or stub_providers() })
end

local function lists_run_all_config()
  reset_config()
  local list = list_with_providers()
  assert.eq(#list, 4, "config count")
  assert.eq(list[4].id, "run_all", "run all last")
end

local function run_all_targets_ordered()
  reset_config()
  local configs = require("android.run.configs")
  local list = list_with_providers()
  local run_all = configs.find(list, "run_all")
  assert.table_eq(run_all.targets, { "jvm:server", "android:app", "ios" }, "run all")
end

local function run_all_prefers_configured_modules()
  reset_config()
  config.setup({
    run = {
      run_all = {
        target_modules = {
          jvm = { ":backend" },
          android = { ":custom" },
        },
      },
    },
  })
  local configs = require("android.run.configs")
  local list = list_with_providers(stub_preference_providers())
  local run_all = configs.find(list, "run_all")
  assert.table_eq(run_all.targets, { "jvm:backend", "android:custom", "ios" }, "run all")
end

local function run_all_respects_custom_order()
  reset_config()
  config.setup({
    run = {
      run_all = {
        order = { "ios", "android" },
      },
    },
  })
  local configs = require("android.run.configs")
  local list = list_with_providers()
  local run_all = configs.find(list, "run_all")
  assert.table_eq(run_all.targets, { "ios", "android:app" }, "run all order")
end

local function prefers_android_default()
  reset_config()
  local configs = require("android.run.configs")
  local list = list_with_providers()
  local chosen = configs.default(list)
  assert.eq(chosen.id, "android:app", "android default")
end

local function returns_empty_list_when_workspace_missing()
  reset_config()
  local configs = require("android.run.configs")
  local list = configs.from_workspace(nil)
  assert.eq(#list, 0, "empty list")
end

local function returns_nil_when_find_id_nil()
  reset_config()
  local configs = require("android.run.configs")
  local list = { { id = "android" } }
  assert.eq(configs.find(list, nil), nil, "nil id")
end

local function returns_nil_when_find_id_missing()
  reset_config()
  local configs = require("android.run.configs")
  local list = { { id = "android" } }
  assert.eq(configs.find(list, "ios"), nil, "missing id")
end

function M.run()
  lists_run_all_config()
  run_all_targets_ordered()
  run_all_prefers_configured_modules()
  run_all_respects_custom_order()
  prefers_android_default()
  returns_empty_list_when_workspace_missing()
  returns_nil_when_find_id_nil()
  returns_nil_when_find_id_missing()
end

return M
