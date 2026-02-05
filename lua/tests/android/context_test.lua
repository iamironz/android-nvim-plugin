local M = {}

local assert = require("tests.helpers.assert")
local stubs = require("tests.helpers.stubs")

local function create_saver()
  local saved = {}
  local function save(tbl, key)
    saved[tbl] = saved[tbl] or {}
    if saved[tbl][key] == nil then
      saved[tbl][key] = tbl[key]
    end
  end

  local function restore()
    for tbl, keys in pairs(saved) do
      for key, value in pairs(keys) do
        tbl[key] = value
      end
    end
  end

  return save, restore
end

local function load_context()
  package.loaded["android.actions.context"] = nil
  return require("android.actions.context")
end

local function with_context_env(run)
  local save, restore = create_saver()
  local detect_calls = 0
  local settings_version = 1
  local settings_exists = true
  local buffer_name = "/repo/app/src/Main.kt"

  save(vim.api, "nvim_buf_get_name")
  vim.api.nvim_buf_get_name = function()
    return buffer_name
  end

  save(vim.fn, "getcwd")
  vim.fn.getcwd = function()
    return "/repo"
  end

  save(vim.loop, "fs_stat")
  vim.loop.fs_stat = function(path)
    if path == "/repo/settings.gradle" then
      if not settings_exists then
        return nil
      end
      return {
        type = "file",
        size = 10,
        mtime = { sec = settings_version, nsec = 0 },
      }
    end
    return nil
  end

  stubs.with_stubs({
    ["android.project.detect"] = {
      detect = function()
        detect_calls = detect_calls + 1
        return { root = "/repo", gradle = { root = "/repo" } }
      end,
    },
  }, function()
    run({
      context = load_context(),
      get_detect_calls = function()
        return detect_calls
      end,
      set_settings_version = function(value)
        settings_version = value
      end,
      set_settings_exists = function(value)
        settings_exists = value
      end,
      set_buffer_name = function(value)
        buffer_name = value
      end,
    })
  end)

  restore()
end

local function caches_workspace_on_repeated_calls()
  with_context_env(function(env)
    env.context.workspace()
    env.context.workspace()

    assert.eq(env.get_detect_calls(), 1, "cache hit")
  end)
end

local function invalidates_cache_on_settings_change()
  with_context_env(function(env)
    env.context.workspace()
    env.set_settings_version(2)
    env.context.workspace()

    assert.eq(env.get_detect_calls(), 2, "cache invalidated")
  end)
end

local function skips_cache_when_settings_missing()
  with_context_env(function(env)
    env.set_settings_exists(false)
    env.context.workspace()
    env.context.workspace()

    assert.eq(env.get_detect_calls(), 2, "missing settings skips cache")
  end)
end

local function bypasses_cache_when_path_outside_root()
  with_context_env(function(env)
    env.context.workspace()
    env.context.workspace()

    env.set_buffer_name("/other/file.txt")
    env.context.workspace()

    assert.eq(env.get_detect_calls(), 2, "outside root bypasses cache")
  end)
end

function M.run()
  caches_workspace_on_repeated_calls()
  invalidates_cache_on_settings_change()
  skips_cache_when_settings_missing()
  bypasses_cache_when_path_outside_root()
end

return M
