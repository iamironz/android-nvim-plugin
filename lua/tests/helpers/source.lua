local M = {}

local function count_keyword(line, keyword)
  local pattern = "%f[%a]" .. keyword .. "%f[^%a]"
  local count = 0
  local index = 1
  while true do
    local start_pos, end_pos = line:find(pattern, index)
    if not start_pos then
      break
    end
    count = count + 1
    index = end_pos + 1
  end
  return count
end

local function read_lines(path)
  local ok, lines = pcall(vim.fn.readfile, path)
  if not ok then
    return nil, "failed to read file"
  end
  return lines
end

function M.file_line_count(path)
  local lines, err = read_lines(path)
  if not lines then
    return nil, err
  end
  return #lines
end

function M.function_length(path, signature_pattern)
  local lines, err = read_lines(path)
  if not lines then
    return nil, err
  end

  local start_line = nil
  for index, line in ipairs(lines) do
    if line:match(signature_pattern) then
      start_line = index
      break
    end
  end
  if not start_line then
    return nil, "function signature not found"
  end

  local depth = 1
  for index = start_line + 1, #lines do
    local line = lines[index]
    depth = depth + count_keyword(line, "function")
    depth = depth + count_keyword(line, "if")
    depth = depth + count_keyword(line, "for")
    depth = depth + count_keyword(line, "while")
    depth = depth + count_keyword(line, "repeat")
    depth = depth + count_keyword(line, "do")
    depth = depth - count_keyword(line, "end")
    if depth <= 0 then
      return index - start_line + 1
    end
  end

  return nil, "function does not terminate"
end

return M
