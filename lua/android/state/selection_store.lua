local M = {}

local path = require("android.state.path")
local cache_by_file = {}

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
    return deep_copy(cached.state or {})
  end

  local payload = read_file(file_path)
  local state = decode_json(payload)
  cache_by_file[file_path] = {
    stamp = stamp,
    payload = payload or "",
    state = deep_copy(state),
  }
  return state
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

  vim.fn.mkdir(dir, "p")
  local payload = encode_json(state)
  if not payload then
    return false
  end
  local cached = cache_by_file[file_path]
  if cached and cached.payload == payload then
    return true
  end
  local lines = vim.split(payload, "\n", { plain = true })
  vim.fn.writefile(lines, file_path)
  cache_by_file[file_path] = {
    stamp = file_stamp(file_path),
    payload = payload,
    state = deep_copy(state or {}),
  }
  return true
end

return M
