local M = {}

local buf_id = nil
local win_id = nil
local header_lines = {}
local header_count = 0

local function buffer_valid()
  return buf_id and vim.api.nvim_buf_is_valid(buf_id)
end

local function reset_header()
  header_lines = {}
  header_count = 0
end

local function body_start()
  return header_count
end

function M.open()
  if not buf_id or not vim.api.nvim_buf_is_valid(buf_id) then
    buf_id = vim.api.nvim_create_buf(false, true)
    vim.api.nvim_buf_set_option(buf_id, "buftype", "nofile")
    vim.api.nvim_buf_set_option(buf_id, "swapfile", false)
    vim.api.nvim_buf_set_option(buf_id, "filetype", "android-log")
    reset_header()
  end

  vim.cmd("botright split")
  win_id = vim.api.nvim_get_current_win()
  vim.api.nvim_win_set_buf(win_id, buf_id)
end

function M.append(lines)
  if not buffer_valid() then return end

  vim.api.nvim_buf_set_lines(buf_id, -1, -1, false, lines)

  if win_id and vim.api.nvim_win_is_valid(win_id) then
    local count = vim.api.nvim_buf_line_count(buf_id)
    if count > 0 then
      vim.api.nvim_win_set_cursor(win_id, {count, 0})
    end
  end
end

function M.clear()
  if not buffer_valid() then return end
  reset_header()
  vim.api.nvim_buf_set_lines(buf_id, 0, -1, false, {})
end

function M.set_header_lines(lines)
  if not buffer_valid() then return end
  local new_lines = lines or {}
  local previous_count = header_count
  header_lines = new_lines
  header_count = #new_lines

  local existing_lines = vim.api.nvim_buf_get_lines(buf_id, 0, -1, false)
  local body_lines = {}
  if previous_count > 0 then
    for i = previous_count + 1, #existing_lines do
      body_lines[#body_lines + 1] = existing_lines[i]
    end
  else
    body_lines = existing_lines
  end

  local merged = {}
  for _, line in ipairs(header_lines) do
    merged[#merged + 1] = line
  end
  for _, line in ipairs(body_lines) do
    merged[#merged + 1] = line
  end
  vim.api.nvim_buf_set_lines(buf_id, 0, -1, false, merged)
end

function M.clear_body()
  if not buffer_valid() then return end
  local start = body_start()
  vim.api.nvim_buf_set_lines(buf_id, start, -1, false, {})
end

function M.replace_body(lines)
  if not buffer_valid() then return end
  local start = body_start()
  vim.api.nvim_buf_set_lines(buf_id, start, -1, false, lines or {})
end

function M.trim_body(max_lines)
  if not buffer_valid() then return end
  if not max_lines or max_lines <= 0 then
    return
  end
  local start = body_start()
  local total = vim.api.nvim_buf_line_count(buf_id)
  local body_lines = total - start
  if body_lines <= max_lines then
    return
  end
  local overflow = body_lines - max_lines
  vim.api.nvim_buf_set_lines(buf_id, start, start + overflow, false, {})
end

function M.close()
  if win_id and vim.api.nvim_win_is_valid(win_id) then
    vim.api.nvim_win_close(win_id, true)
    win_id = nil
    return true
  end

  win_id = nil
  return false
end

return M
