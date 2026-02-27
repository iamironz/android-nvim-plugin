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

local function parses_include_builds_from_settings()
  local workspace = require("android.gradle.workspace")
  local include_builds = workspace.parse_include_builds({
    "includeBuild(\"client\")",
    "includeBuild 'driver'",
    "includeBuild(\"common\") {",
    "  dependencySubstitution {",
    "  }",
    "}",
    "// includeBuild(\"ignored\")",
  })

  assert.table_eq(include_builds, { "client", "common", "driver" }, "include builds")
end

local function loads_modules_from_included_builds()
  local workspace = require("android.gradle.workspace")
  local read = function(path)
    if path == "/repo/settings.gradle" then
      return {
        "include(\":root\")",
        "includeBuild(\"client\")",
        "includeBuild(\"driver\")",
      }
    end
    if path == "/repo/client/settings.gradle" then
      return { "include(\":app\", \":feature:chat\")" }
    end
    if path == "/repo/driver/settings.gradle" then
      return { "include(\":app\")" }
    end
    return nil
  end

  local modules = workspace.load_modules("/repo", read)
  assert.table_eq(
    modules,
    { ":client:app", ":client:feature:chat", ":driver:app", ":root" },
    "composite modules"
  )
end

local function loads_included_build_roots()
  local workspace = require("android.gradle.workspace")
  local read = function(path)
    if path == "/repo/settings.gradle" then
      return {
        "includeBuild(\"client\")",
        "includeBuild(\"tools/driver\")",
      }
    end
    return nil
  end

  local builds = workspace.load_included_builds("/repo", read)
  assert.eq(#builds, 2, "included build count")
  assert.eq(builds[1].name, "client", "first included build name")
  assert.eq(builds[1].root, "/repo/client", "first included build root")
  assert.eq(builds[2].name, "driver", "second included build name")
  assert.eq(builds[2].root, "/repo/tools/driver", "second included build root")
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
  parses_include_builds_from_settings()
  loads_modules_from_included_builds()
  loads_included_build_roots()
  finds_workspace_root_from_settings()
  detects_workspace_root_and_modules()
end

return M
