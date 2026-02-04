local M = {}

function M.trim(value)
  if type(value) ~= "string" then
    return ""
  end
  return value:match("^%s*(.-)%s*$") or ""
end

return M
