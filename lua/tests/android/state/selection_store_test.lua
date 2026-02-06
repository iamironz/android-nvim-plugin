local M = {}

local assert = require("tests.helpers.assert")

local function new_state_root()
  local dir = vim.fn.tempname()
  vim.fn.mkdir(dir, "p")
  return dir
end

local function cleanup_state_root(dir)
  if dir and dir ~= "" then
    vim.fn.delete(dir, "rf")
  end
end

local function with_stubbed_writefile(callback)
  local original = vim.fn.writefile
  local count = 0
  vim.fn.writefile = function(lines, file_path)
    count = count + 1
    return original(lines, file_path)
  end
  local ok, err = pcall(function()
    callback(function()
      return count
    end)
  end)
  vim.fn.writefile = original
  if not ok then
    error(err)
  end
end

local function with_stubbed_readfile(callback)
  local original = vim.fn.readfile
  local count = 0
  vim.fn.readfile = function(file_path)
    count = count + 1
    return original(file_path)
  end
  local ok, err = pcall(function()
    callback(function()
      return count
    end)
  end)
  vim.fn.readfile = original
  if not ok then
    error(err)
  end
end

local function save_skips_duplicate_payload_writes()
  local state_root = new_state_root()
  local workspace_root = "/workspace"
  local payload = { run = { config_id = "android" }, logcat = { filter = "Main" } }
  local ok, err = pcall(function()
    package.loaded["android.state.selection_store"] = nil
    local selection_store = require("android.state.selection_store")
    with_stubbed_writefile(function(write_count)
      selection_store.save({
        state_root = state_root,
        workspace_root = workspace_root,
      }, payload)
      selection_store.save({
        state_root = state_root,
        workspace_root = workspace_root,
      }, payload)
      assert.eq(write_count(), 1, "duplicate save deduped")
    end)
  end)
  cleanup_state_root(state_root)
  if not ok then
    error(err)
  end
end

local function load_uses_cache_for_repeated_reads()
  local state_root = new_state_root()
  local workspace_root = "/workspace"
  local payload = { run = { config_id = "android" }, logcat = { filter = "Main" } }
  local ok, err = pcall(function()
    package.loaded["android.state.selection_store"] = nil
    local selection_store = require("android.state.selection_store")
    selection_store.save({
      state_root = state_root,
      workspace_root = workspace_root,
    }, payload)

    -- Reset module cache so first load hits disk, second should hit in-memory cache.
    package.loaded["android.state.selection_store"] = nil
    selection_store = require("android.state.selection_store")
    with_stubbed_readfile(function(read_count)
      selection_store.load({
        state_root = state_root,
        workspace_root = workspace_root,
      })
      selection_store.load({
        state_root = state_root,
        workspace_root = workspace_root,
      })
      assert.eq(read_count(), 1, "second load uses cache")
    end)
  end)
  cleanup_state_root(state_root)
  if not ok then
    error(err)
  end
end

local function load_returns_copied_state()
  local state_root = new_state_root()
  local workspace_root = "/workspace"
  local ok, err = pcall(function()
    package.loaded["android.state.selection_store"] = nil
    local selection_store = require("android.state.selection_store")
    selection_store.save({
      state_root = state_root,
      workspace_root = workspace_root,
    }, {
      logcat = { filter = "Main" },
    })

    local first = selection_store.load({
      state_root = state_root,
      workspace_root = workspace_root,
    })
    first.logcat.filter = "Mutated"

    local second = selection_store.load({
      state_root = state_root,
      workspace_root = workspace_root,
    })
    assert.eq(second.logcat.filter, "Main", "cached load returns copy")
  end)
  cleanup_state_root(state_root)
  if not ok then
    error(err)
  end
end

function M.run()
  save_skips_duplicate_payload_writes()
  load_uses_cache_for_repeated_reads()
  load_returns_copied_state()
end

return M
