local M = {}

local function normalize_value(value)
  if value == nil then
    return ""
  end
  return tostring(value)
end

local function trim(value)
  return (value:gsub("^%s+", ""):gsub("%s+$", ""))
end

local function normalize_name_value(value)
  local text = normalize_value(value)
  text = trim(text:gsub("%s+", " "))
  if text == "" then
    return "-"
  end
  if #text > 40 then
    return text:sub(1, 37) .. "..."
  end
  return text
end

local function append_name_part(parts, key, value)
  parts[#parts + 1] = string.format("%s=%s", key, normalize_name_value(value))
end

local function panel_names(prefix, control_prefix, fields)
  local body = { prefix }
  local control = { control_prefix }
  for _, field in ipairs(fields or {}) do
    append_name_part(body, field.key, field.value)
    append_name_part(control, field.key, field.value)
  end
  return {
    body = table.concat(body, " "),
    control = table.concat(control, " "),
  }
end

local function filter_panel_names(prefix, results_prefix, fields)
  local names = panel_names(prefix, results_prefix, fields)
  return {
    prompt = names.body,
    results = names.control,
  }
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

function M.logcat_panel_names(opts)
  local options = opts or {}
  return panel_names("android://logcat", "android://logcat-controls", {
    { key = "module", value = options.module },
    { key = "variant", value = options.variant },
    { key = "app", value = options.package },
    { key = "filter", value = options.filter },
    { key = "level", value = options.level },
  })
end

function M.build_panel_names(opts)
  local options = opts or {}
  return panel_names("android://build", "android://build-controls", {
    { key = "module", value = options.module },
    { key = "variant", value = options.variant },
    { key = "task", value = options.task },
    { key = "filter", value = options.filter },
  })
end

function M.build_filter_panel_names(opts)
  local options = opts or {}
  return filter_panel_names("android://build-filter", "android://build-filter-results", {
    { key = "module", value = options.module },
    { key = "variant", value = options.variant },
    { key = "task", value = options.task },
    { key = "filter", value = options.filter },
  })
end

function M.logcat_filter_panel_names(opts)
  local options = opts or {}
  return filter_panel_names("android://logcat-filter", "android://logcat-filter-results", {
    { key = "module", value = options.module },
    { key = "variant", value = options.variant },
    { key = "app", value = options.package },
    { key = "filter", value = options.filter },
    { key = "level", value = options.level },
  })
end

return M
