local M = {}

local assert = require("tests.helpers.assert")
local stubs_helper = require("tests.helpers.stubs")
local registry_helper = require("tests.helpers.run_registry")

local function build_store(initial)
  local state = initial or {}
  return {
    load = function()
      return state
    end,
    save = function(_, next_state)
      state = next_state
      return true
    end,
    get_state = function()
      return state
    end,
  }
end

local function with_missing_selection_stub(fn)
  local calls = { find = 0, default = 0, save = 0 }
  local original_registry = package.loaded["android.run.registry"]
  local stubbed = {
    ["android.state.selection_store"] = {
      load = function()
        return { run = { config_id = "missing" } }
      end,
      save = function(_, state)
        calls.save = calls.save + 1
        calls.save_state = state
        return true
      end,
    },
    ["android.run.configs"] = {
      from_workspace = function()
        return { { id = "android" }, { id = "ios" } }
      end,
      find = function(_, id)
        calls.find = calls.find + 1
        calls.find_id = id
        return nil
      end,
      default = function(list)
        calls.default = calls.default + 1
        return list[1]
      end,
    },
  }

  stubs_helper.with_stubs(stubbed, function()
    package.loaded["android.run.registry"] = nil
    local registry = require("android.run.registry")
    local resolved = registry.resolve(registry_helper.build_workspace())
    fn(resolved, calls)
  end)
  package.loaded["android.run.registry"] = original_registry
end

local function with_selection_store_stub(fn)
  local calls = { load = 0, save = 0 }
  local original_registry = package.loaded["android.run.registry"]
  local stubbed = {
    ["android.state.selection_store"] = {
      load = function(opts)
        calls.load = calls.load + 1
        calls.load_opts = opts
        return { run = { config_id = "android" } }
      end,
      save = function(opts, state)
        calls.save = calls.save + 1
        calls.save_opts = opts
        calls.save_state = state
        return true
      end,
    },
    ["android.run.configs"] = {
      from_workspace = function()
        return { { id = "android" } }
      end,
      find = function(list, id)
        if not id then
          return nil
        end
        return list[1]
      end,
      default = function(list)
        return list[1]
      end,
    },
  }

  stubs_helper.with_stubs(stubbed, function()
    package.loaded["android.run.registry"] = nil
    local registry = require("android.run.registry")
    local workspace = registry_helper.build_workspace()
    registry.list(workspace)
    registry.select(workspace, "android")
    fn(calls)
  end)
  package.loaded["android.run.registry"] = original_registry
end

local function selection_persists_config_id()
  local registry = require("android.run.registry")
  local store = build_store()
  local instance = registry.new({ store = store })
  instance.select(registry_helper.build_workspace(), "ios")
  assert.eq(store.get_state().run.config_id, "ios", "selection stored")
end

local function snapshot_passes_detect_opts_to_configs()
  local captured = nil
  local original_registry = package.loaded["android.run.registry"]
  local stubbed = {
    ["android.state.selection_store"] = {
      load = function()
        return {}
      end,
      save = function()
        return true
      end,
    },
    ["android.run.configs"] = {
      from_workspace = function(_, opts)
        captured = opts and opts.detect_opts
        return {}
      end,
      find = function()
        return nil
      end,
      default = function()
        return nil
      end,
    },
  }

  stubs_helper.with_stubs(stubbed, function()
    package.loaded["android.run.registry"] = nil
    local registry = require("android.run.registry")
    registry.snapshot(registry_helper.build_workspace(), {
      detect_opts = { tasks = { "assemble" } },
    })
  end)
  package.loaded["android.run.registry"] = original_registry

  assert.eq(captured and captured.tasks[1], "assemble", "detect opts")
end

local function resolve_uses_selected_id()
  local registry = require("android.run.registry")
  local store = build_store({ run = { config_id = "ios" } })
  local instance = registry.new({ store = store })
  local resolved = instance.resolve(registry_helper.build_workspace())
  assert.eq(resolved.id, "ios", "selected resolve")
end

local function resolves_default_when_selected_missing()
  with_missing_selection_stub(function(resolved)
    assert.eq(resolved.id, "android", "fallback default")
  end)
end

local function autosaves_default_when_selected_missing()
  with_missing_selection_stub(function(_, calls)
    local saved_id = calls.save_state and calls.save_state.run and calls.save_state.run.config_id
    local summary = string.format("%d|%s", calls.save, saved_id or "")
    assert.eq(summary, "1|android", "autosave default")
  end)
end

local function select_returns_config_id()
  local registry = require("android.run.registry")
  local store = build_store()
  local instance = registry.new({ store = store })
  local selected = instance.select(registry_helper.build_workspace(), "android")
  assert.eq(selected, "android", "select returns id")
end

local function default_registry_calls_load_twice()
  with_selection_store_stub(function(calls)
    assert.eq(calls.load, 2, "load called")
  end)
end

local function default_registry_calls_save_once()
  with_selection_store_stub(function(calls)
    assert.eq(calls.save, 1, "save called")
  end)
end

local function default_registry_load_opts_workspace()
  with_selection_store_stub(function(calls)
    assert.eq(calls.load_opts.workspace_root, "/workspace", "load workspace")
  end)
end

local function default_registry_save_opts_workspace()
  with_selection_store_stub(function(calls)
    assert.eq(calls.save_opts.workspace_root, "/workspace", "save workspace")
  end)
end

