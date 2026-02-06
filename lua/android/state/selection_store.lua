local M = {}

local path = require("android.state.path")
local cache_by_file = {}
local snapshot_by_state = setmetatable({}, { __mode = "k" })
local LOCK_WAIT_TIMEOUT_MS = 3000
local LOCK_STALE_TIMEOUT_MS = 10000
local LOCK_WAIT_STEP_MS = 10

local function deep_copy(value, seen)
  if type(value) ~= "table" then
    return value
  end
  local tracked = seen or {}
  if tracked[value] then
    return tracked[value]
  end
  local copy = {}
  tracked[value] = copy
  for key, nested in pairs(value) do
    copy[deep_copy(key, tracked)] = deep_copy(nested, tracked)
  end
  return copy
end

local function deep_equal(left, right, seen)
  if left == right then
    return true
  end
  if type(left) ~= type(right) then
    return false
  end
  if type(left) ~= "table" then
    return false
  end

  local tracked = seen or {}
  tracked[left] = tracked[left] or {}
  if tracked[left][right] then
    return true
  end
  tracked[left][right] = true

  for key, value in pairs(left) do
    if not deep_equal(value, right[key], tracked) then
      return false
    end
  end

  for key in pairs(right) do
    if left[key] == nil then
      return false
    end
  end

  return true
end

local function merge_with_base(latest, base, next_state)
  if type(next_state) ~= "table" then
    return deep_copy(next_state)
  end

  local latest_table = type(latest) == "table" and latest or {}
  local base_table = type(base) == "table" and base or {}
  local merged = deep_copy(latest_table)
  local keys = {}

  for key in pairs(base_table) do
    keys[key] = true
  end
  for key in pairs(next_state) do
    keys[key] = true
  end
  for key in pairs(latest_table) do
    keys[key] = true
  end

  for key in pairs(keys) do
    local base_value = base_table[key]
    local next_value = next_state[key]
    local latest_value = latest_table[key]

    if next_value == nil then
      if base_value ~= nil then
        merged[key] = nil
      end
    elseif deep_equal(next_value, base_value) then
      -- Preserve latest value for unchanged keys.
    elseif type(next_value) == "table" then
      merged[key] = merge_with_base(latest_value, base_value, next_value)
    else
      merged[key] = deep_copy(next_value)
    end
  end

  return merged
end

local function remember_snapshot(state)
  if type(state) ~= "table" then
    return state
  end
  snapshot_by_state[state] = deep_copy(state)
  return state
end

local function snapshot_for(state)
  if type(state) ~= "table" then
    return nil
  end
  return snapshot_by_state[state]
end

local function replace_table_contents(target, source)
  if type(target) ~= "table" then
    return
  end

  for key in pairs(target) do
    target[key] = nil
  end

  for key, value in pairs(source or {}) do
    target[key] = deep_copy(value)
  end
end

local function file_stamp(file_path)
  local stat = vim.loop.fs_stat(file_path)
  if not stat or not stat.mtime then
    return "missing"
  end
  local sec = stat.mtime.sec or 0
  local nsec = stat.mtime.nsec or 0
  local size = stat.size or 0
  return string.format("%d:%d:%d", sec, nsec, size)
end

local function read_file(file_path)
  local ok, lines = pcall(vim.fn.readfile, file_path)
  if not ok or not lines then
    return nil
  end
  return table.concat(lines, "\n")
end

local function decode_json(payload)
  if not payload or payload == "" then
    return {}
  end
  local ok, data = pcall(vim.fn.json_decode, payload)
  if not ok or type(data) ~= "table" then
    return {}
  end
  return data
end

local function encode_json(value)
  local ok, data = pcall(vim.fn.json_encode, value or {})
  if not ok then
    return nil
  end
  return data
end

local function lock_dir_path(file_path)
  return file_path .. ".lock"
end

local function monotonic_ms()
  return math.floor(vim.loop.hrtime() / 1000000)
end

