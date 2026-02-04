local M = {}

local filters = require("android.logcat.filters")

local function append(target, items)
  for _, item in ipairs(items or {}) do
    table.insert(target, item)
  end
end

local function build_filter_args(filter_spec)
  local spec = filter_spec or {}
  local tag = spec.tag
  local level = spec.level
  local args = {}

  if tag and tag ~= "" then
    local normalized = filters.normalize_level(level, "V")
    table.insert(args, tag .. ":" .. normalized)
    table.insert(args, "*:S")
    return args
  end

  local normalized = filters.normalize_level(level, nil)
  if normalized then
    table.insert(args, "*:" .. normalized)
  end

  return args
end

function M.build(opts)
  local options = opts or {}
  local cmd = {}

  if options.adb_path then
    table.insert(cmd, options.adb_path)
  end

  if options.serial and options.serial ~= "" then
    append(cmd, { "-s", options.serial })
  end

  append(cmd, { "logcat", "-v", options.format or "threadtime" })

  if options.pid and options.pid ~= "" then
    append(cmd, { "--pid", options.pid })
  elseif options.package and options.package ~= "" then
    append(cmd, { "-e", options.package })
  end

  append(cmd, build_filter_args(options.filters))
  return cmd
end

return M
