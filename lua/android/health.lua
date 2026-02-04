local M = {}

local build_helpers = require("android.actions.build_helpers")
local discovery = require("android.sdk.discovery")
local project_detect = require("android.project.detect")

local function default_exists(path)
  local stat = vim.loop.fs_stat(path)
  return stat ~= nil
end

local function default_read_file(path)
  local ok, lines = pcall(vim.fn.readfile, path)
  if ok then
    return lines
  end
  return nil
end

local function default_scandir(path)
  local handle = vim.loop.fs_scandir(path)
  if not handle then
    return {}
  end

  local entries = {}
  while true do
    local name, entry_type = vim.loop.fs_scandir_next(handle)
    if not name then
      break
    end
    table.insert(entries, { name = name, type = entry_type })
  end
  return entries
end

local function default_executable(command)
  return vim.fn.executable(command)
end

local function resolve_reporter(health)
  local api = health or vim.health
  if api and api.start and api.ok and api.error then
    return {
      start = api.start,
      ok = api.ok,
      warn = api.warn or api.ok,
      error = api.error,
      info = api.info or api.ok,
    }
  end
  return {
    start = api.report_start or api.report_info or api.report_ok,
    ok = api.report_ok,
    warn = api.report_warn or api.report_ok,
    error = api.report_error,
    info = api.report_info or api.report_ok,
  }
end

local function list_build_tools(root, scandir)
  if not root or root == "" then
    return {}
  end
  local scan = scandir or default_scandir
  local entries = scan(root .. "/build-tools") or {}
  local versions = {}
  for _, entry in ipairs(entries) do
    local name = entry.name or entry[1]
    if name and name ~= "" then
      table.insert(versions, name)
    end
  end
  table.sort(versions)
  return versions
end

local function check_sdk_root(context, reporter)
  reporter.start("Android SDK")
  local root, source = discovery.detect_root(context.env, context.exists, {
    config = context.config,
    read_file = context.read_file,
    root = context.cwd,
    cwd = context.cwd,
    os_name = context.os_name,
    home = context.home,
  })
  if not root then
    reporter.error(
      "Android SDK root not found. Set ANDROID_SDK_ROOT or sdk.dir in local.properties, "
        .. "or configure sdk.root in setup."
    )
    return nil
  end
  reporter.ok("Android SDK root: " .. root .. " (source: " .. (source or "unknown") .. ")")
  return root
end

local function check_android_tools(context, reporter, root)
  reporter.start("Android tools")
  if not root then
    reporter.warn("Android SDK root missing. Skipping Android tools checks.")
    return
  end

  local tools = discovery.locate_tools(root, context.exists, context.os_name)
  if tools.sdkmanager then
    reporter.ok("sdkmanager: " .. tools.sdkmanager)
  else
    reporter.error("sdkmanager not found. Install Android SDK Command-line Tools.")
  end
  if tools.avdmanager then
    reporter.ok("avdmanager: " .. tools.avdmanager)
  else
    reporter.error("avdmanager not found. Install Android SDK Command-line Tools.")
  end
  if tools.adb then
    reporter.ok("adb: " .. tools.adb)
  else
    reporter.error("adb not found. Install Android SDK Platform Tools.")
  end
  if tools.emulator then
    reporter.ok("emulator: " .. tools.emulator)
  else
    reporter.error("emulator not found. Install Android Emulator in SDK Manager.")
  end

  local build_tools = list_build_tools(root, context.scandir)
  local aapt2 = discovery.locate_aapt2(root, build_tools, context.exists, context.os_name)
  if aapt2 then
    reporter.ok("aapt2: " .. aapt2)
  else
    reporter.error("aapt2 not found. Install Android SDK Build-Tools.")
  end
end

local function check_gradle(context, reporter)
  reporter.start("Gradle")
  local project = context.project
    or project_detect.detect(context.cwd, {
      exists = context.exists,
      read = context.read_file,
      scandir = context.scandir,
    })
  if not project or not project.root then
    reporter.warn(
      "Gradle project not detected for "
        .. (context.cwd or "current directory")
        .. ". Run checkhealth from a project root."
    )
    return
  end

  local command = build_helpers.resolve_gradle_command(project.root)
  local command_name = command and command[1] or nil
  if not command_name or command_name == "" then
    reporter.error(
      "Gradle command not resolved for "
        .. project.root
        .. ". Set build.gradle_command in setup."
    )
    return
  end

  local exists = context.exists(command_name)
  local executable = context.executable(command_name) == 1
  if exists or executable then
    reporter.ok("Gradle command: " .. command_name)
    return
  end

  reporter.error(
    "Gradle command not found. Run ./gradlew or set build.gradle_command in setup."
  )
end

local function check_ios_tools(context, reporter)
  reporter.start("iOS tools")
  if context.os_name ~= "Darwin" then
    reporter.info("iOS checks skipped on non macOS")
    return
  end

  if context.executable("xcodebuild") == 1 then
    reporter.ok("xcodebuild available")
  else
    reporter.warn("xcodebuild not found. Install Xcode and command line tools.")
  end

  if context.executable("xcrun") == 1 then
    reporter.ok("xcrun available")
  else
    reporter.warn("xcrun not found. Install Xcode command line tools.")
  end
end

function M.check(opts)
  local options = opts or {}
  local reporter = resolve_reporter(options.health)
  local context = {
    cwd = options.cwd or vim.fn.getcwd(),
    os_name = options.os_name or vim.loop.os_uname().sysname,
    env = options.env or vim.env,
    home = options.home or (vim.env.HOME or vim.env.USERPROFILE),
    exists = options.exists or default_exists,
    read_file = options.read_file or default_read_file,
    scandir = options.scandir or default_scandir,
    executable = options.executable or default_executable,
    config = options.config,
    project = options.project,
  }

  local sdk_root = check_sdk_root(context, reporter)
  check_android_tools(context, reporter, sdk_root)
  check_gradle(context, reporter)
  check_ios_tools(context, reporter)
end

return M
