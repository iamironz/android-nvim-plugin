local M = {}
local warned_invalid_paths = {}

local function read_file(path)
  local ok, lines = pcall(vim.fn.readfile, path)
  if not ok or not lines then
    return nil
  end
  return table.concat(lines, "\n")
end

local function clear_warning(path)
  if path and path ~= "" then
    warned_invalid_paths[path] = nil
  end
end

local function warn_invalid_json(path, detail, notify)
  local key = path or "<unknown>"
  if warned_invalid_paths[key] then
    return
  end

  warned_invalid_paths[key] = true
  local message = string.format(
    "Invalid shared project config JSON in %s",
    key
  )
  if detail and detail ~= "" then
    message = string.format("%s: %s", message, detail)
  end
  message = message .. ". Check JSON syntax."
  (notify or vim.notify)(message, vim.log.levels.WARN)
end

local function decode_json(payload, path, notify)
  if not payload or payload == "" then
    clear_warning(path)
    return {}
  end

  local ok, data = pcall(vim.fn.json_decode, payload)
  if not ok then
    warn_invalid_json(path, tostring(data), notify)
    return {}
  end
  if type(data) ~= "table" then
    warn_invalid_json(path, "expected a JSON object", notify)
    return {}
  end

  clear_warning(path)
  return data
end

function M.is_absolute_path(path)
  if not path or path == "" then
    return false
  end
  if path:sub(1, 1) == "/" then
    return true
  end
  if path:match("^%a:[\\/]") then
    return true
  end
  return false
end

function M.resolve_path(root, path)
  if not path or path == "" then
    return nil
  end
  if M.is_absolute_path(path) then
    return path
  end
  if not root or root == "" then
    return path
  end
  return root .. "/" .. path
end

function M.resolve_config_path(root, opts)
  local options = opts or {}
  local override = options.config_path
  local config = require("android.config").get()
  local configured = config and config.run and config.run.config_path or nil
  local path = override or configured or ".android.nvim.json"

  if M.is_absolute_path(path) then
    return path
  end
  if not root or root == "" then
    return nil
  end

  return root .. "/" .. path
end

function M.load(workspace, opts)
  local root = type(workspace) == "table" and workspace.root or workspace
  local path = M.resolve_config_path(root, opts)
  if not path then
    return {}
  end

  local reader = opts and opts.read or read_file
  local notify = opts and opts.notify or vim.notify
  return decode_json(reader(path), path, notify)
end

return M
