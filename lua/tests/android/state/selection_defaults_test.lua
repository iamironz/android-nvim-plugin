local M = {}

local assert = require("tests.helpers.assert")

local function returns_empty_defaults_without_state()
  local defaults = require("android.state.selection_defaults")
  local build = defaults.build_defaults(nil)
  assert.eq(build.module, nil, "module default")
  assert.eq(build.variant, nil, "variant default")
end

local function marks_incomplete_without_variant()
  local defaults = require("android.state.selection_defaults")
  local state = { build = { module = ":app" } }
  assert.eq(defaults.build_is_complete(state), false, "missing variant")
end

local function marks_complete_with_variant()
  local defaults = require("android.state.selection_defaults")
  local state = { build = { module = ":app", variant = "debug" } }
  assert.eq(defaults.build_is_complete(state), true, "has variant")
end

local function updates_build_defaults()
  local defaults = require("android.state.selection_defaults")
  local next_state = defaults.apply_build_defaults({}, ":app", "release")
  assert.eq(next_state.build.module, ":app", "module set")
  assert.eq(next_state.build.variant, "release", "variant set")
end

function M.run()
  returns_empty_defaults_without_state()
  marks_incomplete_without_variant()
  marks_complete_with_variant()
  updates_build_defaults()
end

return M
