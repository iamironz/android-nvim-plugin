local M = {}

local assert = require("tests.helpers.assert")
local stubs_helper = require("tests.helpers.stubs")

local function ios_workspace()
  return { root = "/ios", workspace = "/ios/App.xcworkspace" }
end

local function ios_project_workspace()
  return { root = "/ios", project = "/ios/iosApp.xcodeproj" }
end

local function sample_build_settings()
  return table.concat({
    "TARGET_BUILD_DIR = /build",
    "FULL_PRODUCT_NAME = App.app",
    "PRODUCT_BUNDLE_IDENTIFIER = com.example.app",
  }, "\n")
end

local function build_settings_with_configuration_dir()
  return table.concat({
    "CONFIGURATION_BUILD_DIR = /build",
    "FULL_PRODUCT_NAME = App.app",
    "PRODUCT_BUNDLE_IDENTIFIER = com.example.app",
  }, "\n")
end

local function simctl_booted_output()
  return '{"devices":{"runtime":[{"state":"Booted","udid":"BOOTED-1","name":"iPhone"}]}}'
end

local function simctl_empty_output()
  return '{"devices":{"runtime":[]}}'
end

local function devicectl_paired_json(udid)
  return table.concat({
    "{",
    '  "identifier": "' .. udid .. '",',
    '  "connectionProperties": { "pairingState": "paired" },',
    '  "hardwareProperties": { "reality": "physical" },',
    '  "deviceProperties": { "name": "My iPhone" }',
    "}",
  }, "\n")
end

local function devicectl_json_output(devices)
  return table.concat({
    "{",
    "  \"result\": {",
    "    \"devices\": [",
    devices or "",
    "    ]",
    "  }",
    "}",
  }, "\n")
end

local function with_temp_json(contents, fn)
  local original_tempname = vim.fn.tempname
  local original_readfile = vim.fn.readfile

  vim.fn.tempname = function()
    return "/tmp/devicectl.json"
  end

  vim.fn.readfile = function(path)
    if path == "/tmp/devicectl.json" then
      return vim.split(contents, "\n", { plain = true })
    end
    return original_readfile(path)
  end

  local ok, err = pcall(fn)

  vim.fn.tempname = original_tempname
  vim.fn.readfile = original_readfile

  if not ok then
    error(err)
  end
end

