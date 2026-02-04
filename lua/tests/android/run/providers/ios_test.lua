local M = {}

local assert = require("tests.helpers.assert")

local function detects_ios_workspace()
  local provider = require("android.run.providers.ios")
  local workspace = {
    root = "/workspace",
    ios = {
      root = "/workspace/ios",
      workspace = "/workspace/ios/App.xcworkspace",
      project = "/workspace/ios/App.xcodeproj",
    },
  }

  local list = provider.detect(workspace, {}, { schemes = { "App", "ios" } })
  assert.eq(#list, 1, "one ios config")
  assert.eq(list[1].target, "ios", "ios target")
  assert.eq(list[1].meta.scheme, "App", "preferred scheme")
end

local function prefers_ios_when_base_missing()
  local provider = require("android.run.providers.ios")
  local workspace = {
    root = "/workspace",
    ios = {
      root = "/workspace/ios",
      workspace = "/workspace/ios/Runner.xcworkspace",
      project = "/workspace/ios/Runner.xcodeproj",
    },
  }

  local list = provider.detect(workspace, {}, { schemes = { "ios", "Other" } })
  assert.eq(list[1].meta.scheme, "ios", "prefer ios")
end

function M.run()
  detects_ios_workspace()
  prefers_ios_when_base_missing()
end

return M
