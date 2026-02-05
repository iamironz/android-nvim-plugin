local M = {}

local assert = require("tests.helpers.assert")

local function parses_modules_from_settings_includes()
  local workspace = require("android.gradle.workspace")
  local modules = workspace.parse_settings({
    "include(\":app\", \":lib\")",
    "include ':feature:chat', ':feature:core'",
    "// include(\":ignored\")",
    "includeBuild(\"..\")",
  })

  assert.table_eq(modules, { ":app", ":feature:chat", ":feature:core", ":lib" }, "modules")
end

local function parses_modules_from_multiline_includes()
  local workspace = require("android.gradle.workspace")
  local modules = workspace.parse_settings({
    "include ':app',",
    "  ':feature:chat',",
    "  ':feature:core'",
    "include(",
    "  \":lib\",",
    "  \":lib:core\"",
    ")",
  })

  assert.table_eq(
    modules,
    { ":app", ":feature:chat", ":feature:core", ":lib", ":lib:core" },
    "modules multiline"
  )
end

local function finds_workspace_root_from_settings()
  local workspace = require("android.gradle.workspace")
  local exists = function(path)
    return path == "/work/settings.gradle.kts"
  end

  local root = workspace.find_root("/work/app/src", exists)
  assert.eq(root, "/work", "root path")
end

local function detects_workspace_root_and_modules()
  local workspace = require("android.gradle.workspace")
  local exists = function(path)
    return path == "/repo/settings.gradle"
  end
  local read = function(path)
    if path == "/repo/settings.gradle" then
      return { "include(\":app\")" }
    end
    return nil
  end

  local result = workspace.detect("/repo/app", { exists = exists, read = read })
  assert.eq(result.root, "/repo", "detect root")
  assert.table_eq(result.modules, { ":app" }, "detect modules")
end

function M.run()
  parses_modules_from_settings_includes()
  parses_modules_from_multiline_includes()
  finds_workspace_root_from_settings()
  detects_workspace_root_and_modules()
end

return M
