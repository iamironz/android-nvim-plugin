local M = {}

local utils = require("android.devices.utils")

local function commit(entries, current)
  if current and current.name then
    table.insert(entries, current)
  end
end

local function commit_device(entries, current)
  if current and current.id then
    table.insert(entries, current)
  end
end

local function parse_device_id(line)
  local id, name = line:match("^id:%s*(%d+)%s+or%s+\"([^\"]+)\"")
  if id then
    return id, name
  end
  id = line:match("^id:%s*(%d+)%s*$")
  if id then
    return id, nil
  end
  return nil, nil
end

function M.parse_avd_list(lines)
  local entries = {}
  local current = nil

  for _, line in ipairs(lines or {}) do
    local trimmed = utils.trim(line)
    local name = trimmed:match("^Name:%s*(.+)$")
    if name then
      commit(entries, current)
      current = { name = name }
      goto continue
    end

    if not current then
      goto continue
    end

    local device = trimmed:match("^Device:%s*(.+)$")
    if device then
      current.device = device
      goto continue
    end

    local path = trimmed:match("^Path:%s*(.+)$")
    if path then
      current.path = path
      goto continue
    end

    local target = trimmed:match("^Target:%s*(.+)$")
    if target then
      current.target = target
      goto continue
    end

    local abi = trimmed:match("Tag/ABI:%s*(%S+)")
    if abi then
      current.abi = abi
    end

    ::continue::
  end

  commit(entries, current)
  return entries
end

function M.parse_device_list(lines)
  local entries = {}
  local current = nil

  for _, line in ipairs(lines or {}) do
    local trimmed = utils.trim(line)
    local id, name = parse_device_id(trimmed)
    if id then
      commit_device(entries, current)
      current = { id = id, name = name }
      goto continue
    end

    if not current then
      goto continue
    end

    local device_name = trimmed:match("^Name:%s*(.+)$")
    if device_name then
      current.name = device_name
      goto continue
    end

    local oem = trimmed:match("^OEM%s*:%s*(.+)$")
    if oem then
      current.oem = oem
      goto continue
    end

    local tag = trimmed:match("^Tag%s*:%s*(.+)$")
    if tag then
      current.tag = tag
    end

    ::continue::
  end

  commit_device(entries, current)
  return entries
end

function M.list(runner, avdmanager_path)
  if not runner or not avdmanager_path then
    return {}
  end

  local lines = utils.runner_stdout_lines(runner, { avdmanager_path, "list", "avd" })
  return M.parse_avd_list(lines)
end

function M.list_devices(runner, avdmanager_path)
  if not runner or not avdmanager_path then
    return {}
  end

  local lines = utils.runner_stdout_lines(runner, { avdmanager_path, "list", "device" })
  return M.parse_device_list(lines)
end

function M.build_create_command(avdmanager_path, name, system_image, device_id, opts)
  if not avdmanager_path or avdmanager_path == "" then
    return { ok = false, error = "avdmanager path required" }
  end
  if not name or name == "" then
    return { ok = false, error = "name required" }
  end
  if not system_image or system_image == "" then
    return { ok = false, error = "system image required" }
  end
  if not device_id or device_id == "" then
    return { ok = false, error = "device id required" }
  end

  local cmd = {
    avdmanager_path,
    "create",
    "avd",
    "-n",
    name,
    "-k",
    system_image,
    "-d",
    device_id,
  }

  local options = opts or {}
  if options.force then
    table.insert(cmd, "--force")
  end

  return { ok = true, cmd = cmd }
end

return M
