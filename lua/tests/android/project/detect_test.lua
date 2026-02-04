local M = {}

local assert = require("tests.helpers.assert")

local function detects_gradle_android_kmp_workspace()
  local detect = require("android.project.detect")
  local exists = function(path)
    local matches = {
      ["/repo/settings.gradle.kts"] = true,
      ["/repo/app/build.gradle.kts"] = true,
      ["/repo/shared/build.gradle.kts"] = true,
    }
    return matches[path] or false
  end
  local read = function(path)
    if path == "/repo/settings.gradle.kts" then
      return { "include(\":app\", \":shared\")" }
    end
    if path == "/repo/app/build.gradle.kts" then
      return { "plugins {", "id(\"com.android.application\")", "}" }
    end
    if path == "/repo/shared/build.gradle.kts" then
      return { "plugins {", "kotlin(\"multiplatform\")", "}" }
    end
    return nil
  end

  local result = detect.detect(
    "/repo/app/src",
    { exists = exists, read = read, scandir = function()
      return {}
    end }
  )

  assert.eq(result.root, "/repo", "root")
  assert.table_eq(result.modules, { ":app", ":shared" }, "modules")
  assert.is_true(result.gradle ~= nil, "gradle detected")
  assert.is_true(result.android ~= nil, "android detected")
  assert.is_true(result.kmp ~= nil, "kmp detected")
end

local function detects_android_kmp_with_version_catalog_aliases()
  local detect = require("android.project.detect")
  local exists = function(path)
    local matches = {
      ["/repo/settings.gradle.kts"] = true,
      ["/repo/androidApp/build.gradle.kts"] = true,
      ["/repo/shared/build.gradle.kts"] = true,
    }
    return matches[path] or false
  end
  local read = function(path)
    if path == "/repo/settings.gradle.kts" then
      return { "include(\":androidApp\", \":shared\")" }
    end
    if path == "/repo/androidApp/build.gradle.kts" then
      return {
        "plugins {",
        "alias(libs.plugins.androidApplication)",
        "alias(libs.plugins.kotlinAndroid)",
        "}",
      }
    end
    if path == "/repo/shared/build.gradle.kts" then
      return {
        "plugins {",
        "alias(libs.plugins.kotlinMultiplatform)",
        "}",
      }
    end
    return nil
  end

  local result = detect.detect(
    "/repo/androidApp/src",
    { exists = exists, read = read, scandir = function()
      return {}
    end }
  )

  assert.is_true(result.android ~= nil, "android detected")
  assert.is_true(result.kmp ~= nil, "kmp detected")
end

local function detects_android_with_dotted_alias()
  local detect = require("android.project.detect")
  local exists = function(path)
    local matches = {
      ["/repo/settings.gradle.kts"] = true,
      ["/repo/app/build.gradle.kts"] = true,
    }
    return matches[path] or false
  end
  local read = function(path)
    if path == "/repo/settings.gradle.kts" then
      return { "include(\":app\")" }
    end
    if path == "/repo/app/build.gradle.kts" then
      return {
        "plugins {",
        "alias(libs.plugins.android.application)",
        "}",
      }
    end
    return nil
  end

  local result = detect.detect(
    "/repo/app/src",
    { exists = exists, read = read, scandir = function()
      return {}
    end }
  )

  assert.is_true(result.android ~= nil, "android detected")
end

local function detects_android_from_namespace_only()
  local detect = require("android.project.detect")
  local exists = function(path)
    local matches = {
      ["/repo/settings.gradle.kts"] = true,
      ["/repo/app/build.gradle.kts"] = true,
    }
    return matches[path] or false
  end
  local read = function(path)
    if path == "/repo/settings.gradle.kts" then
      return { "include(\":app\")" }
    end
    if path == "/repo/app/build.gradle.kts" then
      return {
        "android {",
        "namespace = \"com.example.app\"",
        "}",
      }
    end
    return nil
  end

  local result = detect.detect(
    "/repo/app/src",
    { exists = exists, read = read, scandir = function()
      return {}
    end }
  )

  assert.is_true(result.android ~= nil, "android detected")
end

