local M = {}

local assert = require("tests.helpers.assert")
local stubs = require("tests.helpers.stubs")

local function make_reporter()
  local calls = { start = {}, ok = {}, warn = {}, error = {}, info = {} }
  local reporter = {
    start = function(message)
      table.insert(calls.start, message)
    end,
    ok = function(message)
      table.insert(calls.ok, message)
    end,
    warn = function(message)
      table.insert(calls.warn, message)
    end,
    error = function(message)
      table.insert(calls.error, message)
    end,
    info = function(message)
      table.insert(calls.info, message)
    end,
  }
  return reporter, calls
end

local function make_legacy_reporter(with_start)
  local calls = { ok = {}, warn = {}, error = {}, info = {} }
  local reporter = {
    report_ok = function(message)
      table.insert(calls.ok, message)
    end,
    report_warn = function(message)
      table.insert(calls.warn, message)
    end,
    report_error = function(message)
      table.insert(calls.error, message)
    end,
    report_info = function(message)
      table.insert(calls.info, message)
    end,
  }
  if with_start then
    reporter.report_start = function(message)
      table.insert(calls.info, message)
    end
  end
  return reporter, calls
end

local function join_messages(messages)
  return table.concat(messages or {}, "\n")
end

local function reports_missing_sdk_root()
  local reporter, calls = make_reporter()
  require("android.health").check({
    health = reporter,
    cwd = "/repo",
    os_name = "Darwin",
    env = {},
    exists = function()
      return false
    end,
    read_file = function()
      return nil
    end,
    scandir = function()
      return {}
    end,
    executable = function()
      return 1
    end,
    project = { root = "/repo" },
  })

  local errors = join_messages(calls.error)
  assert.contains(errors, "Android SDK root not found", "sdk root error")
  assert.contains(errors, "ANDROID_SDK_ROOT", "sdk root hint")
end

local function reports_android_tools_and_aapt2()
  local reporter, calls = make_reporter()
  require("android.health").check({
    health = reporter,
    cwd = "/repo",
    os_name = "Darwin",
    env = { ANDROID_SDK_ROOT = "/sdk" },
    exists = function(path)
      local matches = {
        ["/sdk"] = true,
        ["/sdk/cmdline-tools/latest/bin/sdkmanager"] = true,
        ["/sdk/cmdline-tools/latest/bin/avdmanager"] = true,
        ["/sdk/emulator/emulator"] = true,
        ["/sdk/platform-tools/adb"] = true,
        ["/sdk/build-tools/34.0.0/aapt2"] = true,
        ["/repo/gradlew"] = true,
      }
      return matches[path] or false
    end,
    read_file = function()
      return nil
    end,
    scandir = function(path)
      if path == "/sdk/build-tools" then
        return { { name = "34.0.0", type = "directory" } }
      end
      return {}
    end,
    executable = function(command)
      if command == "xcodebuild" or command == "xcrun" then
        return 1
      end
      return 0
    end,
    project = { root = "/repo" },
  })

  local ok_messages = join_messages(calls.ok)
  assert.contains(ok_messages, "Android SDK root", "sdk root ok")
  assert.contains(ok_messages, "sdkmanager", "sdkmanager ok")
  assert.contains(ok_messages, "avdmanager", "avdmanager ok")
  assert.contains(ok_messages, "adb", "adb ok")
  assert.contains(ok_messages, "emulator", "emulator ok")
  assert.contains(ok_messages, "aapt2", "aapt2 ok")
  assert.contains(ok_messages, "xcodebuild", "xcodebuild ok")
  assert.contains(ok_messages, "xcrun", "xcrun ok")
end

local function reports_gradle_missing_from_path()
  local reporter, calls = make_reporter()
  require("android.health").check({
    health = reporter,
    cwd = "/repo",
    os_name = "Darwin",
    env = { ANDROID_SDK_ROOT = "/sdk" },
    exists = function(path)
      return path == "/sdk"
    end,
    read_file = function()
      return nil
    end,
    scandir = function()
      return {}
    end,
    executable = function()
      return 0
    end,
    project = { root = "/repo" },
  })

  local errors = join_messages(calls.error)
  assert.contains(errors, "Gradle command not found", "gradle error")
  assert.contains(errors, "gradle_command", "gradle hint")
