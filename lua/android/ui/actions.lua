local M = {}

local picker = require("android.ui.picker")
local menu_items = require("android.ui.menu_items")
local actions = require("android.actions.registry")
local summary = require("android.ui.summary")

local function build_items(blocks)
  local items = {}
  local max_section = 0
  for _, block in ipairs(blocks or {}) do
    local section = block.title or ""
    if #section > max_section then
      max_section = #section
    end
    for _, item in ipairs(block.items or {}) do
      items[#items + 1] = {
        section = section,
        label = item.label or "",
        desc = item.desc,
        value = item.id,
      }
    end
  end
  return items, max_section
end

local function format_entry(entry, max_section)
  local section = entry.section or ""
  local label = entry.label or ""
  local desc = entry.desc or ""
  local base = string.format("%-" .. tostring(max_section) .. "s  %s", section, label)
  if desc == "" then
    return base
  end
  return string.format("%s - %s", base, desc)
end

local function title_key(label)
  return label:sub(1, 1):upper() .. label:sub(2)
end

local function parse_summary(lines)
  local values = {}
  local allowed = {
    run = true,
    module = true,
    variant = true,
    device = true,
    logcat = true,
  }
  for _, line in ipairs(lines or {}) do
    local key, value = line:match("^%s*([^:]+):%s*(.+)%s*$")
    if key and value then
      local normalized_key = key:lower():gsub("^%s+", ""):gsub("%s+$", "")
      local normalized_value = value:gsub("^%s+", ""):gsub("%s+$", "")
      if allowed[normalized_key] and normalized_value ~= "" then
        if normalized_value:lower() ~= "none" then
          values[normalized_key] = normalized_value
        end
      end
    end
  end
  return values
end

local function build_summary_title(base_title, lines)
  local order = { "run", "module", "variant", "device", "logcat" }
  local values = parse_summary(lines)
  local parts = {}
  for _, key in ipairs(order) do
    local value = values[key]
    if value then
      parts[#parts + 1] = string.format("%s %s", title_key(key), value)
      if #parts >= 3 then
        break
      end
    end
  end
  if #parts == 0 then
    return base_title
  end
  return string.format("%s - %s", base_title, table.concat(parts, " | "))
end

function M.open(opts)
  local options = opts or {}
  local blocks = options.blocks or menu_items.top_level_blocks()
  local items, max_section = build_items(blocks)
  local title = options.title or "Android Actions"
  local default_query = options.default_query or options.initial_query
  local on_cancel = options.on_cancel
  if options.include_summary then
    title = build_summary_title(title, summary.lines())
  end
  picker.select_from_list({
    title = title,
    items = items,
    default = default_query,
    format = function(entry)
      return format_entry(entry, max_section)
    end,
    on_select = function(action_id)
      if action_id then
        actions.run(action_id)
      end
    end,
    on_cancel = on_cancel,
  })
end

return M
