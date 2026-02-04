local M = {}

local function compare(a, b)
  local priority_a = a.priority or 100
  local priority_b = b.priority or 100
  if priority_a ~= priority_b then
    return priority_a < priority_b
  end
  local label_a = a.label or a.id or ""
  local label_b = b.label or b.id or ""
  if label_a ~= label_b then
    return label_a < label_b
  end
  return (a.id or "") < (b.id or "")
end

function M.sort_configs(configs)
  local list = {}
  for _, entry in ipairs(configs or {}) do
    list[#list + 1] = entry
  end
  table.sort(list, compare)
  return list
end

return M
