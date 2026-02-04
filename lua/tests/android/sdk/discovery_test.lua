local M = {}

local assert = require("tests.helpers.assert")

local function prefers_android_sdk_root()
  local store = require("android.state.store").new()
  local discovery = require("android.sdk.discovery").new({
    env = {
      ANDROID_SDK_ROOT = "/sdk",
      ANDROID_HOME = "/home",
    },
    exists = function(path)
      return path == "/sdk" or path == "/home"
    end,
    store = store,
  })

  assert.eq(discovery.root(), "/sdk", "root preference")
  assert.eq(store.get("sdk_root"), "/sdk", "root cached")
end

local function falls_back_to_android_home()
  local store = require("android.state.store").new()
  local discovery = require("android.sdk.discovery").new({
    env = {
      ANDROID_HOME = "/home",
    },
    exists = function(path)
      return path == "/home"
    end,
    store = store,
  })

  assert.eq(discovery.root(), "/home", "root fallback")
end

local function prefers_configured_sdk_root()
  local store = require("android.state.store").new()
  local discovery = require("android.sdk.discovery").new({
    env = {
      ANDROID_SDK_ROOT = "/sdk",
    },
    exists = function(path)
      return path == "/custom" or path == "/sdk"
    end,
    config = {
      sdk = {
        root = "/custom",
      },
    },
    store = store,
  })

  assert.eq(discovery.root(), "/custom", "config root")
  assert.eq(store.get("sdk_root_source"), "config", "config source")
end

local function uses_local_properties_before_env()
  local store = require("android.state.store").new()
  local discovery = require("android.sdk.discovery").new({
    env = {
      ANDROID_SDK_ROOT = "/sdk-env",
    },
    root = "/project",
    exists = function(path)
      return path == "/sdk-env" or path == "/sdk-local"
    end,
    read_file = function(path)
      if path == "/project/local.properties" then
        return { "sdk.dir=/sdk-local" }
      end
      return nil
    end,
    store = store,
  })

  assert.eq(discovery.root(), "/sdk-local", "local.properties root")
  assert.eq(store.get("sdk_root_source"), "local.properties", "local.properties source")
end

local function uses_default_sdk_candidates()
  local store = require("android.state.store").new()
  local discovery = require("android.sdk.discovery").new({
    env = {},
    root = "/project",
    os_name = "Darwin",
    home = "/Users/test",
    exists = function(path)
      return path == "/Users/test/Library/Android/sdk"
    end,
    store = store,
  })

  assert.eq(discovery.root(), "/Users/test/Library/Android/sdk", "default root")
  assert.eq(store.get("sdk_root_source"), "default", "default source")
end

local function locates_sdk_tools()
  local store = require("android.state.store").new()
  local discovery = require("android.sdk.discovery").new({
    env = { ANDROID_SDK_ROOT = "/sdk" },
    exists = function(path)
      local matches = {
        ["/sdk"] = true,
        ["/sdk/cmdline-tools/latest/bin/sdkmanager"] = true,
        ["/sdk/cmdline-tools/latest/bin/avdmanager"] = true,
        ["/sdk/emulator/emulator"] = true,
        ["/sdk/platform-tools/adb"] = true,
      }
      return matches[path] or false
    end,
    store = store,
  })

  local tools = discovery.tools()
  assert.eq(tools.sdkmanager, "/sdk/cmdline-tools/latest/bin/sdkmanager", "sdkmanager")
  assert.eq(tools.avdmanager, "/sdk/cmdline-tools/latest/bin/avdmanager", "avdmanager")
  assert.eq(tools.emulator, "/sdk/emulator/emulator", "emulator")
  assert.eq(tools.adb, "/sdk/platform-tools/adb", "adb")
  assert.is_true(store.get("sdk_tools") ~= nil, "tools cached")
end

