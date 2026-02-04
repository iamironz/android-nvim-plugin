local M = {}

local project = require("android.project.detect")
local state_store = require("android.state.selection_store")

local function current_path()
  local name = vim.api.nvim_buf_get_name(0)
  if name == nil or name == "" then
    return vim.fn.getcwd()
  end
  return name
end

function M.workspace()
  local detected = project.detect(current_path())
  if not detected or not detected.gradle then
    vim.notify("Android workspace not found", vim.log.levels.WARN)
    return nil
  end
  return detected
end

function M.load_state(root)
  return state_store.load({ workspace_root = root })
end

function M.save_state(root, state)
  return state_store.save({ workspace_root = root }, state)
end

return M