local function default_registry_save_state()
  with_selection_store_stub(function(calls)
    assert.eq(calls.save_state.run.config_id, "android", "save state")
  end)
end

local function resolves_android_when_gradle_tasks_selected()
  local calls = { save = 0 }
  local original_registry = package.loaded["android.run.registry"]
  local stubbed = {
    ["android.state.selection_store"] = {
      load = function()
        return { run = { config_id = "gradle_tasks" } }
      end,
      save = function(_, state)
        calls.save = calls.save + 1
        calls.saved_state = state
        return true
      end,
    },
    ["android.run.configs"] = {
      from_workspace = function()
        return {
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
        }
      end,
      find = function(list, id)
        for _, entry in ipairs(list) do
          if entry.id == id then
            return entry
          end
        end
        return nil
      end,
      default = function(list)
        return list[1]
      end,
    },
  }

  stubs_helper.with_stubs(stubbed, function()
    package.loaded["android.run.registry"] = nil
    local registry = require("android.run.registry")
    local resolved = registry.resolve(registry_helper.build_workspace())
    assert.eq(resolved and resolved.id, "android:app", "fallback from gradle tasks selection")
  end)
  package.loaded["android.run.registry"] = original_registry

  assert.eq(calls.save, 1, "selection rewritten once")
  assert.eq(
    calls.saved_state and calls.saved_state.run and calls.saved_state.run.config_id,
    "android:app",
    "persisted fallback selection"
  )
end

local function keeps_gradle_tasks_when_it_is_only_config()
  local calls = { save = 0 }
  local original_registry = package.loaded["android.run.registry"]
  local stubbed = {
    ["android.state.selection_store"] = {
      load = function()
        return { run = { config_id = "gradle_tasks" } }
      end,
      save = function()
        calls.save = calls.save + 1
        return true
      end,
    },
    ["android.run.configs"] = {
      from_workspace = function()
        return {
          {
            id = "gradle_tasks",
            type = "gradle_task",
            target = "gradle",
            label = "Gradle tasks",
          },
        }
      end,
      find = function(list, id)
        for _, entry in ipairs(list) do
          if entry.id == id then
            return entry
          end
        end
        return nil
      end,
      default = function(list)
        return list[1]
      end,
    },
  }

  stubs_helper.with_stubs(stubbed, function()
    package.loaded["android.run.registry"] = nil
    local registry = require("android.run.registry")
    local resolved = registry.resolve(registry_helper.build_workspace())
    assert.eq(resolved and resolved.id, "gradle_tasks", "keep single gradle tasks config")
  end)
  package.loaded["android.run.registry"] = original_registry

  assert.eq(calls.save, 0, "selection unchanged")
end

local function resolve_skips_persist_when_requested()
  local calls = { save = 0 }
  local original_registry = package.loaded["android.run.registry"]
  local stubbed = {
    ["android.state.selection_store"] = {
      load = function()
        return {}
      end,
      save = function()
        calls.save = calls.save + 1
        return true
      end,
    },
    ["android.run.configs"] = {
      from_workspace = function()
        return {
          {
            id = "android:app",
            type = "android",
            target = "android",
            label = "Android :app",
          },
        }
      end,
      find = function()
        return nil
      end,
      default = function(list)
        return list[1]
      end,
    },
  }

  stubs_helper.with_stubs(stubbed, function()
    package.loaded["android.run.registry"] = nil
    local registry = require("android.run.registry")
    local resolved = registry.resolve(registry_helper.build_workspace(), { persist = false })
    assert.eq(resolved and resolved.id, "android:app", "resolved without persist")
  end)
  package.loaded["android.run.registry"] = original_registry

  assert.eq(calls.save, 0, "resolve did not persist")
end

local function snapshot_skips_persist_when_requested()
  local calls = { save = 0 }
  local original_registry = package.loaded["android.run.registry"]
  local stubbed = {
    ["android.state.selection_store"] = {
      load = function()
        return {}
      end,
      save = function()
        calls.save = calls.save + 1
        return true
      end,
    },
    ["android.run.configs"] = {
      from_workspace = function()
        return {
          {
            id = "android:app",
            type = "android",
            target = "android",
            label = "Android :app",
          },
        }
      end,
      find = function()
        return nil
      end,
      default = function(list)
        return list[1]
      end,
    },
  }

  stubs_helper.with_stubs(stubbed, function()
    package.loaded["android.run.registry"] = nil
    local registry = require("android.run.registry")
    local snapshot = registry.snapshot(registry_helper.build_workspace(), { persist = false })
    assert.eq(snapshot and snapshot.current and snapshot.current.id, "android:app", "snapshot resolved")
  end)
  package.loaded["android.run.registry"] = original_registry

  assert.eq(calls.save, 0, "snapshot did not persist")
end

function M.run()
  selection_persists_config_id()
  resolve_uses_selected_id()
  resolves_default_when_selected_missing()
  autosaves_default_when_selected_missing()
  select_returns_config_id()
  snapshot_passes_detect_opts_to_configs()
  default_registry_calls_load_twice()
  default_registry_calls_save_once()
  default_registry_load_opts_workspace()
  default_registry_save_opts_workspace()
  default_registry_save_state()
  resolves_android_when_gradle_tasks_selected()
  keeps_gradle_tasks_when_it_is_only_config()
  resolve_skips_persist_when_requested()
  snapshot_skips_persist_when_requested()
end

return M