local function locates_sdk_tools_on_windows()
  local store = require("android.state.store").new()
  local discovery = require("android.sdk.discovery").new({
    env = { ANDROID_SDK_ROOT = "C:/Sdk" },
    os_name = "Windows_NT",
    exists = function(path)
      local matches = {
        ["C:/Sdk"] = true,
        ["C:/Sdk/cmdline-tools/latest/bin/sdkmanager.bat"] = true,
        ["C:/Sdk/cmdline-tools/latest/bin/avdmanager.bat"] = true,
        ["C:/Sdk/emulator/emulator.exe"] = true,
        ["C:/Sdk/platform-tools/adb.exe"] = true,
      }
      return matches[path] or false
    end,
    store = store,
  })

  local tools = discovery.tools()
  assert.eq(
    tools.sdkmanager,
    "C:/Sdk/cmdline-tools/latest/bin/sdkmanager.bat",
    "sdkmanager windows"
  )
  assert.eq(
    tools.avdmanager,
    "C:/Sdk/cmdline-tools/latest/bin/avdmanager.bat",
    "avdmanager windows"
  )
  assert.eq(tools.emulator, "C:/Sdk/emulator/emulator.exe", "emulator windows")
  assert.eq(tools.adb, "C:/Sdk/platform-tools/adb.exe", "adb windows")
end

local function falls_back_to_tools_bin()
  local store = require("android.state.store").new()
  local discovery = require("android.sdk.discovery").new({
    env = { ANDROID_SDK_ROOT = "/sdk" },
    exists = function(path)
      local matches = {
        ["/sdk"] = true,
        ["/sdk/tools/bin/sdkmanager"] = true,
        ["/sdk/tools/bin/avdmanager"] = true,
      }
      return matches[path] or false
    end,
    store = store,
  })

  local tools = discovery.tools()
  assert.eq(tools.sdkmanager, "/sdk/tools/bin/sdkmanager", "sdkmanager fallback")
  assert.eq(tools.avdmanager, "/sdk/tools/bin/avdmanager", "avdmanager fallback")
end

local function falls_back_to_cmdline_tools_bin()
  local store = require("android.state.store").new()
  local discovery = require("android.sdk.discovery").new({
    env = { ANDROID_SDK_ROOT = "/sdk" },
    exists = function(path)
      local matches = {
        ["/sdk"] = true,
        ["/sdk/cmdline-tools/bin/sdkmanager"] = true,
        ["/sdk/cmdline-tools/bin/avdmanager"] = true,
      }
      return matches[path] or false
    end,
    store = store,
  })

  local tools = discovery.tools()
  assert.eq(tools.sdkmanager, "/sdk/cmdline-tools/bin/sdkmanager", "sdkmanager cmdline")
  assert.eq(tools.avdmanager, "/sdk/cmdline-tools/bin/avdmanager", "avdmanager cmdline")
end

local function locates_aapt2_from_build_tools()
  local discovery = require("android.sdk.discovery")
  local build_tools = { "33.0.2", "34.0.0" }
  local path = discovery.locate_aapt2("/sdk", build_tools, function(p)
    return p == "/sdk/build-tools/34.0.0/aapt2"
  end)
  assert.eq(path, "/sdk/build-tools/34.0.0/aapt2", "aapt2 path")
end

local function falls_back_to_earlier_build_tools_aapt2()
  local discovery = require("android.sdk.discovery")
  local build_tools = { "33.0.2", "34.0.0" }
  local path = discovery.locate_aapt2("/sdk", build_tools, function(p)
    return p == "/sdk/build-tools/33.0.2/aapt2"
  end)
  assert.eq(path, "/sdk/build-tools/33.0.2/aapt2", "aapt2 fallback")
end

local function locates_aapt2_on_windows()
  local discovery = require("android.sdk.discovery")
  local build_tools = { "33.0.2", "34.0.0" }
  local path = discovery.locate_aapt2("C:/Sdk", build_tools, function(p)
    return p == "C:/Sdk/build-tools/34.0.0/aapt2.exe"
  end, "Windows_NT")
  assert.eq(path, "C:/Sdk/build-tools/34.0.0/aapt2.exe", "aapt2 windows")
end

local function locate_aapt2_returns_nil_without_build_tools()
  local discovery = require("android.sdk.discovery")
  local path = discovery.locate_aapt2("/sdk", nil, function()
    return false
  end)
  assert.eq(path, nil, "aapt2 requires build tools")
end

function M.run()
  prefers_android_sdk_root()
  falls_back_to_android_home()
  prefers_configured_sdk_root()
  uses_local_properties_before_env()
  uses_default_sdk_candidates()
  locates_sdk_tools()
  locates_sdk_tools_on_windows()
  falls_back_to_cmdline_tools_bin()
  falls_back_to_tools_bin()
  locates_aapt2_from_build_tools()
  falls_back_to_earlier_build_tools_aapt2()
  locates_aapt2_on_windows()
  locate_aapt2_returns_nil_without_build_tools()
end

return M
