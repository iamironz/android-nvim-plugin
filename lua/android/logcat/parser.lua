local M = {}

function M.parse_stack_line(line)
  if type(line) ~= "string" then
    return nil
  end

  local file, line_number = line:match("%(([^:]+):(%d+)%)")
  if not file or not line_number then
    return nil
  end

  return { file = file, line = tonumber(line_number) }
end

return M
