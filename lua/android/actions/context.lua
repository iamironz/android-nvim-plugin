local M = {}

local project = require("android.project.detect")
local state_store = require("android.state.selection_store")

local workspace_cache = nil

local function current_path()
  local name = vim.api.nvim_buf_get_name(0)
  if name == nil or name == "" then
    return vim.fn.getcwd()
  end
  return name
end

local function normalize_root(root)
  if not root then
    return nil
  end
  return (root:gsub("/+$", ""))
end

local function stat_signature(path)
  local stat = vim.loop.fs_stat(path)
  if not stat then
    return nil
  end
  local mtime = stat.mtime or {}
  return table.concat({
    stat.type or "",
    mtime.sec or 0,
    mtime.nsec or 0,
    stat.size or 0,
  }, ":")
end

local function settings_signature(root)
  if not root then
    return nil
  end
  local candidates = {
    root .. "/settings.gradle",
    root .. "/settings.gradle.kts",
  }
  for _, path in ipairs(candidates) do
    local sig = stat_signature(path)
    if sig then
      return sig
    end
  end
  return "missing"
end

local function is_under_root(path, root)
  if not path or not root then
    return false
  end
  local normalized_root = normalize_root(root)
  if not normalized_root then
    return false
  end
  if path:sub(1, #normalized_root) ~= normalized_root then
    return false
  end
  local next_char = path:sub(#normalized_root + 1, #normalized_root + 1)
  return next_char == "" or next_char == "/"
end

local function cache_valid(cache, path)
  if not cache or not cache.workspace or not cache.root then
    return false
  end
  if cache.settings_sig == "missing" then
    return false
  end
  if not is_under_root(path, cache.root) then
    return false
  end
  local current_sig = settings_signature(cache.root)
  if current_sig == "missing" then
    return false
  end
  return current_sig == cache.settings_sig
end

function M.workspace()
  local path = current_path()
  if cache_valid(workspace_cache, path) then
    return workspace_cache.workspace
  end

  local detected = project.detect(path)
  if not detected or not detected.gradle then
    vim.notify("Android workspace not found", vim.log.levels.WARN)
    workspace_cache = nil
    return nil
  end
  local root = normalize_root(detected.root)
  local sig = settings_signature(root)
  if sig == "missing" then
    workspace_cache = nil
    return detected
  end
  workspace_cache = {
    root = root,
    settings_sig = sig,
    workspace = detected,
  }
  return detected
end

function M.load_state(root)
  return state_store.load({ workspace_root = root })
end

function M.save_state(root, state)
  return state_store.save({ workspace_root = root }, state)
end

return M