local function lock_age_ms(lock_path)
  local stat = vim.loop.fs_stat(lock_path)
  if not stat or not stat.mtime then
    return nil
  end
  local now = os.time()
  local lock_sec = stat.mtime.sec or now
  if now < lock_sec then
    return 0
  end
  return (now - lock_sec) * 1000
end

local function wait_for_lock_step()
  if type(vim.wait) == "function" then
    pcall(vim.wait, LOCK_WAIT_STEP_MS)
  end
end

local function acquire_file_lock(file_path)
  local lock_path = lock_dir_path(file_path)
  local started = monotonic_ms()

  while true do
    local ok, err = vim.loop.fs_mkdir(lock_path, 448)
    if ok then
      return function()
        pcall(vim.loop.fs_rmdir, lock_path)
      end
    end

    local message = tostring(err or "")
    if not message:match("EEXIST") then
      return nil
    end

    local age = lock_age_ms(lock_path)
    if age and age >= LOCK_STALE_TIMEOUT_MS then
      pcall(vim.loop.fs_rmdir, lock_path)
    end

    if monotonic_ms() - started >= LOCK_WAIT_TIMEOUT_MS then
      return nil
    end

    wait_for_lock_step()
  end
end

local function write_file_atomic(file_path, payload)
  local tmp_path = string.format(
    "%s.tmp.%d.%d",
    file_path,
    vim.fn.getpid(),
    vim.loop.hrtime()
  )
  local lines = vim.split(payload, "\n", { plain = true })
  local ok_write, write_err = pcall(vim.fn.writefile, lines, tmp_path)
  if not ok_write then
    pcall(vim.fn.delete, tmp_path)
    return false, write_err
  end

  local ok_rename, rename_err = vim.loop.fs_rename(tmp_path, file_path)
  if not ok_rename then
    pcall(vim.fn.delete, tmp_path)
    return false, rename_err
  end

  return true
end

function M.load(opts)
  local options = opts or {}
  local state_root = options.state_root or vim.fn.stdpath("state")
  local workspace_root = options.workspace_root
  local file_path = path.workspace_state_file(state_root, workspace_root)
  if not file_path then
    return {}
  end
  local stamp = file_stamp(file_path)
  local cached = cache_by_file[file_path]
  if cached and cached.stamp == stamp then
    return remember_snapshot(deep_copy(cached.state or {}))
  end

  local payload = read_file(file_path)
  local state = decode_json(payload)
  cache_by_file[file_path] = {
    stamp = stamp,
    payload = payload or "",
    state = deep_copy(state),
  }
  return remember_snapshot(state)
end

function M.save(opts, state)
  local options = opts or {}
  local state_root = options.state_root or vim.fn.stdpath("state")
  local workspace_root = options.workspace_root
  local dir = path.android_state_dir(state_root)
  local file_path = path.workspace_state_file(state_root, workspace_root)
  if not dir or not file_path then
    return false
  end

  pcall(vim.fn.mkdir, dir, "p")
  local next_state = type(state) == "table" and state or {}
  local payload = encode_json(next_state)
  if not payload then
    return false
  end
  local cached = cache_by_file[file_path]
  if cached and cached.payload == payload then
    return true
  end

  local release_lock = acquire_file_lock(file_path)
  if not release_lock then
    return false
  end

  local ok, saved = pcall(function()
    local latest_payload = read_file(file_path) or ""
    local latest_state = decode_json(latest_payload)
    local base_state = snapshot_for(state) or (cached and cached.state) or {}
    local merged_state = merge_with_base(latest_state, base_state, next_state)
    local merged_payload = encode_json(merged_state)
    if not merged_payload then
      return false
    end

    if latest_payload ~= merged_payload then
      local wrote = write_file_atomic(file_path, merged_payload)
      if not wrote then
        return false
      end
    end

    cache_by_file[file_path] = {
      stamp = file_stamp(file_path),
      payload = merged_payload,
      state = deep_copy(merged_state),
    }
    if type(state) == "table" then
      replace_table_contents(state, merged_state)
      remember_snapshot(state)
    end
    return true
  end)

  release_lock()

  if not ok then
    return false
  end

  return saved == true
end

return M
