local M = {}

local job = require("android.command.job")

local function copy_opts(opts)
  local result = {}
  for key, value in pairs(opts or {}) do
    result[key] = value
  end
  return result
end

function M.new(config)
  local options = config or {}
  local spawn = options.spawn or job.spawn
  local entries = {}
  local entries_by_id = {}

  local function list()
    return entries
  end

  local function start(cmd, opts)
    local options = opts or {}
    local entry = {
      id = nil,
      status = "failed",
      exit_code = nil,
      ok = false,
      stop = function() end,
    }

    local on_exit = options.on_exit
    local spawn_opts = copy_opts(options)
    spawn_opts.on_exit = function(code)
      entry.exit_code = code
      entry.ok = code == 0
      if entry.status ~= "stopped" then
        if code == 0 then
          entry.status = "success"
        else
          entry.status = "failed"
        end
      end
      if on_exit then
        on_exit(code)
      end
    end

    local handle = spawn(cmd, spawn_opts)
    entry.id = handle and handle.id or nil
    entry.ok = handle and handle.ok or false
    if handle and handle.stop then
      entry.stop = function()
        handle.stop()
      end
    end

    if handle and handle.ok then
      entry.status = "running"
      entries[#entries + 1] = entry
      if entry.id ~= nil then
        entries_by_id[entry.id] = entry
      end
    else
      entry.status = "failed"
    end

    return entry
  end

  local function resolve_entry(value)
    if type(value) == "table" then
      return value
    end
    if value == nil then
      return nil
    end
    return entries_by_id[value]
  end

  local function stop(value)
    local entry = resolve_entry(value)
    if not entry then
      return
    end
    if entry.stop then
      entry.stop()
    end
    entry.status = "stopped"
    entry.ok = false
  end

  return {
    start = start,
    stop = stop,
    list = list,
  }
end

local default_manager = M.new({ spawn = job.spawn })

function M.start(cmd, opts)
  return default_manager.start(cmd, opts)
end

function M.stop(entry)
  return default_manager.stop(entry)
end

function M.list()
  return default_manager.list()
end

return M
