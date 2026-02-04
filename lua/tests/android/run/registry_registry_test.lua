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

function M.run()
  selection_persists_config_id()
  resolve_uses_selected_id()
  resolves_default_when_selected_missing()
  autosaves_default_when_selected_missing()
  select_returns_config_id()
  default_registry_calls_load_twice()
  default_registry_calls_save_once()
  default_registry_load_opts_workspace()
  default_registry_save_opts_workspace()
  default_registry_save_state()
end

return M
