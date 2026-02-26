local M = {}

function M.trim(value)
  if type(value) ~= "string" then
    return ""
  end
  return value:match("^%s*(.-)%s*$") or ""
end

function M.first_nonempty_line(value)
  if type(value) ~= "string" or value == "" then
    return nil
  end
  for _, line in ipairs(vim.split(value, "\n", { plain = true })) do
    local trimmed = M.trim(line)
    if trimmed ~= "" then
      return trimmed
    end
  end
  return nil
end

return M
