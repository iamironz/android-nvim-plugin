local M = {}

local assert = require("tests.helpers.assert")

local function parses_installed_packages_from_sdkmanager_list()
  local packages = require("android.sdk.packages")
  local installed = packages.parse_installed({
    "Installed packages:",
    "  Path | Version | Description | Location",
    "  build-tools;34.0.0 | 34.0.0 | Android SDK Build-Tools 34 | build-tools/34.0.0",
    "  platform-tools | 35.0.1 | Android SDK Platform-Tools | platform-tools",
    "  platforms;android-34 | 1 | Android SDK Platform 34 | platforms/android-34",
    "Available Packages:",
    "  platform-tools | 35.0.1 | Android SDK Platform-Tools | platform-tools",
  })

  assert.table_eq(
    installed,
    { "build-tools;34.0.0", "platform-tools", "platforms;android-34" },
    "installed packages"
  )
end

local function returns_empty_when_no_installed_section()
  local packages = require("android.sdk.packages")
  local installed = packages.parse_installed({
    "Available Packages:",
    "  platform-tools | 35.0.1 | Android SDK Platform-Tools | platform-tools",
  })

  assert.eq(#installed, 0, "no installed packages")
end

local function lists_build_tools_versions()
  local packages = require("android.sdk.packages")
  local build_tools = packages.list_build_tools({
    "build-tools;33.0.2",
    "platform-tools",
    "build-tools;34.0.0",
  })

  assert.table_eq(build_tools, { "33.0.2", "34.0.0" }, "build tools")
end

local function lists_platform_tools_packages()
  local packages = require("android.sdk.packages")
  local platform_tools = packages.list_platform_tools({
    "platform-tools",
    "build-tools;33.0.2",
  })

  assert.table_eq(platform_tools, { "platform-tools" }, "platform tools")
end

local function lists_system_images()
  local packages = require("android.sdk.packages")
  local system_images = packages.list_system_images({
    "system-images;android-34;google_apis;arm64-v8a",
    "platform-tools",
    "system-images;android-34;google_apis;arm64-v8a",
    "system-images;android-33;default;x86_64",
  })

  assert.table_eq(
    system_images,
    {
      "system-images;android-33;default;x86_64",
      "system-images;android-34;google_apis;arm64-v8a",
    },
    "system images"
  )
end

function M.run()
  parses_installed_packages_from_sdkmanager_list()
  returns_empty_when_no_installed_section()
  lists_build_tools_versions()
  lists_platform_tools_packages()
  lists_system_images()
end

return M
