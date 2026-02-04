local M = {}

local function read_file(path)
  local ok, lines = pcall(vim.fn.readfile, path)
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

local function is_absolute_path(path)
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

local function resolve_config_path(root, opts)
  local options = opts or {}
  local override = options.config_path
  local config = require("android.config").get()
  local configured = config and config.run and config.run.config_path or nil
  local path = override or configured or ".android.nvim.json"

  if is_absolute_path(path) then
    return path
  end
  if not root or root == "" then
    return nil
  end
  return root .. "/" .. path
end

function M.load(workspace, opts)
  local root = workspace and workspace.root
  local path = resolve_config_path(root, opts)
  if not path then
    return {}
  end
  local reader = opts and opts.read or read_file
  local payload = reader(path)
  return decode_json(payload)
end

function M.shell_configs(workspace, opts)
  if opts and opts.configs then
    return opts.configs
  end
  local data = M.load(workspace, opts)
  local run = data.run or {}
  local shell = run.shell
  if type(shell) ~= "table" then
    return {}
  end
  return shell
end

return M
