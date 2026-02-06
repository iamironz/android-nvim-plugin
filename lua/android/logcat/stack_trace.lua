local M = {}

local function is_absolute(path)
  if not path or path == "" then
    return false
  end
  if path:sub(1, 1) == "/" then
    return true
  end
  return path:match("^%a:[/\\]") ~= nil
end

local function resolve_source_path(root, filename)
  if not filename or filename == "" then
    return nil
  end
  if is_absolute(filename) then
    return filename
  end
  if not root or root == "" then
    return nil
  end
  local found = vim.fn.findfile(filename, root .. "/**")
  if found == nil or found == "" then
    return nil
  end
  return found
end

local function resolve_target_win(origin_win)
  if origin_win and vim.api.nvim_win_is_valid(origin_win) then
    return origin_win
  end

  local switched = pcall(vim.cmd, "wincmd p")
  if switched then
    local previous = vim.api.nvim_get_current_win()
    if previous and vim.api.nvim_win_is_valid(previous) then
      return previous
    end
  end

  local current = vim.api.nvim_get_current_win()
  if current and vim.api.nvim_win_is_valid(current) then
    return current
  end

  return nil
end

local function clamp_line(win, line)
  local value = tonumber(line) or 1
  if value < 1 then
    value = 1
  end
  if not win or not vim.api.nvim_win_is_valid(win) then
    return value
  end
  local buf = vim.api.nvim_win_get_buf(win)
  local max_line = vim.api.nvim_buf_line_count(buf)
  if max_line < 1 then
    max_line = 1
  end
  if value > max_line then
    return max_line
  end
  return value
end

function M.open_stack_trace(root, origin_win)
  local line = vim.api.nvim_get_current_line()
  local parser = require("android.logcat.parser")
  local parsed = parser.parse_stack_line(line)
  if not parsed then
    vim.notify("No stack trace location", vim.log.levels.WARN)
    return
  end

  local target = resolve_source_path(root, parsed.file)
  if not target then
    vim.notify("File not found: " .. parsed.file, vim.log.levels.WARN)
    return
  end

  local target_win = resolve_target_win(origin_win)
  if target_win then
    vim.api.nvim_set_current_win(target_win)
  end

  vim.cmd("edit " .. vim.fn.fnameescape(target))
  local current_win = vim.api.nvim_get_current_win()
  local line_number = clamp_line(current_win, parsed.line)
  pcall(vim.api.nvim_win_set_cursor, current_win, { line_number, 0 })
end

return M
