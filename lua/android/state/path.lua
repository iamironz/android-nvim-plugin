local M = {}

local function sanitize(value)
  if not value or value == "" then
    return nil
  end
  local cleaned = value:gsub("[^%w]+", "_")
  cleaned = cleaned:gsub("^_+", "")
  cleaned = cleaned:gsub("_+$", "")
  if cleaned == "" then
    return nil
  end
  return cleaned
end

function M.android_state_dir(state_root)
  if not state_root or state_root == "" then
    return nil
  end
  return state_root .. "/android"
end

function M.workspace_key(workspace_root)
  return sanitize(workspace_root)
end

function M.workspace_state_file(state_root, workspace_root)
  local dir = M.android_state_dir(state_root)
  local key = M.workspace_key(workspace_root)
  if not dir or not key then
    return nil
  end
  return dir .. "/" .. key .. ".json"
end

return M