local function runner_with_outputs(outputs)
  local commands = {}
  local runner = {
    run = function(cmd)
      table.insert(commands, cmd)
      if cmd[1] == "xcodebuild" and cmd[#cmd] == "-list" then
        return { ok = true, stdout = outputs.list_stdout or "Schemes:\n  App\n" }
      end
      if cmd[1] == "xcodebuild" and cmd[#cmd] == "-showBuildSettings" then
        return { ok = true, stdout = outputs.build_settings_stdout or sample_build_settings() }
      end
      if cmd[1] == "xcrun" and cmd[2] == "simctl" and cmd[3] == "list" then
        return { ok = true, stdout = outputs.simctl_stdout or "" }
      end
      if cmd[1] == "xcrun" and cmd[2] == "devicectl" and cmd[3] == "list" then
        return { ok = true, stdout = outputs.devicectl_stdout or "" }
      end
      return { ok = true, stdout = "" }
    end,
  }
  return runner, commands
end

local function run_deploy_and_capture(runner)
  local build_args = nil
  local stubs = {
    ["android.build.stream"] = {
      start_build_job = function(_, args, on_complete)
        build_args = args
        if on_complete then
          on_complete({ ok = true })
        end
        return { ok = true }
      end,
    },
  }

  stubs_helper.with_stubs(stubs, function()
    package.loaded["android.build.ios"] = nil
    local ios = require("android.build.ios")
    ios.deploy(ios_workspace(), runner)
  end)

  return build_args
end

local function extract_destination(build_args)
  local destination = ""
  for i = 1, #(build_args or {}) do
    if build_args[i] == "-destination" then
      destination = build_args[i + 1] or ""
      break
    end
  end
  return destination
end

local function build_uses_workspace_and_scheme()
  local captured = { root = nil, args = nil }
  local runner = {
    run = function(cmd)
      if cmd[1] == "xcodebuild" and cmd[#cmd] == "-list" then
        return { ok = true, stdout = "Schemes:\n  App\n" }
      end
      return { ok = true, stdout = "" }
    end,
  }

  local stubs = {
    ["android.build.stream"] = {
      start_build_job = function(root, args)
        captured.root = root
        captured.args = args
        return { ok = true }
      end,
    },
  }

  stubs_helper.with_stubs(stubs, function()
    package.loaded["android.build.ios"] = nil
    local ios = require("android.build.ios")
    ios.build(ios_workspace(), runner)
  end)

  local joined = table.concat(captured.args or {}, "|")
  local summary = string.format("%s|%s", captured.root or "", joined)
  local expected = table.concat({
    "/ios",
    "xcodebuild",
    "-workspace",
    "/ios/App.xcworkspace",
    "-scheme",
    "App",
    "-configuration",
    "Debug",
    "-sdk",
    "iphonesimulator",
    "build",
  }, "|")
  assert.eq(
    summary,
    expected,
    "build args"
  )
end

local function build_prefers_ios_scheme_when_base_missing()
  local captured = { root = nil, args = nil }
  local runner = {
    run = function(cmd)
      if cmd[1] == "xcodebuild" and cmd[#cmd] == "-list" then
        return { ok = true, stdout = "Schemes:\n  GarminSyncWidget\n  ios\n" }
      end
      return { ok = true, stdout = "" }
    end,
  }

  local stubs = {
    ["android.build.stream"] = {
      start_build_job = function(root, args)
        captured.root = root
        captured.args = args
        return { ok = true }
      end,
    },
  }

  stubs_helper.with_stubs(stubs, function()
    package.loaded["android.build.ios"] = nil
    local ios = require("android.build.ios")
    ios.build(ios_project_workspace(), runner)
  end)

  local scheme = ""
  for i = 1, #(captured.args or {}) do
    if captured.args[i] == "-scheme" then
      scheme = captured.args[i + 1] or ""
      break
    end
  end
  assert.eq(scheme, "ios", "ios scheme preferred")
end

local function deploy_installs_and_launches_simulator()
  local runner, commands = runner_with_outputs({
    simctl_stdout = simctl_booted_output(),
  })
  local build_args = nil
  with_temp_json(devicectl_json_output(devicectl_paired_json("PAIRED-1")), function()
    build_args = run_deploy_and_capture(runner)
  end)
  local destination = extract_destination(build_args)

  local install = nil
  local launch = nil
  local devicectl_called = false
  for _, cmd in ipairs(commands) do
    if cmd[1] == "xcrun" and cmd[2] == "simctl" and cmd[3] == "install" then
      install = cmd
    elseif cmd[1] == "xcrun" and cmd[2] == "simctl" and cmd[3] == "launch" then
      launch = cmd
    elseif cmd[1] == "xcrun" and cmd[2] == "devicectl" then
      devicectl_called = true
    end
  end

  local summary = string.format(
    "%s|%s|%s",
    destination,
    install and install[5] or "",
    launch and launch[5] or ""
  )
  assert.eq(summary, "id=BOOTED-1|/build/App.app|com.example.app", "deploy app")
  assert.is_true(not devicectl_called, "prefers simulator")
end

local function deploy_uses_configuration_build_dir_when_target_missing()
  local runner, commands = runner_with_outputs({
    simctl_stdout = simctl_booted_output(),
    build_settings_stdout = build_settings_with_configuration_dir(),
  })
  with_temp_json(devicectl_json_output(devicectl_paired_json("PAIRED-1")), function()
    run_deploy_and_capture(runner)
  end)

  local install = nil
  local launch = nil
  for _, cmd in ipairs(commands) do
    if cmd[1] == "xcrun" and cmd[2] == "simctl" and cmd[3] == "install" then
      install = cmd
    elseif cmd[1] == "xcrun" and cmd[2] == "simctl" and cmd[3] == "launch" then
      launch = cmd
    end
  end

  local summary = string.format(
    "%s|%s",
    install and install[5] or "",
    launch and launch[5] or ""
  )
  assert.eq(summary, "/build/App.app|com.example.app", "config build dir used")
end

local function deploy_installs_and_launches_physical_device()
  local runner, commands = runner_with_outputs({
    simctl_stdout = simctl_empty_output(),
  })
  local build_args = nil
  with_temp_json(devicectl_json_output(devicectl_paired_json("DEVICE-1")), function()
    build_args = run_deploy_and_capture(runner)
  end)
  local destination = extract_destination(build_args)

  local install = nil
  local launch = nil
  for _, cmd in ipairs(commands) do
    if cmd[1] == "xcrun" and cmd[2] == "devicectl" and cmd[3] == "device" then
      if cmd[4] == "install" then
        install = cmd
      elseif cmd[4] == "process" then
        launch = cmd
      end
    end
  end

  local summary = string.format(
    "%s|%s|%s",
    destination,
    install and install[#install] or "",
    launch and launch[#launch] or ""
  )
  assert.eq(summary, "id=DEVICE-1|/build/App.app|com.example.app", "deploy device")
end

local function deploy_reports_actionable_error_when_no_devices()
  local notify_message = nil
  local runner = select(1, runner_with_outputs({
    simctl_stdout = simctl_empty_output(),
  }))

  local original_notify = vim.notify
  vim.notify = function(message)
    notify_message = message
  end

  local ok, err = pcall(function()
    with_temp_json(devicectl_json_output(""), function()
      package.loaded["android.build.ios"] = nil
      local ios = require("android.build.ios")
      ios.deploy(ios_workspace(), runner)
    end)
  end)

  vim.notify = original_notify

  if not ok then
    error(err)
  end

  assert.eq(
    notify_message,
    "No booted iOS simulators or paired physical devices found. "
      .. "Boot a simulator or pair a device in Xcode.",
    "actionable device error"
  )
end

function M.run()
  build_uses_workspace_and_scheme()
  build_prefers_ios_scheme_when_base_missing()
  deploy_installs_and_launches_simulator()
  deploy_uses_configuration_build_dir_when_target_missing()
  deploy_installs_and_launches_physical_device()
  deploy_reports_actionable_error_when_no_devices()
end

return M
