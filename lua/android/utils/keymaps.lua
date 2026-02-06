local M = {}

function M.buffer_targets(primary_buf, secondary_buf)
  local targets = {}
  if primary_buf then
    targets[#targets + 1] = primary_buf
  end
  if secondary_buf and secondary_buf ~= primary_buf then
    targets[#targets + 1] = secondary_buf
  end
  return targets
end

return M
