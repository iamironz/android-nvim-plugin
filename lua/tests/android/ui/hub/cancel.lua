local M = {}

local assert = require("tests.helpers.assert")

local function hub_calls_on_cancel_on_escape()
  local called = false
  local captured = { esc = nil }
  local original_keymap_set = vim.keymap.set

  vim.keymap.set = function(_, lhs, rhs)
    if lhs == "<Esc>" then
      captured.esc = rhs
    end
  end

  package.loaded["android.ui.hub"] = nil
  local hub = require("android.ui.hub")
  hub.open({
    blocks = { { title = "Build Variants", desc = "Builds and variants", items = { 1 } } },
    on_cancel = function()
      called = true
    end,
  })

  if captured.esc then
    captured.esc()
  end

  vim.keymap.set = original_keymap_set

  assert.eq(called, true, "on_cancel called")
end

local function hub_calls_on_close_with_cancel_reason()
  local reason = nil
  local captured = { esc = nil }
  local original_keymap_set = vim.keymap.set

  vim.keymap.set = function(_, lhs, rhs)
    if lhs == "<Esc>" then
      captured.esc = rhs
    end
  end

  package.loaded["android.ui.hub"] = nil
  local hub = require("android.ui.hub")
  hub.open({
    blocks = { { title = "Build Variants", desc = "Builds", items = { 1 } } },
    on_close = function(value)
      reason = value
    end,
  })

  if captured.esc then
    captured.esc()
  end

  vim.keymap.set = original_keymap_set

  assert.eq(reason, "cancel", "on_close reason")
end

local function hub_left_key_triggers_cancel()
  local canceled = false
  local captured = {}
  local original_keymap_set = vim.keymap.set

  vim.keymap.set = function(_, lhs, rhs)
    captured[lhs] = rhs
  end

  local ok, err = pcall(function()
    package.loaded["android.ui.hub"] = nil
    local hub = require("android.ui.hub")
    hub.open({
      blocks = {
        { title = "Run", items = { 1 } },
      },
      on_cancel = function()
        canceled = true
      end,
    })
    if captured["<Left>"] then
      captured["<Left>"]()
    end
  end)

  vim.keymap.set = original_keymap_set

  if not ok then
    error(err)
  end

  assert.eq(canceled, true, "left triggers cancel")
end

function M.run()
  hub_calls_on_cancel_on_escape()
  hub_calls_on_close_with_cancel_reason()
  hub_left_key_triggers_cancel()
end

return M