local function detects_gradle_workspace_without_android_or_kmp()
  local detect = require("android.project.detect")
  local exists = function(path)
    local matches = {
      ["/repo/settings.gradle.kts"] = true,
      ["/repo/app/build.gradle.kts"] = true,
    }
    return matches[path] or false
  end
  local read = function(path)
    if path == "/repo/settings.gradle.kts" then
      return { "include(\":app\")" }
    end
    if path == "/repo/app/build.gradle.kts" then
      return { "plugins {", "id(\"org.jetbrains.kotlin.jvm\")", "}" }
    end
    return nil
  end

  local result = detect.detect(
    "/repo/app/src",
    { exists = exists, read = read, scandir = function()
      return {}
    end }
  )

  assert.eq(result.root, "/repo", "root")
  assert.table_eq(result.modules, { ":app" }, "modules")
  assert.is_true(result.gradle ~= nil, "gradle detected")
  assert.eq(result.android, nil, "android not detected")
  assert.eq(result.kmp, nil, "kmp not detected")
end

local function detects_gradle_android_workspace_from_groovy_build()
  local detect = require("android.project.detect")
  local exists = function(path)
    local matches = {
      ["/repo/settings.gradle"] = true,
      ["/repo/app/build.gradle"] = true,
    }
    return matches[path] or false
  end
  local read = function(path)
    if path == "/repo/settings.gradle" then
      return { "include(':app')" }
    end
    if path == "/repo/app/build.gradle" then
      return { "plugins {", "id 'com.android.application'", "}" }
    end
    return nil
  end

  local result = detect.detect(
    "/repo/app/src",
    { exists = exists, read = read, scandir = function()
      return {}
    end }
  )

  assert.eq(result.root, "/repo", "root")
  assert.table_eq(result.modules, { ":app" }, "modules")
  assert.is_true(result.gradle ~= nil, "gradle detected")
  assert.is_true(result.android ~= nil, "android detected")
  assert.eq(result.kmp, nil, "kmp not detected")
end

local function ignores_commented_android_kmp_tokens()
  local detect = require("android.project.detect")
  local exists = function(path)
    local matches = {
      ["/repo/settings.gradle.kts"] = true,
      ["/repo/app/build.gradle.kts"] = true,
    }
    return matches[path] or false
  end
  local read = function(path)
    if path == "/repo/settings.gradle.kts" then
      return { "include(\":app\")" }
    end
    if path == "/repo/app/build.gradle.kts" then
      return {
        "// id(\"com.android.application\")",
        "# kotlin(\"multiplatform\")",
        "// id(\"org.jetbrains.kotlin.multiplatform\")",
      }
    end
    return nil
  end

  local result = detect.detect(
    "/repo/app/src",
    { exists = exists, read = read, scandir = function()
      return {}
    end }
  )

  assert.eq(result.root, "/repo", "root")
  assert.table_eq(result.modules, { ":app" }, "modules")
  assert.is_true(result.gradle ~= nil, "gradle detected")
  assert.eq(result.android, nil, "android not detected")
  assert.eq(result.kmp, nil, "kmp not detected")
end

local function detects_ios_workspace_from_xcodeproj()
  local detect = require("android.project.detect")
  local scandir = function(path)
    if path == "/ios" then
      return { { name = "MyApp.xcodeproj", type = "directory" } }
    end
    return {}
  end

  local result = detect.detect(
    "/ios/Sources/App/main.swift",
    { exists = function()
      return false
    end, read = function()
      return nil
    end, scandir = scandir }
  )

  assert.eq(result.root, "/ios", "root")
  assert.eq(result.ios.root, "/ios", "ios root")
  assert.eq(result.ios.project, "/ios/MyApp.xcodeproj", "ios project")
  assert.eq(result.ios.workspace, nil, "ios workspace")
  assert.eq(result.ios.package, nil, "ios package")
end

local function detects_ios_workspace_from_xcworkspace()
  local detect = require("android.project.detect")
  local scandir = function(path)
    if path == "/ios" then
      return { { name = "MyApp.xcworkspace", type = "directory" } }
    end
    return {}
  end

  local result = detect.detect(
    "/ios/Sources/App/main.swift",
    { exists = function()
      return false
    end, read = function()
      return nil
    end, scandir = scandir }
  )

  assert.eq(result.root, "/ios", "root")
  assert.eq(result.ios.root, "/ios", "ios root")
  assert.eq(result.ios.project, nil, "ios project")
  assert.eq(result.ios.workspace, "/ios/MyApp.xcworkspace", "ios workspace")
  assert.eq(result.ios.package, nil, "ios package")
