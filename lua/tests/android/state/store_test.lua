local M = {}

local assert = require("tests.helpers.assert")

local function gets_initial_value()
  local store = require("android.state.store").new({ status = "idle" })
  assert.eq(store.get("status"), "idle", "initial get")

  store.set("status", "busy")
  assert.eq(store.get("status"), "busy", "updated get")
end

local function returns_fallback_for_missing_key()
  local store = require("android.state.store").new()
  assert.eq(store.get("missing", "fallback"), "fallback", "fallback get")
end

local function updates_value_and_returns_next()
  local store = require("android.state.store").new({ count = 1 })
  local next_value = store.update("count", function(value)
    return value + 1
  end)

  assert.eq(next_value, 2, "update return")
  assert.eq(store.get("count"), 2, "update stored")
end

local function snapshot_is_isolated_from_store()
  local store = require("android.state.store").new({ name = "main" })
  local snapshot = store.snapshot()

  assert.eq(snapshot.name, "main", "snapshot value")
  snapshot.name = "changed"
  assert.eq(store.get("name"), "main", "snapshot isolation")
  assert.is_true(snapshot ~= store.get(), "snapshot identity")
end

local function resets_state_values()
  local store = require("android.state.store").new({ mode = "a" })
  store.reset({ mode = "b" })
  assert.eq(store.get("mode"), "b", "reset state")
end

function M.run()
  gets_initial_value()
  returns_fallback_for_missing_key()
  updates_value_and_returns_next()
  snapshot_is_isolated_from_store()
  resets_state_values()
end

return M
