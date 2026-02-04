local M = {}

function M.build_workspace()
  return {
    root = "/workspace",
    modules = { ":app", ":server" },
    android = { root = "/workspace", modules = { ":app", ":server" } },
    ios = {
      root = "/workspace/ios",
      workspace = "/workspace/ios/App.xcworkspace",
      project = "/workspace/ios/App.xcodeproj",
      package = "/workspace/ios/Package.swift",
    },
  }
end

return M
