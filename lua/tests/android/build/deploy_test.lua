local M = {}

local assert = require("tests.helpers.assert")
local deploy = require("android.build.deploy")

local function make_temp_file(name)
  local dir = vim.fn.tempname()
  vim.fn.mkdir(dir, "p")
  local path = dir .. "/" .. name
  vim.fn.writefile({ "bin" }, path)
  return path
end

local function adb_command(adb_path, device, args)
  local cmd = { adb_path, "-s", device }
  for _, arg in ipairs(args) do
    table.insert(cmd, arg)
  end
  return cmd
end

local function builds_install_command()
  local adb_path = make_temp_file("adb")
  local result = deploy.build_install_command(
    adb_path,
    "emulator-5554",
    "/apks/app-debug.apk"
  )

  assert.is_true(result.ok, "install ok")
  assert.table_eq(
    result.cmd,
    adb_command(adb_path, "emulator-5554", {
      "install",
      "-r",
      "-d",
      "-t",
      "/apks/app-debug.apk",
    }),
    "install cmd"
  )
end

local function builds_launch_command_with_activity()
  local adb_path = make_temp_file("adb")
  local result = deploy.build_launch_command(
    adb_path,
    "emulator-5554",
    "com.example.app",
    "com.example.app.MainActivity"
  )

  assert.is_true(result.ok, "launch ok")
  assert.table_eq(
    result.cmd,
    adb_command(adb_path, "emulator-5554", {
      "shell",
      "am",
      "start",
      "-n",
      "com.example.app/com.example.app.MainActivity",
    }),
    "launch cmd"
  )
end

local function builds_launch_command_with_app_id()
  local adb_path = make_temp_file("adb")
  local result = deploy.build_launch_command(
    adb_path,
    "emulator-5554",
    "com.example.app",
    nil
  )

  assert.is_true(result.ok, "launch ok")
  assert.table_eq(
    result.cmd,
    adb_command(adb_path, "emulator-5554", {
      "shell",
      "monkey",
      "-p",
      "com.example.app",
      "-c",
      "android.intent.category.LAUNCHER",
      "1",
    }),
    "launch monkey"
  )
end

local function warns_when_launch_missing_app_id()
  local adb_path = make_temp_file("adb")
  local result = deploy.build_launch_command(
    adb_path,
    "emulator-5554",
    nil,
    nil
  )

  assert.is_true(result.ok, "launch ok")
  assert.eq(result.cmd, nil, "launch cmd missing")
  assert.contains(result.warning, "app id", "launch warning")
end

local function returns_error_for_missing_adb()
  local result = deploy.build_install_command(
    nil,
    "emulator-5554",
    "/apks/app.apk"
  )

  assert.eq(result.ok, false, "missing adb ok")
  assert.contains(result.error, "adb", "missing adb error")
end

local function resolves_app_id_from_aapt2_output()
  local aapt2_path = make_temp_file("aapt2")
  local received = { cmd = nil }
  local stdout = table.concat(
    {
      "package: name='com.example.app' versionCode='1' versionName='1.0'",
      "sdkVersion:'21'",
      "launchable-activity: name='com.example.app.MainActivity' label='App' icon=''",
    },
    "\n"
  )

  local runner = {
    run = function(cmd)
      received.cmd = cmd
      return { ok = true, stdout = stdout, stderr = "" }
    end,
  }

  local result = deploy.resolve_app_id("/apks/app-debug.apk", aapt2_path, runner)

  assert.is_true(result.ok, "resolve app id ok")
  assert.eq(result.app_id, "com.example.app", "resolve app id")
  assert.eq(result.activity, nil, "activity not parsed")
  assert.table_eq(
    received.cmd,
    { aapt2_path, "dump", "badging", "/apks/app-debug.apk" },
    "aapt2 command"
  )
end

local function returns_error_for_missing_aapt2_path()
  local result = deploy.resolve_app_id("/apks/app-debug.apk", nil, {})

  assert.eq(result.ok, false, "missing aapt2 ok")
  assert.contains(result.error, "aapt2", "missing aapt2 error")
end

local function deploys_with_launch_fallback_without_app_id()
  local adb_path = make_temp_file("adb")
  local received = {}
  local runner = {
    run = function(cmd)
      table.insert(received, cmd)
      return { ok = true, stdout = "", stderr = "" }
    end,
  }

  local result = deploy.deploy({
    adb_path = adb_path,
    device = "emulator-5554",
    apk_path = "/apks/app-debug.apk",
    runner = runner,
  })

  assert.is_true(result.ok, "deploy ok")
  assert.eq(#received, 1, "deploy run count")
  assert.eq(result.launch, nil, "launch result missing")
  assert.contains(result.warning, "launch", "deploy warning")
end

local function deploys_with_warning_when_aapt2_missing()
  local adb_path = make_temp_file("adb")
  local received = {}
  local runner = {
    run = function(cmd)
      table.insert(received, cmd)
      return { ok = true, stdout = "", stderr = "" }
    end,
  }

  local result = deploy.deploy({
    adb_path = adb_path,
    device = "emulator-5554",
    apk_path = "/apks/app-debug.apk",
    aapt2_path = vim.fn.tempname() .. "/missing-aapt2",
    runner = runner,
  })

  assert.is_true(result.ok, "deploy ok")
  assert.eq(#received, 1, "deploy run count")
  assert.contains(result.warning, "aapt2", "deploy warning")
end

function M.run()
  builds_install_command()
  builds_launch_command_with_activity()
  builds_launch_command_with_app_id()
  warns_when_launch_missing_app_id()
  returns_error_for_missing_adb()
  resolves_app_id_from_aapt2_output()
  returns_error_for_missing_aapt2_path()
  deploys_with_launch_fallback_without_app_id()
  deploys_with_warning_when_aapt2_missing()
end

return M
