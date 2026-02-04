local M = {}

local assert = require("tests.helpers.assert")
local gradle_cache = require("android.gradle.cache")

local function new_selection_store()
  local saved = {}
  local store = {}
  function store.load(opts)
    return saved[opts.workspace_root] or {}
  end
  function store.save(opts, state)
    saved[opts.workspace_root] = state
    return true
  end
  return store
end

local function persistent_cache_reuses_modules()
  local selection_store = new_selection_store()
  local cache = gradle_cache.persistent({ selection_store = selection_store })
  local calls = 0
  local loader = function()
    calls = calls + 1
    return { ":app" }
  end

  local first = cache.modules("/root", loader)
  local again = gradle_cache.persistent({ selection_store = selection_store })
  local second = again.modules("/root", loader)

  assert.table_eq(first, { ":app" }, "first")
  assert.table_eq(second, { ":app" }, "cached")
  assert.eq(calls, 1, "loader calls")
end

function M.run()
  persistent_cache_reuses_modules()
end

return M
