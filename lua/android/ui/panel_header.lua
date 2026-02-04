local M = {}

local function normalize_value(value)
  if value == nil then
    return ""
  end
  return tostring(value)
end

function M.logcat_lines(opts)
  local options = opts or {}
  return {
    string.format("Package: %s", normalize_value(options.package)),
    string.format("Filter: %s", normalize_value(options.filter)),
    string.format("Level: %s", normalize_value(options.level)),
  }
end

function M.build_lines(opts)
  local options = opts or {}
  return {
    string.format("Filter: %s", normalize_value(options.filter)),
  }
end

return M