end

local function detects_ios_workspace_from_package()
  local detect = require("android.project.detect")
  local exists = function(path)
    return path == "/ios/Package.swift"
  end

  local result = detect.detect(
    "/ios/Sources/App/main.swift",
    { exists = exists, read = function()
      return nil
    end, scandir = function()
      return {}
    end }
  )

  assert.eq(result.root, "/ios", "root")
  assert.table_eq(result.modules, {}, "modules")
  assert.eq(result.ios.root, "/ios", "ios root")
  assert.eq(result.ios.package, "/ios/Package.swift", "ios package")
end

local function detects_ios_workspace_under_gradle_root_ios()
  local detect = require("android.project.detect")
  local exists = function(path)
    return path == "/repo/settings.gradle.kts"
  end
  local read = function(path)
    if path == "/repo/settings.gradle.kts" then
      return { "include(\":app\")" }
    end
    return nil
  end
  local scandir = function(path)
    if path == "/repo/ios" then
      return { { name = "KmpApp.xcodeproj", type = "directory" } }
    end
    return {}
  end

  local result = detect.detect(
    "/repo/app/src",
    { exists = exists, read = read, scandir = scandir }
  )

  assert.eq(result.root, "/repo", "root")
  assert.eq(result.ios.root, "/repo/ios", "ios root")
  assert.eq(result.ios.project, "/repo/ios/KmpApp.xcodeproj", "ios project")
  assert.eq(result.ios.workspace, nil, "ios workspace")
end

local function detects_ios_workspace_under_gradle_root_iosapp()
  local detect = require("android.project.detect")
  local exists = function(path)
    return path == "/repo/settings.gradle.kts"
  end
  local read = function(path)
    if path == "/repo/settings.gradle.kts" then
      return { "include(\":app\")" }
    end
    return nil
  end
  local scandir = function(path)
    if path == "/repo/iosApp" then
      return { { name = "KmpApp.xcworkspace", type = "directory" } }
    end
    return {}
  end

  local result = detect.detect(
    "/repo/app/src",
    { exists = exists, read = read, scandir = scandir }
  )

  assert.eq(result.root, "/repo", "root")
  assert.eq(result.ios.root, "/repo/iosApp", "ios root")
  assert.eq(result.ios.project, nil, "ios project")
  assert.eq(result.ios.workspace, "/repo/iosApp/KmpApp.xcworkspace", "ios workspace")
end

local function android_false_when_no_android_tokens()
  local detect = require("android.project.detect")
  local exists = function(path)
    local matches = {
      ["/repo/settings.gradle.kts"] = true,
      ["/repo/shared/build.gradle.kts"] = true,
    }
    return matches[path] or false
  end
  local read = function(path)
    if path == "/repo/settings.gradle.kts" then
      return { "include(\":shared\")" }
    end
    if path == "/repo/shared/build.gradle.kts" then
      return { "plugins {", "kotlin(\"multiplatform\")", "}" }
    end
    return nil
  end

  local result = detect.detect(
    "/repo/shared/src",
    { exists = exists, read = read, scandir = function()
      return {}
    end }
  )

  assert.eq(result.root, "/repo", "root")
  assert.is_true(result.kmp ~= nil, "kmp detected")
  assert.eq(result.android, nil, "android not detected")
end

local function returns_nil_when_no_project()
  local detect = require("android.project.detect")
  local result = detect.detect(
    "/tmp",
    { exists = function()
      return false
    end, read = function()
      return nil
    end, scandir = function()
      return {}
    end }
  )

  assert.eq(result, nil, "no project")
end

function M.run()
  detects_gradle_android_kmp_workspace()
  detects_android_kmp_with_version_catalog_aliases()
  detects_android_with_dotted_alias()
  detects_android_from_namespace_only()
  detects_gradle_workspace_without_android_or_kmp()
  detects_gradle_android_workspace_from_groovy_build()
  ignores_commented_android_kmp_tokens()
  android_false_when_no_android_tokens()
  detects_ios_workspace_from_xcodeproj()
  detects_ios_workspace_from_xcworkspace()
  detects_ios_workspace_from_package()
  detects_ios_workspace_under_gradle_root_ios()
  detects_ios_workspace_under_gradle_root_iosapp()
  returns_nil_when_no_project()
end

return M
