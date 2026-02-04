local M = {}
local function panel()
  return require("android.ui.panel")
end
local highlight = require("android.logcat.highlight")

local function next_line_index(buf)
  local count = vim.api.nvim_buf_line_count(buf)
  if count == 1 then
    local first = vim.api.nvim_buf_get_lines(buf, 0, 1, false)[1]
    if first == "" then
      return 0
    end
  end
  return count
end

local function should_trim(session)
  return session.max_lines and session.max_lines > 0
end

local function trim_lines(lines, max_lines)
  local overflow = #lines - max_lines
  if overflow <= 0 then
    return lines
  end
  local trimmed = {}
  for i = overflow + 1, #lines do
    trimmed[#trimmed + 1] = lines[i]
  end
  return trimmed
end

local function trim(session)
  local max_lines = session.max_lines
  if not max_lines or max_lines <= 0 then
    return
  end
  session.body_lines = trim_lines(session.body_lines, max_lines)
end

local function trim_raw(session)
  local max_lines = session.max_lines
  if not max_lines or max_lines <= 0 then
    return
  end
  session.raw_lines = trim_lines(session.raw_lines, max_lines)
end

local function append_raw_lines(session, lines)
  if not lines or #lines == 0 then
    return
  end
  session.raw_lines = session.raw_lines or {}
  for _, line in ipairs(lines) do
    table.insert(session.raw_lines, line)
  end
  if should_trim(session) then
    trim_raw(session)
  end
end

local function append_lines(session, lines)
  if not lines or #lines == 0 then
    return
  end
  if session.status_message then
    session.status_message = nil
    session.body_lines = {}
    if session.active then
      panel().clear_body()
    end
  end
  for _, line in ipairs(lines) do
    table.insert(session.body_lines, line)
  end
  if should_trim(session) then
    trim(session)
  end
  if session.active then
    local start_line = next_line_index(session.buf)
    panel().append(lines)
    highlight.apply(session.buf, start_line, lines)
    if should_trim(session) then
      panel().trim_body(session.max_lines)
    end
  end
end

local function clear_body(session)
  session.backlog = {}
  session.status_message = nil
  session.body_lines = {}
  session.raw_lines = {}
  if session.active then
    highlight.clear(session.buf)
    panel().clear_body()
  end
end

M.append_lines = append_lines
M.append_raw_lines = append_raw_lines
M.clear_body = clear_body
M.next_line_index = next_line_index
M.should_trim = should_trim
M.trim = trim
M.trim_raw = trim_raw

return M
