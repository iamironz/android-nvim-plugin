local M = {}

local assert = require("tests.helpers.assert")
local stubs = require("tests.helpers.stubs")

local function with_selection_store_stub(fn)
  local storage = {}
  local stubbed = {
    ["android.state.selection_store"] = {
      load = function(opts)
        return storage[opts.workspace_root] or {}
      end,
      save = function(opts, state)
        storage[opts.workspace_root] = state
        return true
      end,
    },
  }

  stubs.with_stubs(stubbed, function()
    package.loaded["android.state.cache"] = nil
    local cache = require("android.state.cache")
    fn(cache, storage)
  end)
end

local function reuses_cache_across_instances()
  with_selection_store_stub(function(cache, storage)
    assert.is_true(type(cache.workspace_store) == "function", "workspace_store")

    local calls = 0
    local function first_loader()
      calls = calls + 1
      return "alpha"
    end

    local store_a = cache.workspace_store()
    local cache_a = cache.new({ store = store_a })
    local value = cache_a.fetch("/workspace", "modules", "stamp", first_loader)
    assert.eq(value, "alpha", "first value")
    assert.eq(calls, 1, "loader called once")

    local store_b = cache.workspace_store()
    local cache_b = cache.new({ store = store_b })
    local reused = cache_b.fetch("/workspace", "modules", "stamp", function()
      calls = calls + 1
      return "beta"
    end)

    assert.eq(reused, "alpha", "reused value")
    assert.eq(calls, 1, "loader not called")
    assert.eq(storage["/workspace"].gradle_cache.modules.value, "alpha", "bucket key")
  end)
end

function M.run()
  reuses_cache_across_instances()
end

return M
