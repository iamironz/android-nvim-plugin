local M = {}

local assert = require("tests.helpers.assert")
local command = require("android.logcat.command")

local function builds_command_with_serial_and_pid()
  local cmd = command.build({
    adb_path = "/sdk/adb",
    serial = "device-1",
    pid = "1234",
    filters = { level = "D", tag = "MyTag" },
  })

  assert.table_eq(cmd, {
    "/sdk/adb",
    "-s",
    "device-1",
    "logcat",
    "-v",
    "threadtime",
    "--pid",
    "1234",
    "MyTag:D",
    "*:S",
  }, "pid command")
end

local function builds_command_with_package_filter()
  local cmd = command.build({
    adb_path = "adb",
    package = "com.example.app",
    filters = { level = "W" },
  })

  assert.table_eq(cmd, {
    "adb",
    "logcat",
    "-v",
    "threadtime",
    "-e",
    "com.example.app",
    "*:W",
  }, "package command")
end

local function defaults_tag_level_when_missing()
  local cmd = command.build({
    adb_path = "adb",
    filters = { tag = "MyTag" },
  })

  assert.table_eq(cmd, {
    "adb",
    "logcat",
    "-v",
    "threadtime",
    "MyTag:V",
    "*:S",
  }, "tag default level")
end

function M.run()
  builds_command_with_serial_and_pid()
  builds_command_with_package_filter()
  defaults_tag_level_when_missing()
end

return M
