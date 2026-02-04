local M = {}

local assert = require("tests.helpers.assert")

local function builds_state_directory()
  local path = require("android.state.path")
  assert.eq(path.android_state_dir("/state"), "/state/android", "state dir")
end

local function builds_workspace_state_file()
  local path = require("android.state.path")
  local file_path = path.workspace_state_file("/state", "/Users/me/My App")
  assert.eq(file_path, "/state/android/Users_me_My_App.json", "workspace file")
end

function M.run()
  builds_state_directory()
  builds_workspace_state_file()
end

return M
