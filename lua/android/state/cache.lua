local M = {}

local selection_store = require("android.state.selection_store")

local bucket_key = "gradle_cache"

local function default_stat(path)
  return vim.loop.fs_stat(path)
end

local function mtime_stamp(stat)
  if not stat or not stat.mtime then
    return "missing"
  end
  local sec = stat.mtime.sec or 0
  local nsec = stat.mtime.nsec or 0
  return tostring(sec) .. ":" .. tostring(nsec)
end

function M.files_stamp(paths, stat)
  local check = stat or default_stat
  local entries = {}
  for _, path in ipairs(paths or {}) do
    local info = check(path)
    table.insert(entries, path .. "=" .. mtime_stamp(info))
  end
  table.sort(entries)
  return table.concat(entries, "|")
end

function M.workspace_store(opts)
  local options = opts or {}
  local store = {}
  local selection = options.selection_store or selection_store
  local key = options.key or bucket_key

  local function load_state(workspace_root)
    return selection.load({
      workspace_root = workspace_root,
      state_root = options.state_root,
    })
  end

  local function save_state(workspace_root, state)
    return selection.save({
      workspace_root = workspace_root,
      state_root = options.state_root,
    }, state)
  end

  function store.get(workspace_root, fallback)
    if not workspace_root or workspace_root == "" then
      return fallback
    end
    local state = load_state(workspace_root)
    local bucket = state and state[key] or nil
    if bucket == nil then
      return fallback
    end
    return bucket
  end

  function store.set(workspace_root, bucket)
    if not workspace_root or workspace_root == "" then
      return bucket
    end
    local state = load_state(workspace_root)
    if type(state) ~= "table" then
      state = {}
    end
    state[key] = bucket or {}
    save_state(workspace_root, state)
    return bucket
  end

  return store
end

function M.new(opts)
  local options = opts or {}
  local store = options.store or M.workspace_store(options)
  local cache = {}

  function cache.fetch(workspace_root, key, stamp, loader)
    if not workspace_root or workspace_root == "" then
      return loader()
    end
    local bucket = store.get(workspace_root, {})
    local entry = bucket[key]
    if entry and entry.stamp == stamp then
      return entry.value
    end
    local value, cacheable = loader()
    if cacheable == false then
      return value
    end
    bucket[key] = { stamp = stamp, value = value }
    store.set(workspace_root, bucket)
    return value
  end

  function cache.clear(workspace_root, key)
    if not workspace_root or workspace_root == "" then
      return false
    end
    local bucket = store.get(workspace_root, {})
    if key then
      bucket[key] = nil
    else
      bucket = {}
    end
    store.set(workspace_root, bucket)
    return true
  end

  return cache
end

return M
