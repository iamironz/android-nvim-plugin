local M = {}

local assert = require("tests.helpers.assert")

local function buffer_targets_returns_primary_buffer()
  package.loaded["android.utils.keymaps"] = nil
  local keymaps = require("android.utils.keymaps")
  local targets = keymaps.buffer_targets(3)
  assert.table_eq(targets, { 3 }, "primary target")
end

local function buffer_targets_includes_secondary_when_distinct()
  package.loaded["android.utils.keymaps"] = nil
  local keymaps = require("android.utils.keymaps")
  local targets = keymaps.buffer_targets(3, 7)
  assert.table_eq(targets, { 3, 7 }, "secondary target")
end

local function buffer_targets_ignores_duplicate_secondary()
  package.loaded["android.utils.keymaps"] = nil
  local keymaps = require("android.utils.keymaps")
  local targets = keymaps.buffer_targets(3, 3)
  assert.table_eq(targets, { 3 }, "deduped target")
end

function M.run()
  buffer_targets_returns_primary_buffer()
  buffer_targets_includes_secondary_when_distinct()
  buffer_targets_ignores_duplicate_secondary()
end

return M