end

local function warns_when_gradle_project_missing()
  local reporter, calls = make_reporter()
  stubs.with_stubs({
    ["android.project.detect"] = {
      detect = function()
        return nil
      end,
    },
  }, function()
    package.loaded["android.health"] = nil
    require("android.health").check({
      health = reporter,
      cwd = "/repo",
      os_name = "Darwin",
      env = {},
      exists = function()
        return false
      end,
      read_file = function()
        return nil
      end,
      scandir = function()
        return {}
      end,
      executable = function()
        return 0
      end,
    })
  end)

  local warnings = join_messages(calls.warn)
  assert.contains(warnings, "Gradle project not detected", "gradle warning")
  assert.contains(warnings, "/repo", "gradle cwd")
end

local function reports_gradle_command_resolution_failure()
  local reporter, calls = make_reporter()
  stubs.with_stubs({
    ["android.actions.build_helpers"] = {
      resolve_gradle_command = function()
        return nil
      end,
    },
    ["android.project.detect"] = {
      detect = function()
        return { root = "/repo" }
      end,
    },
  }, function()
    package.loaded["android.health"] = nil
    require("android.health").check({
      health = reporter,
      cwd = "/repo",
      os_name = "Darwin",
      env = {},
      exists = function()
        return false
      end,
      read_file = function()
        return nil
      end,
      scandir = function()
        return {}
      end,
      executable = function()
        return 0
      end,
    })
  end)

  local errors = join_messages(calls.error)
  assert.contains(errors, "Gradle command not resolved", "gradle command error")
  assert.contains(errors, "/repo", "gradle command root")
end

local function supports_legacy_reporter_without_start()
  local reporter, calls = make_legacy_reporter(false)
  require("android.health").check({
    health = reporter,
    cwd = "/repo",
    os_name = "Darwin",
    env = {},
    exists = function()
      return false
    end,
    read_file = function()
      return nil
    end,
    scandir = function()
      return {}
    end,
    executable = function()
      return 0
    end,
    project = { root = "/repo" },
  })

  local errors = join_messages(calls.error)
  assert.contains(errors, "Android SDK root not found", "legacy reporter")
end

local function warns_when_ios_tools_missing_on_macos()
  local reporter, calls = make_reporter()
  require("android.health").check({
    health = reporter,
    cwd = "/repo",
    os_name = "Darwin",
    env = {},
    exists = function()
      return false
    end,
    read_file = function()
      return nil
    end,
    scandir = function()
      return {}
    end,
    executable = function()
      return 0
    end,
    project = { root = "/repo" },
  })

  local warnings = join_messages(calls.warn)
  assert.contains(warnings, "xcodebuild not found", "xcodebuild warning")
  assert.contains(warnings, "xcrun not found", "xcrun warning")
end

local function skips_ios_checks_on_non_macos()
  local reporter, calls = make_reporter()
  require("android.health").check({
    health = reporter,
    cwd = "/repo",
    os_name = "Linux",
    env = {},
    exists = function()
      return false
    end,
    read_file = function()
      return nil
    end,
    scandir = function()
      return {}
    end,
    executable = function()
      return 0
    end,
    project = { root = "/repo" },
  })

  local info = join_messages(calls.info)
  assert.contains(info, "iOS checks skipped", "non macOS skip")
end

function M.run()
  reports_missing_sdk_root()
  reports_android_tools_and_aapt2()
  reports_gradle_missing_from_path()
  warns_when_gradle_project_missing()
  reports_gradle_command_resolution_failure()
  supports_legacy_reporter_without_start()
  warns_when_ios_tools_missing_on_macos()
  skips_ios_checks_on_non_macos()
end

return M
