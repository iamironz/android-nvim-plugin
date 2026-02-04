local M = {}

local path = require("android.state.path")

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

  local payload = read_file(file_path)
  return decode_json(payload)
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
  local lines = vim.split(payload, "\n", { plain = true })
  vim.fn.writefile(lines, file_path)
  return true
end

return M
