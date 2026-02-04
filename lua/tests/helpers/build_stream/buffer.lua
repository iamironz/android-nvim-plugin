local M = {}

local function clone_lines(lines)
  local copy = {}
  for i, line in ipairs(lines or {}) do
    copy[i] = line
  end
  return copy
end

function M.ensure_buffer(state, buf)
  state.buffers[buf] = state.buffers[buf] or { lines = {} }
  return state.buffers[buf]
end

function M.buffer_get_lines(state, buf, start, end_)
  local buffer = M.ensure_buffer(state, buf)
  local start_index = start + 1
  local end_index = end_ == -1 and #buffer.lines or end_
  local result = {}
  for i = start_index, end_index do
    result[#result + 1] = buffer.lines[i]
  end
  return result
end

function M.buffer_set_lines(state, buf, start, end_, lines)
  local buffer = M.ensure_buffer(state, buf)
  local start_index = start + 1
  local end_index = end_ == -1 and #buffer.lines or end_
  local next_lines = {}
  for i = 1, start_index - 1 do
    next_lines[#next_lines + 1] = buffer.lines[i]
  end
  for _, line in ipairs(lines or {}) do
    next_lines[#next_lines + 1] = line
  end
  for i = end_index + 1, #buffer.lines do
    next_lines[#next_lines + 1] = buffer.lines[i]
  end
  buffer.lines = next_lines

  local attached = state.attached[buf]
  if attached and attached.on_lines then
    attached.on_lines(nil, buf, 0, start, end_, start + #(lines or {}), 0)
  end
end

function M.set_header_lines_in_buffer(state, lines)
  local buf = state.current_buf
  local buffer = M.ensure_buffer(state, buf)
  local previous_count = state.header_count or 0
  local body_lines = {}
  if previous_count > 0 then
    for i = previous_count + 1, #buffer.lines do
      body_lines[#body_lines + 1] = buffer.lines[i]
    end
  else
    body_lines = clone_lines(buffer.lines)
  end

  local merged = {}
  for _, line in ipairs(lines or {}) do
    merged[#merged + 1] = line
  end
  for _, line in ipairs(body_lines) do
    merged[#merged + 1] = line
  end
  state.header_count = #merged - #body_lines
  M.buffer_set_lines(state, buf, 0, -1, merged)
end

function M.set_body_lines_in_buffer(state, lines)
  local buf = state.current_buf
  local buffer = M.ensure_buffer(state, buf)
  local header_lines = {}
  local header_count = state.header_count or 0
  if header_count > 0 then
    for i = 1, header_count do
      header_lines[#header_lines + 1] = buffer.lines[i]
    end
  end

  local merged = {}
  for _, line in ipairs(header_lines) do
    merged[#merged + 1] = line
  end
  for _, line in ipairs(lines or {}) do
    merged[#merged + 1] = line
  end
  M.buffer_set_lines(state, buf, 0, -1, merged)
end

function M.append_body_lines_in_buffer(state, lines)
  local buf = state.current_buf
  local buffer = M.ensure_buffer(state, buf)
  local next_lines = clone_lines(buffer.lines)
  for _, line in ipairs(lines or {}) do
    next_lines[#next_lines + 1] = line
  end
  M.buffer_set_lines(state, buf, 0, -1, next_lines)
end

function M.trim_body_lines_in_buffer(state, max_lines)
  if not max_lines or max_lines <= 0 then
    return nil
  end
  local buf = state.current_buf
  local header_count = state.header_count or 0
  local body_lines = M.buffer_get_lines(state, buf, header_count, -1)
  if #body_lines <= max_lines then
    return nil
  end
  local trimmed = {}
  for i = #body_lines - max_lines + 1, #body_lines do
    trimmed[#trimmed + 1] = body_lines[i]
  end
  M.set_body_lines_in_buffer(state, trimmed)
  return trimmed
end

function M.append_lines(target, lines)
  for _, line in ipairs(lines or {}) do
    table.insert(target, line)
  end
end

return M
