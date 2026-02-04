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

  local target_win = origin_win
  if target_win and vim.api.nvim_win_is_valid(target_win) then
    vim.api.nvim_set_current_win(target_win)
  else
    vim.cmd("wincmd p")
    target_win = vim.api.nvim_get_current_win()
  end

  vim.cmd("edit " .. vim.fn.fnameescape(target))
  vim.api.nvim_win_set_cursor(target_win, { parsed.line, 0 })
end

return M
