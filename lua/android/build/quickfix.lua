local M = {}

local function parse_kotlin(line)
  if type(line) ~= "string" then
    return nil
  end

  local file, lnum, col, text = line:match(
    "^e:%s+(.-):%s*%((%d+),%s*(%d+)%)%s*:%s*(.+)$"
  )
  if not file then
    return nil
  end

  return {
    filename = file,
    lnum = tonumber(lnum),
    col = tonumber(col) or 1,
    text = text,
  }
end

local function parse_java(line)
  if type(line) ~= "string" then
    return nil
  end

  local file, lnum, text = line:match("^(.-):(%d+):%s*(error:%s*.+)$")
  if not file then
    return nil
  end

  return {
    filename = file,
    lnum = tonumber(lnum),
    col = 1,
    text = text,
  }
end

function M.parse(lines)
  local items = {}
  for _, line in ipairs(lines or {}) do
    local item = parse_kotlin(line) or parse_java(line)
    if item then
      table.insert(items, item)
    end
  end
  return items
end

return M
